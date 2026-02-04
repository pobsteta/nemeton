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

# Package-level TWI cache (avoids recomputing for W2, W3, F2, R3)
.twi_cache <- new.env(parent = emptyenv())

#' Get or compute TWI raster with caching
#'
#' Returns a cached TWI raster if one exists for the given DEM fingerprint,
#' otherwise computes it (GRASS preferred, terra D8 fallback) and caches.
#' @param dem A SpatRaster DEM
#' @return A SpatRaster with TWI values
#' @keywords internal
#' @noRd
get_or_compute_twi <- function(dem) {
  # Key = DEM fingerprint (dimensions + extent + CRS)
  key <- paste(nrow(dem), ncol(dem),
               paste(as.vector(terra::ext(dem)), collapse = ","),
               terra::crs(dem, describe = TRUE)$code,
               sep = "|")

  if (exists(key, envir = .twi_cache)) {
    cli::cli_alert_info("TWI: Using cached raster")
    return(get(key, envir = .twi_cache))
  }

  # Compute: prefer GRASS, fallback terra D8
  if (requireNamespace("fasterRaster", quietly = TRUE)) {
    twi_raster <- calculate_twi_grass(dem)
  } else {
    twi_raster <- calculate_twi_terra(dem)
  }

  assign(key, twi_raster, envir = .twi_cache)
  twi_raster
}

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

  # --- Path 1: Full inventory data (species/age/density columns) ---
  if (has_inventory) {
    species <- units[[species_col]]
    age <- units[[age_col]]
    density <- units[[density_col]]

    biomass <- calculate_allometric_biomass(species, age, density)
    msg_info("indicator_carbon_biomass")
    return(biomass)
  }

  units_sf <- as_pure_sf(units)

  # --- Path 2: LiDAR MNH available → tutorial 02 allometric model ---
  mnh_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "lidar_mnh") else NULL
  if (!is.null(mnh_raster)) {
    cli::cli_alert_info("Estimating C1 from LiDAR MNH (canopy height model)")
    zmean <- safe_extract(
      mnh_raster, units_sf, fun = "mean", progress = FALSE
    )
    # pzabove2: proportion of MNH pixels > 2m (canopy cover %)
    mnh_above2 <- mnh_raster > 2
    pzabove2 <- safe_extract(
      mnh_above2, units_sf, fun = "mean", progress = FALSE
    ) * 100
    # AGB = k * (pzabove2/100) * zmean^1.5  (tutorial 02 model)
    k_biomasse <- 2.5
    fraction_carbone <- 0.47
    agb <- k_biomasse * (pzabove2 / 100) * (pmax(0, zmean, na.rm = FALSE)^1.5)
    biomass <- agb * fraction_carbone
    return(biomass)
  }

  # --- Path 3: BD Forêt V2 → enrich parcels then allometric model ---
  bdforet_sf <- if (!is.null(layers)) resolve_vector_layer(layers, "bdforet") else NULL
  if (!is.null(bdforet_sf) && nrow(bdforet_sf) > 0) {
    cli::cli_alert_info("Enriching parcels with BD For\u00eat data for C1")
    enriched <- enrich_parcels_bdforet(units_sf, bdforet_sf)
    if (any(!is.na(enriched$species))) {
      biomass <- calculate_allometric_biomass(
        enriched$species, enriched$age, enriched$density
      )
      return(biomass)
    }
  }

  # --- Path 4: NDVI fallback ---
  ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
  if (!is.null(ndvi_raster)) {
    cli::cli_alert_info("No LiDAR/BD For\u00eat; estimating C1 from NDVI")
    ndvi_mean <- safe_extract(
      ndvi_raster, units_sf, fun = "mean", progress = FALSE
    )
    # NDVI-to-biomass proxy: scale NDVI (0-1) to approximate carbon stock
    # (tC/ha). Typical temperate forest: ~80-150 tC/ha at high NDVI.
    biomass <- pmax(0, ndvi_mean, na.rm = FALSE) * 150
    return(biomass)
  }

  # Last resort: return NA
  cli::cli_alert_warning(
    "C1: no inventory, LiDAR, BD For\u00eat, or NDVI data; returning NA"
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

  # Get NDVI raster (resolve lazy-load)
  ndvi_raster <- resolve_raster_layer(layers, ndvi_layer)
  if (is.null(ndvi_raster)) {
    stop(sprintf("NDVI layer '%s' not found in layers", ndvi_layer), call. = FALSE)
  }

  # Extract mean NDVI for each unit
  ndvi_mean <- safe_extract(
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
#' @return Numeric vector of network density (m/ha)
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

  # Get watercourse vector layer (resolve lazy-load)
  watercourses <- resolve_vector_layer(layers, watercourse_layer)
  if (is.null(watercourses)) {
    stop(sprintf("Watercourse layer '%s' not found in layers", watercourse_layer), call. = FALSE)
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

    # Calculate total length of watercourses (in meters)
    if (nrow(intersected) > 0) {
      total_length_m <- as.numeric(sum(sf::st_length(intersected)))
    } else {
      total_length_m <- 0
    }

    # Calculate unit area (in ha)
    area_m2 <- as.numeric(sf::st_area(unit_geom))
    area_ha <- area_m2 / 10000

    # Density = m / ha (consistent with tuto 03)
    density[i] <- total_length_m / area_ha
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

  # Strategy 1: Use BD TOPO water surfaces (mares, retenues, étangs)
  water_surfaces_sf <- resolve_vector_layer(layers, "water_surfaces")
  if (!is.null(water_surfaces_sf) && nrow(water_surfaces_sf) > 0) {
    cli::cli_alert_info("W2: Computing wetland coverage from BD TOPO water surfaces")

    if (!sf::st_crs(units) == sf::st_crs(water_surfaces_sf)) {
      water_surfaces_sf <- sf::st_transform(water_surfaces_sf, sf::st_crs(units))
    }

    for (i in seq_len(nrow(units))) {
      unit_geom <- units[i, ]
      parcel_area <- as.numeric(sf::st_area(unit_geom))

      intersected <- tryCatch(
        suppressWarnings(sf::st_intersection(water_surfaces_sf, unit_geom)),
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
  # Prefer GRASS TWI (same as W3) for consistency, fallback to terra D8
  dem <- get_dem_raster(layers)
  if (!is.null(dem)) {
    cli::cli_alert_info("W2: Estimating wetlands from TWI (threshold > 12)")
    twi_raster <- get_or_compute_twi(dem)

    for (i in seq_len(nrow(units))) {
      twi_vals <- safe_extract(
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
  lc_raster <- resolve_raster_layer(layers, wetland_layer)
  if (is.null(lc_raster)) lc_raster <- resolve_raster_layer(layers, "landcover")
  if (is.null(lc_raster)) lc_raster <- resolve_raster_layer(layers, "forest_cover")
  if (!is.null(wetland_values) && !is.null(lc_raster)) {
    cli::cli_alert_info("W2: Computing wetland coverage from OSO landcover codes")

    for (i in seq_len(nrow(units))) {
      lc_values <- safe_extract(
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
#' Calculates TWI using fasterRaster/GRASS GIS (preferred) or terra fallback (D8).
#' Higher values indicate areas with greater water accumulation potential.
#'
#' The GRASS method (via fasterRaster) performs proper hydrological conditioning:
#' depression filling, flow direction, flow accumulation, then TWI = ln(SCA / tan(slope)).
#' The terra D8 method is a simpler approximation used as fallback.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing DEM raster
#' @param dem_layer Character. Name of DEM layer in layers object
#' @param method Character. TWI calculation method: "auto" (prefer GRASS),
#'   "grass" (fasterRaster/GRASS GIS), or "d8" (terra D8). Default "auto".
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
                                method = c("auto", "grass", "d8")) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  # Match and validate method
  method <- match.arg(method)

  # Get best available DEM (prefer LiDAR HD MNT over BD ALTI)
  dem <- get_dem_raster(layers)
  if (is.null(dem)) {
    dem <- resolve_raster_layer(layers, dem_layer)
  }
  if (is.null(dem)) {
    stop(sprintf("No DEM layer available (tried lidar_mnt, %s)", dem_layer), call. = FALSE)
  }

  # Calculate TWI (cached across W2, W3, F2, R3)
  if (method == "d8") {
    twi_raster <- calculate_twi_terra(dem)
  } else {
    twi_raster <- get_or_compute_twi(dem)
  }

  # Extract mean TWI for each unit
  twi_mean <- safe_extract(
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

#' Calculate TWI using fasterRaster/GRASS GIS
#'
#' Uses GRASS GIS via fasterRaster for proper hydrological TWI computation:
#' depression filling, flow direction/accumulation via wetness().
#' @keywords internal
#' @noRd
calculate_twi_grass <- function(dem) {
  if (!requireNamespace("fasterRaster", quietly = TRUE)) {
    stop("fasterRaster package required for GRASS TWI calculation", call. = FALSE)
  }

  # Detect GRASS installation
  grass_dir <- Sys.getenv("GRASS_DIR", unset = "")
  if (grass_dir == "") {
    # Common GRASS paths on Linux
    candidates <- c(
      "/usr/lib/grass84", "/usr/lib/grass83", "/usr/lib/grass82",
      "/usr/lib/grass", "/usr/local/grass"
    )
    for (path in candidates) {
      if (dir.exists(path)) {
        grass_dir <- path
        break
      }
    }
  }

  if (grass_dir == "" || !dir.exists(grass_dir)) {
    warning("GRASS GIS not found, falling back to terra D8", call. = FALSE)
    return(calculate_twi_terra(dem))
  }

  tryCatch({
    cli::cli_alert_info("W3: Computing TWI with fasterRaster/GRASS ({basename(grass_dir)})")

    # Initialize GRASS session
    fasterRaster::faster(grassDir = grass_dir)

    # Convert terra raster to GRaster
    elev <- fasterRaster::fast(dem)

    # Compute TWI using GRASS r.topidx (handles depression filling internally)
    twi_grass <- fasterRaster::wetness(elev)

    # Convert back to terra raster
    twi_terra <- terra::rast(twi_grass)

    # Sanitize output
    twi_terra[is.infinite(twi_terra)] <- NA
    twi_terra[is.nan(twi_terra)] <- NA
    twi_terra[twi_terra < 0] <- 0
    twi_terra[twi_terra > 50] <- NA

    cli::cli_alert_success("W3: GRASS TWI computed successfully")
    twi_terra
  }, error = function(e) {
    warning(
      sprintf("GRASS TWI failed (%s), falling back to terra D8", conditionMessage(e)),
      call. = FALSE
    )
    calculate_twi_terra(dem)
  })
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
  is_raster <- !is.null(resolve_raster_layer(layers, soil_layer))
  is_vector <- !is.null(resolve_vector_layer(layers, soil_layer))

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
  # Get soil raster (resolve lazy-load)
  soil_raster <- resolve_raster_layer(layers, soil_layer)

  # Extract mean soil values for each unit
  soil_values <- safe_extract(
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
  # Get soil vector layer (resolve lazy-load)
  soil_vector <- resolve_vector_layer(layers, soil_layer)

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

#' Soil Fertility Index (F2)
#'
#' Calculates soil fertility potential by combining TWI (water/nutrient
#' accumulation) and slope (erosion risk). Follows the tuto 03 methodology:
#' F2 = (twi_norm + slope_norm) / 2
#'
#' TWI is computed via GRASS (fasterRaster) when available, terra D8 otherwise.
#' Higher values indicate more fertile soil conditions.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing DEM raster
#' @param dem_layer Character. Name of DEM layer
#'
#' @return Numeric vector of fertility scores (0-100, higher = more fertile)
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(rasters = list(dem = "dem.tif"))
#' results <- indicator_soil_erosion(units, layers)
#' }
indicator_soil_erosion <- function(units,
                                   layers,
                                   dem_layer = "dem") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  # Get best available DEM (prefer LiDAR HD MNT over BD ALTI)
  dem <- get_dem_raster(layers)
  if (is.null(dem)) {
    dem <- resolve_raster_layer(layers, dem_layer)
  }
  if (is.null(dem)) {
    stop(sprintf("No DEM layer available (tried lidar_mnt, %s)", dem_layer), call. = FALSE)
  }

  units_sf <- as_pure_sf(units)

  # 1. Compute TWI (cached across W2, W3, F2, R3)
  cli::cli_alert_info("F2: Computing fertility from TWI + slope")
  twi_raster <- get_or_compute_twi(dem)

  twi_mean <- safe_extract(twi_raster, units_sf, fun = "mean", progress = FALSE)

  # 2. Compute slope (degrees)
  slope_raster <- terra::terrain(dem, v = "slope", unit = "degrees")
  slope_mean <- safe_extract(slope_raster, units_sf, fun = "mean", progress = FALSE)

  # 3. Normalize TWI: [5, 15] -> [0, 100] (higher TWI = more fertile)
  twi_norm <- pmax(pmin((twi_mean - 5) / 10 * 100, 100), 0)

  # 4. Normalize slope: [0°, 45°] -> [100, 0] (flatter = more fertile)
  slope_norm <- pmax(pmin(100 - (slope_mean / 45) * 100, 100), 0)

  # 5. F2 = average of TWI and slope components
  fertility <- round((twi_norm + slope_norm) / 2, 1)

  # Log calculation
  msg_info("indicator_soil_erosion")

  fertility
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
                                              landcover_layer = "landcover",
                                              forest_values = seq(1, 6),
                                              buffer = 1000) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }
  if (!inherits(layers, "nemeton_layers")) {
    stop("layers must be a nemeton_layers object", call. = FALSE)
  }

  # Resolve landcover raster (handle lazy-load)
  landcover <- resolve_raster_layer(layers, landcover_layer)
  if (is.null(landcover)) {
    cli::cli_alert_warning("L1: Landcover layer '{landcover_layer}' not available, returning NA")
    return(rep(NA_real_, nrow(units)))
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
  # Requires forest_cover or landcover raster from layers
  lc <- NULL
  if (!is.null(layers) && inherits(layers, "nemeton_layers")) {
    lc <- resolve_raster_layer(layers, "forest_cover")
    if (is.null(lc)) lc <- resolve_raster_layer(layers, "landcover")
  }
  if (is.null(lc)) {
    # Fallback: estimate from NDVI (high NDVI = forested)
    ndvi <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
    if (!is.null(ndvi)) {
      cli::cli_alert_info("A1: No forest_cover layer, estimating from NDVI")
      buffers <- sf::st_buffer(units, dist = 1000)
      coverage <- safe_extract(ndvi, as_pure_sf(buffers),
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
  ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
  if (!is.null(ndvi_raster)) {
    cli::cli_alert_info("F1: Estimating soil fertility from NDVI productivity")
    fertility <- safe_extract(ndvi_raster,
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
  # F2: Soil fertility (TWI + slope) - delegates to indicator_soil_erosion
  if (!is.null(layers) && inherits(layers, "nemeton_layers")) {
    return(indicator_soil_erosion(units, layers))
  }
  cli::cli_alert_warning("F2: No layers available for fertility, returning NA")
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
  ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
  if (!is.null(ndvi_raster)) {
    cli::cli_alert_info("E1: Estimating fuelwood potential from NDVI")
    ndvi_mean <- safe_extract(ndvi_raster,
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
  # P1: Timber volume - prefer LiDAR MNH, fallback to NDVI
  if (!is.null(layers) && inherits(layers, "nemeton_layers")) {
    # Strategy 1: Use LiDAR MNH (Canopy Height Model) for volume estimation
    mnh_raster <- resolve_raster_layer(layers, "lidar_mnh")
    if (!is.null(mnh_raster)) {
      cli::cli_alert_info("P1: Estimating timber volume from LiDAR MNH")
      units_sf <- as_pure_sf(units)
      mnh_mean <- safe_extract(mnh_raster, units_sf,
        fun = "mean", progress = FALSE)
      # Height-to-volume relationship (temperate forests, approximate)
      # Typical: H=10m -> ~100 m3/ha, H=20m -> ~300 m3/ha, H=30m -> ~500 m3/ha
      # Using: V = 0.55 * H^1.8 (simplified power model)
      volume <- 0.55 * pmax(0, mnh_mean)^1.8
      return(volume)
    }

    # Strategy 2: Fallback to NDVI
    ndvi_raster <- resolve_raster_layer(layers, "ndvi")
    if (!is.null(ndvi_raster)) {
      cli::cli_alert_info("P1: Estimating timber volume from NDVI")
      ndvi_mean <- safe_extract(ndvi_raster,
        as_pure_sf(units), fun = "mean", progress = FALSE
      )
      # NDVI -> volume proxy: NDVI 0.8 ~ 200 m3/ha for mature temperate forest
      return(pmax(0, ndvi_mean) * 250)
    }
  }
  rep(NA_real_, nrow(units))
}

#' @noRd
indicator_production_productivity <- function(units, layers = NULL, ...) {
  # P2: Productivity - estimate from NDVI as proxy for NPP
  ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
  if (!is.null(ndvi_raster)) {
    cli::cli_alert_info("P2: Estimating productivity from NDVI")
    ndvi_mean <- safe_extract(ndvi_raster,
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
    dem <- get_dem_raster(layers)
    if (!is.null(dem)) {
      slope <- terra::terrain(dem, v = "slope", unit = "degrees")
      slope_mean <- safe_extract(slope,
        as_pure_sf(units), fun = "mean", progress = FALSE
      )
      # Gentle slopes (< 15°) favor quality forestry
      slope_score <- pmax(0, 1 - slope_mean / 30) * 50
      scores <- scores + slope_score - 25
    }
    # Higher NDVI = healthier trees = better quality
    ndvi_raster <- resolve_raster_layer(layers, "ndvi")
    if (!is.null(ndvi_raster)) {
      ndvi_mean <- safe_extract(ndvi_raster,
        as_pure_sf(units), fun = "mean", progress = FALSE
      )
      ndvi_score <- pmax(0, ndvi_mean / 0.8) * 50
      scores <- scores + ndvi_score - 25
    }
    return(pmin(pmax(scores, 0), 100))
  }
  rep(NA_real_, nrow(units))
}
