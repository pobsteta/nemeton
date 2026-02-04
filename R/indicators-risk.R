# indicators-risk.R
# Risk & Resilience Family (R) Indicators
# Aligned with tuto 03 methodology (fireexposuR, microclima, SPEI)

#' @importFrom terra terrain extract rasterize global clamp
#' @importFrom sf st_centroid st_distance st_transform st_coordinates
#' @importFrom stats median weighted.mean ts
#' @keywords internal
NULL

# ==============================================================================
# T031: R1 - Fire Risk Index
# ==============================================================================

#' Calculate Fire Risk Index (R1)
#'
#' Computes fire risk using fire exposure analysis from BD Foret fuel mapping
#' (via \pkg{fireexposuR}). Falls back to slope + species + climate method
#' when \pkg{fireexposuR} or BD Foret data is unavailable.
#'
#' @param units An sf object with forest parcels.
#' @param dem A SpatRaster with digital elevation model (meters).
#' @param layers A nemeton_layers object. Used to extract DEM and BD Foret.
#' @param bdforet An sf object with BD Foret V2 polygons, or NULL.
#' @param species_field Character. Column name with species names (fallback only).
#' @param climate List with 'temperature' and 'precipitation' SpatRasters,
#'   or NULL (fallback only).
#' @param weights Named numeric vector. Weights for fallback components:
#'   c(slope, species, climate). Default c(1/3, 1/3, 1/3).
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item R1: Fire risk index (0-100). Higher = higher risk.
#'   }
#'
#' @details
#' **Primary method** (requires \pkg{fireexposuR} + BD Foret):
#' Rasterizes BD Foret as a hazard layer, then computes fire exposure
#' with a 500m transmission distance. The 0-1 exposure is scaled to 0-100.
#'
#' **Fallback method**: R1 = w1*slope + w2*species_flammability + w3*climate_dryness
#'
#' @family risk-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#' library(terra)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#'
#' dem <- rast("path/to/dem.tif")
#' result <- indicator_risk_fire(units, dem = dem)
#' summary(result$R1)
#' }
indicator_risk_fire <- function(units,
                                dem = NULL,
                                layers = NULL,
                                bdforet = NULL,
                                species_field = "species",
                                climate = NULL,
                                weights = c(slope = 1 / 3, species = 1 / 3, climate = 1 / 3)) {
  # Validate inputs
  validate_sf(units)

  # Extract DEM from layers if not provided directly (prefer LiDAR HD MNT)
  if (is.null(dem) && !is.null(layers)) {
    dem <- get_dem_raster(layers)
  }

  if (is.null(dem) || !inherits(dem, "SpatRaster")) {
    cli::cli_alert_warning("R1: No DEM available for fire risk, returning NA")
    units$R1 <- rep(NA_real_, nrow(units))
    return(units)
  }

  # Resolve BD Foret from layers if not provided directly
  if (is.null(bdforet) && !is.null(layers)) {
    bdforet <- resolve_vector_layer(layers, "bdforet")
  }

  # --- Primary method: fireexposuR + BD Foret ---
  has_fireexposur <- requireNamespace("fireexposuR", quietly = TRUE)
  if (has_fireexposur && !is.null(bdforet) && inherits(bdforet, "sf") && nrow(bdforet) > 0) {
    tryCatch({
      cli::cli_alert_info("R1: Using fireexposuR with BD For\u00eat hazard layer")
      # Rasterize BD Foret onto DEM grid: forest = 1 (fuel), non-forest = 0
      hazard <- terra::rasterize(terra::vect(bdforet), dem, field = 1, background = 0)
      # Fire exposure with 500m transmission distance
      exposure <- fireexposuR::fire_exp(hazard, t_dist = 500)
      # Extract mean exposure per parcel (0-1 scale)
      exposure_mean <- safe_extract(exposure,
        as_pure_sf(units), fun = "mean", progress = FALSE)
      units$R1 <- pmin(pmax(exposure_mean * 100, 0), 100)
      msg_info("indicator_risk_fire")
      return(units)
    }, error = function(e) {
      cli::cli_alert_warning("R1: fireexposuR failed ({e$message}), using fallback")
    })
  }

  # --- Fallback method: slope + species + climate ---
  if (!has_fireexposur || is.null(bdforet)) {
    cli::cli_alert_info("R1: Using fallback method (slope + species + climate)")
  }

  # Normalize weights
  weights <- weights / sum(weights)

  # Component 1: Slope factor
  slope_raster <- terra::terrain(dem, v = "slope", unit = "degrees")
  slope_values <- safe_extract(slope_raster,
    as_pure_sf(units), fun = "mean", progress = FALSE)
  slope_factor <- pmin(slope_values / 30, 1) * 100

  # Component 2: Species flammability (or NDVI-based proxy)
  if (species_field %in% names(units)) {
    species <- units[[species_field]]
    species_factor <- get_species_flammability(species)
  } else {
    ndvi_raster_r1 <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
    if (!is.null(ndvi_raster_r1)) {
      ndvi_mean <- safe_extract(ndvi_raster_r1,
        as_pure_sf(units), fun = "mean", progress = FALSE)
      species_factor <- pmax(0, pmin(100, 100 - ndvi_mean * 100))
    } else {
      species_factor <- rep(50, nrow(units))
    }
    weights["slope"] <- weights["slope"] + weights["species"] / 2
    weights["climate"] <- weights["climate"] + weights["species"] / 2
    weights["species"] <- 0
  }

  # Component 3: Climate dryness (if available)
  if (!is.null(climate) && all(c("temperature", "precipitation") %in% names(climate))) {
    temp_values <- terra::extract(climate$temperature, units, fun = mean, na.rm = TRUE, ID = FALSE)[, 1]
    precip_values <- terra::extract(climate$precipitation, units, fun = mean, na.rm = TRUE, ID = FALSE)[, 1]
    temp_norm <- pmin(pmax((temp_values - 8) / 8, 0), 1) * 100
    precip_norm <- pmin(pmax((1400 - precip_values) / 900, 0), 1) * 100
    climate_factor <- (temp_norm + precip_norm) / 2
  } else {
    climate_factor <- rep(50, nrow(units))
    weights["slope"] <- weights["slope"] + weights["climate"] / 2
    weights["species"] <- weights["species"] + weights["climate"] / 2
    weights["climate"] <- 0
  }

  # Renormalize weights
  total_w <- sum(weights)
  if (total_w > 0) weights <- weights / total_w

  # Composite R1
  units$R1 <- weights["slope"] * slope_factor +
    weights["species"] * species_factor +
    weights["climate"] * climate_factor

  units$R1 <- pmin(pmax(units$R1, 0), 100)
  msg_info("indicator_risk_fire")
  units
}

