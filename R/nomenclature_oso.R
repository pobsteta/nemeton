# nomenclature_oso.R
# Nomenclature OSO (Theia / CESBIO) a 23 classes, partagee par L1, L2, A1,
# W2, RECONFORT et inst/datasources/FR.json. Source unique : toute table qui
# interprete un code OSO doit en deriver plutot que de recopier des codes.

#' OSO land-cover nomenclature (23 classes, Theia / CESBIO)
#'
#' Codes of the national OSO land-cover product (2018 onwards). Forest is
#' split into broadleaf (16) and coniferous (17); there is no mixed-forest
#' class. Used internally as the single source of the OSO codes read by L1
#' (edge contrast), L2 (forest mask), A1 (forest share), W2 (no wetland class)
#' and the RECONFORT broadleaf mask.
#' @noRd
OSO_NOMENCLATURE <- data.frame(
  code = 1:23,
  cle = c(
    "bati_dense", "bati_diffus", "zones_industrielles", "routes",
    "colza", "cereales_paille", "proteagineux", "soja", "tournesol",
    "mais", "riz", "tubercules", "prairies", "vergers", "vignes",
    "foret_feuillus", "foret_coniferes", "pelouses", "landes_ligneuses",
    "surfaces_minerales", "plages_dunes", "glaciers_neiges", "eau"
  ),
  # Contraste de matrice de L1 (0 = foret, 100 = matrice la plus hostile).
  # Valeurs reprises de la table d'origine (bati 90, routes 75, cultures 50,
  # vignes 45, eau 30, prairies 20, landes 15, foret 0) ; vergers alignes sur
  # les vignes, pelouses sur les prairies ; surfaces minerales, plages et
  # glaciers sans valeur d'origine gardent le contraste neutre 50.
  contraste_l1 = c(
    90, 90, 90, 75,
    50, 50, 50, 50, 50, 50, 50, 50,
    20, 45, 45,
    0, 0, 20, 15,
    50, 50, 50, 30
  ),
  stringsAsFactors = FALSE
)

#' OSO forest codes (broadleaf 16, coniferous 17)
#' @noRd
OSO_CLASSES_FORET <- c(foret_feuillus = 16L, foret_coniferes = 17L)

#' OSO broadleaf-forest code (RECONFORT deciduous mask)
#' @noRd
OSO_CLASSE_FEUILLUS <- 16L
