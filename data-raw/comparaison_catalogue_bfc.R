# data-raw/comparaison_catalogue_bfc.R
#
# Premier exercice reel de comparer_itineraires(trajectoires =) (spec 065 /
# spec 068) : des UGF fictives de BFC, chacune faite de placettes IFN de test
# de meme essence dominante, tous les candidats admissibles simules sur les
# memes placettes avec simuler_itineraire(unites =), puis classes sous
# plusieurs profils.
#
# Pre-requis : la calibration de data-raw/simulation_catalogue_bfc.R
# (FINN_SIM_DOSSIER/calibration.pt + .rds) et ses donnees (FINN_INC_DONNEES).
#
# UGF (FINN_CMP_N placettes chacune, defaut 20) :
#   chene sessile (03) x 3, hetre (09) x 3, sapin (61), epicea (62),
#   douglas (64) x 1.
# Candidats : les itineraires sources admissibles (essence de l'UGF), plus
# « sans_gestion ». L'ilot de senescence est ecarte : sa dynamique est celle
# de la libre evolution (regle aucune_coupe), seul le code change.
#
# Choix (a relire) : une UGF faite de placettes tirees au hasard parmi celles
# d'une essence n'est pas une vraie UGF (pas de contiguite) ; les groupes
# conformes sont alors tires au hasard (`groupes_conformes`). Plafond de
# densite actif (densite_max_ifn() sur toutes les placettes). 50 ans,
# 10 tirages. FINN_CMP_PRODUITS (defaut « oui ») : simuler_itineraire(produits
# = TRUE), C = foret + produits et E = substitution ; « non » reproduit le run
# du 2026-11-11 (P et C sur pied). Sorties dans FINN_SIM_DOSSIER :
# trajectoires_ugf<suffixe>.rds, comparaison_ugf<suffixe>.csv
# (FINN_CMP_SUFFIXE). FINN_CMP_BIODIV (defaut « oui ») :
# simuler_itineraire(biodiversite = TRUE), B = bois mort produit par la
# mortalite naturelle depuis l'annee 0 (stock a 50 ans) ; tres gros bois
# vivants (tiges_tgb) resumes a part.

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
d <- readRDS(Sys.getenv("FINN_INC_DONNEES"))
dossier <- Sys.getenv("FINN_SIM_DOSSIER")
n_ugf <- as.integer(Sys.getenv("FINN_CMP_N", "20"))
# carbone des produits et substitution (famille E), parametres_filiere_bois()
produits <- Sys.getenv("FINN_CMP_PRODUITS", "oui") == "oui"
suffixe <- Sys.getenv("FINN_CMP_SUFFIXE", "")
# bois mort et tres gros bois (famille B)
biodiv <- Sys.getenv("FINN_CMP_BIODIV", "oui") == "oui"
stopifnot(nzchar(dossier))
cal <- readRDS(file.path(dossier, "calibration.rds"))
cal$modele <- torch::torch_load(file.path(dossier, "calibration.pt"))
dm <- densite_max_ifn(d$arbres)

init <- d$arbres[placette %in% d$test & statut %in% c("vivant", "mort") & is.finite(d1)]
dom <- init[, .(g = sum(poids * pi * (d1 / 200)^2)), by = .(placette, essence)][
  order(placette, -g)][, .SD[1], by = placette]

# --- UGF ------------------------------------------------------------------------
plan <- data.table(essence = c("03", "09", "61", "62", "64"), n = c(3L, 3L, 1L, 1L, 1L))
set.seed(23)
ugf <- rbindlist(lapply(seq_len(nrow(plan)), function(i) {
  p <- dom[essence == plan$essence[i], placette]
  k <- min(plan$n[i], length(p) %/% n_ugf)
  p <- sample(p, k * n_ugf)
  data.table(placette = p, essence = plan$essence[i],
             unite = sprintf("ugf_%s_%d", plan$essence[i], rep(seq_len(k), each = n_ugf)))
}))
units <- unique(ugf[, .(unit_id = unite, essence)])
cat_it <- itineraires_catalogue()
adm <- itineraires_admissibles(units, cat_it)
cand <- adm[adm$admissible %in% TRUE & adm$itineraire != "bfc_ilot_senescence", ]
print(as.data.table(cand)[, .(candidats = paste(itineraire, collapse = ", ")), by = unit_id])

