# indicators-risk.R
# Risk & Resilience Family (R) Indicators
# MVP v0.3.0 - Multi-Family Indicator Extension

#' @importFrom terra terrain extract
#' @importFrom sf st_centroid st_distance
#' @importFrom stats median
#' @keywords internal
NULL

# ==============================================================================
# T031: R1 - Fire Risk Index
# ==============================================================================

#' Calculate Fire Risk Index (R1)
#'
#' Computes fire risk based on topographic slope, species flammability, and
#' climate dryness.
#'
#' @param units An sf object with forest parcels.
#' @param dem A SpatRaster with digital elevation model (meters).
#' @param species_field Character. Column name with species names.
#' @param climate List with 'temperature' and 'precipitation' SpatRasters, or NULL.
#' @param weights Named numeric vector. Weights for components:
#'   c(slope, species, climate). Default c(1/3, 1/3, 1/3).
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item R1: Fire risk index (0-100). Higher = higher risk.
#'   }
#'
#' @details
#' **Formula**: R1 = w1×slope_factor + w2×species_flammability + w3×climate_dryness
#'
#' **Components**:
#' \itemize{
#'   \item slope_factor: Slope from DEM, normalized to 0-100 (>30° = max risk)
#'   \item species_flammability: Lookup from internal table (Pinus=80, Quercus=50, Fagus=20)
#'   \item climate_dryness: Low precipitation + high temperature = high dryness
#' }
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
#' units$species <- sample(c("Pinus", "Quercus", "Fagus"), nrow(units), replace = TRUE)
#'
#' dem <- rast("path/to/dem.tif")
#' climate <- list(
#'   temperature = rast("path/to/temp.tif"),
#'   precipitation = rast("path/to/precip.tif")
#' )
#'
#' result <- indicator_risk_fire(units, dem = dem, species_field = "species", climate = climate)
#' summary(result$R1)
#' }
indicator_risk_fire <- function(units,
                                 dem,
                                 species_field = "species",
                                 climate = NULL,
                                 weights = c(slope = 1/3, species = 1/3, climate = 1/3)) {
  # Validate inputs
  validate_sf(units)
  if (!inherits(dem, "SpatRaster")) {
    stop("dem must be a SpatRaster object", call. = FALSE)
  }

  if (!species_field %in% names(units)) {
    stop(sprintf("Column '%s' not found in units", species_field), call. = FALSE)
  }

  # Normalize weights
  weights <- weights / sum(weights)

  # Component 1: Slope factor
  # Calculate slope from DEM
  slope_raster <- terra::terrain(dem, v = "slope", unit = "degrees")

  # Extract slope for each parcel (mean)
  slope_values <- terra::extract(slope_raster, units, fun = mean, na.rm = TRUE, ID = FALSE)[,1]

  # Normalize: 0° = 0, 30°+ = 100
  slope_factor <- pmin(slope_values / 30, 1) * 100

  # Component 2: Species flammability
  species <- units[[species_field]]
  species_factor <- get_species_flammability(species)

  # Component 3: Climate dryness (if available)
  if (!is.null(climate) && all(c("temperature", "precipitation") %in% names(climate))) {
    # Extract temperature and precipitation
    temp_values <- terra::extract(climate$temperature, units, fun = mean, na.rm = TRUE, ID = FALSE)[,1]
    precip_values <- terra::extract(climate$precipitation, units, fun = mean, na.rm = TRUE, ID = FALSE)[,1]

    # Dryness: high temp + low precip = high dryness
    # Normalize temperature: 8°C=0, 16°C=100
    temp_norm <- pmin(pmax((temp_values - 8) / 8, 0), 1) * 100

    # Normalize precipitation (inverse): 1400mm=0, 500mm=100
    precip_norm <- pmin(pmax((1400 - precip_values) / 900, 0), 1) * 100

    # Climate dryness: average of temp and inverse precip
    climate_factor <- (temp_norm + precip_norm) / 2
  } else {
    # No climate data: use slope and species only, reweight
    climate_factor <- rep(50, nrow(units))  # Neutral value
    weights["slope"] <- weights["slope"] + weights["climate"] / 2
    weights["species"] <- weights["species"] + weights["climate"] / 2
    weights["climate"] <- 0
  }

  # Composite R1
  units$R1 <- weights["slope"] * slope_factor +
               weights["species"] * species_factor +
               weights["climate"] * climate_factor

  # Cap at 0-100
  units$R1 <- pmin(pmax(units$R1, 0), 100)

  msg_info("indicator_risk_fire")

  units
}

