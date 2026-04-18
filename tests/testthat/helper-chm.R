# CHM synthetic fixtures for tests (spec 005 T1.25-T1.28)
# This file is auto-loaded by testthat.

#' Generate a synthetic Canopy Height Model for tests
#'
#' Creates a SpatRaster in EPSG:2154 with:
#'  - plausible forest canopy heights sampled in [5, 35] m,
#'  - a few NA pixels simulating gaps,
#'  - optionally a couple of out-of-range artefacts (> 50 m) to exercise
#'    the range-clamp step of sanitize_chm().
#'
#' When \code{write_cog = TRUE}, the raster is written to a COG file and
#' the returned SpatRaster points to that file.
#'
#' @param size_m Numeric. AOI side length in metres (default 200).
#' @param res_m Numeric. Pixel size in metres (default 1.5).
#' @param seed Integer. Random seed.
#' @param add_artefacts Logical. Include a few > 50 m pixels.
#' @param write_cog Logical. If TRUE, write to a COG tempfile and return
#'   a SpatRaster backed by that file.
#'
#' @return A SpatRaster.
make_fixture_chm <- function(size_m = 200,
                             res_m = 1.5,
                             seed = 42L,
                             add_artefacts = TRUE,
                             write_cog = FALSE) {
  set.seed(seed)
  xmin <- 900000
  ymin <- 6300000
  xmax <- xmin + size_m
  ymax <- ymin + size_m

  r <- terra::rast(
    xmin = xmin, xmax = xmax,
    ymin = ymin, ymax = ymax,
    resolution = res_m,
    crs = "EPSG:2154"
  )

  n <- terra::ncell(r)
  vals <- stats::runif(n, min = 5, max = 35)

  # Quelques pixels NA pour simuler des trous de couvert
  na_idx <- sample(seq_len(n), size = round(0.05 * n))
  vals[na_idx] <- NA_real_

  # Quelques pixels aberrants > 50 m pour tester le clamp de sanitize_chm
  if (isTRUE(add_artefacts)) {
    art_idx <- sample(setdiff(seq_len(n), na_idx), size = 3)
    vals[art_idx] <- c(55, 62, 70)
  }

  terra::values(r) <- vals
  names(r) <- "chm"

  if (isTRUE(write_cog)) {
    f <- tempfile(fileext = ".tif")
    # La taille de bloc par defaut (512) convient a des rasters
    # assez grands ; pour des fixtures plus petites, passer a 16 evite
    # les warnings GDAL.
    blocksize <- if (terra::ncol(r) >= 128) 128L else 16L
    suppressWarnings(
      terra::writeRaster(
        r, f,
        filetype = "COG",
        gdal = c("COMPRESS=DEFLATE",
                 paste0("BLOCKSIZE=", blocksize)),
        overwrite = TRUE
      )
    )
    r <- terra::rast(f)
  }

  r
}


#' Generate simple fixture masks aligned with a fixture CHM
#'
#' Produces forest_mask (SpatRaster, logical), buildings and water as sf
#' polygon layers in EPSG:2154 overlapping a corner of the CHM extent.
#'
#' @param chm A fixture SpatRaster produced by \code{make_fixture_chm()}.
#'
#' @return A list with \code{forest_mask}, \code{buildings}, \code{water}.
make_fixture_masks <- function(chm) {
  ext <- terra::ext(chm)
  xmin <- ext$xmin; xmax <- ext$xmax
  ymin <- ext$ymin; ymax <- ext$ymax

  # Masque foret : tout sauf un quart bas-gauche (non-foret)
  forest_mask <- terra::rast(chm)
  terra::values(forest_mask) <- 1L
  terra::values(forest_mask)[
    terra::cells(forest_mask,
                 terra::ext(xmin,
                            xmin + (xmax - xmin) / 4,
                            ymin,
                            ymin + (ymax - ymin) / 4))
  ] <- 0L

  # Batiments : petit polygone dans le quart bas-droit
  buildings <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(
        c(xmax - 40, ymin + 5),
        c(xmax - 5,  ymin + 5),
        c(xmax - 5,  ymin + 40),
        c(xmax - 40, ymin + 40),
        c(xmax - 40, ymin + 5)
      ))),
      crs = 2154
    )
  )

  # Eau : petit polygone dans le quart haut-gauche
  water <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(
        c(xmin + 5,  ymax - 40),
        c(xmin + 40, ymax - 40),
        c(xmin + 40, ymax - 5),
        c(xmin + 5,  ymax - 5),
        c(xmin + 5,  ymax - 40)
      ))),
      crs = 2154
    )
  )

  list(
    forest_mask = forest_mask,
    buildings = buildings,
    water = water
  )
}


#' Generate a synthetic NDVI raster aligned with a fixture CHM
#'
#' Values uniformly distributed in [-0.2, 0.9]. Useful to exercise the
#' NDVI threshold step of sanitize_chm().
#'
#' @param chm A fixture SpatRaster from \code{make_fixture_chm()}.
#' @param seed Integer.
#'
#' @return A SpatRaster.
make_fixture_ndvi <- function(chm, seed = 1L) {
  set.seed(seed)
  r <- terra::rast(chm)
  terra::values(r) <- stats::runif(terra::ncell(r), min = -0.2, max = 0.9)
  names(r) <- "ndvi"
  r
}


#' Generate a synthetic slope raster aligned with a fixture CHM
#'
#' Slope values in [0, 80] degrees.
#'
#' @param chm A fixture SpatRaster from \code{make_fixture_chm()}.
#' @param seed Integer.
#'
#' @return A SpatRaster.
make_fixture_slope <- function(chm, seed = 2L) {
  set.seed(seed)
  r <- terra::rast(chm)
  terra::values(r) <- stats::runif(terra::ncell(r), min = 0, max = 80)
  names(r) <- "slope"
  r
}
