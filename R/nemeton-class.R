#' Create nemeton_units object
#'
#' Creates a nemeton_units object from spatial data, representing spatial analysis units
#' (forest parcels, plots, grids).
#'
#' @param x An \code{sf} object or path to spatial file (GeoPackage, shapefile)
#' @param id_col Character. Name of column to use as unique identifier.
#'   If NULL, generates automatically as "unit_001", "unit_002", etc.
#' @param metadata Named list of metadata (site_name, year, source, description, etc.)
#' @param validate Logical. Validate geometries? Default TRUE.
#'
#' @return An object of class \code{nemeton_units} (inherits from \code{sf})
#'
#' @details
#' The function validates that:
#' \itemize{
#'   \item Geometries are POLYGON or MULTIPOLYGON
#'   \item CRS is defined
#'   \item Geometries are valid (if validate = TRUE)
#'   \item No empty geometries
#' }
#'
#' Metadata are stored as an attribute and can include:
#' \itemize{
#'   \item site_name: Name of the site/forest
#'   \item year: Reference year
#'   \item source: Data source
#'   \item description: Optional description
#' }
#'
#' @examples
#' \dontrun{
#' library(sf)
#'
#' # From sf object
#' polygons <- st_read("parcels.gpkg")
#' units <- nemeton_units(
#'   polygons,
#'   metadata = list(
#'     site_name = "Forêt de Fontainebleau",
#'     year = 2024,
#'     source = "IGN BD Forêt v2"
#'   )
#' )
#'
#' # From file path
#' units <- nemeton_units(
#'   "parcels.gpkg",
#'   id_col = "parcel_id",
#'   metadata = list(site_name = "Test Forest")
#' )
#' }
#'
#' @export
nemeton_units <- function(x, id_col = NULL, metadata = list(), validate = TRUE) {
  # Load if path
  if (is.character(x) && length(x) == 1) {
    if (!file.exists(x)) {
      cli::cli_abort("File not found: {.path {x}}")
    }
    file_path <- x
    cli::cli_alert_info("Loading spatial data from {.path {file_path}}")
    x <- sf::st_read(file_path, quiet = TRUE)
  }

  # Validate
  if (validate) {
    validate_sf(x, require_crs = TRUE, require_valid = TRUE)
  }

  # Handle ID column
  if (is.null(id_col)) {
    # Generate IDs
    n_ids <- nrow(x)
    x$nemeton_id <- generate_ids(n_ids)
    cli::cli_alert_info("Generated {n_ids} unique ID{?s}")
  } else {
    # Check if column exists
    if (!id_col %in% names(x)) {
      cli::cli_abort("Column {.field {id_col}} not found in data")
    }
    # Rename to nemeton_id
    x$nemeton_id <- as.character(x[[id_col]])
  }

  # Check uniqueness
  if (any(duplicated(x$nemeton_id))) {
    cli::cli_abort("IDs must be unique. Found duplicates in {.field nemeton_id}")
  }

  # Add metadata
  metadata_full <- c(
    metadata,
    list(
      crs = sf::st_crs(x),
      n_units = nrow(x),
      area_total = sum(sf::st_area(x)),
      created_at = Sys.time()
    )
  )

  attr(x, "metadata") <- metadata_full

  # Set class
  class(x) <- c("nemeton_units", class(x))

  x
}

#' Print method for nemeton_units
#'
#' @param x A nemeton_units object
#' @param ... Additional arguments (not used)
#'
#' @return Invisible x
#' @export
print.nemeton_units <- function(x, ...) {
  meta <- attr(x, "metadata")

  cli::cli_h1("nemeton_units object")

  if (!is.null(meta$site_name)) {
    cli::cli_text("Site: {.strong {meta$site_name}}")
  }
  if (!is.null(meta$year)) {
    cli::cli_text("Year: {meta$year}")
  }

  cli::cli_text("Units: {.strong {nrow(x)}}")

  if (!is.null(meta$area_total)) {
    area_ha <- as.numeric(units::set_units(meta$area_total, "ha"))
    cli::cli_text("Total area: {.strong {round(area_ha, 1)}} ha")
  }

  if (!is.null(meta$crs)) {
    cli::cli_text("CRS: {.strong {meta$crs$input}}")
  }

  cli::cli_text("")
  NextMethod()

  invisible(x)
}

#' Summary method for nemeton_units
#'
#' @param object A nemeton_units object
#' @param ... Additional arguments (not used)
#'
#' @return Invisible object
#' @export
summary.nemeton_units <- function(object, ...) {
  meta <- attr(object, "metadata")

  cli::cli_h2("Nemeton Units Summary")

  cli::cli_dl(c(
    "Number of units" = nrow(object),
    "CRS" = if (!is.null(meta$crs)) meta$crs$input else "Unknown",
    "Site" = if (!is.null(meta$site_name)) meta$site_name else "Not specified",
    "Year" = if (!is.null(meta$year)) as.character(meta$year) else "Not specified",
    "Source" = if (!is.null(meta$source)) meta$source else "Not specified"
  ))

  if (!is.null(meta$area_total)) {
    area_ha <- as.numeric(units::set_units(meta$area_total, "ha"))
    cli::cli_text("")
    cli::cli_text("Total area: {round(area_ha, 2)} ha")
    cli::cli_text("Mean area: {round(area_ha / nrow(object), 2)} ha/unit")
  }

  cli::cli_text("")
  cli::cli_h3("Attributes")
  print(names(object))

  invisible(object)
}

