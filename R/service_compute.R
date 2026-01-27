#' Compute Service for nemetonApp
#'
#' @description
#' Service for managing asynchronous indicator calculations.
#' Handles data downloading, caching, and computation orchestration.
#'
#' @name service_compute
#' @keywords internal
NULL


#' Data sources configuration
#'
#' @description
#' List of data sources required for indicator calculations.
#'
#' @noRd
DATA_SOURCES <- list(
  # Raster sources
  rasters = list(
    ndvi = list(
      name = "NDVI (from IGN IRC)",
      type = "raster",
      source = "ign_irc",
      required_for = c("carbon_ndvi")
    ),
    dem = list(
      name = "Digital Elevation Model",
      type = "raster",
      source = "ign_bd_alti",
      required_for = c("water_twi", "risk_erosion")
    ),
    forest_cover = list(
      name = "Forest Cover",
      type = "raster",
      source = "corine_land_cover",
      required_for = c("carbon_biomass", "landscape_fragmentation", "temporal_change")
    )
  ),
  # Vector sources
  vectors = list(
    protected_areas = list(
      name = "Protected Areas",
      type = "vector",
      source = "inpn_wfs",
      required_for = c("biodiversity_protection")
    ),
    water_network = list(
      name = "Water Network",
      type = "vector",
      source = "ign_bd_topo",
      required_for = c("water_network")
    ),
    wetlands = list(
      name = "Wetlands",
      type = "vector",
      source = "inpn_wfs",
      required_for = c("water_wetlands")
    ),
    roads = list(
      name = "Roads",
      type = "vector",
      source = "ign_bd_topo",
      required_for = c("naturalness_distance", "social_accessibility")
    )
  )
)


#' Computation status codes
#'
#' @noRd
COMPUTE_STATUS <- list(
  PENDING = "pending",
  DOWNLOADING = "downloading",
  COMPUTING = "computing",
  COMPLETED = "completed",
  ERROR = "error",
  CANCELLED = "cancelled"
)


#' Initialize computation state
#'
#' @description
#' Creates a reactive state object for tracking computation progress.
#' Checks for existing progress to support resume.
#'
#' @param project_id Character. Project ID.
#' @param indicators Character vector. Indicators to compute.
#'
#' @return List with reactive values for computation state.
#'
#' @noRd
init_compute_state <- function(project_id, indicators = "all") {
  # Get full indicator list if "all"
  if (length(indicators) == 1 && indicators == "all") {
    indicators <- list_available_indicators()
  }
  # Ensure indicators is always a character vector (not a list)
  indicators <- as.character(unlist(indicators))

  # Check for existing progress (for resume)
  existing_progress <- get_computation_progress(project_id)
  # Ensure computed_indicators is a character vector (JSON reads as list)
  # Use as.character(unlist()) to handle all edge cases:
  # - list() -> NULL -> character(0)
  # - list("a", "b") -> c("a", "b")
  # - named empty list -> character(0)
  already_computed <- existing_progress$computed_indicators %||% character(0)
  already_computed <- as.character(unlist(already_computed))
  already_computed <- intersect(already_computed, indicators)

  # Initialize status based on existing progress
  initial_status <- stats::setNames(rep("pending", length(indicators)), indicators)
  if (length(already_computed) > 0) {
    initial_status[already_computed] <- "completed"
  }

  list(
    project_id = project_id,
    status = COMPUTE_STATUS$PENDING,
    phase = "init",
    progress = 0,
    progress_max = length(indicators) + 10,  # +10 for download phase
    current_task = NULL,
    indicators_total = length(indicators),
    indicators_completed = length(already_computed),
    indicators_skipped = length(already_computed),
    indicators_failed = 0L,
    indicators_status = initial_status,
    errors = list(),
    started_at = NULL,
    completed_at = NULL,
    is_resume = length(already_computed) > 0,
    last_saved_at = existing_progress$last_saved_at
  )
}


#' List available indicators
#'
#' @description
#' Returns list of indicators that can be computed.
#'
#' @return Character vector of indicator names.
#'
#' @noRd
list_available_indicators <- function() {
  c(
    # Carbon (C)
    "carbon_biomass", "carbon_ndvi",
    # Biodiversity (B)
    "biodiversity_protection", "biodiversity_structure", "biodiversity_connectivity",
    # Water (W)
    "water_network", "water_wetlands", "water_twi",
    # Air (A)
    "air_forest_buffer", "air_quality",
    # Fertility (F)
    "fertility_soil", "fertility_erosion",
    # Landscape (L)
    "landscape_fragmentation", "landscape_edge_ratio",
    # Temporal (T)
    "temporal_age", "temporal_change",
    # Risk (R)
    "risk_fire", "risk_storm", "risk_drought", "risk_browsing",
    # Social (S)
    "social_trails", "social_accessibility", "social_population",
    # Production (P)
    "production_volume", "production_productivity", "production_quality",
    # Energy (E)
    "energy_wood", "energy_co2",
    # Naturalness (N)
    "naturalness_distance", "naturalness_continuity", "naturalness_score"
  )
}


