#' RECONFORT layer manifest: describe a run's displayable outputs (L6)
#'
#' @description
#' Translates the result of [run_reconfort_dieback()] into a flat
#' `data.frame` describing the map layers a RECONFORT run exposes — the
#' continuous dieback **score**, the per-pixel **classification**, the
#' **probability** map, and the **alert** centroids — together with the
#' rendering hints a viewer needs (palette, direction, value domain,
#' default visibility and opacity).
#'
#' The semantics of a RECONFORT output (what a layer *is*, how its values
#' are scaled, which way the palette runs) are business knowledge and
#' therefore live in the `nemeton` core. A presentation layer
#' (e.g. `nemetonshiny`) consumes this manifest verbatim to build its
#' layer toggles and opacity control, without hard-coding any RECONFORT
#' semantics of its own (ADR-009, CLAUDE.md strict rules §1-3).
#'
#' Only **available** layers are returned: a raster whose path is `NA`
#' (the masked variants only exist once masking ran) is skipped, and the
#' alert row appears only when the run produced at least one alert. For
#' the classification and probability layers the masked variant is
#' preferred and the raw one is used as a fallback.
#'
#' Value domains are *nominal* by default (score `1..100`, probability
#' `0..1000`) — pure, file-free and testable. Pass `include_range = TRUE`
#' to replace them with the actual per-raster min/max read via
#' \pkg{terra} (best-effort: a read failure keeps the nominal domain).
#'
#' @param result The list returned by [run_reconfort_dieback()]. Only
#'   `result$rasters` (a named list of output paths, see
#'   [run_reconfort_dieback()]) and, optionally, `result$alerts_sf` /
#'   `result$n_alerts` are read.
#' @param include_range If `TRUE`, override the nominal `vmin`/`vmax` of
#'   the continuous rasters with their actual `terra::minmax()`. Default
#'   `FALSE` (nominal domains, no file access).
#'
#' @return A `data.frame` with one row per available layer and the
#'   columns:
#'   \describe{
#'     \item{id}{Stable layer key (`"score"`, `"classification"`,
#'       `"probability"`, `"alerts"`).}
#'     \item{label_key}{i18n key (NMT convention) for the display label,
#'       resolved by the viewer.}
#'     \item{type}{`"raster"` or `"vector"`.}
#'     \item{role}{Semantic role, equal to `id` here but kept distinct so
#'       future variants (e.g. masked vs raw) can share a role.}
#'     \item{path}{Raster file path, or `NA` for the vector layer.}
#'     \item{categorical}{`TRUE` for the classification raster, `FALSE`
#'       for the continuous rasters, `NA` for the vector.}
#'     \item{palette}{Suggested palette name for continuous rasters
#'       (`"RdYlGn"`, `"viridis"`), `NA` where the viewer should use the
#'       discrete [`RECONFORT_CLASSES`] colours or its own marker style.}
#'     \item{reverse}{Whether the palette runs high-to-low (the score is
#'       reversed so high = severe = red).}
#'     \item{vmin, vmax}{Value domain for the colour scale (`NA` for the
#'       categorical and vector layers).}
#'     \item{default_visible}{Whether the viewer should show the layer on
#'       first render (score and alerts on; the rest off).}
#'     \item{default_opacity}{Suggested initial opacity in `0..1`.}
#'     \item{n_features}{Alert feature count for the vector layer,
#'       `NA` for rasters.}
#'   }
#'   When the run produced no displayable output the data.frame has zero
#'   rows (the columns and their types are still present).
#'
#' @seealso [run_reconfort_dieback()], [RECONFORT_CLASSES]
#' @export
reconfort_layer_manifest <- function(result, include_range = FALSE) {
  if (!is.list(result) || is.null(result$rasters) ||
      !is.list(result$rasters)) {
    cli::cli_abort(c(
      "{.arg result} must be the list returned by {.fn run_reconfort_dieback}.",
      i = "Expected a {.cls list} with a {.field rasters} element."
    ))
  }
  rasters <- result$rasters

  # Prefer the masked variant, fall back to the raw one, else NA.
  pick <- function(masked, raw) {
    if (!is.null(masked) && length(masked) && !is.na(masked)) return(masked)
    if (!is.null(raw) && length(raw) && !is.na(raw)) return(raw)
    NA_character_
  }

  .reconfort_build_manifest(
    paths = list(
      score          = pick(rasters$continuous_score, NULL),
      classification = pick(rasters$classif_masked, rasters$classif),
      probability    = pick(rasters$probability_masked, rasters$probability)),
    n_alerts      = .reconfort_alert_count(result),
    include_range = include_range)
}


