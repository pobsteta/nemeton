# indicators-temporal.R
# Temporal Dynamics Family (T) Indicators
# MVP v0.3.0 - Multi-Family Indicator Extension
# Aligned with tuto 04 methodology (BD Forêt TFV age estimation)

#' @importFrom stats median weighted.mean
#' @keywords internal
NULL

# ==============================================================================
# T038: T1 - Stand Age Index
# ==============================================================================

#' Calculate Stand Age Index (T1)
#'
#' Estimates stand age from BD Forêt TFV (Type de Formation Végétale) field
#' using area-weighted spatial intersection, following tuto 04 methodology.
#' Falls back to direct age field, establishment year, or NDVI proxy.
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object (optional). Used to resolve bdforet.
#' @param bdforet An sf object with BD Forêt V2 polygons. If NULL and layers
#'   provided, resolved from layers.
#' @param age_field Character. Column name with stand age (years). Default "age".
#'   Used as fallback if BD Forêt not available.
#' @param establishment_year_field Character. Column name with establishment year.
#'   Used as fallback if age_field not found.
#' @param current_year Integer. Current year for age calculation from establishment year.
#'   Default uses current system year.
#'
#' @return Numeric vector of estimated age in years (one per parcel).
#'   Default value is 50 when no data available.
#'
#' @details
#' **Primary method** (BD Forêt TFV):
#' \itemize{
#'   \item Spatial intersection of parcels with BD Forêt polygons
#'   \item Age estimated from vegetation type (TFV field):
#'     - Forêt fermée feuillus / Futaie feuillus: 100 years
#'     - Forêt fermée conifères / Futaie conifères: 80 years
#'     - Forêt ouverte / Taillis: 45 years
#'     - Peupleraie: 20 years
#'     - Jeune peuplement / Lande boisée: 15 years
#'     - Other: 50 years (default)
#'   \item Area-weighted average across overlapping polygons
#' }
#'
#' **Fallback methods** (in order):
#' \enumerate{
#'   \item Direct age column in units
#'   \item Establishment year column
#'   \item NDVI-based maturity estimate
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
#' layers <- massif_demo_layers()
#'
#' # Primary method: BD Forêt
#' result <- indicator_temporal_age(massif_demo_units, layers = layers)
#' summary(result)
#'
#' # Direct age field
#' units <- massif_demo_units
#' units$age <- runif(nrow(units), 20, 250)
#' result <- indicator_temporal_age(units, age_field = "age")
#' }
indicator_temporal_age <- function(units,
                                   layers = NULL,
                                   bdforet = NULL,
                                   age_field = "age",
                                   establishment_year_field = NULL,
                                   current_year = NULL) {
  # Validate inputs
  validate_sf(units)

  # --- Priority 1: BD Forêt TFV (tuto 04 method) ---
  if (is.null(bdforet) && !is.null(layers) && inherits(layers, "nemeton_layers")) {
    bdforet <- resolve_vector_layer(layers, "bdforet")
  }

  if (!is.null(bdforet) && inherits(bdforet, "sf") && nrow(bdforet) > 0) {
    # Ensure matching CRS
    if (!identical(sf::st_crs(bdforet), sf::st_crs(units))) {
      bdforet <- sf::st_transform(bdforet, sf::st_crs(units))
    }

    # Find TFV field
    tfv_field <- NULL
    for (field in c("TFV", "tfv", "CODE_TFV", "code_tfv", "ESSENCE", "essence",
                    "LIB_FV", "lib_fv", "LIBELLE", "libelle")) {
      if (field %in% names(bdforet)) {
        tfv_field <- field
        break
      }
    }

    if (!is.null(tfv_field)) {
      cli::cli_alert_info("T1: Using BD For\u00eat field '{tfv_field}' for age estimation")

      age_values <- numeric(nrow(units))

      for (i in seq_len(nrow(units))) {
        inter <- suppressWarnings(
          tryCatch(sf::st_intersection(bdforet, units[i, ]),
                   error = function(e) NULL)
        )

        if (!is.null(inter) && nrow(inter) > 0) {
          inter$..area.. <- as.numeric(sf::st_area(inter))
          inter$..age_est.. <- .estimate_age_tfv(inter[[tfv_field]])

          total_area <- sum(inter$..area..)
          if (total_area > 0) {
            age_values[i] <- sum(inter$..area.. * inter$..age_est..) / total_area
          } else {
            age_values[i] <- 50.0
          }
        } else {
          age_values[i] <- 50.0
        }
      }

      msg_info("indicator_temporal_age")
      return(age_values)
    }
  }

  # --- Priority 2: Direct age field ---
  if (!is.null(age_field) && age_field %in% names(units)) {
    age_values <- units[[age_field]]
    msg_info("indicator_temporal_age")
    return(age_values)
  }

  # --- Priority 3: Establishment year ---
  if (!is.null(establishment_year_field) && establishment_year_field %in% names(units)) {
    if (is.null(current_year)) {
      current_year <- as.integer(format(Sys.Date(), "%Y"))
    }
    age_values <- current_year - units[[establishment_year_field]]
    msg_info("indicator_temporal_age")
    return(age_values)
  }

  # --- Priority 4: NDVI proxy ---
  ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
  if (!is.null(ndvi_raster)) {
    cli::cli_alert_info("T1: No BD For\u00eat or age data; estimating maturity from NDVI")
    ndvi_mean <- safe_extract(ndvi_raster,
      as_pure_sf(units), fun = "mean", progress = FALSE)
    # NDVI 0.2 ~ young (20yr), NDVI 0.8 ~ mature (120yr)
    age_values <- 20 + pmax(0, ndvi_mean - 0.2) / 0.6 * 100
    msg_info("indicator_temporal_age")
    return(age_values)
  }

  # --- Fallback: default 50 ---
  cli::cli_alert_warning("T1: No data available, returning default age (50)")
  rep(50.0, nrow(units))
}