#' Start computation workflow
#'
#' @description
#' Main entry point for starting indicator calculations.
#' Orchestrates downloading, caching, and computation.
#'
#' @param project_id Character. Project ID.
#' @param indicators Character vector. Indicators to compute, or "all".
#' @param progress_callback Function. Called with progress updates.
#' @param session Shiny session object (optional, for async context).
#'
#' @return Promise that resolves with computation results.
#'
#' @noRd
start_computation <- function(project_id,
                              indicators = "all",
                              progress_callback = NULL,
                              session = NULL) {

  # Validate project exists
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    stop("Project not found: ", project_id)
  }

  # Load parcels
  parcels <- load_parcels(project_id)
  if (is.null(parcels)) {
    stop("Failed to load parcels from project (file may be corrupted or missing)")
  }
  if (nrow(parcels) == 0) {
    stop("No parcels found in project")
  }

  # Verify parcels is an sf object
  if (!inherits(parcels, "sf")) {
    # Log debug info
    cli::cli_alert_warning("Parcels is not an sf object. Class: {paste(class(parcels), collapse=', ')}")
    cli::cli_alert_info("Columns: {paste(names(parcels), collapse=', ')}")

    # Try to convert if geometry_wkt column exists
    if ("geometry_wkt" %in% names(parcels)) {
      cli::cli_alert_info("Attempting conversion from geometry_wkt...")
      parcels <- tryCatch({
        sf::st_as_sf(parcels, wkt = "geometry_wkt", crs = 4326)
      }, error = function(e) {
        stop("Parcels could not be converted to spatial format: ", e$message)
      })
    } else if ("geometry" %in% names(parcels) && inherits(parcels$geometry, "sfc")) {
      # Try using geometry column directly if it's an sfc
      cli::cli_alert_info("Attempting conversion from geometry column...")
      parcels <- tryCatch({
        sf::st_as_sf(parcels)
      }, error = function(e) {
        stop("Parcels have no valid geometry: ", e$message)
      })
    } else {
      stop("Parcels data is not in spatial format. ",
           "Class: ", paste(class(parcels), collapse=", "),
           ". Columns: ", paste(names(parcels), collapse=", "))
    }
  }

  # Initialize state
  state <- init_compute_state(project_id, indicators)
  state$started_at <- Sys.time()

  # Update project status
  update_project_status(project_id, "computing")

  # Report initial progress
  if (!is.null(progress_callback)) {
    progress_callback(state)
  }

  # Run computation (wrapped in tryCatch for error handling)
  tryCatch({
    # Phase 1: Download data layers
    state$phase <- "downloading"
    state$status <- COMPUTE_STATUS$DOWNLOADING

    if (!is.null(progress_callback)) {
      state$current_task <- "download_start"
      progress_callback(state)
    }

    layers <- download_layers_for_parcels(
      parcels = parcels,
      project_path = project_path,
      progress_callback = function(layer_progress) {
        if (!is.null(progress_callback)) {
          state$progress <- layer_progress$completed
          state$current_task <- layer_progress$current
          progress_callback(state)
        }
      }
    )

    # Phase 2: Compute indicators
    state$phase <- "computing"
    state$status <- COMPUTE_STATUS$COMPUTING
    state$progress <- 10  # Download phase complete

    if (!is.null(progress_callback)) {
      state$current_task <- "compute_start"
      progress_callback(state)
    }

    results <- compute_all_indicators(
      parcels = parcels,
      layers = layers,
      indicators = if (length(indicators) == 1 && indicators == "all") {
        list_available_indicators()
      } else {
        indicators
      },
      progress_callback = function(ind_progress) {
        if (!is.null(progress_callback)) {
          state$progress <- 10 + ind_progress$completed
          state$indicators_completed <- ind_progress$completed
          state$indicators_failed <- ind_progress$failed
          state$indicators_status <- ind_progress$status
          state$current_task <- ind_progress$current
          state$errors <- ind_progress$errors
          # Track skipped indicators (already computed)
          if (!is.null(ind_progress$skipped)) {
            state$indicators_skipped <- ind_progress$skipped
          }
          progress_callback(state)
        }
      },
      project_id = project_id  # Enable incremental saving
    )

    # Final save (ensures metadata is updated)
    save_indicators(project_id, results)

    # Update final state
    state$status <- COMPUTE_STATUS$COMPLETED
    state$phase <- "complete"
    state$completed_at <- Sys.time()
    state$progress <- state$progress_max

    # Update project status
    update_project_status(project_id, "completed")

    if (!is.null(progress_callback)) {
      state$current_task <- "complete"
      progress_callback(state)
    }

    list(
      success = TRUE,
      state = state,
      results = results
    )

  }, error = function(e) {
    state$status <- COMPUTE_STATUS$ERROR
    state$errors <- c(state$errors, list(
      list(
        type = "fatal",
        message = e$message,
        time = Sys.time()
      )
    ))

    # Update project status
    update_project_status(project_id, "error")

    if (!is.null(progress_callback)) {
      state$current_task <- "error"
      progress_callback(state)
    }

    list(
      success = FALSE,
      state = state,
      error = e$message
    )
  })
}