# Static per-layer display descriptors (palette, sens, domain, default
# visibility/opacity). Shared by reconfort_layer_manifest() (in-memory)
# and reconfort_cache_manifest() (from cache) so the two emit the *exact*
# same schema and rendering hints.
.RECONFORT_LAYER_DESCRIPTORS <- list(
  list(id = "score", label_key = "reconfort_couche_score", role = "score",
       categorical = FALSE, palette = "RdYlGn", reverse = TRUE,
       vmin = 1, vmax = 100, default_visible = TRUE, default_opacity = 0.8),
  list(id = "classification", label_key = "reconfort_couche_classes",
       role = "classification", categorical = TRUE, palette = NA_character_,
       reverse = FALSE, vmin = NA_real_, vmax = NA_real_,
       default_visible = FALSE, default_opacity = 0.8),
  list(id = "probability", label_key = "reconfort_couche_proba",
       role = "probability", categorical = FALSE, palette = "viridis",
       reverse = FALSE, vmin = 0, vmax = 1000, default_visible = FALSE,
       default_opacity = 0.8)
)


# Empty manifest with the canonical columns + types.
.reconfort_empty_manifest <- function() {
  data.frame(
    id = character(), label_key = character(), type = character(),
    role = character(), path = character(), categorical = logical(),
    palette = character(), reverse = logical(), vmin = numeric(),
    vmax = numeric(), default_visible = logical(),
    default_opacity = numeric(), n_features = integer(),
    stringsAsFactors = FALSE)
}


# Build the manifest data.frame from resolved raster `paths` (named list
# with `score` / `classification` / `probability`, NA when absent) plus an
# optional alert count. The single source of truth for the manifest shape.
.reconfort_build_manifest <- function(paths, n_alerts = 0L,
                                      include_range = FALSE) {
  rows <- list()
  for (d in .RECONFORT_LAYER_DESCRIPTORS) {
    p <- paths[[d$id]]
    if (is.null(p) || is.na(p) || !nzchar(p)) next
    vmin <- d$vmin; vmax <- d$vmax
    if (include_range && !d$categorical) {
      rng <- tryCatch({
        mm <- terra::minmax(terra::rast(p))
        if (all(is.finite(mm))) c(mm[1L], mm[2L]) else NULL
      }, error = function(e) NULL)
      if (!is.null(rng)) { vmin <- rng[1L]; vmax <- rng[2L] }
    }
    rows[[length(rows) + 1L]] <- data.frame(
      id = d$id, label_key = d$label_key, type = "raster", role = d$role,
      path = p, categorical = d$categorical, palette = d$palette,
      reverse = d$reverse, vmin = vmin, vmax = vmax,
      default_visible = d$default_visible,
      default_opacity = d$default_opacity, n_features = NA_integer_,
      stringsAsFactors = FALSE)
  }

  # Alert vector layer — present only when there are alerts. Its geometry
  # lives in the `alert` table / `result$alerts_sf`, not on a raster path.
  if (is.numeric(n_alerts) && length(n_alerts) == 1L && !is.na(n_alerts) &&
      n_alerts > 0L) {
    rows[[length(rows) + 1L]] <- data.frame(
      id = "alerts", label_key = "reconfort_couche_alertes",
      type = "vector", role = "alerts", path = NA_character_,
      categorical = NA, palette = NA_character_, reverse = FALSE,
      vmin = NA_real_, vmax = NA_real_, default_visible = TRUE,
      default_opacity = 0.9, n_features = as.integer(n_alerts),
      stringsAsFactors = FALSE)
  }

  if (!length(rows)) return(.reconfort_empty_manifest())
  do.call(rbind, rows)
}


# Resolve a RECONFORT run id from the cache zone dir: the supplied
# `run_id`, else the most recent inferred from the `reconfort_mask_<id>.tif`
# files and `run_<id>/` bundle dirs (timestamp ids sort chronologically).
.reconfort_resolve_cache_run <- function(zdir, run_id = NULL) {
  if (!is.null(run_id) && length(run_id) == 1L && !is.na(run_id) &&
      nzchar(run_id)) {
    return(as.character(run_id))
  }
  masks <- list.files(zdir, pattern = "^reconfort_mask_.+\\.tif$")
  ids <- sub("^reconfort_mask_(.+)\\.tif$", "\\1", masks)
  subdirs <- list.dirs(zdir, recursive = FALSE, full.names = FALSE)
  ids <- c(ids, sub("^run_", "", subdirs[grepl("^run_", subdirs)]))
  ids <- unique(ids[nzchar(ids)])
  if (!length(ids)) return(NULL)
  sort(ids)[length(ids)]
}


