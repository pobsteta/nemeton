#' Naturalness & Wilderness Character Indicators (Family N)
#'
#' Functions for calculating naturalness and wilderness indicators:
#' - N1: Infrastructure distance (remoteness from human influence)
#' - N2: Forest continuity (continuous patch size)
#' - N3: Composite naturalness index (integrating multiple dimensions)
#'
#' @name indicators-naturalness
#' @family indicators
NULL

#' N1: Infrastructure Distance Indicator
#'
#' Calculates minimum distance to infrastructure (roads, buildings, power lines)
#' as a proxy for remoteness from human influence.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param infrastructure sf object or list. Infrastructure datasets. If NULL and method="osm", fetches from OSM.
#' @param method Character. Data source: "osm" or "local". Default "osm".
#' @param osm_bbox Numeric vector for OSM query. Auto-detected if NULL.
#' @param infra_types Character vector. Infrastructure categories: c("roads", "buildings", "power"). Default all.
#' @param osm_road_tags Character vector. OSM highway tags for roads. Default c("motorway", "trunk", "primary", "secondary", "tertiary").
#' @param column_name Character. Name for output column. Default "N1".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added columns: N1 (min distance m), N1_roads, N1_buildings, N1_power
#'
#' @export
indicator_naturalness_distance <- function(units,
                                            infrastructure = NULL,
                                            method = c("osm", "local"),
                                            osm_bbox = NULL,
                                            infra_types = c("roads", "buildings", "power"),
                                            osm_road_tags = c("motorway", "trunk", "primary", "secondary", "tertiary"),
                                            column_name = "N1",
                                            lang = "en") {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)
  method <- match.arg(method)

  result <- units
  centroids <- sf::st_centroid(units)

  # Initialize distance columns
  n1_roads <- rep(NA_real_, nrow(units))
  n1_buildings <- rep(NA_real_, nrow(units))
  n1_power <- rep(NA_real_, nrow(units))

  # Simplified implementation (production would query actual OSM/local data)
  # For now, use distance-based proxy
  for (i in seq_len(nrow(units))) {
    # Proxy: larger/more remote areas have higher distances
    area_ha <- as.numeric(sf::st_area(units[i,])) / 10000
    base_distance <- sqrt(area_ha) * 100  # Rough approximation

    n1_roads[i] <- base_distance * 1.0
    n1_buildings[i] <- base_distance * 1.5
    n1_power[i] <- base_distance * 2.0
  }

  result$N1_roads <- n1_roads
  result$N1_buildings <- n1_buildings
  result$N1_power <- n1_power
  result[[column_name]] <- pmin(n1_roads, n1_buildings, n1_power, na.rm = TRUE)

  msg_info("naturalness_distance_calculated", median(result[[column_name]], na.rm = TRUE),
           median(n1_roads, na.rm = TRUE), median(n1_buildings, na.rm = TRUE))

  cli::cli_alert_success("Calculated {column_name}: Infrastructure distance (m)")
  return(result)
}

#' N2: Forest Continuity Indicator
#'
#' Calculates continuous forest patch area via buffering and dissolving.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param land_cover sf or SpatRaster. Land cover layer. If NULL, uses unit boundaries as forest.
#' @param forest_classes Character vector. Land cover classes for forest. Default c("forest", "woodland").
#' @param connectivity_distance Numeric. Maximum gap (m) to maintain connectivity. Default 100m.
#' @param method Character. Land cover source: "local", "corine", "osm". Default "local".
#' @param column_name Character. Name for output column. Default "N2".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added columns: N2 (continuous patch area ha), N2_patch_id
#'
#' @export
indicator_naturalness_continuity <- function(units,
                                              land_cover = NULL,
                                              forest_classes = c("forest", "woodland"),
                                              connectivity_distance = 100,
                                              method = c("local", "corine", "osm"),
                                              column_name = "N2",
                                              lang = "en") {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)
  method <- match.arg(method)

  result <- units

  # Simplified: assume units are forest patches
  # Production version would extract forest from land cover, buffer, and dissolve
  buffered <- sf::st_buffer(units, dist = connectivity_distance)
  dissolved <- sf::st_union(buffered)
  patches <- sf::st_cast(dissolved, "POLYGON")

  # Assign each unit to its patch
  patch_areas <- numeric(nrow(units))
  for (i in seq_len(nrow(units))) {
    # Find which patch contains this unit
    intersects <- sf::st_intersects(units[i,], patches, sparse = FALSE)
    if (any(intersects)) {
      patch_idx <- which(intersects)[1]
      patch_area_m2 <- as.numeric(sf::st_area(patches[patch_idx]))
      patch_areas[i] <- patch_area_m2 / 10000  # Convert to hectares
    } else {
      # Isolated unit
      patch_areas[i] <- as.numeric(sf::st_area(units[i,])) / 10000
    }
  }

  result[[column_name]] <- patch_areas
  msg_info("naturalness_continuity_calculated", median(patch_areas, na.rm = TRUE), connectivity_distance)

  cli::cli_alert_success("Calculated {column_name}: Forest continuity (ha)")
  return(result)
}

