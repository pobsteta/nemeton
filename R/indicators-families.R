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

# Package-level nasapower wind cache (avoids re-downloading for L1, R2)
.wind_cache <- new.env(parent = emptyenv())

#' Get wind climatology from NASA POWER with caching
#'
#' Downloads monthly wind direction (WD10M) and speed (WS10M) climatology from
#' NASA POWER, with both in-memory and file-based caching. Returns the
#' speed-weighted mean wind direction in degrees.
#'
#' @param units An sf object (used to compute centroid location)
#' @param default_dir Numeric. Default wind direction (degrees) if unavailable.
#' @return Numeric. Dominant wind direction in degrees.
#' @keywords internal
#' @noRd
get_nasapower_wind <- function(units, default_dir = 270, cache_dir = NULL) {

  # Compute centroid in WGS84
  centroid <- suppressWarnings(sf::st_centroid(sf::st_union(units)))
  coords <- sf::st_coordinates(sf::st_transform(centroid, 4326))
  lon <- round(coords[1, 1], 2)
  lat <- round(coords[1, 2], 2)

  # In-memory cache key (rounded to ~1km grid)

  cache_key <- paste0("wind_", lon, "_", lat)

  if (exists(cache_key, envir = .wind_cache)) {
    wind_dir <- get(cache_key, envir = .wind_cache)
    cli::cli_alert_info("Wind: Using cached direction {wind_dir}\u00b0")
    return(wind_dir)
  }

  # File-based cache — per-project or global fallback
  if (is.null(cache_dir)) {
    cache_dir <- file.path(get_global_cache_dir(), "nasapower")
  }
  cache_file <- file.path(cache_dir, "nasapower_wind.rds")

  if (file.exists(cache_file)) {
    tryCatch({
      cached <- readRDS(cache_file)
      assign(cache_key, cached, envir = .wind_cache)
      cli::cli_alert_info("Wind: Loaded from file cache ({cached}\u00b0)")
      return(cached)
    }, error = function(e) NULL)
  }

  # Download from NASA POWER
  if (!requireNamespace("nasapower", quietly = TRUE)) {
    cli::cli_alert_info("Wind: nasapower not installed, using default {default_dir}\u00b0")
    return(default_dir)
  }

  wind_dir <- tryCatch({
    wind_data <- nasapower::get_power(
      community = "ag",
      lonlat = c(lon, lat),
      pars = c("WD10M", "WS10M"),
      temporal_api = "climatology"
    )
    wd_values <- as.numeric(wind_data[wind_data$PARAMETER == "WD10M", 4:15])
    ws_values <- as.numeric(wind_data[wind_data$PARAMETER == "WS10M", 4:15])

    if (length(wd_values) == 12 && length(ws_values) == 12 &&
        !all(is.na(wd_values)) && !all(is.na(ws_values))) {
      result <- round(stats::weighted.mean(wd_values, ws_values, na.rm = TRUE))

      # Save to file cache
      if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
      tryCatch(saveRDS(result, cache_file), error = function(e) NULL)

      # Save to memory cache
      assign(cache_key, result, envir = .wind_cache)
      cli::cli_alert_info("Wind: Downloaded from NASA POWER ({result}\u00b0), cached")
      result
    } else {
      default_dir
    }
  }, error = function(e) {
    cli::cli_alert_info("Wind: NASA POWER unavailable, using default {default_dir}\u00b0")
    default_dir
  })

  wind_dir
}