#' Discover the persisted RECONFORT display layers from the cache (L6)
#'
#' @description
#' Cache-side counterpart of [reconfort_layer_manifest()]: rebuilds the
#' layer manifest of a RECONFORT run from the rasters persisted under the
#' project cache, **without** the in-memory `result`. This lets a viewer
#' redraw the RECONFORT rasters after a project reload (parity with
#' [read_fordead_layer()] / [read_fordead_dieback_mask()], which read
#' their layers from the cache).
#'
#' The run is resolved from `run_id`, else the most recent run found under
#' the zone cache directory. The discovered display rasters are the
#' run-scoped files written by the `persist` phase of
#' [run_reconfort_dieback()]: `reconfort_mask_<run_id>.tif`
#' (classification), `reconfort_score_<run_id>.tif` (continuous score) and
#' `reconfort_proba_<run_id>.tif` (probability). The CRswir / CRre
#' multi-band stacks (a time series consumed by
#' [read_reconfort_pixel_series()]) are **not** display layers and are
#' excluded.
#'
#' The output is byte-for-byte interchangeable with
#' [reconfort_layer_manifest()] (same columns, types and rendering hints),
#' so the caller reuses the same machinery ([read_reconfort_layer()],
#' raster cache, toggles, opacity). Alerts are not included (they are read
#' from the `alert` table independently).
#'
#' @param cache_dir Project RECONFORT cache directory. The zone layers are
#'   resolved at `<cache_dir>/zone_<zone_id>/` or, as a fallback,
#'   `<cache_dir>/reconfort/zone_<zone_id>/`.
#' @param zone_id Scalar monitoring-zone id.
#' @param run_id Run timestamp, or `NULL` (default) to pick the most
#'   recent run in the zone cache.
#' @param include_range If `TRUE`, fill `vmin`/`vmax` of the continuous
#'   rasters with their actual `terra::minmax()`. Default `FALSE`.
#'
#' @return A `data.frame` with the same columns as
#'   [reconfort_layer_manifest()] (one row per available display raster).
#'   Best-effort: a missing cache / zone / run yields a zero-row frame.
#'
#' @seealso [reconfort_layer_manifest()], [read_reconfort_layer()],
#'   [run_reconfort_dieback()]
#' @export
reconfort_cache_manifest <- function(cache_dir, zone_id, run_id = NULL,
                                     include_range = FALSE) {
  if (missing(cache_dir) || !is.character(cache_dir) ||
      length(cache_dir) != 1L || is.na(cache_dir) || !nzchar(cache_dir)) {
    return(.reconfort_empty_manifest())
  }
  if (length(zone_id) != 1L || is.na(zone_id)) {
    return(.reconfort_empty_manifest())
  }
  zname <- sprintf("zone_%s", zone_id)
  cand  <- c(file.path(cache_dir, zname),
             file.path(cache_dir, "reconfort", zname))
  zdir  <- cand[dir.exists(cand)]
  if (!length(zdir)) return(.reconfort_empty_manifest())
  zdir  <- zdir[[1L]]

  rid <- .reconfort_resolve_cache_run(zdir, run_id)
  if (is.null(rid)) return(.reconfort_empty_manifest())

  pick_file <- function(name) {
    fp <- file.path(zdir, sprintf(name, rid))
    if (file.exists(fp)) fp else NA_character_
  }
  .reconfort_build_manifest(
    paths = list(
      score          = pick_file("reconfort_score_%s.tif"),
      classification = pick_file("reconfort_mask_%s.tif"),
      probability    = pick_file("reconfort_proba_%s.tif")),
    n_alerts      = 0L,
    include_range = include_range)
}


# Count the alerts a run produced, from `alerts_sf` (preferred) or the
# `n_alerts` scalar. Robust to NULL / non-sf inputs.
.reconfort_alert_count <- function(result) {
  a <- result$alerts_sf
  if (inherits(a, "sf") || is.data.frame(a)) return(nrow(a))
  n <- result$n_alerts
  if (is.numeric(n) && length(n) == 1L && !is.na(n)) return(as.integer(n))
  0L
}


