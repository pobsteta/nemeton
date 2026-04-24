#' QField Project Export
#'
#' @description
#' Package a sampling plan (output of the GRTS + TSP workflow, see
#' tutorial \code{09-sampling}) as a QField-ready \code{.qgz} project.
#'
#' A \code{.qgz} is a ZIP archive containing a QGIS project file
#' (\code{.qgs} XML) and the data referenced with relative paths. We
#' embed a GeoPackage with the layers required for field work:
#' \itemize{
#'   \item \strong{placettes}: GRTS sampling points (editable metadata).
#'   \item \strong{arbres}: empty layer seeded from
#'     \code{\link{get_arbre_schema}}, filled on the field.
#'   \item \strong{zone_etude}: study area (read-only context).
#'   \item \strong{parcours_tsp} (optional): TSP route between plots.
#' }
#'
#' The QGIS project file declares edit widgets, aliases, and NOT NULL
#' constraints based on the schemas returned by
#' \code{\link{get_placette_schema}} and \code{\link{get_arbre_schema}},
#' so QField displays a ready-to-use data entry form.
#'
#' @name qfield_export
NULL


# ---- XML helpers (no hard dependency on xml2) -------------------------

.xml_escape <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&",  "&amp;",  x, fixed = TRUE)
  x <- gsub("<",  "&lt;",   x, fixed = TRUE)
  x <- gsub(">",  "&gt;",   x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x <- gsub("'",  "&apos;", x, fixed = TRUE)
  x
}

.xml_tag <- function(name, attrs = NULL, children = NULL, text = NULL,
                     self_close = is.null(children) && is.null(text)) {
  attr_str <- ""
  if (!is.null(attrs) && length(attrs)) {
    parts <- vapply(names(attrs), function(k) {
      sprintf('%s="%s"', k, .xml_escape(attrs[[k]]))
    }, character(1))
    attr_str <- paste0(" ", paste(parts, collapse = " "))
  }
  if (self_close) {
    return(sprintf("<%s%s/>", name, attr_str))
  }
  inner <- if (!is.null(text)) .xml_escape(text) else paste(children, collapse = "")
  sprintf("<%s%s>%s</%s>", name, attr_str, inner, name)
}


# ---- Widget config ----------------------------------------------------

.widget_config <- function(field) {
  # Build the inner <config> block of <editWidget> depending on widget type.
  switch(field$qgis_widget,
    TextEdit = .xml_tag("config", children = .xml_tag("Option", attrs = list(type = "Map"))),
    Range = {
      opts <- list(
        .xml_tag("Option", attrs = list(name = "AllowNull", type = "bool",
                                         value = if (field$required) "false" else "true")),
        .xml_tag("Option", attrs = list(name = "Min", type = "double",
                                         value = if (is.na(field$min)) "-1e9" else as.character(field$min))),
        .xml_tag("Option", attrs = list(name = "Max", type = "double",
                                         value = if (is.na(field$max)) "1e9" else as.character(field$max))),
        .xml_tag("Option", attrs = list(name = "Step", type = "double", value = "1")),
        .xml_tag("Option", attrs = list(name = "Style", type = "QString", value = "SpinBox"))
      )
      .xml_tag("config", children = .xml_tag("Option", attrs = list(type = "Map"), children = opts))
    },
    DateTime = {
      opts <- list(
        .xml_tag("Option", attrs = list(name = "allow_null", type = "bool", value = "true")),
        .xml_tag("Option", attrs = list(name = "display_format", type = "QString",
                                         value = "yyyy-MM-dd HH:mm:ss")),
        .xml_tag("Option", attrs = list(name = "field_format", type = "QString",
                                         value = "yyyy-MM-dd HH:mm:ss")),
        .xml_tag("Option", attrs = list(name = "field_iso_format", type = "bool", value = "true"))
      )
      .xml_tag("config", children = .xml_tag("Option", attrs = list(type = "Map"), children = opts))
    },
    ValueMap = {
      dom <- field$domain %||% character(0)
      # QGIS 3.x ValueMap canonical structure:
      #   <Option type="Map">
      #     <Option type="List" name="map">
      #       <Option type="Map">
      #         <Option type="QString" name="<label>" value="<key>"/>
      #       </Option>
      #       ...
      #     </Option>
      #   </Option>
      # Earlier we emitted List-of-Lists which crashes QGIS at form build.
      entries <- vapply(dom, function(v) {
        .xml_tag("Option", attrs = list(type = "Map"),
                 children = .xml_tag("Option",
                   attrs = list(type = "QString", name = v, value = v)))
      }, character(1))
      opts <- list(
        .xml_tag("Option", attrs = list(type = "List", name = "map"),
                 children = entries)
      )
      .xml_tag("config", children = .xml_tag("Option", attrs = list(type = "Map"), children = opts))
    },
    ExternalResource = {
      opts <- list(
        .xml_tag("Option", attrs = list(name = "DocumentViewer", type = "int", value = "1")),
        .xml_tag("Option", attrs = list(name = "FileWidget", type = "bool", value = "true")),
        .xml_tag("Option", attrs = list(name = "FileWidgetButton", type = "bool", value = "true")),
        .xml_tag("Option", attrs = list(name = "RelativeStorage", type = "int", value = "1")),
        .xml_tag("Option", attrs = list(name = "StorageMode", type = "int", value = "0"))
      )
      .xml_tag("config", children = .xml_tag("Option", attrs = list(type = "Map"), children = opts))
    },
    CheckBox = {
      opts <- list(
        .xml_tag("Option", attrs = list(name = "CheckedState", type = "QString", value = "true")),
        .xml_tag("Option", attrs = list(name = "UncheckedState", type = "QString", value = "false"))
      )
      .xml_tag("config", children = .xml_tag("Option", attrs = list(type = "Map"), children = opts))
    },
    .xml_tag("config", children = .xml_tag("Option", attrs = list(type = "Map")))
  )
}


