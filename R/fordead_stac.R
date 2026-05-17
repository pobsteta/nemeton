#' STAC assembly + FordeadConfig helpers (spec 008 §12, v0.23.0)
#'
#' @description
#' Internal helpers used by [run_fordead_dieback()] to bridge the
#' nemeton STAC COG cache (produced by [ingest_sentinel2_timeseries()])
#' and the fordead 2.x pipeline (`fordead.workflow.FordeadProcess`).
#'
#' Three responsibilities, three helpers :
#'
#' * [.aoi_bbox_4326()] — extract a 4-numeric WGS-84 bbox from an `sf`
#'   AOI (input to `FordeadProcess(bbox=...)`).
#' * [.aoi_geometry_reticulate()] — build a `shapely.geometry`
#'   Python object from the same AOI (input to
#'   `FordeadProcess(geometry=...)`, takes precedence over `bbox`
#'   when both are provided).
#' * [.build_fordead_config()] — construct a `fordead.config.FordeadConfig`
#'   Python object overriding the four R-exposed knobs
#'   (`dates_training`, `dates_monitoring`, `vegetation_index`,
#'   `threshold_anomaly`). Everything else stays at the fordead 2.x
#'   defaults — which, per ADR-013 A1 §12.6, match exactly the
#'   ONF/DSF calibration (CRSWIR, 0.16, 3 anomalies, 2-year training).
#' * [.build_stac_collection_for_aoi()] — walk a `scenes_df` (the
#'   same shape consumed by [read_s2_band_stack()] / spec 010) and
#'   build a `simplestac.ItemCollection` of one `pystac.Item` per
#'   scene, with band assets pointing at local cache COGs.
#'
#' None of these helpers initialise Python at module load time —
#' [reticulate::import()] is called lazily inside each helper, so
#' devtools::load_all() / R CMD check do not require fordead to be
#' available.
#'
#' @name fordead_stac
#' @keywords internal
NULL


#' WGS-84 bbox of an AOI, length-4 numeric
#'
#' @param aoi An `sf` or `sfc` object in any CRS. Is transformed to
#'   EPSG:4326 internally.
#' @return `numeric(4)` in `(xmin, ymin, xmax, ymax)` order.
#' @keywords internal
.aoi_bbox_4326 <- function(aoi) {
  if (!inherits(aoi, c("sf", "sfc"))) {
    cli::cli_abort("{.arg aoi} must be an {.cls sf} or {.cls sfc} object.")
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} is required.")
  }
  aoi_4326 <- sf::st_transform(aoi, 4326)
  bb <- sf::st_bbox(aoi_4326)
  unname(as.numeric(bb[c("xmin", "ymin", "xmax", "ymax")]))
}


#' Build a `shapely.geometry` from an `sf` AOI via WKT round-trip
#'
#' `shapely.wkt.loads()` parses the WKT serialisation of an `sf`
#' geometry — robust across sf, GEOS and Shapely versions. The
#' returned object is suitable for `FordeadProcess(geometry=...)`.
#'
#' @param aoi An `sf` or `sfc` object. Reprojected to EPSG:4326.
#' @return A Python `shapely.geometry.base.BaseGeometry`.
#' @keywords internal
.aoi_geometry_reticulate <- function(aoi) {
  if (!inherits(aoi, c("sf", "sfc"))) {
    cli::cli_abort("{.arg aoi} must be an {.cls sf} or {.cls sfc} object.")
  }
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg reticulate} is required.")
  }
  aoi_4326 <- sf::st_transform(aoi, 4326)
  geom <- sf::st_geometry(aoi_4326)
  # Union multi-feature AOIs so we hand fordead a single polygon
  # (it accepts MultiPolygon too, but the union avoids ambiguity).
  if (length(geom) > 1L) {
    geom <- sf::st_union(geom)
  }
  wkt_str <- sf::st_as_text(geom)
  shapely_wkt <- reticulate::import("shapely.wkt", convert = FALSE)
  shapely_wkt$loads(wkt_str)
}


#' GeoJSON representation of an AOI, R list (used for `pystac.Item.geometry`)
#'
#' `pystac.Item.geometry` accepts a GeoJSON dict. `sf::st_as_text()` +
#' `geojsonio::geojson_json()` would work but pulls a heavy dep. We
#' build the dict by hand via `sf::st_geometry()` -> coordinates.
#'
#' @param aoi An `sf` or `sfc` object. Reprojected to EPSG:4326.
#' @return A nested R list `list(type=..., coordinates=...)` ready for
#'   `reticulate::r_to_py()` -> Python dict.
#' @keywords internal
.aoi_geojson_list <- function(aoi) {
  if (!inherits(aoi, c("sf", "sfc"))) {
    cli::cli_abort("{.arg aoi} must be an {.cls sf} or {.cls sfc} object.")
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg jsonlite} is required to serialise AOI geometry.")
  }
  aoi_4326 <- sf::st_transform(aoi, 4326)
  geom <- sf::st_geometry(aoi_4326)
  if (length(geom) > 1L) geom <- sf::st_union(geom)
  # sf's GDAL-backed GeoJSON writer is the most robust path across
  # POLYGON / MULTIPOLYGON / GEOMETRYCOLLECTION inputs. Round-trip
  # to disk + parse JSON, return the geometry of the first feature
  # as a list ready for reticulate::r_to_py() -> Python dict.
  sf_obj <- sf::st_sf(geometry = geom)
  tmp <- tempfile(fileext = ".geojson")
  on.exit(unlink(tmp), add = TRUE)
  suppressMessages(
    sf::st_write(sf_obj, tmp, quiet = TRUE, delete_dsn = TRUE)
  )
  fc <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
  fc$features[[1L]]$geometry
}


