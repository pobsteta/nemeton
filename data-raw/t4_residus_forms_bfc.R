# data-raw/t4_residus_forms_bfc.R
#
# Bruit d'observation de T4 (spec 068, decision (a) du 2026-11-15) : residus
# observe - simule de l'accroissement de hauteur dominante autour des
# placettes analogues (inst/extdata/t4_analogues_bfc.csv.gz).
#
# Observe : FORMS-T 2019-2024 sur un disque de 250 m autour du point public
# de la placette (coordonnees IFN floutees), meme mesure que
# indicateur_t4_vitalite() (.t4_hdom_annuelle : percentile 90 des pixels
# >= 5 m, au moins 50 pixels), pente de Theil-Sen x 5. Disques ecartes :
# serie incomplete ou chute de plus de 3 m d'une annee a l'autre.
# Simule : moyenne des tirages FINN de la placette.
#
# Le residu garde le biais moyen de l'essence : la reference de T4
# (simule + residu) est centree sur l'observe. Il inclut la variabilite
# entre peuplements et le decalage du floutage : reference prudente.
#
# Variables : FINN_IFN_ZIP, NEMETON_FORMS_T (dossier des Height_<an>.tif,
# defaut ~/.cache/nemeton/forms_t).
#
# Sortie : inst/extdata/t4_residus_forms_bfc.csv
#   placette, essence, h_dom, observe, simule, residu
#
# Sources : IGN, Inventaire forestier national (Licence Ouverte Etalab 2.0) ;
# FORMS-T (Schwartz et al., Zenodo 15489231, CC-BY 4.0).

library(data.table)
library(sf)
pkgload::load_all(quiet = TRUE)

zip <- Sys.getenv("FINN_IFN_ZIP", "data-raw/ifn/export_dataifn_2005_2025.zip")
dossier <- Sys.getenv("NEMETON_FORMS_T", path.expand("~/.cache/nemeton/forms_t"))

ana <- fread("inst/extdata/t4_analogues_bfc.csv.gz",
             colClasses = list(character = c("placette", "ser", "essence")))
cols <- grep("^a[0-9]+$", names(ana), value = TRUE)
ana[, simule := rowMeans(.SD), .SDcols = cols]

pla <- fread(cmd = sprintf("unzip -p '%s' PLACETTE.csv", zip),
             select = c("IDP", "VISITE", "XL", "YL"), colClasses = "character")
pla <- unique(pla[VISITE == "1" & IDP %in% ana$placette], by = "IDP")
disques <- st_buffer(st_as_sf(pla[, .(placette = IDP, x = as.numeric(XL), y = as.numeric(YL))],
                              coords = c("x", "y"), crs = 2154), 250)

forms <- terra::rast(file.path(dossier, sprintf("Height_%d.tif", 2019:2024)))
names(forms) <- 2019:2024
H <- .t4_hdom_annuelle(disques, forms, "cm", 50L)
ok <- complete.cases(H)
chute <- rep(NA, nrow(H))
chute[ok] <- apply(H[ok, , drop = FALSE], 1L, function(h) any(diff(h) < -3))
obs <- rep(NA_real_, nrow(H))
obs[ok] <- 5 * .theil_sen_pentes(H[ok, , drop = FALSE], 2019:2024)
d <- data.table(placette = disques$placette, observe = obs, chute = chute)
cat(sprintf("%d disques, %d series completes, %d chutes > 3 m\n",
            nrow(d), sum(ok), sum(chute, na.rm = TRUE)))

r <- merge(d[ok & !chute], ana[, .(placette, essence, h_dom, simule)], by = "placette")
r[, residu := observe - simule]
r[, `:=`(observe = round(observe, 3), simule = round(simule, 3), residu = round(residu, 3))]
print(r[, .(n = .N, biais = round(mean(residu), 2), sd = round(sd(residu), 2)),
        by = essence][order(-n)][n >= 30])
fwrite(r[, .(placette, essence, h_dom, observe, simule, residu)],
       "inst/extdata/t4_residus_forms_bfc.csv")
