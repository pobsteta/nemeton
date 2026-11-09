# data-raw/prototype_finn_unites.R
#
# Intervalle des predictions FINN a l'echelle d'une unite de gestion (UGF) de
# k placettes (spec 068). Residus a 5 ans du modele « graine 0 » de
# prototype_finn_incertitude.R (min_arbres_essence = 300) sur les 2000
# placettes tenues a l'ecart (1000 « conforme » + 1000 « test »).
#   1. correlation des residus selon la distance (coordonnees IFN XL/YL,
#      Lambert-93, floutees a l'echelle du kilometre) ;
#   2. demi-largeur 90 % mesuree sur les placettes « conforme » par
#      .finn_demi_largeur() (groupes de k voisines, ou au hasard), et sa
#      couverture sur des groupes de k voisines des placettes « test » ;
#      comparaison avec la regle q / sqrt(k).
#
# Variables : FINN_INC_DONNEES (donnees.rds de prototype_finn_incertitude.R),
# FINN_UNI_MODELE (chemin sans extension du modele : .rds + .pt),
# FINN_UNI_PLACETTE (PLACETTE.csv de l'export IFN), FINN_UNI_RESIDUS (cache).

suppressMessages({
  library(data.table)
  pkgload::load_all(".", quiet = TRUE)
})
d <- readRDS(Sys.getenv("FINN_INC_DONNEES"))
f_res <- Sys.getenv("FINN_UNI_RESIDUS")
if (!file.exists(f_res)) {
  modele <- Sys.getenv("FINN_UNI_MODELE")
  cal <- readRDS(paste0(modele, ".rds"))
  cal$modele <- torch::torch_load(paste0(modele, ".pt"))
  p <- c(d$conforme, d$test)
  a <- d$arbres[placette %in% p]; e <- d$env[placette %in% p]
  set.seed(11)
  pr <- as.data.table(predire_finn(cal, a, e, n_tirages = 10L))
  obs <- nemeton:::.finn_g_observee(as.data.frame(a))
  pr[, obs := as.numeric(obs[placette])]
  pla <- fread(Sys.getenv("FINN_UNI_PLACETTE"), sep = ";", select = c("IDP", "VISITE", "XL", "YL"),
               colClasses = "character", encoding = "UTF-8")
  pla <- unique(pla[VISITE == "1", .(placette = IDP, x = as.numeric(XL), y = as.numeric(YL))],
                by = "placette")
  pr <- merge(pr, pla, by = "placette")
  pr[, r := g_predite - obs]
  saveRDS(pr, f_res)
}
pr <- readRDS(f_res)

# 1. correlation par classe de distance
D <- as.matrix(dist(pr[, .(x, y)])) / 1000
R <- outer(pr$r - mean(pr$r), pr$r - mean(pr$r))
cl <- cut(D[upper.tri(D)], c(0, 1.5, 3, 5, 10, 20, 50, 1000))
print(data.table(distance_km = levels(cl),
                 correlation = round(as.numeric(tapply(R[upper.tri(R)], cl, mean)) / var(pr$r), 3),
                 paires = as.integer(table(cl))))

# 2. demi-largeur sur « conforme », couverture sur des groupes voisins de « test »
cf <- pr[placette %in% d$conforme]; te <- pr[placette %in% d$test]
conf <- function(x, coords = TRUE) {
  list(niveau = 0.9, demi_largeur = quantile(abs(x$r), 0.9 * (1 + 1 / nrow(x)), names = FALSE),
       residus = x$r, x = if (coords) x$x, y = if (coords) x$y)
}
groupes_test <- function(x, k, rep = 20) unlist(lapply(seq_len(rep), function(s) {
  set.seed(s); reste <- seq_len(nrow(x)); out <- c()
  while (length(reste) >= k) {
    i <- reste[sample.int(length(reste), 1)]
    dd <- (x$x[reste] - x$x[i])^2 + (x$y[reste] - x$y[i])^2
    j <- reste[order(dd)[1:k]]
    out <- c(out, mean(x$r[j])); reste <- setdiff(reste, j)
  }
  out
}))
res <- rbindlist(lapply(c(1L, 2L, 4L, 8L, 16L, 33L), function(k) {
  qv <- nemeton:::.finn_demi_largeur(conf(cf), k)$q
  qh <- nemeton:::.finn_demi_largeur(conf(cf, FALSE), k)$q
  qr <- conf(cf)$demi_largeur / sqrt(k)
  mt <- if (k == 1) te$r else groupes_test(te, k)
  data.table(k = k, q_voisins = round(qv, 2), couv_voisins = round(mean(abs(mt) <= qv), 3),
             q_hasard = round(qh, 2), couv_hasard = round(mean(abs(mt) <= qh), 3),
             q_racine = round(qr, 2), couv_racine = round(mean(abs(mt) <= qr), 3))
}))
print(res)