#' Estimate age from BD Forêt TFV (vegetation type) field
#'
#' @param tfv Character vector of TFV values.
#' @return Numeric vector of estimated ages in years.
#' @noRd
.estimate_age_tfv <- function(tfv) {
  tfv_lower <- tolower(as.character(tfv))
  ifelse(grepl("ferm.*feuill|futaie.*feuill", tfv_lower), 100,
    ifelse(grepl("ferm.*conif|futaie.*conif", tfv_lower), 80,
      ifelse(grepl("ouvert|taillis", tfv_lower), 45,
        ifelse(grepl("peupler", tfv_lower), 20,
          ifelse(grepl("jeune|lande.*bois", tfv_lower), 15, 50)
        )
      )
    )
  )
}


# ==============================================================================
# T039: T2 - Stability / Change Rate Index
# ==============================================================================

#' Calculate Stability / Change Rate Index (T2)
#'
#' Measures forest stability using N2 (forest continuity/antiquity) as proxy,
#' following tuto 04 methodology. Falls back to T1 age capped at 100.
#'
#' @param units An sf object with forest parcels. May contain pre-computed
#'   columns: N2 (forest continuity) or T1 (stand age).
#' @param layers A nemeton_layers object (optional). Not directly used but
#'   kept for interface consistency.
#' @param t1_values Numeric vector. Pre-computed T1 age values (same length
#'   as nrow(units)). If NULL and units has no T1 column, T2 defaults to 50.
#'
#' @return Numeric vector of stability scores (0-100).
#'   100 = very stable (ancient forest), 0 = recent change.
#'
#' @details
#' **Primary method**: Use N2 (forest continuity/antiquity) column if present
#' in units. N2 measures continuous forest cover duration, serving as a direct
#' proxy for temporal stability.
#'
#' **Fallback**: Use T1 stand age capped at 100. Older forests are assumed
#' more stable.
#'
#' @family temporal-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units[1:10, ]
#'
#' # Compute T1 first, then T2
#' t1 <- indicator_temporal_age(units, layers = massif_demo_layers())
#' t2 <- indicator_temporal_change(units, t1_values = t1)
#' }
indicator_temporal_change <- function(units,
                                      layers = NULL,
                                      t1_values = NULL) {
  # Validate inputs
  validate_sf(units)

  # --- Priority 1: Use N2 (forest continuity/antiquity) as stability proxy ---
  # N2_anciennete or N2 column from naturalness indicator
  n2_col <- NULL
  for (col in c("N2_anciennete", "N2_anciennet", "N2")) {
    if (col %in% names(units)) {
      n2_col <- col
      break
    }
  }

  if (!is.null(n2_col)) {
    cli::cli_alert_info("T2: Using {n2_col} as stability proxy")
    t2 <- units[[n2_col]]
    # Ensure 0-100 range
    t2 <- pmin(pmax(t2, 0), 100)
    msg_info("indicator_temporal_change")
    return(t2)
  }

  # --- Priority 2: Fallback to T1 age capped at 100 ---
  # Try t1_values argument first
  if (!is.null(t1_values) && is.numeric(t1_values) && length(t1_values) == nrow(units)) {
    cli::cli_alert_info("T2: Estimated from T1 age values")
    t2 <- pmin(100, t1_values)
    t2[is.na(t2)] <- 50
    msg_info("indicator_temporal_change")
    return(t2)
  }

  # Try T1 column in units
  if ("T1" %in% names(units)) {
    cli::cli_alert_info("T2: Estimated from T1 column")
    t2 <- pmin(100, units$T1)
    t2[is.na(t2)] <- 50
    msg_info("indicator_temporal_change")
    return(t2)
  }

  # --- Fallback: default 50 ---
  cli::cli_alert_warning("T2: No N2 or T1 data available, returning default (50)")
  rep(50.0, nrow(units))
}