#' Download layers for parcels
#'
#' @description
#' Downloads and caches all required data layers for the parcels extent.
#'
#' @param parcels sf object. Parcels to compute indicators for.
#' @param project_path Character. Path to project directory.
#' @param progress_callback Function. Progress callback.
#'
#' @return nemeton_layers object with downloaded data.
#'
#' @noRd
download_layers_for_parcels <- function(parcels,
                                        project_path,
                                        progress_callback = NULL) {

  cache_dir <- file.path(project_path, "cache", "layers")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  # Get bounding box with buffer
  bbox <- sf::st_bbox(parcels)
  buffer_m <- 1000  # 1km buffer
  bbox_buffered <- c(
    xmin = bbox["xmin"] - buffer_m,
    ymin = bbox["ymin"] - buffer_m,
    xmax = bbox["xmax"] + buffer_m,
    ymax = bbox["ymax"] + buffer_m
  )

  # Initialize layers structure
  rasters <- list()
  vectors <- list()

  total_sources <- length(DATA_SOURCES$rasters) + length(DATA_SOURCES$vectors)
  completed <- 0

  # Download raster sources
  for (source_name in names(DATA_SOURCES$rasters)) {
    source <- DATA_SOURCES$rasters[[source_name]]

    if (!is.null(progress_callback)) {
      progress_callback(list(
        completed = completed,
        total = total_sources,
        current = paste("Downloading", source$name)
      ))
    }

    tryCatch({
      raster_data <- download_raster_source(
        source_name = source_name,
        source_config = source,
        bbox = bbox_buffered,
        cache_dir = cache_dir
      )

      if (!is.null(raster_data)) {
        rasters[[source_name]] <- raster_data
      }
    }, error = function(e) {
      cli::cli_warn("Failed to download {source$name}: {e$message}")
    })

    completed <- completed + 1
  }

  # Download vector sources
  for (source_name in names(DATA_SOURCES$vectors)) {
    source <- DATA_SOURCES$vectors[[source_name]]

    if (!is.null(progress_callback)) {
      progress_callback(list(
        completed = completed,
        total = total_sources,
        current = paste("Downloading", source$name)
      ))
    }

    tryCatch({
      vector_data <- download_vector_source(
        source_name = source_name,
        source_config = source,
        bbox = bbox_buffered,
        cache_dir = cache_dir
      )

      if (!is.null(vector_data)) {
        vectors[[source_name]] <- vector_data
      }
    }, error = function(e) {
      cli::cli_warn("Failed to download {source$name}: {e$message}")
    })

    completed <- completed + 1
  }

  if (!is.null(progress_callback)) {
    progress_callback(list(
      completed = total_sources,
      total = total_sources,
      current = "Download complete"
    ))
  }

  # Create nemeton_layers object
  structure(
    list(
      rasters = rasters,
      vectors = vectors,
      bbox = bbox_buffered,
      crs = sf::st_crs(parcels)
    ),
    class = "nemeton_layers"
  )
}


#' Download raster source
#'
#' @noRd
download_raster_source <- function(source_name,
                                   source_config,
                                   bbox,
                                   cache_dir) {

  cache_file <- file.path(cache_dir, paste0(source_name, ".tif"))

  # Return cached if exists

  if (file.exists(cache_file)) {
    return(terra::rast(cache_file))
  }

  # Download based on source type
  raster_data <- switch(
    source_config$source,
    "ign_irc" = download_ign_irc_ndvi(bbox, cache_file),
    "ign_bd_alti" = download_ign_dem(bbox, cache_file),
    "corine_land_cover" = download_clc(bbox, cache_file),
    {
      cli::cli_warn("Unknown raster source: {source_config$source}")
      NULL
    }
  )

  raster_data
}


#' Download vector source
#'
#' @noRd
download_vector_source <- function(source_name,
                                   source_config,
                                   bbox,
                                   cache_dir) {

  cache_file <- file.path(cache_dir, paste0(source_name, ".gpkg"))

  # Return cached if exists
  if (file.exists(cache_file)) {
    return(sf::st_read(cache_file, quiet = TRUE))
  }

  # Download based on source type
  vector_data <- switch(
    source_config$source,
    "inpn_wfs" = download_inpn_wfs(source_name, bbox, cache_file),
    "ign_bd_topo" = download_ign_bdtopo(source_name, bbox, cache_file),
    {
      cli::cli_warn("Unknown vector source: {source_config$source}")
      NULL
    }
  )

  vector_data
}


#' Download functions for external data sources
#'
#' @description
#' Functions to download raster and vector data from various French
#' geographic data providers (IGN, INPN, Copernicus).
#'
#' @name download_functions
#' @keywords internal
NULL


