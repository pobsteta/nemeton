# data-raw/infradensite_espar.R
#
# Construit inst/extdata/infradensite_espar.csv : infradensite (masse anhydre
# / volume frais, g/cm3) par essence IFN (ESPAR), pour le stock de carbone des
# trajectoires FINN et du C1 (spec 068).
#
# Source : Global Wood Density Database (Chave et al. 2009, Zanne et al. 2009,
# Dryad doi:10.5061/dryad.234, CC0 1.0). Dryad exige desormais un jeton pour
# telecharger le fichier ; la meme base est livree telle quelle dans le paquet
# CRAN BIOMASS (data/wdData.rda) : on n'en reprend que la donnee CC0.
#
# Variable : GWDD_RDA = chemin de wdData.rda (archive source de BIOMASS).
#
# Cascade, du plus precis au plus general (colonne `niveau`) :
#   1. espece_europe : moyenne des valeurs de l'espece, region « Europe » ;
#   2. espece        : moyenne de l'espece, toutes regions ;
#   3. genre         : moyenne des moyennes d'especes du genre, Europe et
#                      Amerique du Nord (le genre mondial tire Quercus a 0,70
#                      avec les chenes tropicaux) ;
#   4. groupe        : moyenne des essences IFN de niveaux 1-2, feuillus
#                      (ESPAR < 51) ou resineux (ESPAR >= 51).
# Nom latin = binome du pivot espece_sci de ifn_espar_correspondance.csv (sous-
# especes et varietes ramenees a l'espece, « x » des hybrides retire).

e <- new.env()
load(Sys.getenv("GWDD_RDA"), envir = e)
wd <- e$wdData
wd$bin <- paste(wd$genus, wd$species)

es <- utils::read.csv("inst/extdata/ifn_espar_correspondance.csv",
                      colClasses = "character", encoding = "UTF-8")
binome <- function(x) {
  w <- strsplit(trimws(x), " +")
  vapply(w, function(v) {
    v <- v[v != "x"]
    if (length(v) >= 2) paste(v[1], v[2]) else v[1]
  }, "")
}
es$bin <- binome(es$espece_sci)
es$genre <- sub(" .*", "", es$bin)
es$groupe <- ifelse(as.integer(sub("\\D.*", "", es$espar)) >= 51, "resineux", "feuillu")

moy_esp <- function(keep) {
  list(m = tapply(wd$wd[keep], wd$bin[keep], mean),
       n = tapply(wd$wd[keep], wd$bin[keep], length))
}
eu <- moy_esp(wd$region == "Europe")
tout <- moy_esp(rep(TRUE, nrow(wd)))
tempere <- wd$region %in% c("Europe", "NorthAmerica")
esp_tempere <- tapply(wd$wd[tempere], wd$bin[tempere], mean)
genre_esp <- sub(" .*", "", names(esp_tempere))
genre_m <- tapply(esp_tempere, genre_esp, mean)
genre_n <- tapply(esp_tempere, genre_esp, length)

es$infradensite <- NA_real_; es$niveau <- NA_character_; es$n_valeurs <- NA_integer_
poser <- function(sel, val, n, niveau) {
  sel <- sel & is.na(es$infradensite) & !is.na(val)
  es$infradensite[sel] <<- val[sel]
  es$n_valeurs[sel] <<- as.integer(n[sel])
  es$niveau[sel] <<- niveau
}
tous <- rep(TRUE, nrow(es))
poser(tous, eu$m[es$bin], eu$n[es$bin], "espece_europe")
poser(tous, tout$m[es$bin], tout$n[es$bin], "espece")
poser(tous, genre_m[es$genre], genre_n[es$genre], "genre")
precis <- es$niveau %in% c("espece_europe", "espece")
grp_m <- tapply(es$infradensite[precis], es$groupe[precis], mean)
grp_n <- tapply(es$infradensite[precis], es$groupe[precis], length)
poser(tous, grp_m[es$groupe], grp_n[es$groupe], "groupe")

out <- data.frame(
  espar = es$espar, lib_espar = es$lib_espar, nom_latin = es$bin,
  groupe = es$groupe, infradensite_g_cm3 = round(es$infradensite, 3),
  niveau = es$niveau, n_valeurs = es$n_valeurs,
  source = "Global Wood Density Database (Zanne et al. 2009, doi:10.5061/dryad.234, CC0)",
  stringsAsFactors = FALSE
)
# deux lignes de repli generiques, pour les codes sans ESPAR
out <- rbind(out, data.frame(
  espar = c("FEUILLU", "RESINEUX"), lib_espar = c("Feuillus", "Résineux"),
  nom_latin = NA_character_, groupe = c("feuillu", "resineux"),
  infradensite_g_cm3 = round(as.numeric(grp_m[c("feuillu", "resineux")]), 3),
  niveau = "groupe", n_valeurs = as.integer(grp_n[c("feuillu", "resineux")]),
  source = out$source[1], stringsAsFactors = FALSE
))
utils::write.csv(out, "inst/extdata/infradensite_espar.csv", row.names = FALSE,
                 fileEncoding = "UTF-8", na = "")
print(table(out$niveau))
print(out[out$espar %in% c("02", "03", "05", "09", "10", "17C", "51", "52", "61", "62", "64",
                           "FEUILLU", "RESINEUX"), c("espar", "lib_espar", "infradensite_g_cm3", "niveau")])
