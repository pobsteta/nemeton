#' Project Service for nemetonApp
#'
#' @description
#' Service for managing nemeton projects - creation, saving, loading.
#' Projects are stored in GeoParquet format for efficient spatial data handling.
#'
#' @name service_project
#' @keywords internal
NULL


#' Get projects root directory
#'
#' @description
#' Returns the root directory for nemeton projects.
#' Uses the project_dir from app options if available.
#'
#' @return Character. Path to projects root directory.
#'
#' @noRd
get_projects_root <- function() {
  opts <- get_app_options()

  if (!is.null(opts$project_dir)) {
    root <- opts$project_dir
  } else {
    root <- file.path(
      Sys.getenv("HOME", rappdirs::user_data_dir()),
      "nemeton_projects"
    )
  }

  # Create if doesn't exist

if (!dir.exists(root)) {
    dir.create(root, recursive = TRUE)
  }

  normalizePath(root, mustWork = FALSE)
}


#' Create a new project
#'
#' @description
#' Creates a new project directory with metadata and initial structure.
#'
#' @param name Character. Project name (required, max 100 chars).
#' @param description Character. Project description (optional, max 500 chars).
#' @param owner Character. Project owner (optional, max 100 chars).
#' @param parcels sf object. Selected parcels (optional, can be added later).
#'
#' @return List with project info (id, path, metadata).
#'
#' @noRd
create_project <- function(name, description = "", owner = "", parcels = NULL) {
  # Validate name
  if (missing(name) || is.null(name) || nchar(trimws(name)) == 0) {
    cli::cli_abort("Project name is required")
  }

  name <- trimws(name)
  if (nchar(name) > 100) {
    cli::cli_abort("Project name must be 100 characters or less")
  }

  # Validate description
  if (nchar(description) > 500) {
    cli::cli_abort("Description must be 500 characters or less")
  }

  # Validate owner
  if (nchar(owner) > 100) {
    cli::cli_abort("Owner must be 100 characters or less")
  }

  # Generate project ID (timestamp + random)
  project_id <- sprintf(
    "%s_%s",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    paste0(sample(letters, 4), collapse = "")
  )

  # Create project directory
  root <- get_projects_root()
  project_path <- file.path(root, project_id)
  dir.create(project_path, recursive = TRUE)

  # Create subdirectories
  dir.create(file.path(project_path, "data"), showWarnings = FALSE)
  dir.create(file.path(project_path, "cache"), showWarnings = FALSE)
  dir.create(file.path(project_path, "exports"), showWarnings = FALSE)

  # Create metadata
  metadata <- list(
    id = project_id,
    name = name,
    description = description,
    owner = owner,
    created_at = Sys.time(),
    updated_at = Sys.time(),
    status = "draft",
    version = "0.7.0",
    parcels_count = 0L,
    indicators_computed = FALSE
 )

  # Save metadata
  metadata_path <- file.path(project_path, "metadata.json")
  jsonlite::write_json(
    metadata,
    metadata_path,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  # Save parcels if provided
  if (!is.null(parcels) && inherits(parcels, "sf") && nrow(parcels) > 0) {
    save_parcels(project_id, parcels)
    metadata$parcels_count <- nrow(parcels)
    jsonlite::write_json(metadata, metadata_path, auto_unbox = TRUE, pretty = TRUE)
  }

  cli::cli_alert_success("Project created: {.val {name}}")

  list(
    id = project_id,
    path = project_path,
    metadata = metadata
  )
}


#' Save parcels to project
#'
#' @description
#' Saves selected parcels to project in GeoParquet format.
#' Uses sfarrow for proper GeoParquet format compatible with QGIS/GIS tools.
#'
#' @param project_id Character. Project ID.
#' @param parcels sf object. Parcels to save.
#'
#' @return Logical. TRUE if successful.
#'
#' @noRd
save_parcels <- function(project_id, parcels) {
  if (!inherits(parcels, "sf")) {
    cli::cli_abort("parcels must be an sf object")
  }

  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    cli::cli_abort("Project not found: {project_id}")
  }

  # Save as GeoParquet
  parcels_path <- file.path(project_path, "data", "parcels.parquet")

  tryCatch({
    # Store CRS info for reference
    crs_epsg <- sf::st_crs(parcels)$epsg
    if (is.null(crs_epsg) || is.na(crs_epsg)) {
      crs_epsg <- 4326
    }

    # Try to use sfarrow for proper GeoParquet (QGIS compatible)
    if (requireNamespace("sfarrow", quietly = TRUE)) {
      cli::cli_alert_info("Saving {nrow(parcels)} parcels as GeoParquet (sfarrow)")

      # Ensure valid CRS before saving
      if (is.na(sf::st_crs(parcels))) {
        parcels <- sf::st_set_crs(parcels, 4326)
      }

      sfarrow::st_write_parquet(parcels, parcels_path)

    } else if (requireNamespace("arrow", quietly = TRUE)) {
      # Fallback to arrow with WKT geometry (less compatible but works)
      cli::cli_alert_warning("sfarrow not available, saving with WKT geometry (may not open in QGIS)")

      parcels_df <- parcels
      parcels_df$geometry_wkt <- sf::st_as_text(sf::st_geometry(parcels))
      parcels_df <- sf::st_drop_geometry(parcels_df)

      arrow::write_parquet(parcels_df, parcels_path)
    } else {
      cli::cli_abort("Package 'sfarrow' or 'arrow' is required for GeoParquet support")
    }

    # Save CRS info as backup
    crs_path <- file.path(project_path, "data", "parcels_crs.json")
    jsonlite::write_json(
      list(
        epsg = crs_epsg,
        wkt = sf::st_crs(parcels)$wkt
      ),
      crs_path,
      auto_unbox = TRUE
    )

    # Update metadata
    update_project_metadata(project_id, list(
      parcels_count = nrow(parcels),
      updated_at = Sys.time()
    ))

    cli::cli_alert_success("Saved {nrow(parcels)} parcels")
    TRUE

  }, error = function(e) {
    cli::cli_abort("Failed to save parcels: {e$message}")
  })
}


