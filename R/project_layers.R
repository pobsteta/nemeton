#' Discover the best available DEM / CHM raster in a Nemeton project
#'
#' @description
#' Néméton projects accumulate digital terrain models (MNT / DEM /
#' DTM) and canopy height models (MNH / CHM) from several sources —
#' IGN RGE ALTI downloaded by tutorials, LiDAR HD MNT produced by
#' `lidR`, `opencanopynemeton`'s `dtm.tif`, Open-Canopy CHM tiles —
#' each landing under its own naming convention. These helpers walk
#' a list of well-known locations in **priority order** (highest
#' quality first) and return the first match, so callers don't have
#' to hard-code paths.
#'
#' When multiple tiles sit in the same directory (e.g. several
#' `BD ALTI` tiles), the raster returned is a virtual mosaic
#' (`terra::vrt()`), so downstream `terra::extract` / `terra::crop`
#' calls transparently cover the full footprint.
#'
#' @section Search order (DEM):
#' \enumerate{
#'   \item `<project>/cache/layers/lidar_mnt/*.tif`  — LiDAR HD (1 m)
#'   \item `<project>/cache/layers/dem/*.tif`        — generic DEM cache
#'   \item `<project>/cache/layers/bd_alti/*.tif`    — IGN BD ALTI (25 m)
#'   \item `<project>/cache/layers/rge_alti/*.tif`   — IGN RGE ALTI (5 m)
#'   \item `<project>/cache/layers/dtm/*.tif`        — generic DTM cache
#'   \item `<project>/cache/layers/mnt/*.tif`        — generic MNT cache
#'   \item `<project>/dtm.tif`                        — `opencanopynemeton` convention
#'   \item `<project>/mnt.tif`                        — tutorial convention
#'   \item `<project>/data/dtm.tif`                   — alt project layout
#'   \item `<project>/data/mnt.tif`                   — alt project layout
#' }
#'
#' @section Search order (CHM):
#' \enumerate{
#'   \item `<project>/cache/layers/chm/*.tif`        — Open-Canopy
#'   \item `<project>/cache/layers/lidar_mnh/*.tif`  — LiDAR HD MNH
#'   \item `<project>/cache/layers/mnh/*.tif`        — generic MNH cache
#'   \item `<project>/chm.tif`                        — single-file convention
#'   \item `<project>/mnh.tif`                        — tutorial convention
#'   \item `<project>/data/chm.tif`                   — alt project layout
#'   \item `<project>/data/mnh.tif`                   — alt project layout
#' }
#'
#' @param project_path Character. Root of the Nemeton project tree.
#' @param load Logical. When `TRUE` (default), open the raster via
#'   `terra::rast()` (or `terra::vrt()` for multi-tile dirs) and
#'   return the `SpatRaster`. When `FALSE`, return the matching
#'   path(s) as a character vector — useful for diagnostics and for
#'   callers that want to control how the raster is loaded.
#' @param verbose Logical. When `TRUE`, log every probed location
#'   via `cli::cli_alert_info()`. Default `FALSE`.
#'
#' @return When `load = TRUE`: a `SpatRaster`, or `NULL` if no
#'   matching raster exists. When `load = FALSE`: a character vector
#'   of file paths (length 1 for single-file matches, longer for
#'   tile directories), or `NULL`. The returned object also carries
#'   the matched layer label as attribute `"nemeton_dem_layer"` /
#'   `"nemeton_chm_layer"`.
#'
#' @name resolve_project_layers
NULL


# Probe one candidate location. Returns:
#   - NULL when nothing matches
#   - A character vector of file paths otherwise (length >= 1)
.probe_raster_candidate <- function(cand, verbose) {
  if (!dir.exists(cand$dir)) {
    if (verbose) {
      cli::cli_alert_info("Skip {.val {cand$label}}: directory does not exist.")
    }
    return(NULL)
  }
  hits <- if (!is.null(cand$file)) {
    list.files(cand$dir,
               pattern     = sprintf("^%s$", cand$file),
               full.names  = TRUE,
               ignore.case = TRUE)
  } else {
    list.files(cand$dir,
               pattern     = "\\.tif$",
               full.names  = TRUE,
               ignore.case = TRUE,
               recursive   = isTRUE(cand$recursive))
  }
  if (!length(hits)) {
    if (verbose) {
      cli::cli_alert_info("Skip {.val {cand$label}}: no matching file in {.path {cand$dir}}.")
    }
    return(NULL)
  }
  if (verbose) {
    cli::cli_alert_success(
      "Found {.val {cand$label}}: {length(hits)} file{?s} at {.path {cand$dir}}."
    )
  }
  hits
}


