# reconfort_sen2cor.R - RECONFORT sur reflectances Sen2Cor (mission 095)
# ---------------------------------------------------------------------------
# Troisieme voie d'acquisition de `run_reconfort_dieback()` :
# `acquisition = "sen2cor"`. Sans IOTA2, sans THEIA, sans GEODES, sans conda :
# les scenes Sentinel-2 L2A (Sen2Cor) de Planetary Computer sont lues par le
# cache de FAST/FORDEAD (`.get_s2_band_raster()`), mises sur une grille de
# 10 m, interpolees sur 67 dates, transformees en CRswir et CRre (134
# caracteristiques), puis classees par le modele v3 lu par
# `reconfort_sharkrf_lire()`.
#
# STATUT : INDICATIF, NON VALIDE. Le modele v3 a ete entraine sur des
# reflectances MAJA (THEIA). L'etude 093 de nemetonplateforme mesure, avec des
# reflectances Sen2Cor, ~24 % de pixels qui changent de classe (surtout vers la
# classe 3). Toutes les sorties le disent (`run_meta.json`, tags GeoTIFF).

.RECONFORT_SEN2COR_MENTION <- "RECONFORT sur Sen2Cor, non valid\u00e9, indicatif"

# Bandes lues, dans l'ordre des couches des scenes preparees.
.RECONFORT_SEN2COR_BANDES <- c("B04", "B05", "B06", "B8A", "B11", "B12")

# Biais moyens Sen2Cor - MAJA par date (etude 092 de nemetonplateforme, 12 dates
# de Couchey, T31TFN, forets de feuillus) : AJUSTES SUR UN SEUL SITE. Utilises
# seulement avec `correction_sen2cor = "biais"` (jamais par defaut).
.RECONFORT_SEN2COR_BIAIS <- c(CRswir = 0.011215741943559105,
                              CRre   = 0.025805809194198708)

# Ordre de repli des voies d'acquisition. UNE seule fonction decide de la voie
# suivante apres un echec ; le repli fenetre -> archive sur indisponibilite
# THEIA est l'objet de la mission 089 (il s'y raccorde en retournant TRUE
# ci-dessous). Isole pour les tests.
.reconfort_repli_fenetre_archive <- function() TRUE

# Voie suivante apres l'echec (ou l'indisponibilite) de `voie`, ou NA quand il
# n'y en a pas. Les causes d'echec par voie sont tenues par l'appelant
# (`causes_voies`) et passees a `.reconfort_avertir_repli_sen2cor()`.
.reconfort_voie_suivante <- function(voie) {
  if (identical(voie, "fenetre")) {
    return(if (isTRUE(.reconfort_repli_fenetre_archive())) "archive" else NA_character_)
  }
  if (identical(voie, "archive")) return("sen2cor")
  NA_character_
}

# Avertissement de repli THEIA -> GEODES (mission 089), classe
# `nemeton_reconfort_repli_archive`.
.reconfort_avertir_repli_archive <- function(cause) {
  cli::cli_warn(
    "catalogue THEIA indisponible ({cause}) : passage par les archives GEODES (~2 Go par sc\u00e8ne)",
    class = "nemeton_reconfort_repli_archive")
}

# Avertissement de repli, classe `nemeton_reconfort_repli_sen2cor`, qui dit les
# deux causes (fenetre/THEIA, archive/GEODES).
.reconfort_avertir_repli_sen2cor <- function(causes) {
  cf <- causes[["fenetre"]] %||% "not tried"
  ca <- causes[["archive"]] %||% "not tried"
  cli::cli_warn(c(
    "No THEIA or GEODES route is available: falling back to Sen2Cor reflectances (Planetary Computer).",
    x = "Window route (THEIA): {cf}",
    x = "Archive route (GEODES): {ca}",
    i = "The v3 model was trained on MAJA reflectances: this map is indicative and NOT validated (about 24 % of pixels change class on the test site)."),
    class = "nemeton_reconfort_repli_sen2cor")
}

# --- Grille de dates ---------------------------------------------------------

