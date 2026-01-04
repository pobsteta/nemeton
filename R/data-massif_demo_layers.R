#' Load Massif Demo Spatial Layers
#'
#' Convenience function to load all spatial layers associated with the
#' \code{\link{massif_demo_units}} dataset.
#'
#' @return A \code{nemeton_layers} object containing:
#' \describe{
#'   \item{rasters}{
#'     \itemize{
#'       \item \code{biomass}: Aboveground biomass (Mg/ha)
#'       \item \code{dem}: Digital Elevation Model (m)
#'       \item \code{landcover}: Land cover classification (6 classes)
#'       \item \code{species_richness}: Number of species per pixel
#'     }
#'   }
#'   \item{vectors}{
#'     \itemize{
#'       \item \code{roads}: Road network (Départementale, Forestière, Chemin)
#'       \item \code{water}: Water courses (Ruisseau, Rivière, Torrent)
#'     }
#'   }
#' }
#'
#' @details
#' All layers are in Lambert-93 projection (EPSG:2154) and cover the same
#' extent as \code{massif_demo_units}.
#'
#' The returned object can be used directly with \code{\link{nemeton_compute}}
#' to calculate biophysical indicators.
#'
#' @section File Locations:
#' The function loads files from the package installation directory:
#' - Rasters: \code{inst/extdata/massif_demo_*.tif}
#' - Vectors: \code{inst/extdata/massif_demo_*.gpkg}
#'
#' @seealso \code{\link{massif_demo_units}}, \code{\link{nemeton_layers}},
#'   \code{\link{nemeton_compute}}
#'
#' @examples
#' # Load demo parcels and layers
#' data(massif_demo_units)
#' layers <- massif_demo_layers()
#'
#' # Inspect layers
#' print(layers)
#'
#' \dontrun{
#' # Compute all indicators
#' results <- nemeton_compute(
#'   massif_demo_units,
#'   layers,
#'   indicators = "all",
#'   preprocess = TRUE
#' )
#'
#' # Carbon indicator only
#' carbon <- nemeton_compute(
#'   massif_demo_units,
#'   layers,
#'   indicators = "carbon",
#'   preprocess = TRUE
#' )
#'
#' # Water regulation (using DEM and water courses)
#' water <- nemeton_compute(
#'   massif_demo_units,
#'   layers,
#'   indicators = "water",
#'   preprocess = TRUE
#' )
#'
#' # Fragmentation (using land cover)
#' fragmentation <- nemeton_compute(
#'   massif_demo_units,
#'   layers,
#'   indicators = "fragmentation",
#'   forest_values = c(1, 2, 3),  # Forest classes
#'   preprocess = TRUE
#' )
#' }
#'
#' @export
massif_demo_layers <- function() {
  # Get package installation path
  pkg_path <- system.file(package = "nemeton")

  if (pkg_path == "") {
    cli::cli_abort(c(
      "!" = "Package {.pkg nemeton} not found",
      "i" = "Install the package first: {.code devtools::install()}"
    ))
  }

  extdata_path <- file.path(pkg_path, "extdata")

  if (!dir.exists(extdata_path)) {
    cli::cli_abort(c(
      "!" = "Demo data directory not found: {.path {extdata_path}}",
      "i" = "Reinstall the package to include demo data"
    ))
  }

  # Define file paths
  raster_files <- list(
    biomass = file.path(extdata_path, "massif_demo_biomass.tif"),
    dem = file.path(extdata_path, "massif_demo_dem.tif"),
    landcover = file.path(extdata_path, "massif_demo_landcover.tif"),
    species_richness = file.path(extdata_path, "massif_demo_species_richness.tif")
  )

  vector_files <- list(
    roads = file.path(extdata_path, "massif_demo_roads.gpkg"),
    water = file.path(extdata_path, "massif_demo_water.gpkg")
  )

  # Check that all files exist
  all_files <- c(raster_files, vector_files)
  missing <- !file.exists(unlist(all_files))

  if (any(missing)) {
    missing_names <- names(all_files)[missing]
    cli::cli_abort(c(
      "!" = "Missing demo data file{?s}: {.field {missing_names}}",
      "i" = "Reinstall the package to include all demo data"
    ))
  }

  # Create nemeton_layers object
  cli::cli_alert_info("Loading Massif Demo spatial layers...")

  layers <- nemeton_layers(
    rasters = raster_files,
    vectors = vector_files
  )

  # Add additional metadata
  layers$metadata$dataset <- "massif_demo"
  layers$metadata$description <- "Synthetic forest dataset for nemeton package demonstration"
  layers$metadata$extent <- "5.8 km x 5.9 km"
  layers$metadata$resolution <- "25m"
  layers$metadata$crs <- "EPSG:2154 (Lambert-93)"

  n_rasters <- length(raster_files)
  n_vectors <- length(vector_files)
  cli::cli_alert_success(
    "Loaded {n_rasters} raster layer{?s} and {n_vectors} vector layer{?s}"
  )

  layers
}
