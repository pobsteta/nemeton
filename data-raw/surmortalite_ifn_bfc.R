# data-raw/surmortalite_ifn_bfc.R
#
# Prototype de la surmortalite (spec 069, livrable 1) : mortalite observee
# entre deux visites IFN moins mortalite attendue par FINN, par essence x
# campagne et par essence x SER x periode, sur les placettes BFC tenues hors
# de la calibration de reference.
#
# Reference (S-1 a) : FINN calibre sur les revisites 2015-2017, avant les
# crises (data-raw/recalibration_finn_bfc.R avec FINN_RECAL_PLACETTES).
# Attendu : G initiale des tiges mortes pendant un pas FINN depuis l'etat de
# la premiere visite (attribut "morts" de .itin_un_pas(), diametre d'entree),
# moyenne de n tirages. Observe : G initiale (d1) des tiges mortes entre les
# visites. Placettes coupees entre les visites exclues.
#
# Jeux :
# - « avant » : placettes de test et de conforme revisitees en 2015-2017,
#   hors calibration de reference ; le seuil (quantile conforme a 95 % des
#   ecarts observe - attendu par placette, S-4) est mesure sur la moitie
#   conforme, la moitie test verifie qu'environ 5 % des placettes le passent ;
# - « crise » : toutes les placettes revisitees de 2018 a 2025.
#
# Critere de reussite (spec 069 § 4.1) : l'exces monte avec les crises
# connues (epicea apres 2018, frene avec la chalarose) et reste proche de
# zero pour le hetre et les chenes avant 2018.
#
# Variables : FINN_INC_DONNEES (donnees.rds), FINN_SIM_DOSSIER (calibration de
# reference), FINN_SURM_CAMPAGNES (csv IDP, c1, c2), FINN_IFN_ZIP (export IFN,
# defaut data-raw/ifn/export_dataifn_2005_2025.zip, pour la SER),
# FINN_DIAG_TIRAGES (defaut 5), FINN_DIAG_PAQUET (defaut 250), FINN_DIAG_N
# (placettes au plus par jeu, pour un essai ; defaut 0 = toutes), FINN_THREADS.
# Sortie : FINN_SIM_DOSSIER/surmortalite.rds (une ligne par placette x
# essence).

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
d <- readRDS(Sys.getenv("FINN_INC_DONNEES"))
dossier <- Sys.getenv("FINN_SIM_DOSSIER")
camp <- fread(Sys.getenv("FINN_SURM_CAMPAGNES"), colClasses = "character")
zip <- Sys.getenv("FINN_IFN_ZIP", "data-raw/ifn/export_dataifn_2005_2025.zip")
n_tir <- as.integer(Sys.getenv("FINN_DIAG_TIRAGES", "5"))
paquet <- as.integer(Sys.getenv("FINN_DIAG_PAQUET", "250"))
torch::torch_set_num_threads(as.integer(Sys.getenv("FINN_THREADS", "4")))
cal <- readRDS(file.path(dossier, "calibration.rds"))
cal$modele <- torch::torch_load(file.path(dossier, "calibration.pt"))
m <- cal$modele; m$eval()
sp <- cal$surface_placette
ga <- function(x) pi * (x / 200)^2
set.seed(69)

# --- placettes : campagne, SER, jeu ---------------------------------------------
ser <- fread(cmd = sprintf("unzip -p '%s' PLACETTE.csv", zip), select = c("IDP", "SER"),
             colClasses = "character")[, .SD[1], by = IDP]
pla <- merge(camp[, .(placette = IDP, c2 = as.integer(c2))], ser[, .(placette = IDP, ser = SER)],
             by = "placette", all.x = TRUE)
coupees <- d$arbres[statut == "coupe", unique(placette)]
pla <- pla[placette %in% d$env$placette & !placette %in% c(cal$placettes, coupees)]
pla[, jeu := fifelse(c2 <= 2017L,
                     fifelse(placette %in% d$conforme, "avant_conforme",
                             fifelse(placette %in% d$test, "avant_test", NA_character_)),
                     "crise")]
pla <- pla[!is.na(jeu)]
n_max <- as.integer(Sys.getenv("FINN_DIAG_N", "0"))
if (n_max > 0) pla <- pla[, .SD[sample(.N, min(.N, n_max))], by = jeu]
pla[, periode := cut(c2, c(2014, 2017, 2020, 2025), labels = c("2015-17", "2018-20", "2021-25"))]
cat("placettes par jeu :\n"); print(pla[, .N, keyby = jeu])

# --- observe, par placette x essence (essences de la calibration, sinon other) ---
a <- d$arbres[placette %in% pla$placette]
a[, ess := fifelse(essence %in% cal$essences, essence, "other")]
obs <- a[statut %in% c("vivant", "mort") & is.finite(d1),
         .(g0 = sum(poids * ga(d1)), mort_obs = sum((poids * ga(d1))[statut == "mort"])),
         by = .(placette, ess)]

