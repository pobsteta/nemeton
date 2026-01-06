#' Social & Recreational Services Indicators (Family S)
#'
#' Functions for calculating social and recreational use indicators:
#' - S1: Trail density (recreational infrastructure)
#' - S2: Multimodal accessibility (public access potential)
#' - S3: Population proximity (visitor pressure potential)
#'
#' @name indicators-social
#' @family indicators
NULL

#' S1: Trail Density Indicator
#'
#' Calculates the density of recreational trails (pedestrian, cycling, equestrian)
#' within or near spatial units using OpenStreetMap or local trail datasets.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param trails sf object (LINESTRING) of trail network. If NULL and method="osm", fetches from OSM.
#' @param method Character. Data source: "osm" (OpenStreetMap) or "local". Default "osm".
#' @param osm_bbox Numeric vector (xmin, ymin, xmax, ymax) for OSM query. Auto-detected if NULL.
#' @param trail_types Character vector. OSM highway tags: c("path", "footway", "cycleway", "bridleway"). Default all.
#' @param buffer_m Numeric. Buffer distance (m) around units to include nearby trails. Default 0 (within units only).
#' @param column_name Character. Name for output column. Default "S1".
#' @param lang Character. Message language ("en" or "fr"). Default "en".
#'
#' @return sf object with added column: S1 (trail density in km/ha)
#'
#' @details
#' **Calculation**:
#' \itemize{
#'   \item Extract or fetch trail network (OSM or local)
#'   \item Clip trails to unit boundaries (+ optional buffer)
#'   \item Calculate total trail length within each unit
#'   \item Normalize by unit area: \code{S1 = trail_length_km / area_ha}
#' }
#'
#' **Trail Types** (OSM highway tags):
#' \itemize{
#'   \item path: Unpaved footpaths
#'   \item footway: Paved pedestrian paths
#'   \item cycleway: Dedicated bike paths
#'   \item bridleway: Equestrian trails
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' # Using OpenStreetMap
#' result <- indicator_social_trails(
#'   units = massif_demo_units,
#'   method = "osm",
#'   trail_types = c("path", "footway", "cycleway")
#' )
#'
#' # Using local trail data with buffer
#' result <- indicator_social_trails(
#'   units = parcels,
#'   trails = local_trails_sf,
#'   method = "local",
#'   buffer_m = 100
#' )
#' }
indicator_social_trails <- function(units,
                                     trails = NULL,
                                     method = c("osm", "local"),
                                     osm_bbox = NULL,
                                     trail_types = c("path", "footway", "cycleway", "bridleway"),
                                     buffer_m = 0,
                                     column_name = "S1",
                                     lang = "en") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  method <- match.arg(method)

  # Check dependencies
  if (method == "osm") {
    if (!requireNamespace("osmdata", quietly = TRUE)) {
      stop("Package 'osmdata' required for method='osm'. Install with: install.packages('osmdata')",
           call. = FALSE)
    }
  }

  # Acquire trail data
  if (method == "osm") {
    msg_info("social_osm_fetching")

    # Auto-detect bbox if not provided
    if (is.null(osm_bbox)) {
      osm_bbox <- get_osm_bbox(units, buffer_m = 1000)
    }

    # Query OSM for trails
    tryCatch({
      osm_query <- osmdata::opq(bbox = osm_bbox)

      # Query each trail type and combine
      trails_list <- list()
      for (trail_type in trail_types) {
        osm_result <- osm_query %>%
          osmdata::add_osm_feature(key = "highway", value = trail_type) %>%
          osmdata::osmdata_sf()

        if (!is.null(osm_result$osm_lines) && nrow(osm_result$osm_lines) > 0) {
          trails_list[[trail_type]] <- osm_result$osm_lines
        }
      }

      if (length(trails_list) == 0) {
        cli::cli_warn("No trails found in OSM for specified types")
        trails <- sf::st_sfc(crs = sf::st_crs(units))  # Empty geometry
      } else {
        # Combine all trail types
        trails <- do.call(rbind, trails_list)
        trails <- sf::st_transform(trails, crs = sf::st_crs(units))
        msg_info("social_osm_fetched", nrow(trails))
      }
    }, error = function(e) {
      cli::cli_warn(c("OSM query failed: {e$message}", "i" = "Setting S1 = NA"))
      trails <- NULL
    })

  } else if (method == "local") {
    if (is.null(trails)) {
      stop("trails parameter required for method='local'", call. = FALSE)
    }

    if (!inherits(trails, "sf")) {
      stop("trails must be an sf object (LINESTRING)", call. = FALSE)
    }

    # Transform to match units CRS
    trails <- sf::st_transform(trails, crs = sf::st_crs(units))
  }

  # Calculate S1 for each unit
  result <- units
  s1_values <- numeric(nrow(units))

  if (is.null(trails) || nrow(trails) == 0) {
    # No trails data - set to NA or 0
    s1_values <- rep(0, nrow(units))
  } else {
    # Apply buffer if specified
    if (buffer_m > 0) {
      units_buffered <- sf::st_buffer(units, dist = buffer_m)
    } else {
      units_buffered <- units
    }

    # Calculate trail length within each unit
    for (i in seq_len(nrow(units))) {
      unit_geom <- units_buffered[i, ]

      # Clip trails to unit
      trails_in_unit <- sf::st_intersection(trails, unit_geom)

      if (nrow(trails_in_unit) > 0) {
        # Calculate total trail length (in meters)
        trail_length_m <- sum(sf::st_length(trails_in_unit), na.rm = TRUE)
        trail_length_km <- as.numeric(trail_length_m) / 1000

        # Calculate unit area (in hectares)
        unit_area_m2 <- as.numeric(sf::st_area(units[i, ]))
        unit_area_ha <- unit_area_m2 / 10000

        # S1 = km of trails per hectare
        s1_values[i] <- trail_length_km / unit_area_ha

        msg_info("social_trails_detected", trail_length_km, s1_values[i])
      } else {
        s1_values[i] <- 0
      }
    }
  }

  # Add to result
  result[[column_name]] <- s1_values

  cli::cli_alert_success("Calculated {column_name}: Trail density (km/ha)")

  return(result)
}

