#' Field Data Schema for QField Integration
#'
#' @description
#' Defines the data model used for field inventory with QField. Two layers
#' are linked by \code{plot_id}:
#' \itemize{
#'   \item \strong{placette} (1): sampling plot, produced upstream by the
#'     GRTS/TSP workflow (tutorial 09-sampling).
#'   \item \strong{arbre} (N): individual tree measurements collected on
#'     the field.
#' }
#'
#' Each field description carries the information needed by
#' \code{\link{create_qfield_project}} to produce a fully configured
#' \code{.qgz} project: type, domain of values, and the recommended
#' QGIS edit widget.
#'
#' The species domain is pulled from \code{\link{list_species_classes}} to
#' keep a single source of truth with the rest of the package.
#'
#' @name field_schema
NULL


# QGIS widget types used in forms (subset mapped to our needs)
.qgis_widgets <- c(
  text         = "TextEdit",
  range        = "Range",
  datetime     = "DateTime",
  value_map    = "ValueMap",
  relation     = "ValueRelation",
  photo        = "ExternalResource",
  checkbox     = "CheckBox"
)


.field <- function(name, type, widget, ...,
                   label = NULL, domain = NULL, required = FALSE,
                   min = NA_real_, max = NA_real_, default = NULL) {
  if (!widget %in% names(.qgis_widgets)) {
    cli::cli_abort("Unknown widget {.val {widget}}. Allowed: {.val {names(.qgis_widgets)}}.")
  }
  list(
    name = name,
    type = type,
    widget = widget,
    qgis_widget = unname(.qgis_widgets[widget]),
    label = label %||% name,
    domain = domain,
    required = required,
    min = min,
    max = max,
    default = default
  )
}


#' Get the placette layer schema
#'
#' Returns the ordered list of field descriptors for the \code{placette}
#' layer. Each entry is a list with \code{name}, \code{type},
#' \code{widget}, \code{qgis_widget}, \code{label}, \code{domain},
#' \code{required}, \code{min}, \code{max}, \code{default}.
#'
#' @return A list of field descriptors.
#'
#' @examples
#' schema <- get_placette_schema()
#' vapply(schema, `[[`, character(1), "name")
#'
#' @export
get_placette_schema <- function() {
  list(
    .field("plot_id",      "character", "text",
           label = "Plot ID", required = TRUE),
    .field("visit_order",  "integer",   "range",
           label = "Visit order", min = 1, max = 10000),
    .field("type",         "character", "value_map",
           label = "Sampling type",
           domain = c("Base", "Over"),
           default = "Base"),
    .field("date_visite",  "datetime",  "datetime",
           label = "Visit date"),
    .field("observateur",  "character", "text",
           label = "Observer"),
    .field("pente_pct",    "double",    "range",
           label = "Slope (%)", min = 0, max = 200),
    .field("exposition",   "character", "value_map",
           label = "Aspect",
           domain = c("N", "NE", "E", "SE", "S", "SW", "W", "NW", "flat")),
    .field("recouvrement_pct", "double", "range",
           label = "Canopy cover (%)", min = 0, max = 100),
    .field("photos",       "character", "photo",
           label = "Photos"),
    .field("notes",        "character", "text",
           label = "Notes")
  )
}


