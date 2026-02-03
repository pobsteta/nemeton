#' Indicator Family Functions - v0.2.0 Extension
#'
#' Functions for calculating indicators across the 12-family framework:
#' B (Biodiversité/Vivant), W (Water/Infiltrée), A (Air/Vaporeuse),
#' F (Fertilité/Riche), C (Carbone/Énergétique), L (Landscape/Esthétique),
#' T (Trame/Nervurée), R (Résilience/Flexible), S (Santé/Ouverte),
#' P (Patrimoine/Radicale), E (Éducation/Éducative), N (Nuit/Ténébreuse)
#'
#' @name indicators-families
#' @keywords internal
NULL

# ==============================================================================
# FAMILY C: CARBONE / ÉNERGÉTIQUE
# Stock de carbone aérien et souterrain, dynamique de stockage
# ==============================================================================

#' Carbon Stock via Biomass and Allometric Models (C1)
#'
#' Calculates aboveground carbon stock (tC/ha) using species-specific
#' allometric equations from IGN/IFN literature. Requires BD Forêt v2 data
#' (species, age, density) or equivalent attributes.
#'
#' @param units nemeton_units object with forest parcel geometries
#' @param layers nemeton_layers object (optional for future integration)
#' @param species_col Character. Column name for species (default "species")
#' @param age_col Character. Column name for stand age (default "age")
#' @param density_col Character. Column name for stand density 0-1 (default "density")
#'
#' @return Numeric vector of carbon stock values (tC/ha)
#'
#' @export
#' @examples
#' \dontrun{
#' # With BD Forêt attributes
#' units$species <- c("Quercus", "Fagus", "Pinus")
#' units$age <- c(80, 60, 40)
#' units$density <- c(0.7, 0.8, 0.6)
#'
#' results <- indicator_carbon_biomass(units)
#' }
indicator_carbon_biomass <- function(units,
                                     layers = NULL,
                                     species_col = "species",
                                     age_col = "age",
                                     density_col = "density") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  has_inventory <- species_col %in% names(units) &&
                   age_col %in% names(units) &&
                   density_col %in% names(units)

  if (has_inventory) {
    # Full allometric model when forest inventory data is available
    species <- units[[species_col]]
    age <- units[[age_col]]
    density <- units[[density_col]]

    biomass <- calculate_allometric_biomass(species, age, density)
    msg_info("indicator_carbon_biomass")
    return(biomass)
  }

  # Fallback: estimate carbon stock from NDVI when inventory columns are missing
  # (cadastral parcels typically lack species/age/density)
  if (!is.null(layers) && inherits(layers, "nemeton_layers") &&
      "ndvi" %in% names(layers$rasters)) {
    cli::cli_alert_info("No forest inventory columns; estimating C1 from NDVI")
    ndvi_raster <- layers$rasters[["ndvi"]]
    ndvi_mean <- exactextractr::exact_extract(
      ndvi_raster,
      as_pure_sf(units),
      fun = "mean",
      progress = FALSE
    )
    # NDVI-to-biomass proxy: scale NDVI (0-1) to approximate carbon stock
    # (tC/ha). Typical temperate forest: ~80-150 tC/ha at high NDVI.
    biomass <- pmax(0, ndvi_mean, na.rm = FALSE) * 150
    return(biomass)
  }

  # Last resort: return NA
  cli::cli_alert_warning(
    "C1: no inventory data and no NDVI layer; returning NA"
  )
  rep(NA_real_, nrow(units))
}

#' NDVI Mean and Trend Analysis (C2)
#'
#' Extracts mean NDVI from Sentinel-2 or equivalent satellite imagery.
#' Optionally calculates NDVI trend over multiple dates (requires temporal rasters).
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing NDVI raster(s)
#' @param ndvi_layer Character. Name of NDVI layer in layers object
#' @param trend Logical. Calculate temporal trend if multiple dates available?
#'   Default FALSE.
#'
#' @return Numeric vector of NDVI mean values (0-1 scale), or list with
#'   mean and trend if trend = TRUE
#'
#' @export
#' @examples
#' \dontrun{
#' # Single-date NDVI
#' layers <- nemeton_layers(rasters = list(ndvi = "sentinel2_ndvi.tif"))
#' results <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi")
#'
#' # Multi-date NDVI with trend
#' results <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi", trend = TRUE)
#' }
indicator_carbon_ndvi <- function(units,
                                  layers,
                                  ndvi_layer = "ndvi",
                                  trend = FALSE) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  # Check NDVI layer exists
  if (!ndvi_layer %in% names(layers$rasters)) {
    stop(sprintf("NDVI layer '%s' not found in layers", ndvi_layer), call. = FALSE)
  }

  # Get NDVI raster
  ndvi_raster <- layers$rasters[[ndvi_layer]]

  # Extract mean NDVI for each unit
  ndvi_mean <- exactextractr::exact_extract(
    ndvi_raster,
    as_pure_sf(units),
    fun = "mean",
    progress = FALSE
  )

  # Handle trend calculation (future implementation)
  if (trend) {
    warning("NDVI trend calculation not yet implemented in v0.2.0 - returning single-date mean only",
      call. = FALSE
    )
    # In future: calculate Sen's slope or linear regression if multi-date raster
  }

  # Log calculation
  msg_info("indicator_carbon_ndvi")

  ndvi_mean
}

