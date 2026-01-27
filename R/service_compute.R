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
      name = "NDVI",
      type = "raster",
      source = "sentinel2",
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

  # Check for existing progress (for resume)
  existing_progress <- get_computation_progress(project_id)
  already_computed <- existing_progress$computed_indicators %||% character(0)
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
  if (is.null(parcels) || nrow(parcels) == 0) {
    stop("No parcels found in project")
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
    "sentinel2" = download_sentinel2_ndvi(bbox, cache_file),
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


#' Placeholder download functions
#' These will be implemented with actual API calls
#'
#' @noRd
download_sentinel2_ndvi <- function(bbox, cache_file) {
  # TODO: Implement Sentinel-2 NDVI download via Copernicus API
  cli::cli_alert_info("Sentinel-2 NDVI download not yet implemented")
  NULL
}

download_ign_dem <- function(bbox, cache_file) {
  # TODO: Implement IGN BD ALTI download via WMS/WCS
  cli::cli_alert_info("IGN DEM download not yet implemented")
  NULL
}

download_clc <- function(bbox, cache_file) {
  # TODO: Implement Corine Land Cover download
  cli::cli_alert_info("Corine Land Cover download not yet implemented")
  NULL
}

download_inpn_wfs <- function(layer_name, bbox, cache_file) {
  # TODO: Implement INPN WFS download
  cli::cli_alert_info("INPN WFS download not yet implemented for {layer_name}")
  NULL
}

download_ign_bdtopo <- function(layer_name, bbox, cache_file) {
  # TODO: Implement IGN BD TOPO download
  cli::cli_alert_info("IGN BD TOPO download not yet implemented for {layer_name}")
  NULL
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
