# data-raw/diagnostic_plafond_finn.R
#
# Diagnostic du plafond de densite de FINN (spec 068) : les simulations du
# catalogue (data-raw/simulation_catalogue_bfc.R) montrent une G sans gestion
# qui croit presque lineairement sur 50 ans (douglas 81 m2/ha). On compare :
#   1. l'accroissement net de G en 5 ans, observe (IFN) et simule (un pas
#      FINN), par classe de G initiale, sur les placettes hors calibration ;
#   2. la limite haute observee de la densite (Reineke : RDI = N (Dg/25)^1.605,
#      quantile 99 %) par essence dominante ;
#   3. une projection de 150 ans sans gestion sur les placettes de test,
#      sans plafond puis avec le plafond de densite_max_ifn() (quantile 99 %
#      de la forme additive du RDI, premiere visite de toutes les placettes).
#
# Variables : FINN_INC_DONNEES (donnees.rds), FINN_SIM_DOSSIER (calibration).
# Sorties dans FINN_SIM_DOSSIER/diagnostic_plafond.rds, tables imprimees.

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
d <- readRDS(Sys.getenv("FINN_INC_DONNEES"))
dossier <- Sys.getenv("FINN_SIM_DOSSIER")
cal <- readRDS(file.path(dossier, "calibration.rds"))
cal$modele <- torch::torch_load(file.path(dossier, "calibration.pt"))
m <- cal$modele; m$eval()
sp <- cal$surface_placette
ga <- function(x) pi * (x / 200)^2
set.seed(7)

hors <- setdiff(unique(d$arbres$placette), c(d$train, d$conforme))
a <- d$arbres[placette %in% hors]
# etat par placette : G1, N1, G2 observee, essence dominante
p1 <- a[statut %in% c("vivant", "mort") & is.finite(d1),
        .(g1 = sum(poids * ga(d1)), n1 = sum(poids)), by = placette]
p2 <- a[statut %in% c("vivant", "recrute") & is.finite(d2), .(g2 = sum(poids * ga(d2))), by = placette]
pm <- a[statut == "mort" & is.finite(d1), .(g_mort = sum(poids * ga(d1))), by = placette]
dom <- a[statut %in% c("vivant", "mort") & is.finite(d1), .(g = sum(poids * ga(d1))),
         by = .(placette, essence)][order(placette, -g)][, .SD[1], by = placette][, .(placette, dom = essence)]
obs <- Reduce(function(x, y) merge(x, y, by = "placette", all.x = TRUE), list(p1, p2, pm, dom))
obs[is.na(g2), g2 := 0][is.na(g_mort), g_mort := 0]
obs[, dg := 100 * sqrt(4 * g1 / (pi * n1))][, rdi := n1 * (dg / 25)^1.605]
# placettes coupees entre les visites : la croissance nette y est faussee
coupees <- a[statut == "coupe", unique(placette)]
obs <- obs[!placette %in% coupees & placette %in% d$env$placette]
classes <- c(0, 10, 20, 30, 40, 50, Inf)
obs[, classe := cut(g1, classes, right = FALSE)]

# --- 1. un pas FINN sur un echantillon de ces placettes -----------------------
ech <- obs[, .SD[sample(.N, min(.N, 300))], by = classe]$placette
x <- a[placette %in% ech]; x[, d2 := NA_real_]
prep <- .finn_preparer(x, d$env[placette %in% ech], sp, essences = cal$essences,
                       variables_env = cal$variables_env, observations = FALSE)
env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
coh0 <- prep$init[, c("siteID", "species", "dbh", "trees")]
coh0$trees <- round(coh0$trees)
sim1 <- rbindlist(lapply(1:5, function(i) {
  coh <- .itin_un_pas(m, coh0, env1, sp, length(cal$essences))
  e <- .itin_etat(coh, nrow(prep$sites), sp)
  data.table(placette = prep$sites$placette, g2_sim = e$g, tirage = i)
}))[, .(g2_sim = mean(g2_sim)), by = placette]
cmp <- merge(obs, sim1, by = "placette")
cat("\n1. Accroissement net de G en 5 ans (m2/ha), par classe de G initiale\n")
print(cmp[, .(n = .N, g1 = round(mean(g1), 1), net_obs = round(mean(g2 - g1), 2),
              net_sim = round(mean(g2_sim - g1), 2), mort_obs = round(mean(g_mort), 2)),
          keyby = classe])