# ==============================================================================
# FAMILY W: WATER / INFILTRÉE
# Infiltration, stockage et restitution de l'eau, protection des sources
# ==============================================================================

#' Hydrographic Network Density (W1)
#'
#' Calculates stream/river network length density within or near forest parcels.
#' Higher values indicate greater hydrological connectivity.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing watercourse vector layer
#' @param watercourse_layer Character. Name of watercourse layer in layers object
#' @param buffer Numeric. Buffer distance (meters) for proximity analysis. Default 0.
#'
#' @return Numeric vector of network density (km/ha)
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(vectors = list(streams = "watercourses.gpkg"))
#' results <- indicator_water_network(units, layers, watercourse_layer = "streams")
#' }
indicator_water_network <- function(units,
                                    layers,
                                    watercourse_layer = "water_network",
                                    buffer = 0) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  # Check watercourse layer exists
  if (!watercourse_layer %in% names(layers$vectors)) {
    stop(sprintf("Watercourse layer '%s' not found in layers", watercourse_layer), call. = FALSE)
  }

  # Get watercourse vector layer
  watercourses <- layers$vectors[[watercourse_layer]]
  # If not loaded (lazy loading), load it
  if (is.null(watercourses)) {
    watercourses <- sf::st_read(layers$vectors[[watercourse_layer]]$path, quiet = TRUE)
  }

  # Ensure CRS match
  if (!sf::st_crs(units) == sf::st_crs(watercourses)) {
    watercourses <- sf::st_transform(watercourses, sf::st_crs(units))
  }

  # Calculate density for each unit
  density <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    unit_geom <- units[i, ]

    # Apply buffer if requested
    if (buffer > 0) {
      unit_geom <- sf::st_buffer(unit_geom, dist = buffer)
    }

    # Intersect watercourses with unit
    intersected <- suppressWarnings(sf::st_intersection(watercourses, unit_geom))

    # Calculate total length of watercourses (in km)
    if (nrow(intersected) > 0) {
      total_length_m <- sum(sf::st_length(intersected))
      total_length_km <- as.numeric(total_length_m) / 1000
    } else {
      total_length_km <- 0
    }

    # Calculate unit area (in ha)
    area_m2 <- as.numeric(sf::st_area(unit_geom))
    area_ha <- area_m2 / 10000

    # Density = km / ha
    density[i] <- total_length_km / area_ha
  }

  # Log calculation
  msg_info("indicator_water_network")

  density
}

