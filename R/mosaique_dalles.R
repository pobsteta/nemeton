# Mosaique virtuelle de dalles (mission 082).
#
# terra::vrt() sur une liste de fichiers abandonne en silence toute dalle dont
# l'ecriture du SRS differe de celle de la premiere (GDAL compare l'ecriture,
# pas le sens : « RGF93 v1 / Lambert-93 » contre « EPSG:2154 »). La mosaique
# ne couvre alors qu'une dalle, sans erreur. Ce helper unique remplace tous
# les appels `terra::vrt(fichiers)` du coeur.


# Ecriture normalisee d'une definition de SRS, pour comparer le sens et non le
# nom : chaine PROJ, sans le `+towgs84` nul (RGF93 = ETRS89 = WGS84 a 0 pres).
.srs_normalise <- function(crs_wkt) {
  if (is.na(crs_wkt) || !nzchar(crs_wkt)) return(NA_character_)
  p <- terra::crs(crs_wkt, proj = TRUE)
  if (!nzchar(p)) return(NA_character_)
  p <- gsub("\\+towgs84=0(,0){6}\\s*", "", p)
  trimws(gsub("\\s+", " ", p))
}

# La transformation de quelques points du SRS `a` vers le SRS `b` est-elle
# l'identite (1 mm pres) ? Deux ecritures d'un meme systeme ne deplacent aucun
# point, meme quand leurs definitions PROJ different par le nom de l'ellipsoide
# (« EPSG:2154 » des dalles IGN : WGS84 sans datum nomme ; WKT complet : GRS80).
# `pts` : matrice (x, y) en coordonnees de `a` (coins de l'emprise d'une dalle).
.srs_transformation_identite <- function(a, b, pts) {
  if (is.null(pts) || !NROW(pts)) return(FALSE)
  pts <- as.matrix(pts)
  res <- tryCatch({
    v <- terra::vect(pts, type = "points", crs = a)
    w <- terra::crds(terra::project(v, b))
    tol <- if (isTRUE(terra::is.lonlat(a))) 1e-8 else 1e-3
    all(is.finite(w)) && all(abs(w - pts) <= tol)
  }, error = function(e) FALSE)
  isTRUE(res)
}

# Coins de l'emprise d'un raster (matrice x, y), dans son propre SRS.
.srs_points_emprise <- function(fichier) {
  e <- terra::ext(terra::rast(fichier))
  cbind(x = c(e$xmin, e$xmax, e$xmin, e$xmax),
        y = c(e$ymin, e$ymin, e$ymax, e$ymax))
}

# Deux SRS (WKT) ont-ils le meme sens ? Vrai si terra les juge identiques, si
# leurs definitions PROJ normalisees coincident, ou si la transformation des
# points `pts` (coordonnees de `a`) de `a` vers `b` est l'identite a 1 mm pres ;
# deux SRS absents sont equivalents, un SRS absent face a un SRS present ne
# l'est pas.
.srs_deux_equivalents <- function(a, b, pts = NULL) {
  a_vide <- is.na(a) || !nzchar(a)
  b_vide <- is.na(b) || !nzchar(b)
  if (a_vide || b_vide) return(a_vide && b_vide)
  if (isTRUE(terra::same.crs(a, b))) return(TRUE)
  na <- .srs_normalise(a)
  nb <- .srs_normalise(b)
  if (!is.na(na) && !is.na(nb) && identical(na, nb)) return(TRUE)
  .srs_transformation_identite(a, b, pts)
}

# Pour chaque fichier, son SRS a-t-il le meme sens que celui du premier ?
# (vecteur logique nomme par fichier ; predicat reutilise par les appelants
# qui veulent decider eux-memes quoi faire d'un SRS different.) Les points de
# l'epreuve d'identite sont les coins de l'emprise de chaque fichier, exprimes
# dans son propre SRS.
.srs_equivalents <- function(fichiers) {
  srs <- vapply(fichiers, function(f) {
    tryCatch(terra::crs(terra::rast(f)),
             error = function(e) {
               cli::cli_abort("Cannot read the CRS of tile {.path {f}}.", parent = e)
             })
  }, character(1))
  ok <- vapply(seq_along(fichiers), function(i) {
    if (i == 1L) return(TRUE)
    # SRS du fichier i vers celui du premier, sur l'emprise du fichier i.
    .srs_deux_equivalents(srs[[i]], srs[[1L]], .srs_points_emprise(fichiers[[i]]))
  }, logical(1))
  names(ok) <- names(srs)
  ok
}

# Nombre de fichiers sources distincts effectivement retenus par un VRT.
.vrt_sources_utilisees <- function(vrt_path) {
  x <- readLines(vrt_path, warn = FALSE)
  m <- regmatches(x, regexpr("(?<=<SourceFilename)[^>]*>[^<]+", x, perl = TRUE))
  length(unique(sub("^[^>]*>", "", m)))
}

#' Build a virtual mosaic of tiles with a coherent coordinate system
#'
#' Single entry point for every `terra::vrt()` on a list of tiles. Tiles whose
#' CRS is the same under two spellings are all kept (GDAL option
#' `-allow_projection_difference`); a tile with a really different CRS is an
#' error naming it (no implicit reprojection); a mosaic that does not use
#' every given file is an error, never a silent warning.
#'
#' @param fichiers Character vector of raster files (or GDAL paths).
#' @param filename Optional path of the `.vrt` to write (temporary by default).
#' @param options Extra `gdalbuildvrt` options (character vector).
#' @return A `SpatRaster`.
#' @noRd
.mosaique_dalles <- function(fichiers, filename = NULL, options = character()) {
  fichiers <- as.character(fichiers)
  if (!length(fichiers)) {
    cli::cli_abort("No tile given to build a mosaic.")
  }
  options <- as.character(options)
  sortie <- if (is.null(filename)) tempfile("mosaique_", fileext = ".vrt") else filename

  # Un seul fichier : comportement inchange de terra::vrt().
  if (length(fichiers) == 1L) {
    return(terra::vrt(fichiers, filename = if (is.null(filename)) "" else filename,
                      options = if (length(options)) options else NULL,
                      overwrite = TRUE))
  }

  # Chemins locaux rendus absolus ; les chemins GDAL (/vsi..., URL) restent tels quels.
  existe <- file.exists(fichiers)
  fichiers[existe] <- normalizePath(fichiers[existe], winslash = "/", mustWork = FALSE)

  ok <- .srs_equivalents(fichiers)
  if (!all(ok)) {
    autres <- fichiers[!ok]
    cli::cli_abort(c(
      "Tiles do not share one coordinate system: {length(autres)} of {length(fichiers)} differ from the first tile {.path {basename(fichiers[[1L]])}}.",
      x = "Different CRS: {.path {basename(autres)}}.",
      i = "No implicit reprojection; reproject these tiles first."
    ), class = "nemeton_mosaique_srs")
  }

  opts <- c("-allow_projection_difference", options)
  sf::gdal_utils("buildvrt", source = fichiers, destination = sortie,
                 options = opts, quiet = TRUE)

  utilises <- .vrt_sources_utilisees(sortie)
  attendus <- length(unique(fichiers))
  if (utilises != attendus) {
    cli::cli_abort(c(
      "The mosaic uses {utilises} of {attendus} tile{?s}.",
      i = "Mosaic file: {.path {sortie}}."
    ), class = "nemeton_mosaique_sources")
  }
  terra::rast(sortie)
}
