# indicators-air.R
# Air Quality & Microclimate Family (A) Indicators
# MVP v0.3.0 - Multi-Family Indicator Extension

#' @importFrom sf st_buffer st_area st_intersection st_distance st_as_sf
#' @importFrom terra extract
#' @importFrom stats median
#' @keywords internal
NULL

# ==============================================================================
# T048: A1 - Tree Coverage Buffer Index
# ==============================================================================

#' Calculate Tree Coverage Buffer Index (A1)
#'
#' Computes forest coverage percentage within a buffer around each parcel
#' to assess local air quality and microclimate regulation potential.
#'
#' @param units An sf object with forest parcels.
#' @param land_cover A SpatRaster with land cover classification.
#' @param forest_classes Numeric vector. Land cover class codes for forests
#'   (e.g., Corine codes 311, 312, 313). Default c(311, 312, 313).
#' @param buffer_radius Numeric. Buffer radius in meters. Default 1000.
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item A1: Forest coverage percentage (0-100) within buffer.
#'   }
#'
#' @details
#' **Formula**: A1 = (forest_area_in_buffer / total_buffer_area) × 100
#'
#' **Interpretation**:
#' \itemize{
#'   \item 0-20\%: Low forest coverage (poor air quality regulation)
#'   \item 20-50\%: Moderate forest coverage
#'   \item 50-80\%: Good forest coverage
#'   \item 80-100\%: Excellent forest coverage (optimal air quality)
#' }
#'
#' @family air-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#' library(terra)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units[1:10, ]
#'
#' land_cover <- rast("path/to/corine_land_cover.tif")
#'
#' # Calculate A1 with 1km buffer
#' result <- indicator_air_coverage(units, land_cover = land_cover, buffer_radius = 1000)
#' summary(result$A1)
#'
#' # Calculate with 500m buffer
#' result <- indicator_air_coverage(units, land_cover = land_cover, buffer_radius = 500)
#' }
indicator_air_coverage <- function(units,
                                   land_cover,
                                   forest_classes = c(311, 312, 313),
                                   buffer_radius = 1000) {
  # Validate inputs
  validate_sf(units)

  if (!inherits(land_cover, "SpatRaster")) {
    stop("land_cover must be a SpatRaster object", call. = FALSE)
  }

  if (buffer_radius <= 0) {
    stop("buffer_radius must be positive", call. = FALSE)
  }

  # Create buffers around each parcel
  buffers <- sf::st_buffer(units, dist = buffer_radius)

  # Extract land cover classes within each buffer
  coverage_pct <- numeric(nrow(units))

  if (requireNamespace("exactextractr", quietly = TRUE)) {
    # Use exactextractr for efficient zonal statistics
    for (i in seq_len(nrow(units))) {
      # Extract land cover values for this buffer
      lc_values <- exactextractr::exact_extract(land_cover, buffers[i, ], progress = FALSE)[[1]]$value

      if (length(lc_values) > 0) {
        # Count forest pixels
        forest_pixels <- sum(lc_values %in% forest_classes, na.rm = TRUE)
        total_pixels <- sum(!is.na(lc_values))

        # Calculate percentage
        if (total_pixels > 0) {
          coverage_pct[i] <- (forest_pixels / total_pixels) * 100
        } else {
          coverage_pct[i] <- NA_real_
        }
      } else {
        coverage_pct[i] <- NA_real_
      }
    }
  } else {
    # Fallback using terra::extract
    for (i in seq_len(nrow(units))) {
      lc_values <- terra::extract(land_cover, buffers[i, ], ID = FALSE)[, 1]

      if (length(lc_values) > 0) {
        forest_pixels <- sum(lc_values %in% forest_classes, na.rm = TRUE)
        total_pixels <- sum(!is.na(lc_values))

        if (total_pixels > 0) {
          coverage_pct[i] <- (forest_pixels / total_pixels) * 100
        } else {
          coverage_pct[i] <- NA_real_
        }
      } else {
        coverage_pct[i] <- NA_real_
      }
    }
  }

  # A1 score (already 0-100 percentage)
  units$A1 <- coverage_pct

  msg_info("indicator_air_coverage")

  units
}

# ==============================================================================
# T049: A2 - Air Quality Index
# ==============================================================================