#' Wetland Coverage (W2)
#'
#' Calculates percentage of parcel area classified as wetland or riparian zone.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing land cover raster or wetland vector
#' @param wetland_layer Character. Name of wetland layer in layers object
#' @param wetland_values Numeric vector. Land cover codes representing wetlands.
#'   Default NULL (auto-detect if possible).
#'
#' @return Numeric vector of wetland coverage (0-100\%)
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
#' results <- indicator_water_wetlands(units, layers, wetland_values = c(50, 51, 52))
#' }
indicator_water_wetlands <- function(units,
                                     layers,
                                     wetland_layer = "wetlands",
                                     wetland_values = NULL) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  coverage <- numeric(nrow(units))

  # Strategy 1: Use vector wetlands layer (ZNIEFF zones humides) if available
  if ("wetlands" %in% names(layers$vectors) && !is.null(layers$vectors[["wetlands"]])) {
    cli::cli_alert_info("W2: Computing wetland coverage from vector layer")
    wetlands_sf <- layers$vectors[["wetlands"]]

    # Ensure CRS match
    if (!sf::st_crs(units) == sf::st_crs(wetlands_sf)) {
      wetlands_sf <- sf::st_transform(wetlands_sf, sf::st_crs(units))
    }

    for (i in seq_len(nrow(units))) {
      unit_geom <- units[i, ]
      parcel_area <- as.numeric(sf::st_area(unit_geom))

      intersected <- tryCatch(
        suppressWarnings(sf::st_intersection(wetlands_sf, unit_geom)),
        error = function(e) NULL
      )

      if (!is.null(intersected) && nrow(intersected) > 0) {
        wetland_area <- sum(as.numeric(sf::st_area(intersected)))
        coverage[i] <- (wetland_area / parcel_area) * 100
      }
    }

    msg_info("indicator_water_wetlands")
    return(pmin(coverage, 100))
  }

  # Strategy 2: Use TWI threshold (TWI > 12 = potential wetland) from DEM
  if ("dem" %in% names(layers$rasters) && !is.null(layers$rasters[["dem"]])) {
    cli::cli_alert_info("W2: Estimating wetlands from TWI (threshold > 12)")
    dem <- layers$rasters[["dem"]]
    twi_raster <- calculate_twi_terra(dem)

    for (i in seq_len(nrow(units))) {
      twi_vals <- exactextractr::exact_extract(
        twi_raster,
        as_pure_sf(units[i, ]),
        fun = NULL,
        progress = FALSE
      )[[1]]

      if (nrow(twi_vals) > 0) {
        wetland_frac <- sum(twi_vals$coverage_fraction[twi_vals$value > 12], na.rm = TRUE)
        total_frac <- sum(twi_vals$coverage_fraction, na.rm = TRUE)
        if (total_frac > 0) {
          coverage[i] <- (wetland_frac / total_frac) * 100
        }
      }
    }

    msg_info("indicator_water_wetlands")
    return(pmin(coverage, 100))
  }

  # Strategy 3: Use raster landcover if available with wetland codes
  if (!is.null(wetland_values) && "forest_cover" %in% names(layers$rasters)) {
    cli::cli_alert_info("W2: Computing wetland coverage from OSO landcover codes")
    lc_raster <- layers$rasters[["forest_cover"]]

    for (i in seq_len(nrow(units))) {
      lc_values <- exactextractr::exact_extract(
        lc_raster,
        as_pure_sf(units[i, ]),
        fun = NULL,
        progress = FALSE
      )[[1]]

      if (nrow(lc_values) > 0) {
        wetland_mask <- lc_values$value %in% wetland_values
        wetland_fraction <- sum(lc_values$coverage_fraction[wetland_mask], na.rm = TRUE)
        total_fraction <- sum(lc_values$coverage_fraction, na.rm = TRUE)
        if (total_fraction > 0) {
          coverage[i] <- (wetland_fraction / total_fraction) * 100
        }
      }
    }

    msg_info("indicator_water_wetlands")
    return(pmin(coverage, 100))
  }

  cli::cli_alert_warning("W2: No wetland data available (no vectors, DEM, or landcover)")
  rep(NA_real_, nrow(units))
}

#' Topographic Wetness Index (W3)
#'
#' Calculates TWI using whitebox (D-infinity algorithm) or terra fallback (D8).
#' Higher values indicate areas with greater water accumulation potential.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing DEM raster
#' @param dem_layer Character. Name of DEM layer in layers object
#' @param method Character. TWI calculation method: "auto" (prefer whitebox),
#'   "dinf" (whitebox D-infinity), or "d8" (terra D8). Default "auto".
#'
#' @return Numeric vector of TWI mean values
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(rasters = list(dem = "dem_25m.tif"))
#' results <- indicator_water_twi(units, layers, dem_layer = "dem")
#' }
indicator_water_twi <- function(units,
                                layers,
                                dem_layer = "dem",
                                method = c("auto", "dinf", "d8")) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  # Match and validate method
  method <- match.arg(method)

  # Check DEM layer exists
  if (!dem_layer %in% names(layers$rasters)) {
    stop(sprintf("DEM layer '%s' not found in layers", dem_layer), call. = FALSE)
  }

  # Get DEM raster
  dem <- layers$rasters[[dem_layer]]
  # If not loaded (lazy loading), load it
  if (is.null(dem)) {
    dem <- terra::rast(layers$rasters[[dem_layer]]$path)
  }

  # Determine which method to use
  use_whitebox <- FALSE
  if (method == "dinf") {
    # Check if whitebox is available
    if (!requireNamespace("whitebox", quietly = TRUE)) {
      warning("whitebox package not available, falling back to terra D8 method", call. = FALSE)
      method <- "d8"
    } else {
      use_whitebox <- TRUE
    }
  } else if (method == "auto") {
    # Prefer whitebox if available
    if (requireNamespace("whitebox", quietly = TRUE)) {
      use_whitebox <- TRUE
    } else {
      method <- "d8"
    }
  }

  # Calculate TWI using selected method
  if (use_whitebox) {
    twi_raster <- calculate_twi_whitebox(dem)
  } else {
    twi_raster <- calculate_twi_terra(dem)
  }

  # Extract mean TWI for each unit
  twi_mean <- exactextractr::exact_extract(
    twi_raster,
    as_pure_sf(units),
    fun = "mean",
    progress = FALSE
  )

  # Log calculation
  msg_info("indicator_water_twi")

  twi_mean
}

