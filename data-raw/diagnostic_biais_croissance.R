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
# initiale, defaut 500 ; 0 = toutes), FINN_DIAG_ENSEMBLE (« hors », defaut :
# placettes hors calibration et hors conforme ; « test » : le jeu de test
# seul, tenu a l'ecart de toutes les calibrations, pour comparer deux
# modeles), FINN_DIAG_PAQUET (placettes par appel FINN, defaut 250 : le cout
# d'un appel croit plus vite que le nombre de placettes). La correction de
# croissance de la calibration (corriger_finn()) est appliquee si elle est
# presente. Sortie :
# FINN_SIM_DOSSIER/biais_croissance<FINN_DIAG_SUFFIXE>.rds.

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
d <- readRDS(Sys.getenv("FINN_INC_DONNEES"))
dossier <- Sys.getenv("FINN_SIM_DOSSIER")
n_tir <- as.integer(Sys.getenv("FINN_DIAG_TIRAGES", "3"))
n_classe <- as.integer(Sys.getenv("FINN_DIAG_N", "500"))
ensemble <- Sys.getenv("FINN_DIAG_ENSEMBLE", "hors")
paquet <- as.integer(Sys.getenv("FINN_DIAG_PAQUET", "250"))
suffixe <- Sys.getenv("FINN_DIAG_SUFFIXE", "")
torch::torch_set_num_threads(as.integer(Sys.getenv("FINN_THREADS", "4")))
cal <- readRDS(file.path(dossier, "calibration.rds"))
cal$modele <- torch::torch_load(file.path(dossier, "calibration.pt"))
m <- cal$modele; m$eval()
sp <- cal$surface_placette
ga <- function(x) pi * (x / 200)^2
set.seed(11)

hors <- if (ensemble == "test") d$test else
  setdiff(unique(d$arbres$placette), c(d$train, d$conforme))
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

# --- simule : un pas, n_tir tirages, par paquets de placettes -----------------
un_paquet <- function(pl) {
  x <- a[placette %in% pl]; x[, d2 := NA_real_]
  prep <- .finn_preparer(x, d$env[placette %in% pl], sp, essences = cal$essences,
                         variables_env = cal$variables_env, observations = FALSE)
  env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
  coh0 <- prep$init[, c("siteID", "species", "dbh", "trees")]
  coh0$trees <- round(coh0$trees)
  n_s <- nrow(prep$sites)
  e0 <- .itin_etat(coh0, n_s, sp)
  rbindlist(lapply(seq_len(n_tir), function(i) {
    coh <- .itin_pas_corrige(m, coh0, env1, sp, length(cal$essences), cal$correction)
    mo <- attr(coh, "morts")
    g_mort <- numeric(n_s)
    if (nrow(mo)) {
      s <- tapply(mo$trees * ga(mo$dbh), factor(mo$siteID, levels = seq_len(n_s)), sum)
      g_mort <- as.numeric(ifelse(is.na(s), 0, s)) / sp
    }
    e1 <- .itin_etat(coh, n_s, sp)
    # survivants (diametre d'entree connu) / recrues
    d0 <- attr(coh, "dbh_entree")
    sv <- is.finite(d0)
    par_site <- function(x, i) {
      v <- tapply(x[i], factor(coh$siteID[i], levels = seq_len(n_s)), sum)
      as.numeric(ifelse(is.na(v), 0, v)) / sp
    }
    data.table(placette = prep$sites$placette, g0_sim = e0$g, g1_sim = e1$g, mort_sim = g_mort,
               surv_sim = par_site(coh$trees * (ga(coh$dbh) - ga(d0)), sv),
               recr_sim = par_site(coh$trees * ga(coh$dbh), !sv))
  }))
}
t0 <- Sys.time()
lots <- split(obs$placette, ceiling(seq_along(obs$placette) / paquet))
sim <- rbindlist(lapply(seq_along(lots), function(k) {
  r <- un_paquet(lots[[k]])
  cat(sprintf("paquet %d/%d : %s\n", k, length(lots), format(round(Sys.time() - t0, 1))))
  r
}))[, lapply(.SD, mean), by = placette]
cat(sprintf("%d placettes, %d tirages : %s\n", nrow(sim), n_tir, format(round(Sys.time() - t0, 1))))

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
cat("\n1b. Survivants et recrues (m2/ha en 5 ans)\n")
print(cmp[, .(n = .N, surv_obs = round(mean(croissance), 2), surv_sim = round(mean(surv_sim), 2),
              recr_obs = round(mean(recrutement), 2), recr_sim = round(mean(recr_sim), 2)),
          keyby = classe])
cat("\n2. Par essence dominante (n >= 50)\n")
print(cmp[, resume(.SD), by = dom][n >= 50][order(-n)])
cat("\n3. Feuillus / resineux x classe de G\n")
print(cmp[, resume(.SD), keyby = .(groupe, classe)])
cat("\n4. Croissance + recrutement relative (sim / obs) par essence x classe (n >= 30)\n")
r <- cmp[, .(n = .N, ratio_cr = round(mean(cr_sim) / mean(cr_obs), 2),
             ecart_mort = round(mean(mort_sim) - mean(mortalite), 2)), keyby = .(dom, classe)]
print(r[n >= 30])
cat(sprintf("\n5. Ensemble : RMSE G1 %.2f, biais %.2f m2/ha (n = %d)\n",
            cmp[, sqrt(mean((g0 + net_sim - (g0 + net_obs))^2))], cmp[, mean(net_sim - net_obs)],
            nrow(cmp)))
saveRDS(cmp, file.path(dossier, paste0("biais_croissance", suffixe, ".rds")))
