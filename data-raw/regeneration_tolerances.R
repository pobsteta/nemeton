# data-raw/regeneration_tolerances.R — spec 027 L3
# ------------------------------------------------------------------
# Per-species regeneration tolerance thresholds consumed by
# regeneration_index(): the maximum under-canopy summer T°max (°C) and
# vapour-pressure deficit (kPa) a target species tolerates for successful
# natural regeneration. Beyond these thresholds the species-relative
# potential is penalised (a thermophilic oak tolerates a hotter, drier
# microsite than a mesophilic beech).
#
# INDICATIVE values, keyed on the species classes of list_species_classes()
# (species-config). Documented, NOT field-calibrated (spec 027 §7/§12): they
# order species sensitivity, they are not absolute physiological limits.
# Sources to consolidate on calibration: silvicultural autecology (Rameau
# Flore forestière), ONF/CNPF station guides, ClimEssences.

tolerances <- data.frame(
  code = c(
    "essence_hetraie", "essence_pessiere_sapiniere", "essence_melezin",
    "essence_douglasaie", "essence_chataigneraie", "essence_chenaie",
    "essence_mixte", "essence_feuillus_pionniers", "essence_peupleraie",
    "essence_pinede", "essence_chene_vert"
  ),
  label = c(
    "Hêtraie", "Pessière-Sapinière", "Mélézin", "Douglasaie",
    "Châtaigneraie", "Chênaie", "Forêt mixte", "Feuillus pionniers",
    "Peupleraie", "Pinède", "Chêne vert"
  ),
  # Max tolerated under-canopy summer T°max (°C): thermophilic species higher.
  tmax_tol_c = c(28.0, 27.0, 29.0, 30.0, 31.0, 32.0, 31.0, 33.0, 33.0, 34.0, 38.0),
  # Max tolerated under-canopy summer VPD (kPa): drought-sensitive lower.
  # Poplar is heat-tolerant but water-demanding -> low vpd_tol.
  vpd_tol_kpa = c(1.8, 1.6, 2.0, 2.2, 2.2, 2.5, 2.4, 2.6, 1.8, 3.0, 3.8),
  stringsAsFactors = FALSE
)

utils::write.csv(
  tolerances,
  file = file.path("inst", "extdata", "regeneration_tolerances.csv"),
  row.names = FALSE, fileEncoding = "UTF-8"
)