# Grille de dates du modele : pas de 10 jours depuis le 1er janvier de
# `s2_year - 1`, jusqu'a la fin de fenetre `edate` du modele (etude 091, section
# 7.1 : 67 dates, 20240101 ... 20251022 pour s2_year = 2025).
.reconfort_dates_grille <- function(s2_year, v_model = "v3", pas = 10L) {
  info <- reconfort_model_info(v_model)
  debut <- as.Date(sprintf("%d-01-01", as.integer(s2_year) - 1L))
  fin <- as.Date(sprintf("%d-%s", as.integer(s2_year), info$edate))
  seq(debut, fin, by = pas)
}

# --- Caracteristiques --------------------------------------------------------

#' RECONFORT v3 feature stack (CRswir then CRre over a date grid)
#'
#' Builds, for each pixel, the model's feature vector: the bands B4, B5, B6,
#' B8A, B11 and B12 are linearly interpolated in time over `dates_grille` from
#' the valid observations, then CRswir and CRre are computed from the
#' interpolated bands (the index is computed AFTER the gap-filling, as in the
#' upstream iota2 external features). The columns are `CRswir_1..n` then
#' `CRre_1..n` (134 columns for the 67-date grid of the v3 model).
#'
#' Edge rule (`bord`): `"constant"` (default, the rule validated in the 093
#' study) extends the first/last valid observation before/after it; `"na"` gives
#' `NA` for grid dates outside the observed range. A pixel with fewer than
#' `min_obs` valid dates gets `NA` everywhere (not predictable). Two
#' observations on the same day: the later one in `dates_obs` order wins.
#'
#' @param obs Named list of six numeric matrices `B4`, `B5`, `B6`, `B8A`,
#'   `B11`, `B12` (reflectance, 0-1), one row per pixel and one column per
#'   observation; `NA` marks an invalid (cloud, no-data) value. An observation
#'   is valid for a pixel only when the six bands are valid.
#' @param dates_obs `Date` vector, one per observation column (any order).
#' @param dates_grille `Date` vector of the target grid (see the 10-day rule of
#'   the v3 model).
#' @param bord `"constant"` or `"na"`.
#' @param min_obs Minimum number of valid observations (default 2).
#' @param correction `"aucune"` (default) or `"biais"`: subtract the mean
#'   Sen2Cor - MAJA biases of study 092 (CRswir 0.0112, CRre 0.0258), fitted on
#'   a single site (Couchey); use only to mimic MAJA reflectances.
#' @return A numeric matrix, one row per pixel, `2 * length(dates_grille)`
#'   columns.
#' @export
#' @examples
#' d <- as.Date("2024-01-01") + c(0, 40)
#' o <- lapply(c(B4 = .05, B5 = .08, B6 = .2, B8A = .4, B11 = .25, B12 = .15),
#'             function(v) matrix(c(v, v), 1))
#' dim(reconfort_caracteristiques_v3(o, d, as.Date("2024-01-01") + seq(0, 40, 10)))
reconfort_caracteristiques_v3 <- function(obs, dates_obs, dates_grille,
                                          bord = c("constant", "na"),
                                          min_obs = 2L,
                                          correction = c("aucune", "biais")) {
  bord <- match.arg(bord)
  correction <- match.arg(correction)
  bandes <- c("B4", "B5", "B6", "B8A", "B11", "B12")
  if (!is.list(obs) || !all(bandes %in% names(obs))) {
    cli::cli_abort("{.arg obs} must be a list with the matrices {.val {bandes}}.")
  }
  obs <- lapply(obs[bandes], as.matrix)
  n <- nrow(obs$B4)
  J <- ncol(obs$B4)
  if (any(vapply(obs, function(m) nrow(m) != n || ncol(m) != J, NA)) ||
      length(dates_obs) != J) {
    cli::cli_abort("All band matrices must be pixels x observations, with one date per column.")
  }
  G <- length(dates_grille)
  # Observations triees par date ; a date egale, la derniere gagne.
  o <- order(as.numeric(dates_obs))
  dobs <- as.numeric(dates_obs)[o]
  dg <- as.numeric(dates_grille)
  valide <- matrix(TRUE, n, J)
  for (b in bandes) valide <- valide & !is.na(obs[[b]][, o, drop = FALSE])
  nobs <- rowSums(valide)

  # Balayage avant : derniere observation valide <= date de grille ; balayage
  # arriere : premiere >= date de grille (0 = aucune).
  prec <- suiv <- matrix(0L, n, G)
  cur <- integer(n)
  for (j in seq_len(J)) {
    v <- valide[, j]
    cur[v] <- j
    # Dates de grille entre l'observation j (incluse) et la suivante.
    fin_j <- if (j < J) dobs[j + 1L] else Inf
    g <- which(dg >= dobs[j] & dg < fin_j)
    for (gi in g) prec[, gi] <- cur
  }
  cur <- integer(n)
  for (j in rev(seq_len(J))) {
    v <- valide[, j]
    cur[v] <- j
    deb_j <- if (j > 1L) dobs[j - 1L] else -Inf
    g <- which(dg <= dobs[j] & dg > deb_j)
    for (gi in g) suiv[, gi] <- cur
  }
  # Grille avant la premiere observation : precedent = 0 ; suivant deja pose
  # par le balayage arriere (j = 1 couvre dg <= dobs[1]).

  ligne <- seq_len(n)
  interp <- function(M) {
    M <- M[, o, drop = FALSE]
    out <- matrix(NA_real_, n, G)
    for (gi in seq_len(G)) {
      p <- prec[, gi]; s <- suiv[, gi]
      vp <- ifelse(p > 0L, M[cbind(ligne, pmax(p, 1L))], NA_real_)
      vs <- ifelse(s > 0L, M[cbind(ligne, pmax(s, 1L))], NA_real_)
      dp <- ifelse(p > 0L, dobs[pmax(p, 1L)], NA_real_)
      ds <- ifelse(s > 0L, dobs[pmax(s, 1L)], NA_real_)
      w <- ifelse(!is.na(dp) & !is.na(ds) & ds > dp, (dg[gi] - dp) / (ds - dp), 0)
      v <- ifelse(!is.na(vp) & !is.na(vs), vp + w * (vs - vp),
                  if (bord == "constant") ifelse(!is.na(vp), vp, vs) else NA_real_)
      out[, gi] <- v
    }
    out[nobs < min_obs, ] <- NA_real_
    out
  }
  I <- lapply(obs, interp)
  cr_swir <- matrix(.reconfort_cr_swir(as.vector(I$B8A), as.vector(I$B11),
                                       as.vector(I$B12)), n, G)
  cr_re <- matrix(.reconfort_cr_re(as.vector(I$B4), as.vector(I$B5),
                                   as.vector(I$B6)), n, G)
  if (identical(correction, "biais")) {
    cr_swir <- cr_swir - .RECONFORT_SEN2COR_BIAIS[["CRswir"]]
    cr_re <- cr_re - .RECONFORT_SEN2COR_BIAIS[["CRre"]]
  }
  X <- cbind(cr_swir, cr_re)
  colnames(X) <- c(paste0("CRswir_", seq_len(G)), paste0("CRre_", seq_len(G)))
  X
}

