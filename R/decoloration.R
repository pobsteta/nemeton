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

# Offset de réflectance selon la baseline (identifiant de scène) : retire 1000
# aux scènes de baseline >= 04.00, borne à 0, 0 devient NA (nodata).
.decol_retirer_offset <- function(x, scene_id) {
  off <- .s2_boa_offset(scene_id)
  if (!is.na(off) && off != 0) x <- x + off
  x[x <= 0] <- NA
  x
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

.decol_composite_chemin <- function(cache_dir, annee, mois) {
  file.path(cache_dir, "decoloration", "composites",
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
  file.rename(tmp, f)
  invisible(f)
}

.decol_composite_lire <- function(f) {
  r <- terra::rast(f)
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
.decol_lire_bande <- function(scene, bande, g, emprise_sf, bandes_dir, emit = NULL) {
  r <- .get_s2_band_raster(scene, bande, emprise_sf, cache_dir = bandes_dir,
                           emit = emit)
  terra::project(r, g, method = if (bande == "SCL") "near" else "bilinear")
}

# Garantit le composite (annee, mois) sur disque ; renvoie TRUE si écrit
.decol_composite_assurer <- function(annee, mois, g, emprise_sf, cache_dir,
                                     nuages_max = 70, emit = NULL,
                                     aujourdhui = Sys.Date()) {
  f <- .decol_composite_chemin(cache_dir, annee, mois)
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
  bandes_dir <- file.path(cache_dir, "sentinel2")
  res <- lapply(seq_len(nrow(scenes)), function(i) {
    sc <- scenes[i, , drop = FALSE]
    tryCatch(
      .decol_indices_scene(function(b, m) {
        .decol_lire_bande(sc, b, g, emprise_sf, bandes_dir, emit)
      }, sc$scene_id),
      error = function(e) e)
  })
  err <- vapply(res, inherits, logical(1), "error")
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
        off <- if (length(dec)) stats::median(dec) else 0
        normale <- stats::median(med[pool, i]) + off
        s <- max(stats::median(mad[pool, i]), plancher)
        z[p, i] <- (X[p, i] - normale) / s
        origine[p, i] <- 2L
      }
    }
  }
  list(z = z, origine = origine)
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
#' @param extent Anything accepted by [sf::st_bbox()] (`sf`, `sfc`, `bbox`,
#'   `SpatRaster`); the grid covers it.
#' @param tfv_col Name of the TFV column. Default `"TFV"`; `"tfv"` and
#'   `"code_tfv"` are also tried.
#' @param buffer_m Inner buffer (m) removed along stand edges. Default 10.
#'
#' @return A [terra::SpatRaster] (EPSG:2154, 20 m) with values 1 to 4
#'   (see `decoloration_detecter()`), `NA` elsewhere.
#' @seealso [decoloration_detecter()]
#' @export
decoloration_carte_essences <- function(x, extent, tfv_col = NULL,
                                        buffer_m = 10) {
  if (!inherits(x, "sf")) cli::cli_abort("{.arg x} must be an {.cls sf} object.")
  col <- tfv_col %||% intersect(c("TFV", "tfv", "code_tfv"), names(x))[1]
  if (is.na(col) || !col %in% names(x)) {
    cli::cli_abort("No TFV column found in {.arg x} (tried TFV, tfv, code_tfv).")
  }
  ess <- .decol_essences()
  g <- .decol_grille(extent)
  x <- sf::st_transform(x, 2154)
  code <- as.character(sf::st_drop_geometry(x)[[col]])
  id <- match(code, ess$code_tfv)
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
    if (buffer_m > 0) geom <- sf::st_buffer(geom, -buffer_m)
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
    if (is.na(col)) cli::cli_abort("{.arg cuts} (sf) needs a {.field date_coupe} Date column.")
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
  cli::cli_abort("{.arg cuts} must be NULL, an sf with {.field date_coupe}, or a SpatRaster of Dates.")
}

# ---------------------------------------------------------------------------
# 7. API
# ---------------------------------------------------------------------------

#' Detect abnormal foliage discoloration from Sentinel-2 monthly composites
#'
#' Computes, on a 20 m Lambert-93 grid covering `extent`, the discoloration
#' composite indicator (ICD) per pixel and year from monthly Sentinel-2
#' composites (April to October), then the yearly alert and the 0-4 levels
#' (0 normal, 1 watch, 2 alert, 3 strong alert, 4 repeated alert).
#'
#' Pixels without `n_ref_min` valid reference years (cut early, or gappy
#' series) use a fallback normal drawn from neighbouring pixels of the same
#' species: median of the neighbours' own normals plus the pixel's own offset
#' (median over its available years of its gap to the neighbours' median of
#' the same year), scale = median of the neighbours' MAD (floored). With fewer
#' than `n_voisins_min` usable neighbours the pixel gets no normal: level `NA`
#' and origin 0, never level 0. The normal stays temporal (neighbours are
#' compared with their own other years), so a regional drought is not
#' cancelled.
#'
#' Sentinel-2 bands are read through nemeton's windowed reader and shared
#' per-band cache (`<cache_dir>/sentinel2/<scene>/<band>.tif`); monthly
#' composites are stored in `<cache_dir>/decoloration/composites/`. The
#' current month is not rebuilt until it has ended for 5 days.
#'
#' @param extent Area of interest: `sf`, `sfc`, `bbox` or `SpatRaster`.
#' @param years Integer vector of years to evaluate (the reference uses all
#'   of them, or `ref_years`).
#' @param species Species map: a [terra::SpatRaster] with values 1 to 4
#'   (1 oak, 2 beech, 3 fir/spruce, 4 Douglas fir), or an `sf` of BD Foret V2
#'   polygons (see [decoloration_carte_essences()]).
#' @param cuts Optional cut dates: `NULL`, an `sf` with a `date_coupe` Date
#'   column, or a [terra::SpatRaster] of Dates. A pixel is removed from its
#'   cut month on.
#' @param cache_dir Cache directory (e.g. a project's `cache/layers`).
#' @param ref_years Reference years for the normal; default all `years`.
#' @param n_ref_min Minimum number of valid reference years. Default 4.
#' @param fallback Use the neighbour fallback normal. Default `TRUE`.
#' @param radius_m Neighbour radius (m). Default 300.
#' @param n_voisins_min Minimum number of usable neighbours. Default 20.
#' @param cloud_max Maximum scene cloud cover (percent). Default 70.
#' @param to_month Last month taken into account ("à date" index); `NULL`
#'   uses the whole season.
#' @param compute_composites If `FALSE`, only composites already on disk are
#'   used (no network).
#' @param emit Optional function receiving progress events (lists with a
#'   `current` field such as `"decoloration:composite"`), like FAST's.
#'
#' @return A list with three multi-layer [terra::SpatRaster] (one layer per
#'   year, 20 m, EPSG:2154): `niveaux` (0-4, `NA` = no data or no normal),
#'   `icd_min` (minimal ICD of the year) and `origine` (origin of the normal:
#'   1 own, 2 neighbours, 0 none), plus `parametres`.
#' @seealso [decoloration_carte_essences()]
#' @export
decoloration_detecter <- function(extent, years, species, cuts = NULL,
                                  cache_dir, ref_years = years,
                                  n_ref_min = 4L, fallback = TRUE,
                                  radius_m = 300, n_voisins_min = 20L,
                                  cloud_max = 70, to_month = NULL,
                                  compute_composites = TRUE, emit = NULL) {
  years <- sort(as.integer(years))
  g <- .decol_grille(extent)
  emprise_sf <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(
    c(xmin = terra::xmin(g), ymin = terra::ymin(g), xmax = terra::xmax(g),
      ymax = terra::ymax(g)), crs = sf::st_crs(2154))))
  ess_r <- if (inherits(species, "sf")) {
    decoloration_carte_essences(species, extent)
  } else if (inherits(species, "SpatRaster")) {
    terra::project(species[[1]], g, method = "near")
  } else {
    cli::cli_abort("{.arg species} must be a SpatRaster or an sf of BD Foret V2.")
  }
  if (compute_composites) {
    for (a in years) for (m in .DECOL_MOIS) {
      .decol_composite_assurer(a, m, g, emprise_sf, cache_dir, cloud_max, emit)
    }
  }
  ess_v <- terra::values(ess_r, mat = FALSE)
  cells <- which(!is.na(ess_v))
  nr <- terra::nrow(g); nc <- terra::ncol(g)
  rc <- cbind(terra::rowFromCell(g, cells), terra::colFromCell(g, cells))
  ess <- as.integer(ess_v[cells])
  tc <- .decol_coupes_vers_t(cuts, g)
  tc <- if (is.null(tc)) rep(NA_real_, length(cells)) else terra::values(tc, mat = FALSE)[cells]
  tab <- .decol_essences()
  mois_ess <- .decol_mois_essence()
  mois_utiles <- .DECOL_MOIS
  if (!is.null(to_month)) mois_utiles <- mois_utiles[mois_utiles <= to_month]
  ny <- length(years); n <- length(cells)

  icd_m <- array(NA_real_, c(n, length(.DECOL_MOIS), ny))
  orig_m <- array(NA_integer_, c(n, length(.DECOL_MOIS), ny))
  for (k in seq_along(.DECOL_MOIS)) {
    m <- .DECOL_MOIS[k]
    suivi <- which(vapply(seq_len(nrow(tab)), function(e) m %in% mois_ess[[tab$essence[e]]], logical(1)))
    sel <- which(ess %in% tab$ess_id[suivi])
    if (!length(sel)) next
    comp <- lapply(years, function(a) {
      f <- .decol_composite_chemin(cache_dir, a, m)
      if (.decol_composite_lisible_strict(f)) .decol_composite_lire(f) else NULL
    })
    t_ym <- .decol_t_mois(years, m)
    coupe <- outer(tc[sel], t_ym, function(a, b) !is.na(a) & a <= b)
    zs <- lapply(stats::setNames(.DECOL_INDICES, .DECOL_INDICES), function(ind) {
      X <- vapply(seq_len(ny), function(j) {
        if (is.null(comp[[j]])) rep(NA_real_, length(sel))
        else terra::values(comp[[j]][[ind]], mat = FALSE)[cells[sel]]
      }, numeric(length(sel)))
      X <- matrix(X, length(sel), ny)
      .decol_zscore(X, years, ref_years, .DECOL_PLANCHER[[ind]],
                    ess[sel], rc[sel, , drop = FALSE], coupe,
                    n_ref_min = n_ref_min, repli = fallback,
                    rayon_px = radius_m / .DECOL_TAILLE_PIXEL,
                    n_voisins_min = n_voisins_min)
    })
    w <- vapply(.DECOL_INDICES, function(ind) tab[[paste0("w_", ind)]][match(ess[sel], tab$ess_id)], numeric(length(sel)))
    w <- matrix(w, length(sel), length(.DECOL_INDICES), dimnames = list(NULL, .DECOL_INDICES))
    r <- .decol_icd(zs, w)
    icd_m[sel, k, ] <- r$icd
    orig_m[sel, k, ] <- r$origine
    if (!is.null(emit)) emit(list(current = "decoloration:anomalies", mois = m,
                                  n_pixels = length(sel)))
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
    names(r) <- as.character(years)
    r
  }
  list(niveaux = vers_raster(niv), icd_min = vers_raster(icmin),
       origine = vers_raster(org),
       parametres = list(n_ref_min = n_ref_min, fallback = fallback,
                         radius_m = radius_m, n_voisins_min = n_voisins_min,
                         to_month = to_month))
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