#' Load parcels from project
#'
#' @description
#' Loads parcels from project GeoParquet file.
#' Supports both proper GeoParquet (sfarrow) and legacy WKT format.
#'
#' @param project_id Character. Project ID.
#'
#' @return sf object with parcels, or NULL if not found.
#'
#' @noRd
load_parcels <- function(project_id) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    return(NULL)
  }

  parcels_path <- file.path(project_path, "data", "parcels.parquet")
  crs_path <- file.path(project_path, "data", "parcels_crs.json")

  if (!file.exists(parcels_path)) {
    return(NULL)
  }

  tryCatch({
    parcels_sf <- NULL

    # Try sfarrow first for proper GeoParquet format
    if (requireNamespace("sfarrow", quietly = TRUE)) {
      parcels_sf <- tryCatch({
        sf_obj <- sfarrow::st_read_parquet(parcels_path)
        if (inherits(sf_obj, "sf") && !is.null(sf::st_geometry(sf_obj))) {
          cli::cli_alert_info("Loaded {nrow(sf_obj)} parcels from GeoParquet (sfarrow)")
          sf_obj
        } else {
          NULL
        }
      }, error = function(e) {
        cli::cli_alert_info("GeoParquet read failed, trying legacy format: {e$message}")
        NULL
      })
    }

    # Fallback to legacy WKT format if sfarrow failed or not available
    if (is.null(parcels_sf)) {
      if (!requireNamespace("arrow", quietly = TRUE)) {
        cli::cli_abort("Package 'arrow' is required")
      }

      # Read parquet (returns a tibble)
      parcels_tbl <- arrow::read_parquet(parcels_path)

      cli::cli_alert_info("Loaded parquet with {nrow(parcels_tbl)} rows, columns: {paste(names(parcels_tbl), collapse=', ')}")

      # IMPORTANT: Convert arrow tibble to plain data.frame for reliable sf conversion
      parcels_df <- as.data.frame(parcels_tbl)

      # Check if geometry_wkt column exists
      if (!"geometry_wkt" %in% names(parcels_df)) {
        cli::cli_warn("Parcels file missing geometry_wkt column")
        # Try to find geometry column
        geom_cols <- grep("geom|geometry", names(parcels_df), value = TRUE, ignore.case = TRUE)
        if (length(geom_cols) > 0) {
          cli::cli_alert_info("Found potential geometry column: {geom_cols[1]}")
          geom_col <- geom_cols[1]
          if (inherits(parcels_df[[geom_col]], "character")) {
            cli::cli_alert_info("Attempting to convert WKT from column: {geom_col}")
            parcels_df$geometry_wkt <- parcels_df[[geom_col]]
          }
        }

        if (!"geometry_wkt" %in% names(parcels_df)) {
          cli::cli_warn("Could not find valid geometry column")
          return(NULL)
        }
      }

      # Verify geometry_wkt contains valid data
      if (all(is.na(parcels_df$geometry_wkt)) || all(parcels_df$geometry_wkt == "")) {
        cli::cli_warn("geometry_wkt column is empty or contains only NA values")
        return(NULL)
      }

      # Get CRS
      crs <- 4326
      if (file.exists(crs_path)) {
        crs_info <- jsonlite::read_json(crs_path)
        if (!is.null(crs_info$epsg)) {
          crs <- crs_info$epsg
        }
      }

      # Convert back to sf
      parcels_sf <- sf::st_as_sf(
        parcels_df,
        wkt = "geometry_wkt",
        crs = crs
      )
    }

    # Verify conversion succeeded
    if (!inherits(parcels_sf, "sf")) {
      cli::cli_warn("Failed to convert parcels to sf object (class: {paste(class(parcels_sf), collapse=', ')})")
      return(NULL)
    }

    # Verify geometry exists
    geom <- sf::st_geometry(parcels_sf)
    if (is.null(geom) || length(geom) == 0) {
      cli::cli_warn("sf object has no valid geometry")
      return(NULL)
    }

    # Remove WKT column if it exists (geometry is now in the sf geometry column)
    if ("geometry_wkt" %in% names(parcels_sf)) {
      parcels_sf$geometry_wkt <- NULL
    }

    # Get CRS for logging
    crs_info <- sf::st_crs(parcels_sf)$epsg
    if (is.null(crs_info) || is.na(crs_info)) crs_info <- "unknown"

    cli::cli_alert_success("Loaded {nrow(parcels_sf)} parcels as sf object (CRS: {crs_info})")
    parcels_sf

  }, error = function(e) {
    cli::cli_warn("Failed to load parcels: {e$message}")
    NULL
  })
}


