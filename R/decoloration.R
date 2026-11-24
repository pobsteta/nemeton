# Détection de la décoloration anormale du feuillage (mission 046)
#
# Portage de la partie « détection » du suivi régional de décoloration
# (méthode §§ 3 à 8) : indices spectraux Sentinel-2 à 20 m, composites
# mensuels, anomalie par pixel (avec normale de repli tirée des pixels
# voisins), ICD par essence, alerte et niveaux 0 à 4.
# Hors périmètre : coupes, volumes, risque, coupes partielles, IFN.

.DECOL_INDICES <- c("GRVI", "CIRE", "CRSWIR", "CRRE", "NDVI")
# +1 : l'indice baisse avec la décoloration ; -1 : il monte
.DECOL_SENS <- c(GRVI = 1, CIRE = 1, CRSWIR = -1, CRRE = -1, NDVI = 1)
.DECOL_PLANCHER <- c(GRVI = 0.01, CIRE = 0.05, CRSWIR = 0.02, CRRE = 0.01,
                     NDVI = 0.01)
.DECOL_ECHELLE <- c(GRVI = 1e-4, CIRE = 1e-3, CRSWIR = 1e-4, CRRE = 1e-4,
                    NDVI = 1e-4)
.DECOL_BANDES <- c("B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B11",
                   "B12")
.DECOL_SCL_MASQUE <- c(0, 1, 3, 8, 9, 10, 11)
.DECOL_MOIS <- 4:10
.DECOL_TAILLE_PIXEL <- 20

# Essences, poids de l'ICD (somme = 1) et mois suivis (méthode § 3 et § 7)
.decol_essences <- function() {
  data.frame(
    ess_id   = 1:4,
    essence  = c("chene", "hetre", "sapin_epicea", "douglas"),
    code_tfv = c("FF1G01-01", "FF1-09-09", "FF2G61-61", "FF2-64-64"),
    w_GRVI   = c(0.15, 0.30, 0.35, 0.45),
    w_CIRE   = c(0.25, 0.25, 0.15, 0.15),
    w_CRSWIR = c(0.15, 0.15, 0.35, 0.25),
    w_CRRE   = c(0.20, 0.15, 0.00, 0.00),  # feuillus seulement
    w_NDVI   = c(0.25, 0.15, 0.15, 0.15),
    stringsAsFactors = FALSE
  )
}

.decol_mois_essence <- function() {
  list(chene = 6:8, hetre = 7:8, sapin_epicea = 6:10, douglas = 4:9)
}

# Temps en mois absolus (pour comparer une date de coupe à un mois)
.decol_t_mois <- function(annee, mois) as.integer(annee) * 12L + (as.integer(mois) - 1L)

# ---------------------------------------------------------------------------
# 1. Indices spectraux (§ 4)
# ---------------------------------------------------------------------------

# `b` : liste nommée de bandes (réflectance ou compte numérique, offset déjà
# retiré) ; fonctionne sur des vecteurs comme sur des SpatRaster.
.decol_indices <- function(b) {
  k  <- (1613.7 - 864.7) / (2202.4 - 864.7)  # B11 entre B8A et B12
  kr <- (704 - 665) / (741 - 665)            # B05 entre B04 et B06
  list(
    GRVI   = (b$B03 - b$B04) / (b$B03 + b$B04),
    CIRE   = b$B07 / b$B05 - 1,
    CRSWIR = b$B11 / (b$B8A + (b$B12 - b$B8A) * k),
    CRRE   = b$B05 / (b$B04 + (b$B06 - b$B04) * kr),
    NDVI   = (b$B08 - b$B04) / (b$B08 + b$B04)
  )
}

# Indices d'une scène sur la grille `g` (SpatRaster 20 m) ; `lire(bande, methode)`
# renvoie la bande rééchantillonnée sur `g`. NULL si tout est masqué.
.decol_indices_scene <- function(lire, scene_id) {
  scl <- lire("SCL", "near")
  # pas de `%in%` sur un SpatRaster (opérateur S4 non répartissé) : égalités
  masque <- Reduce(`|`, lapply(.DECOL_SCL_MASQUE, function(k) scl == k))
  ok <- !(is.na(scl) | masque)
  if (!any(terra::values(ok), na.rm = TRUE)) return(NULL)
  b <- lapply(stats::setNames(.DECOL_BANDES, .DECOL_BANDES), function(nm) {
    r <- lire(nm, "bilinear")
    terra::ifel(r + .s2_boa_offset(scene_id) > 0,
                r + .s2_boa_offset(scene_id), NA)
  })
  idx <- .decol_indices(b)
  idx <- terra::rast(idx)
  names(idx) <- .DECOL_INDICES
  terra::mask(idx, ok, maskvalues = FALSE)
}

# ---------------------------------------------------------------------------
# 2. Composite mensuel (§ 5)
# ---------------------------------------------------------------------------