# ==============================================================================
# T032: R2 - Storm Vulnerability Index
# ==============================================================================

#' Calculate Storm Vulnerability Index (R2)
#'
#' Computes storm vulnerability using wind shelter coefficient from
#' \pkg{microclima}. Falls back to DEM-derived terrain exposure when
#' \pkg{microclima} is unavailable.
#'
#' @param units An sf object with forest parcels.
#' @param dem A SpatRaster with digital elevation model (meters).
#' @param layers A nemeton_layers object. Used to extract DEM if
#'   \code{dem} is NULL.
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item R2: Storm vulnerability (0-100). Higher = more vulnerable.
#'   }
#'
#' @details
#' **Primary method** (requires \pkg{microclima}):
#' Uses \code{microclima::windcoef()} to compute wind shelter coefficient
#' from the DEM. Dominant wind direction is obtained from NASA POWER
#' climatology (\pkg{nasapower}), defaulting to 270 degrees (west) for France.
#' R2 = (1 - shelter_coef) * 100.
#'
#' **Fallback method** (DEM terrain derivatives):
#' Combines aspect-wind alignment, slope, and terrain ruggedness (TRI):
#' R2 = wind_exposure * (0.6 * slope_norm + 0.4 * TRI_norm) * 100.
#'
#' @family risk-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#' dem <- rast("path/to/dem.tif")
#'
#' result <- indicator_risk_storm(units, dem = dem)
#' summary(result$R2)
#' }
indicator_risk_storm <- function(units,
                                 dem = NULL,
                                 layers = NULL) {
  # Validate inputs
  validate_sf(units)

  # Extract DEM from layers if not provided directly (prefer LiDAR HD MNT)
  if (is.null(dem) && !is.null(layers)) {
    dem <- get_dem_raster(layers)
  }

  if (is.null(dem) || !inherits(dem, "SpatRaster")) {
    cli::cli_alert_warning("R2: No DEM available for storm risk, returning NA")
    units$R2 <- rep(NA_real_, nrow(units))
    return(units)
  }

  # --- Get dominant wind direction (cached) ---
  wind_dir <- get_nasapower_wind(units, default_dir = 270)

  # --- Primary method: microclima::windcoef ---
  if (suppressWarnings(requireNamespace("microclima", quietly = TRUE))) {
    tryCatch({
      cli::cli_alert_info("R2: Using microclima::windcoef (wind direction = {wind_dir}\u00b0)")
      shelter_coef <- microclima::windcoef(
        dsm = dem,
        direction = wind_dir,
        hgt = 10,
        reso = terra::res(dem)[1]
      )
      # Vulnerability = 1 - shelter (exposed sites have low shelter)
      r2_raster <- 1 - shelter_coef
      r2_mean <- safe_extract(r2_raster,
        as_pure_sf(units), fun = "mean", progress = FALSE)
      units$R2 <- pmin(pmax(r2_mean * 100, 0), 100)
      msg_info("indicator_risk_storm")
      return(units)
    }, error = function(e) {
      cli::cli_alert_warning("R2: microclima failed ({e$message}), using terrain fallback")
    })
  }

  # --- Fallback method: DEM terrain derivatives ---
  cli::cli_alert_info("R2: Using terrain fallback (aspect + slope + TRI)")

  aspect <- terra::terrain(dem, v = "aspect", unit = "degrees")
  pente <- terra::terrain(dem, v = "slope", unit = "degrees")
  tri <- terra::terrain(dem, v = "TRI")

  # Wind exposure: max when aspect is aligned with wind direction
  diff_angle <- abs(aspect - wind_dir)
  diff_angle <- terra::app(terra::sds(diff_angle, 360 - diff_angle), fun = "min")
  expo_vent <- 1 - (diff_angle / 180)

  # Normalize slope: 0-45 degrees -> 0-1
  pente_norm <- terra::clamp(pente / 45, lower = 0, upper = 1)

  # Normalize TRI
  tri_max <- terra::global(tri, "max", na.rm = TRUE)$max
  if (is.na(tri_max) || tri_max == 0) tri_max <- 1
  tri_norm <- terra::clamp(tri / tri_max, lower = 0, upper = 1)

  # Composite: wind exposure modulated by terrain steepness/roughness
  r2_raster <- expo_vent * (0.6 * pente_norm + 0.4 * tri_norm)

  r2_mean <- safe_extract(r2_raster,
    as_pure_sf(units), fun = "mean", progress = FALSE)
  units$R2 <- pmin(pmax(r2_mean * 100, 0), 100)
  msg_info("indicator_risk_storm")
  units
}

