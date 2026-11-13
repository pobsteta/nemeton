# data-raw/diagnostic_biais_croissance.R
#
# Diagnostic du biais de croissance de FINN par densite et par essence
# (spec 068, suite de la note du 2026-11-13). Le biais moyen d'un pas est
# presque nul (+0,33 m2/ha), mais il change de signe avec la densite :
# FINN croit trop de 10 a 50 m2/ha et pas assez au-dela
# (diagnostic_plafond_finn.R). D'ou vient-il : croissance des survivants et
# recrutement, ou mortalite ? Depend-il de l'essence ?
#
# Sur toutes les placettes hors calibration et hors conforme, non coupees
# entre les visites : un pas FINN (10 tirages), decompose avec la mortalite
# par cohorte que rend .itin_un_pas() (attribut "morts", G au diametre
# d'entree). Simule : mortalite = G des morts ; croissance + recrutement =
# G1 - G0 + mortalite. Observe : memes parts depuis l'IFN (vivants d2 - d1,
# morts d1, recrutes d2).
#
# Variables : FINN_INC_DONNEES (donnees.rds), FINN_SIM_DOSSIER (calibration),
# FINN_DIAG_TIRAGES (defaut 3), FINN_DIAG_N (placettes au plus par classe de G
# initiale, defaut 500 ; 0 = toutes). Sortie :
# FINN_SIM_DOSSIER/biais_croissance.rds.

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
d <- readRDS(Sys.getenv("FINN_INC_DONNEES"))
dossier <- Sys.getenv("FINN_SIM_DOSSIER")
n_tir <- as.integer(Sys.getenv("FINN_DIAG_TIRAGES", "3"))
n_classe <- as.integer(Sys.getenv("FINN_DIAG_N", "500"))
cal <- readRDS(file.path(dossier, "calibration.rds"))
cal$modele <- torch::torch_load(file.path(dossier, "calibration.pt"))
m <- cal$modele; m$eval()
sp <- cal$surface_placette
ga <- function(x) pi * (x / 200)^2
set.seed(11)

hors <- setdiff(unique(d$arbres$placette), c(d$train, d$conforme))
coupees <- d$arbres[statut == "coupe", unique(placette)]
hors <- setdiff(intersect(hors, d$env$placette), coupees)
a <- d$arbres[placette %in% hors]

# --- observe -----------------------------------------------------------------
obs <- a[, .(
  g0 = sum((poids * ga(d1))[statut %in% c("vivant", "mort") & is.finite(d1)]),
  croissance = sum((poids * (ga(d2) - ga(d1)))[statut == "vivant" & is.finite(d1 + d2)]),
  mortalite = sum((poids * ga(d1))[statut == "mort" & is.finite(d1)]),
  recrutement = sum((poids * ga(d2))[statut == "recrute" & is.finite(d2)])
), by = placette]
dom <- a[statut %in% c("vivant", "mort") & is.finite(d1), .(g = sum(poids * ga(d1))),
         by = .(placette, essence)][order(placette, -g)][, .SD[1], by = placette]
obs <- merge(obs, dom[, .(placette, dom = essence)], by = "placette")
obs <- obs[g0 > 0]
obs[, classe := cut(g0, c(0, 10, 20, 30, 40, 50, Inf), right = FALSE)]
if (n_classe > 0) obs <- obs[, .SD[sample(.N, min(.N, n_classe))], by = classe]
cat(sprintf("%d placettes\n", nrow(obs)))

# --- simule : un pas, n_tir tirages --------------------------------------------
x <- a[placette %in% obs$placette]; x[, d2 := NA_real_]
prep <- .finn_preparer(x, d$env[placette %in% obs$placette], sp, essences = cal$essences,
                       variables_env = cal$variables_env, observations = FALSE)
env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
coh0 <- prep$init[, c("siteID", "species", "dbh", "trees")]
coh0$trees <- round(coh0$trees)
n_s <- nrow(prep$sites)
e0 <- .itin_etat(coh0, n_s, sp)
t0 <- Sys.time()
sim <- rbindlist(lapply(seq_len(n_tir), function(i) {
  coh <- .itin_un_pas(m, coh0, env1, sp, length(cal$essences))
  mo <- attr(coh, "morts")
  g_mort <- numeric(n_s)
  if (nrow(mo)) {
    s <- tapply(mo$trees * ga(mo$dbh), factor(mo$siteID, levels = seq_len(n_s)), sum)
    g_mort <- as.numeric(ifelse(is.na(s), 0, s)) / sp
  }
  e1 <- .itin_etat(coh, n_s, sp)
  cat(sprintf("tirage %d : %s\n", i, format(round(Sys.time() - t0, 1))))
  data.table(placette = prep$sites$placette, g0_sim = e0$g, g1_sim = e1$g, mort_sim = g_mort)
}))[, lapply(.SD, mean), by = placette]
cat(sprintf("%d placettes, %d tirages : %s\n", n_s, n_tir, format(round(Sys.time() - t0, 1))))

cmp <- merge(obs, sim, by = "placette")
cmp[, `:=`(net_obs = croissance - mortalite + recrutement, net_sim = g1_sim - g0_sim,
           cr_obs = croissance + recrutement, cr_sim = g1_sim - g0_sim + mort_sim)]
cmp[, groupe := fifelse(is_conifer(dom), "resineux", "feuillus")]

resume <- function(x) x[, .(n = .N, g0 = round(mean(g0), 1),
                            net_obs = round(mean(net_obs), 2), net_sim = round(mean(net_sim), 2),
                            cr_obs = round(mean(cr_obs), 2), cr_sim = round(mean(cr_sim), 2),
                            mort_obs = round(mean(mortalite), 2), mort_sim = round(mean(mort_sim), 2))]
cat("\n1. Par classe de G initiale (m2/ha en 5 ans ; cr = croissance + recrutement)\n")
print(cmp[, resume(.SD), keyby = classe])
cat("\n2. Par essence dominante (n >= 50)\n")
print(cmp[, resume(.SD), by = dom][n >= 50][order(-n)])
cat("\n3. Feuillus / resineux x classe de G\n")
print(cmp[, resume(.SD), keyby = .(groupe, classe)])
cat("\n4. Croissance + recrutement relative (sim / obs) par essence x classe (n >= 30)\n")
r <- cmp[, .(n = .N, ratio_cr = round(mean(cr_sim) / mean(cr_obs), 2),
             ecart_mort = round(mean(mort_sim) - mean(mortalite), 2)), keyby = .(dom, classe)]
print(r[n >= 30])
saveRDS(cmp, file.path(dossier, "biais_croissance.rds"))
