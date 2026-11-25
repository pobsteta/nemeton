# Masques du spike de re-entrainement RECONFORT : chenaie et coupes rases
# (mission 060 de nemetonplateforme).

#' Decode a SUFOSAT `YYDDD` clear-cut date
#'
#' `YYDDD` is the two-digit year followed by the day of the year (1 to 366), as
#' in the published SUFOSAT / nemetonsar files: `21150` is day 150 of 2021.
#' Zero and `NA` mean "no clear-cut".
#'
#' @param code Numeric vector of `YYDDD` codes.
#' @return A `data.frame` with `annee` (integer, 2000 + YY), `jour` (integer)
#'   and `date` (`Date`), `NA` where there is no clear-cut. A code whose day is
#'   outside 1..366 is an error, not a missing value.
#' @export
#' @examples
#' reconfort_coupe_decoder(c(21150, 0, NA))
reconfort_coupe_decoder <- function(code) {
  if (!is.numeric(code)) cli::cli_abort("{.arg code} must be numeric.")
  vide <- is.na(code) | code == 0
  jour <- as.integer(code %% 1000)
  yy <- as.integer(code %/% 1000)
  mauvais <- !vide & (jour < 1L | jour > 366L | code < 0 | code != round(code))
  if (any(mauvais)) {
    cli::cli_abort("Invalid {.code YYDDD} code{?s}: {.val {unique(code[mauvais])}} (day must be 1..366).")
  }
  annee <- ifelse(vide, NA_integer_, 2000L + yy)
  jour[vide] <- NA_integer_
  date <- rep(as.Date(NA), length(code))
  if (any(!vide)) {
    date[!vide] <- as.Date(sprintf("%d-01-01", annee[!vide])) + jour[!vide] - 1L
  }
  data.frame(annee = as.integer(annee), jour = jour, date = date)
}

#' Encode a date as a SUFOSAT `YYDDD` code
#'
#' Inverse of [reconfort_coupe_decoder()].
#'
#' @param date A `Date` vector (years 2000 to 2099).
#' @return A numeric vector of `YYDDD` codes (`NA` for `NA`).
#' @export
#' @examples
#' reconfort_coupe_encoder(as.Date("2021-05-30"))
reconfort_coupe_encoder <- function(date) {
  if (!inherits(date, "Date")) cli::cli_abort("{.arg date} must be a Date.")
  y <- as.integer(format(date, "%Y"))
  if (any(y < 2000L | y > 2099L, na.rm = TRUE)) {
    cli::cli_abort("{.arg date} must be in 2000-2099.")
  }
  (y - 2000L) * 1000 + as.integer(format(date, "%j"))
}

#' Remove pixels outside the oak stands or clear-cut
#'
#' Applies the two RECONFORT training masks to a table of pixels (or plots)
#' located by coordinates:
#' * **oak stand**: a pixel outside the layer `chenaie` is removed (the layer is
#'   supplied by the caller, in practice BD Foret v2);
#' * **clear-cut**: a pixel whose SUFOSAT date (`YYDDD`) falls in year `C` is
#'   removed for every observation year `annee >= C` (kept for the years before
#'   the cut; the cut year is excluded because the series is then already
#'   disturbed).
#'
#' @param pixels A `data.frame` with `x`, `y` and `annee` (observation year).
#' @param chenaie `NULL` (no oak mask), a [terra::SpatRaster] (cells with a
#'   non-zero, non-`NA` value are oak stand) or an `sf` polygon layer.
#' @param coupes `NULL` (no clear-cut mask), a [terra::SpatRaster] holding
#'   `YYDDD` codes, or an `sf` layer with a `date_coupe` column (`YYDDD`) of
#'   polygons (several cuts on a pixel: the earliest counts).
#' @param crs Coordinate reference system of `x`/`y` (anything accepted by
#'   [terra::crs()]); masks are reprojected to it when it differs.
#' @return `pixels` without the removed rows, with the attribute `retires`
#'   (a data.frame of the removed rows and their `motif`: `"hors_chenaie"` or
#'   `"coupe_rase"`).
#' @export
#' @examples
#' px <- data.frame(x = 1, y = 1, annee = c(2020L, 2021L))
#' coupes <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2,
#'                       crs = "EPSG:2154", vals = 21150)
#' reconfort_masquer(px, coupes = coupes, crs = "EPSG:2154")
reconfort_masquer <- function(pixels, chenaie = NULL, coupes = NULL, crs = "EPSG:2154") {
  if (!is.data.frame(pixels) || !all(c("x", "y", "annee") %in% names(pixels))) {
    cli::cli_abort("{.arg pixels} must be a data.frame with columns {.field x}, {.field y}, {.field annee}.")
  }
  n <- nrow(pixels)
  motif <- rep(NA_character_, n)
  if (!n) {
    attr(pixels, "retires") <- cbind(pixels, motif = character())
    return(pixels)
  }
  pts <- terra::vect(cbind(pixels$x, pixels$y), type = "points", crs = crs)

  if (!is.null(chenaie)) {
    dans <- .reconfort_valeur_masque(pts, chenaie, "chenaie")
    dans <- if (inherits(chenaie, "SpatRaster")) !is.na(dans) & dans != 0 else !is.na(dans)
    motif[!dans & is.na(motif)] <- "hors_chenaie"
  }
  if (!is.null(coupes)) {
    code <- .reconfort_valeur_masque(pts, coupes, "coupes")
    an_coupe <- reconfort_coupe_decoder(as.numeric(code))$annee
    coupe <- !is.na(an_coupe) & pixels$annee >= an_coupe
    motif[coupe & is.na(motif)] <- "coupe_rase"
  }
  retire <- !is.na(motif)
  out <- pixels[!retire, , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "retires") <- cbind(pixels[retire, , drop = FALSE], motif = motif[retire])
  out
}

# Valeur du masque sous chaque point. Raster : valeur de la cellule ; couche sf :
# `date_coupe` (la plus ancienne) pour `coupes`, sinon 1 si le point est dans un
# polygone et NA sinon.
.reconfort_valeur_masque <- function(pts, masque, nom) {
  if (inherits(masque, "SpatRaster")) {
    if (!terra::same.crs(masque, pts)) pts <- terra::project(pts, terra::crs(masque))
    return(terra::extract(masque, pts)[[2]])
  }
  if (!inherits(masque, "sf")) {
    cli::cli_abort("{.arg {nom}} must be a SpatRaster or an sf polygon layer.")
  }
  v <- terra::vect(masque)
  if (!terra::same.crs(v, pts)) pts <- terra::project(pts, terra::crs(v))
  ex <- terra::relate(pts, v, "within", pairs = TRUE)
  res <- rep(NA_real_, length(pts))
  if (nom == "coupes") {
    if (!"date_coupe" %in% names(masque)) {
      cli::cli_abort("The clear-cut layer needs a {.field date_coupe} column (YYDDD).")
    }
    codes <- as.numeric(masque$date_coupe)
    if (nrow(ex)) {
      # plus ancienne coupe = plus petit code (annee puis jour)
      agg <- tapply(codes[ex[, 2]], ex[, 1], function(z) {
        z <- z[!is.na(z) & z > 0]
        if (length(z)) min(z) else NA_real_
      })
      res[as.integer(names(agg))] <- as.numeric(agg)
    }
  } else if (nrow(ex)) {
    res[unique(ex[, 1])] <- 1
  }
  res
}