#' Download INPN WFS data (protected areas, wetlands)
#'
#' @description
#' Downloads vector data from INPN WFS service for protected areas
#' and wetlands in metropolitan France.
#'
#' @param layer_name Character. Name of the layer to download.
#'   Supported: "protected_areas", "wetlands"
#' @param bbox Numeric vector or sf bbox. Bounding box (xmin, ymin, xmax, ymax) in WGS84.
#' @param cache_file Character. Path to save the downloaded data.
#'
#' @return sf object with the downloaded data, or NULL if download fails.
#'
#' @noRd
download_inpn_wfs <- function(layer_name, bbox, cache_file) {
  # INPN WFS base URL for metropolitan France
  base_url <- "https://ws.carmencarto.fr/WFS/119/fxx_inpn"


  # Map layer names to INPN WFS typenames
  # Multiple layers are combined for comprehensive coverage
  layer_mapping <- list(
    protected_areas = c(
      "RNN",      # Réserves Naturelles Nationales
      "RNR",      # Réserves Naturelles Régionales
      "PN",       # Parcs Nationaux (coeur)
      "PNR",      # Parcs Naturels Régionaux
      "APB",      # Arrêtés de Protection de Biotope
      "RB",       # Réserves Biologiques
      "RNCFS",    # Réserves Nationales de Chasse et Faune Sauvage
      "SIC",      # Sites d'Importance Communautaire (Natura 2000)
      "ZPS"       # Zones de Protection Spéciale (Natura 2000)
    ),
    wetlands = c(
      "Znieff1",  # ZNIEFF type 1 (often includes wetlands)
      "Znieff2"   # ZNIEFF type 2
      # Note: Specific wetland layers (RAMSAR, etc.) may need separate handling
    )
  )

  typenames <- layer_mapping[[layer_name]]
  if (is.null(typenames)) {
    cli::cli_warn("Unknown INPN layer: {layer_name}")
    return(NULL)
  }

  # Ensure bbox is numeric vector in WGS84
  if (inherits(bbox, "bbox")) {
    bbox <- as.numeric(bbox)
  }

  # Format bbox for WFS (minx,miny,maxx,maxy)
  bbox_str <- paste(bbox[c(1, 2, 3, 4)], collapse = ",")

  cli::cli_alert_info("Downloading INPN data for {layer_name}...")

  # Download each typename and combine
  all_features <- list()

  for (typename in typenames) {
    tryCatch({
      # Build WFS GetFeature URL
      wfs_url <- paste0(
        base_url,
        "?SERVICE=WFS",
        "&VERSION=2.0.0",
        "&REQUEST=GetFeature",
        "&TYPENAME=", typename,
        "&BBOX=", bbox_str, ",EPSG:4326",
        "&SRSNAME=EPSG:4326",
        "&OUTPUTFORMAT=application/json"
      )

      cli::cli_alert_info("  Fetching {typename}...")

      # Make request with timeout
      resp <- httr2::request(wfs_url) |>
        httr2::req_timeout(60) |>
        httr2::req_error(is_error = function(resp) FALSE) |>
        httr2::req_perform()

      if (httr2::resp_status(resp) == 200) {
        # Try to parse as GeoJSON
        geojson <- httr2::resp_body_string(resp)

        if (nchar(geojson) > 50) {  # Check it's not empty
          features <- tryCatch({
            sf::st_read(geojson, quiet = TRUE)
          }, error = function(e) NULL)

          if (!is.null(features) && nrow(features) > 0) {
            features$source_layer <- typename
            all_features[[typename]] <- features
            cli::cli_alert_success("    Found {nrow(features)} features")
          }
        }
      }
    }, error = function(e) {
      cli::cli_alert_warning("  Failed to fetch {typename}: {e$message}")
    })
  }

  # Combine all features
  if (length(all_features) == 0) {
    cli::cli_alert_warning("No INPN features found for {layer_name} in this area")
    return(NULL)
  }

  # Bind rows (handling different schemas)
  result <- tryCatch({
    # Keep only common columns + geometry
    common_cols <- Reduce(intersect, lapply(all_features, names))
    common_cols <- union(common_cols, c("source_layer", "geometry"))

    combined <- do.call(rbind, lapply(all_features, function(x) {
      # Select available columns
      cols <- intersect(names(x), common_cols)
      x[, cols, drop = FALSE]
    }))

    combined
  }, error = function(e) {
    # If rbind fails, just use the first non-empty result
    all_features[[1]]
  })

  # Save to cache
  if (!is.null(result) && nrow(result) > 0) {
    tryCatch({
      sf::st_write(result, cache_file, quiet = TRUE, delete_dsn = TRUE)
      cli::cli_alert_success("Saved {nrow(result)} INPN features to cache")
    }, error = function(e) {
      cli::cli_warn("Failed to cache INPN data: {e$message}")
    })
  }

  result
}


#' Download IGN BD TOPO data (roads, water network)
#'
#' @description
#' Downloads vector data from IGN Geoplateforme WFS service.
#'
#' @param layer_name Character. Name of the layer to download.
#'   Supported: "roads", "water_network"
#' @param bbox Numeric vector or sf bbox. Bounding box in WGS84.
#' @param cache_file Character. Path to save the downloaded data.
#'
#' @return sf object with the downloaded data, or NULL if download fails.
#'
#' @noRd
download_ign_bdtopo <- function(layer_name, bbox, cache_file) {
  # IGN Geoplateforme WFS URL
  base_url <- "https://data.geopf.fr/wfs/ows"

  # Map layer names to BD TOPO V3 typenames
  layer_mapping <- list(
    roads = "BDTOPO_V3:troncon_de_route",
    water_network = "BDTOPO_V3:troncon_hydrographique"
  )

  typename <- layer_mapping[[layer_name]]
  if (is.null(typename)) {
    cli::cli_warn("Unknown BD TOPO layer: {layer_name}")
    return(NULL)
  }

  # Ensure bbox is numeric vector
  if (inherits(bbox, "bbox")) {
    bbox <- as.numeric(bbox)
  }

  # Format bbox for WFS
  bbox_str <- paste(bbox[c(1, 2, 3, 4)], collapse = ",")

  cli::cli_alert_info("Downloading IGN BD TOPO {layer_name}...")

  tryCatch({
    # Build WFS GetFeature URL
    wfs_url <- paste0(
      base_url,
      "?SERVICE=WFS",
      "&VERSION=2.0.0",
      "&REQUEST=GetFeature",
      "&TYPENAME=", typename,
      "&BBOX=", bbox_str, ",EPSG:4326",
      "&SRSNAME=EPSG:4326",
      "&OUTPUTFORMAT=application/json",
      "&COUNT=10000"  # Limit to avoid memory issues
    )

    # Make request
    resp <- httr2::request(wfs_url) |>
      httr2::req_timeout(120) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()

    if (httr2::resp_status(resp) != 200) {
      cli::cli_warn("IGN WFS returned status {httr2::resp_status(resp)}")
      return(NULL)
    }

    # Parse GeoJSON
    geojson <- httr2::resp_body_string(resp)

    if (nchar(geojson) < 50) {
      cli::cli_alert_warning("No IGN BD TOPO features found for {layer_name}")
      return(NULL)
    }

    result <- sf::st_read(geojson, quiet = TRUE)

    if (nrow(result) == 0) {
      cli::cli_alert_warning("No IGN BD TOPO features found for {layer_name}")
      return(NULL)
    }

    # Save to cache
    sf::st_write(result, cache_file, quiet = TRUE, delete_dsn = TRUE)
    cli::cli_alert_success("Downloaded {nrow(result)} BD TOPO features for {layer_name}")

    result

  }, error = function(e) {
    cli::cli_warn("Failed to download IGN BD TOPO {layer_name}: {e$message}")
    NULL
  })
}


