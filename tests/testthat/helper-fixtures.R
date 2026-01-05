# Test fixtures and helper functions
# This file is automatically loaded before tests

# Force English language for consistent test messages
nemeton::nemeton_set_language("en")

#' Create a test sf object (simple square polygon)
#'
#' @param crs CRS for the test object (default: EPSG:2154 - Lambert 93)
#' @param n_features Number of features to create
#' @return sf object with test geometries
create_test_units <- function(crs = 2154, n_features = 3) {
  # Create simple square polygons within raster extent
  # Raster extent: 566400, 567000, 6615100, 6615500 (600m x 400m)
  # Use smaller offset (120m) to keep all polygons inside
  polys <- lapply(seq_len(n_features), function(i) {
    # Create a 100m x 100m square, offset by 120m to stay inside raster
    xmin <- 566450 + (i - 1) * 120
    ymin <- 6615150 + (i - 1) * 120
    xmax <- xmin + 100
    ymax <- ymin + 100

    sf::st_polygon(list(matrix(
      c(xmin, ymin,
        xmax, ymin,
        xmax, ymax,
        xmin, ymax,
        xmin, ymin),
      ncol = 2, byrow = TRUE
    )))
  })

  # Create sf object
  sfc <- sf::st_sfc(polys, crs = crs)
  units <- sf::st_sf(
    id = sprintf("unit_%03d", seq_len(n_features)),
    area = rep(10000, n_features), # 100m x 100m = 10000 m²
    geometry = sfc
  )

  units
}

#' Create a test raster (SpatRaster)
#'
#' @param extent Extent vector c(xmin, xmax, ymin, ymax)
#' @param crs CRS for the raster
#' @param values Values to fill (or "random")
#' @param res Resolution in map units
#' @return SpatRaster object
create_test_raster <- function(extent = c(566400, 567000, 6615100, 6615500),
                                crs = "EPSG:2154",
                                values = "random",
                                res = 10) {
  # Create raster
  r <- terra::rast(
    extent = terra::ext(extent),
    resolution = res,
    crs = crs
  )

  # Fill with values
  if (is.character(values) && values == "random") {
    terra::values(r) <- runif(terra::ncell(r), 0, 100)
  } else if (is.character(values) && values == "constant") {
    terra::values(r) <- 50
  } else {
    terra::values(r) <- values
  }

  r
}

#' Create a test vector layer (lines for roads/rivers)
#'
#' @param crs CRS for the vector
#' @param type Type of geometry ("lines" or "points")
#' @return sf object with test geometries
create_test_vector <- function(crs = 2154, type = "lines") {
  if (type == "lines") {
    # Create two diagonal lines crossing the test area
    line1 <- sf::st_linestring(matrix(
      c(566400, 6615100,
        567000, 6615500),
      ncol = 2, byrow = TRUE
    ))

    line2 <- sf::st_linestring(matrix(
      c(566400, 6615500,
        567000, 6615100),
      ncol = 2, byrow = TRUE
    ))

    sfc <- sf::st_sfc(list(line1, line2), crs = crs)
    roads <- sf::st_sf(
      road_id = c("R001", "R002"),
      road_type = c("primary", "secondary"),
      geometry = sfc
    )

    return(roads)
  } else if (type == "points") {
    # Create 5 random points
    coords <- matrix(
      c(566500, 6615200,
        566600, 6615300,
        566700, 6615250,
        566800, 6615400,
        566900, 6615350),
      ncol = 2, byrow = TRUE
    )

    sfc <- sf::st_sfc(lapply(1:nrow(coords), function(i) {
      sf::st_point(coords[i, ])
    }), crs = crs)

    points <- sf::st_sf(
      point_id = sprintf("P%03d", 1:5),
      geometry = sfc
    )

    return(points)
  }
}

#' Create temporary test files
#'
#' Creates temporary raster and vector files for testing file-based operations
#'
#' @return Named list with paths to temporary files
create_temp_test_files <- function() {
  # Create temp directory
  temp_dir <- tempdir()

  # Create and save test raster (biomass)
  biomass_raster <- create_test_raster(values = "random")
  biomass_path <- file.path(temp_dir, "test_biomass.tif")
  terra::writeRaster(biomass_raster, biomass_path, overwrite = TRUE)

  # Create and save test raster (DEM)
  dem_raster <- create_test_raster(values = seq(100, 200, length.out = terra::ncell(biomass_raster)))
  dem_path <- file.path(temp_dir, "test_dem.tif")
  terra::writeRaster(dem_raster, dem_path, overwrite = TRUE)

  # Create and save test raster (landcover - categorical)
  landcover_raster <- create_test_raster(values = "constant")
  terra::values(landcover_raster) <- sample(1:5, terra::ncell(landcover_raster), replace = TRUE)
  landcover_path <- file.path(temp_dir, "test_landcover.tif")
  terra::writeRaster(landcover_raster, landcover_path, overwrite = TRUE)

  # Create and save test vector (roads)
  roads <- create_test_vector(type = "lines")
  roads_path <- file.path(temp_dir, "test_roads.gpkg")
  sf::st_write(roads, roads_path, quiet = TRUE, delete_dsn = TRUE)

  # Create and save test vector (water)
  water <- create_test_vector(type = "lines")
  water_path <- file.path(temp_dir, "test_water.gpkg")
  sf::st_write(water, water_path, quiet = TRUE, delete_dsn = TRUE)

  # Return paths
  list(
    biomass = biomass_path,
    dem = dem_path,
    landcover = landcover_path,
    roads = roads_path,
    water = water_path,
    temp_dir = temp_dir
  )
}

#' Get path to real test cadastral parcel
#'
#' @return Path to the cadastral parcel gpkg file
get_cadastral_test_file <- function() {
  # Path relative to package root
  pkg_root <- here::here()
  cadastral_path <- file.path(pkg_root, "inst/extdata", "360053000AS0090.gpkg")

  if (!file.exists(cadastral_path)) {
    skip("Cadastral test file not found")
  }

  cadastral_path
}

#' Skip test if suggested packages not available
#'
#' @param pkg Package name
skip_if_not_installed <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    skip(paste("Package", pkg, "not installed"))
  }
}