# Médiane des valeurs valides, indice par indice ; liste de SpatRaster à 5 couches
.decol_mediane_scenes <- function(scenes, g) {
  if (!length(scenes)) {
    out <- terra::rast(g, nlyrs = length(.DECOL_INDICES))
    terra::values(out) <- NA_real_
  } else {
    out <- terra::rast(lapply(.DECOL_INDICES, function(i) {
      terra::app(terra::rast(lapply(scenes, function(s) s[[i]])),
                 "median", na.rm = TRUE)
    }))
  }
  names(out) <- .DECOL_INDICES
  out <- terra::ifel(is.finite(out), out, NA)
  lim <- list(GRVI = c(-1, 1), NDVI = c(-1, 1), CIRE = c(-1, 15),
              CRSWIR = c(0, 3), CRRE = c(0, 3))
  for (i in names(lim)) {
    out[[i]] <- terra::clamp(out[[i]], lim[[i]][1], lim[[i]][2], values = FALSE)
  }
  out
}

# Empreinte de la grille (étendue, résolution, CRS) : les composites sont
# rangés par grille, jamais relus pour une autre emprise.
.decol_empreinte_grille <- function(g) {
  e <- as.vector(terra::ext(g))
  sprintf("g_%.0f_%.0f_%.0f_%.0f_r%.0f_%s", e[["xmin"]], e[["ymin"]], e[["xmax"]],
          e[["ymax"]], terra::res(g)[1], gsub("[^A-Za-z0-9]", "", terra::crs(g, describe = TRUE)$code %||% "x"))
}

.decol_composite_chemin <- function(cache_dir, annee, mois, g) {
  file.path(cache_dir, "decoloration", "composites", .decol_empreinte_grille(g),
            sprintf("s2_%d_%02d.tif", annee, mois))
}

