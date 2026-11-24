# Fonctions de l'étude FAST contre décoloration (mission 045, brief 2026-11-24).
# Fonctions pures, sans réseau, testées par tests/testthat/test-etude-fast-decoloration.R.
# Les mois sont des indices entiers  an * 12 + mois - 1  (même codage que
# `sufosat_tcoupe()` de la décoloration). Une absence de coupe vaut NA.

HORIZONS <- c(12L, 24L, 36L, 48L)

# --- 1. tirage des zones ---------------------------------------------------
# communes : data.frame(commune, groupe, taux_touche). Par groupe d'essences :
# `n_haut` communes très touchées (quartile haut) + `n_bas` peu touchées
# (quartile bas) ; plus `n_melange` communes du groupe "melange" (FAST seul).
# Graine fixe ; ordre d'entrée sans effet.
tirer_zones <- function(communes, graine = 45L, n_haut = 2L, n_bas = 1L,
                        n_melange = 2L,
                        groupes = c("chene", "hetre", "sapin_epicea", "douglas")) {
  communes <- communes[order(communes$commune), ]
  set.seed(graine)
  tir <- function(d, n, haut, strate) {
    if (!nrow(d) || n < 1L) return(NULL)
    q <- stats::quantile(d$taux_touche, if (haut) 0.75 else 0.25, na.rm = TRUE)
    p <- d[if (haut) d$taux_touche >= q else d$taux_touche <= q, , drop = FALSE]
    p <- p[sample.int(nrow(p), min(n, nrow(p))), , drop = FALSE]
    p$strate <- strate
    p
  }
  out <- list()
  for (g in groupes) {
    d <- communes[communes$groupe == g, , drop = FALSE]
    out <- c(out, list(tir(d, n_haut, TRUE, "tres_touchee"), tir(d, n_bas, FALSE, "peu_touchee")))
  }
  m <- communes[communes$groupe == "melange", , drop = FALSE]
  if (nrow(m) && n_melange > 0L) {
    m <- m[sample.int(nrow(m), min(n_melange, nrow(m))), , drop = FALSE]
    m$strate <- "melange"
    out <- c(out, list(m))
  }
  z <- do.call(rbind, out); rownames(z) <- NULL
  z$graine <- graine
  z
}

# --- 2. vérité SUFOSAT -----------------------------------------------------
# t4 : matrice n x 4 des mois de coupe des 4 sous-pixels de 10 m (NA = pas de
# coupe). Pixel de 20 m coupé si >= `min_sous` sous-pixels coupés ; sa date est
# celle où ce seuil est atteint (min_sous-ième date la plus précoce).
coupe_20m <- function(t4, min_sous = 2L) {
  t4 <- as.matrix(t4)
  apply(t4, 1L, function(v) {
    v <- sort(v[!is.na(v)])
    if (length(v) >= min_sous) v[min_sous] else NA_real_
  })
}

mois_indice <- function(annee, mois = 10L) as.integer(annee) * 12L + mois - 1L

# --- 3. cohorte, exclusion, censure ----------------------------------------
# data.frame(garde, delai, evenement, censure) par pixel.
#  - garde = FALSE : pixel déjà coupé à la date de l'indice (cas 2)
#  - censure : mois observables = derniere_coupe - t_indice (cas 1)
#  - evenement : coupe dans (t_indice, derniere_coupe]
cohorte_pixels <- function(t_coupe, t_indice, derniere_coupe) {
  deja <- !is.na(t_coupe) & t_coupe <= t_indice
  cens <- max(0L, derniere_coupe - t_indice)
  ev   <- !deja & !is.na(t_coupe) & t_coupe <= derniere_coupe
  data.frame(garde = !deja,
             delai = ifelse(ev, t_coupe - t_indice, cens),
             evenement = ev,
             censure = cens)
}

# Cas 0 : une cohorte est sans biais si tout pixel encore debout à la date de
# l'indice a au moins `n_ref_min` années de référence valides avant sa coupe.
cohorte_sans_biais <- function(annee, premiere_annee = 2017L, n_ref_min = 4L) {
  annee >= premiere_annee + n_ref_min
}
# Un pixel coupé en `annee_coupe` n'a de valeurs que premiere..annee_coupe-1 ;
# son anomalie (leave-one-out) exige n_ref_min *autres* années valides.
pixel_comparable <- function(annee_coupe, premiere_annee = 2017L, n_ref_min = 4L) {
  nv <- pmax(0L, annee_coupe - premiere_annee)
  is.na(annee_coupe) | (nv - 1L >= n_ref_min)
}