#' Get or compute TWI raster with caching
#'
#' Returns a cached TWI raster if one exists for the given DEM fingerprint,
#' otherwise computes it (GRASS preferred, terra D8 fallback) and caches.
#' @param dem A SpatRaster DEM
#' @param cache_dir Character. Directory for file cache (per-project).
#'   If NULL, falls back to global nemeton cache.
#' @return A SpatRaster with TWI values
#' @keywords internal
#' @noRd
get_or_compute_twi <- function(dem, cache_dir = NULL) {
  # Key = DEM fingerprint (dimensions + extent + CRS)
  key <- paste(nrow(dem), ncol(dem),
               paste(as.vector(terra::ext(dem)), collapse = ","),
               terra::crs(dem, describe = TRUE)$code,
               sep = "|")

  # 1. Memory cache (instant)
  if (exists(key, envir = .twi_cache)) {
    cli::cli_alert_info("TWI: Using cached raster (memory)")
    return(get(key, envir = .twi_cache))
  }

  # 2. File cache (persists between sessions) — per-project or global fallback
  if (is.null(cache_dir)) {
    cache_dir <- file.path(get_global_cache_dir(), "twi")
  }
  cache_file <- file.path(cache_dir, "twi.tif")

  if (file.exists(cache_file)) {
    tryCatch({
      twi_raster <- terra::rast(cache_file)
      assign(key, twi_raster, envir = .twi_cache)
      cli::cli_alert_info("TWI: Loaded from file cache")
      return(twi_raster)
    }, error = function(e) NULL)
  }

  # 3. Compute: prefer GRASS, fallback terra D8
  if (requireNamespace("fasterRaster", quietly = TRUE)) {
    twi_raster <- calculate_twi_grass(dem)
  } else {
    twi_raster <- calculate_twi_terra(dem)
  }

  # Save to both caches
  assign(key, twi_raster, envir = .twi_cache)
  tryCatch({
    if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
    terra::writeRaster(twi_raster, cache_file, overwrite = TRUE)
    cli::cli_alert_info("TWI: Saved to file cache")
  }, error = function(e) NULL)

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
#' results <- indicateur_c1_biomasse(units)
#' }
indicateur_c1_biomasse <- function(units,
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
    msg_info("indicateur_c1_biomasse")
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
#' results <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi")
#'
#' # Multi-date NDVI with trend
#' results <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi", trend = TRUE)
#' }
indicateur_c2_ndvi <- function(units,
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
  msg_info("indicateur_c2_ndvi")

  ndvi_mean
}

# ==============================================================================
# FAMILY W: WATER / INFILTRÉE
# Infiltration, stockage et restitution de l'eau, protection des sources
# ==============================================================================

#' Hydrographic Network Density (W1)
#'
#' Calculates stream/river network length density within or near forest parcels.
#' Includes a proximity bonus for parcels near watercourses (within 500m)
#' that are not directly crossed, reflecting the hydrological influence of
#' nearby streams on water table and microclimate.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing watercourse vector layer
#' @param watercourse_layer Character. Name of watercourse layer in layers object
#' @param buffer Numeric. Buffer distance (meters) for proximity analysis. Default 0.
#' @param proximity_m Numeric. Maximum distance (m) for proximity bonus. Default 500.
#' @param proximity_ref Numeric. Equivalent density bonus (m/ha) at distance 0. Default 50.
#'
#' @return Numeric vector of network density (m/ha)
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(vectors = list(streams = "watercourses.gpkg"))
#' results <- indicateur_w1_reseau(units, layers, watercourse_layer = "streams")
#' }
indicateur_w1_reseau <- function(units,
                                    layers,
                                    watercourse_layer = "water_network",
                                    buffer = 0,
                                    proximity_m = 500,
                                    proximity_ref = 50) {
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
    cli::cli_warn("W1: No watercourse data available for this area. Returning 0.")
    return(rep(0, nrow(units)))
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
    area_m2 <- as.numeric(sf::st_area(units[i, ]))
    area_ha <- area_m2 / 10000

    # Direct density = m / ha (consistent with tuto 03)
    direct_density <- total_length_m / area_ha

    # Proximity bonus: parcels near watercourses benefit from water table influence
    # Decreases linearly from proximity_ref at 0m to 0 at proximity_m
    if (total_length_m == 0 && proximity_m > 0) {
      min_dist <- as.numeric(min(sf::st_distance(units[i, ], watercourses)))
      if (min_dist < proximity_m) {
        proximity_bonus <- (1 - min_dist / proximity_m) * proximity_ref
      } else {
        proximity_bonus <- 0
      }
    } else {
      # Parcel already crossed by watercourse: full proximity bonus
      proximity_bonus <- proximity_ref
    }

    density[i] <- direct_density + proximity_bonus
  }

  # Log calculation
  msg_info("indicateur_w1_reseau")

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
#' results <- indicateur_w2_zones_humides(units, layers, wetland_values = c(50, 51, 52))
#' }
indicateur_w2_zones_humides <- function(units,
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
  has_any_source <- FALSE

  # Source 1: BD TOPO water surfaces (mares, retenues, étangs)
  water_surfaces_sf <- resolve_vector_layer(layers, "water_surfaces")
  if (!is.null(water_surfaces_sf) && nrow(water_surfaces_sf) > 0) {
    cli::cli_alert_info("W2: Adding BD TOPO water surfaces coverage")
    has_any_source <- TRUE

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
        coverage[i] <- coverage[i] + (wetland_area / parcel_area) * 100
      }
    }
  }

  # Source 2: TWI threshold (TWI > 12 = potential wetland zones)
  dem <- get_dem_raster(layers)
  if (!is.null(dem)) {
    cli::cli_alert_info("W2: Adding TWI-based wetland zones (threshold > 12)")
    has_any_source <- TRUE
    twi_raster <- get_or_compute_twi(dem, cache_dir = layers$cache_dir)

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
          coverage[i] <- coverage[i] + (wetland_frac / total_frac) * 100
        }
      }
    }
  }

  # Source 3: OSO landcover wetland codes (if provided)
  lc_raster <- resolve_raster_layer(layers, wetland_layer)
  if (is.null(lc_raster)) lc_raster <- resolve_raster_layer(layers, "landcover")
  if (is.null(lc_raster)) lc_raster <- resolve_raster_layer(layers, "forest_cover")
  if (!is.null(wetland_values) && !is.null(lc_raster)) {
    cli::cli_alert_info("W2: Adding OSO landcover wetland coverage")
    has_any_source <- TRUE

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
          coverage[i] <- coverage[i] + (wetland_fraction / total_fraction) * 100
        }
      }
    }
  }

  if (!has_any_source) {
    cli::cli_alert_warning("W2: No wetland data available (no vectors, DEM, or landcover)")
    return(rep(NA_real_, nrow(units)))
  }

  msg_info("indicateur_w2_zones_humides")
  pmin(coverage, 100)
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
#' results <- indicateur_w3_humidite(units, layers, dem_layer = "dem")
#' }
indicateur_w3_humidite <- function(units,
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
    twi_raster <- get_or_compute_twi(dem, cache_dir = layers$cache_dir)
  }

  # Extract mean TWI for each unit
  twi_mean <- safe_extract(
    twi_raster,
    as_pure_sf(units),
    fun = "mean",
    progress = FALSE
  )

  # Log calculation
  msg_info("indicateur_w3_humidite")

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

    # fasterRaster needs terra/sf/data.table loaded, and its namespace fully attached
    # to find internal .fasterRaster object (fails in Shiny without this)
    requireNamespace("terra", quietly = TRUE)
    requireNamespace("sf", quietly = TRUE)
    requireNamespace("data.table", quietly = TRUE)
    loadNamespace("fasterRaster")

    # Initialize GRASS session
    fasterRaster::faster(grassDir = grass_dir)

    # GRASS TWI requires projected CRS (not lon/lat)
    if (terra::is.lonlat(dem)) {
      dem <- terra::project(dem, "EPSG:2154")
    }

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
#' results <- indicateur_f1_fertilite(units, layers, soil_layer = "soil")
#' }
indicateur_f1_fertilite <- function(units,
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
  msg_info("indicateur_f1_fertilite")

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
#' results <- indicateur_f2_erosion(units, layers)
#' }
indicateur_f2_erosion <- function(units,
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
  twi_raster <- get_or_compute_twi(dem, cache_dir = layers$cache_dir)

  twi_mean <- safe_extract(twi_raster, units_sf, fun = "mean", progress = FALSE)

  # 2. Compute slope (degrees)
  slope_raster <- terra::terrain(dem, v = "slope", unit = "degrees")
  slope_mean <- safe_extract(slope_raster, units_sf, fun = "mean", progress = FALSE)

  # 3. Normalize TWI: [2.5, 10] -> [0, 100] (higher TWI = more fertile)
  # Window adjusted to match typical TWI values (2.5-10 range covers most landscapes)
  twi_norm <- pmax(pmin((twi_mean - 2.5) / 7.5 * 100, 100), 0)

  # 4. Normalize slope: [0°, 45°] -> [100, 0] (flatter = more fertile)
  slope_norm <- pmax(pmin(100 - (slope_mean / 45) * 100, 100), 0)

  # 5. F2 = average of TWI and slope components
  fertility <- round((twi_norm + slope_norm) / 2, 1)

  # Log calculation
  msg_info("indicateur_f2_erosion")

  fertility
}

# ==============================================================================
# FAMILY L: LANDSCAPE / ESTHÉTIQUE
# Qualité paysagère, composition, diversité des structures, harmonies
# ==============================================================================

#' Sylvosphere - Edge Effect (L1)
#'
#' Composite indicator (0-100) with 3 components:
#' - Geometry (30%): shape index measuring parcel irregularity
#' - Matrix contrast (40%): land use contrast in buffer zone (OSO classes)
#' - Exposure (30%): wind (60%) and sun (40%) exposure based on boundary orientation
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object containing land cover (optional)
#' @param landcover_layer Character. Name of land cover layer
#' @param forest_values Numeric vector. Land cover codes for forest
#' @param buffer Numeric. Buffer distance (meters) for contrast analysis. Default 50m.
#'
#' @return Numeric vector of sylvosphere scores (0-100)
#'
#' @export
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
#' results <- indicateur_l2_fragmentation(
#'   units, layers,
#'   forest_values = c(1, 2, 3), buffer = 50
#' )
#' }
indicateur_l2_fragmentation <- function(units,
                                              layers = NULL,
                                              landcover_layer = "landcover",
                                              forest_values = seq(1, 6),
                                              buffer = 50) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  # --- Component 1: Geometry (30%) ---
  # Shape index: SI = perimeter / (2 * sqrt(pi * area))
  l1_geometrie <- numeric(nrow(units))
  perimeters <- numeric(nrow(units))
  areas <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    boundary <- sf::st_cast(units[i, ], "MULTILINESTRING")
    perimeters[i] <- as.numeric(sf::st_length(boundary))
    areas[i] <- as.numeric(sf::st_area(units[i, ]))
    si <- perimeters[i] / (2 * sqrt(pi * areas[i]))
    l1_geometrie[i] <- pmin(100, (si - 1) * 25)
  }

  # --- Component 2: Matrix contrast (40%) ---
  # OSO contrast table
  oso_contrast <- c(
    "16" = 0, "17" = 0, "18" = 0,    # Forest (conif, broadleaf, mixed)
    "19" = 15,                         # Landes
    "20" = 20,                         # Prairies
    "21" = 50, "22" = 50, "23" = 50,  # Cultures
    "24" = 45,                         # Vignes
    "25" = 90, "26" = 90, "27" = 90, "28" = 90,  # Built-up
    "29" = 75,                         # Roads
    "30" = 30                          # Water
  )

  l1_contraste <- numeric(nrow(units))
  has_landcover <- FALSE

  if (!is.null(layers) && inherits(layers, "nemeton_layers")) {
    landcover <- resolve_raster_layer(layers, landcover_layer)
    if (is.null(landcover)) landcover <- resolve_raster_layer(layers, "forest_cover")
    if (!is.null(landcover)) has_landcover <- TRUE
  }

  if (has_landcover) {
    for (i in seq_len(nrow(units))) {
      # Buffer around parcel, subtract parcel = edge zone
      edge_zone <- tryCatch({
        geom_i <- sf::st_geometry(units[i, ])
        buf <- sf::st_buffer(geom_i, dist = buffer)
        sf::st_sf(geometry = sf::st_difference(buf, geom_i))
      }, error = function(e) NULL)

      if (is.null(edge_zone) || as.numeric(sf::st_area(edge_zone)) < 1) {
        l1_contraste[i] <- 50  # neutral fallback
        next
      }

      # Extract landcover values in edge zone
      lc_values <- tryCatch({
        safe_extract(landcover, as_pure_sf(edge_zone), progress = FALSE)[[1]]$value
      }, error = function(e) NULL)

      if (is.null(lc_values) || length(lc_values) == 0) {
        l1_contraste[i] <- 50
        next
      }

      lc_values <- lc_values[!is.na(lc_values)]
      if (length(lc_values) == 0) {
        l1_contraste[i] <- 50
        next
      }

      # Weighted contrast by pixel count
      lc_tab <- table(as.character(lc_values))
      total_pixels <- sum(lc_tab)
      weighted_contrast <- 0
      for (cls in names(lc_tab)) {
        weight <- if (cls %in% names(oso_contrast)) oso_contrast[cls] else 50
        weighted_contrast <- weighted_contrast + (as.numeric(weight) * lc_tab[cls])
      }
      l1_contraste[i] <- weighted_contrast / total_pixels
    }
  } else {
    # No landcover: neutral contrast
    l1_contraste <- rep(50, nrow(units))
  }

  # --- Component 3: Exposure (30%) ---
  # Wind (60%) + Sun (40%)
  # Get dominant wind direction (cached, default 225° SW for France)
  wind_dir_deg <- get_nasapower_wind(units, default_dir = 225, cache_dir = if (!is.null(layers)) layers$cache_dir)

  l1_exposition <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    # Get boundary coordinates for segment analysis
    boundary <- sf::st_boundary(sf::st_geometry(units[i, ]))
    coords <- sf::st_coordinates(boundary)

    if (nrow(coords) < 3) {
      l1_exposition[i] <- 50
      next
    }

    # Geographic azimuth per segment: atan2(dx, dy) -> 0°=North, clockwise
    n_seg <- nrow(coords) - 1
    azimuths <- numeric(n_seg)
    seg_lengths <- numeric(n_seg)

    for (j in seq_len(n_seg)) {
      dx <- coords[j + 1, 1] - coords[j, 1]
      dy <- coords[j + 1, 2] - coords[j, 2]
      azimuths[j] <- (atan2(dx, dy) * 180 / pi + 360) %% 360
      seg_lengths[j] <- sqrt(dx^2 + dy^2)
    }

    # Wind exposure: max when edge normal is aligned with wind direction
    vent_exposure <- vapply(azimuths, function(az) {
      normale <- (az + 90) %% 360
      diff_angle <- abs(normale - wind_dir_deg)
      if (diff_angle > 180) diff_angle <- 360 - diff_angle
      cos(diff_angle * pi / 180)
    }, numeric(1))

    # Sun exposure: max when edge normal points South (180°)
    soleil_exposure <- vapply(azimuths, function(az) {
      normale <- (az + 90) %% 360
      diff_angle <- abs(normale - 180)
      if (diff_angle > 180) diff_angle <- 360 - diff_angle
      cos(diff_angle * pi / 180)
    }, numeric(1))

    total_len <- sum(seg_lengths)
    if (total_len > 0) {
      # Wind: absolute value (exposure regardless of face direction)
      wind_score <- sum(abs(vent_exposure) * seg_lengths) / total_len * 100
      # Sun: only positive (south-facing edges count)
      sun_score <- sum(pmax(0, soleil_exposure) * seg_lengths) / total_len * 100
    } else {
      wind_score <- 50
      sun_score <- 50
    }

    l1_exposition[i] <- 0.6 * wind_score + 0.4 * sun_score
  }

  # --- Synthesis ---
  l1 <- 0.30 * l1_geometrie + 0.40 * l1_contraste + 0.30 * l1_exposition
  l1 <- pmin(pmax(round(l1, 1), 0), 100)

  msg_info("indicateur_l2_fragmentation")
  l1
}

