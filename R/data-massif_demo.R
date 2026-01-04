#' Massif Demo - Example Forest Dataset
#'
#' Synthetic forest dataset for demonstrating the nemeton package functionality.
#' Contains 20 forest parcels with associated spatial layers covering a 5km x 5km
#' area in France (Lambert-93 projection).
#'
#' @format An \code{sf} object with 20 features and 5 fields:
#' \describe{
#'   \item{parcel_id}{Character. Unique parcel identifier (P01-P20)}
#'   \item{forest_type}{Character. Forest type:
#'     \itemize{
#'       \item "Futaie feuillue" - Broadleaf high forest
#'       \item "Futaie résineuse" - Coniferous high forest
#'       \item "Futaie mixte" - Mixed high forest
#'       \item "Taillis" - Coppice
#'     }}
#'   \item{age_class}{Character. Stand age class:
#'     \itemize{
#'       \item "Jeune" - Young (< 40 years)
#'       \item "Moyen" - Middle-aged (40-80 years)
#'       \item "Mature" - Mature (80-120 years)
#'       \item "Surannée" - Over-mature (> 120 years)
#'     }}
#'   \item{management}{Character. Management objective:
#'     \itemize{
#'       \item "Production" - Timber production
#'       \item "Conservation" - Biodiversity conservation
#'       \item "Mixte" - Mixed objectives
#'     }}
#'   \item{surface_ha}{Numeric. Parcel area in hectares}
#'   \item{geometry}{sfc_POLYGON. Parcel boundaries (EPSG:2154)}
#' }
#'
#' @details
#' The dataset includes:
#'
#' **Parcels** (\code{massif_demo_units}):
#' - 20 forest parcels (2-20 ha each, 136 ha total)
#' - Realistic spatial clustering and irregular shapes
#' - Diverse forest types and management regimes
#'
#' **Rasters** (25m resolution, in \code{inst/extdata/}):
#' - \code{massif_demo_biomass.tif}: Aboveground biomass (50-400 Mg/ha)
#' - \code{massif_demo_dem.tif}: Digital Elevation Model (350-700m)
#' - \code{massif_demo_landcover.tif}: Land cover (6 classes, 85\% forest)
#' - \code{massif_demo_species_richness.tif}: Species richness (5-45 species)
#'
#' **Vector layers** (in \code{inst/extdata/}):
#' - \code{massif_demo_roads.gpkg}: 5 roads (types: Départementale, Forestière, Chemin)
#' - \code{massif_demo_water.gpkg}: 3 water courses (types: Ruisseau, Rivière, Torrent)
#'
#' All spatial data use Lambert-93 projection (EPSG:2154).
#' Generated with \code{set.seed(42)} for reproducibility.
#'
#' @section Data Generation:
#' The dataset was created synthetically to represent typical French forest landscapes:
#' - Biomass: Spatial gradient with patches and noise
#' - Topography: Realistic elevation with gentle slopes
#' - Land cover: Spatially coherent forest/non-forest classes
#' - Species richness: Correlated with biomass and habitat diversity
#' - Infrastructure: Sinuous roads and topography-following streams
#'
#' @section Usage:
#' Use \code{\link{massif_demo_layers}} to load all associated spatial layers:
#'
#' \preformatted{
#' # Load parcels
#' data(massif_demo_units)
#'
#' # Load all layers
#' layers <- massif_demo_layers()
#'
#' # Compute indicators
#' results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
#' }
#'
#' @source Synthetic data generated with \code{data-raw/massif_demo.R}
#'
#' @seealso \code{\link{massif_demo_layers}}, \code{\link{nemeton_compute}}
#'
#' @examples
#' # Load the demo dataset
#' data(massif_demo_units)
#'
#' # Inspect parcels
#' print(massif_demo_units)
#' summary(massif_demo_units$surface_ha)
#' table(massif_demo_units$forest_type)
#'
#' # Plot parcels
#' if (require("ggplot2")) {
#'   ggplot(massif_demo_units) +
#'     geom_sf(aes(fill = forest_type)) +
#'     theme_minimal() +
#'     labs(title = "Massif Demo - Forest Types")
#' }
#'
#' \dontrun{
#' # Complete workflow example
#' library(nemeton)
#'
#' # 1. Load data
#' data(massif_demo_units)
#' layers <- massif_demo_layers()
#'
#' # 2. Compute all indicators
#' results <- nemeton_compute(
#'   massif_demo_units,
#'   layers,
#'   indicators = "all",
#'   preprocess = TRUE
#' )
#'
#' # 3. Normalize indicators
#' normalized <- normalize_indicators(
#'   results,
#'   indicators = c("carbon", "biodiversity", "water"),
#'   method = "minmax"
#' )
#'
#' # 4. Create ecosystem health index
#' health <- create_composite_index(
#'   normalized,
#'   indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
#'   weights = c(0.4, 0.4, 0.2),
#'   name = "ecosystem_health"
#' )
#'
#' # 5. Visualize
#' plot_indicators_map(
#'   health,
#'   indicators = "ecosystem_health",
#'   palette = "RdYlGn",
#'   title = "Ecosystem Health - Massif Demo"
#' )
#' }
#'
"massif_demo_units"