#' Save indicators results to project
#'
#' @description
#' Saves computed indicators to project.
#'
#' @param project_id Character. Project ID.
#' @param indicators List or data.frame. Computed indicators.
#'
#' @return Logical. TRUE if successful.
#'
#' @noRd
save_indicators <- function(project_id, indicators) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    cli::cli_abort("Project not found: {project_id}")
  }

  indicators_path <- file.path(project_path, "data", "indicators.parquet")

  tryCatch({
    if (!requireNamespace("arrow", quietly = TRUE)) {
      cli::cli_abort("Package 'arrow' is required")
    }

    # Convert to data.frame if needed
    if (is.list(indicators) && !is.data.frame(indicators)) {
      indicators_df <- as.data.frame(indicators)
    } else {
      indicators_df <- indicators
    }

    arrow::write_parquet(indicators_df, indicators_path)

    # Update metadata
    update_project_metadata(project_id, list(
      indicators_computed = TRUE,
      updated_at = Sys.time(),
      status = "completed"
    ))

    cli::cli_alert_success("Indicators saved")
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
#' @return data.frame with indicators, or NULL if not found.
#'
#' @noRd
load_indicators <- function(project_id) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    return(NULL)
  }

  indicators_path <- file.path(project_path, "data", "indicators.parquet")

  if (!file.exists(indicators_path)) {
    return(NULL)
  }

  tryCatch({
    arrow::read_parquet(indicators_path)
  }, error = function(e) {
    cli::cli_warn("Failed to load indicators: {e$message}")
    NULL
  })
}


