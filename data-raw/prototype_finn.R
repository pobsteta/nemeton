# data-raw/prototype_finn.R
#
# Prototype FINN (spec 068, etape 2, decision D-2) : peut-on simuler un
# itineraire sylvicole avec FINN en retirant des arbres ENTRE deux pas de
# simulation ? FINN 0.1.0 n'a qu'une perturbation qui vide des placettes
# entieres (`disturbance`, fraction de placettes detruites) : pas de coupe
# selective. On teste ici :
#   1. une simulation de reference (mecaniste, parametres de la vignette A de
#      FINN : NON calibres, ce sont des ordres de grandeur d'API, pas une foret) ;
#   2. la meme, interrompue tous les `pas` ans : cohortes rendues
#      (`return_cohorts = "last"`), eclaircie par le haut appliquee a la table,
#      reprise par `init_cohort = CohortMat(obs_df = ...)` ;
#   3. le temps de calcul CPU pour 100 sites x 100 placettes x 50 ans.
#
# Lancement (FINN et torch installes, libtorch telecharge) :
#   Rscript data-raw/prototype_finn.R
# Rien n'est ecrit dans le paquet : le script affiche ses resultats.

suppressMessages({
  library(FINN)
  library(data.table)
})

FINN.seed(1234)
Nsp <- 5L
patch_size <- 0.1

# --- 1. Modele mecaniste : parametres de la vignette A de FINN (5 especes) ---
shadeSP <- c(0.1, 0.2, 0.5, 0.5, 0.7)
parReg <- shadeSP
parRegEnv <- matrix(c(c(1, 2, 3, 3, 5), runif(Nsp, -2, 2)), Nsp, 2)
parGrowth <- matrix(c(shadeSP, c(0.04, 0.05, 0.05, 0.06, 0.1)), Nsp, 2)
parGrowthEnv <- matrix(c(c(0.2, 0.3, 0.5, 1, 1) * 0.5, runif(Nsp, -2, -0.5)), Nsp, 2)
parMort <- matrix(c(as.numeric(scale(shadeSP)), as.numeric(scale(parGrowth[, 2])),
                    rep(0, Nsp)), Nsp, 3)
parMortEnv <- matrix(c(runif(Nsp, -3, -2), runif(Nsp, -3, -2)), Nsp, 2)

modele <- function() {
  finn(
    N_species = Nsp,
    competition_process = createProcess(~0, func = FINN::competition),
    growth_process = createProcess(~ 1 + env1, initEnv = parGrowthEnv,
                                   initSpecies = parGrowth, func = FINN::growth),
    regeneration_process = createProcess(~ 1 + env1, initEnv = parRegEnv,
                                         initSpecies = parReg, func = FINN::regeneration),
    mortality_process = createProcess(~ 1 + env1, initEnv = parMortEnv,
                                      initSpecies = parMort, func = FINN::mortality)
  )
}

env_annees <- function(n_sites, n_annees) {
  e <- data.table(expand.grid(siteID = seq_len(n_sites), year = seq_len(n_annees)))
  e$env1 <- 0
  e
}

ba_site <- function(sim) {
  s <- sim$long$site
  s[variable == "ba", .(ba_ha = sum(value) / patch_size), by = .(siteID, year)]
}

# --- 2. Reference : 150 ans sans gestion ------------------------------------
n_sites <- 1L; n_patches <- 50L
m <- modele()
ref <- simulateForest(m, env = env_annees(n_sites, 150L), patches = n_patches,
                      patch_size = patch_size, device = "cpu")
ba_ref <- ba_site(ref)
cat("Reference : surface terriere (m2/ha) aux annees 50, 100, 150 :",
    round(ba_ref[year %in% c(50, 100, 150), ba_ha], 1), "\n")

# --- 3. Meme modele, interrompu tous les `pas` ans, eclaircie par le haut ---
# Eclaircie : retirer `taux` des tiges des cohortes de diametre >= `dmin`.
eclaircie <- function(coh, taux = 0.3, dmin = 20) {
  coh <- copy(coh)
  k <- coh$dbh >= dmin & coh$trees > 0
  # tirage binomial par cohorte : une cohorte d'une seule tige (cas des gros
  # arbres sur une placette de 0,1 ha) est coupee avec la probabilite `taux` ;
  # arrondir trees * (1 - taux) ne couperait jamais rien.
  coh$trees[k] <- stats::rbinom(sum(k), size = as.integer(coh$trees[k]), prob = 1 - taux)
  coh
}

simuler_par_pas <- function(n_annees, pas, intervention = NULL, debut = 50L) {
  m <- modele()
  init <- NULL
  ba <- list()
  annee0 <- 0L
  while (annee0 < n_annees) {
    duree <- min(pas, n_annees - annee0)
    sim <- simulateForest(m, env = env_annees(n_sites, duree), patches = n_patches,
                          patch_size = patch_size, init_cohort = init, device = "cpu",
                          return_cohorts = "last")
    b <- ba_site(sim); b$year <- b$year + annee0
    ba[[length(ba) + 1L]] <- b
    # cohortes du dernier pas, format long (variable / value) -> large
    coh <- as.data.table(sim$long$cohort)
    coh <- dcast(coh[year == max(year)], siteID + patchID + species + cohortID ~ variable,
                 value.var = "value")
    if (!is.null(intervention) && annee0 + duree >= debut) coh <- intervention(coh)
    coh <- coh[trees > 0, .(siteID, patchID, cohortID = seq_len(.N), species, dbh, trees)]
    init <- if (nrow(coh)) CohortMat$new(obs_df = as.data.frame(coh), sp = Nsp) else NULL
    annee0 <- annee0 + duree
  }
  rbindlist(ba)
}

t0 <- Sys.time()
sans <- simuler_par_pas(150L, pas = 10L)
avec <- simuler_par_pas(150L, pas = 10L, intervention = eclaircie)
cat("Par pas de 10 ans, sans gestion :", round(sans[year %in% c(50, 100, 150), ba_ha], 1), "\n")
cat("Par pas de 10 ans, eclaircie 30 % des >= 20 cm des 50 ans :",
    round(avec[year %in% c(50, 100, 150), ba_ha], 1), "\n")
cat("Duree des deux simulations par pas :", format(round(Sys.time() - t0, 1)), "\n")

# --- 4. Temps : 100 sites x 100 placettes x 50 ans --------------------------
t1 <- Sys.time()
invisible(simulateForest(modele(), env = env_annees(100L, 50L), patches = 100L,
                         patch_size = patch_size, device = "cpu"))
cat("100 sites x 100 placettes x 50 ans, CPU :", format(round(Sys.time() - t1, 1)), "\n")
