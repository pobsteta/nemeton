# Per-pixel Sentinel-2 visualization helpers (spec 010).
#
# Exposes the cropped Sentinel-2 bands cached on disk by
# `ingest_sentinel2_timeseries(..., cache_dir = ...)` as SpatRaster
# objects, plus index stacks (NDVI / NBR) and per-pixel time series
# extraction. The cache layout
# `<cache_dir>/{scene_id}/{B04,B08,B12}.tif` is owned by R/monitoring.R
# (`.s2_band_cache_path`) — both sides resolve the path through the
# shared private helper `.s2_safe_scene_id()` to guarantee write/read
# agreement.
#
# All functions are read-only (no HTTP, no DB write). Missing scenes
# are tolerated and reported via a single aggregated warning rather
# than per-scene errors — the goal is "useful map even with a
# partially populated cache" rather than "fail loud on first hole".

#' Read a single cached Sentinel-2 band as a SpatRaster
#'
#' Opens `<cache_dir>/<sanitized_scene_id>/<band>.tif` and returns the
#' corresponding [terra::SpatRaster] object. No HTTP. The file is
#' produced by [ingest_sentinel2_timeseries()] when called with a
#' non-NULL `cache_dir`.
#'
#' Returns `NULL` (not an error) when the file is absent — callers like
#' [read_s2_band_stack()] use this to skip missing scenes silently and
#' emit a single aggregated warning.
#'
#' @param cache_dir Character(1). Path to the S2 cache root, e.g.
#'   `<project>/cache/layers/sentinel2`.
#' @param scene_id Character(1). The Sentinel-2 scene id as returned
#'   by the STAC search and stored in `obs_pixel.scene_id`. The on-disk
#'   directory name is its sanitized form (cf.
#'   `nemeton:::.s2_safe_scene_id`).
#' @param band Character(1). One of `"B04"` (Red, 10 m), `"B08"`
#'   (NIR, 10 m) or `"B12"` (SWIR, 20 m).
#'
#' @return A 1-layer [terra::SpatRaster] in the source CRS (typically
#'   EPSG:32631 or 32632 — UTM zones over France), or `NULL` if the
#'   file is missing. The raster is **not** reprojected — leaflet /
#'   leafem handles that downstream.
#'
#' @examples
#' \dontrun{
#'   cache <- "/home/user/projects/myforest/cache/layers/sentinel2"
#'   r <- read_s2_band_raster(cache,
#'                            "S2A_MSIL2A_20260508T103651_R008_T31TFN_20260508T191011",
#'                            "B04")
#'   terra::plot(r)
#' }
#'
#' @seealso [read_s2_band_stack()] for multi-temporal stacks,
#'   [build_index_stack()] for NDVI / NBR, [extract_pixel_timeseries()]
#'   for per-pixel time series, [diagnose_s2_cache()] to inspect what's
#'   on disk, [ingest_sentinel2_timeseries()] for the write path.
#' @export
read_s2_band_raster <- function(cache_dir, scene_id, band) {
  if (!is.character(cache_dir) || length(cache_dir) != 1L ||
      is.na(cache_dir) || !nzchar(cache_dir)) {
    stop("`cache_dir` must be a single non-empty character path.",
         call. = FALSE)
  }
  if (!is.character(scene_id) || length(scene_id) != 1L ||
      is.na(scene_id) || !nzchar(scene_id)) {
    stop("`scene_id` must be a single non-empty character.",
         call. = FALSE)
  }
  band <- match.arg(band, c("B04", "B08", "B12"))

  path <- file.path(cache_dir, .s2_safe_scene_id(scene_id),
                    paste0(band, ".tif"))
  if (!file.exists(path)) return(NULL)
  terra::rast(path)
}

