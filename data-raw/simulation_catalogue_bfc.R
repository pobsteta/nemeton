# data-raw/simulation_catalogue_bfc.R
#
# Premiere simulation reelle des itineraires sources du catalogue (spec 065 /
# spec 068) sur des placettes IFN de BFC, avec FINN calibre par le coeur.
#
# Etapes (variable FINN_SIM_ETAPE) :
#   donnees   : table d'arbres et d'environnement de BFC, tirages calibration /
#               test / conforme (delegue a prototype_finn_incertitude.R,
#               etape « donnees ») -> FINN_INC_DONNEES ;
#   calibrer  : calibrer_finn() sur les 1 000 placettes de calibration (0,7 ha,
#               600 epoques, lr 0,003, garde-fou 300 arbres par essence), puis
#               conformer_finn() sur les 1 000 placettes « conforme » ; modele
#               dans FINN_SIM_DOSSIER (calibration.pt + calibration.rds) ;
#   simuler   : pour chaque itineraire source, les placettes tenues a l'ecart
#               dont l'essence dominante en G est une essence objectif (toutes
#               si le domaine n'en fixe pas), FINN_SIM_N placettes au plus ;
#               l'itineraire et « sans_gestion » sur les memes placettes,
#               50 ans, 10 tirages, volume et carbone ; table longue dans
#               FINN_SIM_DOSSIER/trajectoires<suffixe>.rds et resume a 50 ans
#               imprime (resume_horizon<suffixe>.csv).
#
# Plafond de densite (FINN_SIM_PLAFOND, defaut « oui ») : densite_max_ifn()
# sur la premiere visite de toutes les placettes BFC (quantile 99 %), passe a
# simuler_itineraire() ; « non » reproduit la premiere simulation, sans
# plafond (diagnostic : data-raw/diagnostic_plafond_finn.R). FINN_SIM_SUFFIXE
# distingue les sorties (defaut vide).
#
# Choix (a relire) : l'essence dominante est lue sur l'etat initial (arbres
# vivants, G) ; les placettes de test n'ont servi ni a la calibration ni aux
# residus conformes ; une seule calibration (la variance d'optimisation est
# negligeable, spec 068) ; pas de SER : tarif de Schaeffer France par essence.
# Les modeles et les sorties restent hors du depot.

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
etape <- Sys.getenv("FINN_SIM_ETAPE", "simuler")
f_donnees <- Sys.getenv("FINN_INC_DONNEES")
dossier <- Sys.getenv("FINN_SIM_DOSSIER")
n_max <- as.integer(Sys.getenv("FINN_SIM_N", "60"))
horizon <- as.numeric(Sys.getenv("FINN_SIM_HORIZON", "50"))
plafond <- Sys.getenv("FINN_SIM_PLAFOND", "oui") == "oui"
suffixe <- Sys.getenv("FINN_SIM_SUFFIXE", "")
stopifnot(nzchar(f_donnees), nzchar(dossier))
dir.create(dossier, showWarnings = FALSE, recursive = TRUE)
f_cal <- file.path(dossier, "calibration")

if (etape == "donnees") {
  Sys.setenv(FINN_INC_ETAPE = "donnees", FINN_INC_DOSSIER = dossier)
  source("data-raw/prototype_finn_incertitude.R")
}

d <- readRDS(f_donnees)
sous <- function(p) list(a = d$arbres[placette %in% p], e = d$env[placette %in% p])

if (etape == "calibrer") {
  t0 <- Sys.time()
  x <- sous(d$train)
  cal <- calibrer_finn(x$a, x$e)
  cat(sprintf("calibration : %s ; essences %s\n", format(round(Sys.time() - t0, 1)),
              paste(cal$essences, collapse = ", ")))
  y <- sous(d$conforme)
  cal <- conformer_finn(cal, y$a, y$e)
  cat(sprintf("conforme : demi-largeur %.2f m2/ha a 5 ans\n", cal$conforme$demi_largeur))
  torch::torch_save(cal$modele$clone(deep = FALSE), paste0(f_cal, ".pt"))
  m <- cal$modele; cal$modele <- NULL
  saveRDS(cal, paste0(f_cal, ".rds"))
  quit(save = "no")
}

# --- simulation ---------------------------------------------------------------
cal <- readRDS(paste0(f_cal, ".rds"))
cal$modele <- torch::torch_load(paste0(f_cal, ".pt"))

init <- d$arbres[placette %in% d$test & statut %in% c("vivant", "mort") & is.finite(d1)]
dom <- init[, .(g = sum(poids * pi * (d1 / 200)^2)), by = .(placette, essence)][
  order(placette, -g)][, .SD[1], by = placette]
dm <- if (plafond) densite_max_ifn(d$arbres) else NULL
if (plafond) print(dm)
cat_it <- itineraires_catalogue()
sources <- Filter(function(it) identical(it$statut_source, "source"), cat_it)

# placettes de chaque itineraire tirees avant toute simulation : les tirages
# de FINN et des coupes consomment le generateur, les variantes (avec ou sans
# plafond) doivent porter sur les memes placettes
set.seed(11)
tirage <- lapply(sources, function(it) {
  ess <- unlist(it$domaine$essences_objectif)
  p <- if (length(ess)) dom[essence %in% ess, placette] else dom$placette
  if (length(p) > n_max) sample(p, n_max) else p
})
res <- list()
for (i_it in seq_along(sources)) {
  it <- sources[[i_it]]
  p <- tirage[[i_it]]
  if (!length(p)) {
    cat(sprintf("%s : aucune placette de test a essence objectif\n", it$code))
    next
  }
  x <- sous(p)
  t0 <- Sys.time()
  sim <- function(i) simuler_itineraire(cal, x$a, x$e, itineraire = i, horizon = horizon,
                                        n_tirages = 10L, volume = TRUE, carbone = TRUE,
                                        densite_max = dm)
  a <- sim(it)
  b <- sim(NULL)
  a$groupe <- it$code; b$groupe <- it$code
  res[[it$code]] <- rbind(a, b)
  cat(sprintf("%s : %d placettes, %s\n", it$code, length(p), format(round(Sys.time() - t0, 1))))
}
traj <- rbindlist(res, fill = TRUE)
saveRDS(traj, file.path(dossier, paste0("trajectoires", suffixe, ".rds")))

# resume : moyenne des placettes, a l'horizon (G, volume, carbone) et cumul
# des prelevements
fin <- traj[annee == horizon & variable %in% c("g", "volume", "carbone"),
            .(valeur = mean(moyenne)), by = .(groupe, itineraire, variable)]
cum <- traj[variable %in% c("g_prelevee", "volume_preleve"),
            .(valeur = sum(moyenne) / uniqueN(placette)), by = .(groupe, itineraire, variable)]
tab <- dcast(rbind(fin, cum), groupe + itineraire ~ variable, value.var = "valeur")
n_pla <- traj[, .(n = uniqueN(placette)), by = groupe]
tab <- merge(tab, n_pla, by = "groupe")
setcolorder(tab, c("groupe", "n", "itineraire"))
num <- setdiff(names(tab), c("groupe", "itineraire", "n"))
tab[, (num) := lapply(.SD, round, 1), .SDcols = num]
print(tab)
fwrite(tab, file.path(dossier, paste0("resume_horizon", suffixe, ".csv")))