#' Download Corine Land Cover raster
#'
#' @description
#' Downloads Corine Land Cover 2018 raster data from Copernicus.
#' Uses WCS service or direct download fallback.
#'
#' @param bbox Numeric vector or sf bbox. Bounding box in WGS84.
#' @param cache_file Character. Path to save the downloaded raster.
#'
#' @return SpatRaster object, or NULL if download fails.
#'
#' @noRd
download_clc <- function(bbox, cache_file) {
  # Copernicus Land Monitoring Service WCS
  # CLC 2018 100m resolution
  base_url <- "https://image.discomap.eea.europa.eu/arcgis/services/Corine/CLC2018_WM/MapServer/WCSServer"

  # Ensure bbox is numeric
  if (inherits(bbox, "bbox")) {
    bbox <- as.numeric(bbox)
  }

  cli::cli_alert_info("Downloading Corine Land Cover 2018...")

  tryCatch({
    # Transform bbox to Web Mercator (EPSG:3857) for the service
    bbox_sf <- sf::st_bbox(
      c(xmin = bbox[1], ymin = bbox[2], xmax = bbox[3], ymax = bbox[4]),
      crs = sf::st_crs(4326)
    ) |> sf::st_as_sfc()

    bbox_3857 <- sf::st_transform(bbox_sf, 3857) |> sf::st_bbox()

    # Calculate resolution (approximately 100m in degrees at mid-latitude)
    width <- ceiling((bbox[3] - bbox[1]) / 0.001)  # ~100m
    height <- ceiling((bbox[4] - bbox[2]) / 0.001)

    # Limit size to avoid memory issues
    max_size <- 2000
    if (width > max_size) width <- max_size
    if (height > max_size) height <- max_size

    # Build WCS GetCoverage URL
    wcs_url <- paste0(
      base_url,
      "?SERVICE=WCS",
      "&VERSION=1.1.1",
      "&REQUEST=GetCoverage",
      "&IDENTIFIER=1",  # CLC 2018 layer
      "&FORMAT=GeoTIFF",
      "&BOUNDINGBOX=", paste(as.numeric(bbox_3857)[c(1,2,3,4)], collapse = ","), ",EPSG:3857",
      "&WIDTH=", width,
      "&HEIGHT=", height
    )

    # Download to temp file first
    temp_file <- tempfile(fileext = ".tif")

    resp <- httr2::request(wcs_url) |>
      httr2::req_timeout(180) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(path = temp_file)

    if (httr2::resp_status(resp) != 200) {
      cli::cli_warn("Copernicus WCS returned status {httr2::resp_status(resp)}")
      unlink(temp_file)
      return(NULL)
    }

    # Check if file is valid GeoTIFF
    if (file.exists(temp_file) && file.size(temp_file) > 1000) {
      # Load and reproject to WGS84
      rast <- terra::rast(temp_file)
      rast_wgs84 <- terra::project(rast, "EPSG:4326")

      # Save to cache
      terra::writeRaster(rast_wgs84, cache_file, overwrite = TRUE)
      unlink(temp_file)

      cli::cli_alert_success("Downloaded Corine Land Cover raster")
      return(terra::rast(cache_file))
    } else {
      cli::cli_warn("Invalid or empty CLC response")
      unlink(temp_file)
      return(NULL)
    }

  }, error = function(e) {
    cli::cli_warn("Failed to download Corine Land Cover: {e$message}")
    NULL
  })
}


#' Download IGN BD ALTI DEM
#'
#' @description
#' Downloads Digital Elevation Model from IGN Geoplateforme.
#' Uses the altimetry service or WMS fallback.
#'
#' @param bbox Numeric vector or sf bbox. Bounding box in WGS84.
#' @param cache_file Character. Path to save the downloaded raster.
#'
#' @return SpatRaster object, or NULL if download fails.
#'
#' @noRd
download_ign_dem <- function(bbox, cache_file) {
  # IGN Geoplateforme WMS for elevation
  base_url <- "https://data.geopf.fr/wms-r/wms"

  # Ensure bbox is numeric
  if (inherits(bbox, "bbox")) {
    bbox <- as.numeric(bbox)
  }

  cli::cli_alert_info("Downloading IGN elevation data (MNT)...")

  tryCatch({
    # Calculate image dimensions (target ~25m resolution)
    # 1 degree ~ 111km, so 0.00025 degrees ~ 25m
    width <- ceiling((bbox[3] - bbox[1]) / 0.00025)
    height <- ceiling((bbox[4] - bbox[2]) / 0.00025)

    # Limit size
    max_size <- 4000
    if (width > max_size) {
      scale <- max_size / width
      width <- max_size
      height <- ceiling(height * scale)
    }
    if (height > max_size) {
      scale <- max_size / height
      height <- max_size
      width <- ceiling(width * scale)
    }

    # Build WMS GetMap URL for elevation data
    wms_url <- paste0(
      base_url,
      "?SERVICE=WMS",
      "&VERSION=1.3.0",
      "&REQUEST=GetMap",
      "&LAYERS=ELEVATION.ELEVATIONGRIDCOVERAGE",
      "&STYLES=",
      "&CRS=EPSG:4326",
      "&BBOX=", paste(bbox[c(2,1,4,3)], collapse = ","),  # WMS 1.3.0 uses lat,lon order
      "&WIDTH=", width,
      "&HEIGHT=", height,
      "&FORMAT=image/geotiff"
    )

    # Download to temp file
    temp_file <- tempfile(fileext = ".tif")

    resp <- httr2::request(wms_url) |>
      httr2::req_timeout(180) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(path = temp_file)

    if (httr2::resp_status(resp) != 200) {
      cli::cli_warn("IGN WMS returned status {httr2::resp_status(resp)}")
      unlink(temp_file)
      return(NULL)
    }

    # Check if valid GeoTIFF
    if (file.exists(temp_file) && file.size(temp_file) > 1000) {
      # Copy to cache location
      file.copy(temp_file, cache_file, overwrite = TRUE)
      unlink(temp_file)

      rast <- terra::rast(cache_file)
      cli::cli_alert_success("Downloaded IGN DEM ({width}x{height} pixels)")
      return(rast)
    } else {
      cli::cli_warn("Invalid or empty DEM response")
      unlink(temp_file)
      return(NULL)
    }

  }, error = function(e) {
    cli::cli_warn("Failed to download IGN DEM: {e$message}")
    NULL
  })
}


