# build_ifn_tarifs_schaeffer.R — numéros de tarif Schaeffer par SER (spec 062)
# ==========================================================================
# Produit trois tables dans inst/extdata/, au format embarqué par Marculus
# (brief Marculus du 2026-10-16 : séparateur `;`, UTF-8 sans BOM, champ vide
# pour une valeur absente) :
#   - ifn_tarif_schaeffer_ser.csv  niveau;code;espar;essence_libelle;type;
#                                  numero;n_arbres;cv;millesime;part_houppier
#   - emerge_coefficients.csv      coefficients EMERGE par espar (part de houppier)
#   - communes_ser.csv             insee;nom;departement;ser;part;greco
#   - ser.csv                      code;nom;greco
#
# SOURCES ET LICENCES
# -------------------
# - IFN : IGN – Inventaire forestier national français, Données brutes,
#   Campagnes annuelles 2005 et suivantes,
#   https://inventaire-forestier.ign.fr/dataIFN/, Licence Ouverte Etalab v2.0.
# - SER : couche inrae:ser_l93 (IGN, servie par INRAE), cf. localiser_ser().
# - Communes : Etalab contours-administratifs (dérivé d'ADMIN EXPRESS, IGN),
#   communes-100m, Licence Ouverte. ADMIN EXPRESS COG CARTO n'est servi qu'en
#   .7z ; le dérivé Etalab se lit directement par /vsigzip/.
#
# MÉTHODE : `PPtools::TarifFindSch()` et `TarifIFN()` de Max Bruciamacchie
# (AgroParisTech Nancy), GPL-2, reprise sous GPL-3 avec son autorisation
# explicite (courriel du 22 juillet 2026, qui couvre tout PPtools). Calcul dans
# `calculer_tarifs_schaeffer()` (R/ifn_tarifs.R), partagé avec
# `tarif_schaeffer_local()` : une seule chaîne, un seul millésime.
#
# Écarts à PPtools (spec 062) : variance à poids de fiabilité au lieu de
# Hmisc::wtd.var ; pas de krigeage ; fenêtre des 15 dernières campagnes.
#
# Les numéros sont une VALEUR PAR DÉFAUT pour le marteleur, pas une
# prescription : ils décrivent les arbres que l'IFN a mesurés.

library(data.table)
devtools::load_all(quiet = TRUE)

src_dir <- Sys.getenv("NEMETON_IFN_SRC", unset = "data-raw/ifn")

# --- 0. Coefficients EMERGE (part de houppier) ---------------------------
# gftools::ListTarEmerge (version « mai2 », projet ANR EMERGE ; gftools,
# Pascal Obstétar, GPL-3), lu depuis le .rda : gftools n'est pas publié.
# Mêmes équations que Marculus (Cubage.kt) : tige et houppier bois fort,
# découpe 7 cm, hdec = 0,8 · htot.
gft_dir <- Sys.getenv("NEMETON_GFTOOLS_DIR", unset = "/media/pascal/data2/digital_ocean/gftools")
e <- new.env()
load(file.path(gft_dir, "data", "ListTarEmerge.rda"), envir = e)
em <- as.data.table(e$ListTarEmerge)[!is.na(espar) & !is.na(Vtot_a)]
em <- unique(em[, .(espar, nom_lat, a = Vtot_a, b = Vtot_b_hdn, c = Vtot_c_hsurd,
                    d = Vtige_d, e = Vtige_e_logis, f = Vtige_f_hdn, g = Vtige_g_invc130,
                    alpha = Vhoup_Alpha, beta = Vhoup_B)])
em <- em[!duplicated(espar)]
setorder(em, espar)
fwrite(em, "inst/extdata/emerge_coefficients.csv", sep = ";", na = "", bom = FALSE)
message("emerge_coefficients.csv : ", nrow(em), " espar")
n_campagnes <- as.integer(Sys.getenv("NEMETON_TARIF_CAMPAGNES", unset = "15"))

# --- 1. Arbres IFN cubés, SER de leur placette ---------------------------
dat <- ifn_charger(c("ARBRE", "PLACETTE"), dest_dir = src_dir)
pl <- as.data.table(dat$PLACETTE)[, .(CAMPAGNE, IDP, SER, GRECO)]
ar <- as.data.table(dat$ARBRE)[, .(CAMPAGNE, IDP, A, ESPAR, VEGET, C13, V, HTOT)]
rm(dat)
derniere <- max(as.integer(ar$CAMPAGNE))
premiere <- derniere - n_campagnes + 1L
millesime <- paste0(premiere, "-", derniere)
message("Fenetre de campagnes : ", millesime)
ar <- ar[as.integer(CAMPAGNE) >= premiere]
# La SER est portée par la placette ; une placette revisitée garde sa SER.
pl <- unique(pl[!is.na(SER) & nzchar(SER) & SER != "-1", .(IDP, SER, GRECO)], by = "IDP")
ar <- merge(ar, pl, by = "IDP")

