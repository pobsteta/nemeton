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
#' @param aoi Optional `sf` / `sfc`. When supplied, the returned rasters
#'   are cropped (and masked) copies written under `aoi/` in the output
#'   directories, keyed by the AOI; the shared `dtm.tif` / `chm.tif` cache
#'   always keeps the full tile extent.
#' @param ncores Integer. Number of cores passed to `lasR::exec()`.
#'   Default 1 — set to `parallel::detectCores() - 1` for large blocks.
#' @param overwrite Logical. Re-derive even if `dtm.tif` / `chm.tif`
#'   already exist in the output directories. Default `FALSE`. An existing
#'   pair is reused only when its `.key` sidecar matches the current tiles
#'   and resolution and both rasters read back; otherwise it is rebuilt.
#'   Outputs are written to temporary files and moved into place only once
#'   complete.
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

  # Le cache dtm.tif / chm.tif couvre TOUJOURS l'emprise complète des dalles
  # et n'est resservi que si sa clé (dalles + résolution) correspond et que
  # les deux rasters se relisent. Un cache sans clé (antérieur à ce
  # correctif, possiblement rogné en place sur une autre AOI) est rebâti.
  key <- .lasr_cache_key(laz_files, res)
  reuse <- !overwrite && .lasr_cache_valide(dtm_path, chm_path, key)

  if (reuse) {
    if (verbose) {
      cli::cli_alert_info(
        "DTM/CHM already exist (use {.code overwrite = TRUE} to rebuild). Skipping."
      )
    }
    elapsed <- as.difftime(0, units = "secs")
  } else {
    if (verbose) {
      cli::cli_alert_info("lasR pipeline on {length(laz_files)} tile{?s} \\
                           (res = {res} m, ncores = {ncores}) ...")
    }
    # lasR écrit dans des temporaires voisins ; ils ne sont promus sous
    # dtm.tif / chm.tif qu'une fois tous deux complets et relisibles. Un
    # pipeline interrompu ne laisse donc jamais de cache partiel.
    dtm_tmp <- .atomic_tmp_path(dtm_path)
    chm_tmp <- .atomic_tmp_path(chm_path)
    on.exit(unlink(c(dtm_tmp, chm_tmp), force = TRUE), add = TRUE)
    unlink(paste0(c(dtm_path, chm_path), ".key"), force = TRUE)

    t0 <- Sys.time()
    ans <- tryCatch(
      .lasr_derive(laz_files, dtm_tmp, chm_tmp, res = res, ncores = ncores),
      error = function(e) {
        cli::cli_warn(c(
          "lasR pipeline failed: {conditionMessage(e)}",
          i = "No partial output was kept."
        ))
        NULL
      }
    )
    elapsed <- difftime(Sys.time(), t0, units = "secs")

    if (is.null(ans)) {
      return(invisible(NULL))
    }
    produits <- c(dtm = dtm_tmp, chm = chm_tmp)
    lisibles <- vapply(produits, .raster_lisible, logical(1))
    if (!all(lisibles)) {
      cli::cli_warn(
        "lasR output unreadable ({.val {names(produits)[!lisibles]}}); nothing cached."
      )
      return(invisible(NULL))
    }
    .atomic_promote(dtm_tmp, dtm_path)
    .atomic_promote(chm_tmp, chm_path)
    # Clés écrites en dernier : un cache sans clé n'est jamais resservi.
    for (p in c(dtm_path, chm_path)) {
      .atomic_write(paste0(p, ".key"), function(tmp) writeLines(key, tmp))
    }
  }

  dtm_out <- dtm_path
  chm_out <- chm_path

  # ---- optional crop to AOI -----------------------------------------
  # On ne rogne JAMAIS le cache partagé en place : la découpe va dans une
  # copie propre à l'AOI (sous-dossier `aoi/`, invisible pour
  # resolve_project_dem / resolve_project_chm qui ne listent que le
  # premier niveau), indexée par l'AOI et la clé du cache complet.
  if (!is.null(aoi)) {
    if (!requireNamespace("terra", quietly = TRUE) ||
        !requireNamespace("sf", quietly = TRUE)) {
      cli::cli_warn("Skipping AOI crop: {.pkg terra} and {.pkg sf} required.")
    } else {
      aoi_key <- .lasr_aoi_key(aoi, key)
      dtm_out <- .lasr_crop_copy(dtm_path, aoi, aoi_key, "dtm")
      chm_out <- .lasr_crop_copy(chm_path, aoi, aoi_key, "chm")
    }
  }

  if (verbose && !reuse) {
    cli::cli_alert_success(
      "lasR done in {format_duration(as.numeric(elapsed))} \u2014 \\
       DTM: {.path {dtm_out}} | CHM: {.path {chm_out}}"
    )
  }

  invisible(list(
    dtm     = if (file.exists(dtm_out)) dtm_out else NULL,
    chm     = if (file.exists(chm_out)) chm_out else NULL,
    n_tiles = length(laz_files),
    elapsed = elapsed
  ))
}