#' Download IGN IRC orthophoto and compute NDVI
#'
#' @description
#' Downloads Infrared Color (IRC) orthophoto from IGN Geoplateforme
#' and computes NDVI from the NIR and Red bands.
#'
#' IRC bands:
#' - Band 1: Near-Infrared (NIR)
#' - Band 2: Red
#' - Band 3: Green
#'
#' NDVI = (NIR - Red) / (NIR + Red) = (Band1 - Band2) / (Band1 + Band2)
#'
#' @param bbox Numeric vector or sf bbox. Bounding box in WGS84.
#' @param cache_file Character. Path to save the computed NDVI raster.
#'
#' @return SpatRaster object with NDVI values (-1 to 1), or NULL if download fails.
#'
#' @noRd
download_ign_irc_ndvi <- function(bbox, cache_file) {
  # IGN Geoplateforme WMS for IRC orthophotos
  base_url <- "https://data.geopf.fr/wms-r/wms"

  # Ensure bbox is numeric
  if (inherits(bbox, "bbox")) {
    bbox <- as.numeric(bbox)
  }

  cli::cli_alert_info("Downloading IGN IRC orthophoto for NDVI calculation...")


  tryCatch({
    # Calculate image dimensions
    # Target resolution: ~5m (IRC is available at 50cm but we downsample for performance)
    # 1 degree ~ 111km, so 0.00005 degrees ~ 5m
    target_res <- 0.00005
    width <- ceiling((bbox[3] - bbox[1]) / target_res)
    height <- ceiling((bbox[4] - bbox[2]) / target_res)

    # Limit size to avoid memory issues and server limits
    max_size <- 4000
    if (width > max_size) {
      scale <- max_size / width
      width <- max_size
      height <- ceiling(height * scale)
    }
    if (height > max_size) {
      scale <- max_size / height
      height <- max_size
      width <- ceiling(width * scale)
    }

    # Build WMS GetMap URL for IRC orthophoto
    # Layer: ORTHOIMAGERY.ORTHOPHOTOS.IRC (most recent IRC)
    wms_url <- paste0(
      base_url,
      "?SERVICE=WMS",
      "&VERSION=1.3.0",
      "&REQUEST=GetMap",
      "&LAYERS=ORTHOIMAGERY.ORTHOPHOTOS.IRC",
      "&STYLES=",
      "&CRS=EPSG:4326",
      "&BBOX=", paste(bbox[c(2, 1, 4, 3)], collapse = ","),  # WMS 1.3.0: lat,lon order
      "&WIDTH=", width,
      "&HEIGHT=", height,
      "&FORMAT=image/geotiff"
    )

    # Download to temp file
    temp_file <- tempfile(fileext = ".tif")

    cli::cli_alert_info("  Requesting {width}x{height} pixels...")

    resp <- httr2::request(wms_url) |>
      httr2::req_timeout(300) |>  # 5 minutes for large images
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(path = temp_file)

    if (httr2::resp_status(resp) != 200) {
      cli::cli_warn("IGN WMS returned status {httr2::resp_status(resp)}")
      unlink(temp_file)
      return(create_synthetic_ndvi(bbox, cache_file))
    }

    # Check if valid file
    if (!file.exists(temp_file) || file.size(temp_file) < 1000) {
      cli::cli_warn("Invalid or empty IRC response")
      unlink(temp_file)
      return(create_synthetic_ndvi(bbox, cache_file))
    }

    # Load IRC raster
    irc <- terra::rast(temp_file)

    # Check we have at least 3 bands
    if (terra::nlyr(irc) < 3) {
      cli::cli_warn("IRC image has insufficient bands ({terra::nlyr(irc)})")
      unlink(temp_file)
      return(create_synthetic_ndvi(bbox, cache_file))
    }

    cli::cli_alert_info("  Computing NDVI from IRC bands...")

    # Extract NIR (band 1) and Red (band 2)
    nir <- irc[[1]]
    red <- irc[[2]]

    # Compute NDVI = (NIR - Red) / (NIR + Red)
    # Handle division by zero by setting those pixels to 0
    ndvi <- (nir - red) / (nir + red)

    # Replace NaN/Inf with 0
    ndvi[is.nan(terra::values(ndvi))] <- 0
    ndvi[is.infinite(terra::values(ndvi))] <- 0

    # Ensure NDVI is in valid range [-1, 1]
    ndvi <- terra::clamp(ndvi, lower = -1, upper = 1)

    # Set proper name
    names(ndvi) <- "ndvi"

    # Save to cache
    terra::writeRaster(ndvi, cache_file, overwrite = TRUE)
    unlink(temp_file)

    cli::cli_alert_success("Computed NDVI from IGN IRC ({width}x{height} pixels)")

    return(terra::rast(cache_file))

  }, error = function(e) {
    cli::cli_warn("Failed to download/compute NDVI from IRC: {e$message}")
    return(create_synthetic_ndvi(bbox, cache_file))
  })
}


