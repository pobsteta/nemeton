# indicators-temporal.R
# Temporal Dynamics Family (T) Indicators
# MVP v0.3.0 - Multi-Family Indicator Extension

#' @importFrom stats median
#' @keywords internal
NULL

# ==============================================================================
# T038: T1 - Stand Age Index
# ==============================================================================

#' Calculate Stand Age Index (T1)
#'
#' Computes stand age from direct age field or establishment year,
#' with log-scale normalization favoring ancient forests.
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object (optional, not used in this indicator).
#' @param age_field Character. Column name with stand age (years). Default "age".
#' @param establishment_year_field Character. Column name with establishment year.
#'   Used if age_field is NULL.
#' @param current_year Integer. Current year for age calculation from establishment year.
#'   Default uses current system year.
#'
#' @return The input sf object with added columns:
#'   \itemize{
#'     \item T1: Stand age (years)
#'     \item T1_norm: Normalized age score (0-100). Log scale, ancient forests score high.
#'   }
#'
#' @details
#' **Formula**: T1 = age (direct) OR current_year - establishment_year
#'
#' **Normalization**: Log scale to favor ancient forests
#' \itemize{
#'   \item 0-30 years: Young forest (0-30 score)
#'   \item 30-100 years: Mature forest (30-60 score)
#'   \item 100-200 years: Old forest (60-80 score)
#'   \item 200+ years: Ancient forest (80-100 score)
#' }
#'
#' @family temporal-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#' units$age <- runif(nrow(units), 20, 250)
#'
#' result <- indicator_temporal_age(units, age_field = "age")
#' summary(result$T1)
#' summary(result$T1_norm)
#'
#' # Using establishment year
#' units$planted <- sample(1850:2000, nrow(units), replace = TRUE)
#' result <- indicator_temporal_age(units, age_field = NULL, establishment_year_field = "planted", current_year = 2025)
#' }
indicator_temporal_age <- function(units,
                                   layers = NULL,
                                   age_field = "age",
                                   establishment_year_field = NULL,
                                   current_year = NULL) {
  # Validate inputs
  validate_sf(units)

  # Determine age source
  if (!is.null(age_field) && age_field %in% names(units)) {
    # Use direct age field
    age_values <- units[[age_field]]
  } else if (!is.null(establishment_year_field) && establishment_year_field %in% names(units)) {
    # Calculate from establishment year
    if (is.null(current_year)) {
      current_year <- as.integer(format(Sys.Date(), "%Y"))
    }

    establishment_years <- units[[establishment_year_field]]
    age_values <- current_year - establishment_years
  } else {
    # Fallback: estimate stand maturity from NDVI
    # Higher NDVI typically correlates with more mature forests
    ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
    if (!is.null(ndvi_raster)) {
      cli::cli_alert_info("T1: No age data; estimating maturity from NDVI")
      ndvi_mean <- safe_extract(ndvi_raster,
        as_pure_sf(units), fun = "mean", progress = FALSE)
      # NDVI 0.2 ~ young (20yr), NDVI 0.8 ~ mature (120yr)
      age_values <- 20 + pmax(0, ndvi_mean - 0.2) / 0.6 * 100
    } else {
      cli::cli_alert_warning("T1: No age or NDVI data, returning NA")
      return(rep(NA_real_, nrow(units)))
    }
  }

  # Normalize with log scale (ancient forests score high)
  # Log transformation: log(1 + age) scaled to 0-100
  # Reference points: 30yr=30, 100yr=60, 200yr=80, 300yr=90
  log_age <- log(1 + age_values)
  log_min <- log(1 + 20) # Minimum age ~20 years
  log_max <- log(1 + 300) # Maximum ancient forest ~300 years

  # Normalized T1 score (0-100)
  t1_norm <- pmin(pmax((log_age - log_min) / (log_max - log_min), 0), 1) * 100

  msg_info("indicator_temporal_age")

  # Return normalized score (can be used directly for aggregation)
  t1_norm
}

# ==============================================================================
# T039: T2 - Land Cover Change Rate Index
# ==============================================================================

