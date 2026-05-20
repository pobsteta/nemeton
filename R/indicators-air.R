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
#'   Required in legacy mode; may be \code{NULL} when \code{fvc} is
#'   supplied.
#' @param forest_classes Numeric vector. Land cover class codes for forests
#'   (OSO codes: 16 = coniferous, 17 = broadleaf, 18 = mixed).
#'   Default c(16, 17, 18).
#' @param buffer_radius Numeric. Buffer radius in meters. Default 1000.
#' @param fvc Optional \code{SpatRaster} of Fractional Vegetation
#'   Cover in \code{[0, 1]} (typically the Theia
#'   \code{s2_biophysical} FVC product, loaded via
#'   \code{\link{load_raster_source}}). When supplied, activates
#'   FVC mode: A1 is the per-buffer mean FVC rescaled to a 0-100
#'   percentage, and \code{land_cover} is ignored. The raster is
#'   expected in the CRS of \code{units}.
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item A1: Forest coverage percentage (0-100) within buffer.
#'   }
#'
#' @details
#' **Formula** (legacy mode): A1 = (forest_area_in_buffer / total_buffer_area) × 100
#'
#' **FVC mode** (Theia \code{s2_biophysical}, phase 3a): A1 = mean(FVC) × 100
#' over the buffer.
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
#' result <- indicateur_a1_couverture(units, land_cover = land_cover, buffer_radius = 1000)
#' summary(result$A1)
#'
#' # Calculate with 500m buffer
#' result <- indicateur_a1_couverture(units, land_cover = land_cover, buffer_radius = 500)
#' }
indicateur_a1_couverture <- function(units,
                                   land_cover = NULL,
                                   forest_classes = c(16, 17, 18),
                                   buffer_radius = 1000,
                                   fvc = NULL) {
  # Validate inputs
  validate_sf(units)

  if (buffer_radius <= 0) {
    stop("buffer_radius must be positive", call. = FALSE)
  }

  # Create buffers around each parcel
  buffers <- sf::st_buffer(units, dist = buffer_radius)

  # --- FVC mode (Theia s2_biophysical, phase 3a) ----------------
  if (!is.null(fvc)) {
    if (!inherits(fvc, "SpatRaster")) {
      stop("fvc must be a SpatRaster object", call. = FALSE)
    }
    cli::cli_alert_info("A1: tree coverage from FVC (Theia s2_biophysical)")
    fvc_mean <- safe_extract(
      fvc,
      as_pure_sf(buffers),
      fun = "mean",
      progress = FALSE
    )
    units$A1 <- fvc_mean * 100
    msg_info("indicateur_a1_couverture")
    return(units)
  }

  # Legacy mode requires a land-cover raster
  if (!inherits(land_cover, "SpatRaster")) {
    stop("land_cover must be a SpatRaster object", call. = FALSE)
  }

  # Extract land cover classes within each buffer
  coverage_pct <- numeric(nrow(units))

  if (requireNamespace("exactextractr", quietly = TRUE)) {
    # Use exactextractr for efficient zonal statistics
    for (i in seq_len(nrow(units))) {
      # Extract land cover values for this buffer
      lc_values <- safe_extract(land_cover, buffers[i, ], progress = FALSE)[[1]]$value

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

  msg_info("indicateur_a1_couverture")

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
#' @param layers A nemeton_layers object. If provided, roads are extracted
#'   from the "roads" vector layer when the `roads` parameter is NULL.
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
#' result <- indicateur_a2_qualite_air(units, atmo_data = atmo_data, method = "direct")
#'
#' # Proxy method
#' roads <- st_read("path/to/roads.gpkg")
#' urban <- st_read("path/to/urban_areas.gpkg")
#' result <- indicateur_a2_qualite_air(units, roads = roads, urban_areas = urban, method = "proxy")
#' }
indicateur_a2_qualite_air <- function(units,
                                  layers = NULL,
                                  atmo_data = NULL,
                                  roads = NULL,
                                  urban_areas = NULL,
                                  method = "auto") {
  # Validate inputs
  validate_sf(units)

  # Extract roads from layers if not provided directly
  if (is.null(roads) && !is.null(layers)) {
    roads <- resolve_vector_layer(layers, "roads")
  }

  # Harmonize CRS: project roads and atmo_data to same CRS as units
  if (!is.null(roads) && inherits(roads, "sf")) {
    if (!identical(sf::st_crs(roads), sf::st_crs(units))) {
      roads <- sf::st_transform(roads, sf::st_crs(units))
    }
  }
  if (!is.null(atmo_data) && inherits(atmo_data, "sf")) {
    if (!identical(sf::st_crs(atmo_data), sf::st_crs(units))) {
      atmo_data <- sf::st_transform(atmo_data, sf::st_crs(units))
    }
  }

  # Auto-detect method
  if (method == "auto") {
    if (!is.null(atmo_data) && inherits(atmo_data, "sf")) {
      method <- "direct"
    } else if (!is.null(roads)) {
      method <- "proxy"
    } else {
      # No data available at all - return neutral score
      cli::cli_alert_warning("A2: No ATMO data or roads available, returning neutral score")
      units$A2 <- rep(50, nrow(units))
      units$A2_method <- "none"
      return(units)
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
    parcel_centroids <- suppressWarnings(sf::st_centroid(units))

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
    # Proxy method: weighted pollution from roads (tuto 02, exercice 9.2)
    if (is.null(roads)) {
      stop("roads must be provided for proxy method", call. = FALSE)
    }

    # Pollution weights by BD TOPO v3 `nature` field
    pollution_weights <- c(
      "autoroute"          = 1.0,
      "type autoroutier"   = 1.0,
      "quasi-autoroute"    = 0.9,
      "route.*2 chauss"    = 0.8,
      "bretelle"           = 0.7,
      "route.*1 chauss"    = 0.6,
      "rond-point"         = 0.5,
      "route empierr"      = 0.3,
      "chemin"             = 0.1,
      "piste cyclable"     = 0.05,
      "sentier"            = 0.02,
      "escalier"           = 0.02
    )

    # Assign weight to each road segment based on road type field
    # Try multiple possible field names (BD TOPO v3: "nature", demo data: "road_type", etc.)
    nature_field <- NULL
    for (field in c("nature", "NATURE", "classe", "importance", "type", "road_type")) {
      if (field %in% names(roads)) {
        nature_field <- field
        break
      }
    }
    if (!is.null(nature_field)) {
      road_nature <- tolower(roads[[nature_field]])
      road_w <- rep(0.5, nrow(roads))  # default weight
      for (j in seq_along(pollution_weights)) {
        matched <- grepl(names(pollution_weights)[j], road_nature, ignore.case = TRUE)
        road_w[matched] <- pollution_weights[j]
      }
    } else {
      road_w <- rep(0.5, nrow(roads))
    }

    parcel_centroids <- suppressWarnings(sf::st_centroid(units))

    # Compute pollution score per parcel
    pollution_scores <- numeric(nrow(units))

    for (i in seq_len(nrow(units))) {
      dists <- as.numeric(sf::st_distance(parcel_centroids[i, ], roads))
      # Keep roads within 2000m
      within <- dists < 2000
      if (any(within)) {
        d <- pmax(dists[within], 10)  # minimum 10m to avoid extreme values
        w <- road_w[within]
        pollution_scores[i] <- sum(w / (d / 100)^2)
      } else {
        pollution_scores[i] <- 0
      }
    }

    # Normalize across all parcels using log transform
    max_score <- max(pollution_scores, na.rm = TRUE)
    if (max_score > 0) {
      pollution_norm <- log1p(pollution_scores) / log1p(max_score)
    } else {
      pollution_norm <- rep(0, nrow(units))
    }

    # A2: higher = better air quality (invert pollution)
    units$A2 <- round(pmin(pmax((1 - pollution_norm) * 100, 0), 100), 1)
    units$A2_method <- "proxy"
  } else {
    stop("method must be 'auto', 'direct', or 'proxy'", call. = FALSE)
  }

  msg_info("indicateur_a2_qualite_air")

  units
}
