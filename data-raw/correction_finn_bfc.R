# data-raw/correction_finn_bfc.R
#
# Correction de l'accroissement de FINN (spec 068, decision D-G option 1,
# appliquee par defaut, decision du 2026-11-14) : corriger_finn() sur le jeu
# conforme, puis conformer_finn() sur les memes placettes (l'intervalle est
# remesure apres correction). On mesure ensuite sur le test avec
# data-raw/diagnostic_biais_croissance.R (FINN_SIM_DOSSIER = FINN_CORR_SORTIE).
#
# Variables : FINN_INC_DONNEES (donnees.rds), FINN_SIM_DOSSIER (calibration
# de depart), FINN_CORR_SORTIE (dossier de sortie), FINN_CORR_TIRAGES (defaut
# 3), FINN_CORR_ITERATIONS (defaut 2), FINN_THREADS.

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
d <- readRDS(Sys.getenv("FINN_INC_DONNEES"))
dossier <- Sys.getenv("FINN_SIM_DOSSIER")
sortie <- Sys.getenv("FINN_CORR_SORTIE")
stopifnot(nzchar(sortie))
dir.create(sortie, showWarnings = FALSE, recursive = TRUE)
torch::torch_set_num_threads(as.integer(Sys.getenv("FINN_THREADS", "4")))
cal <- readRDS(file.path(dossier, "calibration.rds"))
cal$modele <- torch::torch_load(file.path(dossier, "calibration.pt"))
set.seed(17)

conf <- d$conforme
a <- d$arbres[placette %in% conf]; e <- d$env[placette %in% conf]
t0 <- Sys.time()
cal <- corriger_finn(cal, a, e,
                     n_tirages = as.integer(Sys.getenv("FINN_CORR_TIRAGES", "3")),
                     iterations = as.integer(Sys.getenv("FINN_CORR_ITERATIONS", "2")))
cat(sprintf("correction : %s\n", format(round(Sys.time() - t0, 1))))
print(cal$correction$suivi)
cat("\nfacteurs :\n"); print(round(cal$correction$facteurs, 3))
t1 <- Sys.time()
cal <- conformer_finn(cal, a, e)
cat(sprintf("\nconforme : demi-largeur %.2f m2/ha a 5 ans (%s)\n", cal$conforme$demi_largeur,
            format(round(Sys.time() - t1, 1))))
torch::torch_save(cal$modele$clone(deep = FALSE), file.path(sortie, "calibration.pt"))
cal$modele <- NULL
saveRDS(cal, file.path(sortie, "calibration.rds"))
cat("fin\n")