.field_config_xml <- function(schema) {
  visible <- Filter(function(f) !startsWith(f$name, "."), schema)
  fields <- vapply(visible, function(f) {
    ew <- .xml_tag("editWidget", attrs = list(type = f$qgis_widget),
                   children = .widget_config(f))
    .xml_tag("field",
             attrs = list(name = f$name, configurationFlags = "NoFlag"),
             children = ew)
  }, character(1))
  .xml_tag("fieldConfiguration", children = fields)
}


.aliases_xml <- function(schema) {
  visible <- Filter(function(f) !startsWith(f$name, "."), schema)
  items <- vapply(visible, function(f) {
    .xml_tag("alias", attrs = list(field = f$name, name = f$label, index = "0"))
  }, character(1))
  .xml_tag("aliases", children = items)
}


.constraints_xml <- function(schema) {
  visible <- Filter(function(f) !startsWith(f$name, "."), schema)
  # constraints="1" means NotNull (QGIS bitflag); 0 means no constraint
  items <- vapply(visible, function(f) {
    c_val <- if (isTRUE(f$required)) 1L else 0L
    .xml_tag("constraint",
             attrs = list(field = f$name, constraints = c_val,
                          unique_strength = "0", notnull_strength = if (c_val) "1" else "0",
                          exp_strength = "0"))
  }, character(1))
  .xml_tag("constraints", children = items)
}


.spatialrefsys_xml <- function(crs = 2154) {
  # Build a full <spatialrefsys> block that QGIS 3.x can resolve without
  # relying on just <authid>. Uses sf::st_crs() to pull WKT + proj4.
  info <- tryCatch(sf::st_crs(crs), error = function(e) NULL)
  wkt_val <- if (!is.null(info) && !is.null(info$wkt) && !is.na(info$wkt)) {
    info$wkt
  } else ""
  proj4_val <- if (!is.null(info) && !is.null(info$proj4string) &&
                   !is.na(info$proj4string)) info$proj4string else ""
  desc_val <- if (!is.null(info) && !is.null(info$Name) && !is.na(info$Name)) {
    info$Name
  } else paste0("EPSG:", crs)
  geographic <- if (!is.null(info) && isTRUE(sf::st_is_longlat(info))) "true" else "false"

  .xml_tag("spatialrefsys",
    attrs = list(nativeFormat = "Wkt"),
    children = c(
      .xml_tag("wkt",                text = wkt_val),
      .xml_tag("proj4",              text = proj4_val),
      .xml_tag("srsid",              text = as.character(crs)),
      .xml_tag("srid",               text = as.character(crs)),
      .xml_tag("authid",             text = paste0("EPSG:", crs)),
      .xml_tag("description",        text = desc_val),
      .xml_tag("projectionacronym",  text = ""),
      .xml_tag("ellipsoidacronym",   text = ""),
      .xml_tag("geographicflag",     text = geographic)
    ))
}