#' Calculate TWI using terra (D8 algorithm)
#' @keywords internal
#' @noRd
calculate_twi_terra <- function(dem) {
  # Calculate slope (in radians)
  slope_deg <- terra::terrain(dem, v = "slope", unit = "degrees")
  slope_rad <- slope_deg * pi / 180

  # Replace zero/very small slopes with small value to avoid division by zero
  # This handles flat areas
  slope_rad[slope_rad < 0.001] <- 0.001

  # Calculate flow direction (D8)
  flow_dir <- terra::terrain(dem, v = "flowdir", neighbors = 8)

  # Calculate flow accumulation (number of cells draining to each cell)
  flow_acc <- terra::flowAccumulation(flow_dir)

  # Get cell resolution (m)
  cell_res <- terra::res(dem)
  cell_area <- prod(cell_res) # resolution in x and y (m²)
  cell_width <- cell_res[1]

  # Specific catchment area (m²/m) = (flow_acc + 1) * cell_area / cell_width
  # +1 because flow_acc doesn't include the cell itself
  # This represents the contributing area per unit contour length
  catchment_area <- (flow_acc + 1) * cell_area / cell_width

  # Calculate TWI = ln(catchment_area / tan(slope))
  # TWI represents the tendency of water to accumulate at a location
  twi <- log(catchment_area / tan(slope_rad))

  # Handle edge cases:
  # - Infinite values can occur from numerical issues
  # - Negative TWI values shouldn't exist theoretically
  twi[is.infinite(twi)] <- NA
  twi[is.nan(twi)] <- NA

  # Set a reasonable range for TWI (typically 0-20 in natural landscapes)
  # Extreme values indicate calculation issues
  twi[twi < 0] <- 0
  twi[twi > 50] <- NA # Flag suspiciously high values

  twi
}

#' Calculate TWI using whitebox (D-infinity algorithm)
#' @keywords internal
#' @noRd
calculate_twi_whitebox <- function(dem) {
  # Placeholder for whitebox implementation (v0.3.0+)
  # For now, fall back to terra
  warning("whitebox TWI not yet fully implemented, using terra D8", call. = FALSE)
  calculate_twi_terra(dem)
}

# ==============================================================================
# FAMILY F: FERTILITÉ / RICHE
# Santé biologique, chimique et physique des sols
# ==============================================================================

#' Soil Fertility Class (F1)
#'
#' Extracts soil fertility classification from BD Sol or equivalent pedological database.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing soil data
#' @param soil_layer Character. Name of soil layer in layers object
#' @param fertility_col Character. Column/band name for fertility class
#'
#' @return Numeric vector of fertility scores (0-100 scale, higher = more fertile)
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(vectors = list(soil = "bd_sol.gpkg"))
#' results <- indicator_soil_fertility(units, layers, soil_layer = "soil")
#' }
indicator_soil_fertility <- function(units,
                                     layers,
                                     soil_layer = "soil",
                                     fertility_col = "fertility") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  # Check if soil layer exists (try raster first, then vector)
  is_raster <- soil_layer %in% names(layers$rasters)
  is_vector <- soil_layer %in% names(layers$vectors)

  if (!is_raster && !is_vector) {
    stop(sprintf("Soil layer '%s' not found in layers", soil_layer), call. = FALSE)
  }

  if (is_raster) {
    # Extract from raster
    fertility <- extract_fertility_from_raster(units, layers, soil_layer, fertility_col)
  } else {
    # Extract from vector (e.g., BD Sol polygons)
    fertility <- extract_fertility_from_vector(units, layers, soil_layer, fertility_col)
  }

  # Log calculation
  msg_info("indicator_soil_fertility")

  fertility
}

