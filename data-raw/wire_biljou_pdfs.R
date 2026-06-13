# wire_biljou_pdfs.R — relie les PDF hébergés par BILJOU (data-raw/references/
# biljou/) aux doc_id, passe en full-text et retague copyright -> HAL.
# Décision Pascal 2026-06-13 : PDF publiquement hébergés par INRAE/BILJOU,
# usage recherche ; tag HAL (archive ouverte) cohérent avec Bontemps/Charru.
#   Rscript data-raw/wire_biljou_pdfs.R
suppressMessages(pkgload::load_all(quiet = TRUE))

dir <- "data-raw/references/biljou"
map <- c(
  breda_2006_drought_review            = "ASF_Secheresse2006.pdf",
  aussenac_2000_microclimate           = "Aussenac2000.pdf",
  aussenac_1995_structure_couvert      = "Aussenac_1995_bad.pdf",
  aussenac_1970_couvert_precipitations = "Aussenac_AFS_1970.pdf",
  aussenac_1980_interception           = "Aussenac_Boulangeat.1980.pdf",
  aussenac_1979_bioclimatique          = "Aussenac_Granier_AFS_1979.pdf",
  ballif_1983_lysimetrie_craie         = "Ballif_Dutil_1983.pdf",
  bernier_2002_canopy_gas_exchange     = "Bernier_et_al2002.pdf",
  beven_1982_macropores                = "Beven1982.pdf",
  bouriaud_2003_lai_litter             = "Bouriaud.pdf",
  breda_1993_water_transfer_oak        = "Breda_1992_Can.J.For.Res.pdf",
  breda_1999_indice_foliaire           = "Breda_1999.pdf",
  breda_2002_reservoir_sols            = "Breda_2002_LaHouilleBlanche.pdf",
  breda_2002_conduite_ressources_eau   = "Breda_Roman_Amat_2002.pdf",
  brethes_1997_renecofor_pedologie     = "Brethes_et_al_1997_Description_sols.pdf",
  breda_1995_soil_water_oak            = "Bréda_PlantSoil1995.pdf",
  cermak_2001_floodplain               = "Cermak2001.pdf",
  quentin_2001_sols_hesse              = "EGS_Hesse_RU.pdf",
  garbaye_1997_ectomycorhizes          = "Garbaye_Guehl_1997.pdf",
  granier_1999_lumped_water_balance    = "Granier.1999.pdf",
  granier_1996_sapflow                 = "Granier1996_GCB.pdf",
  granier_2000_water_balance_beech     = "GranierAFM2000.pdf",
  granier_2000_canopy_conductance      = "Granier_Loustau_Breda_2000.pdf",
  granier_1995_bilan_hydrique          = "Granier_al_1995.pdf",
  pitman_2010_litterfall               = "ICP_Forest_Litter_2010.pdf",
  breda_2003_lai_review                = "JexpBotLAI.pdf",
  klinge_2001_drainage_simulation      = "Klinge2001.pdf",
  breda_2008_lai_ecology               = "LAI_Encyclopedia_of_Ecology_849.pdf",
  lagergren_2002_transpiration         = "Lagergren2002.pdf",
  lebourgeois_2002_phenologie          = "Lebourgeois_al_2002.pdf",
  badeau_2008_renecofor_faisabilite    = "Livre_Jaune_VBadeau_2008_renecofor.pdf",
  llorens_1997_interception_pinus      = "Llorens1997.pdf",
  loustau_1992_interception_pine       = "Loustau_et_al_1992.pdf",
  minderman_1968_drainage_lysimeters   = "Minderman1968.pdf",
  peiffer_2005_hetraies                = "PEIFFER_al_2005.pdf",
  rambal_1984_root_water_uptake        = "Rambal1984.pdf",
  rowe_1983_interception_beech         = "Rowe1983.pdf",
  breda_2008_pompe_biologique          = "SEC2008_Marion_final.pdf",
  sadras_1996_soil_water_thresholds    = "Sadras1996_REW04_culture.pdf",
  saugier_2002_forets_cycle_eau        = "Saugier_2002.pdf",
  soudani_2008_greenup_modis           = "Soudani_et_al_2008_RENECOFOR_MODIS.pdf",
  vincke_2005_evapotranspiration_i     = "Vincke_et_al_2001a.pdf",
  vincke_2005_evapotranspiration_ii    = "Vincke_et_al_2001b.pdf",
  falkenmark_2006_blue_green_water     = "falkenmark-and-rockstrom.pdf"
)

m <- read_knowledge_manifest()
wired <- 0; missing_file <- character(0); missing_id <- character(0)
for (id in names(map)) {
  path <- file.path(dir, map[[id]])
  if (!file.exists(path)) { missing_file <- c(missing_file, map[[id]]); next }
  i <- which(m$doc_id == id)
  if (!length(i)) { missing_id <- c(missing_id, id); next }
  m$ingest_strategy[i] <- "full"
  m$local_path[i] <- path
  if (identical(m$license[i], "copyright")) {
    m$license[i] <- "HAL"            # archive ouverte / hosting INRAE BILJOU
    m$license_commercial_ok[i] <- "FALSE"
  }
  wired <- wired + 1
}
cat("câblés :", wired, "| fichiers absents :", length(missing_file),
    "| doc_id absents :", length(missing_id), "\n")
if (length(missing_file)) cat("  fichiers absents :", paste(missing_file, collapse=", "), "\n")
if (length(missing_id))   cat("  doc_id absents :", paste(missing_id, collapse=", "), "\n")

issues <- validate_knowledge_manifest(m)
errs <- issues[issues$severity == "error", , drop = FALSE]
if (nrow(errs)) { print(errs); stop("validation echouee, rien ecrit") }

write_knowledge_manifest(m, path = knowledge_manifest_path())
cat("strategies:\n"); print(table(m$ingest_strategy))
cat("licenses (full):\n"); print(table(m$license[m$ingest_strategy=="full"]))