# Resolve a raster file path from a `read_reconfort_layer()` `layer`
# argument: either a length-1 character path, or a single row of a
# `reconfort_layer_manifest()` data.frame (whose `type` must be
# "raster"). Aborts with an actionable message otherwise.
.reconfort_resolve_layer_path <- function(layer) {
  if (is.data.frame(layer)) {
    if (nrow(layer) != 1L) {
      cli::cli_abort(c(
        "{.arg layer} must be a single manifest row.",
        x = "Got {nrow(layer)} rows.",
        i = "Subset one row, e.g. {.code manifest[manifest$id == \"score\", ]}."
      ))
    }
    if (!is.null(layer$type) && !identical(layer$type[[1L]], "raster")) {
      cli::cli_abort(c(
        "{.arg layer} is not a raster layer ({.val {layer$type[[1L]]}}).",
        i = "The alert vector is not a maskable raster; render it directly."
      ))
    }
    path <- layer$path[[1L]]
  } else if (is.character(layer) && length(layer) == 1L) {
    path <- layer
  } else {
    cli::cli_abort(
      "{.arg layer} must be a raster path or a single manifest row.")
  }
  if (is.null(path) || is.na(path) || !nzchar(path)) {
    cli::cli_abort("{.arg layer} has no usable raster path.")
  }
  if (!file.exists(path)) {
    cli::cli_abort(c("RECONFORT raster not found.",
                     x = "{.path {path}}"))
  }
  path
}


#' Read a RECONFORT output raster, masked to the UGF zone by default (L7)
#'
#' @description
#' Reader for the raster layers of a RECONFORT run, the analogue of
#' [read_fast_alert_raster()] and [read_fordead_dieback_mask()]
#' (spec 016). By default it restricts the raster to the **UGF zone
#' polygon** (pixels outside the user's managed perimeter become `NA`),
#' so RECONFORT reaches parity with the two other health pipelines and
#' the spatial mask lives in the `nemeton` core rather than in the
#' presentation layer (spec 021 L7, ADR-013 amendment A6).
#'
#' The on-disk IOTA² rasters are not modified: the mask is applied at
#' **read time** (spec 016 principle "mask at read, not write"). Reuses
#' the spec 016 helpers `.apply_zone_mask()` / `.get_zone_aoi()`.
#'
#' @param layer Either a length-1 raster path, or a single row of a
#'   [reconfort_layer_manifest()] data.frame (its `type` must be
#'   `"raster"`; a `"vector"` row — the alert centroids — is rejected,
#'   the vector is not masked here, see spec 021 L7 §D3).
#' @param con A `DBIConnection`, used only to resolve the zone polygon
#'   via [`.get_zone_aoi`()] when `mask_polygon` is `NULL`. `NULL`
#'   skips DB resolution.
#' @param zone_id Integer scalar identifying the row in `monitoring_zone`
#'   (used with `con`).
#' @param apply_zone_mask If `TRUE` (default), mask the raster to the UGF
#'   polygon. `FALSE` returns the raw raster (bbox + OSO broadleaf
#'   extent), the pre-L7 behaviour.
#' @param mask_polygon An explicit `sf`/`sfc` polygon overriding the DB
#'   lookup. When `NULL`, the polygon is resolved from `con` + `zone_id`.
#'
#' @return A `terra::SpatRaster` (masked to the UGF zone unless
#'   `apply_zone_mask = FALSE` or no polygon could be resolved).
#'
#' @seealso [reconfort_layer_manifest()], [run_reconfort_dieback()],
#'   [read_fast_alert_raster()], [read_fordead_dieback_mask()]
#' @export
read_reconfort_layer <- function(layer, con = NULL, zone_id = NULL,
                                 apply_zone_mask = TRUE,
                                 mask_polygon = NULL) {
  path <- .reconfort_resolve_layer_path(layer)
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} is required to read RECONFORT rasters.")
  }
  out <- terra::rast(path)

  if (isTRUE(apply_zone_mask)) {
    # spec 016 (v0.49.0) parity: restrict to the UGF polygon at read
    # time. Resolve the polygon from an explicit override, else the DB.
    poly <- mask_polygon %||%
      (if (!is.null(con) && !is.null(zone_id))
         tryCatch(.get_zone_aoi(con, as.integer(zone_id)),
                  error = function(e) NULL)
       else NULL)
    if (is.null(poly)) {
      cli::cli_warn(c(
        "{.arg apply_zone_mask} is TRUE but no UGF polygon could be resolved.",
        i = "Provide {.arg mask_polygon}, or both {.arg con} and {.arg zone_id}.",
        i = "Returning the unmasked raster (bbox + OSO broadleaf extent)."
      ))
    }
    out <- .apply_zone_mask(out, poly)
  }
  out
}
