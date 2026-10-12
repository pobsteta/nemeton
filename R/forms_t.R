#' Load a FORMS-T canopy-height time series over an area
#'
#' Reads the FORMS-T canopy height (Theia, 10 m, centimetres) for several
#' years and returns one layer per year, on a common grid, cropped to `aoi`.
#' This is the input of the measured path of [indicateur_t2_changement()]
#' (spec 060).
#'
#' Each year is read from a local copy of the national rasters when one is
#' available (`dossier`, files `Height_<year>.tif` as published on Zenodo),
#' otherwise from the Theia STAC catalogue through [load_theia_source()]
#' (THEIA API key required, see `theia_sign_urls()`). A year that cannot be
#' read is skipped with a warning.
#'
#' @param aoi An `sf`/`sfc` area of interest (any CRS).
#' @param annees Integer vector of years. Default `2019:2024`, the years
#'   published at the time of writing.
#' @param dossier Directory holding local `Height_<year>.tif` files. Default
#'   `NULL`: the `NEMETON_FORMS_T_DIR` environment variable, and Theia when it
#'   is unset or a year is missing there.
#' @param country Character. ISO country code. Default `"FR"` (FORMS-T covers
#'   metropolitan France only).
#'
#' @return A `terra::SpatRaster` in centimetres, one layer per year read,
#'   named by year and sorted chronologically; `NULL` (with a warning) when
#'   fewer than three years could be read.
#'
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [indicateur_t2_changement()]
#' @export
#'
#' @examples
#' \dontrun{
#' h <- charger_forms_t_hauteurs(parcelles, annees = 2019:2024)
#' t2 <- indicateur_t2_changement(parcelles, forms_t = h)
#' }
charger_forms_t_hauteurs <- function(aoi, annees = 2019:2024, dossier = NULL,
                                     country = "FR") {
  if (!inherits(aoi, c("sf", "sfc"))) {
    cli::cli_abort("{.arg aoi} must be an {.cls sf} or {.cls sfc} object.")
  }
  annees <- sort(unique(as.integer(annees)))
  if (is.null(dossier)) dossier <- Sys.getenv("NEMETON_FORMS_T_DIR", "")

  couches <- list()
  for (an in annees) {
    r <- .forms_t_annee(aoi, an, dossier, country)
    if (is.null(r)) {
      cli::cli_warn("FORMS-T height {an}: not available, year skipped.")
      next
    }
    couches[[as.character(an)]] <- r
  }
  if (length(couches) < 3L) {
    cli::cli_warn(c(
      "FORMS-T: fewer than three years read ({length(couches)}).",
      i = "A change rate needs at least three years."
    ))
    return(NULL)
  }

  # Grille commune : celle de la première année lue. Les COG FORMS-T sont
  # sur la même grille nationale, le rééchantillonnage ne joue qu'en cas de
  # recadrage différent d'une année à l'autre.
  ref <- couches[[1L]]
  couches <- lapply(couches, function(r) {
    if (terra::compareGeom(r, ref, stopOnError = FALSE)) r
    else terra::resample(r, ref, method = "near")
  })
  out <- terra::rast(couches)
  names(out) <- names(couches)
  out
}

# Une année de FORMS-T sur l'AOI, depuis la copie locale si elle existe,
# sinon depuis Theia. NULL si l'année est illisible.
.forms_t_annee <- function(aoi, an, dossier, country) {
  local <- if (nzchar(dossier)) file.path(dossier, sprintf("Height_%d.tif", an))
  if (!is.null(local) && file.exists(local)) {
    r <- terra::rast(local)
    v <- terra::project(terra::vect(sf::st_geometry(aoi)), terra::crs(r))
    return(terra::crop(r, v, snap = "out"))
  }
  r <- tryCatch(
    load_theia_source(
      "forms_t", aoi = aoi, asset = "height", country = country,
      datetime = sprintf("%d-01-01T00:00:00Z/%d-12-31T23:59:59Z", an, an)
    ),
    error = function(e) NULL
  )
  if (inherits(r, "SpatRaster")) r else NULL
}
