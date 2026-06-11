# Test fixtures and helper functions
# This file is automatically loaded before tests

# Force English language for consistent test messages
nemeton::nemeton_set_language("en")

# Patch shiny::testServer to drain later callbacks after each call.
# Without this, accumulated async state from many testServer sessions
# causes subsequent test_file() calls to hang.
.original_testServer <- shiny::testServer
.patched_testServer <- function(...) {
  on.exit(later::run_now(0), add = TRUE)
  .original_testServer(...)
}
suppressWarnings({
  unlockBinding("testServer", asNamespace("shiny"))
  assign("testServer", .patched_testServer, envir = asNamespace("shiny"))
})

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
      c(
        xmin, ymin,
        xmax, ymin,
        xmax, ymax,
        xmin, ymax,
        xmin, ymin
      ),
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
  skip_if_terra_write_broken()
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
      c(
        566400, 6615100,
        567000, 6615500
      ),
      ncol = 2, byrow = TRUE
    ))

    line2 <- sf::st_linestring(matrix(
      c(
        566400, 6615500,
        567000, 6615100
      ),
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
      c(
        566500, 6615200,
        566600, 6615300,
        566700, 6615250,
        566800, 6615400,
        566900, 6615350
      ),
      ncol = 2, byrow = TRUE
    )

    sfc <- sf::st_sfc(lapply(seq_len(nrow(coords)), function(i) {
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
  skip_if_terra_write_broken()
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
  # Some GitHub runners exhibit a terra anomaly where raster construction
  # (terra::rast / writeRaster) fails inside testthat — see helper-fast-raster.R.
  # Almost every raster test opens with some skip_if_not_installed() call, so
  # probe (cached) and skip there rather than fail on the runner. No-op on every
  # healthy environment (local, most CI), where the probe passes and tests run.
  skip_if_terra_write_broken()
}

# ==============================================================================
# Shared test data builders
# ==============================================================================

#' Create test units with family columns pre-populated
#'
#' Replaces the common pattern:
#'   units <- create_test_units(n_features = N)
#'   units$famille_carbone <- runif(N, 40, 90)
#'   units$famille_biodiversite <- runif(N, 30, 85)
#'   ...
#'
#' @param n_features Number of features
#' @param families Character vector of family names (without "famille_" prefix)
#' @param seed Optional random seed for reproducibility
#' @return sf object with family columns
create_test_family_units <- function(n_features = 10,
                                     families = c("carbone", "biodiversite",
                                                  "eau", "risque"),
                                     seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  units <- create_test_units(n_features = n_features)

  # Plages de valeurs réalistes par famille
  family_ranges <- list(
    carbone = c(40, 90), biodiversite = c(30, 85), eau = c(35, 80),
    risque = c(25, 75), temporel = c(45, 95), air = c(50, 85),
    social = c(30, 70), production = c(35, 75), energie = c(40, 80),
    naturalite = c(30, 70), sol = c(35, 75), paysage = c(40, 80)
  )

  for (fam in families) {
    rng <- family_ranges[[fam]]
    if (is.null(rng)) rng <- c(30, 80)
    units[[paste0("famille_", fam)]] <- runif(n_features, rng[1], rng[2])
  }

  units
}

#' Create test units from massif_demo with family columns
#'
#' Replaces the common pattern:
#'   data(massif_demo_units)
#'   units <- massif_demo_units[1:N, ]
#'   units$famille_carbone <- runif(N, ...)
#'
#' @param n_features Number of features (capped to dataset size)
#' @param families Character vector of family names
#' @param seed Optional random seed
#' @return sf object from massif_demo with family columns
create_demo_family_units <- function(n_features = 10,
                                     families = c("carbone", "biodiversite",
                                                  "eau", "risque"),
                                     seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  data("massif_demo_units", package = "nemeton", envir = environment())
  units <- massif_demo_units[seq_len(min(n_features, nrow(massif_demo_units))), ]
  n <- nrow(units)

  family_ranges <- list(
    carbone = c(40, 90), biodiversite = c(30, 85), eau = c(35, 80),
    risque = c(25, 75), temporel = c(45, 95), air = c(50, 85),
    social = c(30, 70), production = c(35, 75), energie = c(40, 80),
    naturalite = c(30, 70), sol = c(35, 75), paysage = c(40, 80)
  )

  for (fam in families) {
    rng <- family_ranges[[fam]]
    if (is.null(rng)) rng <- c(30, 80)
    units[[paste0("famille_", fam)]] <- runif(n, rng[1], rng[2])
  }

  units
}

#' Create cluster-ready data frame with clear group separation
#'
#' Replaces local make_cluster_df() in test-analysis-clustering.R
#'
#' @param n_per_group Number of rows per group (3 groups: high/mid/low)
#' @param families Character vector of column names
#' @return data.frame with clusterable data
create_test_cluster_df <- function(n_per_group = 5,
                                   families = c("famille_carbone",
                                                "famille_biodiversite",
                                                "famille_production",
                                                "famille_social")) {
  groups <- list(high = c(80, 100), mid = c(40, 60), low = c(0, 20))
  dfs <- lapply(seq_along(groups), function(g) {
    rng <- groups[[g]]
    df <- data.frame(id = (g - 1) * n_per_group + seq_len(n_per_group))
    for (fam in families) df[[fam]] <- runif(n_per_group, rng[1], rng[2])
    df
  })
  do.call(rbind, dfs)
}

#' Create a mock nemeton_layers object
#'
#' Replaces local make_layers() in batch test files
#'
#' @param rasters Named list of SpatRaster objects
#' @param vectors Named list of sf objects
#' @param cache_dir Cache directory path
#' @return nemeton_layers object
create_test_layers <- function(rasters = list(), vectors = list(),
                               cache_dir = NULL) {
  layers <- list(
    rasters = rasters,
    vectors = vectors,
    cache_dir = if (is.null(cache_dir)) tempdir() else cache_dir,
    metadata = list(
      created_at = Sys.time(),
      n_rasters = length(rasters),
      n_vectors = length(vectors),
      validated = FALSE
    )
  )
  class(layers) <- "nemeton_layers"
  layers
}

#' Load a test fixture RDS file
#'
#' Replaces readRDS(test_path("fixtures", "name.rds"))
#'
#' @param name Fixture name (without .rds extension)
#' @return The deserialized R object, or skip if not found
load_test_fixture <- function(name) {
  path <- testthat::test_path("fixtures", paste0(name, ".rds"))
  if (!file.exists(path)) testthat::skip(paste("Fixture not found:", name))
  readRDS(path)
}