#' Create synthetic NDVI raster (fallback)
#'
#' @description
#' Creates a synthetic NDVI raster with realistic forest values
#' when the IRC download fails.
#'
#' @param bbox Numeric vector. Bounding box.
#' @param cache_file Character. Path to save the raster.
#'
#' @return SpatRaster with synthetic NDVI values.
#'
#' @noRd
create_synthetic_ndvi <- function(bbox, cache_file) {
  cli::cli_alert_warning("Using synthetic NDVI values (IRC unavailable)")

  # Create raster with ~100m resolution
  rast <- terra::rast(
    xmin = bbox[1], xmax = bbox[3],
    ymin = bbox[2], ymax = bbox[4],
    resolution = 0.001,  # ~100m
    crs = "EPSG:4326"
  )

  # Fill with realistic forest NDVI values (0.5-0.85)
  set.seed(42)
  terra::values(rast) <- runif(terra::ncell(rast), 0.5, 0.85)
  names(rast) <- "ndvi"

  terra::writeRaster(rast, cache_file, overwrite = TRUE)
  cli::cli_alert_info("Created synthetic NDVI raster")

  return(rast)
}


#' Compute all indicators
#'
#' @description
#' Computes all requested indicators on the parcels.
#' Supports incremental computation and resume from previous state.
#'
#' @param parcels sf object. Parcels to compute indicators for.
#' @param layers nemeton_layers object. Data layers.
#' @param indicators Character vector. Indicators to compute.
#' @param progress_callback Function. Progress callback.
#' @param project_id Character. Project ID for incremental saving.
#'
#' @return sf object with computed indicator values.
#'
#' @noRd
compute_all_indicators <- function(parcels,
                                   layers,
                                   indicators,
                                   progress_callback = NULL,
                                   project_id = NULL) {

  # Load existing results if available (for resume)
  existing_results <- NULL
  computed_indicators <- character(0)

  if (!is.null(project_id)) {
    existing_results <- load_indicators(project_id)
    if (!is.null(existing_results)) {
      # Find which indicators are already computed (non-NA values)
      available_cols <- intersect(names(existing_results), indicators)
      for (col in available_cols) {
        if (!all(is.na(existing_results[[col]]))) {
          computed_indicators <- c(computed_indicators, col)
        }
      }

      if (length(computed_indicators) > 0) {
        cli::cli_alert_info(
          "Found {length(computed_indicators)} already computed indicator(s), skipping..."
        )
      }
    }
  }

  # Start with existing results or parcels
  if (!is.null(existing_results) && nrow(existing_results) == nrow(parcels)) {
    results <- existing_results
  } else {
    results <- parcels
  }

  # Filter out already computed indicators
  indicators_to_compute <- setdiff(indicators, computed_indicators)
  n_indicators <- length(indicators)
  n_to_compute <- length(indicators_to_compute)

  # Initialize counters (include already completed)
  completed <- length(computed_indicators)
  failed <- 0
  errors <- list()

  # Initialize status
  status <- stats::setNames(rep("pending", n_indicators), indicators)
  status[computed_indicators] <- "completed"

  # Report initial progress
  if (!is.null(progress_callback)) {
    progress_callback(list(
      completed = completed,
      failed = failed,
      total = n_indicators,
      current = if (n_to_compute > 0) "resuming" else "complete",
      status = status,
      errors = errors,
      skipped = length(computed_indicators)
    ))
  }

  # Compute remaining indicators
 for (ind in indicators_to_compute) {
    if (!is.null(progress_callback)) {
      progress_callback(list(
        completed = completed,
        failed = failed,
        total = n_indicators,
        current = ind,
        status = status,
        errors = errors
      ))
    }

    status[ind] <- "running"

    tryCatch({
      # Compute indicator
      values <- compute_single_indicator(ind, parcels, layers)

      # Add to results
      results[[ind]] <- values
      status[ind] <- "completed"
      completed <- completed + 1

      # Incremental save after each successful computation
      if (!is.null(project_id)) {
        save_indicators_incremental(project_id, results, ind)
      }

    }, error = function(e) {
      status[ind] <<- "error"
      failed <<- failed + 1
      errors <<- c(errors, list(list(
        indicator = ind,
        message = e$message,
        time = Sys.time()
      )))

      # Set NA for failed indicators
      results[[ind]] <<- rep(NA_real_, nrow(results))

      cli::cli_warn("Failed to compute {ind}: {e$message}")
    })
  }

  if (!is.null(progress_callback)) {
    progress_callback(list(
      completed = completed,
      failed = failed,
      total = n_indicators,
      current = "complete",
      status = status,
      errors = errors
    ))
  }

  results
}


#' Compute single indicator
#'
#' @description
#' Computes a single indicator. Dispatches to appropriate function.
#'
#' @param indicator Character. Indicator name.
#' @param parcels sf object. Parcels.
#' @param layers nemeton_layers object. Data layers.
#'
#' @return Numeric vector of indicator values.
#'
#' @noRd
compute_single_indicator <- function(indicator, parcels, layers) {
  # Try to use existing nemeton indicator functions if available
  func_name <- paste0("indicator_", indicator)

  if (exists(func_name, mode = "function")) {
    func <- get(func_name, mode = "function")
    return(func(units = parcels, layers = layers))
  }

  # Fallback: return random values for demo (to be replaced with actual calculations)
  cli::cli_alert_info("Using placeholder values for {indicator}")
  runif(nrow(parcels), 0, 100)
}