#' Extract fertility from raster layer
#' @keywords internal
#' @noRd
extract_fertility_from_raster <- function(units, layers, soil_layer, fertility_col) {
  # Get soil raster
  soil_raster <- layers$rasters[[soil_layer]]
  # If not loaded (lazy loading), load it
  if (is.null(soil_raster)) {
    soil_raster <- terra::rast(layers$rasters[[soil_layer]]$path)
  }

  # Extract mean soil values for each unit
  soil_values <- exactextractr::exact_extract(
    soil_raster,
    as_pure_sf(units),
    fun = "mean",
    progress = FALSE
  )

  # Convert to 0-100 fertility scale
  # Assuming input values are categorical (e.g., 1-5) or continuous
  # Normalize to 0-100 scale
  min_val <- min(soil_values, na.rm = TRUE)
  max_val <- max(soil_values, na.rm = TRUE)

  if (max_val == min_val) {
    # All values identical
    fertility <- rep(50, length(soil_values)) # Neutral value
  } else {
    # Linear scaling to 0-100
    fertility <- ((soil_values - min_val) / (max_val - min_val)) * 100
  }

  fertility
}

#' Extract fertility from vector layer
#' @keywords internal
#' @noRd
extract_fertility_from_vector <- function(units, layers, soil_layer, fertility_col) {
  # Get soil vector layer
  soil_vector <- layers$vectors[[soil_layer]]
  # If not loaded (lazy loading), load it
  if (is.null(soil_vector)) {
    soil_vector <- sf::st_read(layers$vectors[[soil_layer]]$path, quiet = TRUE)
  }

  # Ensure CRS match
  if (!sf::st_crs(units) == sf::st_crs(soil_vector)) {
    soil_vector <- sf::st_transform(soil_vector, sf::st_crs(units))
  }

  # Check if fertility column exists
  if (!fertility_col %in% names(soil_vector)) {
    stop(sprintf("Fertility column '%s' not found in soil layer", fertility_col), call. = FALSE)
  }

  # Intersect units with soil polygons and extract fertility
  fertility <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    unit_geom <- units[i, ]

    # Intersect with soil layer
    intersected <- suppressWarnings(sf::st_intersection(soil_vector, unit_geom))

    if (nrow(intersected) > 0) {
      # Calculate area-weighted average fertility
      intersected$area <- as.numeric(sf::st_area(intersected))
      total_area <- sum(intersected$area)

      fertility_values <- intersected[[fertility_col]]
      weights <- intersected$area / total_area

      fertility[i] <- sum(fertility_values * weights, na.rm = TRUE)
    } else {
      # No intersection - assign NA or default value
      fertility[i] <- NA_real_
    }
  }

  # Ensure 0-100 scale
  fertility <- pmin(pmax(fertility, 0), 100)

  fertility
}

#' Erosion Risk Index (F2)
#'
#' Calculates erosion risk by combining slope (from DEM) with land cover protection.
#' Higher values indicate greater erosion risk.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing DEM and land cover
#' @param dem_layer Character. Name of DEM layer
#' @param landcover_layer Character. Name of land cover layer
#' @param forest_values Numeric vector. Land cover codes for forest (protective cover)
#'
#' @return Numeric vector of erosion risk scores (0-100, higher = more risk)
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(
#'   rasters = list(dem = "dem.tif", landcover = "landcover.tif")
#' )
#' results <- indicator_soil_erosion(units, layers, forest_values = c(1, 2, 3))
#' }
indicator_soil_erosion <- function(units,
                                   layers,
                                   dem_layer = "dem",
                                   landcover_layer = "forest_cover",
                                   forest_values = seq(1, 6)) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  # Check DEM layer exists
  if (!dem_layer %in% names(layers$rasters)) {
    stop(sprintf("DEM layer '%s' not found in layers", dem_layer), call. = FALSE)
  }

  # Get DEM raster
  dem <- layers$rasters[[dem_layer]]
  if (is.null(dem)) {
    dem <- terra::rast(layers$rasters[[dem_layer]]$path)
  }

  # Calculate slope from DEM (in degrees)
  slope <- terra::terrain(dem, v = "slope", unit = "degrees")

  # Check landcover layer exists for protection factor
  has_landcover <- landcover_layer %in% names(layers$rasters) &&
    !is.null(layers$rasters[[landcover_layer]])

  if (has_landcover) {
    landcover <- layers$rasters[[landcover_layer]]
    # Calculate forest cover protection factor (0-1)
    is_forest <- function(x) {
      as.numeric(x %in% forest_values)
    }
    protection <- terra::app(landcover, is_forest)
    erosion_raster <- slope * (1 - protection)
  } else {
    # No landcover: use slope only (assume moderate protection from forest)
    cli::cli_alert_info("F2: No landcover layer, computing erosion from slope only")
    erosion_raster <- slope * 0.5  # Assume 50% forest protection
  }

  # Extract mean erosion risk for each unit
  erosion_mean <- exactextractr::exact_extract(
    erosion_raster,
    as_pure_sf(units),
    fun = "mean",
    progress = FALSE
  )

  # Normalize to 0-100 scale
  # Slope can be 0-90 degrees, erosion_raster is 0-90
  # Scale to 0-100 for consistency
  max_possible <- 90 # Maximum slope in degrees
  erosion_risk <- (erosion_mean / max_possible) * 100

  # Ensure within bounds
  erosion_risk <- pmin(erosion_risk, 100)
  erosion_risk <- pmax(erosion_risk, 0)

  # Log calculation
  msg_info("indicator_soil_erosion")

  erosion_risk
}