#' Read a multi-temporal stack for one Sentinel-2 band
#'
#' Stacks the cached `<band>.tif` files of several scenes into a
#' single [terra::SpatRaster] with one layer per observation date.
#' Layers are named by `as.character(obs_date)` and the corresponding
#' [terra::time()] attribute is set, so callers can index by date.
#'
#' Missing scenes (no `<band>.tif` on disk) are skipped silently and
#' reported via a **single aggregated warning** — never one warning
#' per missing scene. Returns `NULL` if every scene is missing.
#'
#' @param cache_dir Character(1). Same as [read_s2_band_raster()].
#' @param scenes_df A `data.frame` with at minimum columns
#'   `scene_id` (character) and `obs_date` (Date, or coercible). Extra
#'   columns are ignored. Rows are re-ordered by `obs_date` internally.
#'   In practice this is what the app gets from
#'   `SELECT DISTINCT scene_id, obs_date FROM obs_pixel JOIN plot ...`.
#' @param band Character(1). One of `"B04"`, `"B08"`, `"B12"`.
#'
#' @return A multi-layer [terra::SpatRaster] in source CRS, with
#'   `names(out)` = `as.character(obs_date)` and `terra::time(out)`
#'   set to the dates of the surviving scenes. `NULL` when no scene
#'   could be opened.
#'
#' @examples
#' \dontrun{
#'   cache <- "/proj/cache/layers/sentinel2"
#'   scenes <- read_obs_pixel(con, zone_id = 1L)
#'   scenes <- unique(scenes[, c("scene_id", "obs_date")])
#'   stack  <- read_s2_band_stack(cache, scenes, "B04")
#'   terra::time(stack)        # the dates as a vector
#'   terra::plot(stack[[1]])   # first scene
#' }
#'
#' @seealso [read_s2_band_raster()], [build_index_stack()] for
#'   computed NDVI / NBR layers, [extract_pixel_timeseries()].
#' @export
read_s2_band_stack <- function(cache_dir, scenes_df, band) {
  .validate_scenes_df(scenes_df)
  band <- match.arg(band, c("B04", "B08", "B12"))

  scenes_df <- scenes_df[order(as.Date(scenes_df$obs_date)), , drop = FALSE]

  rasters <- lapply(seq_len(nrow(scenes_df)), function(i) {
    read_s2_band_raster(cache_dir, scenes_df$scene_id[i], band)
  })
  ok <- !vapply(rasters, is.null, logical(1))
  n_total   <- nrow(scenes_df)
  n_missing <- sum(!ok)

  if (n_missing > 0L) {
    cli::cli_warn(c(
      "Skipped {n_missing}/{n_total} scene{?s} (no cached {.field {band}}).",
      i = "Run {.fn ingest_sentinel2_timeseries} with the same {.code cache_dir} to refill."
    ))
  }
  if (!any(ok)) return(NULL)

  out <- terra::rast(rasters[ok])
  names(out)       <- as.character(scenes_df$obs_date[ok])
  terra::time(out) <- as.Date(scenes_df$obs_date[ok])
  out
}

