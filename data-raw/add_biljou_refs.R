# add_biljou_refs.R — ajoute au manifest RAG toutes les références citées
# sur le site BILJOU (INRAE Nancy, modèle de bilan hydrique forestier).
# https://appgeodb.nancy.inrae.fr/biljou/fr/  (11 fiches pédagogiques)
#
# Toutes les refs entrent en to_confirm / abstract_only / copyright :
# licences non vérifiables depuis le site (articles de revue, ouvrages).
# Le gel D5 (009.1 §5) interdit l'ingestion full-text avant arbitrage.
#
#   Rscript data-raw/add_biljou_refs.R
suppressMessages(pkgload::load_all(quiet = TRUE))

# strip accents pour coller au style maison (titres sans accents dans le CSV)
noacc <- function(x) iconv(x, to = "ASCII//TRANSLIT")

# doc_id | title | author | publisher | year | lang | doc_type | family_codes | profile_codes | notes_extra
raw <- "
peiffer_2005_hetraies|Bilan d'eau, de carbone et croissances comparees de deux hetraies de plaine|Peiffer M, Le Goff N, Nys C, Ottorini J-M, Granier A|Revue forestiere francaise LVII|2005|fr|paper|W|C|technicien|chercheur|
granier_1995_bilan_hydrique|Modelisation du bilan hydrique des peuplements forestiers|Granier A, Badeau V, Breda N|Revue forestiere francaise XLVII|1995|fr|paper|W|R3|gestionnaire_onf|technicien|chercheur|Reference fondatrice BILJOU
aussenac_1980_interception|Interception des precipitations et evapotranspiration reelle dans des peuplements de feuillus et de resineux|Aussenac G, Boulangeat C|Annales des Sciences forestieres 37(2)|1980|fr|paper|W|technicien|chercheur|
breda_2006_drought_review|Temperate forest trees and stands under severe drought: a review of ecophysiological responses, adaptation processes and long-term consequences|Breda N, Huc R, Granier A, Dreyer E|Annals of Forest Science 63|2006|en|paper|R3|W|gestionnaire_onf|chercheur|
granier_2000_water_balance_beech|Water balance, transpiration and canopy conductance in two beech stands|Granier A, Biron P, Lemoine D|Agricultural and Forest Meteorology 100|2000|en|paper|W|C|technicien|chercheur|
bertin_2013_bilan_hydrique_aforce|Le bilan hydrique des peuplements forestiers. Etat des connaissances scientifiques et techniques|Bertin S, Balandier P, Becquey J, Bonal D, Breda N, Perrier C, Riou-Nivert P, Sevrin E|RMT AFORCE|2013|fr|report|W|R3|gestionnaire_onf|technicien|chercheur|190 p
courbet_2022_foret_eau_quae|Foret et changement climatique - Comprendre et modeliser le fonctionnement hydrique des arbres|Courbet F, Doussan C, Limousin J-M, Martin-St Paul N, Simioni G|Editions Quae|2022|fr|report|W|R3|gestionnaire_onf|chercheur|Collection Syntheses, 144 p
aussenac_1979_bioclimatique|Etude bioclimatique d'une futaie feuillue II. Etude de l'humidite du sol de l'evapotranspiration reelle|Aussenac G, Granier A|Annales des Sciences Forestieres 36|1979|fr|paper|W|technicien|chercheur|
breda_1993_water_transfer_oak|Water transfer in a mature oak stand (Quercus petraea): seasonal evolution and effects of a severe drought|Breda N, Cochard H, Dreyer E, Granier A|Canadian Journal of Forest Research 23|1993|en|paper|W|R3|technicien|chercheur|
granier_1996_sapflow|Transpiration of trees and forest stands: short and long-term monitoring using sapflow methods|Granier A, Biron P, Breda N, Pontailler J-Y, Saugier B|Global Change Biology 2(3)|1996|en|paper|W|C|technicien|chercheur|
granier_2000_canopy_conductance|A generic model of forest canopy conductance dependent on climate, soil water availability and leaf area index|Granier A, Loustau D, Breda N|Annals of Forest Science 57(8)|2000|en|paper|W|C|technicien|chercheur|
lagergren_2002_transpiration|Transpiration response to soil moisture in pine and spruce trees in Sweden|Lagergren F, Lindroth A|Agricultural and Forest Meteorology 112(2)|2002|en|paper|W|technicien|chercheur|
vincke_2005_evapotranspiration_i|Evapotranspiration of a declining Quercus robur stand from 1999 to 2001. I. Trees and forest floor daily transpiration|Vincke C, Breda N, Granier A, Devillez F|Annals of Forest Science 62(6)|2005|en|paper|W|R3|technicien|chercheur|
aussenac_1970_couvert_precipitations|Action du couvert forestier sur la distribution au sol des precipitations|Aussenac G|Annales des sciences forestieres 27(4)|1970|fr|paper|W|technicien|chercheur|
ulrich_1995_interception_renecofor|Interception des pluies en foret : facteurs determinants. RENECOFOR sous-reseau CATAENAT|Ulrich E, Lelong N, Lanier M, Schneider|ONF Bulletin technique n.30|1995|fr|report|W|technicien|chercheur|
llorens_1997_interception_pinus|Rainfall interception by a Pinus sylvestris forest patch overgrown in a Mediterranean mountainous abandoned area. 2. Gash's analytical model|Llorens P|Journal of Hydrology 199(3-4)|1997|en|paper|W|technicien|chercheur|
loustau_1992_interception_pine|Interception loss, throughfall and stemflow in a maritime pine stand. 1. Variability of throughfall and stemflow beneath the pine canopy|Loustau D, Berbigier P, Granier A, Elhadjmoussa F|Journal of Hydrology 138|1992|en|paper|W|technicien|chercheur|
rowe_1983_interception_beech|Rainfall interception by an evergreen beech forest, Nelson, New Zealand|Rowe L K|Journal of Hydrology 66|1983|en|paper|W|technicien|chercheur|
badeau_2008_renecofor_faisabilite|RENECOFOR - Etude critique de faisabilite sur la comparabilite des donnees meteorologiques, l'estimation de la reserve utile en eau du sol et le calcul des volumes d'eau drainee|Badeau V, Ulrich E|Office National des Forets|2008|fr|report|W|F|gestionnaire_onf|technicien|chercheur|ISBN 978-2-84207-323-7
badeau_2008_modelisation_bilan|Modelisation du bilan hydrique : etape cle de la determination des parametres et des variables d'entree|Badeau V, Breda N|RDV techniques hors-serie n.4 ONF|2008|fr|report|W|gestionnaire_onf|technicien|chercheur|
breda_2002_reservoir_sols|Reservoir en eau des sols forestiers temperes : specificite et difficultes d'evaluation|Breda N, Lefevre Y, Badeau V|La Houille Blanche 3-2002|2002|fr|paper|W|F|technicien|chercheur|
brethes_1997_renecofor_pedologie|RENECOFOR - Caracteristiques pedologiques des 102 peuplements du reseau|Brethes A, Ulrich E|Office National des Forets|1997|fr|report|F|W|gestionnaire_onf|technicien|chercheur|ISBN 2-84207-112-3
quentin_2001_sols_hesse|Etude des sols de la foret de Hesse (Lorraine). Contribution a l'etude du bilan hydrique|Quentin C, Bigorre F, Breda N, Granier A, Teissier D|Etude et Gestion des Sols 8|2001|fr|paper|F|W|technicien|chercheur|
garbaye_1997_ectomycorhizes|Le role des ectomycorhizes dans l'utilisation de l'eau par les arbres forestiers|Garbaye J, Guehl J M|Revue Forestiere Francaise XLIX sp 1997|1997|fr|paper|W|B|naturaliste|chercheur|technicien|
breda_2008_pompe_biologique|Une pompe biologique performante|Breda N, Zapater M, Barlet C, Lefevre Y, Granier A|SEC2008 Volume 1|2008|fr|paper|W|technicien|chercheur|
breda_1995_soil_water_oak|Soil water dynamics in an oak stand|Breda N, Granier A, Barataud F, Moyne C|Plant and Soil 172(1)|1995|en|paper|W|technicien|chercheur|
cermak_2001_floodplain|Water balance of a Southern Moravian floodplain forest|Cermak J, Prax A|Annals of Forest Science 58(1)|2001|en|paper|W|W2|chercheur|
rambal_1984_root_water_uptake|Water balance and pattern of root water uptake by a Quercus coccifera L. evergreen scrub|Rambal S|Oecologia 62|1984|en|paper|W|R3|chercheur|
vincke_2005_evapotranspiration_ii|Evapotranspiration of a declining Quercus robur stand from 1991 to 2001. II. Daily evapotranspiration and soil water dynamics|Vincke C, Breda N, Granier A, Devillez F|Annals of Forest Science 62(7)|2005|en|paper|W|R3|technicien|chercheur|
aussenac_1995_structure_couvert|Effets des modifications de la structure du couvert forestier sur le bilan hydrique, l'etat hydrique des arbres et la croissance|Aussenac G, Granier A, Breda N|Revue Forestiere Francaise XLVII|1995|fr|paper|W|C|gestionnaire_onf|technicien|chercheur|
breda_1999_indice_foliaire|L'indice foliaire des couverts forestiers : mesure, variabilite et role fonctionnel|Breda N|Revue Forestiere Francaise LI-2|1999|fr|paper|C|W|technicien|chercheur|
breda_2002_mesure_indice_foliaire|Mesure de l'indice foliaire en foret|Breda N, Soudani K, Bergonzini J C|GIP-ECOFOR|2002|fr|manual|C|W|technicien|chercheur|ISBN 2-914770-02-2
lebourgeois_2002_phenologie|Premieres observations phenologiques des peuplements du reseau national de suivi a long terme des ecosystemes forestiers|Lebourgeois F, Differt J, Granier A, Breda N, Ulrich E|Revue Forestiere Francaise LIV|2002|fr|paper|T|C|technicien|chercheur|
aussenac_2000_microclimate|Interactions between forest stands and microclimate: ecophysiological aspects and consequences for silviculture|Aussenac G|Annals of Forest Science 57|2000|en|paper|A|W|technicien|chercheur|
breda_2008_lai_ecology|Leaf area index in ecology|Breda N|Encyclopedia of Ecology (Elsevier)|2008|en|report|C|chercheur|
pitman_2010_litterfall|Sampling and analysing of litterfall|Pitman R, Bastrup-Birk A, Breda N, Rautio P|ICP Forests Manual|2010|en|manual|C|technicien|chercheur|ISBN 978-3-926301-03-1
breda_2003_lai_review|Ground-based measurements of leaf area index: a review of methods, instruments and current controversies|Breda N J J|Journal of Experimental Botany 54(392)|2003|en|paper|C|technicien|chercheur|
bouriaud_2003_lai_litter|Leaf area index from litter collection: impact of specific leaf area variability within a beech stand|Bouriaud O, Soudani K, Breda N|Canadian Journal of Remote Sensing 29(3)|2003|en|paper|C|chercheur|
soudani_2008_greenup_modis|Evaluation of the onset of green-up in temperate deciduous broadleaf forests derived from MODIS data|Soudani K, le Maire G, Dufrene E, Francois C, Delpierre N, Ulrich E, Cecchini S|Remote Sensing of Environment 112|2008|en|paper|C2|T2|chercheur|
badeau_2017_plantes_saisons|Les plantes au rythme des saisons|Badeau V, Bonhomme M, Bonne F et al.|Biotope Editions|2017|fr|report|T|C|naturaliste|chercheur|336 p
peiffer_2008_renecofor_meteo|RENECOFOR - Monitoring local forest weather conditions (France and Luxemburg), report for 1995-2004|Peiffer M, Badeau V, Breda N, Ulrich E|Office National des Forets|2008|en|report|W|R3|gestionnaire_onf|technicien|chercheur|ISBN 978-2-84207-325-1
allen_1998_fao56_evapotranspiration|Crop evapotranspiration - Guidelines for computing crop water requirements - FAO Irrigation and drainage paper 56|Allen R G, Pereira L S, Raes D, Smith M|FAO|1998|en|report|W|technicien|chercheur|
ballif_1983_lysimetrie_craie|Lysimetrie en sol de craie non remanie. I - Drainage, evaporation et role du couvert vegetal. Resultats 1973-1980|Ballif J L, Dutil P|Agronomie 3|1983|fr|paper|W|F|technicien|chercheur|
beven_1982_macropores|Macropores and water flow in soils|Beven K, Germann P|Water Resources Research 18(5)|1982|en|paper|W|W3|chercheur|
klinge_2001_drainage_simulation|Simulation of water drainage of a rain forest and forest conversion plots using a soil water model|Klinge R, Schmidt J, Folster H|Journal of Hydrology 246|2001|en|paper|W|chercheur|
minderman_1968_drainage_lysimeters|The amount of drainage water and solutes from lysimeters planted with either oak, pine or natural dune vegetation, or without any vegetation cover|Minderman G, Leeflang K W F|Plant and Soil XXVIII(1)|1968|en|paper|W|chercheur|
bernier_2002_canopy_gas_exchange|Validation of a canopy gas exchange model and derivation of a soil water modifier for transpiration for sugar maple|Bernier P, Breda N, Granier A, Raulier F, Mathieu F|Forest Ecology and Management 163(1)|2002|en|paper|R3|W|chercheur|
granier_1999_lumped_water_balance|A lumped water balance model to evaluate duration and intensity of drought constraints in forest stands|Granier A, Breda N, Biron P, Villette S|Ecological Modelling 116|1999|en|paper|R3|W|gestionnaire_onf|technicien|chercheur|Modele BILJOU (papier de reference)
sadras_1996_soil_water_thresholds|Soil-water thresholds for the responses of leaf expansion and gas exchange: a review|Sadras V O, Milroy S P|Field Crops Research 47|1996|en|paper|R3|W|chercheur|
falkenmark_2006_blue_green_water|The new blue and green water paradigm: breaking new ground for water resources planning and management|Falkenmark M, Rockstrom J|Journal of Water Resources Planning and Management|2006|en|paper|W|chercheur|elu_regional|
birot_2011_water_forests_med_en|Water for forests and people in the Mediterranean region - a challenging balance|Birot Y, Gracia C, Palahi M|EFI What Science Can Tell Us 1|2011|en|report|W|R3|gestionnaire_onf|elu_regional|chercheur|ISBN 978-952-5453-80-5
birot_2011_eau_forets_med_fr|L'eau pour les forets et les hommes en region mediterraneenne : un equilibre a trouver|Birot Y, Garcia C, Palahi M|EFI What Science Can Tell Us 1|2011|fr|report|W|R3|gestionnaire_onf|elu_regional|chercheur|ISBN 978-952-5453-82-9
breda_2002_conduite_ressources_eau|Impact de la conduite des peuplements forestiers sur les ressources en eau|Breda N, Roman-Amat B|La Houille Blanche (3)|2002|fr|paper|W|P|gestionnaire_onf|technicien|chercheur|
saugier_2002_forets_cycle_eau|Comment les forets controlent-elles le cycle de l'eau ?|Saugier B|La Houille Blanche (3)|2002|fr|paper|W|citoyen|chercheur|
"