# --- Lecture des scenes Sen2Cor (cache FAST/FORDEAD) -------------------------

# Cherche les scenes Planetary Computer de la fenetre, comme FAST/FORDEAD :
# `stac_search_s2_pc()` puis `.dedup_s2_reprocessed()` (une seule ligne par prise
# de vue), restreintes aux tuiles demandees. Isole pour les tests.
.reconfort_sen2cor_chercher <- function(aoi, tiles, date_from, date_to) {
  bb <- sf::st_bbox(sf::st_transform(sf::st_geometry(aoi), 4326))
  sc <- stac_search_s2_pc(as.numeric(bb), date_from, date_to, max_cloud = 100)
  sc <- .dedup_s2_reprocessed(sc)
  if (nrow(sc) && length(tiles)) {
    t <- sub("^T", "", tiles)
    garde <- Reduce(`|`, lapply(t, function(x) grepl(paste0("_T", x, "_"), sc$scene_id)))
    sc <- sc[garde, , drop = FALSE]
  }
  sc[order(sc$obs_date), , drop = FALSE]
}

# Lit une scene (cache `.get_s2_band_raster()`, qui va chercher sur Planetary
# Computer ce qui manque), la met sur `grille` (10 m, plus proche voisin, comme
# la 091 et la 092) et ecrit un GeoTIFF INT16 de 6 couches (reflectance x 10000,
# offset BOA retire) ; NA partout ou une bande est absente ou ou la SCL n'est
# pas 4 ou 5 (vegetation, sol nu). Isole pour les tests.
.reconfort_sen2cor_scene_sur_grille <- function(scene, grille, aoi_sf, s2_cache_dir,
                                                dest, scl_ok = c(4L, 5L)) {
  lire <- function(band) {
    r <- .get_s2_band_raster(scene, band, aoi_sf, s2_cache_dir, emit = NULL)
    terra::project(r, grille, method = "near")
  }
  off <- .s2_boa_offset(scene$scene_id)
  if (is.na(off)) off <- 0
  couches <- lapply(.RECONFORT_SEN2COR_BANDES, function(b) {
    r <- lire(b)
    v <- terra::values(r, mat = FALSE)
    nod <- is.na(v) | v == 0
    v <- pmax(v + off, 0)
    v[nod] <- NA
    v
  })
  scl <- terra::values(lire("SCL"), mat = FALSE)
  ok <- !is.na(scl) & scl %in% scl_ok
  m <- vapply(couches, function(v) { v[!ok] <- NA; v }, numeric(terra::ncell(grille)))
  r <- terra::rast(grille, nlyrs = length(.RECONFORT_SEN2COR_BANDES))
  names(r) <- .RECONFORT_SEN2COR_BANDES
  terra::values(r) <- m
  terra::writeRaster(r, dest, overwrite = TRUE, datatype = "INT2S",
                     NAflag = -32768, gdal = c("COMPRESS=DEFLATE"))
  invisible(dest)
}