# Écriture atomique : fichier temporaire, relu, puis renommé
.decol_composite_ecrire <- function(r, f) {
  dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  tmp <- sub("\\.tif$", ".part.tif", f)
  on.exit(unlink(tmp), add = TRUE)
  e <- .DECOL_ECHELLE[names(r)]
  terra::writeRaster(round(r / e), tmp, overwrite = TRUE, filetype = "GTiff",
                     datatype = "INT2S",
                     gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2"))
  ok <- isTRUE(tryCatch({
    t <- terra::rast(tmp)
    terra::global(t[[1]], "max", na.rm = TRUE)
    TRUE
  }, error = function(e) FALSE))
  if (!ok) cli::cli_abort("Composite {.path {f}} unreadable after writing.")
  if (!isTRUE(file.rename(tmp, f))) {
    cli::cli_abort("Cannot rename {.path {tmp}} to {.path {f}}.")
  }
  invisible(f)
}

# `g` : grille attendue ; erreur claire si le composite est sur une autre grille
.decol_composite_lire <- function(f, g = NULL) {
  r <- terra::rast(f)
  if (!is.null(g) &&
      (!isTRUE(all.equal(as.vector(terra::ext(r)), as.vector(terra::ext(g)))) ||
       !isTRUE(all.equal(terra::res(r), terra::res(g))))) {
    cli::cli_abort(c("Composite {.path {f}} is on a different grid than the requested one.",
                     i = "Delete it or use another {.arg dossier_cache}."))
  }
  if (identical(terra::datatype(r)[1], "INT2S")) r <- r * .DECOL_ECHELLE[names(r)]
  r
}

# Faut-il (re)faire le composite ? Un mois futur : non. Un mois pas fini
# depuis 5 jours : non (le composite provisoire existant est gardé tel quel).
# Un composite illisible : oui, il est supprimé.
.decol_composite_a_faire <- function(f, annee, mois, aujourdhui = Sys.Date()) {
  d0 <- as.Date(sprintf("%d-%02d-01", annee, mois))
  d1 <- seq(d0, by = "month", length.out = 2)[2] - 1
  if (d0 > aujourdhui) return(FALSE)
  if (file.exists(f)) {
    if (!.decol_composite_lisible_strict(f)) {
      unlink(f)
    } else if (as.Date(file.mtime(f)) > d1 + 5) {
      return(FALSE)
    }
  }
  if (aujourdhui <= d1 + 5) return(FALSE)
  TRUE
}

.decol_composite_lisible_strict <- function(f) {
  isTRUE(tryCatch({
    r <- terra::rast(f)
    terra::global(r[[1]], "max", na.rm = TRUE)
    all(.DECOL_INDICES %in% names(r))
  }, error = function(e) FALSE))
}

# Recherche STAC Planetary Computer des scènes du mois, toutes bandes utiles
# (B03, B06, B07 et SCL en plus des 7 bandes de FAST/FORDEAD).
.decol_chercher_scenes <- function(bbox4326, d0, d1, nuages_max = 70) {
  body <- list(
    collections = list("sentinel-2-l2a"),
    bbox        = as.numeric(bbox4326),
    datetime    = sprintf("%s/%s", d0, d1),
    limit       = .stac_page_size(),
    query       = list("eo:cloud_cover" = list(lt = as.numeric(nuages_max)))
  )
  feats <- .stac_search_paginate(
    "https://planetarycomputer.microsoft.com/api/stac/v1/search", body)
  if (!length(feats)) return(data.frame(scene_id = character(0)))
  token <- .pc_collection_token("sentinel-2-l2a")
  bandes <- c(.DECOL_BANDES, "SCL")
  rows <- lapply(feats, function(ft) {
    row <- list(scene_id = ft$id %||% NA_character_,
                obs_date = .parse_stac_datetime(ft$properties$datetime),
                cloud_pct = as.numeric(ft$properties$`eo:cloud_cover` %||% NA))
    for (b in bandes) {
      h <- ft$assets[[b]]$href %||% ""
      row[[paste0("href_", b)]] <- .pc_apply_token(h, token)
    }
    as.data.frame(row, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out <- out[!is.na(out$cloud_pct) & out$cloud_pct < nuages_max, , drop = FALSE]
  .dedup_s2_reprocessed(out)
}

# Lecture d'une bande par le lecteur fenêtré et le cache par bande de nemeton
# (même cache que FAST : `<cache>/sentinel2/<scène>/<bande>.tif`), puis
# rééchantillonnage sur la grille 20 m Lambert 93.
.decol_lire_bande <- function(scene, bande, g, emprise_sf, cache_dir, emit = NULL) {
  r <- NULL
  if (bande %in% c("B03", "B04", "B08")) {
    r <- .decol_lire_apercu(scene, bande, emprise_sf, cache_dir)
  }
  if (is.null(r)) {
    r <- .get_s2_band_raster(scene, bande, emprise_sf,
                             cache_dir = file.path(cache_dir, "sentinel2"),
                             emit = emit)
  }
  terra::project(r, g, method = if (bande == "SCL") "near" else "bilinear")
}

# Bandes à 10 m lues dans l'aperçu natif à 20 m inclus dans le COG (comme le
# script régional : OVERVIEW_LEVEL=0, 4 fois moins de données) ; NULL si non
# disponible (le lecteur ordinaire prend alors le relais). Cache dédié :
# `<cache>/decoloration/apercu20m/<scène>/<bande>.tif`.
.decol_lire_apercu <- function(scene, bande, emprise_sf, cache_dir) {
  chemin <- file.path(cache_dir, "decoloration", "apercu20m",
                      .s2_safe_scene_id(scene$scene_id), paste0(bande, ".tif"))
  if (file.exists(chemin)) {
    r <- tryCatch(terra::rast(chemin), error = function(e) NULL)
    if (!is.null(r)) return(r)
    unlink(chemin)
  }
  href <- .pc_ensure_fresh_href(scene[[paste0("href_", bande)]][[1]])
  r <- tryCatch(
    .with_s2_gdal_opts(suppressWarnings(
      terra::rast(.s2_vsi_path(href), opts = "OVERVIEW_LEVEL=0"))),
    error = function(e) NULL)
  if (is.null(r) || terra::res(r)[1] > .DECOL_TAILLE_PIXEL * 1.01) return(NULL)
  r <- tryCatch({
    ext_n <- terra::ext(terra::vect(sf::st_transform(emprise_sf, terra::crs(r))))
    terra::crop(r, ext_n, snap = "out") + 0
  }, error = function(e) NULL)
  if (is.null(r)) return(NULL)
  dir.create(dirname(chemin), recursive = TRUE, showWarnings = FALSE)
  tmp <- sub("\\.tif$", ".part.tif", chemin)
  terra::writeRaster(r, tmp, overwrite = TRUE, filetype = "GTiff",
                     gdal = "COMPRESS=DEFLATE")
  if (!isTRUE(file.rename(tmp, chemin))) unlink(tmp)
  r
}

# Garantit le composite (annee, mois) sur disque ; renvoie TRUE si écrit
.decol_composite_assurer <- function(annee, mois, g, emprise_sf, cache_dir,
                                     nuages_max = 70, emit = NULL,
                                     aujourdhui = Sys.Date()) {
  f <- .decol_composite_chemin(cache_dir, annee, mois, g)
  if (!.decol_composite_a_faire(f, annee, mois, aujourdhui)) return(FALSE)
  d0 <- as.Date(sprintf("%d-%02d-01", annee, mois))
  d1 <- seq(d0, by = "month", length.out = 2)[2] - 1
  bb84 <- sf::st_bbox(sf::st_transform(emprise_sf, 4326))
  scenes <- tryCatch(.decol_chercher_scenes(bb84, d0, d1, nuages_max),
                     error = function(e) e)
  if (inherits(scenes, "error")) {
    if (!is.null(emit)) emit(list(current = "decoloration:catalogue_injoignable",
                                  annee = annee, mois = mois,
                                  error_message = .redact_url(conditionMessage(scenes))))
    return(FALSE)  # mois refait au prochain lancement
  }
  traiter <- function(i) {
    sc <- scenes[i, , drop = FALSE]
    tryCatch(
      .decol_indices_scene(function(b, m) {
        .decol_lire_bande(sc, b, g, emprise_sf, cache_dir, emit)
      }, sc$scene_id),
      error = function(e) e)
  }
  res <- lapply(seq_len(nrow(scenes)), traiter)
  err <- vapply(res, inherits, logical(1), "error")
  # second essai des scènes en échec, après une courte pause (réseau coupé en
  # route, fichier tout juste publié), comme le script régional
  if (any(err)) {
    Sys.sleep(getOption("nemeton.decoloration_pause_s", 10))
    res[err] <- lapply(which(err), traiter)
    err <- vapply(res, inherits, logical(1), "error")
  }
  # trop de scènes en échec : mois non enregistré, refait au prochain lancement
  if (any(err) && sum(err) > 0.2 * length(res)) {
    if (!is.null(emit)) emit(list(current = "decoloration:mois_non_enregistre",
                                  annee = annee, mois = mois,
                                  n_echecs = sum(err), n_scenes = length(res)))
    return(FALSE)
  }
  res <- Filter(Negate(is.null), res[!err])
  out <- .decol_mediane_scenes(res, g)
  .decol_composite_ecrire(out, f)
  if (!is.null(emit)) emit(list(current = "decoloration:composite",
                                annee = annee, mois = mois,
                                n_scenes = length(res)))
  TRUE
}

# ---------------------------------------------------------------------------
# 3. Anomalie standardisée, avec normale de repli par les voisins (§ 6)
# ---------------------------------------------------------------------------

.decol_med_lignes <- function(M) {
  if (!ncol(M)) return(rep(NA_real_, nrow(M)))
  apply(M, 1, function(v) if (all(is.na(v))) NA_real_ else stats::median(v, na.rm = TRUE))
}
.decol_mad_lignes <- function(M) {
  if (!ncol(M)) return(rep(NA_real_, nrow(M)))
  apply(M, 1, function(v) if (all(is.na(v))) NA_real_ else stats::mad(v, na.rm = TRUE))
}

# X        : matrice pixels x années (même indice, même mois)
# ref      : années de référence autorisées
# ess      : essence de chaque pixel (vecteur)
# rc       : matrice pixels x 2 (ligne, colonne) sur la grille
# coupe    : matrice logique pixels x années, TRUE = pixel retiré (coupé)
# Renvoie list(z, origine) ; origine : 1 propre, 2 voisins, 0 aucune,
# NA = pas de valeur ce mois-là.
.decol_zscore <- function(X, annees, ref, plancher, ess, rc, coupe = NULL,
                          n_ref_min = 4L, repli = TRUE, rayon_px = 15,
                          n_voisins_min = 20L) {
  n <- nrow(X); ny <- ncol(X)
  if (!is.null(coupe)) X[coupe] <- NA
  est_ref <- annees %in% ref
  med <- mad <- nref <- matrix(NA_real_, n, ny)
  for (i in seq_len(ny)) {
    O <- X[, est_ref & seq_len(ny) != i, drop = FALSE]
    nref[, i] <- rowSums(!is.na(O))
    med[, i] <- .decol_med_lignes(O)
    mad[, i] <- .decol_mad_lignes(O)
  }
  propre <- nref >= n_ref_min & !is.na(med)
  z <- matrix(NA_real_, n, ny)
  origine <- matrix(NA_integer_, n, ny)
  avec <- !is.na(X)
  ok <- avec & propre
  z[ok] <- ((X - med) / pmax(mad, plancher))[ok]
  origine[ok] <- 1L
  origine[avec & !propre] <- 0L

  decalage_nul <- matrix(FALSE, n, ny)
  if (repli && any(avec & !propre)) {
    nr <- max(rc[, 1]); nc <- max(rc[, 2])
    grille <- matrix(NA_integer_, nr, nc)
    grille[rc] <- seq_len(n)
    lim <- ceiling(rayon_px)
    n_min_annee <- max(1L, ceiling(n_voisins_min / 2))
    for (p in which(rowSums(avec & !propre) > 0)) {
      r0 <- max(1L, rc[p, 1] - lim); r1 <- min(nr, rc[p, 1] + lim)
      c0 <- max(1L, rc[p, 2] - lim); c1 <- min(nc, rc[p, 2] + lim)
      fen <- which(!is.na(grille[r0:r1, c0:c1]), arr.ind = TRUE)
      q <- grille[cbind(fen[, 1] + r0 - 1L, fen[, 2] + c0 - 1L)]
      d2 <- (rc[q, 1] - rc[p, 1])^2 + (rc[q, 2] - rc[p, 2])^2
      q <- q[d2 <= rayon_px^2 & q != p & ess[q] == ess[p]]
      for (i in which(avec[p, ] & !propre[p, ])) {
        pool <- q[propre[q, i] & !(if (is.null(coupe)) FALSE else coupe[q, i])]
        if (length(pool) < n_voisins_min) next   # reste 0 : « aucune »
        autres <- which(avec[p, ] & est_ref & seq_len(ny) != i)
        dec <- vapply(autres, function(j) {
          v <- X[pool, j]
          if (sum(!is.na(v)) < n_min_annee) NA_real_
          else X[p, j] - stats::median(v, na.rm = TRUE)
        }, numeric(1))
        dec <- dec[!is.na(dec)]
        # le pixel a d'autres années mais toutes sont écartées (trop peu de
        # voisins valides) : décalage ramené à 0, signalé à l'appelant
        if (length(autres) && !length(dec)) decalage_nul[p, i] <- TRUE
        off <- if (length(dec)) stats::median(dec) else 0
        normale <- stats::median(med[pool, i]) + off
        s <- max(stats::median(mad[pool, i]), plancher)
        z[p, i] <- (X[p, i] - normale) / s
        origine[p, i] <- 2L
      }
    }
  }
  list(z = z, origine = origine, decalage_nul = decalage_nul)
}

# ---------------------------------------------------------------------------
# 4. ICD (§ 7)
# ---------------------------------------------------------------------------

# `zs` : liste nommée (un élément par indice) de list(z, origine) sur le même
# jeu de pixels ; `w` : matrice pixels x indices de poids (0 = indice ignoré).
# Les mois hors saison de l'essence sont mis à NA par l'appelant (poids absents).
.decol_icd <- function(zs, w) {
  n <- nrow(zs[[1]]$z); ny <- ncol(zs[[1]]$z)
  icd <- matrix(0, n, ny)
  orig <- matrix(1L, n, ny)
  nul <- matrix(FALSE, n, ny)   # pas de valeur
  aucune <- matrix(FALSE, n, ny)
  for (ind in names(zs)) {
    actif <- w[, ind] > 0
    if (!any(actif)) next
    zi <- zs[[ind]]$z * (.DECOL_SENS[[ind]] * w[, ind])
    oi <- zs[[ind]]$origine
    manque <- is.na(zi) & actif                  # actif est recyclé par colonne
    contrib <- zi
    contrib[!actif, ] <- 0
    contrib[is.na(contrib)] <- 0
    icd <- icd + contrib
    nul <- nul | (manque & is.na(oi))
    aucune <- aucune | (manque & !is.na(oi) & oi == 0L)
    voisins <- !is.na(oi) & oi == 2L & actif
    orig[voisins] <- 2L
  }
  icd[nul | aucune] <- NA
  orig[aucune] <- 0L
  orig[nul] <- NA_integer_
  list(icd = icd, origine = orig)
}

# ---------------------------------------------------------------------------
# 5. Alerte et niveaux (§ 8)
# ---------------------------------------------------------------------------

# v : ICD des mois suivis (NA ignorés). Renvoie c(classe, ICD min) avec
# classe 2 = alerte, 1 = surveillance, 0 = normal, NA = aucune donnée.
.decol_alerte_pixel <- function(v, s_alerte = -2, s_surv = -1.5, n_pers = 2L) {
  vv <- v[!is.na(v)]
  if (!length(vv)) return(c(NA_real_, NA_real_))
  r <- rle(vv < s_alerte)
  if (any(r$values & r$lengths >= n_pers)) return(c(2, min(vv)))
  if (any(vv < s_surv)) return(c(1, min(vv)))
  c(0, min(vv))
}

# icd : matrice pixels x mois (colonnes = mois, ordre croissant). Renvoie
# list(classe, icd_min) vecteurs.
.decol_alerte <- function(icd, s_alerte = -2, s_surv = -1.5, n_pers = 2L) {
  res <- t(apply(icd, 1, .decol_alerte_pixel, s_alerte = s_alerte,
                 s_surv = s_surv, n_pers = n_pers))
  if (nrow(icd) == 1L) res <- matrix(res, 1)
  list(classe = res[, 1], icd_min = res[, 2])
}

# Niveaux 0 à 4 ; `prec` = alerte sur la saison complète de l'année d'avant
.decol_niveau <- function(classe, icd_min, prec, s_forte = -3) {
  prec <- !is.na(prec) & prec
  ifelse(is.na(classe), NA_integer_,
  ifelse(classe == 2 & prec, 4L,
  ifelse(classe == 2 & icd_min < s_forte, 3L,
  ifelse(classe == 2, 2L, ifelse(classe == 1, 1L, 0L)))))
}

# ---------------------------------------------------------------------------
# 6. Carte d'essences (§ 3)
# ---------------------------------------------------------------------------

#' Build a species map for decoloration monitoring from BD Foret V2 polygons
#'
#' Rasterises the four tracked pure stands of the BD Foret V2 (oak, beech,
#' fir/spruce, Douglas fir; TFV codes `FF1G01-01`, `FF1-09-09`, `FF2G61-61`,
#' `FF2-64-64`) on a 20 m Lambert-93 grid, after an inner buffer that removes
#' the stand edges.
#'
#' @param x An `sf` object of BD Foret V2 polygons with a TFV column.
#' @param emprise Anything accepted by [sf::st_bbox()] (`sf`, `sfc`, `bbox`,
#'   `SpatRaster`); the grid covers it.
#' @param col_tfv Name of the TFV column. Default `"TFV"`; `"tfv"`,
#'   `"code_tfv"` and `"ess_id"` (already coded 1 to 4) are also tried.
#' @param retrait_m Inner buffer (m) removed along stand edges. Default 10.
#'
#' @return A [terra::SpatRaster] (EPSG:2154, 20 m) with values 1 to 4
#'   (see `decoloration_detecter()`), `NA` elsewhere.
#' @seealso [decoloration_detecter()]
#' @export
decoloration_carte_essences <- function(x, emprise, col_tfv = NULL,
                                        retrait_m = 10) {
  if (!inherits(x, "sf")) cli::cli_abort("{.arg x} must be an {.cls sf} object.")
  col <- col_tfv %||% intersect(c("TFV", "tfv", "code_tfv", "ess_id"), names(x))[1]
  if (is.na(col) || !col %in% names(x)) {
    cli::cli_abort("No TFV column found in {.arg x} (tried TFV, tfv, code_tfv, ess_id).")
  }
  ess <- .decol_essences()
  g <- .decol_grille(emprise)
  x <- sf::st_transform(x, 2154)
  code <- as.character(sf::st_drop_geometry(x)[[col]])
  # colonne déjà codée 1 à 4 (cache BD Forêt de nemetonplateforme) : prise telle quelle
  id <- if (identical(col, "ess_id")) match(as.integer(code), ess$ess_id) else match(code, ess$code_tfv)
  # le WFS IGN expose parfois le libellé plutôt que le code : on accepte
  # aussi le code en préfixe d'un libellé
  manque <- which(is.na(id) & !is.na(code))
  for (i in manque) {
    h <- which(vapply(ess$code_tfv, function(k) startsWith(code[i], k), logical(1)))
    if (length(h)) id[i] <- h[1]
  }
  keep <- !is.na(id)
  out <- terra::rast(g)
  terra::values(out) <- NA_integer_
  if (any(keep)) {
    geom <- sf::st_geometry(x)[keep]
    if (retrait_m > 0) geom <- sf::st_buffer(geom, -retrait_m)
    ok <- !sf::st_is_empty(geom)
    if (any(ok)) {
      v <- terra::vect(sf::st_sf(ess_id = id[keep][ok], geometry = geom[ok]))
      out <- terra::rasterize(v, out, field = "ess_id", touches = FALSE)
    }
  }
  names(out) <- "essence"
  out
}

# Grille 20 m Lambert 93 alignée sur des multiples de 20 m
.decol_grille <- function(extent) {
  if (inherits(extent, "SpatRaster")) {
    bb <- sf::st_bbox(c(xmin = terra::xmin(extent), ymin = terra::ymin(extent),
                        xmax = terra::xmax(extent), ymax = terra::ymax(extent)),
                      crs = sf::st_crs(terra::crs(extent)))
  } else {
    bb <- sf::st_bbox(extent)
  }
  if (!is.na(sf::st_crs(bb)) && sf::st_crs(bb) != sf::st_crs(2154)) {
    bb <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(bb), 2154))
  }
  res <- .DECOL_TAILLE_PIXEL
  e <- terra::ext(floor(bb["xmin"] / res) * res, ceiling(bb["xmax"] / res) * res,
                  floor(bb["ymin"] / res) * res, ceiling(bb["ymax"] / res) * res)
  terra::rast(e, resolution = res, crs = "EPSG:2154")
}

# Dates de coupe -> raster de temps en mois absolus sur la grille `g`
.decol_coupes_vers_t <- function(coupes, g) {
  if (is.null(coupes)) return(NULL)
  if (inherits(coupes, "sf")) {
    col <- intersect(c("date_coupe", "date"), names(coupes))[1]
    if (is.na(col)) cli::cli_abort("{.arg coupes} (sf) needs a {.field date_coupe} Date column.")
    d <- as.Date(sf::st_drop_geometry(coupes)[[col]])
    tm <- .decol_t_mois(as.integer(format(d, "%Y")), as.integer(format(d, "%m")))
    v <- terra::vect(sf::st_sf(t = tm, geometry = sf::st_transform(sf::st_geometry(coupes), 2154)))
    return(terra::rasterize(v, terra::rast(g), field = "t", fun = "min", touches = FALSE))
  }
  if (inherits(coupes, "SpatRaster")) {
    r <- terra::project(coupes[[1]], g, method = "near")
    d <- as.Date(terra::values(r, mat = FALSE), origin = "1970-01-01")
    out <- terra::rast(g)
    terra::values(out) <- .decol_t_mois(as.integer(format(d, "%Y")),
                                        as.integer(format(d, "%m")))
    return(out)
  }
  cli::cli_abort("{.arg coupes} must be NULL, an sf with {.field date_coupe}, or a SpatRaster of Dates.")
}

# ---------------------------------------------------------------------------
# 7. API
# ---------------------------------------------------------------------------

#' Detect abnormal foliage discoloration from Sentinel-2 monthly composites
#'
#' Computes, on a 20 m Lambert-93 grid covering `emprise`, the discoloration
#' composite indicator (ICD) per pixel and year from monthly Sentinel-2
#' composites (April to October), then the yearly alert and the 0-4 levels
#' (0 normal, 1 watch, 2 alert, 3 strong alert, 4 repeated alert).
#'
#' Pixels without `n_annees_ref_min` valid reference years (cut early, or gappy
#' series) use a fallback normal drawn from neighbouring pixels of the same
#' species: median of the neighbours' own normals plus the pixel's own offset
#' (median over its available years of its gap to the neighbours' median of
#' the same year), scale = median of the neighbours' MAD (floored). With fewer
#' than `n_voisins_min` usable neighbours the pixel gets no normal: level `NA`
#' and origin 0, never level 0. The normal stays temporal (neighbours are
#' compared with their own other years), so a regional drought is not
#' cancelled. A neighbour median of a given year needs at least half of
#' `n_voisins_min` valid neighbours; when every other year of a pixel is
#' discarded for that reason its offset falls back to 0, and the number of
#' such pixels is reported (event `decoloration:repli_decalage_nul` and
#' `diagnostics` in the result).
#'
#' Sentinel-2 bands are read through nemeton's windowed reader and shared
#' per-band cache (`<dossier_cache>/sentinel2/<scene>/<band>.tif`); the 10 m
#' bands (B03, B04, B08) are read from the native 20 m overview of the COG
#' (as the regional script does) into `<dossier_cache>/decoloration/apercu20m/`.
#' Monthly composites are stored per grid in
#' `<dossier_cache>/decoloration/composites/<grid footprint>/`, so two
#' different extents never share a composite. The current month is not
#' rebuilt until it has ended for 5 days.
#'
#' @param emprise Area of interest: `sf`, `sfc`, `bbox` or `SpatRaster`.
#' @param annees Integer vector of years to evaluate.
#' @param essences Species map: a [terra::SpatRaster] with values 1 to 4
#'   (1 oak, 2 beech, 3 fir/spruce, 4 Douglas fir), or an `sf` of BD Foret V2
#'   polygons (see [decoloration_carte_essences()]).
#' @param coupes Optional cut dates: `NULL`, an `sf` with a `date_coupe` Date
#'   column, or a [terra::SpatRaster] of Dates. A pixel is removed from its
#'   cut month on.
#' @param dossier_cache Cache directory (e.g. a project's `cache/layers`).
#' @param annees_reference Reference years for the normal; default all `annees`.
#' @param n_annees_ref_min Minimum number of valid reference years. Default 4.
#' @param repli Use the neighbour fallback normal. Default `TRUE`.
#' @param rayon_m Neighbour radius (m). Default 300.
#' @param n_voisins_min Minimum number of usable neighbours. Default 20.
#' @param nuages_max Maximum scene cloud cover (percent). Default 70.
#' @param mois_a_date Last month taken into account ("à date" index). `NULL`
#'   (default): last month with a composite for the last year of `annees`; the
#'   month in progress counts only from its 20th day. Can be forced.
#' @param calculer_composites If `FALSE`, only composites already on disk are
#'   used (no network).
#' @param emettre Optional function receiving progress events (lists with a
#'   `current` field such as `"decoloration:composite"`), like FAST's.
#'
#' @return A list with three multi-layer [terra::SpatRaster] (one layer per
#'   year, 20 m, EPSG:2154): `niveaux` (0-4, `NA` = no data or no normal),
#'   `icd_min` (minimal ICD of the year) and `origine` (origin of the normal:
#'   1 own, 2 neighbours, 0 none), plus `parametres` and `diagnostics`
#'   (`n_pixels_decalage_nul`).
#' @seealso [decoloration_carte_essences()]
#' @export
decoloration_detecter <- function(emprise, annees, essences, coupes = NULL,
                                  dossier_cache, annees_reference = annees,
                                  n_annees_ref_min = 4L, repli = TRUE,
                                  rayon_m = 300, n_voisins_min = 20L,
                                  nuages_max = 70, mois_a_date = NULL,
                                  calculer_composites = TRUE, emettre = NULL) {
  annees <- sort(as.integer(annees))
  g <- .decol_grille(emprise)
  emprise_sf <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(
    c(xmin = terra::xmin(g), ymin = terra::ymin(g), xmax = terra::xmax(g),
      ymax = terra::ymax(g)), crs = sf::st_crs(2154))))
  ess_r <- if (inherits(essences, "sf")) {
    decoloration_carte_essences(essences, emprise)
  } else if (inherits(essences, "SpatRaster")) {
    terra::project(essences[[1]], g, method = "near")
  } else {
    cli::cli_abort("{.arg essences} must be a SpatRaster or an sf of BD Foret V2.")
  }
  if (calculer_composites) {
    for (a in annees) for (m in .DECOL_MOIS) {
      .decol_composite_assurer(a, m, g, emprise_sf, dossier_cache, nuages_max, emettre)
    }
  }
  ess_v <- terra::values(ess_r, mat = FALSE)
  cells <- which(!is.na(ess_v))
  rc <- cbind(terra::rowFromCell(g, cells), terra::colFromCell(g, cells))
  ess <- as.integer(ess_v[cells])
  tc <- .decol_coupes_vers_t(coupes, g)
  tc <- if (is.null(tc)) rep(NA_real_, length(cells)) else terra::values(tc, mat = FALSE)[cells]
  tab <- .decol_essences()
  mois_ess <- .decol_mois_essence()
  if (is.null(mois_a_date)) {
    mois_a_date <- .decol_mois_a_date(dossier_cache, g, max(annees))
  }
  mois_utiles <- .DECOL_MOIS[.DECOL_MOIS <= mois_a_date]
  ny <- length(annees); n <- length(cells)

  icd_m <- array(NA_real_, c(n, length(.DECOL_MOIS), ny))
  orig_m <- array(NA_integer_, c(n, length(.DECOL_MOIS), ny))
  decalage_nul <- rep(FALSE, n)
  for (k in seq_along(.DECOL_MOIS)) {
    m <- .DECOL_MOIS[k]
    suivi <- which(vapply(seq_len(nrow(tab)), function(e) m %in% mois_ess[[tab$essence[e]]], logical(1)))
    sel <- which(ess %in% tab$ess_id[suivi])
    if (!length(sel)) next
    comp <- lapply(annees, function(a) {
      f <- .decol_composite_chemin(dossier_cache, a, m, g)
      if (.decol_composite_lisible_strict(f)) .decol_composite_lire(f, g) else NULL
    })
    t_ym <- .decol_t_mois(annees, m)
    coupe <- outer(tc[sel], t_ym, function(a, b) !is.na(a) & a <= b)
    zs <- lapply(stats::setNames(.DECOL_INDICES, .DECOL_INDICES), function(ind) {
      X <- vapply(seq_len(ny), function(j) {
        if (is.null(comp[[j]])) rep(NA_real_, length(sel))
        else terra::values(comp[[j]][[ind]], mat = FALSE)[cells[sel]]
      }, numeric(length(sel)))
      X <- matrix(X, length(sel), ny)
      .decol_zscore(X, annees, annees_reference, .DECOL_PLANCHER[[ind]],
                    ess[sel], rc[sel, , drop = FALSE], coupe,
                    n_ref_min = n_annees_ref_min, repli = repli,
                    rayon_px = rayon_m / .DECOL_TAILLE_PIXEL,
                    n_voisins_min = n_voisins_min)
    })
    for (ind in names(zs)) {
      decalage_nul[sel] <- decalage_nul[sel] | rowSums(zs[[ind]]$decalage_nul) > 0
    }
    w <- vapply(.DECOL_INDICES, function(ind) tab[[paste0("w_", ind)]][match(ess[sel], tab$ess_id)], numeric(length(sel)))
    w <- matrix(w, length(sel), length(.DECOL_INDICES), dimnames = list(NULL, .DECOL_INDICES))
    r <- .decol_icd(zs, w)
    icd_m[sel, k, ] <- r$icd
    orig_m[sel, k, ] <- r$origine
    if (!is.null(emettre)) emettre(list(current = "decoloration:anomalies", mois = m,
                                        n_pixels = length(sel)))
  }
  n_dn <- sum(decalage_nul)
  if (!is.null(emettre) && n_dn > 0) {
    emettre(list(current = "decoloration:repli_decalage_nul", n_pixels = n_dn,
                 n_pixels_total = n))
  }

  idx_date <- which(.DECOL_MOIS %in% mois_utiles)
  niv <- icmin <- org <- matrix(NA_real_, n, ny)
  prec <- rep(FALSE, n)
  for (j in seq_len(ny)) {
    ad <- .decol_alerte(matrix(icd_m[, idx_date, j], n))
    niv[, j] <- .decol_niveau(ad$classe, ad$icd_min, prec)
    icmin[, j] <- ad$icd_min
    org[, j] <- .decol_origine_annee(icd_m[, idx_date, j, drop = FALSE][, , 1],
                                     orig_m[, idx_date, j, drop = FALSE][, , 1])
    # alerte sur la saison complète : sert d'« année d'avant » à l'année suivante
    pl <- .decol_alerte(matrix(icd_m[, , j], n))$classe
    prec <- !is.na(pl) & pl == 2
  }
  vers_raster <- function(M) {
    r <- terra::rast(lapply(seq_len(ny), function(j) {
      v <- rep(NA_real_, terra::ncell(g)); v[cells] <- M[, j]
      x <- terra::rast(g); terra::values(x) <- v; x
    }))
    names(r) <- as.character(annees)
    r
  }
  list(niveaux = vers_raster(niv), icd_min = vers_raster(icmin),
       origine = vers_raster(org),
       parametres = list(n_annees_ref_min = n_annees_ref_min, repli = repli,
                         rayon_m = rayon_m, n_voisins_min = n_voisins_min,
                         mois_a_date = mois_a_date),
       diagnostics = list(n_pixels_decalage_nul = n_dn, n_pixels = n))
}