# ==============================================================================
# T032: R2 - Storm Vulnerability Index
# ==============================================================================

#' Calculate Storm Vulnerability Index (R2)
#'
#' Computes storm vulnerability based on stand height, density, and topographic exposure.
#'
#' @param units An sf object with forest parcels.
#' @param dem A SpatRaster with digital elevation model (meters).
#' @param height_field Character. Column name with stand height (meters).
#' @param density_field Character. Column name with stand density (0-1 scale).
#' @param weights Named numeric vector. Weights for components:
#'   c(height, density, exposure). Default c(1/3, 1/3, 1/3).
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item R2: Storm vulnerability (0-100). Higher = more vulnerable.
#'   }
#'
#' @details
#' **Formula**: R2 = w1×height_factor + w2×density_factor + w3×exposure_factor
#'
#' **Components**:
#' \itemize{
#'   \item height_factor: Taller stands (>30m) are more vulnerable
#'   \item density_factor: Dense stands (>0.8) have higher wind load
#'   \item exposure_factor: Topographic Position Index from DEM (ridges = exposed)
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
#' units$height <- runif(nrow(units), 10, 35)
#' units$density <- runif(nrow(units), 0.5, 1.0)
#'
#' dem <- rast("path/to/dem.tif")
#'
#' result <- indicator_risk_storm(units, dem = dem, height_field = "height", density_field = "density")
#' summary(result$R2)
#' }
indicator_risk_storm <- function(units,
                                  dem,
                                  height_field = "height",
                                  density_field = "density",
                                  weights = c(height = 1/3, density = 1/3, exposure = 1/3)) {
  # Validate inputs
  validate_sf(units)
  if (!inherits(dem, "SpatRaster")) {
    stop("dem must be a SpatRaster object", call. = FALSE)
  }

  if (!height_field %in% names(units)) {
    stop(sprintf("Column '%s' not found in units", height_field), call. = FALSE)
  }

  if (!density_field %in% names(units)) {
    stop(sprintf("Column '%s' not found in units", density_field), call. = FALSE)
  }

  # Normalize weights
  weights <- weights / sum(weights)

  # Component 1: Height factor
  # Normalize: 10m=0, 35m+=100
  height_values <- units[[height_field]]
  height_factor <- pmin(pmax((height_values - 10) / 25, 0), 1) * 100

  # Component 2: Density factor
  # Normalize: 0.5=0, 1.0=100
  density_values <- units[[density_field]]
  density_factor <- pmin(pmax((density_values - 0.5) / 0.5, 0), 1) * 100

  # Component 3: Topographic exposure (TPI-like)
  # Calculate TPI (Topographic Position Index): high = ridges = exposed
  tpi_raster <- terra::terrain(dem, v = "TPI")

  # Extract TPI for each parcel
  tpi_values <- terra::extract(tpi_raster, units, fun = mean, na.rm = TRUE, ID = FALSE)[,1]

  # Normalize TPI: negative (valleys) = 0, positive (ridges) = 100
  # Typical TPI range: -50 to +50
  exposure_factor <- pmin(pmax((tpi_values + 50) / 100, 0), 1) * 100

  # Composite R2
  units$R2 <- weights["height"] * height_factor +
               weights["density"] * density_factor +
               weights["exposure"] * exposure_factor

  # Cap at 0-100
  units$R2 <- pmin(pmax(units$R2, 0), 100)

  msg_info("indicator_risk_storm")

  units
}

# ==============================================================================
# T033: R3 - Drought Stress Index
# ==============================================================================