#' Calculate Air Quality Index (A2)
#'
#' Computes air quality score using direct ATMO station data (if available)
#' or proxy method based on distance to pollution sources (roads, urban areas).
#'
#' @param units An sf object with forest parcels.
#' @param atmo_data An sf object with ATMO air quality stations (points).
#'   Must contain columns: NO2 (µg/m³), PM10 (µg/m³). Can be NULL.
#' @param roads An sf object with road network (lines). Used for proxy method.
#' @param urban_areas An sf object with urban zones (polygons). Used for proxy method.
#' @param method Character. Method to use:
#'   \itemize{
#'     \item "auto" (default): Use direct if atmo_data available, else proxy
#'     \item "direct": Require ATMO data (error if NULL)
#'     \item "proxy": Use distance-based proxy
#'   }
#'
#' @return The input sf object with added columns:
#'   \itemize{
#'     \item A2: Air quality index (0-100). Higher = better air quality.
#'     \item A2_method: Method used ("direct" or "proxy")
#'   }
#'
#' @details
#' **Direct Method** (ATMO data):
#' - Interpolate NO2 and PM10 from nearest stations
#' - Convert to quality score: low pollution = high score
#'
#' **Proxy Method** (distance-based):
#' - Calculate distance to nearest road and urban area
#' - Far from pollution sources = high score
#'
#' @family air-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units[1:10, ]
#'
#' # Direct method with ATMO data
#' atmo_data <- st_read("path/to/atmo_stations.gpkg")
#' result <- indicator_air_quality(units, atmo_data = atmo_data, method = "direct")
#'
#' # Proxy method
#' roads <- st_read("path/to/roads.gpkg")
#' urban <- st_read("path/to/urban_areas.gpkg")
#' result <- indicator_air_quality(units, roads = roads, urban_areas = urban, method = "proxy")
#' }
indicator_air_quality <- function(units,
                                  atmo_data = NULL,
                                  roads = NULL,
                                  urban_areas = NULL,
                                  method = "auto") {
  # Validate inputs
  validate_sf(units)

  # Auto-detect method
  if (method == "auto") {
    if (!is.null(atmo_data) && inherits(atmo_data, "sf")) {
      method <- "direct"
    } else if (!is.null(roads) || !is.null(urban_areas)) {
      method <- "proxy"
    } else {
      stop("Either atmo_data or roads/urban_areas must be provided", call. = FALSE)
    }
  }

  # Direct method: ATMO station data
  if (method == "direct") {
    if (is.null(atmo_data) || !inherits(atmo_data, "sf")) {
      stop("atmo_data must be an sf object for direct method", call. = FALSE)
    }

    # Check required columns
    if (!all(c("NO2", "PM10") %in% names(atmo_data))) {
      stop("atmo_data must contain columns: NO2, PM10", call. = FALSE)
    }

    # For each parcel, interpolate pollution from nearest stations (simple IDW)
    a2_scores <- numeric(nrow(units))
    parcel_centroids <- sf::st_centroid(units)

    for (i in seq_len(nrow(units))) {
      # Calculate distances to all stations
      distances <- sf::st_distance(parcel_centroids[i, ], atmo_data)[1, ]

      # Inverse distance weighting (nearest 3 stations)
      nearest_idx <- order(distances)[seq_len(min(3, length(distances)))]
      nearest_dist <- as.numeric(distances[nearest_idx])
      nearest_dist[nearest_dist == 0] <- 1 # Avoid division by zero

      weights <- 1 / nearest_dist
      weights <- weights / sum(weights)

      # Weighted average pollution
      NO2_weighted <- sum(atmo_data$NO2[nearest_idx] * weights)
      PM10_weighted <- sum(atmo_data$PM10[nearest_idx] * weights)

      # Convert to quality score (invert pollution)
      # NO2: 0-40 µg/m³ = good (100-0 score)
      # PM10: 0-50 µg/m³ = good (100-0 score)
      NO2_score <- pmin(pmax((40 - NO2_weighted) / 40, 0), 1) * 100
      PM10_score <- pmin(pmax((50 - PM10_weighted) / 50, 0), 1) * 100

      # Average of both pollutants
      a2_scores[i] <- (NO2_score + PM10_score) / 2
    }

    units$A2 <- a2_scores
    units$A2_method <- "direct"
  } else if (method == "proxy") {
    # Proxy method: distance to pollution sources
    if (is.null(roads) && is.null(urban_areas)) {
      stop("Either roads or urban_areas must be provided for proxy method", call. = FALSE)
    }

    parcel_centroids <- sf::st_centroid(units)
    a2_scores <- numeric(nrow(units))

    for (i in seq_len(nrow(units))) {
      scores <- numeric(0)

      # Distance to nearest road
      if (!is.null(roads) && inherits(roads, "sf")) {
        road_dist <- min(sf::st_distance(parcel_centroids[i, ], roads))
        # Normalize: 0m=0, 5000m+=100
        road_score <- pmin(as.numeric(road_dist) / 5000, 1) * 100
        scores <- c(scores, road_score)
      }

      # Distance to nearest urban area
      if (!is.null(urban_areas) && inherits(urban_areas, "sf")) {
        urban_dist <- min(sf::st_distance(parcel_centroids[i, ], urban_areas))
        # Normalize: 0m=0, 10000m+=100
        urban_score <- pmin(as.numeric(urban_dist) / 10000, 1) * 100
        scores <- c(scores, urban_score)
      }

      # Average of available distance scores
      if (length(scores) > 0) {
        a2_scores[i] <- mean(scores)
      } else {
        a2_scores[i] <- 50 # Neutral default
      }
    }

    units$A2 <- a2_scores
    units$A2_method <- "proxy"
  } else {
    stop("method must be 'auto', 'direct', or 'proxy'", call. = FALSE)
  }

  msg_info("indicator_air_quality")

  units
}