# Indice « à date » (§ 8) : dernier mois ayant un composite lisible pour
# l'année de fin ; le mois en cours n'est pris qu'à partir de son 20e jour
# (sinon composite trop pauvre). Sans composite : toute la saison.
.decol_mois_a_date <- function(dossier_cache, g, annee_fin, aujourdhui = Sys.Date()) {
  m <- .DECOL_MOIS[vapply(.DECOL_MOIS, function(k) {
    .decol_composite_lisible_strict(.decol_composite_chemin(dossier_cache, annee_fin, k, g))
  }, logical(1))]
  if (length(m) &&
      .decol_t_mois(annee_fin, max(m)) ==
      .decol_t_mois(as.integer(format(aujourdhui, "%Y")), as.integer(format(aujourdhui, "%m"))) &&
      as.integer(format(aujourdhui, "%d")) < 20) {
    m <- m[m < max(m)]
  }
  if (length(m)) max(m) else max(.DECOL_MOIS)
}

# Origine de la normale pour une année : 2 si un mois valide l'utilise, 1 sinon,
# 0 si aucun mois n'a pu être calculé faute de normale, NA sans donnée.
.decol_origine_annee <- function(icd, orig) {
  icd <- matrix(icd, nrow = nrow(orig)); orig <- matrix(orig, nrow = nrow(icd))
  vapply(seq_len(nrow(icd)), function(p) {
    ok <- !is.na(icd[p, ])
    if (any(ok)) return(if (any(orig[p, ok] == 2L, na.rm = TRUE)) 2 else 1)
    if (any(orig[p, ] == 0L, na.rm = TRUE)) 0 else NA_real_
  }, numeric(1))
}
