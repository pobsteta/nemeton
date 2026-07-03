# data-raw/european_species_tolerances.R — spec 027 (calibration essences UE)
# ------------------------------------------------------------------
# Convertit data-raw/Essences_europeennes_tolerances.xlsx (fourni par Pascal,
# 2026-07-03) en inst/extdata/european_species_tolerances.csv, table de
# référence des tolérances au repeuplement pour ~193 essences européennes.
#
# Trois périmètres empilés (colonne `statut`) :
#   frm_1999  : Annexe I Directive 1999/105/CE en vigueur (47) — Confiance Élevé.
#   frm_2025  : Ajouts Annexe I futur règlement FRM (accord 8/12/2025, 17).
#   atlas_jrc : Dendroflore European Atlas of Forest Tree Species (JRC) hors
#               liste FRM (~130) — canevas DÉRIVÉ PAR RÈGLE, à valider.
#
# Axes : tmax_tol_c / vpd_tol_kpa (mêmes axes que regeneration_tolerances(),
# ici sourcés/calibrés par espèce), + tolérances Niinemets & Valladares (2006)
# sécheresse/ombre/engorgement (1–5), gel, thermophilie (1–9), humidité de l'air.
#
# Colonne `confidence` (eleve/moyen/faible) : NE PAS utiliser les lignes
# `faible` (estimées par règle) en opérationnel sans validation. `invasif` :
# taxons signalés INTRO/INVASIF (présence ≠ recommandation).
#
# Sources (onglet 2 du xlsx) : Directive 1999/105/CE Annexe I ; COM(2023)415 &
# accord 8/12/2025 ; San-Miguel-Ayanz et al. (2016) European Atlas of Forest
# Tree Species ; Caudullo, Welk & San-Miguel-Ayanz (2017) Data in Brief 12 ;
# Niinemets & Valladares (2006) Ecol. Monogr. 76:521–547 ; Münchinger et al.
# (2023) ; Visakorpi et al. (2024) ; EUFORGEN ; Ellenberg ; ClimEssences (RMT
# AFORCE). Cf. inst/REFERENCES.md.
#
# Régénérer : Rscript data-raw/european_species_tolerances.R  (nécessite readxl)

stopifnot(requireNamespace("readxl", quietly = TRUE))

f <- file.path("data-raw", "Essences_europeennes_tolerances.xlsx")
d <- readxl::read_excel(f, sheet = 1, skip = 2, .name_repair = "minimal")
names(d) <- gsub("[\r\n]+", " ", trimws(names(d)))
d <- d[!is.na(d[[1]]) & nzchar(trimws(d[[1]])), ]

# Code technique NMT depuis le nom scientifique : "Abies alba" -> "abies_alba".
mk_code <- function(x) {
  x <- tolower(trimws(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

norm_statut <- function(x) {
  x <- trimws(x)
  ifelse(grepl("1999", x), "frm_1999",
  ifelse(grepl("2025", x), "frm_2025", "atlas_jrc"))
}
norm_conf <- function(x) {
  x <- tolower(trimws(x))
  ifelse(grepl("lev", x), "eleve", ifelse(grepl("moy", x), "moyen", "faible"))
}
norm_type <- function(x) ifelse(grepl("onif", x), "conifere", "feuillu")
num <- function(x) suppressWarnings(as.numeric(x))

# Rattachement espèce -> classe NMT (list_species_classes) par règle de genre.
# APPROXIMATION assumée : sert au repérage « présent sur UGF » du sélecteur, pas
# à la botanique fine. Chênes sempervirents & sclérophylles med -> chene_vert ;
# autres feuillus natifs -> feuillus_pionniers ; exotiques/incertains -> mixte.
.EVERGREEN_QUERCUS <- c("ilex", "suber", "coccifera", "rotundifolia", "alnifolia")
.MED_SCLEROPHYLL_GENERA <- c("Olea", "Arbutus", "Pistacia", "Phillyrea", "Myrtus",
                             "Ceratonia", "Laurus", "Nerium", "Punica", "Quercus")
map_species_class <- function(sci) {
  parts <- strsplit(trimws(sci), "\\s+")[[1]]
  genus <- parts[1]; epithet <- if (length(parts) >= 2) tolower(parts[2]) else ""
  if (genus %in% c("Abies", "Picea")) return("essence_pessiere_sapiniere")
  if (genus == "Pseudotsuga") return("essence_douglasaie")
  if (genus == "Larix") return("essence_melezin")
  if (genus %in% c("Pinus", "Cedrus", "Juniperus", "Cupressus", "Taxus",
                   "Tetraclinis")) return("essence_pinede")
  if (genus == "Fagus") return("essence_hetraie")
  if (genus == "Castanea") return("essence_chataigneraie")
  if (genus == "Populus") return("essence_peupleraie")
  if (genus == "Quercus") {
    return(if (epithet %in% .EVERGREEN_QUERCUS) "essence_chene_vert" else "essence_chenaie")
  }
  if (genus %in% .MED_SCLEROPHYLL_GENERA) return("essence_chene_vert")
  # Feuillus natifs d'accompagnement.
  if (genus %in% c("Acer", "Fraxinus", "Carpinus", "Betula", "Alnus", "Salix",
                   "Sorbus", "Prunus", "Tilia", "Ulmus", "Corylus", "Ostrya",
                   "Crataegus", "Pyrus", "Malus", "Mespilus", "Cornus",
                   "Rhamnus", "Frangula", "Euonymus", "Viburnum", "Sambucus",
                   "Ilex", "Laburnum", "Buxus", "Ligustrum", "Colutea",
                   "Hippophae", "Erica", "Juglans")) {
    return("essence_feuillus_pionniers")
  }
  "essence_mixte"  # exotiques / introduits / incertains
}

out <- data.frame(
  code               = mk_code(d[[1]]),
  species_sci        = trimws(d[[1]]),
  species_fr         = trimws(d[[2]]),
  type               = norm_type(d[[3]]),
  species_class      = vapply(d[[1]], map_species_class, character(1), USE.NAMES = FALSE),
  statut             = norm_statut(d[[4]]),
  tmax_tol_c         = num(d[[5]]),
  vpd_tol_kpa        = num(d[[6]]),
  drought_tol        = num(d[[7]]),   # Séch. N&V 1–5 (1 intolérant → 5 tolérant)
  shade_tol          = num(d[[8]]),   # Ombre/couvert 1–5 = aptitude régé sous couvert
  waterlog_tol       = num(d[[9]]),   # Engorgement 1–5
  frost_winter_min_c = num(d[[10]]),  # Gel hiver toléré (°C)
  frost_late         = num(d[[11]]),  # Gel tardif 1→5 (1 sensible → 5 peu sensible)
  frost_early        = num(d[[12]]),  # Gel précoce 1→5
  air_humidity       = trimws(d[[13]]),
  thermophily        = num(d[[14]]),  # 1→9
  confidence         = norm_conf(d[[15]]),
  invasif            = grepl("INVASIF|INTRO", paste(d[[16]], d[[1]]), ignore.case = TRUE),
  notes              = trimws(d[[16]]),
  stringsAsFactors = FALSE
)
stopifnot(!any(duplicated(out$code)))

utils::write.csv(
  out,
  file = file.path("inst", "extdata", "european_species_tolerances.csv"),
  row.names = FALSE, fileEncoding = "UTF-8"
)
message(sprintf("Wrote %d species (%d FRM, %d Atlas, %d invasif) to CSV.",
                nrow(out), sum(grepl("^frm", out$statut)),
                sum(out$statut == "atlas_jrc"), sum(out$invasif)))