#' Load project
#'
#' @description
#' Loads a complete project including metadata, parcels, and indicators.
#'
#' @param project_id Character. Project ID.
#'
#' @return List with project data, or NULL if not found.
#'
#' @noRd
load_project <- function(project_id) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    cli::cli_warn("Project not found: {project_id}")
    return(NULL)
  }

  metadata <- load_project_metadata(project_id)
  if (is.null(metadata)) {
    return(NULL)
  }

  list(
    id = project_id,
    path = project_path,
    metadata = metadata,
    parcels = load_parcels(project_id),
    indicators = load_indicators(project_id)
  )
}


#' List recent projects
#'
#' @description
#' Lists recent projects sorted by last update date.
#'
#' @param limit Integer. Maximum number of projects to return (default: 10).
#'
#' @return data.frame with project info.
#'
#' @noRd
list_recent_projects <- function(limit = 10L) {
  root <- get_projects_root()

  if (!dir.exists(root)) {
    return(data.frame(
      id = character(0),
      name = character(0),
      description = character(0),
      owner = character(0),
      status = character(0),
      parcels_count = integer(0),
      created_at = as.POSIXct(character(0)),
      updated_at = as.POSIXct(character(0)),
      is_corrupted = logical(0)
    ))
  }

  # List project directories
  dirs <- list.dirs(root, full.names = TRUE, recursive = FALSE)

  if (length(dirs) == 0) {
    return(data.frame(
      id = character(0),
      name = character(0),
      description = character(0),
      owner = character(0),
      status = character(0),
      parcels_count = integer(0),
      created_at = as.POSIXct(character(0)),
      updated_at = as.POSIXct(character(0)),
      is_corrupted = logical(0)
    ))
  }

  # Load metadata for each project
  projects <- lapply(dirs, function(dir) {
    project_id <- basename(dir)
    health <- check_project_health(project_id)

    metadata_path <- file.path(dir, "metadata.json")
    if (!file.exists(metadata_path)) {
      return(NULL)
    }

    tryCatch({
      metadata <- jsonlite::read_json(metadata_path)
      data.frame(
        id = metadata$id %||% project_id,
        name = metadata$name %||% "Untitled",
        description = metadata$description %||% "",
        owner = metadata$owner %||% "",
        status = metadata$status %||% "unknown",
        parcels_count = metadata$parcels_count %||% 0L,
        created_at = as.POSIXct(metadata$created_at %||% NA),
        updated_at = as.POSIXct(metadata$updated_at %||% NA),
        is_corrupted = !health$valid,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      # Corrupted metadata
      data.frame(
        id = project_id,
        name = "Corrupted Project",
        description = "",
        owner = "",
        status = "error",
        parcels_count = 0L,
        created_at = as.POSIXct(NA),
        updated_at = as.POSIXct(NA),
        is_corrupted = TRUE,
        stringsAsFactors = FALSE
      )
    })
  })

  # Combine and sort
  projects <- do.call(rbind, Filter(Negate(is.null), projects))

  if (is.null(projects) || nrow(projects) == 0) {
    return(data.frame(
      id = character(0),
      name = character(0),
      description = character(0),
      owner = character(0),
      status = character(0),
      parcels_count = integer(0),
      created_at = as.POSIXct(character(0)),
      updated_at = as.POSIXct(character(0)),
      is_corrupted = logical(0)
    ))
  }

  # Sort by updated_at (most recent first)
  projects <- projects[order(projects$updated_at, decreasing = TRUE), ]

  # Apply limit
  if (nrow(projects) > limit) {
    projects <- projects[1:limit, ]
  }

  rownames(projects) <- NULL
  projects
}


#' Check project health
#'
#' @description
#' Checks if a project is valid and not corrupted.
#'
#' @param project_id Character. Project ID.
#'
#' @return List with valid (logical) and issues (character vector).
#'
#' @noRd
check_project_health <- function(project_id) {
  project_path <- get_project_path(project_id)

  issues <- character(0)

  # Check project exists
  if (is.null(project_path) || !dir.exists(project_path)) {
    return(list(valid = FALSE, issues = "Project directory not found"))
  }

  # Check metadata
  metadata_path <- file.path(project_path, "metadata.json")
  if (!file.exists(metadata_path)) {
    issues <- c(issues, "Missing metadata.json")
  } else {
    tryCatch({
      metadata <- jsonlite::read_json(metadata_path)
      if (is.null(metadata$name)) {
        issues <- c(issues, "Metadata missing 'name' field")
      }
    }, error = function(e) {
      issues <<- c(issues, paste("Corrupted metadata:", e$message))
    })
  }

  # Check data directory
  data_path <- file.path(project_path, "data")
  if (!dir.exists(data_path)) {
    issues <- c(issues, "Missing data directory")
  }

  # Check parcels file if metadata says parcels exist
  if (file.exists(metadata_path)) {
    metadata <- tryCatch(jsonlite::read_json(metadata_path), error = function(e) NULL)
    if (!is.null(metadata) && !is.null(metadata$parcels_count) && metadata$parcels_count > 0) {
      parcels_path <- file.path(project_path, "data", "parcels.parquet")
      if (!file.exists(parcels_path)) {
        issues <- c(issues, "Missing parcels.parquet but metadata indicates parcels exist")
      }
    }
  }

  list(
    valid = length(issues) == 0,
    issues = issues
  )
}


#' Delete project
#'
#' @description
#' Permanently deletes a project and all its data.
#'
#' @param project_id Character. Project ID.
#'
#' @return Logical. TRUE if deleted successfully.
#'
#' @noRd
delete_project <- function(project_id) {
  project_path <- get_project_path(project_id)

  if (is.null(project_path) || !dir.exists(project_path)) {
    cli::cli_warn("Project not found: {project_id}")
    return(FALSE)
  }

  tryCatch({
    unlink(project_path, recursive = TRUE)
    cli::cli_alert_success("Project deleted: {project_id}")
    TRUE
  }, error = function(e) {
    cli::cli_abort("Failed to delete project: {e$message}")
  })
}


#' Update project status
#'
#' @description
#' Updates the status of a project.
#'
#' @param project_id Character. Project ID.
#' @param status Character. New status (draft, downloading, computing, completed, error).
#'
#' @return Logical. TRUE if successful.
#'
#' @noRd
update_project_status <- function(project_id, status) {
  valid_statuses <- c("draft", "downloading", "computing", "completed", "error")

  if (!status %in% valid_statuses) {
    cli::cli_abort("Invalid status: {status}. Must be one of: {paste(valid_statuses, collapse = ', ')}")
  }

  update_project_metadata(project_id, list(
    status = status,
    updated_at = Sys.time()
  ))
}


#' Update project metadata
#'
#' @description
#' Updates specific fields in project metadata.
#'
#' @param project_id Character. Project ID.
#' @param updates List. Fields to update.
#'
#' @return Logical. TRUE if successful.
#'
#' @noRd
update_project_metadata <- function(project_id, updates) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    cli::cli_abort("Project not found: {project_id}")
  }

  metadata_path <- file.path(project_path, "metadata.json")

  if (!file.exists(metadata_path)) {
    cli::cli_abort("Metadata file not found")
  }

  tryCatch({
    metadata <- jsonlite::read_json(metadata_path)

    # Update fields
    for (key in names(updates)) {
      metadata[[key]] <- updates[[key]]
    }

    # Always update updated_at
    metadata$updated_at <- Sys.time()

    jsonlite::write_json(metadata, metadata_path, auto_unbox = TRUE, pretty = TRUE)
    TRUE

  }, error = function(e) {
    cli::cli_abort("Failed to update metadata: {e$message}")
  })
}