# Prepare toutes les scenes : une par date, dans `dossier`. Les scenes qui
# echouent sont ignorees avec un avertissement (une scene manquante ne doit pas
# perdre le run) ; echec total = erreur.
.reconfort_sen2cor_preparer <- function(aoi, tiles, date_from, date_to, grille,
                                        s2_cache_dir, dossier, quiet = FALSE) {
  sc <- .reconfort_sen2cor_chercher(aoi, tiles, date_from, date_to)
  if (!nrow(sc)) {
    cli::cli_abort(c("No Sentinel-2 L2A scene found on Planetary Computer for the window {date_from} to {date_to}.",
                     i = "Tiles: {.val {tiles}}."))
  }
  dir.create(dossier, recursive = TRUE, showWarnings = FALSE)
  ext <- terra::ext(grille)
  aoi_sf <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(
    c(xmin = terra::xmin(ext), xmax = terra::xmax(ext), ymin = terra::ymin(ext), ymax = terra::ymax(ext)), crs = sf::st_crs(2154))))
  chemins <- rep(NA_character_, nrow(sc))
  for (i in seq_len(nrow(sc))) {
    dest <- file.path(dossier, sprintf("%s_%s.tif", format(sc$obs_date[i], "%Y%m%d"),
                                       .s2_safe_scene_id(sc$scene_id[i])))
    ok <- tryCatch({
      .reconfort_sen2cor_scene_sur_grille(sc[i, , drop = FALSE], grille, aoi_sf,
                                          s2_cache_dir, dest)
      TRUE
    }, error = function(e) {
      cli::cli_warn("Sen2Cor scene {.val {sc$scene_id[i]}} skipped: {conditionMessage(e)}")
      FALSE
    })
    if (ok) chemins[i] <- dest
  }
  garde <- !is.na(chemins)
  if (!any(garde)) cli::cli_abort("No Sen2Cor scene could be read.")
  data.frame(date = sc$obs_date[garde], chemin = chemins[garde],
             scene_id = sc$scene_id[garde], stringsAsFactors = FALSE)
}

# --- Classification par blocs et ecriture -----------------------------------

