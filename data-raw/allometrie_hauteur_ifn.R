# data-raw/allometrie_hauteur_ifn.R
#
# Allometrie hauteur-diametre de T4 (spec 068, decision T4-2) : hauteur totale
# mesuree par l'IFN (HTOT) en fonction du diametre a 1,30 m, par essence et,
# quand l'effectif suffit, par essence x SER. Placettes de
# Bourgogne-Franche-Comte, domaine de calibration de FINN.
#
# Modele (Michaelis-Menten) : h = 1.3 + a * d / (b + d), d en cm, h en m.
# Compare a Chapman-Richards (2026-11-14) : erreurs de test egales a 0,1 m
# pres, la forme a deux parametres est gardee. La courbe par SER gagne au
# plus 0,25 m (chenes) ; elle n'est ajustee que pour >= 500 arbres.
#
# Arbres : vivants (VEGET 0), HTOT mesure (arbres non simplifies), d >= 7,5 cm.
# Essences : codes ESPAR a >= 300 arbres, le reste dans « other ».
# Erreur de test : RMSE sur 20 % des arbres tenus hors de l'ajustement ; les
# coefficients publies sont ensuite reajustes sur tous les arbres.
#
# Source : IGN, Inventaire forestier national, donnees brutes 2005-2025,
# Licence Ouverte Etalab 2.0.
#
# Sortie : inst/extdata/allometrie_hauteur_ifn.csv
#   essence, ser ("" = toutes SER), a, b, n_arbres, rmse

library(data.table)

zip <- Sys.getenv("FINN_IFN_ZIP", "data-raw/ifn/export_dataifn_2005_2025.zip")
bfc <- c("21", "25", "39", "58", "70", "71", "89", "90")
min_essence <- 300L
min_ser <- 500L

arb <- fread(cmd = paste("unzip -p", shQuote(zip), "ARBRE.csv"), sep = ";",
             select = c("IDP", "ESPAR", "VEGET", "C13", "HTOT"),
             colClasses = list(character = c("IDP", "ESPAR", "VEGET")))
pla <- fread(cmd = paste("unzip -p", shQuote(zip), "PLACETTE.csv"), sep = ";",
             select = c("IDP", "SER", "DEP"),
             colClasses = list(character = c("IDP", "SER", "DEP")))
pla <- unique(pla, by = "IDP")

arb <- merge(arb[VEGET == "0" & !is.na(HTOT) & !is.na(C13)], pla, by = "IDP")
arb <- arb[DEP %in% bfc & HTOT > 1.3]
arb[, d := C13 / pi * 100]
arb <- arb[d >= 7.5]
n_ess <- arb[, .N, by = ESPAR]
arb[, essence := fifelse(ESPAR %in% n_ess[N >= min_essence, ESPAR], ESPAR, "other")]

ajuster <- function(x) {
  stats::nls(HTOT ~ 1.3 + pa * d / (pb + d), data = x, start = list(pa = 30, pb = 30))
}
predire <- function(cf, d) 1.3 + cf[["pa"]] * d / (cf[["pb"]] + d)

set.seed(68)
arb[, test := stats::runif(.N) < 0.2]

lignes <- list()
for (e in sort(unique(arb$essence))) {
  x <- arb[essence == e]
  groupes <- c("", x[, .N, by = SER][N >= min_ser, sort(SER)])
  for (s in groupes) {
    xs <- if (s == "") x else x[SER == s]
    f_tr <- tryCatch(ajuster(xs[test == FALSE]), error = function(err) NULL)
    f <- tryCatch(ajuster(xs), error = function(err) NULL)
    if (is.null(f) || is.null(f_tr)) next
    te <- xs[test == TRUE]
    lignes[[length(lignes) + 1L]] <- data.table(
      essence = e, ser = s, a = round(coef(f)[["pa"]], 4), b = round(coef(f)[["pb"]], 4),
      n_arbres = nrow(xs),
      rmse = round(sqrt(mean((te$HTOT - predire(coef(f_tr), te$d))^2)), 3))
  }
}
res <- rbindlist(lignes)
print(res)
fwrite(res, "inst/extdata/allometrie_hauteur_ifn.csv")
