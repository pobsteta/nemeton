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

# Lecture deterministe d'un SRS projete : methode et parametres numeriques
# (chaine PROJ), ellipsoide (WKT : demi-grand axe, aplatissement inverse),
# unites, +towgs84. Independante de la version de PROJ pour les operations de
# transformation ; NULL si la definition n'est pas lisible.
.srs_parametres <- function(crs_wkt) {
  p <- tryCatch(terra::crs(crs_wkt, proj = TRUE), error = function(e) "")
  if (is.na(p) || !nzchar(p)) return(NULL)
  jetons <- strsplit(trimws(p), "\\s+")[[1L]]
  jetons <- sub("^\\+", "", jetons)
  kv <- strsplit(jetons, "=", fixed = TRUE)
  cle <- vapply(kv, `[`, character(1), 1L)
  val <- vapply(kv, function(x) if (length(x) > 1L) x[[2L]] else "", character(1))
  names(val) <- cle
  if (!"proj" %in% cle) return(NULL)
  ell <- regmatches(crs_wkt, regexec(
    "(?:ELLIPSOID|SPHEROID)\\[\\s*\"[^\"]*\"\\s*,\\s*([-0-9.eE+]+)\\s*,\\s*([-0-9.eE+]+)",
    crs_wkt, perl = TRUE))[[1L]]
  if (length(ell) < 3L) return(NULL)
  num <- c("lat_0", "lon_0", "lat_1", "lat_2", "lat_ts", "x_0", "y_0", "k", "k_0",
           "alpha", "gamma", "lonc", "zone")
  par <- suppressWarnings(as.numeric(val[names(val) %in% num]))
  names(par) <- names(val)[names(val) %in% num]
  names(par)[names(par) == "k_0"] <- "k"
  tw <- if ("towgs84" %in% cle) suppressWarnings(as.numeric(strsplit(val[["towgs84"]], ",")[[1L]])) else numeric()
  autres <- val[!names(val) %in% c(num, "ellps", "datum", "towgs84", "no_defs", "type", "proj",
                                    "a", "b", "rf", "f", "R", "units")]
  list(proj = val[["proj"]], par = par,
       units = if ("units" %in% cle) val[["units"]] else "m",
       a = as.numeric(ell[[2L]]), invf = as.numeric(ell[[3L]]),
       towgs84 = if (length(tw) && any(is.na(tw) | tw != 0)) tw else numeric(),
       autres = autres[order(names(autres))])
}

# Meme sens, sans PROJ : meme methode et memes parametres (1e-9), ellipsoides de
# meme demi-grand axe (1e-3 m) et d'aplatissement inverse a 1e-6 relatif pres
# (GRS80 et WGS84 : 0,1 mm sur le demi-petit axe, physiquement equivalents), pas
# de +towgs84 non nul, memes unites.
.srs_memes_parametres <- function(a, b) {
  pa <- .srs_parametres(a)
  pb <- .srs_parametres(b)
  if (is.null(pa) || is.null(pb)) return(FALSE)
  if (!identical(pa$proj, pb$proj) || !identical(pa$units, pb$units)) return(FALSE)
  defaut <- c(x_0 = 0, y_0 = 0, k = 1)
  cles <- union(names(pa$par), names(pb$par))
  for (k in cles) {
    va <- if (k %in% names(pa$par)) pa$par[[k]] else unname(defaut[k])
    vb <- if (k %in% names(pb$par)) pb$par[[k]] else unname(defaut[k])
    if (is.na(va) || is.na(vb) || abs(va - vb) > 1e-9) return(FALSE)
  }
  if (!identical(pa$autres, pb$autres)) return(FALSE)
  if (abs(pa$a - pb$a) > 1e-3) return(FALSE)
  if (abs(pa$invf - pb$invf) > 1e-6 * max(abs(pa$invf), abs(pb$invf), 1)) return(FALSE)
  # un +towgs84 non nul d'un seul cote, ou different : pas le meme systeme
  identical(pa$towgs84, pb$towgs84)
}

# Deux SRS (WKT) ont-ils le meme sens ? Vrai si terra les juge identiques, si
# leurs definitions PROJ normalisees coincident, si la transformation des
# points `pts` (coordonnees de `a`) de `a` vers `b` est l'identite a 1 mm pres,
# ou si leurs parametres de projection et ellipsoides concordent (critere
# deterministe, independant de la version de PROJ) ; deux SRS absents sont
# equivalents, un SRS absent face a un SRS present ne l'est pas.
.srs_deux_equivalents <- function(a, b, pts = NULL) {
  a_vide <- is.na(a) || !nzchar(a)
  b_vide <- is.na(b) || !nzchar(b)
  if (a_vide || b_vide) return(a_vide && b_vide)
  if (isTRUE(tryCatch(terra::same.crs(a, b), error = function(e) FALSE))) return(TRUE)
  na <- .srs_normalise(a)
  nb <- .srs_normalise(b)
  if (!is.na(na) && !is.na(nb) && identical(na, nb)) return(TRUE)
  if (.srs_transformation_identite(a, b, pts)) return(TRUE)
  isTRUE(tryCatch(.srs_memes_parametres(a, b), error = function(e) FALSE))
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