# ==============================================================================
# FAMILY L: LANDSCAPE / ESTHÉTIQUE
# Qualité paysagère, composition, diversité des structures, harmonies
# ==============================================================================

#' Landscape Fragmentation (L1)
#'
#' Calculates forest patch metrics within buffer zone: patch count and mean size.
#' Higher fragmentation = more patches with smaller mean size.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing land cover
#' @param landcover_layer Character. Name of land cover layer
#' @param forest_values Numeric vector. Land cover codes for forest
#' @param buffer Numeric. Analysis buffer distance (meters). Default 1000 (1 km).
#'
#' @return Numeric vector of fragmentation index (patch count / mean size)
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
#' results <- indicator_landscape_fragmentation(
#'   units, layers,
#'   forest_values = c(1, 2, 3), buffer = 1000
#' )
#' }
indicator_landscape_fragmentation <- function(units,
                                              layers,
                                              landcover_layer = "forest_cover",
                                              forest_values = seq(1, 6),
                                              buffer = 1000) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }
  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  # Check landcover layer exists
  if (!landcover_layer %in% names(layers$rasters) ||
      is.null(layers$rasters[[landcover_layer]])) {
    cli::cli_alert_warning("L1: Landcover layer '{landcover_layer}' not available, returning NA")
    return(rep(NA_real_, nrow(units)))
  }

  # Load landcover raster
  landcover <- layers$rasters[[landcover_layer]]
  if (is.null(landcover)) {
    landcover <- terra::rast(layers$rasters[[landcover_layer]]$path)
  }

  # Calculate fragmentation for each unit
  fragmentation <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    # Create buffer zone
    if (buffer > 0) {
      buffer_zone <- sf::st_buffer(units[i, ], dist = buffer)
    } else {
      buffer_zone <- units[i, ]
    }

    # Crop landcover to buffer zone
    lc_cropped <- terra::crop(landcover, terra::vect(buffer_zone), snap = "out")
    lc_masked <- terra::mask(lc_cropped, terra::vect(buffer_zone))

    # Create forest mask (1 = forest, NA = non-forest)
    is_forest <- function(x) {
      ifelse(x %in% forest_values, 1, NA)
    }
    forest_mask <- terra::app(lc_masked, is_forest)

    # Count connected forest patches using terra::patches()
    if (!terra::global(forest_mask, "notNA", na.rm = TRUE)[1, 1] == 0) {
      # There are forest pixels
      patches <- terra::patches(forest_mask, directions = 8, zeroAsNA = TRUE)

      # Count unique patch IDs
      patch_ids <- terra::values(patches, mat = FALSE, na.rm = TRUE)
      num_patches <- length(unique(patch_ids))
    } else {
      # No forest pixels in buffer
      num_patches <- 0
    }

    fragmentation[i] <- num_patches
  }

  msg_info("indicator_landscape_fragmentation")
  fragmentation
}

#' Edge-to-Area Ratio (L2)
#'
#' Calculates perimeter-to-area ratio for forest parcels. Higher values
#' indicate greater edge effect and fragmentation.
#'
#' @param units nemeton_units object
#'
#' @return Numeric vector of edge density (m/ha)
#'
#' @export
#' @examples
#' \dontrun{
#' results <- indicator_landscape_edge(units)
#' }
indicator_landscape_edge <- function(units) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (nrow(units) == 0) {
    stop("units is empty (no features)", call. = FALSE)
  }

  # Calculate perimeter (m) and area (ha) for each parcel
  edge_density <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    # Get perimeter in meters
    # Convert to LINESTRING/MULTILINESTRING to get boundary length
    boundary <- sf::st_cast(units[i, ], "MULTILINESTRING")
    perimeter_m <- as.numeric(sf::st_length(boundary))

    # Get area in hectares
    area_ha <- as.numeric(sf::st_area(units[i, ])) / 10000

    # Edge density (m/ha)
    edge_density[i] <- perimeter_m / area_ha
  }

  msg_info("indicator_landscape_edge")
  edge_density
}