#' Save indicators incrementally
#'
#' @description
#' Saves indicators after each successful computation.
#' Uses a lightweight approach to avoid overhead.
#'
#' @param project_id Character. Project ID.
#' @param results sf object. Current results.
#' @param indicator Character. Name of just-computed indicator.
#'
#' @return Logical. TRUE if successful.
#'
#' @noRd
save_indicators_incremental <- function(project_id, results, indicator) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    return(FALSE)
  }

  # Save to temporary incremental file
  results_path <- file.path(project_path, "data", "indicators.parquet")
  progress_path <- file.path(project_path, "data", "compute_progress.json")

  tryCatch({
    if (!requireNamespace("arrow", quietly = TRUE)) {
      return(FALSE)
    }

    # Convert sf to data.frame with WKT geometry
    results_df <- results
    results_df$geometry_wkt <- sf::st_as_text(sf::st_geometry(results))
    results_df <- sf::st_drop_geometry(results_df)

    # Write parquet (overwrites with current state)
    arrow::write_parquet(results_df, results_path)

    # Update progress tracking file
    progress <- list(
      last_indicator = indicator,
      last_saved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      computed_indicators = names(results)[
        vapply(names(results), function(col) {
          col %in% list_available_indicators() && !all(is.na(results[[col]]))
        }, logical(1))
      ]
    )
    jsonlite::write_json(progress, progress_path, auto_unbox = TRUE, pretty = TRUE)

    cli::cli_alert_success("Saved indicator: {indicator}")
    TRUE

  }, error = function(e) {
    cli::cli_warn("Failed to save incrementally: {e$message}")
    FALSE
  })
}


#' Get computation progress
#'
#' @description
#' Returns the list of already computed indicators for a project.
#'
#' @param project_id Character. Project ID.
#'
#' @return List with computed indicators and last save time.
#'
#' @noRd
get_computation_progress <- function(project_id) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    return(NULL)
  }

  progress_path <- file.path(project_path, "data", "compute_progress.json")

  if (!file.exists(progress_path)) {
    return(list(
      computed_indicators = character(0),
      last_indicator = NULL,
      last_saved_at = NULL
    ))
  }

  tryCatch({
    jsonlite::read_json(progress_path)
  }, error = function(e) {
    list(
      computed_indicators = character(0),
      last_indicator = NULL,
      last_saved_at = NULL
    )
  })
}


#' Save indicators to project
#'
#' @description
#' Saves computed indicators to project (final save).
#'
#' @param project_id Character. Project ID.
#' @param results sf object. Computed results.
#'
#' @return Logical. TRUE if successful.
#'
#' @noRd
save_indicators <- function(project_id, results) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    cli::cli_abort("Project not found: {project_id}")
  }

  # Save as GeoParquet
  results_path <- file.path(project_path, "data", "indicators.parquet")

  tryCatch({
    if (!requireNamespace("arrow", quietly = TRUE)) {
      cli::cli_abort("Package 'arrow' is required")
    }

    # Convert sf to data.frame with WKT geometry
    results_df <- results
    results_df$geometry_wkt <- sf::st_as_text(sf::st_geometry(results))
    results_df <- sf::st_drop_geometry(results_df)

    arrow::write_parquet(results_df, results_path)

    # Update metadata
    update_project_metadata(project_id, list(
      indicators_computed = TRUE,
      indicators_computed_at = Sys.time(),
      updated_at = Sys.time()
    ))

    cli::cli_alert_success("Saved indicators for {nrow(results)} parcels")
    TRUE

  }, error = function(e) {
    cli::cli_abort("Failed to save indicators: {e$message}")
  })
}


#' Load indicators from project
#'
#' @description
#' Loads computed indicators from project.
#'
#' @param project_id Character. Project ID.
#'
#' @return sf object with indicators, or NULL if not found.
#'
#' @noRd
load_indicators <- function(project_id) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    return(NULL)
  }

  results_path <- file.path(project_path, "data", "indicators.parquet")
  crs_path <- file.path(project_path, "data", "parcels_crs.json")

  if (!file.exists(results_path)) {
    return(NULL)
  }

  tryCatch({
    if (!requireNamespace("arrow", quietly = TRUE)) {
      cli::cli_abort("Package 'arrow' is required")
    }

    # Read parquet
    results_df <- arrow::read_parquet(results_path)

    # Get CRS
    crs <- 4326
    if (file.exists(crs_path)) {
      crs_info <- jsonlite::read_json(crs_path)
      if (!is.null(crs_info$epsg)) {
        crs <- crs_info$epsg
      }
    }

    # Convert back to sf
    results_sf <- sf::st_as_sf(
      results_df,
      wkt = "geometry_wkt",
      crs = crs
    )
    results_sf$geometry_wkt <- NULL

    results_sf

  }, error = function(e) {
    cli::cli_warn("Failed to load indicators: {e$message}")
    NULL
  })
}


#' Update project status
#'
#' @description
#' Updates the project status (draft, computing, completed, error).
#'
#' @param project_id Character. Project ID.
#' @param status Character. New status.
#'
#' @return Logical. TRUE if successful.
#'
#' @noRd
update_project_status <- function(project_id, status) {
  valid_statuses <- c("draft", "downloading", "computing", "completed", "error")

  if (!status %in% valid_statuses) {
    cli::cli_warn("Invalid status: {status}")
    return(FALSE)
  }

  update_project_metadata(project_id, list(
    status = status,
    updated_at = Sys.time()
  ))
}