#' Build a `fordead.config.FordeadConfig` from R-exposed parameters
#'
#' Overrides only the four fields exposed in [run_fordead_dieback()]
#' (`dates_training`, `dates_monitoring`, `vegetation_index`,
#' `threshold_anomaly`). The remaining fields keep their fordead 2.x
#' defaults, which match ADR-013 §G5 calibration (CRSWIR formula,
#' threshold 0.16 wired by default, 3 consecutive anomalies, definitive
#' stop, count type "v2").
#'
#' @param dates_training Character(2) — start and end of the
#'   training period (ISO yyyy-mm-dd).
#' @param dates_monitoring Character(2) — start and end of the
#'   monitoring period. The end may be `NA_character_` to mean "open".
#' @param vegetation_index Character(1). Default `"CRSWIR"`.
#' @param threshold_anomaly Numeric(1) > 0. Default `0.16`.
#'
#' @return A Python `FordeadConfig` object.
#' @keywords internal
.build_fordead_config <- function(dates_training,
                                  dates_monitoring,
                                  vegetation_index  = "CRSWIR",
                                  threshold_anomaly = 0.16) {
  .check_dates_pair(dates_training,   "dates_training",   allow_open_end = FALSE)
  .check_dates_pair(dates_monitoring, "dates_monitoring", allow_open_end = TRUE)
  if (!is.character(vegetation_index) || length(vegetation_index) != 1L ||
      !nzchar(vegetation_index)) {
    cli::cli_abort("{.arg vegetation_index} must be a single non-empty string.")
  }
  if (!is.numeric(threshold_anomaly) || length(threshold_anomaly) != 1L ||
      is.na(threshold_anomaly) || threshold_anomaly <= 0) {
    cli::cli_abort("{.arg threshold_anomaly} must be a positive scalar.")
  }
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg reticulate} is required.")
  }

  cfg_mod <- reticulate::import("fordead.config", convert = FALSE)

  predict_end <- if (is.na(dates_monitoring[2L])) NULL else dates_monitoring[2L]

  cfg_mod$FordeadConfig(
    spectral_index = cfg_mod$SpectralIndexConfig(name = vegetation_index),
    fit = cfg_mod$FitConfig(
      start = dates_training[1L],
      end   = dates_training[2L]
    ),
    predict = cfg_mod$PredictConfig(
      start     = dates_monitoring[1L],
      end       = predict_end,
      threshold = threshold_anomaly
    )
  )
}