# ==============================================================================
# T033: R3 - Drought Stress Index
# ==============================================================================

#' Calculate Drought Stress Index (R3)
#'
#' Computes drought stress combining a climate component (SPEI-3 index)
#' and a topographic modulation (aspect, slope, TWI). Falls back to
#' topographic-only assessment when \pkg{SPEI} is unavailable.
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object. Used to extract DEM.
#' @param dem A SpatRaster with digital elevation model (meters).
#' @param climate_data Optional list with \code{precip} (monthly precipitation
#'   vector in mm) and \code{temp} (list with \code{tmin} and \code{tmax}
#'   monthly vectors in degrees C). If NULL, uses simulated data.
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item R3: Drought stress (0-100). Higher = higher stress.
#'   }
#'
#' @details
#' **Climate component** (weight 0.6):
#' Uses SPEI-3 (Standardised Precipitation-Evapotranspiration Index at 3-month
#' scale) via \pkg{SPEI}. PET is computed with the Hargreaves method.
#' R3_climat = (-SPEI_recent + 2) / 4, clamped to 0-1.
#' Falls back to 0.5 without \pkg{SPEI}.
#'
#' **Topographic component** (weight 0.4):
#' \itemize{
#'   \item aspect_risk: south-facing = max risk
#'   \item slope_risk: steep slopes = runoff = dry
#'   \item twi_risk: low TWI = dry
#' }
#' topo_risk = 0.4*aspect_risk + 0.3*slope_risk + 0.3*twi_risk
#'
#' R3 = (0.6 * climate + 0.4 * topo) * 100
#'
#' @family risk-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#' dem <- rast("path/to/dem.tif")
#'
#' result <- indicator_risk_drought(units, dem = dem)
#' summary(result$R3)
#' }
indicator_risk_drought <- function(units,
                                   layers = NULL,
                                   dem = NULL,
                                   climate_data = NULL) {
  # Validate inputs
  validate_sf(units)

  # Extract DEM from layers if not provided directly
  if (is.null(dem) && !is.null(layers)) {
    dem <- get_dem_raster(layers)
  }

  if (is.null(dem) || !inherits(dem, "SpatRaster")) {
    cli::cli_alert_warning("R3: No DEM available for drought risk, returning NA")
    units$R3 <- rep(NA_real_, nrow(units))
    return(units)
  }

  # --- Component 1: Climate SPEI (weight 0.6) ---
  r3_climat <- 0.5  # Default scalar fallback

  if (requireNamespace("SPEI", quietly = TRUE)) {
    tryCatch({
      # Get latitude for Hargreaves PET
      centroid <- suppressWarnings(sf::st_centroid(sf::st_union(units)))
      coords <- sf::st_coordinates(sf::st_transform(centroid, 4326))
      lat_mean <- coords[1, 2]

      if (!is.null(climate_data) &&
          !is.null(climate_data$precip) &&
          !is.null(climate_data$temp)) {
        # Use provided monthly data
        precip <- climate_data$precip
        tmin <- climate_data$temp$tmin
        tmax <- climate_data$temp$tmax
      } else {
        # Simulated data (same as tuto 03) - representative Mediterranean/continental
        cli::cli_alert_info("R3: Using simulated climate data for SPEI")
        set.seed(42)
        n_months <- 60  # 5 years
        # Monthly precipitation pattern (dry summers)
        base_precip <- rep(c(60, 55, 50, 45, 50, 30, 20, 25, 40, 55, 65, 70), length.out = n_months)
        precip <- pmax(0, base_precip + stats::rnorm(n_months, 0, 15))
        # Temperature pattern
        base_tmax <- rep(c(8, 10, 14, 18, 22, 27, 30, 29, 24, 18, 12, 8), length.out = n_months)
        base_tmin <- rep(c(0, 1, 4, 7, 11, 15, 18, 17, 13, 8, 4, 1), length.out = n_months)
        tmax <- base_tmax + stats::rnorm(n_months, 0, 2)
        tmin <- base_tmin + stats::rnorm(n_months, 0, 2)
      }

      # Compute PET with Hargreaves
      pet <- suppressMessages(SPEI::hargreaves(Tmin = tmin, Tmax = tmax, lat = lat_mean))
      # SPEI-3
      bal <- precip - as.numeric(pet)
      spei_result <- suppressMessages(SPEI::spei(ts(bal, frequency = 12), scale = 3))
      spei_vals <- as.numeric(spei_result$fitted)
      # Use most recent valid SPEI value
      valid_spei <- spei_vals[!is.na(spei_vals) & is.finite(spei_vals)]
      if (length(valid_spei) > 0) {
        spei_recent <- utils::tail(valid_spei, 1)
        # Convert SPEI to risk: SPEI -2 = max risk (1), SPEI +2 = no risk (0)
        r3_climat <- max(0, min(1, (-spei_recent + 2) / 4))
        cli::cli_alert_info("R3: SPEI-3 = {round(spei_recent, 2)}, climate risk = {round(r3_climat, 2)}")
      }
    }, error = function(e) {
      cli::cli_alert_warning("R3: SPEI computation failed ({e$message}), using default 0.5")
    })
  } else {
    cli::cli_alert_info("R3: SPEI package not available, using default climate risk 0.5")
  }

  # --- Component 2: Topographic modulation (weight 0.4) ---
  aspect <- terra::terrain(dem, v = "aspect", unit = "degrees")
  pente <- terra::terrain(dem, v = "slope", unit = "degrees")

  # Aspect risk: south-facing (180°) = max drought risk
  aspect_risk <- (1 + cos((aspect - 180) * pi / 180)) / 2

  # Slope risk: steep slopes = more runoff = drier
  pente_risk <- terra::clamp(pente / 30, lower = 0, upper = 1)

  # TWI risk: low TWI = dry
  twi_raster <- get_or_compute_twi(dem)
  twi_max <- terra::global(twi_raster, "max", na.rm = TRUE)$max
  if (is.na(twi_max) || twi_max == 0) twi_max <- 1
  twi_norm <- terra::clamp(twi_raster / twi_max, lower = 0, upper = 1)
  twi_risk <- 1 - twi_norm

  # Composite topographic risk
  topo_risk <- 0.4 * aspect_risk + 0.3 * pente_risk + 0.3 * twi_risk

  # --- Final R3: climate (0.6) + topo (0.4) ---
  # r3_climat is a scalar, topo_risk is a raster
  r3_raster <- 0.6 * r3_climat + 0.4 * topo_risk

  r3_mean <- safe_extract(r3_raster,
    as_pure_sf(units), fun = "mean", progress = FALSE)
  units$R3 <- pmin(pmax(r3_mean * 100, 0), 100)

  msg_info("indicator_risk_drought")
  units
}