# --- simulations par essence (memes placettes pour tous les candidats) ----------
res <- list()
for (e in unique(units$essence)) {
  u <- ugf[essence == e]
  a <- d$arbres[placette %in% u$placette]
  env <- d$env[placette %in% u$placette]
  codes <- unique(cand$itineraire[cand$unit_id %in% u$unite])
  for (code in c(codes, "sans_gestion")) {
    t0 <- Sys.time()
    it <- if (code == "sans_gestion") NULL else cat_it[[code]]
    res[[paste(e, code)]] <- simuler_itineraire(
      cal, a, env, itineraire = it, horizon = 50, n_tirages = 10L, volume = TRUE,
      carbone = TRUE, unites = as.data.frame(u[, .(placette, unite)]), densite_max = dm,
      produits = produits, biodiversite = biodiv
    )
    cat(sprintf("%s %s : %s\n", e, code, format(round(Sys.time() - t0, 1))))
  }
}
traj <- do.call(rbind, res)
saveRDS(traj, file.path(dossier, paste0("trajectoires_ugf", suffixe, ".rds")))

# --- comparaison sous quatre profils -------------------------------------------
profils <- c("profil_proprietaire_prive", "profil_gestionnaire_onf",
             "profil_technicien", "profil_naturaliste")
cmp <- rbindlist(lapply(profils, function(pr) {
  x <- comparer_itineraires(units, pr, catalogue = cat_it, admissibles = adm,
                            itineraires = c(unique(cand$itineraire), "sans_gestion"),
                            reference = "sans_gestion", trajectoires = traj)
  v <- as.data.table(attr(x, "valeurs"))
  v <- dcast(v, unit_id + itineraire ~ famille, value.var = "valeur")
  x <- merge(as.data.table(x), v, by = c("unit_id", "itineraire"))
  x[, profil := pr]
}))
cmp <- cmp[, .(profil, unit_id, itineraire, rang, score = round(score_global, 2), pareto,
               P_vol_preleve = round(P), C_carbone = round(C, 1),
               E_substitution = if ("E" %in% names(cmp)) round(E, 1) else NA_real_,
               B_bois_mort = if ("B" %in% names(cmp)) round(B, 1) else NA_real_,
               incertitude_g = round(incertitude, 1), gagnantes = familles_gagnantes,
               perdantes = familles_perdantes)]
setorder(cmp, profil, unit_id, rang)
print(cmp, nrows = 500)
fwrite(cmp, file.path(dossier, paste0("comparaison_ugf", suffixe, ".csv")))

# --- famille B a 50 ans : bois mort, mortalite, tres gros bois -----------------
if (biodiv) {
  tb <- as.data.table(traj)[annee == 50 & variable %in% c("bois_mort", "tiges_tgb", "g")]
  tb <- dcast(tb, unite + itineraire ~ variable, value.var = "moyenne")
  vm <- as.data.table(traj)[variable == "volume_mort", .(volume_mort_cumule = sum(moyenne)),
                            by = .(unite, itineraire)]
  tb <- merge(tb, vm, by = c("unite", "itineraire"))
  tb <- tb[, .(unite, itineraire, g = round(g, 1), bois_mort = round(bois_mort, 1),
               volume_mort_cumule = round(volume_mort_cumule, 1),
               tiges_tgb = round(tiges_tgb, 1))]
  setorder(tb, unite, itineraire)
  print(tb, nrows = 200)
  fwrite(tb, file.path(dossier, paste0("biodiversite_ugf", suffixe, ".csv")))
}