#' Build a `simplestac.ItemCollection` from a scenes_df + local COG cache
#'
#' Walks `scenes_df`, locates `<cache_dir>/<safe_scene_id>/<band>.tif`
#' for each scene/band pair, and constructs one `pystac.Item` per
#' scene whose bands are all present on disk. Scenes with one or more
#' missing bands are skipped with a warning (aggregated, one
#' `cli::cli_warn` at the end). The items are wrapped in a
#' `simplestac.ItemCollection`.
#'
#' Why local COG paths and not the remote PC/CDSE hrefs:
#'
#' * Local paths don't expire — long `fit()` / `predict()` runs are
#'   safe against PC SAS token expiry (cf. v0.22.1).
#' * Re-running FORDEAD on the same AOI is fast (no network).
#' * The cache is already extent-aware (cf. v0.21.4 / v0.21.8), so we
#'   know each `<band>.tif` covers at least the AOI.
#'
#' @param aoi An `sf` or `sfc` object — used for `Item.geometry`,
#'   `Item.bbox`, and as a per-item property. Reprojected to EPSG:4326.
#' @param scenes_df A `data.frame` (or tibble) with at minimum the
#'   columns `scene_id` (character) and `obs_date` (Date or coercible).
#'   Duplicate `scene_id` rows are silently de-duplicated.
#' @param cache_dir Character(1). Root directory of the COG cache,
#'   typically `<project>/cache/layers/sentinel2`.
#' @param bands_required Character vector of band codes required by
#'   FORDEAD. Default `c("B02", "B04", "B05", "B8A", "B11", "B12")`
#'   covers CRSWIR + cloud / shadow / soil masks.
#'
#' @return A Python `simplestac.utils.ItemCollection` object. The
#'   number of items equals the number of scenes whose bands are
#'   all present.
#' @keywords internal
.build_stac_collection_for_aoi <- function(aoi,
                                           scenes_df,
                                           cache_dir,
                                           bands_required = c("B02", "B04", "B05",
                                                              "B8A", "B11", "B12")) {
  if (!is.data.frame(scenes_df) ||
      !all(c("scene_id", "obs_date") %in% names(scenes_df))) {
    cli::cli_abort(c(
      "{.arg scenes_df} must be a data.frame with columns ",
      "{.field scene_id} and {.field obs_date}."
    ))
  }
  if (!is.character(cache_dir) || length(cache_dir) != 1L || !dir.exists(cache_dir)) {
    cli::cli_abort("{.arg cache_dir} must be an existing directory.")
  }
  if (!is.character(bands_required) || length(bands_required) == 0L) {
    cli::cli_abort("{.arg bands_required} must be a non-empty character vector.")
  }
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg reticulate} is required.")
  }

  scenes_df$obs_date <- as.Date(scenes_df$obs_date)
  scenes_df <- scenes_df[!is.na(scenes_df$obs_date) &
                           !is.na(scenes_df$scene_id), , drop = FALSE]
  scenes_df <- scenes_df[!duplicated(scenes_df$scene_id), , drop = FALSE]
  scenes_df <- scenes_df[order(scenes_df$obs_date), , drop = FALSE]

  if (nrow(scenes_df) == 0L) {
    cli::cli_abort("{.arg scenes_df} is empty after de-duplication / NA filter.")
  }

  bbox_4326   <- .aoi_bbox_4326(aoi)
  geometry_gj <- .aoi_geojson_list(aoi)

  pystac     <- reticulate::import("pystac",     convert = FALSE)
  # simplestac 1.2.5 doesn't re-export ItemCollection at the package
  # top level — the class lives in `simplestac.utils`. Importing the
  # submodule directly avoids `simplestac$ItemCollection` AttributeError
  # at runtime (observed against v1.2.5 in 2026-05-17).
  simplestac <- reticulate::import("simplestac.utils", convert = FALSE)
  pydt       <- reticulate::import("datetime",   convert = FALSE)

  items   <- list()
  skipped <- character(0)

  for (i in seq_len(nrow(scenes_df))) {
    sid <- as.character(scenes_df$scene_id[i])
    dt  <- scenes_df$obs_date[i]
    safe_sid  <- .s2_safe_scene_id(sid)
    scene_dir <- file.path(cache_dir, safe_sid)

    band_paths <- file.path(scene_dir, paste0(bands_required, ".tif"))
    missing    <- !file.exists(band_paths)
    if (any(missing)) {
      skipped <- c(skipped, sprintf("%s (missing: %s)",
                                    sid,
                                    paste(bands_required[missing], collapse = ",")))
      next
    }

    iso_dt <- pydt$datetime$fromisoformat(
      paste0(format(dt, "%Y-%m-%d"), "T00:00:00+00:00")
    )
    item <- pystac$Item(
      id         = sprintf("fordead_%s", format(dt, "%Y%m%d")),
      geometry   = reticulate::r_to_py(geometry_gj),
      bbox       = reticulate::r_to_py(as.list(bbox_4326)),
      datetime   = iso_dt,
      properties = reticulate::dict()
    )
    for (b_idx in seq_along(bands_required)) {
      b    <- bands_required[b_idx]
      href <- band_paths[b_idx]
      asset <- pystac$Asset(
        href       = href,
        roles      = list("data"),
        media_type = "image/tiff; application=geotiff; profile=cloud-optimized"
      )
      item$add_asset(b, asset)
    }
    items[[length(items) + 1L]] <- item
  }

  if (length(skipped) > 0L) {
    cli::cli_warn(c(
      "Skipped {length(skipped)}/{nrow(scenes_df)} scenes with missing bands:",
      "*" = "{skipped}"
    ))
  }
  if (length(items) == 0L) {
    cli::cli_abort(
      "No scene in {.arg scenes_df} had all required bands in {.path {cache_dir}}."
    )
  }

  simplestac$ItemCollection(items)
}


# ----------------------------------------------------------------------
# Argument validators
# ----------------------------------------------------------------------

# Check a length-2 character vector parses as ISO yyyy-mm-dd dates,
# with `start <= end`. `allow_open_end = TRUE` permits NA for the
# end (interpreted by fordead as "open / latest available").
.check_dates_pair <- function(x, arg_name, allow_open_end = FALSE) {
  if (!is.character(x) || length(x) != 2L) {
    cli::cli_abort("{.arg {arg_name}} must be a length-2 character vector.")
  }
  start <- suppressWarnings(as.Date(x[1L]))
  end   <- suppressWarnings(as.Date(x[2L]))
  if (is.na(start)) {
    cli::cli_abort("{.arg {arg_name}[1]} must parse as a date (ISO yyyy-mm-dd).")
  }
  if (is.na(end) && !isTRUE(allow_open_end)) {
    cli::cli_abort("{.arg {arg_name}[2]} must parse as a date (ISO yyyy-mm-dd).")
  }
  if (!is.na(end) && end < start) {
    cli::cli_abort("{.arg {arg_name}}: end {.val {x[2L]}} is before start {.val {x[1L]}}.")
  }
  invisible(TRUE)
}
