# Fonctions de l'étude FAST contre décoloration (mission 045, brief 2026-11-24).
# Fonctions pures, sans réseau, testées par tests/testthat/test-etude-fast-decoloration.R.
# Les mois sont des indices entiers  an * 12 + mois - 1  (même codage que
# `sufosat_tcoupe()` de la décoloration). Une absence de coupe vaut NA.

# Horizon principal 24 mois (décision de l'orchestrateur) : l'excès de coupe des
# niveaux 2-4 sur le niveau 0 plafonne à 24 mois (1,65 / 1,98 / 1,96 / 1,90 points
# à 12 / 24 / 36 / 46 mois, cohorte 2021) tandis que le lift baisse (6,3 / 4,1 /
# 3,3 / 2,6) : au-delà, on n'ajoute que des coupes ordinaires. 12 et 36 mois en
# sensibilité ; 46 mois en information, cohorte 2021 seule.
HORIZON_PRINCIPAL <- 24L
HORIZONS <- c(12L, 24L, 36L, 46L)
MOIS_ICD <- list(chene = 6:8, hetre = 7:8, sapin_epicea = 6:10, douglas = 4:9,
                 melange = 6:9)

# --- 1. tirage des zones ---------------------------------------------------
# communes : data.frame(commune, departement, groupe, taux_touche). Déterministe,
# comme comparaison_nemeton.R : par groupe d'essences, `n_haut` communes de plus
# fort taux (un département au plus chacune tant que c'est possible) et `n_bas`
# de plus faible taux ; égalités départagées par le nom. Les `n_melange`
# communes du groupe « melange » (hors 4 essences) sont tirées avec `graine`.
tirer_zones <- function(communes, graine = 45L, n_haut = 2L, n_bas = 1L,
                        n_melange = 2L,
                        groupes = c("chene", "hetre", "sapin_epicea", "douglas")) {
  if (is.null(communes$departement)) communes$departement <- NA_character_
  communes <- communes[order(communes$commune), , drop = FALSE]
  out <- list()
  for (g in groupes) {
    d <- communes[communes$groupe == g & is.finite(communes$taux_touche), , drop = FALSE]
    if (!nrow(d)) next
    d <- d[order(-d$taux_touche, d$commune), , drop = FALSE]
    fort <- d[!duplicated(d$departement), , drop = FALSE]
    fort <- fort[seq_len(min(n_haut, nrow(fort))), , drop = FALSE]
    if (nrow(fort) < n_haut) {
      reste <- d[!d$commune %in% fort$commune, , drop = FALSE]
      fort <- rbind(fort, reste[seq_len(min(n_haut - nrow(fort), nrow(reste))), , drop = FALSE])
    }
    fort$strate <- rep("tres_touchee", nrow(fort))
    b <- d[order(d$taux_touche, d$commune), , drop = FALSE]
    b <- b[!b$commune %in% fort$commune, , drop = FALSE]
    b <- b[seq_len(min(n_bas, nrow(b))), , drop = FALSE]
    b$strate <- rep("peu_touchee", nrow(b))
    out <- c(out, list(fort, b))
  }
  m <- communes[communes$groupe == "melange", , drop = FALSE]
  if (nrow(m) && n_melange > 0L) {
    set.seed(graine)
    m <- m[sort(sample.int(nrow(m), min(n_melange, nrow(m)))), , drop = FALSE]
    m$strate <- rep("melange", nrow(m))
    out <- c(out, list(m))
  }
  z <- do.call(rbind, out); rownames(z) <- NULL
  z$graine <- graine
  z
}

# --- 2. vérité SUFOSAT -----------------------------------------------------
# t4 : matrice n x 4 des mois de coupe des 4 sous-pixels de 10 m (NA = pas de
# coupe). Pixel de 20 m coupé si >= `min_sous` sous-pixels coupés ; sa date est
# la plus précoce des sous-pixels (règle de la décoloration, brief § 3.6).
coupe_20m <- function(t4, min_sous = 2L) {
  t4 <- as.matrix(t4)
  apply(t4, 1L, function(v) {
    v <- sort(v[!is.na(v)])
    if (length(v) >= min_sous) v[1] else NA_real_
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
  sp <- split(df, df$zone); zs <- names(sp)
  v <- replicate(B, {
    z <- sample(zs, length(zs), replace = TRUE)
    stat(do.call(rbind, sp[z]))
  })
  a <- (1 - niveau) / 2
  e <- stat(df)
  if (length(e) == 1L)   # statistique scalaire : c(estim, bas, haut)
    return(c(estim = unname(e), bas = unname(stats::quantile(v, a, na.rm = TRUE)),
             haut = unname(stats::quantile(v, 1 - a, na.rm = TRUE))))
  v <- matrix(v, nrow = length(e))   # statistique vectorielle : une ligne par composante
  data.frame(mesure = names(e), estim = unname(e),
             bas = apply(v, 1, stats::quantile, a, na.rm = TRUE, names = FALSE),
             haut = apply(v, 1, stats::quantile, 1 - a, na.rm = TRUE, names = FALSE))
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