#' Create nemeton_layers object
#'
#' Creates a catalog of spatial layers (rasters and vectors) with lazy loading.
#'
#' @param rasters Named list of paths to raster files (GeoTIFF, etc.)
#' @param vectors Named list of paths to vector files (GeoPackage, shapefile, etc.)
#' @param validate Logical. Validate file existence? Default TRUE.
#'
#' @return An object of class \code{nemeton_layers}
#'
#' @details
#' Layers are not loaded into memory until first use (lazy loading).
#' This allows creating a catalog of large rasters without memory overhead.
#'
#' @examples
#' \dontrun{
#' layers <- nemeton_layers(
#'   rasters = list(
#'     ndvi = "data/sentinel2_ndvi.tif",
#'     dem = "data/ign_mnt_25m.tif"
#'   ),
#'   vectors = list(
#'     rivers = "data/bdtopo_hydro.gpkg",
#'     roads = "data/routes.shp"
#'   )
#' )
#'
#' summary(layers)
#' }
#'
#' @export
nemeton_layers <- function(rasters = NULL, vectors = NULL, validate = TRUE) {
  # Check that at least one is provided
  if (is.null(rasters) && is.null(vectors)) {
    cli::cli_abort("At least one of {.arg rasters} or {.arg vectors} must be provided")
  }

  # Initialize structure
  layers <- list(
    rasters = list(),
    vectors = list(),
    metadata = list(
      created_at = Sys.time(),
      n_rasters = 0,
      n_vectors = 0,
      validated = validate
    )
  )

  # Process rasters
  if (!is.null(rasters)) {
    if (is.null(names(rasters)) || any(names(rasters) == "")) {
      cli::cli_abort("{.arg rasters} must be a named list")
    }

    for (name in names(rasters)) {
      path <- rasters[[name]]

      # Validate existence
      if (validate && !file.exists(path)) {
        cli::cli_abort("Raster layer {.field {name}}: file not found at {.path {path}}")
      }

      layers$rasters[[name]] <- list(
        path = normalizePath(path, mustWork = FALSE),
        loaded = FALSE,
        object = NULL,
        metadata = list()
      )
    }

    layers$metadata$n_rasters <- length(rasters)
  }

  # Process vectors
  if (!is.null(vectors)) {
    if (is.null(names(vectors)) || any(names(vectors) == "")) {
      cli::cli_abort("{.arg vectors} must be a named list")
    }

    for (name in names(vectors)) {
      path <- vectors[[name]]

      # Validate existence
      if (validate && !file.exists(path)) {
        cli::cli_abort("Vector layer {.field {name}}: file not found at {.path {path}}")
      }

      layers$vectors[[name]] <- list(
        path = normalizePath(path, mustWork = FALSE),
        loaded = FALSE,
        object = NULL,
        metadata = list()
      )
    }

    layers$metadata$n_vectors <- length(vectors)
  }

  # Set class
  class(layers) <- "nemeton_layers"

  n_r <- layers$metadata$n_rasters
  n_v <- layers$metadata$n_vectors
  cli::cli_alert_info("Created layer catalog: {n_r} raster{?s}, {n_v} vector{?s}")

  layers
}

#' Print method for nemeton_layers
#'
#' @param x A nemeton_layers object
#' @param ... Additional arguments (not used)
#'
#' @return Invisible x
#' @export
print.nemeton_layers <- function(x, ...) {
  cli::cli_h1("nemeton_layers object")

  cli::cli_h2("Rasters ({length(x$rasters)})")
  if (length(x$rasters) > 0) {
    for (name in names(x$rasters)) {
      status <- if (x$rasters[[name]]$loaded) "[loaded]" else "[not loaded]"
      cli::cli_li("{.strong {name}}: {.path {basename(x$rasters[[name]]$path)}} {status}")
    }
  } else {
    cli::cli_text("  (none)")
  }

  cli::cli_h2("Vectors ({length(x$vectors)})")
  if (length(x$vectors) > 0) {
    for (name in names(x$vectors)) {
      status <- if (x$vectors[[name]]$loaded) "[loaded]" else "[not loaded]"
      cli::cli_li("{.strong {name}}: {.path {basename(x$vectors[[name]]$path)}} {status}")
    }
  } else {
    cli::cli_text("  (none)")
  }

  invisible(x)
}

#' Summary method for nemeton_layers
#'
#' @param object A nemeton_layers object
#' @param ... Additional arguments (not used)
#'
#' @return Invisible object
#' @export
summary.nemeton_layers <- function(object, ...) {
  cli::cli_h2("Nemeton Layers Summary")

  cli::cli_text("Rasters: {length(object$rasters)}")
  cli::cli_text("Vectors: {length(object$vectors)}")
  cli::cli_text("Created: {format(object$metadata$created_at, '%Y-%m-%d %H:%M')}")

  invisible(object)
}
