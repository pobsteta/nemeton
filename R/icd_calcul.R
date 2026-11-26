# ICD : calculs purs (matrices et vecteurs), sans disque ni reseau (spec 071).

# Mediane par ligne, NA ignores ; NA si la ligne est entierement NA.
.icd_med_lignes <- function(M) {
  if (!is.matrix(M)) M <- matrix(M, ncol = 1L)
  if (requireNamespace("matrixStats", quietly = TRUE)) {
    return(matrixStats::rowMedians(M, na.rm = TRUE))
  }
  apply(M, 1L, function(v) if (all(is.na(v))) NA_real_ else stats::median(v))
}

# Composite mensuel (note, section 5) : mediane des valeurs valides des
# images du mois. `M` : cellules x images. Un mois sans image valide reste NA.
.icd_composite <- function(M) .icd_med_lignes(M)

# Codes SUFOSAT AAJJJ (annee sur deux chiffres, jour de l'annee) <-> Date :
# les fonctions de la spec 070, sans recopie. 0 et NA = jamais coupe ; un code
# invalide (jour hors 1..366) est une erreur.
.icd_yyddd_vers_date <- function(x) reconfort_coupe_decoder(as.numeric(x))$date

.icd_date_vers_yyddd <- function(d) reconfort_coupe_encoder(as.Date(d))

# Retire du calcul un pixel a partir du mois de sa coupe (note, section 6).
# `X` : cellules x annees pour UN mois `mois` ; `annees` : annee de chaque
# colonne ; `date_coupe` : Date par cellule (NA = jamais coupe).
.icd_retirer_coupes <- function(X, annees, mois, date_coupe) {
  if (is.null(date_coupe)) return(X)
  dm <- as.integer(format(date_coupe, "%Y")) * 12L +
    as.integer(format(date_coupe, "%m"))
  for (j in seq_along(annees)) {
    coupe <- !is.na(dm) & (annees[j] * 12L + mois) >= dm
    X[coupe, j] <- NA_real_
  }
  X
}

# Anomalie standardisee (note, section 6), un indice, un mois.
#   z = (x - mediane des autres annees) / max(MAD * 1,4826 ; plancher)
# `X` : cellules x annees. La reference d'une annee est l'ensemble des autres
# annees (ou des `annees_reference` privees de l'annee elle-meme). Moins de
# `min_ref` annees de reference valides : NA.
.icd_z <- function(X, annees, plancher, annees_reference = NULL,
                   min_ref = .ICD_MIN_REF) {
  if (!is.matrix(X)) X <- matrix(X, ncol = 1L)
  stopifnot(ncol(X) == length(annees))
  ref_ok <- if (is.null(annees_reference)) rep(TRUE, length(annees))
            else annees %in% annees_reference
  Z <- matrix(NA_real_, nrow(X), ncol(X))
  for (j in seq_along(annees)) {
    cols <- which(ref_ok & seq_along(annees) != j)
    if (length(cols) < min_ref) next
    R <- X[, cols, drop = FALSE]
    n_val <- rowSums(!is.na(R))
    med <- .icd_med_lignes(R)
    mad <- .icd_med_lignes(abs(R - med)) * .ICD_MAD_ECHELLE
    z <- (X[, j] - med) / pmax(mad, plancher)
    z[n_val < min_ref] <- NA_real_
    Z[, j] <- z
  }
  Z
}

# ICD (note, section 7) : somme signee ponderee des z. `zlist` : liste nommee
# de vecteurs (un par indice) ; `w` : poids nommes d'une essence. Un indice
# de poids non nul dont le z manque donne NA (pas de somme partielle).
.icd_icd <- function(zlist, w) {
  n <- length(zlist[[1L]])
  out <- numeric(n)
  for (i in names(w)[w > 0]) {
    out <- out + .ICD_SIGNES[[i]] * w[[i]] * zlist[[i]]
  }
  out
}

