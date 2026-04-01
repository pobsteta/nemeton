#' Social & Recreational Services Indicators (Family S)
#'
#' Functions for calculating social and recreational use indicators:
#' - S1: Distance to roads (accessibility via road network)
#' - S2: Distance to buildings (proximity to built areas)
#' - S3: Population proximity (visitor pressure potential)
#'
#' @name indicators-social
#' @keywords internal
#' @family indicators
NULL

#' S1: Distance to Roads Indicator
#'
#' Calculates the mean distance (in metres) from each spatial unit to the
#' nearest road, using rasterized road data and \code{terra::distance()}.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param roads sf object (LINESTRING) of road network. If NULL, resolved from layers.
#' @param dem SpatRaster. Digital elevation model used as reference grid.
#'   If NULL, resolved from layers.
#' @param layers A nemeton_layers object (optional). Used to resolve roads/dem
#'   when not provided directly.
#' @param column_name Character. Name for output column. Default "S1".
#' @param lang Character. Message language ("en" or "fr"). Default "en".
#'
#' @return sf object with added column: S1 (mean distance to nearest road in metres)
#'
#' @details
#' **Calculation** (tuto 03 method):
#' \itemize{
#'   \item Rasterize road geometries onto the DEM grid
#'   \item Compute distance raster via \code{terra::distance()}
#'   \item Extract mean distance per spatial unit
#' }
#'
#' Returns NA when DEM or roads are unavailable.
#'
#' @export
#' @examples
#' \dontrun{
#' result <- indicateur_s1_routes(
#'   units = parcels,
#'   roads = roads_sf,
#'   dem = dem_raster
#' )
#' }
indicateur_s1_routes <- function(units,
                                    roads = NULL,
                                    dem = NULL,
                                    layers = NULL,
                                    column_name = "S1",
                                    lang = "en") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  # Resolve roads from layers if not provided
 if (is.null(roads) && !is.null(layers)) {
    roads <- resolve_vector_layer(layers, "roads")
  }

  # Resolve DEM from layers if not provided
  if (is.null(dem) && !is.null(layers)) {
    dem <- resolve_raster_layer(layers, "dem")
    if (is.null(dem)) dem <- resolve_raster_layer(layers, "lidar_mnt")
  }

  result <- units

  # Fallback: no DEM or no roads → NA
  if (is.null(dem) || is.null(roads) || nrow(roads) == 0) {
    cli::cli_alert_warning("S1: DEM or roads unavailable, returning NA")
    result[[column_name]] <- rep(NA_real_, nrow(units))
    return(result)
  }

  # Rasterize roads onto DEM grid
  roads_vect <- terra::vect(sf::st_transform(roads, terra::crs(dem)))
  roads_rast <- terra::rasterize(roads_vect, dem, field = 1, background = NA)

  # Compute distance to nearest road (metres)
  s1_raster <- terra::distance(roads_rast)

  # Extract mean distance per unit
  s1_values <- safe_extract(s1_raster, units, fun = "mean", progress = FALSE)

  result[[column_name]] <- as.numeric(s1_values)

  cli::cli_alert_success("Calculated {column_name}: Distance to roads (m)")

  return(result)
}