# ---- internal helpers: lasR pipeline & cache keys -------------------

# Pipeline lasR (substituable dans les tests). Atomes (lasR >= 0.10) :
#   reader_las()      : lecture de toutes les dalles
#   triangulate()     : TIN du sol (classe LAS 2)
#   rasterize(res, tri, ofile): MNT par interpolation du TIN
#   transform_with(tri): soustraction du TIN (normalisation des hauteurs)
#   rasterize(res, "max", ofile): MNH = z normalisé maximal
.lasr_derive <- function(laz_files, dtm_file, chm_file, res, ncores) {
  read  <- lasR::reader_las()
  tri   <- lasR::triangulate(filter = lasR::keep_class(2L))
  dtm_s <- lasR::rasterize(res, tri,   ofile = dtm_file)
  norm  <- lasR::transform_with(tri)
  # Bruit bas (7) et haut (18, ASPRS) hors du CHM : un seul point aberrant
  # suffisait a creer un pic dans un rasterize « max » (audit 1.0).
  chm_s <- lasR::rasterize(res, "max", filter = lasR::drop_class(c(7L, 18L)),
                           ofile = chm_file)
  pipeline <- read + tri + dtm_s + norm + chm_s
  lasR::exec(pipeline, on = laz_files,
             with = list(ncores = lasR::concurrent_files(ncores)))
}

# Clé du cache complet : jeu de dalles (noms + tailles) et résolution.
.lasr_cache_key <- function(laz_files, res) {
  f <- sort(laz_files)
  rlang::hash(list(basename(f), unname(file.size(f)), as.numeric(res)))
}

.lasr_cache_valide <- function(dtm_path, chm_path, key) {
  cle_ok <- function(p) {
    k <- paste0(p, ".key")
    file.exists(k) &&
      identical(tryCatch(readLines(k, warn = FALSE)[1], error = function(e) NA), key)
  }
  cle_ok(dtm_path) && cle_ok(chm_path) &&
    .raster_lisible(dtm_path) && .raster_lisible(chm_path)
}

# Clé de la découpe : géométrie de l'AOI (WKB), son CRS, et la clé du cache
# complet dont elle dérive.
.lasr_aoi_key <- function(aoi, key) {
  g <- sf::st_geometry(sf::st_as_sf(aoi))
  substr(rlang::hash(list(sf::st_as_binary(g), sf::st_crs(g)$wkt, key)), 1L, 16L)
}

.lasr_crop_copy <- function(path, aoi, aoi_key, prefix) {
  out <- file.path(dirname(path), "aoi", sprintf("%s_%s.tif", prefix, aoi_key))
  if (.cache_valid_or_drop(out, .raster_lisible)) return(out)
  r <- terra::rast(path)
  a <- sf::st_transform(sf::st_as_sf(aoi), terra::crs(r))
  v <- terra::vect(a)
  r2 <- terra::mask(terra::crop(r, v), v)
  .atomic_write(out, function(tmp) {
    terra::writeRaster(r2, tmp, overwrite = TRUE,
                       gdal = c("TILED=YES", "COMPRESS=DEFLATE"))
  }, validate = .raster_lisible)
  out
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
      "No pre-rasterized {.val {toupper(target)}} found \u2014 falling back to \\
       lasR derivation from {length(laz_files)} .laz tile{?s}."
    )
  }

  out <- compute_dtm_chm_from_laz(
    laz_dir = laz_dir,
    verbose = verbose
  )
  !is.null(out) && (!is.null(out$dtm) || !is.null(out$chm))
}