#' Build a multi-temporal NDVI or NBR stack from cached Sentinel-2 bands
#'
#' For each scene in `scenes_df`, opens the required cached bands and
#' computes the requested spectral index pixel-wise:
#'
#' * **NDVI** = (B08 − B04) / (B08 + B04) — proxy of vegetation vigour
#' * **NBR** = (B08 − B12) / (B08 + B12) — proxy of vegetation /
#'   burned-area discrimination. B12 is natively 20 m, so it is
#'   resampled to the B08 10 m grid via [terra::resample()] with
#'   `method = "bilinear"` — same idiom as the per-plot ingestion path
#'   in `.extract_scene_obs()`.
#'
#' Scenes with incomplete cached bands (missing B04, B08, or — for NBR
#' — B12) are skipped silently with a single aggregated warning. NAs
#' propagate naturally through the arithmetic: a NA in any source
#' pixel yields NA in the index.
#'
#' @param cache_dir Character(1). Path to the S2 cache root.
#' @param scenes_df See [read_s2_band_stack()].
#' @param index Character(1). One of `"NDVI"` (default) or `"NBR"`.
#'
#' @return A multi-layer [terra::SpatRaster] in source CRS at 10 m,
#'   values in `[-1, 1]` (NAs preserved), layers named by `obs_date`
#'   with `terra::time()` set, and an `"index"` attribute carrying
#'   the chosen index name. `NULL` if no scene survives.
#'
#' @section Why arithmetic alone is enough:
#' Sentinel-2 L2A reflectances are non-negative, so `(a − b) / (a + b)`
#' stays in `[-1, 1]` mathematically. No `clamp()` needed.
#'
#' @section Note on B12 resampling:
#' `extract_pixel_timeseries()` deliberately does **not** resample B12
#' — for a single-point extraction the natively 20 m pixel containing
#' the click is what the user wants. So `build_index_stack()` at
#' point `(x, y)` may differ from `extract_pixel_timeseries()` at the
#' same `(x, y)` by a sub-pixel amount when `index = "NBR"`. This is
#' documented and intentional.
#'
#' @examples
#' \dontrun{
#'   cache <- "/proj/cache/layers/sentinel2"
#'   scenes <- unique(read_obs_pixel(con, 1L)[, c("scene_id", "obs_date")])
#'   ndvi_stack <- build_index_stack(cache, scenes, "NDVI")
#'   terra::plot(ndvi_stack[[1]])
#' }
#'
#' @seealso [read_s2_band_stack()], [extract_pixel_timeseries()].
#' @export
build_index_stack <- function(cache_dir, scenes_df,
                              index = c("NDVI", "NBR")) {
  index <- match.arg(index)
  .validate_scenes_df(scenes_df)

  bands_needed <- switch(index,
    NDVI = c("B04", "B08"),
    NBR  = c("B08", "B12")
  )

  scenes_df <- scenes_df[order(as.Date(scenes_df$obs_date)), , drop = FALSE]

  layers <- lapply(seq_len(nrow(scenes_df)), function(i) {
    sid <- scenes_df$scene_id[i]
    rs  <- stats::setNames(
      lapply(bands_needed, function(b) read_s2_band_raster(cache_dir, sid, b)),
      bands_needed
    )
    if (any(vapply(rs, is.null, logical(1)))) return(NULL)

    if (index == "NDVI") {
      (rs$B08 - rs$B04) / (rs$B08 + rs$B04)
    } else {
      # B12 at 20 m onto B08's 10 m grid. method = "bilinear" matches
      # `.extract_scene_obs` in R/monitoring.R so per-pixel NBR is
      # numerically consistent with per-plot NBR aggregates.
      b12_10m <- terra::resample(rs$B12, rs$B08, method = "bilinear")
      (rs$B08 - b12_10m) / (rs$B08 + b12_10m)
    }
  })

  ok <- !vapply(layers, is.null, logical(1))
  n_total   <- nrow(scenes_df)
  n_missing <- sum(!ok)

  if (n_missing > 0L) {
    cli::cli_warn(c(
      "Skipped {n_missing}/{n_total} scene{?s} (incomplete cache for {.field {index}}).",
      i = "Run {.fn diagnose_s2_cache} to find the gaps."
    ))
  }
  if (!any(ok)) return(NULL)

  valid_layers <- layers[ok]

  # spec 013 / v0.47.5 — align all per-scene layers to the smallest
  # common extent before stacking. Cached files for the same band
  # written by separate app sessions (e.g. across a zone
  # re-registration) can have sub-pixel-to-many-pixel extent drift,
  # which makes `terra::rast(layers)` fail with
  # `[rast] extents do not match`. We crop every layer to the
  # intersection of all extents — slightly less spatial coverage,
  # but a coherent stack that downstream consumers
  # (`read_fast_alert_raster`, etc.) can build on.
  common_ext <- terra::ext(valid_layers[[1L]])
  if (length(valid_layers) > 1L) {
    for (lyr in valid_layers[-1L]) {
      common_ext <- terra::intersect(common_ext, terra::ext(lyr))
      if (is.null(common_ext)) break
    }
  }
  if (is.null(common_ext)) {
    cli::cli_warn(c(
      "build_index_stack: per-scene cached extents have no common
       overlap; cannot stack.",
      i = "Run {.fn diagnose_s2_cache} and consider purging the cache to
           force a coherent rewrite."
    ))
    return(NULL)
  }
  needs_align <- !all(vapply(valid_layers, function(l) {
    e <- terra::ext(l)
    isTRUE(all.equal(c(terra::xmin(e), terra::xmax(e),
                       terra::ymin(e), terra::ymax(e)),
                     c(terra::xmin(common_ext), terra::xmax(common_ext),
                       terra::ymin(common_ext), terra::ymax(common_ext)),
                     tolerance = 1e-6))
  }, logical(1)))
  if (needs_align) {
    valid_layers <- lapply(valid_layers,
                           function(l) terra::crop(l, common_ext, snap = "in"))
  }

  out <- terra::rast(valid_layers)
  names(out)       <- as.character(scenes_df$obs_date[ok])
  terra::time(out) <- as.Date(scenes_df$obs_date[ok])
  attr(out, "index") <- index
  out
}