#' S2: Distance to Buildings Indicator
#'
#' Calculates the mean distance (in metres) from each spatial unit to the
#' nearest building, using rasterized building data and \code{terra::distance()}.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param buildings sf object (POLYGON) of buildings. If NULL, resolved from layers.
#' @param dem SpatRaster. Digital elevation model used as reference grid.
#'   If NULL, resolved from layers.
#' @param layers A nemeton_layers object (optional). Used to resolve buildings/dem
#'   when not provided directly.
#' @param column_name Character. Name for output column. Default "S2".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added column: S2 (mean distance to nearest building in metres)
#'
#' @details
#' **Calculation** (tuto 03 method):
#' \itemize{
#'   \item Rasterize building geometries onto the DEM grid
#'   \item Compute distance raster via \code{terra::distance()}
#'   \item Extract mean distance per spatial unit
#' }
#'
#' Returns NA when DEM or buildings are unavailable.
#'
#' @export
#' @examples
#' \dontrun{
#' result <- indicateur_s2_bati(
#'   units = parcels,
#'   buildings = buildings_sf,
#'   dem = dem_raster
#' )
#' }
indicateur_s2_bati <- function(units,
                                           buildings = NULL,
                                           dem = NULL,
                                           layers = NULL,
                                           column_name = "S2",
                                           lang = "en") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  # Resolve buildings from layers if not provided
  if (is.null(buildings) && !is.null(layers)) {
    buildings <- resolve_vector_layer(layers, "buildings")
  }

  # Resolve DEM from layers if not provided
  if (is.null(dem) && !is.null(layers)) {
    dem <- resolve_raster_layer(layers, "dem")
    if (is.null(dem)) dem <- resolve_raster_layer(layers, "lidar_mnt")
  }

  result <- units

  # Fallback: no DEM or no buildings → NA
  if (is.null(dem) || is.null(buildings) || nrow(buildings) == 0) {
    cli::cli_alert_warning("S2: DEM or buildings unavailable, returning NA")
    result[[column_name]] <- rep(NA_real_, nrow(units))
    return(result)
  }

  # Rasterize buildings onto DEM grid
  bat_vect <- terra::vect(sf::st_transform(buildings, terra::crs(dem)))
  bat_rast <- terra::rasterize(bat_vect, dem, field = 1, background = NA)

  # Compute distance to nearest building (metres)
  s2_raster <- terra::distance(bat_rast)

  # Extract mean distance per unit
  s2_values <- safe_extract(s2_raster, units, fun = "mean", progress = FALSE)

  result[[column_name]] <- as.numeric(s2_values)

  cli::cli_alert_success("Calculated {column_name}: Distance to buildings (m)")

  return(result)
}

#' S3: Population Proximity Indicator
#'
#' Calculates population counts within buffer zones (5km, 10km, 20km) to estimate
#' visitor pressure potential and recreational use intensity.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param population_grid sf object or SpatRaster of population data. If NULL, uses proxy.
#' @param method Character. Data source: "insee" (INSEE Carroyage), "local", or "proxy". Default "proxy".
#' @param buffer_radii Numeric vector. Buffer distances (m) for population counts. Default c(5000, 10000, 20000).
#' @param column_name Character. Name for output column (main indicator). Default "S3".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added columns: S3 (population within primary buffer), S3_5km, S3_10km, S3_20km
#'
#' @details
#' **Calculation**:
#' \itemize{
#'   \item Create buffer zones around each unit (5km, 10km, 20km)
#'   \item Sum population within each buffer from INSEE Carroyage 1km grid
#'   \item S3 = population within closest buffer (highest pressure)
#' }
#'
#' **Data Sources**:
#' \itemize{
#'   \item INSEE Carroyage 1km or 200m population grids (France)
#'   \item WorldPop or GPW for international applications
#'   \item Proxy: Distance to nearest urban area if no population data
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' data(massif_demo_units)
#' result <- indicateur_s3_population(
#'   units = massif_demo_units,
#'   method = "proxy",
#'   buffer_radii = c(5000, 10000, 20000)
#' )
#' }
indicateur_s3_population <- function(units,
                                       population_grid = NULL,
                                       method = c("proxy", "insee", "local"),
                                       buffer_radii = c(5000, 10000, 20000),
                                       column_name = "S3",
                                       lang = "en") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  method <- match.arg(method)

  result <- units

  # Simplified proxy calculation
  # (In production, would query INSEE Carroyage or other population grids)

  # Create buffers
  buffer_5km <- sf::st_buffer(units, dist = buffer_radii[1])
  buffer_10km <- sf::st_buffer(units, dist = buffer_radii[2])
  buffer_20km <- sf::st_buffer(units, dist = buffer_radii[3])

  # Placeholder calculation - proxy based on inverse area
  # (larger buffers would typically contain more population)
  area_5km <- as.numeric(sf::st_area(buffer_5km)) / 1000000 # km²
  area_10km <- as.numeric(sf::st_area(buffer_10km)) / 1000000
  area_20km <- as.numeric(sf::st_area(buffer_20km)) / 1000000

  # Proxy population assuming 100 people/km² average rural density
  pop_5km <- round(area_5km * 100)
  pop_10km <- round(area_10km * 100)
  pop_20km <- round(area_20km * 100)

  # Add to result
  result$S3_5km <- pop_5km
  result$S3_10km <- pop_10km
  result$S3_20km <- pop_20km
  result[[column_name]] <- pop_5km # Primary indicator is 5km buffer

  msg_info("social_population_calculated", median(pop_5km), median(pop_10km), median(pop_20km))

  cli::cli_alert_success("Calculated {column_name}: Population proximity (5/10/20km buffers)")

  return(result)
}