# ==============================================================================
# ALIAS FUNCTIONS
# Map indicator names from list_available_indicators() to existing functions.
# These are required because compute_single_indicator dispatches to
# indicator_<name> but some functions have different naming conventions.
# ==============================================================================

#' @noRd
indicator_air_forest_buffer <- function(units, layers = NULL, ...) {
  # A1: Forest coverage buffer - delegates to indicator_air_coverage
  # Requires forest_cover raster from layers
  lc <- NULL
  if (!is.null(layers) && inherits(layers, "nemeton_layers")) {
    lc <- layers$rasters[["forest_cover"]]
  }
  if (is.null(lc)) {
    # Fallback: estimate from NDVI (high NDVI = forested)
    ndvi <- if (!is.null(layers)) layers$rasters[["ndvi"]] else NULL
    if (!is.null(ndvi)) {
      cli::cli_alert_info("A1: No forest_cover layer, estimating from NDVI")
      buffers <- sf::st_buffer(units, dist = 1000)
      coverage <- exactextractr::exact_extract(ndvi, as_pure_sf(buffers),
        fun = "mean", progress = FALSE
      )
      # NDVI > 0.4 is typically forested; scale to 0-100
      result <- units
      result$A1 <- pmin(pmax(coverage / 0.8, 0), 1) * 100
      return(result)
    }
    cli::cli_alert_warning("A1: No forest_cover or NDVI layer available")
    result <- units
    result$A1 <- rep(NA_real_, nrow(units))
    return(result)
  }
  # OSO forest codes: 1-6 are various forest types
  indicator_air_coverage(units, land_cover = lc,
    forest_classes = seq(1, 6), buffer_radius = 1000)
}

#' @noRd
indicator_fertility_soil <- function(units, layers = NULL, ...) {
  # F1: Soil fertility - no dedicated soil layer available

  # Proxy: use NDVI as vegetation productivity indicator
  if (!is.null(layers) && inherits(layers, "nemeton_layers") &&
      "ndvi" %in% names(layers$rasters)) {
    cli::cli_alert_info("F1: Estimating soil fertility from NDVI productivity")
    ndvi_raster <- layers$rasters[["ndvi"]]
    fertility <- exactextractr::exact_extract(ndvi_raster,
      as_pure_sf(units), fun = "mean", progress = FALSE
    )
    # Scale NDVI (0-1) to fertility score (0-100)
    return(pmin(pmax(fertility / 0.8, 0), 1) * 100)
  }
  cli::cli_alert_warning("F1: No data available for soil fertility, returning NA")
  rep(NA_real_, nrow(units))
}

#' @noRd
indicator_fertility_erosion <- function(units, layers = NULL, ...) {
  # F2: Erosion risk - uses DEM slope and forest cover
  if (!is.null(layers) && inherits(layers, "nemeton_layers") &&
      "dem" %in% names(layers$rasters)) {
    dem_layer <- "dem"
    lc_layer <- if ("forest_cover" %in% names(layers$rasters)) "forest_cover" else NULL
    if (!is.null(lc_layer)) {
      return(indicator_soil_erosion(units, layers,
        dem_layer = dem_layer, landcover_layer = lc_layer,
        forest_values = seq(1, 6)))
    }
    # DEM only: compute slope-based erosion risk
    cli::cli_alert_info("F2: Computing erosion from slope only (no landcover)")
    dem <- layers$rasters[["dem"]]
    slope <- terra::terrain(dem, v = "slope", unit = "degrees")
    slope_mean <- exactextractr::exact_extract(slope,
      as_pure_sf(units), fun = "mean", progress = FALSE
    )
    # Normalize: 0° = 0, 45° = 100
    return(pmin(slope_mean / 45, 1) * 100)
  }
  cli::cli_alert_warning("F2: No DEM available for erosion, returning NA")
  rep(NA_real_, nrow(units))
}

#' @noRd
indicator_landscape_edge_ratio <- function(units, ...) {
  # L2: Edge-to-area ratio - delegates to indicator_landscape_edge
  indicator_landscape_edge(units)
}

#' @noRd
indicator_social_population <- function(units, ...) {
  # S3: Population proximity - delegates to indicator_social_proximity
  indicator_social_proximity(units, method = "proxy")
}