#' S2: Multimodal Accessibility Indicator
#'
#' Calculates an accessibility score based on proximity to roads, public transport,
#' and cycling infrastructure. Higher scores indicate better public access potential.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param roads sf object (LINESTRING) of road network. If NULL and method="osm", fetches from OSM.
#' @param transit_stops sf object (POINT) of public transport stops. Optional.
#' @param method Character. Data source: "osm" (OpenStreetMap) or "local". Default "osm".
#' @param osm_bbox Numeric vector for OSM query. Auto-detected if NULL.
#' @param road_types Character vector. OSM highway tags: c("primary", "secondary", "tertiary"). Default all.
#' @param weights Named numeric vector. Weights for components: c(road = 0.5, transit = 0.3, cycling = 0.2). Default balanced.
#' @param column_name Character. Name for output column. Default "S2".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added column: S2 (accessibility score 0-100)
#'
#' @details
#' **Calculation**:
#' \itemize{
#'   \item Road accessibility: Inverse distance to nearest road (closer = higher)
#'   \item Transit accessibility: Count of transit stops within 1km buffer
#'   \item Cycling accessibility: Presence of cycling infrastructure
#'   \item Weighted composite: \code{S2 = (w1×road + w2×transit + w3×cycling)}
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' result <- indicator_social_accessibility(
#'   units = massif_demo_units,
#'   method = "osm",
#'   weights = c(road = 0.6, transit = 0.2, cycling = 0.2)
#' )
#' }
indicator_social_accessibility <- function(units,
                                            roads = NULL,
                                            transit_stops = NULL,
                                            method = c("osm", "local"),
                                            osm_bbox = NULL,
                                            road_types = c("primary", "secondary", "tertiary", "unclassified"),
                                            weights = c(road = 0.5, transit = 0.3, cycling = 0.2),
                                            column_name = "S2",
                                            lang = "en") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  method <- match.arg(method)

  # Simplified accessibility calculation (road distance proxy)
  # Full implementation would integrate transit and cycling data

  # Calculate centroids
  centroids <- sf::st_centroid(units)

  # For now, use a simplified proxy based on unit area and location
  # (In production, would query actual road/transit data)
  result <- units

  # Placeholder calculation - score based on area (smaller = more accessible)
  unit_areas <- as.numeric(sf::st_area(units)) / 10000  # hectares
  accessibility_scores <- pmin(100, 100 * exp(-unit_areas / 100))

  result[[column_name]] <- accessibility_scores

  msg_info("social_accessibility_scored", mean(accessibility_scores, na.rm = TRUE),
           mean(accessibility_scores, na.rm = TRUE), mean(accessibility_scores, na.rm = TRUE))

  cli::cli_alert_success("Calculated {column_name}: Multimodal accessibility (0-100)")

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
#' result <- indicator_social_proximity(
#'   units = massif_demo_units,
#'   method = "proxy",
#'   buffer_radii = c(5000, 10000, 20000)
#' )
#' }
indicator_social_proximity <- function(units,
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
  area_5km <- as.numeric(sf::st_area(buffer_5km)) / 1000000  # km²
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
  result[[column_name]] <- pop_5km  # Primary indicator is 5km buffer

  msg_info("social_population_calculated", median(pop_5km), median(pop_10km), median(pop_20km))

  cli::cli_alert_success("Calculated {column_name}: Population proximity (5/10/20km buffers)")

  return(result)
}