.srs_xml <- function(crs = 2154) {
  .xml_tag("srs", children = .spatialrefsys_xml(crs))
}


col2rgb_str <- function(hex) {
  rgb <- grDevices::col2rgb(hex)
  paste(rgb[1], rgb[2], rgb[3], sep = ",")
}


# ---- Layer block ------------------------------------------------------

.extent_xml <- function(bbox = NULL) {
  # QGIS 3.x expects an <extent> under every <maplayer>. Missing values
  # trigger a silent parse failure on some builds.
  if (is.null(bbox) || any(!is.finite(unlist(bbox)))) {
    bbox <- c(xmin = 0, ymin = 0, xmax = 1, ymax = 1)
  }
  fmt <- function(x) formatC(x, format = "f", digits = 8)
  .xml_tag("extent",
    children = c(
      .xml_tag("xmin", text = fmt(bbox[["xmin"]])),
      .xml_tag("ymin", text = fmt(bbox[["ymin"]])),
      .xml_tag("xmax", text = fmt(bbox[["xmax"]])),
      .xml_tag("ymax", text = fmt(bbox[["ymax"]]))
    ))
}


.maplayer_xml <- function(id, name, gpkg_rel, layername, geometry,
                          schema, crs, bbox = NULL,
                          renderer_xml = NULL, readonly = FALSE) {
  children <- c(
    .extent_xml(bbox),
    .xml_tag("id", text = id),
    .xml_tag("datasource", text = sprintf("./%s|layername=%s", gpkg_rel, layername)),
    .xml_tag("layername", text = name),
    .xml_tag("provider", attrs = list(encoding = "UTF-8"), text = "ogr"),
    .srs_xml(crs),
    if (!is.null(schema)) .field_config_xml(schema) else "",
    if (!is.null(schema)) .aliases_xml(schema) else "",
    if (!is.null(schema)) .constraints_xml(schema) else "",
    if (!is.null(renderer_xml)) renderer_xml else "",
    if (readonly) .xml_tag("flags", text = "Identifiable|Readonly") else ""
  )
  .xml_tag("maplayer",
    attrs = list(type = "vector", geometry = geometry,
                 hasScaleBasedVisibilityFlag = "0",
                 readOnly = if (readonly) "1" else "0"),
    children = children)
}


.layer_tree_node <- function(id, name, source) {
  .xml_tag("layer-tree-layer",
    attrs = list(id = id, name = name, source = source,
                 checked = "Qt::Checked", expanded = "1",
                 providerKey = "ogr", patch_size = "-1,-1"))
}


.build_qgs_xml <- function(layers, crs = 2154, project_name = "Nemeton sampling") {
  # layers: list of list(id, name, gpkg_rel, layername, geometry, schema,
  #                     renderer, readonly, bbox)
  maplayers <- vapply(layers, function(l) {
    .maplayer_xml(l$id, l$name, l$gpkg_rel, l$layername, l$geometry,
                  l$schema, crs, l$bbox, l$renderer, isTRUE(l$readonly))
  }, character(1))
  tree_nodes <- vapply(layers, function(l) {
    src <- sprintf("./%s|layername=%s", l$gpkg_rel, l$layername)
    .layer_tree_node(l$id, l$name, src)
  }, character(1))

  empty_map <- .xml_tag("Option", attrs = list(type = "Map"))
  customprops <- .xml_tag("customproperties", children = empty_map)
  custom_order <- .xml_tag("custom-order", attrs = list(enabled = "0"))

  header <- '<?xml version="1.0" encoding="UTF-8"?>'
  body <- .xml_tag("qgis",
    attrs = list(version = "3.34.0-Prizren", projectname = project_name),
    children = c(
      .xml_tag("homePath", attrs = list(path = "")),
      .xml_tag("title", text = project_name),
      .xml_tag("projectCrs",
        children = .spatialrefsys_xml(crs)),
      .xml_tag("layer-tree-group",
        attrs = list(checked = "Qt::Checked", expanded = "1"),
        children = c(customprops, tree_nodes, custom_order)),
      .xml_tag("projectlayers", children = maplayers),
      .xml_tag("properties", children = empty_map)
    )
  )
  paste0(header, "\n", body, "\n")
}