# Applique le modele a la pile de scenes preparees, par blocs de lignes, sur les
# seuls pixels du masque (si fourni). Ecrit les memes fichiers que la voie
# IOTA2 dans `final_dir` et retourne la liste `rasters` de
# `.reconfort_collect_outputs()`.
.reconfort_sen2cor_classer <- function(scenes, modele, grille, masque_vals, s2_year,
                                       dates_grille, final_dir,
                                       correction = "aucune", bloc_px = 40000L,
                                       quiet = FALSE) {
  dir.create(final_dir, recursive = TRUE, showWarnings = FALSE)
  nc <- terra::ncol(grille); nr <- terra::nrow(grille)
  K <- length(modele$classes)
  rs <- lapply(scenes$chemin, terra::rast)
  for (r in rs) terra::readStart(r)
  on.exit(for (r in rs) try(terra::readStop(r), silent = TRUE), add = TRUE)
  lignes <- max(1L, as.integer(bloc_px %/% nc))
  votes <- array(0L, c(nr * nc, K))
  for (r0 in seq.int(1L, nr, by = lignes)) {
    nl <- min(lignes, nr - r0 + 1L)
    cel <- ((r0 - 1L) * nc + 1L):((r0 - 1L + nl) * nc)
    sel <- if (is.null(masque_vals)) rep(TRUE, length(cel)) else masque_vals[cel]
    if (!any(sel)) next
    vals <- lapply(rs, function(r) {
      terra::readValues(r, row = r0, nrows = nl, mat = TRUE)[sel, , drop = FALSE] / 10000
    })
    nsel <- sum(sel)
    obs <- lapply(seq_along(.RECONFORT_SEN2COR_BANDES), function(b) {
      matrix(vapply(vals, function(m) m[, b], numeric(nsel)), nrow = nsel)
    })
    names(obs) <- c("B4", "B5", "B6", "B8A", "B11", "B12")
    X <- reconfort_caracteristiques_v3(obs, scenes$date, dates_grille,
                                       correction = correction)
    v <- reconfort_sharkrf_predire(modele, X)
    v[v < 0L] <- 0L
    votes[cel[sel], ] <- v
    if (!quiet) cli::cli_alert_info("Sen2Cor classification: rows {r0}-{r0 + nl - 1L} of {nr}.")
  }
  .reconfort_sen2cor_ecrire(votes, grille, masque_vals, s2_year, final_dir,
                            classes = modele$classes)
}

# Ecrit classif / probabilite (votes en pour mille, somme 1000) / score continu,
# bruts puis masques. Noms et formats de la voie IOTA2.
.reconfort_sen2cor_ecrire <- function(votes, grille, masque_vals, s2_year, final_dir,
                                      classes = seq_len(ncol(votes))) {
  K <- ncol(votes)
  tot <- rowSums(votes)
  proba <- votes
  nz <- tot > 0L
  proba[nz, ] <- round(votes[nz, , drop = FALSE] * 1000 / tot[nz])
  cl <- ifelse(nz, classes[max.col(votes, ties.method = "first")], 0L)
  p3 <- if (K >= 3L) proba[, 3L] else 0
  score <- pmin(pmax(floor((1001 - proba[, 1L] + proba[, 2L] + 2 * p3) / 30), 1), 100)
  score[!nz] <- 0
  tags <- c(SOURCE_REFLECTANCES = "sen2cor", VALIDEE = "FALSE",
            MENTION = .RECONFORT_SEN2COR_MENTION)
  ecrire <- function(vals, nom, type, nlyr = 1L) {
    r <- terra::rast(grille, nlyrs = nlyr)
    terra::values(r) <- vals
    terra::metags(r) <- tags
    p <- file.path(final_dir, nom)
    terra::writeRaster(r, p, overwrite = TRUE, datatype = type,
                       gdal = c("COMPRESS=LZW"))
    normalizePath(p)
  }
  # Hors masque : 0 (la carte brute IOTA2 couvre toute l'image ; ici on ne
  # classe que le masque, hors masque = 0 dans les deux jeux de fichiers).
  y <- as.character(s2_year)
  list(
    final_dir          = final_dir,
    classif            = ecrire(cl, "Classif_Seed_0.tif", "INT1U"),
    classif_masked     = ecrire(cl, sprintf("Final_Classif_masked_%s.tif", y), "INT1U"),
    probability        = ecrire(proba, "ProbabilityMap_seed_0.tif", "INT2U", K),
    probability_masked = ecrire(proba, sprintf("Final_Proba_map_masked%s.tif", y), "INT2S", K),
    continuous_score   = ecrire(score, sprintf("Final_continuous_score_masked%s.tif", y), "INT2S")
  )
}