#' Landscape Fragmentation (L2)
#'
#' Calculates landscape fragmentation using landscapemetrics (COHESION + AI)
#' when available, or shape index fallback. Returns a score 0-100.
#'
#' @param units nemeton_units object
#' @param layers nemeton_layers object (optional, for raster-based metrics)
#' @param landcover_layer Character. Name of landcover layer in layers.
#' @param forest_values Numeric vector. Values representing forest in landcover.
#' @param buffer Numeric. Buffer distance in meters around union of parcels.
#'
#' @return Numeric vector of fragmentation scores (0-100)
#'
#' @export
#' @examples
#' \dontrun{
#' results <- indicateur_l1_sylvosphere(units, layers, buffer = 1000)
#' }
indicateur_l1_sylvosphere <- function(units, layers = NULL,
                                     landcover_layer = "landcover",
                                     forest_values = seq(1, 6),
                                     buffer = 1000) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (nrow(units) == 0) {
    stop("units is empty (no features)", call. = FALSE)
  }

  # Try landscapemetrics approach if layers available
  if (!is.null(layers) && inherits(layers, "nemeton_layers") &&
      requireNamespace("landscapemetrics", quietly = TRUE)) {

    landcover <- resolve_raster_layer(layers, landcover_layer)
    if (is.null(landcover)) landcover <- resolve_raster_layer(layers, "forest_cover")

    if (!is.null(landcover)) {
      tryCatch({
        # Buffer 1km around union of parcels
        union_geom <- sf::st_union(units)
        buffer_zone <- sf::st_buffer(union_geom, dist = buffer)

        # Crop landcover to buffer zone
        lc_cropped <- terra::crop(landcover, terra::vect(buffer_zone), snap = "out")
        lc_masked <- terra::mask(lc_cropped, terra::vect(buffer_zone))

        # Create forest mask (1 = forest, 0 = non-forest)
        is_forest <- function(x) {
          ifelse(x %in% forest_values, 1, 0)
        }
        forest_raster <- terra::app(lc_masked, is_forest)

        # Calculate landscape metrics
        metrics <- suppressWarnings(landscapemetrics::calculate_lsm(
          terra::as.int(forest_raster),
          what = c("lsm_l_cohesion", "lsm_l_ai")
        ))

        cohesion <- metrics$value[metrics$metric == "cohesion"]
        ai <- metrics$value[metrics$metric == "ai"]

        if (length(cohesion) > 0 && length(ai) > 0 &&
            !is.na(cohesion[1]) && !is.na(ai[1])) {
          # L2 = (COHESION + AI) / 2 — same value for all parcels
          l2_score <- (cohesion[1] + ai[1]) / 2
          l2_score <- pmin(pmax(round(l2_score, 1), 0), 100)

          msg_info("indicateur_l1_sylvosphere")
          return(rep(l2_score, nrow(units)))
        }
      }, error = function(e) {
        cli::cli_alert_warning("L2: landscapemetrics failed ({e$message}), using shape index fallback")
      })
    }
  }

  # Fallback: shape index per parcel
  scores <- numeric(nrow(units))
  for (i in seq_len(nrow(units))) {
    boundary <- sf::st_cast(units[i, ], "MULTILINESTRING")
    perimeter <- as.numeric(sf::st_length(boundary))
    area <- as.numeric(sf::st_area(units[i, ]))

    shape_index <- perimeter / (2 * sqrt(pi * area))
    scores[i] <- pmin(round(100 / shape_index, 1), 100)
  }

  msg_info("indicateur_l1_sylvosphere")
  scores
}

# ==============================================================================
# ALIAS FUNCTIONS
# Obsolete: previously mapped indicator names for compute_single_indicator
# (removed in v0.15.0 along with service_compute.R). Legacy A1/E1/E2/F1/F2/N3
# stubs that shadowed the real implementations in indicators-{air,energy,
# naturalness}.R have been removed. Only the l1_sylvosphere_ratio delegate
# remains since it has a unique name.
# ==============================================================================


#' @noRd
indicateur_l1_sylvosphere_ratio <- function(units, layers = NULL, ...) {
  # L2: Landscape fragmentation - delegates to indicateur_l1_sylvosphere
  indicateur_l1_sylvosphere(units, layers = layers, ...)
}

# indicateur_s3_population est defini dans indicators-social.R

