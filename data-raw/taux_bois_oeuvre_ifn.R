# data-raw/taux_bois_oeuvre_ifn.R
#
# Part de bois d'oeuvre potentiel dans le volume des arbres, par groupe
# d'essences et classe de diametre, mesuree sur les placettes IFN de
# Bourgogne-Franche-Comte (spec 068, sources du carbone des produits bois).
#
# Donnee : ARBRE.csv de l'export IFN (IGN, Licence Ouverte), champs Q1, Q2,
# Q3 et R (2005-2013) : repartition en dixiemes du volume de l'arbre entre
# qualite 1 (tranchage, deroulage, ebenisterie), 2 (sciages courants,
# charpente, caisserie), 3 (industrie, chauffage) et rebut, selon la qualite
# presumee sur pied (documentation ARBRE.csv v2.4, p. 5). Releves sur les
# arbres de circonference >= 0,705 m ; les petits bois sont en qualite 3
# (Q3 = 10). A partir de 2014, QUALITE (une classe par arbre, bille de pied)
# remplace Q1-Q3 : non retenue, elle ne donne pas de part de volume.
#
# Bois d'oeuvre potentiel = Q1 + Q2, pondere par le volume (V) et le poids (W)
# de l'arbre. C'est la mesure qu'utilise l'etude ADEME-IGN-FCBA 2016
# (Disponibilites en bois d'origine forestiere a l'horizon 2035, tome 1
# § 3.4.3-3.4.4, annexe 17), qui la dit « fourchette haute » : presomption sur
# pied, defauts internes invisibles.
#
# Variable : FINN_VOL_IFN (dossier de l'export : ARBRE.csv, PLACETTE.csv ;
# ifn_charger() les telecharge). Sortie imprimee et ecrite dans
# FINN_VOL_IFN/taux_bo_bfc.csv.

suppressMessages(library(data.table))
ifn <- Sys.getenv("FINN_VOL_IFN")
stopifnot(nzchar(ifn))
ar <- fread(file.path(ifn, "ARBRE.csv"), sep = ";", colClasses = "character",
            select = c("CAMPAGNE", "IDP", "ESPAR", "VEGET", "C13", "V", "W", "Q1", "Q2", "Q3", "R"))
pl <- unique(fread(file.path(ifn, "PLACETTE.csv"), sep = ";", colClasses = "character",
                   select = c("IDP", "DEP")))
ar <- merge(ar, pl, by = "IDP")
num <- c("C13", "V", "W", "Q1", "Q2", "Q3", "R")
ar[, (num) := lapply(.SD, as.numeric), .SDcols = num]
bfc <- c("21", "25", "39", "58", "70", "71", "89", "90")
ar <- ar[DEP %in% bfc & VEGET == "0" & as.integer(CAMPAGNE) <= 2013 & is.finite(V) & is.finite(W)]
ar[, d := C13 / pi * 100]
# petits bois : qualite 3 par convention de l'IFN
ar[!is.finite(Q1) & d < 22.5, `:=`(Q1 = 0, Q2 = 0, Q3 = 1, R = 0)]
ar[, groupe := fcase(ESPAR %in% c("03", "02"), "chenes", ESPAR == "09", "hetre",
                     ESPAR == "61", "sapin", ESPAR == "62", "epicea", ESPAR == "64", "douglas",
                     as.integer(substr(ESPAR, 1, 2)) >= 51, "autres_resineux",
                     default = "autres_feuillus")]
ar[, classe := cut(d, c(7.5, 22.5, 32.5, 42.5, 52.5, 62.5, Inf), right = FALSE,
                   labels = c("10-20", "25-30", "35-40", "45-50", "55-60", "65+"))]
x <- ar[is.finite(Q1) & !is.na(classe),
        .(n = .N, taux_bo = round(sum(W * V * (Q1 + Q2)) / sum(W * V), 2),
          taux_q1 = round(sum(W * V * Q1) / sum(W * V), 2),
          taux_rebut = round(sum(W * V * R) / sum(W * V), 2)),
        by = .(groupe, classe)]
setorder(x, groupe, classe)
print(dcast(x, groupe ~ classe, value.var = "taux_bo"))
print(dcast(x, groupe ~ classe, value.var = "n"))
print(ar[is.finite(Q1), .(taux_bo = round(sum(W * V * (Q1 + Q2)) / sum(W * V), 2), n = .N),
         by = groupe][order(groupe)])
fwrite(x, file.path(ifn, "taux_bo_bfc.csv"))