#' Extract a per-pixel NDVI / NBR time series at one geographic point
#'
#' Reads, for each scene in `scenes_df`, the cached source bands needed
#' for the requested indices and returns the value of the pixel
#' containing the point `xy`. The point is transformed from its input
#' CRS (`crs`, default WGS84 = EPSG:4326 — the convention used by
#' leaflet `input$map_click`) to each scene's source CRS internally.
#'
#' Behaviour at the boundaries:
#'
#' * **Scene with incomplete cache** (e.g. B08 missing) → the row for
#'   that `obs_date` is present in the output with `value = NA`. The
#'   missing-scene case is **not** skipped silently here — the user
#'   wants to see the temporal hole on the plotly, not have it
#'   disappear.
#' * **Point outside the raster footprint** → `value = NA` for every
#'   date / index.
#' * **NA pixel** (cloud mask, no data) → `value = NA` for that date.
#'
#' For NBR, B12 is sampled at its native 20 m resolution (no resample).
#' This intentionally differs from [build_index_stack()] where B12 is
#' resampled bilinearly to the B08 10 m grid — see the *Note on B12
#' resampling* section there. Net effect: NBR at point `(x, y)` from
#' `extract_pixel_timeseries()` may differ from the same point read
#' off `build_index_stack()` by a sub-pixel amount.
#'
#' @param cache_dir Character(1). Path to the S2 cache root.
#' @param scenes_df See [read_s2_band_stack()].
#' @param xy Numeric(2). Coordinates `c(x, y)` of the point of interest
#'   in the CRS specified by `crs`.
#' @param crs Coordinate reference system of `xy`. Accepts anything
#'   [sf::st_crs()] understands: an EPSG integer (default `4326`), a
#'   PROJ string, a WKT. The transformation to each scene's source CRS
#'   happens internally on a per-scene basis.
#' @param indices Character. A non-empty subset of `c("NDVI", "NBR")`.
#'   Default: both.
#'
#' @return A `data.frame` with columns `obs_date` (Date), `index`
#'   (character) and `value` (numeric, possibly NA), sorted by
#'   `(obs_date, index)`. `nrow` = `nrow(scenes_df) * length(indices)`.
#'
#' @examples
#' \dontrun{
#'   cache <- "/proj/cache/layers/sentinel2"
#'   scenes <- unique(read_obs_pixel(con, 1L)[, c("scene_id", "obs_date")])
#'   # A point clicked on the leaflet map at (lng, lat) = (5.0, 47.5)
#'   ts <- extract_pixel_timeseries(cache, scenes, c(5.0, 47.5))
#'   library(ggplot2)
#'   ggplot(ts, aes(obs_date, value, colour = index)) + geom_line()
#' }
#'
#' @seealso [build_index_stack()], [read_s2_band_stack()],
#'   [read_obs_pixel()] for the per-plot equivalent already aggregated
#'   in the DB.
#' @export
extract_pixel_timeseries <- function(cache_dir, scenes_df, xy,
                                     crs = 4326,
                                     indices = c("NDVI", "NBR")) {
  .validate_scenes_df(scenes_df)
  if (!is.numeric(xy) || length(xy) != 2L || anyNA(xy)) {
    stop("`xy` must be a length-2 numeric, no NA.", call. = FALSE)
  }
  indices <- match.arg(indices, c("NDVI", "NBR"), several.ok = TRUE)

  scenes_df <- scenes_df[order(as.Date(scenes_df$obs_date)), , drop = FALSE]

  # Build the point sf once, reproject per-scene to the raster's CRS.
  pt_in <- sf::st_sfc(sf::st_point(xy), crs = crs)

  # Bands the union of indices needs.
  bands_needed <- unique(unlist(lapply(indices, function(idx) {
    if (idx == "NDVI") c("B04", "B08") else c("B08", "B12")
  })))

  na_row <- function(date_i) {
    data.frame(
      obs_date = rep(date_i, length(indices)),
      index    = indices,
      value    = NA_real_,
      stringsAsFactors = FALSE
    )
  }

  rows <- lapply(seq_len(nrow(scenes_df)), function(i) {
    sid     <- scenes_df$scene_id[i]
    date_i  <- as.Date(scenes_df$obs_date[i])

    rs <- stats::setNames(
      lapply(bands_needed, function(b) read_s2_band_raster(cache_dir, sid, b)),
      bands_needed
    )
    if (any(vapply(rs, is.null, logical(1)))) {
      return(na_row(date_i))
    }

    # Use the CRS of B08 as the canonical native CRS. All S2 bands of
    # the same scene share the same CRS (different resolutions but
    # same tile projection), so picking any is equivalent.
    pt_native <- sf::st_transform(pt_in, terra::crs(rs[["B08"]]))
    pt_vect   <- terra::vect(pt_native)

    vals <- vapply(indices, function(idx) {
      if (idx == "NDVI") {
        b04 <- terra::extract(rs$B04, pt_vect)[1L, 2L]
        b08 <- terra::extract(rs$B08, pt_vect)[1L, 2L]
        if (is.na(b04) || is.na(b08) || (b04 + b08) == 0) return(NA_real_)
        (b08 - b04) / (b08 + b04)
      } else { # NBR
        b08 <- terra::extract(rs$B08, pt_vect)[1L, 2L]
        # Native 20 m B12 — no resample for a single-point extraction.
        b12 <- terra::extract(rs$B12, pt_vect)[1L, 2L]
        if (is.na(b08) || is.na(b12) || (b08 + b12) == 0) return(NA_real_)
        (b08 - b12) / (b08 + b12)
      }
    }, numeric(1L))

    data.frame(
      obs_date = rep(date_i, length(indices)),
      index    = indices,
      value    = as.numeric(vals),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out[order(out$obs_date, out$index), , drop = FALSE]
}

# Internal: validate the `scenes_df` argument shared by read_s2_band_stack(),
# build_index_stack(), and extract_pixel_timeseries(). Stops on first failure
# rather than collecting — these are programmer-side mistakes, fail fast.
.validate_scenes_df <- function(scenes_df) {
  if (!is.data.frame(scenes_df)) {
    stop("`scenes_df` must be a data.frame.", call. = FALSE)
  }
  missing_cols <- setdiff(c("scene_id", "obs_date"), names(scenes_df))
  if (length(missing_cols) > 0L) {
    stop(sprintf("`scenes_df` is missing column(s): %s.",
                 paste(missing_cols, collapse = ", ")),
         call. = FALSE)
  }
  if (!nrow(scenes_df)) {
    stop("`scenes_df` is empty (0 rows).", call. = FALSE)
  }
  if (anyNA(scenes_df$scene_id) || anyNA(scenes_df$obs_date)) {
    stop("`scenes_df` contains NA in `scene_id` or `obs_date`.",
         call. = FALSE)
  }
  invisible(scenes_df)
}