#' Load project metadata
#'
#' @description
#' Loads metadata for a project.
#'
#' @param project_id Character. Project ID.
#'
#' @return List with metadata, or NULL if not found.
#'
#' @noRd
load_project_metadata <- function(project_id) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    return(NULL)
  }

  metadata_path <- file.path(project_path, "metadata.json")

  if (!file.exists(metadata_path)) {
    return(NULL)
  }

  tryCatch({
    jsonlite::read_json(metadata_path)
  }, error = function(e) {
    cli::cli_warn("Failed to load metadata: {e$message}")
    NULL
  })
}


#' Get project path
#'
#' @description
#' Returns the full path to a project directory.
#'
#' @param project_id Character. Project ID.
#'
#' @return Character path, or NULL if not found.
#'
#' @noRd
get_project_path <- function(project_id) {
  if (is.null(project_id) || nchar(project_id) == 0) {
    return(NULL)
  }

  root <- get_projects_root()
  project_path <- file.path(root, project_id)

  if (dir.exists(project_path)) {
    return(project_path)
  }

  NULL
}


#' Save external data cache
#'
#' @description
#' Saves downloaded external data (BD Foret, etc.) to project cache.
#' Part of preventive cache strategy.
#'
#' @param project_id Character. Project ID.
#' @param data_name Character. Name of the data (e.g., "bdforet", "corine").
#' @param data sf or data.frame. The data to cache.
#'
#' @return Logical. TRUE if successful.
#'
#' @noRd
save_cache_data <- function(project_id, data_name, data) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    cli::cli_abort("Project not found: {project_id}")
  }

  cache_path <- file.path(project_path, "cache")
  if (!dir.exists(cache_path)) {
    dir.create(cache_path, recursive = TRUE)
  }

  file_path <- file.path(cache_path, paste0(data_name, ".parquet"))

  tryCatch({
    if (!requireNamespace("arrow", quietly = TRUE)) {
      cli::cli_abort("Package 'arrow' is required")
    }

    if (inherits(data, "sf")) {
      # Convert sf to data.frame with WKT
      data_df <- data
      data_df$geometry_wkt <- sf::st_as_text(sf::st_geometry(data))
      data_df <- sf::st_drop_geometry(data_df)

      # Save CRS
      crs_path <- file.path(cache_path, paste0(data_name, "_crs.json"))
      jsonlite::write_json(
        list(epsg = sf::st_crs(data)$epsg),
        crs_path,
        auto_unbox = TRUE
      )

      arrow::write_parquet(data_df, file_path)
    } else {
      arrow::write_parquet(data, file_path)
    }

    TRUE

  }, error = function(e) {
    cli::cli_warn("Failed to cache {data_name}: {e$message}")
    FALSE
  })
}