.materialise_raster <- function(paths, load, layer_label, attr_name) {
  if (!load) {
    attr(paths, attr_name) <- layer_label
    return(paths)
  }
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required to load the resolved raster.")
  }
  r <- if (length(paths) == 1L) {
    terra::rast(paths)
  } else {
    # Virtual mosaic — zero-copy, all downstream terra ops work.
    terra::vrt(paths)
  }
  attr(r, attr_name) <- layer_label
  r
}


.validate_project_path <- function(project_path) {
  if (!is.character(project_path) || length(project_path) != 1L ||
      !nzchar(project_path)) {
    cli::cli_abort("{.arg project_path} must be a single non-empty path.")
  }
  if (!dir.exists(project_path)) {
    cli::cli_abort("{.arg project_path} does not exist: {.path {project_path}}")
  }
  invisible(project_path)
}


#' @rdname resolve_project_layers
#' @examples
#' \dontrun{
#' dem <- resolve_project_dem("C:/.../projects/20260416_112240_gomv",
#'                            verbose = TRUE)
#' if (is.null(dem)) {
#'   stop("No DEM found — download one with opencanopynemeton or happign.")
#' }
#' attr(dem, "nemeton_dem_layer")  # "opencanopy DTM"
#' plan <- create_sampling_plan(zone, mnt = dem, ...)
#' }
#' @export
resolve_project_dem <- function(project_path, load = TRUE, verbose = FALSE) {
  .validate_project_path(project_path)

  candidates <- list(
    list(label = "LiDAR HD MNT",
         dir   = file.path(project_path, "cache", "layers", "lidar_mnt")),
    list(label = "generic DEM cache",
         dir   = file.path(project_path, "cache", "layers", "dem")),
    list(label = "IGN BD ALTI",
         dir   = file.path(project_path, "cache", "layers", "bd_alti")),
    list(label = "IGN RGE ALTI",
         dir   = file.path(project_path, "cache", "layers", "rge_alti")),
    list(label = "generic DTM cache",
         dir   = file.path(project_path, "cache", "layers", "dtm")),
    list(label = "generic MNT cache",
         dir   = file.path(project_path, "cache", "layers", "mnt")),
    list(label = "opencanopy DTM",
         dir   = project_path,
         file  = "dtm.tif"),
    list(label = "tutorial MNT",
         dir   = project_path,
         file  = "mnt.tif"),
    list(label = "data/dtm.tif",
         dir   = file.path(project_path, "data"),
         file  = "dtm.tif"),
    list(label = "data/mnt.tif",
         dir   = file.path(project_path, "data"),
         file  = "mnt.tif")
  )

  for (cand in candidates) {
    hits <- .probe_raster_candidate(cand, verbose = verbose)
    if (!is.null(hits)) {
      return(.materialise_raster(hits, load, cand$label,
                                 attr_name = "nemeton_dem_layer"))
    }
  }
  if (verbose) {
    cli::cli_alert_warning("No DEM found anywhere under {.path {project_path}}.")
  }
  NULL
}


#' @rdname resolve_project_layers
#' @examples
#' \dontrun{
#' chm <- resolve_project_chm("C:/.../projects/20260416_112240_gomv")
#' plan <- create_sampling_plan(zone, mnt = dem, chm = chm, ...)
#' }
#' @export
resolve_project_chm <- function(project_path, load = TRUE, verbose = FALSE) {
  .validate_project_path(project_path)

  candidates <- list(
    list(label = "Open-Canopy CHM",
         dir   = file.path(project_path, "cache", "layers", "chm")),
    list(label = "LiDAR HD MNH",
         dir   = file.path(project_path, "cache", "layers", "lidar_mnh")),
    list(label = "generic MNH cache",
         dir   = file.path(project_path, "cache", "layers", "mnh")),
    list(label = "single-file CHM",
         dir   = project_path,
         file  = "chm.tif"),
    list(label = "tutorial MNH",
         dir   = project_path,
         file  = "mnh.tif"),
    list(label = "data/chm.tif",
         dir   = file.path(project_path, "data"),
         file  = "chm.tif"),
    list(label = "data/mnh.tif",
         dir   = file.path(project_path, "data"),
         file  = "mnh.tif")
  )

  for (cand in candidates) {
    hits <- .probe_raster_candidate(cand, verbose = verbose)
    if (!is.null(hits)) {
      return(.materialise_raster(hits, load, cand$label,
                                 attr_name = "nemeton_chm_layer"))
    }
  }
  if (verbose) {
    cli::cli_alert_warning("No CHM found anywhere under {.path {project_path}}.")
  }
  NULL
}