# --- 2. Numéros par échelon ----------------------------------------------
ser_t <- as.data.table(calculer_tarifs_schaeffer(ar, groupes = "SER"))[
  , `:=`(niveau = "SER", code = SER)]
gre_t <- as.data.table(calculer_tarifs_schaeffer(ar, groupes = "GRECO"))[
  , `:=`(niveau = "GRECO", code = GRECO)]
fr_t <- as.data.table(calculer_tarifs_schaeffer(ar))[, `:=`(niveau = "FRANCE", code = "FR")]
tab <- rbindlist(list(ser_t, gre_t, fr_t), fill = TRUE)

# Libellé : référentiel nemeton (codes à deux chiffres déjà complétés ; le
# référentiel espar-cdref13 brut écrit 9 pour 09 et ferait disparaître le hêtre).
corr <- as.data.table(ifn_espar_correspondance())
depad <- function(v) sub("^0([0-9])$", "\\1", v)
tab[, essence_libelle := corr$lib_espar[match(depad(espar), depad(corr$espar))]]
manquants <- unique(tab[is.na(essence_libelle), espar])
if (length(manquants)) message("Essences sans libelle : ", paste(manquants, collapse = ", "))
tab[, millesime := millesime]
tab[, niveau := factor(niveau, c("SER", "GRECO", "FRANCE"))]
setorder(tab, niveau, code, espar, type)
tab[, niveau := as.character(niveau)]
tab <- tab[, .(niveau, code, espar, essence_libelle, type, numero, n_arbres, cv, millesime,
                part_houppier)]
message(nrow(tab), " lignes de tarifs, ", uniqueN(tab[niveau == "SER", code]), " SER, ",
        sum(fr_t$n_arbres[fr_t$type == "SCHR"]), " arbres retenus (France)")

ecrire <- function(x, fichier) {
  fwrite(x, file.path("inst/extdata", fichier), sep = ";", na = "", bom = FALSE,
         quote = "auto", encoding = "UTF-8")
  message(fichier, " : ", round(file.size(file.path("inst/extdata", fichier)) / 1e6, 2), " Mo")
}
ecrire(tab, "ifn_tarif_schaeffer_ser.csv")

# --- 3. SER --------------------------------------------------------------
ser_cache <- path.expand("~/.cache/nemeton/ser/ser_l93.json")
ser <- if (file.exists(ser_cache)) {
  sf::st_read(ser_cache, quiet = TRUE)
} else {
  nemeton:::.ser_wfs_read(c(-400000, 6000000, 1300000, 7200000), timeout = 600L)
}
ser <- ser[ser$codeser != "-1", ]
ser <- sf::st_make_valid(sf::st_transform(ser, 2154))
ser_tab <- unique(as.data.table(sf::st_drop_geometry(ser))[, .(code = codeser, nom = NomSER)])
ser_tab <- ser_tab[!duplicated(code)][, greco := substr(code, 1L, 1L)]
setorder(ser_tab, code)
ecrire(ser_tab, "ser.csv")

# --- 4. Communes × SER ---------------------------------------------------
url <- "https://etalab-datasets.geo.data.gouv.fr/contours-administratifs/2026/geojson/communes-100m.geojson.gz"
f_com <- file.path(src_dir, "communes-100m-2026.geojson.gz")
if (!file.exists(f_com)) utils::download.file(url, f_com, mode = "wb")
com <- sf::st_read(paste0("/vsigzip/", normalizePath(f_com)), quiet = TRUE)
# Reprojection PUIS make_valid (make_valid sur 4326 déplace les sommets).
com <- sf::st_make_valid(sf::st_transform(com, 2154))
com$surface <- as.numeric(sf::st_area(com))
# Une entité par SER (les grandes SER arrivent en plusieurs morceaux).
ser_u <- stats::aggregate(ser["codeser"], by = list(ser = ser$codeser), FUN = function(x) x[1])
ser_u <- sf::st_transform(ser_u[, "ser"], sf::st_crs(com))
inter <- suppressWarnings(sf::st_intersection(com[, c("code", "nom", "departement", "surface")],
                                              ser_u))
inter$a <- as.numeric(sf::st_area(inter))
cs <- as.data.table(sf::st_drop_geometry(inter))[, .(a = sum(a)), by = .(insee = code, nom, departement, ser, surface)]
cs[, part := a / surface]
# Bavures des contours simplifiés : parts < 1 % écartées, puis renormalisées.
cs <- cs[part >= 0.01]
cs[, part := round(part / sum(part), 4), by = insee]
cs[, greco := substr(ser, 1L, 1L)]
cs <- cs[, .(insee, nom, departement, ser, part, greco)]
setorder(cs, insee, -part)
message(nrow(cs), " lignes commune x SER, ", uniqueN(cs$insee), " communes")
ecrire(cs, "communes_ser.csv")