#' @noRd
indicator_energy_wood <- function(units, layers = NULL, ...) {
  # E1: Fuelwood potential - estimate from NDVI-based biomass
  if (!is.null(layers) && inherits(layers, "nemeton_layers") &&
      "ndvi" %in% names(layers$rasters)) {
    cli::cli_alert_info("E1: Estimating fuelwood potential from NDVI")
    ndvi_raster <- layers$rasters[["ndvi"]]
    ndvi_mean <- exactextractr::exact_extract(ndvi_raster,
      as_pure_sf(units), fun = "mean", progress = FALSE
    )
    # NDVI -> volume proxy -> fuelwood potential
    # Approximate: NDVI 0.8 -> ~200 m3/ha volume -> 2% harvest -> 0.3 residue
    volume_proxy <- pmax(0, ndvi_mean) * 250  # m3/ha
    fuelwood <- volume_proxy * 0.02 * 0.3 * 550 / 1000 * 0.5  # tonnes DM/yr
    return(fuelwood)
  }
  cli::cli_alert_warning("E1: No NDVI available for fuelwood estimate")
  rep(NA_real_, nrow(units))
}

#' @noRd
indicator_energy_co2 <- function(units, layers = NULL, ...) {
  # E2: CO2 emission avoidance - estimate from E1
  e1 <- indicator_energy_wood(units, layers = layers)
  if (all(is.na(e1))) return(e1)
  # Convert fuelwood (tonnes DM/yr) to CO2 avoided (tCO2eq/yr)
  # 1 tonne DM = 4500 kWh, emission factor ~0.222 kgCO2eq/kWh for gas substitution
  e1 * 4500 * 0.222 / 1000
}

#' @noRd
indicator_naturalness_score <- function(units, ...) {
  # N3: Composite naturalness - simplified without dependent indicators
  # Use a proxy based on area and shape
  result <- units
  area_ha <- as.numeric(sf::st_area(units)) / 10000
  # Larger continuous areas = higher naturalness
  n3 <- pmin(log1p(area_ha) / log1p(100), 1) * 100
  result$N3 <- n3
  result
}

#' @noRd
indicator_production_volume <- function(units, layers = NULL, ...) {
  # P1: Timber volume - estimate from NDVI
  if (!is.null(layers) && inherits(layers, "nemeton_layers") &&
      "ndvi" %in% names(layers$rasters)) {
    cli::cli_alert_info("P1: Estimating timber volume from NDVI")
    ndvi_raster <- layers$rasters[["ndvi"]]
    ndvi_mean <- exactextractr::exact_extract(ndvi_raster,
      as_pure_sf(units), fun = "mean", progress = FALSE
    )
    # NDVI -> volume proxy: NDVI 0.8 ~ 200 m3/ha for mature temperate forest
    return(pmax(0, ndvi_mean) * 250)
  }
  rep(NA_real_, nrow(units))
}

#' @noRd
indicator_production_productivity <- function(units, layers = NULL, ...) {
  # P2: Productivity - estimate from NDVI as proxy for NPP
  if (!is.null(layers) && inherits(layers, "nemeton_layers") &&
      "ndvi" %in% names(layers$rasters)) {
    cli::cli_alert_info("P2: Estimating productivity from NDVI")
    ndvi_raster <- layers$rasters[["ndvi"]]
    ndvi_mean <- exactextractr::exact_extract(ndvi_raster,
      as_pure_sf(units), fun = "mean", progress = FALSE
    )
    # NDVI as proxy: scale to m3/ha/yr (typical range 3-15)
    return(pmax(0, ndvi_mean) * 15)
  }
  rep(NA_real_, nrow(units))
}

#' @noRd
indicator_production_quality <- function(units, layers = NULL, ...) {
  # P3: Timber quality - proxy from slope and NDVI
  if (!is.null(layers) && inherits(layers, "nemeton_layers")) {
    scores <- rep(50, nrow(units))  # Base neutral score
    # Lower slope = better access = higher quality management
    if ("dem" %in% names(layers$rasters)) {
      dem <- layers$rasters[["dem"]]
      slope <- terra::terrain(dem, v = "slope", unit = "degrees")
      slope_mean <- exactextractr::exact_extract(slope,
        as_pure_sf(units), fun = "mean", progress = FALSE
      )
      # Gentle slopes (< 15°) favor quality forestry
      slope_score <- pmax(0, 1 - slope_mean / 30) * 50
      scores <- scores + slope_score - 25
    }
    # Higher NDVI = healthier trees = better quality
    if ("ndvi" %in% names(layers$rasters)) {
      ndvi_raster <- layers$rasters[["ndvi"]]
      ndvi_mean <- exactextractr::exact_extract(ndvi_raster,
        as_pure_sf(units), fun = "mean", progress = FALSE
      )
      ndvi_score <- pmax(0, ndvi_mean / 0.8) * 50
      scores <- scores + ndvi_score - 25
    }
    return(pmin(pmax(scores, 0), 100))
  }
  rep(NA_real_, nrow(units))
}
