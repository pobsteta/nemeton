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