# --- attendu : un pas FINN, n_tir tirages, par paquets ---------------------------
un_paquet <- function(pl) {
  x <- a[placette %in% pl]; x[, d2 := NA_real_]
  prep <- .finn_preparer(x, d$env[placette %in% pl], sp, essences = cal$essences,
                         variables_env = cal$variables_env, observations = FALSE)
  env1 <- prep$env[prep$env$year == 0L, , drop = FALSE]
  coh0 <- prep$init[, c("siteID", "species", "dbh", "trees")]
  coh0$trees <- round(coh0$trees)
  rbindlist(lapply(seq_len(n_tir), function(i) {
    coh <- .itin_pas_corrige(m, coh0, env1, sp, length(cal$essences), cal$correction)
    mo <- as.data.table(attr(coh, "morts"))
    if (!nrow(mo)) return(NULL)
    mo[, .(mort_sim = sum(trees * ga(dbh)) / sp / n_tir),
       by = .(placette = prep$sites$placette[siteID], ess = cal$essences[species])]
  }))
}
t0 <- Sys.time()
lots <- split(pla$placette, ceiling(seq_along(pla$placette) / paquet))
sim <- rbindlist(lapply(seq_along(lots), function(k) {
  r <- un_paquet(lots[[k]])
  cat(sprintf("paquet %d/%d : %s\n", k, length(lots), format(round(Sys.time() - t0, 1))))
  r
}))[, .(mort_sim = sum(mort_sim)), by = .(placette, ess)]

x <- merge(obs, sim, by = c("placette", "ess"), all = TRUE)
for (v in c("g0", "mort_obs", "mort_sim")) set(x, which(is.na(x[[v]])), v, 0)
x <- merge(x, pla, by = "placette")
x[, ecart := mort_obs - mort_sim]
saveRDS(x, file.path(dossier, "surmortalite.rds"))

# --- seuil conforme par placette (toutes essences), S-4 : 95 % -------------------
parp <- x[, .(g0 = sum(g0), mort_obs = sum(mort_obs), mort_sim = sum(mort_sim), ecart = sum(ecart)),
          by = .(placette, jeu, c2, periode, ser)]
r <- sort(parp[jeu == "avant_conforme", ecart])
k <- ceiling((length(r) + 1) * 0.95)
seuil <- if (k <= length(r)) r[k] else Inf
cat(sprintf("\nseuil conforme 95 %% : %.2f m2/ha de morts en plus en 5 ans (n = %d)\n",
            seuil, length(r)))
cat("\n1. Par jeu et campagne : mortalite observee / attendue (m2/ha en 5 ans), part au-dessus du seuil\n")
print(parp[, .(n = .N, mort_obs = round(mean(mort_obs), 2), mort_sim = round(mean(mort_sim), 2),
               ecart = round(mean(ecart), 2), au_dessus = sprintf("%.1f %%", 100 * mean(ecart > seuil))),
           keyby = .(jeu, c2)])

# --- par essence : rapport observe / attendu et exces, IC bootstrap --------------
boot <- function(o, s, n = 1000L) {
  b <- replicate(n, { i <- sample(length(o), replace = TRUE); sum(o[i]) / sum(s[i]) })
  b <- b[is.finite(b)]
  if (!length(b) || sum(s) <= 0) return(NA_character_)
  sprintf("%.2f [%.2f-%.2f]", sum(o) / sum(s), stats::quantile(b, 0.025), stats::quantile(b, 0.975))
}
noms <- c("03" = "chene sessile", "02" = "chene pedoncule", "09" = "hetre", "11" = "charme",
          "62" = "epicea", "61" = "sapin", "64" = "douglas", "17C" = "frene", "14" = "robinier",
          "24" = "tremble")
pres <- x[g0 > 0]
pres[, nom := fifelse(ess %in% names(noms), noms[ess], ess)]
cat("\n2. Par essence (placettes ou elle est presente) x periode : obs / attendu [IC 95 %], exces moyen\n")
print(pres[, .(n = .N, obs_sur_att = boot(mort_obs, mort_sim), exces = round(mean(ecart), 2),
               exces_pct_g0 = round(100 * sum(ecart) / sum(g0), 1)),
           keyby = .(nom, periode)][n >= 30])
cat("\n3. Epicea, frene, hetre, chenes par campagne (n >= 20)\n")
print(pres[nom %in% c("epicea", "frene", "hetre", "chene sessile", "chene pedoncule", "sapin"),
           .(n = .N, obs = round(mean(mort_obs), 2), att = round(mean(mort_sim), 2),
             exces = round(mean(ecart), 2)), keyby = .(nom, c2)][n >= 20])
cat("\n4. Par essence x SER x periode (n >= 30)\n")
print(pres[, .(n = .N, obs_sur_att = boot(mort_obs, mort_sim, 300L), exces = round(mean(ecart), 2)),
           keyby = .(nom, ser, periode)][n >= 30])
cat(sprintf("\nduree : %s\nfin\n", format(round(Sys.time() - t0, 1))))