# Classe annuelle (note, section 8) sur une matrice cellules x mois suivis
# (colonnes dans l'ordre chronologique, mois consecutifs). Alerte : ICD < -2
# pendant au moins 2 mois consecutifs valides (un mois NA rompt la suite) ;
# date d'alerte = premier mois de la premiere suite ; Surveillance : ICD < -1,5
# au moins un mois ; Normal sinon. 0 / 1 / 2 ; NA si aucun mois valide.
.icd_classe_annuelle <- function(M, mois, persistance = .ICD_PERSISTANCE) {
  M <- as.matrix(M)
  n <- nrow(M); k <- ncol(M)
  icd_min <- rep(NA_real_, n)
  valides <- if (k) rowSums(!is.na(M)) else rep(0L, n)
  if (k) {
    icd_min[valides > 0] <- suppressWarnings(
      apply(M[valides > 0, , drop = FALSE], 1L, min, na.rm = TRUE))
  }
  surv  <- if (k) rowSums(M < .ICD_SEUIL_SURVEILLANCE, na.rm = TRUE) > 0 else rep(FALSE, n)
  mois_alerte <- rep(NA_integer_, n)
  alerte <- rep(FALSE, n)
  if (k >= persistance) {
    bas <- M < .ICD_SEUIL_ALERTE
    bas[is.na(bas)] <- FALSE
    # suites de `persistance` mois consecutifs sous le seuil : une colonne par
    # mois de depart possible
    debuts <- seq_len(k - persistance + 1L)
    suite <- bas[, debuts, drop = FALSE]
    for (d in seq_len(persistance - 1L)) {
      suite <- suite & bas[, debuts + d, drop = FALSE]
    }
    alerte <- rowSums(suite) > 0
    prem <- max.col(suite, ties.method = "first")
    mois_alerte[alerte] <- as.integer(mois[prem[alerte]])
  }
  classe <- ifelse(valides == 0, NA_real_,
                   ifelse(alerte, 2, ifelse(surv, 1, 0)))
  list(classe = classe, icd_min = icd_min, mois_alerte = mois_alerte,
       n_mois_valides = as.integer(valides))
}

# Niveaux 0 a 4 (note, section 8), repris de niveaux_decoloration() de
# data-raw/etude_fast_decoloration/ : 3 = alerte et ICD minimal < -3 ;
# 4 = alerte cette annee et sur la saison complete de l'annee precedente.
.icd_niveaux <- function(classe, icd_min, classe_prec) {
  n <- classe
  n[!is.na(classe) & classe == 2 & !is.na(icd_min) & icd_min < .ICD_SEUIL_FORTE] <- 3
  n[!is.na(classe) & classe == 2 & !is.na(classe_prec) & classe_prec == 2] <- 4
  n
}

# Mois (parmi avril-octobre) que l'on peut lire a la date `today` pour
# l'annee en cours (indice "a date", note section 8) : les mois termines, et le
# mois en cours seulement s'il est entame depuis au moins 20 jours.
.icd_mois_utilisables <- function(today = Sys.Date()) {
  today <- as.Date(today)
  m <- as.integer(format(today, "%m"))
  j <- as.integer(format(today, "%d"))
  if (m > max(.ICD_MOIS_SAISON)) return(.ICD_MOIS_SAISON)
  fin <- if (j >= .ICD_JOURS_INDICE_DATE) m else m - 1L
  .ICD_MOIS_SAISON[.ICD_MOIS_SAISON <= fin]
}

# Un mois est "en cours" tant qu'il n'est pas termine depuis 5 jours.
.icd_mois_en_cours <- function(annee, mois, today = Sys.Date()) {
  debut_suivant <- as.Date(sprintf("%04d-%02d-01", annee + (mois == 12L),
                                   if (mois == 12L) 1L else mois + 1L))
  as.Date(today) < debut_suivant + .ICD_JOURS_MOIS_COURS
}

# Cohen's kappa entre deux vecteurs de meme longueur (NA ecartes).
.icd_kappa <- function(a, b) {
  ok <- !is.na(a) & !is.na(b)
  a <- a[ok]; b <- b[ok]
  n <- length(a)
  if (n == 0L) return(NA_real_)
  niv <- sort(unique(c(a, b)))
  ta <- table(factor(a, niv)); tb <- table(factor(b, niv))
  po <- mean(a == b)
  pe <- sum(as.numeric(ta) * as.numeric(tb)) / n^2
  if (isTRUE(all.equal(pe, 1))) return(NA_real_)
  (po - pe) / (1 - pe)
}

# Classes 0-4 de FAST comme l'app (repris de classes_fast() de l'etude) :
# 0 = pas d'alerte, 1-4 = quartiles des valeurs > 0.
.icd_classes_fast <- function(score) {
  cl <- rep(NA_real_, length(score)); ok <- !is.na(score)
  cl[ok] <- 0
  pos <- ok & score > 0
  if (any(pos)) {
    q <- unique(stats::quantile(score[pos], c(.25, .5, .75), names = FALSE))
    cl[pos] <- 1 + findInterval(score[pos], q, left.open = TRUE)
  }
  cl
}