#' Calculate Drought Stress Index (R3)
#'
#' Computes drought stress based on topographic wetness (inverse TWI),
#' precipitation deficit, and species sensitivity.
#'
#' @param units An sf object with forest parcels.
#' @param twi_field Character. Column name with Topographic Wetness Index (TWI).
#'   Can reuse W3 from v0.2.0.
#' @param climate List with 'precipitation' SpatRaster, or NULL.
#' @param species_field Character. Column name with species names.
#' @param weights Named numeric vector. Weights for components:
#'   c(twi, precip, species). Default c(0.4, 0.4, 0.2).
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item R3: Drought stress (0-100). Higher = higher stress.
#'   }
#'
#' @details
#' **Formula**: R3 = w1×(100-TWI_norm) + w2×precip_deficit + w3×species_sensitivity
#'
#' **Components**:
#' \itemize{
#'   \item Inverse TWI: Low TWI (dry sites) = high drought stress
#'   \item Precipitation deficit: Low annual precip = high stress
#'   \item Species sensitivity: Fagus (80), Quercus (50), Pinus (50), others (50)
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
#' # Reuse W3 (TWI) from v0.2.0
#' units$W3 <- runif(nrow(units), 5, 15)
#' units$species <- sample(c("Fagus", "Quercus", "Pinus"), nrow(units), replace = TRUE)
#'
#' climate <- list(precipitation = rast("path/to/precip.tif"))
#'
#' result <- indicator_risk_drought(units, twi_field = "W3", climate = climate, species_field = "species")
#' summary(result$R3)
#' }
indicator_risk_drought <- function(units,
                                    twi_field = "W3",
                                    climate = NULL,
                                    species_field = "species",
                                    weights = c(twi = 0.4, precip = 0.4, species = 0.2)) {
  # Validate inputs
  validate_sf(units)

  if (!twi_field %in% names(units)) {
    stop(sprintf("Column '%s' not found in units. Run indicator_water_twi() first to compute W3.", twi_field), call. = FALSE)
  }

  if (!species_field %in% names(units)) {
    stop(sprintf("Column '%s' not found in units", species_field), call. = FALSE)
  }

  # Normalize weights
  weights <- weights / sum(weights)

  # Component 1: Inverse TWI (low TWI = dry sites = high stress)
  twi_values <- units[[twi_field]]

  # Normalize TWI: 5=100 (dry), 15=0 (wet)
  twi_factor <- pmin(pmax((15 - twi_values) / 10, 0), 1) * 100

  # Component 2: Precipitation deficit (if available)
  if (!is.null(climate) && "precipitation" %in% names(climate)) {
    precip_values <- terra::extract(climate$precipitation, units, fun = mean, na.rm = TRUE, ID = FALSE)[,1]

    # Normalize precipitation (inverse): 1200mm+=0, 600mm-=100
    precip_factor <- pmin(pmax((1200 - precip_values) / 600, 0), 1) * 100
  } else {
    # No climate data: use TWI only, reweight
    precip_factor <- rep(50, nrow(units))  # Neutral value
    weights["twi"] <- weights["twi"] + weights["precip"]
    weights["precip"] <- 0
  }

  # Component 3: Species sensitivity
  species <- units[[species_field]]
  species_factor <- get_species_drought_sensitivity(species)

  # Composite R3
  units$R3 <- weights["twi"] * twi_factor +
               weights["precip"] * precip_factor +
               weights["species"] * species_factor

  # Cap at 0-100
  units$R3 <- pmin(pmax(units$R3, 0), 100)

  msg_info("indicator_risk_drought")

  units
}

# ==============================================================================
# T034: R4 - Game Browsing Pressure Index
# ==============================================================================

