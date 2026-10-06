# localiser_ser.R — rattacher des unités à leur sylvoécorégion (spec 054 lot 4)
# ---------------------------------------------------------------------------
# Les références IFN par SER (production, prélèvement, volume) ne servent à
# rien si l'unité ne connaît pas sa SER : l'app n'a aucune colonne SER sur ses
# parcelles. Le contour des SER est servi en WFS par INRAE (couche
# inrae:ser_l93, IGN, Lambert 93), relevé le 2026-10-01 :
#   - sortie GeoJSON acceptée, BBOX accepté ;
#   - les grandes SER arrivent en plusieurs entités (multiparties éclatées) ;
#   - un polygone porte le code "-1" (hors SER) : il est ignoré.
# Acquisition dans le cœur (règle #1), même pattern que load_onf_parcelles.R.

.SER_WFS <- "https://geodata.inrae.fr/geoserver/inrae/ows"

# Contours des SER intersectant `bbox` (xmin, ymin, xmax, ymax en EPSG:2154),
# ou NULL en cas d'échec réseau ou de réponse illisible.
.ser_wfs_read <- function(bbox, timeout = 60L) {
  urn <- "urn:ogc:def:crs:EPSG::2154"
  url <- paste0(
    .SER_WFS, "?service=WFS&version=2.0.0&request=GetFeature",
    "&typeNames=inrae:ser_l93&outputFormat=application/json",
    "&srsName=EPSG:2154&BBOX=",
    paste(c(format(bbox, scientific = FALSE, trim = TRUE), urn), collapse = ",")
  )
  dest <- tempfile(fileext = ".json")
  on.exit(unlink(dest), add = TRUE)
  ancien <- options(timeout = timeout)
  on.exit(options(ancien), add = TRUE)
  status <- tryCatch(
    suppressWarnings(utils::download.file(url, dest, mode = "wb", quiet = TRUE)),
    error = function(e) {
      cli::cli_warn(c("SER WFS request failed.", i = conditionMessage(e)))
      -1L
    }
  )
  if (!identical(as.integer(status), 0L) || !file.exists(dest) ||
      file.size(dest) == 0) {
    return(NULL)
  }
  x <- tryCatch(sf::st_read(dest, quiet = TRUE), error = function(e) {
    cli::cli_warn(c("SER WFS response could not be parsed.",
                    i = conditionMessage(e)))
    NULL
  })
  if (is.null(x) || !"codeser" %in% names(x)) return(NULL)
  x
}

#' Attach each unit to its sylvoecoregion (SER)
#'
#' @description
#' Adds the SER code of each unit, as needed by the IFN references keyed by
#' sylvoecoregion ([ifn_production_reference()],
#' [indicateur_p2_station()] with `source = "ifn_fh"`,
#' [ifn_taux_prelevement_production()], [completer_volume_ifn()]). A unit
#' that straddles two SER gets the one covering the largest part of it.
#'
#' The SER outlines come from the INRAE WFS (layer `inrae:ser_l93`, IGN
#' sylvoecoregions, Lambert 93), restricted to the extent of `units`; pass
#' `ser_layer` to work offline or with a cached copy.
#'
#' @param units An `sf` object with a defined CRS.
#' @param ser_layer Optional `sf` of SER outlines with a `codeser` column.
#'   `NULL` (default) downloads the outlines intersecting `units`.
#' @param colonne Name of the added column. Default `"ser"`.
#' @param timeout Network timeout in seconds. Default `60`.
#'
#' @return `units` with `colonne` added (or overwritten): the SER code, or
#'   `NA` for a unit outside every SER or when the outlines could not be
#'   obtained (with a warning).
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @seealso [ifn_production_reference()].
#' @export
#' @examples
#' \dontrun{
#' ugf <- localiser_ser(ugf)
#' table(ugf$ser)
#' }
localiser_ser <- function(units, ser_layer = NULL, colonne = "ser",
                          timeout = 60L) {
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an sf object.")
  }
  if (is.na(sf::st_crs(units))) {
    cli::cli_abort("{.arg units} must have a defined CRS.")
  }
  n <- nrow(units)
  if (n == 0L) {
    units[[colonne]] <- character(0)
    return(units)
  }
  u <- sf::st_transform(sf::st_geometry(units), 2154)
  if (is.null(ser_layer)) {
    ser_layer <- .ser_wfs_read(as.numeric(sf::st_bbox(u)), timeout = timeout)
    if (is.null(ser_layer)) {
      cli::cli_warn("SER outlines unavailable: {.field {colonne}} left NA.")
      units[[colonne]] <- rep(NA_character_, n)
      return(units)
    }
  }
  if (!"codeser" %in% names(ser_layer)) {
    cli::cli_abort("{.arg ser_layer} must have a {.field codeser} column.")
  }
  ser_layer <- ser_layer[!is.na(ser_layer$codeser) & ser_layer$codeser != "-1", ]
  ser_layer <- sf::st_make_valid(sf::st_transform(ser_layer["codeser"], 2154))

  # Plus grande intersection, par unite : une UGF a cheval prend la SER qui
  # la couvre le plus. Points et lignes : simple appartenance.
  code <- rep(NA_character_, n)
  inter <- sf::st_intersects(u, ser_layer)
  for (i in seq_len(n)) {
    k <- inter[[i]]
    if (length(k) == 0L) next
    if (length(k) == 1L || !inherits(u[i], c("sfc_POLYGON", "sfc_MULTIPOLYGON"))) {
      code[i] <- ser_layer$codeser[k[1]]
      next
    }
    aires <- vapply(k, function(j) {
      a <- suppressWarnings(sf::st_intersection(u[i], sf::st_geometry(ser_layer)[j]))
      if (length(a) == 0L) 0 else sum(as.numeric(sf::st_area(a)))
    }, numeric(1))
    # Une SER eclatee en plusieurs entites : sommer par code.
    par_code <- tapply(aires, ser_layer$codeser[k], sum)
    code[i] <- names(par_code)[which.max(par_code)]
  }
  units[[colonne]] <- code
  units
}
