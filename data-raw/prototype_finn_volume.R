# data-raw/prototype_finn_volume.R
#
# Controle des tarifs Schaeffer a une entree utilises par
# simuler_itineraire(volume = TRUE) (spec 068) : volume IFN mesure (V, arbres
# vifs de la premiere visite) contre volume du tarif de l'essence exacte
# (ifn_tarif_schaeffer_reference(), type conseille, SER de la placette), sur
# les 1000 placettes « test » de prototype_finn_incertitude.R.
#
# Variables : FINN_INC_DONNEES (donnees.rds), FINN_VOL_IFN (dossier de
# l'export IFN : ARBRE.csv, PLACETTE.csv).

suppressMessages({library(data.table); pkgload::load_all(".", quiet = TRUE)})
d <- readRDS(Sys.getenv("FINN_INC_DONNEES")); ifn <- Sys.getenv("FINN_VOL_IFN")
ar <- fread(file.path(ifn, "ARBRE.csv"), sep = ";", select = c("CAMPAGNE", "IDP", "ESPAR", "C13", "V", "W", "VEGET"), colClasses = "character")
pla <- fread(file.path(ifn, "PLACETTE.csv"), sep = ";", select = c("IDP", "VISITE", "CAMPAGNE", "SER"), colClasses = "character")
v1 <- pla[VISITE == "1" & IDP %in% d$test, .(IDP, CAMPAGNE, ser = SER)]
ar <- merge(ar, v1, by = c("IDP", "CAMPAGNE"))[VEGET == "0" & nzchar(V)]
ar[, `:=`(D = as.numeric(C13) / pi * 100, V = as.numeric(V), W = as.numeric(W))]
cle <- unique(ar[, .(ESPAR, ser)])
tt <- rbindlist(lapply(seq_len(nrow(cle)), function(i) {
  r <- ifn_tarif_schaeffer_reference(cle$ESPAR[i], ser = cle$ser[i])
  data.table(ESPAR = cle$ESPAR[i], ser = cle$ser[i], numero = r$numero[r$type == r$type_conseille[1]][1],
             type = r$type_conseille[1])
}))
ar <- merge(ar, tt, by = c("ESPAR", "ser"))
ar[!is.na(type), Vt := volume_tarif_schaeffer(numero, D, type)]
cat("arbres", nrow(ar), " sans tarif", ar[is.na(Vt), .N], "\n")
cat("campagnes", paste(range(ar$CAMPAGNE), collapse = "-"), "\n")
x <- ar[!is.na(Vt), .(V_ifn = sum(W * V), V_tarif = sum(W * Vt), n = .N), by = ESPAR][order(-V_ifn)]
x[, ecart_pct := round(100 * (V_tarif / V_ifn - 1), 1)]
print(head(x, 12))
cat("total : ecart", round(100 * (x[, sum(V_tarif) / sum(V_ifn)] - 1), 1), "%\n")
print(ar[!is.na(Vt), .(ecart = round(100 * (sum(W * Vt) / sum(W * V) - 1), 1)), by = .(classe = cut(D, c(0, 20, 30, 45, 70, 200)))][order(classe)])