# --- 2. limite haute observee (toutes placettes BFC, premiere visite) ---------
toutes <- d$arbres[statut %in% c("vivant", "mort") & is.finite(d1),
                   .(g1 = sum(poids * ga(d1)), n1 = sum(poids)), by = placette]
domt <- d$arbres[statut %in% c("vivant", "mort") & is.finite(d1), .(g = sum(poids * ga(d1))),
                 by = .(placette, essence)][order(placette, -g)][, .SD[1], by = placette]
toutes <- merge(toutes, domt[, .(placette, dom = essence)], by = "placette")
toutes[, dg := 100 * sqrt(4 * g1 / (pi * n1))][, rdi := n1 * (dg / 25)^1.605]
lim <- toutes[, .(n = .N, g_q99 = round(quantile(g1, 0.99), 1), g_max = round(max(g1), 1),
                  rdi_q99 = round(quantile(rdi, 0.99)), rdi_q95 = round(quantile(rdi, 0.95))),
              by = dom][n >= 100][order(-n)]
cat("\n2. Limite haute observee, premiere visite, par essence dominante (n >= 100)\n")
print(lim)

# --- 3. projection de 150 ans sans gestion, placettes de test -----------------
tst <- d$arbres[placette %in% d$test]
domt_t <- domt[placette %in% d$test, .(placette, dom = essence)]
p_long <- domt_t[, .SD[sample(.N, min(.N, 40))], by = dom][dom %in% c("03", "02", "09", "61", "62", "64")]$placette
long <- simuler_itineraire(cal, tst[placette %in% p_long], d$env[placette %in% p_long],
                           itineraire = NULL, horizon = 150, n_tirages = 3L)
long <- merge(as.data.table(long), domt_t, by = "placette")
traj_long <- long[variable %in% c("g", "tiges"), .(moyenne = mean(moyenne)), by = .(dom, annee, variable)]
cat("\n3. G moyenne sans gestion sur 150 ans, par essence dominante (m2/ha)\n")
print(dcast(traj_long[variable == "g" & annee %in% c(0, 25, 50, 75, 100, 125, 150)],
            dom ~ annee, value.var = "moyenne")[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 1) else v)])
# RDI simule a 50 et 150 ans
rdi_sim <- dcast(long[variable %in% c("g", "tiges")], placette + dom + annee ~ variable,
                 value.var = "moyenne")
rdi_sim[, dg := 100 * sqrt(4 * g / (pi * tiges))][, rdi := tiges * (dg / 25)^1.605]
cat("\nRDI moyen simule (limite observee q99 en section 2)\n")
print(dcast(rdi_sim[annee %in% c(0, 50, 150), .(rdi = round(mean(rdi))), by = .(dom, annee)],
            dom ~ annee, value.var = "rdi"))

# --- 4. la meme projection avec le plafond d'auto-eclaircie --------------------
dm <- densite_max_ifn(d$arbres)
long_p <- simuler_itineraire(cal, tst[placette %in% p_long], d$env[placette %in% p_long],
                             itineraire = NULL, horizon = 150, n_tirages = 3L, densite_max = dm)
long_p <- merge(as.data.table(long_p), domt_t, by = "placette")
cat("\n4. G moyenne sans gestion sur 150 ans avec plafond (m2/ha)\n")
print(dcast(long_p[variable == "g" & annee %in% c(0, 25, 50, 75, 100, 125, 150),
                   .(moyenne = round(mean(moyenne), 1)), by = .(dom, annee)],
            dom ~ annee, value.var = "moyenne"))

saveRDS(list(comparaison = cmp, limite = lim, toutes = toutes, long = long,
             long_plafond = long_p, densite_max = dm),
        file.path(dossier, "diagnostic_plafond.rds"))