#' Calculate Game Browsing Pressure Index (R4)
#'
#' Computes browsing pressure risk from ungulates (deer, wild boar) based on
#' species palatability, stand vulnerability, edge exposure, and local game density.
#'
#' @param units An sf object with forest parcels.
#' @param species_field Character. Column name with species names.
#' @param height_field Character. Column name with stand height (meters). Optional.
#' @param age_field Character. Column name with stand age (years). Optional.
#' @param game_density SpatRaster with game density index (0-100), or NULL.
#' @param edge_buffer Numeric. Buffer distance (m) for edge effect calculation. Default 50.
#' @param weights Named numeric vector. Weights for components:
#'   c(palatability, vulnerability, edge, density). Default c(0.35, 0.30, 0.20, 0.15).
#'
#' @return The input sf object with added columns:
#'   \itemize{
#'     \item R4: Browsing pressure risk (0-100). Higher = higher risk.
#'     \item R4_palatability: Species palatability score (0-100).
#'     \item R4_vulnerability: Stand vulnerability score (0-100).
#'   }
#'
#' @details
#' **Formula**: R4 = w1*palatability + w2*vulnerability + w3*edge_exposure + w4*game_density
#'
#' **Components**:
#' \itemize{
#'   \item palatability: Species attractiveness to browsers (Quercus=90, Abies=85, Fagus=70, Pinus=30)
#'   \item vulnerability: Young/short stands more vulnerable (<2m = 100, >10m = 0)
#'   \item edge_exposure: Proportion of parcel within buffer of forest edge
#'   \item game_density: Local ungulate population index if available
#' }
#'
#' **Data sources for game density**:
#' \itemize{
#'   \item ONF/CNPF: Consumption indices from field surveys
#'   \item Hunting federations: Harvest statistics by commune
#'   \item ONCFS/OFB: Wildlife monitoring data
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
#' units$species <- sample(c("Quercus", "Fagus", "Pinus", "Abies"), nrow(units), replace = TRUE
#' units$height <- runif(nrow(units), 1, 25)
#' units$age <- runif(nrow(units), 5, 80)
#'
#' # Without game density data
#' result <- indicator_risk_browsing(units, species_field = "species", height_field = "height")
#' summary(result$R4)
#'
#' # With game density raster
#' game_raster <- rast("path/to/game_density.tif")
#' result <- indicator_risk_browsing(units, species_field = "species", game_density = game_raster)
#' }
indicator_risk_browsing <- function(units,
                                     species_field = "species",
                                     height_field = NULL,
                                     age_field = NULL,
                                     game_density = NULL,
                                     edge_buffer = 50,
                                     weights = c(palatability = 0.35, vulnerability = 0.30,
                                                 edge = 0.20, density = 0.15)) {
  # Validate inputs

  validate_sf(units)

  if (!species_field %in% names(units)) {
    stop(sprintf("Column '%s' not found in units", species_field), call. = FALSE)
  }

  # Normalize weights
  weights <- weights / sum(weights)

  n_units <- nrow(units)

  # ==========================================================================
  # Component 1: Species palatability
  # ==========================================================================
  species <- units[[species_field]]
  palatability_factor <- get_species_palatability(species)
  units$R4_palatability <- palatability_factor

  # ==========================================================================
  # Component 2: Stand vulnerability (young/short stands more vulnerable)
  # ==========================================================================
  if (!is.null(height_field) && height_field %in% names(units)) {
    height_values <- units[[height_field]]
    # Vulnerability: <2m = 100, 2-10m = decreasing, >10m = 0
    vulnerability_factor <- pmax(0, pmin(100, (10 - height_values) / 8 * 100))
  } else if (!is.null(age_field) && age_field %in% names(units)) {
    age_values <- units[[age_field]]
    # Vulnerability: <10 years = 100, 10-40 years = decreasing, >40 years = 0
    vulnerability_factor <- pmax(0, pmin(100, (40 - age_values) / 30 * 100))
  } else {
    # Default: moderate vulnerability
    vulnerability_factor <- rep(50, n_units)
  }
  units$R4_vulnerability <- vulnerability_factor

  # ==========================================================================
  # Component 3: Edge exposure
  # ==========================================================================
  # Calculate proportion of parcel within buffer distance of edge
  edge_factor <- numeric(n_units)

  for (i in seq_len(n_units)) {
    geom <- sf::st_geometry(units)[i]
    area_total <- as.numeric(sf::st_area(geom))

    if (area_total > 0) {
      # Create inner buffer (negative buffer)
      inner <- tryCatch({
        sf::st_buffer(geom, -edge_buffer)
      }, error = function(e) NULL)

      if (!is.null(inner) && !sf::st_is_empty(inner)) {
        area_inner <- as.numeric(sf::st_area(inner))
        # Edge proportion: area in edge zone / total area
        edge_proportion <- (area_total - area_inner) / area_total
      } else {
        # Small parcel entirely in edge zone
        edge_proportion <- 1
      }

      edge_factor[i] <- edge_proportion * 100
    } else {
      edge_factor[i] <- 50
    }
  }

  # ==========================================================================
  # Component 4: Game density (if available)
  # ==========================================================================
  if (!is.null(game_density) && inherits(game_density, "SpatRaster")) {
    density_values <- terra::extract(game_density, units, fun = mean, na.rm = TRUE, ID = FALSE)[, 1]
    density_factor <- pmin(pmax(density_values, 0), 100)
  } else {
    # No game density data: use neutral value and redistribute weight
    density_factor <- rep(50, n_units)
    weights["palatability"] <- weights["palatability"] + weights["density"] / 3
    weights["vulnerability"] <- weights["vulnerability"] + weights["density"] / 3
    weights["edge"] <- weights["edge"] + weights["density"] / 3
    weights["density"] <- 0
  }

  # ==========================================================================
  # Composite R4
  # ==========================================================================
  units$R4 <- weights["palatability"] * palatability_factor +
              weights["vulnerability"] * vulnerability_factor +
              weights["edge"] * edge_factor +
              weights["density"] * density_factor

  # Cap at 0-100
  units$R4 <- pmin(pmax(units$R4, 0), 100)

  msg_info("indicator_risk_browsing")

  units
}