#' Load cached external data
#'
#' @description
#' Loads cached external data from project.
#'
#' @param project_id Character. Project ID.
#' @param data_name Character. Name of the data.
#'
#' @return Data (sf or data.frame), or NULL if not found.
#'
#' @noRd
load_cache_data <- function(project_id, data_name) {
  project_path <- get_project_path(project_id)
  if (is.null(project_path)) {
    return(NULL)
  }

  file_path <- file.path(project_path, "cache", paste0(data_name, ".parquet"))

  if (!file.exists(file_path)) {
    return(NULL)
  }

  tryCatch({
    data_df <- arrow::read_parquet(file_path)

    # Check if it's spatial data
    if ("geometry_wkt" %in% names(data_df)) {
      crs_path <- file.path(project_path, "cache", paste0(data_name, "_crs.json"))
      crs <- 4326
      if (file.exists(crs_path)) {
        crs_info <- jsonlite::read_json(crs_path)
        if (!is.null(crs_info$epsg)) {
          crs <- crs_info$epsg
        }
      }

      data_sf <- sf::st_as_sf(data_df, wkt = "geometry_wkt", crs = crs)
      data_sf$geometry_wkt <- NULL
      return(data_sf)
    }

    data_df

  }, error = function(e) {
    cli::cli_warn("Failed to load cached {data_name}: {e$message}")
    NULL
  })
}
