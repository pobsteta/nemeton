# data-raw/diagnostic_finn_processus.R
#
# Diagnostic de la calibration FINN (spec 068, etape 3) : d'ou vient le biais
# positif de FINN sur la surface terriere a 5 ans ? L'ecart G5 - G0 est
# decompose en trois parts, observees (IFN) et simulees (FINN), par hectare :
#   croissance  = accroissement en G des arbres vivants aux deux visites ;
#   mortalite   = G initiale des arbres morts dans l'intervalle (perte) ;
#   recrutement = G a 5 ans des arbres recrutes (gain).
# G5 = G0 + croissance - mortalite + recrutement, dans les deux cas.
#
# Cote FINN, G0 est celle des cohortes apres l'arrondi des effectifs par
# CohortMat (cf. FINN_PATCH_MULT dans prototype_finn_calibration.R) ; la
# difference avec G0 observee est affichee a part (« arrondi »).
#
# Lecture des cohortes simulees (FINN 0.1.0, verifie sur un mini-modele) :
# `return_cohorts` rend year = 1 apres un pas ; une cohorte initiale de rang k
# du site s (sur S sites) porte cohortID = (k - 1) * S + s ; les recrutes ont
# un rang superieur au nombre de cohortes initiales.
#
# Lancement : un modele sauvegarde par prototype_finn_calibration.R et les
# memes variables d'environnement que pour l'ajuster (tirage identique) :
#   FINN_MODELE=.../p1.pt FINN_N_TRAIN=1000 FINN_N_TEST=1000 FINN_PATCH_MULT=1 \
#     FINN_N_PRED=10 Rscript data-raw/diagnostic_finn_processus.R

stopifnot(nzchar(Sys.getenv("FINN_MODELE")), file.exists(Sys.getenv("FINN_MODELE")))
source("data-raw/prototype_finn_calibration.R")

g_arbre <- function(d) pi * (d / 200)^2

decomposer_obs <- function(ids) {
  map <- data.table(siteID = sort(ids))[, s := .I]
  x <- merge(tr[siteID %in% ids], map, by = "siteID")
  x[, .(
    croissance = sum((W1 * (g_arbre(d2) - g_arbre(d1)))[statut == "vivant"]),
    mortalite = sum((W1 * g_arbre(d1))[statut == "mort"]),
    recrutement = sum((W2 * g_arbre(d2))[statut == "recrute"]),
    g0 = sum((W1 * g_arbre(d1))[statut %in% c("vivant", "mort")])
  ), by = .(siteID = s)]
}

decomposer_finn <- function(d) {
  S <- d$init$dims[1]; K <- d$init$dims[3]
  t0 <- as.array(d$init$trees)[, 1, ]; d0 <- as.array(d$init$dbh)[, 1, ]
  sp0 <- as.array(d$init$species)[, 1, ]
  if (is.null(dim(t0))) { t0 <- matrix(t0, S); d0 <- matrix(d0, S); sp0 <- matrix(sp0, S) }
  init <- data.table(siteID = rep(seq_len(S), K), k = rep(seq_len(K), each = S),
                     t0 = as.vector(t0), d0 = as.vector(d0), sp0 = as.vector(sp0))[t0 > 0]
  m$eval()
  rbindlist(lapply(seq_len(n_pred), function(i) {
    sim <- predict(m, env = d$env, init_cohort = d$init, patches = 1L,
                   patch_size = patch_size, device = "cpu", return_cohorts = 1L)
    coh <- dcast(as.data.table(sim$long$cohort)[year == 1L],
                 siteID + species + cohortID ~ variable, value.var = "value")
    coh[, k := (cohortID - siteID) %/% S + 1L]
    rec <- coh[k > K & trees > 0, .(recrutement = sum(trees * g_arbre(dbh))), by = siteID]
    surv <- merge(init, coh[k <= K, .(siteID, k, sp1 = species, t1 = trees, d1 = dbh)],
                  by = c("siteID", "k"), all.x = TRUE)
    # une cohorte absente de la sortie est morte
    surv[is.na(t1), `:=`(t1 = 0, d1 = 0)]
    stopifnot(surv[t1 > 0, all(sp1 == sp0)])
    out <- surv[, .(croissance = sum(t1 * (g_arbre(d1) - g_arbre(d0))),
                    mortalite = sum((t0 - pmin(t1, t0)) * g_arbre(d0)),
                    g0 = sum(t0 * g_arbre(d0))), by = siteID]
    out <- merge(out, rec, by = "siteID", all.x = TRUE)
    out[is.na(recrutement), recrutement := 0][, tirage := i][]
  }))[, lapply(.SD, mean), by = siteID, .SDcols = c("croissance", "mortalite", "recrutement", "g0")]
}

comparer <- function(d, ids, label) {
  o <- decomposer_obs(ids); f <- decomposer_finn(d)
  x <- merge(o, f, by = "siteID", suffixes = c("_obs", "_finn"))
  parts <- c("g0", "croissance", "mortalite", "recrutement")
  res <- rbindlist(lapply(parts, function(p) {
    a <- x[[paste0(p, "_obs")]] / patch_size; b <- x[[paste0(p, "_finn")]] / patch_size
    data.table(echantillon = label, part = p, observe = mean(a), finn = mean(b),
               ecart = mean(b - a), rmse = sqrt(mean((b - a)^2)))
  }))
  res[part == "g0", part := "g0 (arrondi)"]
  res[, n := nrow(x)][]
}

# W1 et W2 sont des poids a l'hectare : on les ramene a la placette FINN pour
# reutiliser la meme division par patch_size que cote FINN.
tr[, `:=`(W1 = W1 * patch_size, W2 = W2 * patch_size)]
diag <- rbind(comparer(train, id_train, "calibration"), comparer(test, id_test, "tenu a l'ecart"))
cat("\nDecomposition de G5 - G0 (m2/ha), moyennes par placette ; ecart = FINN - observe\n")
print(diag[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