# --- 4. états manquants / non applicables (cas 3 et 4) -----------------------
# niveau : classe de la méthode ; n_images : images de la saison ;
# applicable : méthode définie pour ce pixel (essence connue pour la décoloration).
etat_pixel <- function(niveau, n_images = rep(1L, length(niveau)),
                       applicable = rep(TRUE, length(niveau))) {
  e <- as.character(niveau)
  e[is.na(niveau) | n_images == 0L] <- "manquant"
  e[!applicable] <- "non_applicable"
  e
}

# --- 5. Kaplan-Meier pondéré ------------------------------------------------
# delai (mois), evenement (lgl), poids (volume). Risque cumulé à chaque horizon ;
# NA si personne n'est suivi jusque-là (horizon non couvert, cas 1).
km_risque <- function(delai, evenement, poids = rep(1, length(delai)),
                      horizons = HORIZONS) {
  ok <- is.finite(delai) & is.finite(poids) & poids > 0
  delai <- delai[ok]; evenement <- evenement[ok]; poids <- poids[ok]
  ts <- sort(unique(delai[evenement]))
  S <- 1; cum <- numeric(0)
  for (t in ts) {
    n <- sum(poids[delai >= t]); d <- sum(poids[evenement & delai == t])
    S <- S * (1 - d / n); cum[as.character(t)] <- 1 - S
  }
  suivi_max <- if (length(delai)) max(delai) else 0
  vapply(horizons, function(h) {
    if (h > suivi_max) return(NA_real_)
    k <- as.numeric(names(cum)) <= h
    if (!any(k)) 0 else unname(cum[max(which(k))])
  }, numeric(1))
}

lift <- function(risque, risque_ref) risque / risque_ref

# --- 6. AUC et précision à surface égale ------------------------------------
auc_rang <- function(score, y) {
  ok <- !is.na(score) & !is.na(y); score <- score[ok]; y <- as.logical(y[ok])
  n1 <- sum(y); n0 <- sum(!y)
  if (n1 == 0L || n0 == 0L) return(NA_real_)
  r <- rank(score)
  (sum(r[y]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# Les k (part) pixels les plus mauvais ; égalités départagées par l'ordre.
precision_rappel <- function(score, y, k) {
  ok <- !is.na(score) & !is.na(y); score <- score[ok]; y <- as.logical(y[ok])
  m <- max(1L, as.integer(ceiling(k * length(score))))
  sel <- order(-score, seq_along(score))[seq_len(m)]
  tp <- sum(y[sel])
  c(precision = tp / m, rappel = if (sum(y)) tp / sum(y) else NA_real_, n_alertes = m)
}

# --- 7. intervalle par tirage PAR ZONE ---------------------------------------
# df avec colonne `zone` ; stat(df) -> nombre. On rééchantillonne les zones.
ic_par_zone <- function(df, stat, B = 500L, graine = 45L, niveau = 0.95) {
  set.seed(graine)
  zs <- unique(df$zone)
  v <- replicate(B, {
    z <- sample(zs, length(zs), replace = TRUE)
    stat(do.call(rbind, lapply(seq_along(z), function(i) {
      d <- df[df$zone == z[i], ]; d$zone <- i; d })))
  })
  a <- (1 - niveau) / 2
  c(estim = stat(df), bas = unname(stats::quantile(v, a, na.rm = TRUE)),
    haut = unname(stats::quantile(v, 1 - a, na.rm = TRUE)))
}

# --- 8. grille commune (cas 5) -----------------------------------------------
# r10 : SpatRaster 10 m (score continu ou alerte 0/1) -> grille r20.
# Alerte : majorité (>= 2 sous-pixels sur 4, égalité = alerte).
fast_vers_20m <- function(r10, r20, alerte = FALSE) {
  m <- terra::aggregate(r10, fact = 2, fun = "mean", na.rm = TRUE)
  if (alerte) m <- m >= 0.5
  terra::resample(m, r20, method = if (alerte) "near" else "average")
}

# --- 9. reprise par zone et par étape ----------------------------------------
# Exécute fn() sauf si <dossier>/<zone>/<etape>.rds existe ; note le temps.
etape_cache <- function(dossier, zone, etape, fn,
                        journal = file.path(dossier, "durees.csv")) {
  f <- file.path(dossier, zone, paste0(etape, ".rds"))
  if (file.exists(f)) return(readRDS(f))
  dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  t0 <- Sys.time(); res <- fn()
  dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  saveRDS(res, f)
  utils::write.table(data.frame(zone = zone, etape = etape, secondes = round(dt, 1)),
                     journal, sep = ",", row.names = FALSE,
                     append = file.exists(journal), col.names = !file.exists(journal))
  res
}
