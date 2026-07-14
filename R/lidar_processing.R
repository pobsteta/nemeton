#' Derive DTM and CHM rasters from IGN LiDAR HD point clouds
#'
#' @description
#' Fallback used when IGN's pre-rasterized MNT / MNH GeoTIFFs cannot
#' be downloaded (404 on derived products, bandwidth issues, dalles
#' produced but tiles not yet published) but the raw COPC point cloud
#' tiles **are** present under `cache/layers/lidar_nuage/`.
#'
#' Wraps a minimal [`lasR`](https://r-lidar.github.io/lasR/) pipeline:
#'
#' \enumerate{
#'   \item read all `.copc.laz` / `.laz` tiles in `laz_dir`,
#'   \item triangulate ground returns (class 2) into a TIN,
#'   \item rasterize the TIN to a DTM (1 m default),
#'   \item normalize the cloud by subtracting the TIN,
#'   \item rasterize the maximum normalized Z to a CHM.
#' }
#'
#' Outputs are written under the exact directory layout expected by
#' [`resolve_project_dem()`] / [`resolve_project_chm()`], so calling
#' code that already discovers MNT/MNH rasters via those helpers picks
#' the derived products up transparently.
#'
#' @param laz_dir Character. Directory containing the COPC tiles
#'   (typically `<project>/cache/layers/lidar_nuage`).
#' @param dtm_dir Character. Output directory for the DTM. Defaults to
#'   sibling `lidar_mnt/` of `laz_dir` (i.e. `<project>/cache/layers/lidar_mnt`).
#' @param chm_dir Character. Output directory for the CHM. Defaults to
#'   sibling `lidar_mnh/` of `laz_dir`.
#' @param res Numeric. Output raster resolution in metres. Default 1
#'   to match IGN LiDAR HD MNH / MNT native resolution.
#' @param aoi Optional `sf` / `sfc`. When supplied, the output rasters
#'   are cropped (and masked) to this AOI.
#' @param ncores Integer. Number of cores passed to `lasR::exec()`.
#'   Default 1 — set to `parallel::detectCores() - 1` for large blocks.
#' @param overwrite Logical. Re-derive even if `dtm.tif` / `chm.tif`
#'   already exist in the output directories. Default `FALSE`.
#' @param verbose Logical. When `TRUE`, log each stage via `cli`.
#'   Default `TRUE`.
#'
#' @return Invisibly, a list with:
#'   \describe{
#'     \item{dtm}{Path to the derived DTM (or `NULL` if not produced).}
#'     \item{chm}{Path to the derived CHM (or `NULL` if not produced).}
#'     \item{n_tiles}{Number of input `.laz` tiles processed.}
#'     \item{elapsed}{`difftime` of the lasR pipeline run.}
#'   }
#'   Returns `NULL` invisibly (with a `cli::cli_warn`) when no tiles
#'   are found or when `lasR` is not installed.
#'
#' @section Installation:
#' `lasR` is not on CRAN. Install it from r-universe:
#' ```r
#' install.packages("lasR", repos = "https://r-lidar.r-universe.dev")
#' ```
#'
#' @examples
#' \dontrun{
#' # Standalone:
#' compute_dtm_chm_from_laz(
#'   laz_dir = "<project>/cache/layers/lidar_nuage",
#'   ncores  = 4
#' )
#'
#' # Then resolve as usual — the derived tifs are picked up:
#' dem <- resolve_project_dem("<project>")
#' chm <- resolve_project_chm("<project>")
#' }
#' @export
compute_dtm_chm_from_laz <- function(laz_dir,
                                     dtm_dir   = NULL,
                                     chm_dir   = NULL,
                                     res       = 1,
                                     aoi       = NULL,
                                     ncores    = 1L,
                                     overwrite = FALSE,
                                     verbose   = TRUE) {

  if (!requireNamespace("lasR", quietly = TRUE)) {
    cli::cli_warn(c(
      "{.pkg lasR} is required to derive MNT/MNH from .laz tiles.",
      i = "Install from r-universe: {.code install.packages('lasR', repos = 'https://r-lidar.r-universe.dev')}"
    ))
    return(invisible(NULL))
  }
  if (!is.character(laz_dir) || length(laz_dir) != 1L || !nzchar(laz_dir)) {
    cli::cli_abort("{.arg laz_dir} must be a single non-empty path.")
  }
  if (!dir.exists(laz_dir)) {
    cli::cli_warn("LAZ directory does not exist: {.path {laz_dir}}")
    return(invisible(NULL))
  }

  laz_files <- list.files(
    laz_dir,
    pattern     = "\\.(copc\\.laz|laz|las)$",
    full.names  = TRUE,
    ignore.case = TRUE
  )
  if (!length(laz_files)) {
    cli::cli_warn("No .laz / .copc.laz tiles found under {.path {laz_dir}}.")
    return(invisible(NULL))
  }

  if (is.null(dtm_dir)) {
    dtm_dir <- file.path(dirname(laz_dir), "lidar_mnt")
  }
  if (is.null(chm_dir)) {
    chm_dir <- file.path(dirname(laz_dir), "lidar_mnh")
  }
  dir.create(dtm_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(chm_dir, recursive = TRUE, showWarnings = FALSE)

  dtm_path <- file.path(dtm_dir, "dtm.tif")
  chm_path <- file.path(chm_dir, "chm.tif")

  if (!overwrite && file.exists(dtm_path) && file.exists(chm_path)) {
    if (verbose) {
      cli::cli_alert_info(
        "DTM/CHM already exist (use {.code overwrite = TRUE} to rebuild). Skipping."
      )
    }
    return(invisible(list(
      dtm = dtm_path, chm = chm_path,
      n_tiles = length(laz_files), elapsed = as.difftime(0, units = "secs")
    )))
  }

  if (verbose) {
    cli::cli_alert_info("lasR pipeline on {length(laz_files)} tile{?s} \\
                         (res = {res} m, ncores = {ncores}) ...")
  }

  # ---- lasR pipeline ------------------------------------------------
  # Atoms used (lasR >= 0.10):
  #   reader_las()      : read all tiles
  #   triangulate()     : ground TIN (LAS class 2)
  #   rasterize(res, tri, ofile): DTM via TIN interpolation
  #   transform_with(tri): subtract TIN from z (height normalization)
  #   rasterize(res, "max", ofile): CHM as max normalized z
  read  <- lasR::reader_las()
  tri   <- lasR::triangulate(filter = lasR::keep_class(2L))
  dtm_s <- lasR::rasterize(res, tri,   ofile = dtm_path)
  norm  <- lasR::transform_with(tri)
  chm_s <- lasR::rasterize(res, "max", ofile = chm_path)

  pipeline <- read + tri + dtm_s + norm + chm_s

  t0 <- Sys.time()
  ans <- tryCatch(
    lasR::exec(pipeline, on = laz_files,
               with = list(ncores = lasR::concurrent_files(ncores))),
    error = function(e) {
      cli::cli_warn(c(
        "lasR pipeline failed: {conditionMessage(e)}",
        i = "Outputs may be partial — check {.path {dtm_dir}} and {.path {chm_dir}}."
      ))
      NULL
    }
  )
  elapsed <- difftime(Sys.time(), t0, units = "secs")

  if (is.null(ans)) {
    return(invisible(NULL))
  }

  # ---- optional crop to AOI -----------------------------------------
  if (!is.null(aoi)) {
    if (!requireNamespace("terra", quietly = TRUE) ||
        !requireNamespace("sf", quietly = TRUE)) {
      cli::cli_warn("Skipping AOI crop: {.pkg terra} and {.pkg sf} required.")
    } else {
      .crop_to_aoi <- function(path, aoi) {
        if (!file.exists(path)) return(invisible(NULL))
        r <- terra::rast(path)
        a <- sf::st_transform(sf::st_as_sf(aoi), terra::crs(r))
        v <- terra::vect(a)
        r2 <- terra::mask(terra::crop(r, v), v)
        tmp <- tempfile(fileext = ".tif")
        terra::writeRaster(r2, tmp, overwrite = TRUE,
                           gdal = c("TILED=YES", "COMPRESS=DEFLATE"))
        file.copy(tmp, path, overwrite = TRUE)
        unlink(tmp)
      }
      .crop_to_aoi(dtm_path, aoi)
      .crop_to_aoi(chm_path, aoi)
    }
  }

  if (verbose) {
    cli::cli_alert_success(
      "lasR done in {format_duration(as.numeric(elapsed))} — \\
       DTM: {.path {dtm_path}} | CHM: {.path {chm_path}}"
    )
  }

  invisible(list(
    dtm     = if (file.exists(dtm_path)) dtm_path else NULL,
    chm     = if (file.exists(chm_path)) chm_path else NULL,
    n_tiles = length(laz_files),
    elapsed = elapsed
  ))
}


# ---- internal helper used by resolve_project_dem/chm fallback -----
#
# Try to derive MNT/MNH from .laz tiles in <project>/cache/layers/lidar_nuage
# when no pre-rasterized DEM/CHM is found. Returns TRUE if either a DTM
# or a CHM was successfully produced (so the caller knows to re-probe).
#
# `target` is informational only (which side asked) — the lasR pipeline
# produces both in a single pass, so we run it once and let
# resolve_project_dem / resolve_project_chm pick up what they need.
.maybe_compute_lidar_rasters <- function(project_path,
                                         target  = c("dtm", "chm"),
                                         verbose = FALSE) {
  target <- match.arg(target)
  laz_dir <- file.path(project_path, "cache", "layers", "lidar_nuage")
  if (!dir.exists(laz_dir)) return(FALSE)

  laz_files <- list.files(
    laz_dir,
    pattern     = "\\.(copc\\.laz|laz|las)$",
    full.names  = TRUE,
    ignore.case = TRUE
  )
  if (!length(laz_files)) return(FALSE)

  if (!requireNamespace("lasR", quietly = TRUE)) {
    if (verbose) {
      cli::cli_alert_info(
        "Found {length(laz_files)} .laz tile{?s} but {.pkg lasR} not installed; \\
         skipping automatic MNT/MNH derivation."
      )
    }
    return(FALSE)
  }

  if (verbose) {
    cli::cli_alert_info(
      "No pre-rasterized {.val {toupper(target)}} found — falling back to \\
       lasR derivation from {length(laz_files)} .laz tile{?s}."
    )
  }

  out <- compute_dtm_chm_from_laz(
    laz_dir = laz_dir,
    verbose = verbose
  )
  !is.null(out) && (!is.null(out$dtm) || !is.null(out$chm))
}