# Grille de travail 10 m (Lambert-93) de l'AOI + masque feuillus sur cette
# grille (vecteur logique, NULL = pas de masque).
.reconfort_sen2cor_grille <- function(aoi, mask_path) {
  win <- .reconfort_aoi_window(aoi, 2154, .RECONFORT_AOI_BUFFER_M)
  g <- terra::rast(terra::ext(win[["xmin"]], win[["xmax"]], win[["ymin"]], win[["ymax"]]),
                   resolution = 10, crs = "EPSG:2154")
  mv <- NULL
  if (!is.null(mask_path) && !is.na(mask_path)) {
    m <- terra::project(terra::rast(mask_path), g, method = "near")
    mv <- terra::values(m, mat = FALSE)
    mv <- !is.na(mv) & mv != 0
  }
  list(grille = g, masque = mv)
}

#' RECONFORT map from Sen2Cor reflectances (indicative, not validated)
#'
#' Applies the RECONFORT v3 random forest to Sentinel-2 L2A (Sen2Cor)
#' reflectances from Planetary Computer, without IOTA2, conda, THEIA or GEODES.
#' Scenes come through the FAST/FORDEAD band cache. The result is **indicative
#' and not validated**: the model was trained on MAJA reflectances, and on the
#' Couchey test site about 24 % of the pixels change class with Sen2Cor.
#' Normally called through `run_reconfort_dieback(acquisition = "sen2cor")`.
#'
#' @param aoi `sf` polygon of the zone.
#' @param modele Path to the SharkRF model file, or a `reconfort_sharkrf`.
#' @param s2_year Last year of the series.
#' @param final_dir Output directory (files named as the IOTA2 route).
#' @param mask_path Optional broadleaf mask raster (non-zero = classify).
#' @param tiles MGRS tiles to keep (e.g. `"T31TFN"`), `NULL` for all.
#' @param v_model Model version (analysis window).
#' @param s2_cache_dir Sentinel-2 band cache shared with FAST/FORDEAD.
#' @param work_dir Directory for the prepared scenes (removed afterwards).
#' @param correction `"aucune"` (default) or `"biais"`, see
#'   [reconfort_caracteristiques_v3()].
#' @param quiet Suppress progress messages.
#' @return The list of output rasters (same fields as the IOTA2 route).
#' @keywords internal
#' @noRd
.reconfort_carte_sen2cor <- function(aoi, modele, s2_year, final_dir,
                                     mask_path = NULL, tiles = NULL,
                                     v_model = "v3", s2_cache_dir, work_dir,
                                     correction = "aucune", quiet = FALSE) {
  if (is.character(modele)) modele <- reconfort_sharkrf_lire(modele)
  dates_grille <- .reconfort_dates_grille(s2_year, v_model)
  if (length(dates_grille) * 2L != modele$n_vars) {
    cli::cli_abort("The date grid gives {2L * length(dates_grille)} features, the model expects {modele$n_vars}.")
  }
  gm <- .reconfort_sen2cor_grille(aoi, mask_path)
  date_from <- format(dates_grille[[1L]], "%Y-%m-%d")
  date_to <- sprintf("%d-%s", as.integer(s2_year), reconfort_model_info(v_model)$edate)
  scenes <- .reconfort_sen2cor_preparer(aoi, tiles, date_from, date_to, gm$grille,
                                        s2_cache_dir, file.path(work_dir, "scenes"),
                                        quiet = quiet)
  on.exit(unlink(file.path(work_dir, "scenes"), recursive = TRUE), add = TRUE)
  .reconfort_sen2cor_classer(scenes, modele, gm$grille, gm$masque, s2_year,
                             dates_grille, final_dir, correction = correction,
                             quiet = quiet)
}

# Cache Sentinel-2 par defaut de la voie Sen2Cor : celui de FAST/FORDEAD
# (`<projet>/cache/layers/sentinel2`) quand `cache_dir` est le dossier `cache`
# du projet ou le contient deja ; sinon un cache a part `<cache_dir>/s2_bands`.
.reconfort_s2_cache_defaut <- function(cache_dir) {
  fast <- file.path(cache_dir, "layers", "sentinel2")
  if (identical(basename(normalizePath(cache_dir, mustWork = FALSE)), "cache") ||
      dir.exists(fast)) {
    return(fast)
  }
  file.path(cache_dir, "s2_bands")
}
