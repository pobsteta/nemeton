# data-raw/recalibration_finn_bfc.R
#
# Recalibration de FINN sur toutes les placettes de BFC disponibles (spec 068,
# decision D-G du 2026-11-13) : le diagnostic du biais de croissance
# (data-raw/diagnostic_biais_croissance.R) montre une relation
# densite-croissance trop plate. Hypothese a tester : 1 000 placettes de
# calibration ne suffisent pas. On calibre sur toutes les placettes qui ne
# sont ni dans le jeu conforme ni dans le test (5 632), puis on mesure avec le
# meme diagnostic sur le test (FINN_DIAG_ENSEMBLE=test).
#
# Variables :
#   FINN_INC_DONNEES      donnees.rds (data-raw/prototype_finn_incertitude.R) ;
#   FINN_RECAL_DOSSIER    dossier de sortie (calibration.pt / .rds, comme
#                         simulation_catalogue_bfc.R, pour reutiliser ses
#                         scripts) ;
#   FINN_RECAL_EPOQUES    defaut 200 : avec des lots de 50 placettes, 5 632
#                         placettes x 200 epoques font 22 500 pas d'optimiseur,
#                         contre 12 000 pour 1 000 x 600 ;
#   FINN_RECAL_POIDS      « auto » (defaut) ou six poids « dbh=..,ba=..,... »
#                         (calibrer_finn(poids_perte =)) ;
#   FINN_THREADS          threads torch, defaut 4 (deux runs en parallele sur
#                         8 coeurs).
#   FINN_RECAL_PLACETTES  facultatif : fichier texte d'identifiants IFN (un
#                         par ligne) ; calibration et conforme sont restreints
#                         a ces placettes (spec 069 S-1 : reference d'avant
#                         les crises, revisites 2015-2017).

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
d <- readRDS(Sys.getenv("FINN_INC_DONNEES"))
dossier <- Sys.getenv("FINN_RECAL_DOSSIER")
stopifnot(nzchar(dossier))
dir.create(dossier, showWarnings = FALSE, recursive = TRUE)
epoques <- as.integer(Sys.getenv("FINN_RECAL_EPOQUES", "200"))
poids <- Sys.getenv("FINN_RECAL_POIDS", "auto")
if (!identical(poids, "auto")) {
  kv <- strsplit(strsplit(poids, ",")[[1]], "=")
  poids <- stats::setNames(as.numeric(vapply(kv, `[`, "", 2)), vapply(kv, `[`, "", 1))
}
torch::torch_set_num_threads(as.integer(Sys.getenv("FINN_THREADS", "4")))

train <- setdiff(unique(d$env$placette), c(d$conforme, d$test))
f_pla <- Sys.getenv("FINN_RECAL_PLACETTES")
if (nzchar(f_pla)) {
  garder <- readLines(f_pla)
  train <- intersect(train, garder)
  d$conforme <- intersect(d$conforme, garder)
  cat(sprintf("restreint a %s : %d placettes de conforme\n", f_pla, length(d$conforme)))
}
cat(sprintf("calibration sur %d placettes, %d epoques, poids %s\n", length(train), epoques,
            paste(format(poids), collapse = " ")))
t0 <- Sys.time()
cal <- calibrer_finn(d$arbres[placette %in% train], d$env[placette %in% train],
                     epoques = epoques, poids_perte = poids,
                     dossier = file.path(dossier, "points"))
cat(sprintf("calibration : %s ; essences %s\n", format(round(Sys.time() - t0, 1)),
            paste(cal$essences, collapse = ", ")))
t1 <- Sys.time()
cal <- conformer_finn(cal, d$arbres[placette %in% d$conforme], d$env[placette %in% d$conforme])
cat(sprintf("conforme : demi-largeur %.2f m2/ha a 5 ans (%s)\n", cal$conforme$demi_largeur,
            format(round(Sys.time() - t1, 1))))
torch::torch_save(cal$modele$clone(deep = FALSE), file.path(dossier, "calibration.pt"))
cal$modele <- NULL
saveRDS(cal, file.path(dossier, "calibration.rds"))
cat("fin\n")
