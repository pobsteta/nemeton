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

  # One descriptor per candidate raster layer (in display order). Each is
  # emitted only when its resolved path exists.
  raster_rows <- list(
    list(id = "score", label_key = "reconfort_couche_score",
         role = "score", path = pick(rasters$continuous_score, NULL),
         categorical = FALSE, palette = "RdYlGn", reverse = TRUE,
         vmin = 1, vmax = 100, default_visible = TRUE,
         default_opacity = 0.8),
    list(id = "classification", label_key = "reconfort_couche_classes",
         role = "classification",
         path = pick(rasters$classif_masked, rasters$classif),
         categorical = TRUE, palette = NA_character_, reverse = FALSE,
         vmin = NA_real_, vmax = NA_real_, default_visible = FALSE,
         default_opacity = 0.8),
    list(id = "probability", label_key = "reconfort_couche_proba",
         role = "probability",
         path = pick(rasters$probability_masked, rasters$probability),
         categorical = FALSE, palette = "viridis", reverse = FALSE,
         vmin = 0, vmax = 1000, default_visible = FALSE,
         default_opacity = 0.8)
  )

  rows <- list()
  for (r in raster_rows) {
    if (is.na(r$path)) next
    if (include_range && !r$categorical) {
      rng <- tryCatch({
        mm <- terra::minmax(terra::rast(r$path))
        if (all(is.finite(mm))) c(mm[1L], mm[2L]) else NULL
      }, error = function(e) NULL)
      if (!is.null(rng)) { r$vmin <- rng[1L]; r$vmax <- rng[2L] }
    }
    rows[[length(rows) + 1L]] <- data.frame(
      id = r$id, label_key = r$label_key, type = "raster", role = r$role,
      path = r$path, categorical = r$categorical, palette = r$palette,
      reverse = r$reverse, vmin = r$vmin, vmax = r$vmax,
      default_visible = r$default_visible,
      default_opacity = r$default_opacity, n_features = NA_integer_,
      stringsAsFactors = FALSE)
  }

  # Alert vector layer — present only when the run raised alerts. The
  # geometry lives in `result$alerts_sf` and the `alert` table, not on a
  # raster path.
  n_alerts <- .reconfort_alert_count(result)
  if (n_alerts > 0L) {
    rows[[length(rows) + 1L]] <- data.frame(
      id = "alerts", label_key = "reconfort_couche_alertes",
      type = "vector", role = "alerts", path = NA_character_,
      categorical = NA, palette = NA_character_, reverse = FALSE,
      vmin = NA_real_, vmax = NA_real_, default_visible = TRUE,
      default_opacity = 0.9, n_features = n_alerts,
      stringsAsFactors = FALSE)
  }

  if (!length(rows)) {
    return(data.frame(
      id = character(), label_key = character(), type = character(),
      role = character(), path = character(), categorical = logical(),
      palette = character(), reverse = logical(), vmin = numeric(),
      vmax = numeric(), default_visible = logical(),
      default_opacity = numeric(), n_features = integer(),
      stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
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