lines <- Filter(nzchar, trimws(strsplit(raw, "\n")[[1]]))
parts <- strsplit(lines, "|", fixed = TRUE)

rows <- lapply(parts, function(p) {
  # p: doc_id,title,author,publisher,year,lang,doc_type, then family/profile/notes
  # family_codes = champs jusqu'au 1er code profil ; profiles = jusqu'au notes.
  # Convention d'ecriture : on liste familles puis profils ; le helper recolle
  # avec '|' donc on doit re-separer. Pour rester sans ambiguite on encode
  # family/profiles/notes par positions fixes : voir mapping ci-dessous.
  p
})

# Le split '|' a aussi decoupe les codes multi-valeurs. On reconstruit
# proprement : champs 1-7 fixes, puis on identifie familles (regex) vs profils
# (vocab) vs notes (reste).
vocab <- knowledge_manifest_vocab()
fam_re <- vocab$family_regex
profs  <- vocab$profiles

mk <- function(p) {
  doc_id <- p[1]; title <- p[2]; author <- p[3]; publisher <- p[4]
  year <- p[5]; lang <- p[6]; doc_type <- p[7]
  rest <- p[-(1:7)]
  fam <- character(0); prof <- character(0); note_extra <- ""
  for (tok in rest) {
    if (grepl(fam_re, tok) && !(tok %in% profs)) fam <- c(fam, tok)
    else if (tok %in% profs) prof <- c(prof, tok)
    else note_extra <- if (nzchar(note_extra)) paste(note_extra, tok) else tok
  }
  notes <- "Cite sur BILJOU (INRAE Nancy, modele bilan hydrique) - licence a confirmer"
  if (nzchar(note_extra)) notes <- paste0(notes, " ; ", note_extra)
  data.frame(
    doc_id = doc_id,
    title = noacc(title),
    author = noacc(author),
    publisher = noacc(publisher),
    pub_date = paste0(year, "-01-01"),
    lang = lang,
    doc_type = doc_type,
    source_url = "",
    license = "copyright",
    license_commercial_ok = "FALSE",
    family_codes = paste(fam, collapse = "|"),
    profile_codes = paste(prof, collapse = "|"),
    ingest_strategy = "abstract_only",
    local_path = "",
    status = "to_confirm",
    notes = noacc(notes),
    stringsAsFactors = FALSE)
}

new_rows <- do.call(rbind, lapply(parts, mk))
cat("Nouvelles refs construites :", nrow(new_rows), "\n")

man <- read_knowledge_manifest()
dups <- intersect(man$doc_id, new_rows$doc_id)
if (length(dups)) stop("doc_id deja present : ", paste(dups, collapse = ", "))

combined <- rbind(man, new_rows)
issues <- validate_knowledge_manifest(combined)
errs <- issues[issues$severity == "error", , drop = FALSE]
if (nrow(errs)) {
  cat("ERREURS DE VALIDATION :\n"); print(errs)
  stop("validation echouee, rien ecrit")
}
warns <- issues[issues$severity == "warning", , drop = FALSE]
if (nrow(warns)) { cat("Avertissements :\n"); print(warns) }

path <- knowledge_manifest_path()   # source du repo : inst/extdata/knowledge_corpus_v1.csv
write_knowledge_manifest(combined, path = path)
cat("Manifest ecrit :", path, "|", nrow(combined), "docs\n")
print(table(combined$status))