#' Get the arbre layer schema
#'
#' Returns the ordered list of field descriptors for the \code{arbre}
#' layer. The \code{espece} domain is populated from the species
#' configuration of \code{region} (see \code{\link{list_species_classes}}),
#' so that QField offers a controlled vocabulary consistent with the rest
#' of the package.
#'
#' @param region Character. Species region used to populate the
#'   \code{espece} domain. Default \code{"BFC"}.
#' @param lang Character. Language for the species labels. Default
#'   \code{"fr"}.
#'
#' @return A list of field descriptors.
#'
#' @examples
#' schema <- get_arbre_schema(region = "BFC", lang = "fr")
#' espece <- Filter(function(f) f$name == "espece", schema)[[1]]
#' espece$domain
#'
#' @export
get_arbre_schema <- function(region = "BFC", lang = "fr") {
  species_df <- tryCatch(
    list_species_classes(region = region, lang = lang),
    error = function(e) {
      cli::cli_warn("Species config for {.val {region}} unavailable: {.val {e$message}}. Falling back to free text.")
      NULL
    }
  )
  species_domain <- if (!is.null(species_df)) species_df$code else NULL
  species_labels <- if (!is.null(species_df)) {
    stats::setNames(species_df$label, species_df$code)
  } else {
    NULL
  }

  list(
    .field("plot_id",  "character", "text",
           label = "Plot ID", required = TRUE),
    .field("tree_id",  "character", "text",
           label = "Tree ID", required = TRUE),
    .field("espece",   "character", "value_map",
           label = "Species",
           domain = species_domain,
           default = NULL),
    .field("dbh_cm",   "double",    "range",
           label = "DBH (cm)", min = 0, max = 300, required = TRUE),
    .field("h_m",      "double",    "range",
           label = "Total height (m)", min = 0, max = 80),
    .field("statut",   "character", "value_map",
           label = "Status",
           domain = c("vivant", "mort", "chablis", "coupe"),
           default = "vivant"),
    .field("qualite",  "character", "value_map",
           label = "Quality",
           domain = c("A", "B", "C", "D")),
    .field("photos",   "character", "photo",
           label = "Photos"),
    .field("notes",    "character", "text",
           label = "Notes"),
    # Attached metadata (not shown but useful to roundtrip labels)
    .field(".species_labels", "attachment", "text",
           label = "(labels)", domain = species_labels)
  )
}


#' Convert a schema to a tidy data.frame
#'
#' Helper used by exporters and tests. Drops attachment-only fields
#' (those whose name starts with a dot).
#'
#' @param schema A list returned by \code{\link{get_placette_schema}} or
#'   \code{\link{get_arbre_schema}}.
#'
#' @return A data.frame with one row per visible field.
#'
#' @examples
#' schema_to_df(get_placette_schema())
#'
#' @export
schema_to_df <- function(schema) {
  visible <- Filter(function(f) !startsWith(f$name, "."), schema)
  data.frame(
    name = vapply(visible, `[[`, character(1), "name"),
    type = vapply(visible, `[[`, character(1), "type"),
    widget = vapply(visible, `[[`, character(1), "qgis_widget"),
    label = vapply(visible, `[[`, character(1), "label"),
    required = vapply(visible, `[[`, logical(1), "required"),
    stringsAsFactors = FALSE
  )
}


#' Build an empty sf data.frame matching a schema
#'
#' Produces a zero-row \code{sf} object whose columns and column types
#' match \code{schema}. Used by \code{\link{create_qfield_project}} to
#' seed the \code{arbre} layer before it is filled on the field.
#'
#' @param schema A schema list (see \code{\link{get_arbre_schema}}).
#' @param crs An integer EPSG code. Default 2154 (Lambert-93).
#' @param geometry_type One of \code{"POINT"}, \code{"MULTIPOINT"},
#'   \code{"LINESTRING"}, \code{"POLYGON"}. Default \code{"POINT"}.
#'
#' @return An empty sf object.
#'
#' @keywords internal
empty_sf_from_schema <- function(schema, crs = 2154, geometry_type = "POINT") {
  visible <- Filter(function(f) !startsWith(f$name, "."), schema)
  cols <- lapply(visible, function(f) {
    switch(f$type,
      character = character(0),
      integer   = integer(0),
      double    = double(0),
      datetime  = as.POSIXct(character(0), tz = "UTC"),
      character(0)
    )
  })
  names(cols) <- vapply(visible, `[[`, character(1), "name")
  df <- as.data.frame(cols, stringsAsFactors = FALSE)

  # Build a zero-length sfc with the requested geometry type so downstream
  # drivers (notably GPKG) record the geometry column correctly.
  empty_geom <- switch(toupper(geometry_type),
    POINT      = sf::st_point(),
    LINESTRING = sf::st_linestring(matrix(numeric(0), ncol = 2)),
    POLYGON    = sf::st_polygon(),
    sf::st_point()
  )
  sfc <- sf::st_sfc(empty_geom, crs = crs)[0]
  attr(sfc, "class") <- c(paste0("sfc_", toupper(geometry_type)), "sfc")
  df$geometry <- sfc
  sf::st_sf(df, sf_column_name = "geometry", crs = crs)
}
