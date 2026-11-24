# Fonctions de comparaison (suite de fonctions.R, à sourcer après lui).
# Pures, testées par tests/testthat/test-etude-fast-decoloration.R.

# Vérité à l'horizon h : TRUE si coupe dans h mois ; FALSE si suivi >= h sans coupe ;
# NA si censuré avant h (la cohorte ne compte pas à cet horizon).
vrai_sous_h <- function(delai, evenement, censure, h = HORIZON_PRINCIPAL) {
  ifelse(evenement & delai <= h, TRUE, ifelse(censure >= h, FALSE, NA))
}

# alerte_AAAA.tif ne porte que classe 0/1/2 et icd_min : niveau 3 = classe 2 et
# icd_min < -3 ; niveau 4 = classe 2 cette année et classe 2 l'année précédente.
niveaux_decoloration <- function(classe, icd_min, classe_prec) {
  n <- classe
  n[!is.na(classe) & classe == 2 & !is.na(icd_min) & icd_min < -3] <- 3
  n[!is.na(classe) & classe == 2 & !is.na(classe_prec) & classe_prec == 2] <- 4
  n
}

# Classes 0-4 de FAST comme l'app : 0 = pas d'alerte, 1-4 = quartiles des valeurs > 0.
classes_fast <- function(score) {
  cl <- rep(NA_real_, length(score)); ok <- !is.na(score)
  cl[ok] <- 0
  pos <- ok & score > 0
  if (any(pos)) {
    q <- unique(stats::quantile(score[pos], c(.25, .5, .75), names = FALSE))
    cl[pos] <- 1 + findInterval(score[pos], q, left.open = TRUE)
  }
  cl
}

# Croisement des classes en surfaces (pixel de 20 m = 0,04 ha).
croisement_classes <- function(classe_fast, niveau_dec, pixel_ha = 0.04) {
  t <- table(fast = ifelse(is.na(classe_fast), "manquant", classe_fast),
             decoloration = ifelse(is.na(niveau_dec), "manquant", niveau_dec))
  d <- as.data.frame(t, responseName = "n_pixels", stringsAsFactors = FALSE)
  d$surface_ha <- d$n_pixels * pixel_ha
  d
}

# Part des coupes vues par FAST seul, décoloration seule, les deux, aucune.
part_coupes_vues <- function(alerte_fast, alerte_dec, evenement) {
  k <- ifelse(alerte_fast & alerte_dec, "les_deux", ifelse(alerte_fast, "fast_seul",
       ifelse(alerte_dec, "decoloration_seule", "aucune")))
  t <- table(factor(k[evenement], c("fast_seul", "decoloration_seule", "les_deux", "aucune")))
  data.frame(vue_par = names(t), n_coupes = as.integer(t), part = as.numeric(t) / max(1, sum(t)))
}

# Garde-fou : l'étude ne touche JAMAIS la base de production (NEMETON_DB_URL).
isoler_base <- function(dossier) {
  Sys.unsetenv("NEMETON_DB_URL")
  paste0("sqlite:///", normalizePath(dossier, mustWork = FALSE), "/etude.sqlite")
}

# Fenêtres FAST de l'année a : count/rolling sur la saison de a aux mois de l'ICD
# de l'essence ; trend sur a-3 ... a.
fenetres_fast <- function(a, mois) {
  fin <- function(an, m) as.character(as.Date(sprintf("%d-%02d-01", an + (m == 12L), if (m == 12L) 1L else m + 1L)) - 1)
  list(saison = c(from = sprintf("%d-%02d-01", a, min(mois)), to = fin(a, max(mois))),
       trend  = c(from = sprintf("%d-01-01", a - 3L), to = sprintf("%d-12-31", a)))
}