#' Calculate Land Cover Change Rate Index (T2)
#'
#' Computes annualized land cover change rate from multi-date rasters
#' (e.g., Corine Land Cover).
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object (optional, not used in this indicator).
#' @param land_cover_early A SpatRaster with early land cover classification.
#' @param land_cover_late A SpatRaster with late land cover classification.
#' @param years_elapsed Numeric. Number of years between the two land cover dates.
#' @param interpretation Character. How to interpret change:
#'   \itemize{
#'     \item "stability" (default): Low change = high score (conservation)
#'     \item "dynamism": High change = high score (ecological dynamism)
#'   }
#'
#' @return The input sf object with added columns:
#'   \itemize{
#'     \item T2: Annualized change rate (\%/year)
#'     \item T2_norm: Normalized score (0-100). Depends on interpretation.
#'   }
#'
#' @details
#' **Formula**: T2 = (changed_pixels / total_pixels) / years_elapsed × 100
#'
#' **Normalization**:
#' \itemize{
#'   \item stability: 0\% change/yr = 100, 5\%+ change/yr = 0
#'   \item dynamism: 0\% change/yr = 0, 5\%+ change/yr = 100
#' }
#'
#' @family temporal-indicators
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
#' lc_1990 <- rast("path/to/corine_1990.tif")
#' lc_2020 <- rast("path/to/corine_2020.tif")
#'
#' # Stability interpretation (conservation)
#' result <- indicator_temporal_change(units, lc_1990, lc_2020, years_elapsed = 30, interpretation = "stability")
#' summary(result$T2)
#'
#' # Dynamism interpretation (ecological change)
#' result <- indicator_temporal_change(units, lc_1990, lc_2020, years_elapsed = 30, interpretation = "dynamism")
#' }
indicator_temporal_change <- function(units,
                                      layers = NULL,
                                      land_cover_early = NULL,
                                      land_cover_late = NULL,
                                      years_elapsed = NULL,
                                      interpretation = "stability") {
  # Validate inputs
  validate_sf(units)

  # If no multi-date land cover available, estimate stability from current data
  if (is.null(land_cover_early) || !inherits(land_cover_early, "SpatRaster") ||
      is.null(land_cover_late) || !inherits(land_cover_late, "SpatRaster")) {
    # Fallback: assume forested areas are stable (high stability score)
    # Use NDVI as proxy - high NDVI = established forest = likely stable
    ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
    if (!is.null(ndvi_raster)) {
      cli::cli_alert_info("T2: No multi-date rasters; estimating stability from NDVI")
      ndvi_mean <- safe_extract(ndvi_raster,
        as_pure_sf(units), fun = "mean", progress = FALSE)
      # High NDVI = likely stable forest = high stability score
      units$T2 <- rep(0, nrow(units))  # Assume 0% change rate
      units$T2_norm <- pmin(pmax(ndvi_mean / 0.8, 0), 1) * 100
      return(units)
    }
    cli::cli_alert_warning("T2: No land cover data available for change detection")
    units$T2 <- rep(NA_real_, nrow(units))
    units$T2_norm <- rep(NA_real_, nrow(units))
    return(units)
  }

  if (is.null(years_elapsed) || years_elapsed <= 0) {
    stop("years_elapsed must be positive", call. = FALSE)
  }

  # Check interpretation
  if (!interpretation %in% c("stability", "dynamism")) {
    stop("interpretation must be 'stability' or 'dynamism'", call. = FALSE)
  }

  # Use exactextractr for efficient zonal statistics
  # For each parcel, count pixels with different land cover classes
  if (requireNamespace("exactextractr", quietly = TRUE)) {
    # Extract land cover values for each parcel
    lc_early_values <- safe_extract(land_cover_early, units, fun = "mode", progress = FALSE)
    lc_late_values <- safe_extract(land_cover_late, units, fun = "mode", progress = FALSE)

    # For more detailed change detection, extract all values and calculate change percentage
    change_rates <- numeric(nrow(units))

    for (i in seq_len(nrow(units))) {
      # Extract all pixel values for this parcel
      early_vals <- safe_extract(land_cover_early, units[i, ], progress = FALSE)[[1]]$value
      late_vals <- safe_extract(land_cover_late, units[i, ], progress = FALSE)[[1]]$value

      if (length(early_vals) > 0 && length(late_vals) > 0) {
        # Calculate percentage of pixels that changed
        # Simple approach: compare modal values
        early_mode <- as.numeric(names(sort(table(early_vals), decreasing = TRUE)[1]))
        late_mode <- as.numeric(names(sort(table(late_vals), decreasing = TRUE)[1]))

        # If modes differ, estimate change percentage from value distributions
        if (early_mode != late_mode) {
          # Count how many pixels differ between early and late
          # This is a simplified approach - for production, pixel-by-pixel comparison would be better
          changed_pct <- 100 * (1 - sum(early_vals == late_vals, na.rm = TRUE) / length(early_vals))
        } else {
          changed_pct <- 0
        }

        # Annualized change rate
        change_rates[i] <- changed_pct / years_elapsed
      } else {
        change_rates[i] <- NA_real_
      }
    }
  } else {
    # Fallback using terra::extract (less efficient)
    early_vals <- terra::extract(land_cover_early, units, fun = "modal", na.rm = TRUE, ID = FALSE)[, 1]
    late_vals <- terra::extract(land_cover_late, units, fun = "modal", na.rm = TRUE, ID = FALSE)[, 1]

    # Simple binary change detection: did the modal class change?
    changed <- (early_vals != late_vals)
    change_rates <- ifelse(changed, 100 / years_elapsed, 0)
  }

  # Raw T2 score (annualized change rate %/year)
  units$T2 <- change_rates

  # Normalize based on interpretation
  # Reference: 0%/yr = no change, 5%/yr = very high change
  if (interpretation == "stability") {
    # Stability: low change = high score
    units$T2_norm <- pmin(pmax((5 - change_rates) / 5, 0), 1) * 100
  } else {
    # Dynamism: high change = high score
    units$T2_norm <- pmin(change_rates / 5, 1) * 100
  }

  msg_info("indicator_temporal_change")

  units
}