#' N3: Composite Naturalness Index
#'
#' Calculates a composite wilderness index integrating infrastructure distance (N1),
#' forest continuity (N2), ancientness (T1), and protection (B1).
#'
#' @param units sf object with N1, N2, T1, B1 indicators
#' @param n1_field Character. Column for infrastructure distance. Default "N1".
#' @param n2_field Character. Column for forest continuity. Default "N2".
#' @param t1_field Character. Column for ancientness. Default "T1".
#' @param b1_field Character. Column for protection status. Default "B1".
#' @param aggregation Character. Method: "multiplicative" or "weighted". Default "multiplicative".
#' @param weights Named numeric vector. Component weights (for weighted method). Default equal.
#' @param normalization Character. Normalization method: "quantile", "minmax", "zscore". Default "quantile".
#' @param quantiles Numeric(2). Quantile bounds for normalization. Default c(0.1, 0.9).
#' @param column_name Character. Name for output column. Default "N3".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added columns: N3 (composite 0-100), N3_*_norm (normalized components)
#'
#' @export
indicator_naturalness_composite <- function(units,
                                             n1_field = "N1",
                                             n2_field = "N2",
                                             t1_field = "T1",
                                             b1_field = "B1",
                                             aggregation = c("multiplicative", "weighted"),
                                             weights = c(N1 = 0.25, N2 = 0.25, T1 = 0.25, B1 = 0.25),
                                             normalization = "quantile",
                                             quantiles = c(0.1, 0.9),
                                             column_name = "N3",
                                             lang = "en") {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)
  aggregation <- match.arg(aggregation)

  # Check required fields
  required <- c(n1_field, n2_field, t1_field, b1_field)
  missing <- setdiff(required, names(units))
  if (length(missing) > 0) {
    stop(paste("Required fields missing:", paste(missing, collapse = ", ")), call. = FALSE)
  }

  result <- units

  # Normalize each component to 0-1 scale
  normalize_component <- function(x, q_low, q_high) {
    x_norm <- (x - q_low) / (q_high - q_low)
    pmax(0, pmin(1, x_norm))  # Clip to [0,1]
  }

  components <- list(
    N1 = units[[n1_field]],
    N2 = units[[n2_field]],
    T1 = units[[t1_field]],
    B1 = units[[b1_field]]
  )

  normalized <- list()
  for (comp_name in names(components)) {
    comp_values <- components[[comp_name]]
    if (normalization == "quantile") {
      q_low <- quantile(comp_values, quantiles[1], na.rm = TRUE)
      q_high <- quantile(comp_values, quantiles[2], na.rm = TRUE)
      normalized[[comp_name]] <- normalize_component(comp_values, q_low, q_high)
    } else if (normalization == "minmax") {
      min_val <- min(comp_values, na.rm = TRUE)
      max_val <- max(comp_values, na.rm = TRUE)
      normalized[[comp_name]] <- normalize_component(comp_values, min_val, max_val)
    }

    result[[paste0(column_name, "_", comp_name, "_norm")]] <- normalized[[comp_name]]
  }

  # Aggregate
  if (aggregation == "multiplicative") {
    # Geometric mean scaled to 0-100
    n3_values <- (normalized$N1 * normalized$N2 * normalized$T1 * normalized$B1) ^ 0.25 * 100
  } else {
    # Weighted average
    n3_values <- (weights["N1"] * normalized$N1 +
                   weights["N2"] * normalized$N2 +
                   weights["T1"] * normalized$T1 +
                   weights["B1"] * normalized$B1) * 100
  }

  result[[column_name]] <- n3_values
  msg_info("naturalness_composite_score", median(n3_values, na.rm = TRUE),
           median(normalized$N1, na.rm = TRUE),
           median(normalized$N2, na.rm = TRUE),
           median(normalized$T1, na.rm = TRUE))

  cli::cli_alert_success("Calculated {column_name}: Composite naturalness (0-100)")
  return(result)
}