# ==============================================================================
# T034: R4 - Game Browsing Pressure Index
# ==============================================================================

#' Calculate Game Browsing Pressure Index (R4)
#'
#' Computes browsing pressure risk from ungulates (deer, wild boar) based on
#' species palatability from BD Foret, stand vulnerability from LiDAR,
#' edge exposure, and local game density from hunting statistics.
#'
#' Aligned with tuto 03 methodology: BD Foret intersection for palatability,
#' LiDAR MNH for vulnerability, hunting data (data.gouv.fr) for density.
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object. Used to extract BD Foret and LiDAR MNH.
#' @param bdforet An sf object with BD Foret V2 polygons, or NULL (resolved from layers).
#' @param game_density SpatRaster with game density index (0-100), or NULL
#'   (auto-computed from hunting data if available).
#' @param edge_buffer Numeric. Buffer distance (m) for edge effect calculation.
#'   Default 50.
#'
#' @return The input sf object with added columns:
#'   \itemize{
#'     \item R4: Browsing pressure risk (0-100). Higher = higher risk.
#'     \item R4_palatability: Species palatability score (0-100).
#'     \item R4_vulnerability: Stand vulnerability score (0-100).
#'   }
#'
#' @details
#' **Formula**: R4 = 0.35*palatability + 0.30*vulnerability + 0.20*edge + 0.15*density
#'
#' **Components**:
#' \itemize{
#'   \item palatability: From BD Foret species intersection (pattern matching on
#'     essence names). Quercus=90, Abies=85, Fagus=70, Pinus=30.
#'   \item vulnerability: From LiDAR MNH mean height per parcel.
#'     <2m = 100, 2-10m = decreasing, >10m = 0.
#'   \item edge_exposure: Proportion of parcel within buffer of forest edge.
#'   \item game_density: From departmental hunting harvest statistics
#'     (data.gouv.fr, OFB). Auto-fetched via \code{\link{get_game_pressure_raster}}.
#' }
#'
#' @family risk-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#'
#' result <- indicator_risk_browsing(units)
#' summary(result$R4)
#' }
indicator_risk_browsing <- function(units,
                                    layers = NULL,
                                    bdforet = NULL,
                                    game_density = NULL,
                                    edge_buffer = 50) {
  # Validate inputs
  validate_sf(units)

  # Fixed weights from tuto 03
  w_palatability <- 0.35
  w_vulnerability <- 0.30
  w_edge <- 0.20
  w_density <- 0.15

  n_units <- nrow(units)

  # Resolve BD Foret from layers if not provided
  if (is.null(bdforet) && !is.null(layers)) {
    bdforet <- resolve_vector_layer(layers, "bdforet")
  }

  # ==========================================================================
  # Component 1: Palatability from BD Foret intersection (tuto 03 method)
  # ==========================================================================
  palatability_factor <- rep(50, n_units)  # Default

  if (!is.null(bdforet) && inherits(bdforet, "sf") && nrow(bdforet) > 0) {
    cli::cli_alert_info("R4: Computing palatability from BD For\u00eat intersection")

    # Find species/essence column in BD Foret
    essence_col <- NULL
    for (col in c("essence", "tfv", "libelle", "code_tfv",
                  "TFV", "ESSENCE", "LIB_FV", "LIBELLE")) {
      if (col %in% names(bdforet)) {
        essence_col <- col
        break
      }
    }

    if (!is.null(essence_col)) {
      bdforet_proj <- sf::st_transform(bdforet, sf::st_crs(units))

      for (i in seq_len(n_units)) {
        inter <- tryCatch({
          suppressWarnings(sf::st_intersection(bdforet_proj, sf::st_geometry(units)[i]))
        }, error = function(e) NULL)

        if (!is.null(inter) && nrow(inter) > 0) {
          essence <- tolower(as.character(inter[[essence_col]][1]))
          # Use get_species_palatability for pattern matching
          score <- get_species_palatability(essence)
          if (!is.na(score)) {
            palatability_factor[i] <- score
          }
        }
      }
    }
  } else {
    cli::cli_alert_info("R4: No BD For\u00eat data, using default palatability 50")
  }
  units$R4_palatability <- palatability_factor

  # ==========================================================================
  # Component 2: Vulnerability from LiDAR MNH (tuto 03 method)
  # ==========================================================================
  vulnerability_factor <- rep(50, n_units)  # Default

  mnh_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "lidar_mnh") else NULL

  if (!is.null(mnh_raster)) {
    cli::cli_alert_info("R4: Computing vulnerability from LiDAR MNH")
    mnh_mean <- safe_extract(mnh_raster,
      as_pure_sf(units), fun = "mean", progress = FALSE)
    # Tuto formula: (10 - zmean) / 8 * 100
    vulnerability_factor <- pmax(0, pmin(100, (10 - mnh_mean) / 8 * 100))
  } else {
    cli::cli_alert_info("R4: No LiDAR MNH, using default vulnerability 50")
  }
  units$R4_vulnerability <- vulnerability_factor

  # ==========================================================================
  # Component 3: Edge exposure (same as tuto 03)
  # ==========================================================================
  # Project to metric CRS if needed (st_buffer requires meters, not degrees)
  units_proj <- units
  if (sf::st_is_longlat(units)) {
    units_proj <- sf::st_transform(units, 2154)
  }

  edge_factor <- numeric(n_units)

  for (i in seq_len(n_units)) {
    geom <- sf::st_geometry(units_proj)[i]
    area_total <- as.numeric(sf::st_area(geom))

    if (area_total > 0) {
      inner <- tryCatch({
        sf::st_buffer(geom, -edge_buffer)
      }, error = function(e) NULL)

      if (!is.null(inner) && !sf::st_is_empty(inner)) {
        area_inner <- as.numeric(sf::st_area(inner))
        edge_proportion <- (area_total - area_inner) / area_total
      } else {
        edge_proportion <- 1
      }

      edge_factor[i] <- edge_proportion * 100
    } else {
      edge_factor[i] <- 100
    }
  }

  # ==========================================================================
  # Component 4: Game density (tuto 03: hunting data from data.gouv.fr)
  # ==========================================================================
  density_factor <- rep(50, n_units)  # Default

  if (!is.null(game_density) && inherits(game_density, "SpatRaster")) {
    # Use provided raster
    density_values <- terra::extract(game_density, units, fun = mean, na.rm = TRUE, ID = FALSE)[, 1]
    density_values[is.na(density_values) | is.nan(density_values)] <- 50
    density_factor <- pmin(pmax(density_values, 0), 100)
    cli::cli_alert_info("R4: Using provided game density raster")
  } else {
    # Try auto-fetch from hunting data (tuto 03 method)
    tryCatch({
      game_raster <- get_game_pressure_raster(units)
      if (!is.null(game_raster) && inherits(game_raster, "SpatRaster")) {
        density_values <- terra::extract(game_raster, units, fun = mean, na.rm = TRUE, ID = FALSE)[, 1]
        density_values[is.na(density_values) | is.nan(density_values)] <- 50
        density_factor <- pmin(pmax(density_values, 0), 100)
        cli::cli_alert_info("R4: Game density computed from hunting data (data.gouv.fr)")
      }
    }, error = function(e) {
      cli::cli_alert_info("R4: Could not fetch hunting data ({e$message}), using default density 50")
    })
  }

  # ==========================================================================
  # Composite R4 (fixed weights from tuto 03)
  # ==========================================================================
  units$R4 <- w_palatability * palatability_factor +
    w_vulnerability * vulnerability_factor +
    w_edge * edge_factor +
    w_density * density_factor

  # Cap at 0-100
  units$R4 <- pmin(pmax(units$R4, 0), 100)

  msg_info("indicator_risk_browsing")

  units
}