# ---- Public API -------------------------------------------------------

#' Create a QField project from a sampling plan
#'
#' Packages sampling plots, study area, and (optionally) the TSP route as
#' a QField-ready \code{.qgz} project. The project embeds a GeoPackage
#' and a minimal QGIS 3.x project file wired with field schemas.
#'
#' @param placettes An sf object with POINT geometry. Must contain the
#'   \code{plot_id} column. A \code{type} column (values \code{"Base"},
#'   \code{"Over"}) triggers categorised symbology.
#' @param zone_etude Optional sf polygon of the study area.
#' @param parcours_tsp Optional sf linestring of the TSP route.
#' @param output_dir Character. Destination directory (created if
#'   needed).
#' @param project_name Character. Name of the \code{.qgz} file (without
#'   extension) and the project title in QGIS. Default
#'   \code{"echantillon"}.
#' @param crs Integer EPSG code. Must match the CRS of \code{placettes}.
#'   Default 2154 (Lambert-93).
#' @param region Character. Species region used to populate the
#'   \code{espece} domain in the arbre layer. Default \code{"BFC"}.
#' @param lang Character. Language used for aliases and labels. Default
#'   \code{"fr"}.
#' @param overwrite Logical. Overwrite an existing \code{.qgz}. Default
#'   \code{TRUE}.
#'
#' @return Absolute path to the \code{.qgz} file that was created.
#'
#' @examples
#' \dontrun{
#' library(sf)
#' pts <- st_sf(
#'   plot_id = sprintf("P%02d", 1:3),
#'   type = c("Base", "Base", "Over"),
#'   visit_order = 1:3,
#'   geometry = st_sfc(st_point(c(900000, 6500000)),
#'                     st_point(c(900100, 6500100)),
#'                     st_point(c(900200, 6500200)),
#'                     crs = 2154)
#' )
#' qgz <- create_qfield_project(pts, output_dir = tempdir())
#' }
#'
#' @export
create_qfield_project <- function(placettes,
                                  zone_etude = NULL,
                                  parcours_tsp = NULL,
                                  output_dir,
                                  project_name = "echantillon",
                                  crs = 2154,
                                  region = "BFC",
                                  lang = "fr",
                                  overwrite = TRUE) {
  if (!inherits(placettes, "sf")) {
    cli::cli_abort("{.arg placettes} must be an sf object.")
  }
  if (!"plot_id" %in% names(placettes)) {
    cli::cli_abort("{.arg placettes} must contain a {.val plot_id} column.")
  }
  if (sf::st_crs(placettes)$epsg %||% NA != crs) {
    placettes <- sf::st_transform(placettes, crs)
  }

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  qgz_path <- file.path(output_dir, paste0(project_name, ".qgz"))
  if (file.exists(qgz_path)) {
    if (!overwrite) {
      cli::cli_abort("File {.path {qgz_path}} already exists (overwrite = FALSE).")
    }
    file.remove(qgz_path)
  }

  # Stage in a temp dir, then zip into .qgz with relative paths.
  stage <- tempfile("qfield_stage_")
  dir.create(stage, recursive = TRUE)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)

  gpkg_rel  <- paste0(project_name, ".gpkg")
  gpkg_path <- file.path(stage, gpkg_rel)

  # --- Write GPKG layers ---------------------------------------------
  placette_schema <- get_placette_schema()
  arbre_schema    <- get_arbre_schema(region = region, lang = lang)

  # Ensure placettes carries all expected columns, with NA values TYPED
  # according to the schema — plain NA is logical and would make GPKG
  # store the column as BOOLEAN, which then mismatches the DateTime /
  # Range / TextEdit widgets declared in the .qgs and crashes QGIS when
  # it tries to build the attribute form.
  visible_p <- Filter(function(f) !startsWith(f$name, "."), placette_schema)
  typed_na <- function(type) {
    switch(type,
      character = NA_character_,
      integer   = NA_integer_,
      double    = NA_real_,
      datetime  = as.POSIXct(NA, tz = "UTC"),
      NA
    )
  }
  for (f in visible_p) {
    col <- f$name
    if (!col %in% names(placettes)) {
      placettes[[col]] <- typed_na(f$type)
    } else {
      # Coerce all-NA (logical) columns to the schema type too.
      if (all(is.na(placettes[[col]])) && is.logical(placettes[[col]])) {
        placettes[[col]] <- rep(typed_na(f$type), nrow(placettes))
      }
    }
  }
  p_names <- vapply(visible_p, `[[`, character(1), "name")
  sf::st_write(placettes[c(p_names, attr(placettes, "sf_column"))],
               gpkg_path, layer = "placettes", quiet = TRUE, append = FALSE)

  # Empty arbres layer with correct schema.
  arbres_empty <- empty_sf_from_schema(arbre_schema, crs = crs)
  sf::st_write(arbres_empty, gpkg_path, layer = "arbres",
               quiet = TRUE, append = FALSE)

  if (!is.null(zone_etude)) {
    zone_etude <- sf::st_transform(zone_etude, crs)
    sf::st_write(zone_etude, gpkg_path, layer = "zone_etude",
                 quiet = TRUE, append = FALSE)
  }
  if (!is.null(parcours_tsp)) {
    parcours_tsp <- sf::st_transform(parcours_tsp, crs)
    sf::st_write(parcours_tsp, gpkg_path, layer = "parcours_tsp",
                 quiet = TRUE, append = FALSE)
  }

  # --- Build .qgs XML ------------------------------------------------
  placettes_bbox <- tryCatch(sf::st_bbox(placettes), error = function(e) NULL)
  layers_meta <- list(
    list(id = "placettes_01", name = "Placettes", gpkg_rel = gpkg_rel,
         layername = "placettes", geometry = "Point",
         schema = placette_schema,
         bbox = placettes_bbox,
         renderer = NULL,
         readonly = FALSE),
    list(id = "arbres_01", name = "Arbres", gpkg_rel = gpkg_rel,
         layername = "arbres", geometry = "Point",
         schema = arbre_schema,
         bbox = placettes_bbox,
         renderer = NULL, readonly = FALSE)
  )
  if (!is.null(zone_etude)) {
    layers_meta <- c(layers_meta, list(list(
      id = "zone_etude_01", name = "Zone d'étude", gpkg_rel = gpkg_rel,
      layername = "zone_etude", geometry = "Polygon",
      schema = NULL,
      bbox = tryCatch(sf::st_bbox(zone_etude), error = function(e) placettes_bbox),
      renderer = NULL, readonly = TRUE
    )))
  }
  if (!is.null(parcours_tsp)) {
    layers_meta <- c(layers_meta, list(list(
      id = "parcours_tsp_01", name = "Parcours TSP", gpkg_rel = gpkg_rel,
      layername = "parcours_tsp", geometry = "Line",
      schema = NULL,
      bbox = tryCatch(sf::st_bbox(parcours_tsp), error = function(e) placettes_bbox),
      renderer = NULL, readonly = TRUE
    )))
  }

  qgs_xml <- .build_qgs_xml(layers_meta, crs = crs, project_name = project_name)
  qgs_path <- file.path(stage, paste0(project_name, ".qgs"))
  writeLines(qgs_xml, qgs_path, useBytes = TRUE)

  # --- Zip into .qgz --------------------------------------------------
  owd <- setwd(stage); on.exit(setwd(owd), add = TRUE)
  files_rel <- c(basename(qgs_path), gpkg_rel)
  zip_rc <- utils::zip(zipfile = qgz_path, files = files_rel,
                       flags = "-q -X", zip = Sys.getenv("R_ZIPCMD", "zip"))
  if (zip_rc != 0 || !file.exists(qgz_path)) {
    cli::cli_abort("Failed to build {.path {qgz_path}} (zip return code {zip_rc}).")
  }

  cli::cli_alert_success("QField project created: {.path {qgz_path}}")
  invisible(qgz_path)
}
