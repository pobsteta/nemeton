# build_ifn_tables.R — tables de référence IFN par essence x SER (spec 040)
# ==========================================================================
# Produit deux tables dans inst/extdata/ :
#   - ifn_volume_essence_ser.csv     volume SUR PIED  (m3/ha)
#   - ifn_prelevement_essence_ser.csv  PRELEVEMENT    (m3/ha/an)
#
# SOURCE ET LICENCE
# -----------------
# Données brutes de l'inventaire forestier national, téléchargées directement
# chez l'IGN : https://inventaire-forestier.ign.fr/dataIFN/
# Licence Ouverte Etalab v2.0 — réutilisation libre. Citation demandée :
#   « IGN – Inventaire forestier national français, Données brutes, Campagnes
#     annuelles 2005 et suivantes, https://inventaire-forestier.ign.fr/dataIFN/,
#     site consulté le 22/07/2026 »
#
# La MÉTHODE d'agrégation du volume sur pied suit `PPtools::CarteEssenceSer()`
# de Max Bruciamacchie (AgroParisTech Nancy), GPL-2, reprise sous GPL-3 avec son
# autorisation explicite donnée par courriel le 22 juillet 2026. La découverte
# de l'accès direct aux données brutes doit à `FrenchNFIfindeR`
# (Jérémy Borderieux, GPL-3) — dont l'URL est ici redécouverte dynamiquement,
# ce package figeant la campagne 2023.
#
# ATTENTION — deux sémantiques à ne pas confondre, cf. spec 040 §5.a-3 :
# le volume sur pied est un STOCK ; le prélèvement est ce qui A ÉTÉ récolté,
# pas une prescription sylvicole.

library(data.table)

# --- 1. Chargement via les fonctions du package -----------------------
# La capacité de téléchargement/chargement est internalisée dans nemeton
# (R/ifn_source.R) : pas de dépendance à FrenchNFIfindeR.
devtools::load_all(quiet = TRUE)

src_dir <- Sys.getenv("NEMETON_IFN_SRC", unset = "data-raw/ifn")
dat <- ifn_charger(c("ARBRE", "PLACETTE", "espar-cdref13"), dest_dir = src_dir)
millesime <- attr(dat, "millesime")
message("Campagne la plus recente : ", millesime)

pl <- as.data.table(dat$PLACETTE)[, .(CAMPAGNE, IDP, VISITE, SER)]
ar <- as.data.table(dat$ARBRE)[, .(CAMPAGNE, IDP, A, ESPAR, VEGET, VEGET5, V, W)]
codes_ess <- as.data.table(dat[["espar-cdref13"]])
rm(dat)

ar[, `:=`(V = as.numeric(V), W = as.numeric(W))]
pl <- pl[!is.na(SER) & SER != ""]
# Le GRECO est la premiere lettre du code SER (A11, B10, C20...), verifie.
pl[, GRECO := substr(SER, 1L, 1L)]

# --- 2. Fabrique d'agrégat commune -----------------------------------
# `n_plac_maille` : TOUTES les placettes de la maille (y compris celles ou
# l'essence est absente) -> denominateur honnete.
# vol_ha_present : moyenne sur les seules placettes de presence (figure de
#   peuplement, comparable a un P1 d'UGF).
# vol_ha_maille  : contribution de l'essence a la maille (figure de ressource).
agreger <- function(par_placette, placettes, diviseur = 1, noms = c("vol_ha_present", "vol_ha_maille")) {
  n_ser <- placettes[, .(n_plac_maille = uniqueN(IDP)), by = .(cle = SER)][, niveau := "ser"]
  n_gre <- placettes[, .(n_plac_maille = uniqueN(IDP)), by = .(cle = GRECO)][, niveau := "greco"]
  n_nat <- data.table(cle = "FR", n_plac_maille = uniqueN(placettes$IDP), niveau = "national")
  n_all <- rbindlist(list(n_ser, n_gre, n_nat))

  d <- merge(par_placette, unique(placettes[, .(IDP, SER, GRECO)]), by = "IDP")
  long <- rbindlist(list(
    d[, .(niveau = "ser",      cle = SER,   ESPAR, val)],
    d[, .(niveau = "greco",    cle = GRECO, ESPAR, val)],
    d[, .(niveau = "national", cle = "FR",  ESPAR, val)]
  ))
  out <- long[, .(n_plac_presence = .N, somme = sum(val)), by = .(niveau, cle, ESPAR)]
  out <- merge(out, n_all, by = c("niveau", "cle"))
  out[, (noms[1]) := somme / n_plac_presence / diviseur]
  out[, (noms[2]) := somme / n_plac_maille   / diviseur]
  out[, taux_presence := n_plac_presence / n_plac_maille]
  out[, `:=`(ser   = fifelse(niveau == "ser",   cle, NA_character_),
             greco = fifelse(niveau == "greco", cle, NA_character_))]
  out[, c("cle", "somme") := NULL]
  setnames(out, "ESPAR", "espar")
  out[]
}

ecrire <- function(tbl, fichier, source_txt) {
  # Cle a normaliser : le referentiel espar-cdref13 ecrit les codes numeriques
  # SANS zero non significatif (9, 2, 3) la ou ARBRE.csv les ecrit sur deux
  # caracteres (09, 02, 03) -> sinon hetre et chenes perdent leur libelle.
  # Les codes alphanumeriques (29MI, 21C, 21M) sont laisses intacts.
  norm_espar <- function(x) {
    ifelse(grepl("^[0-9]+$", x), as.character(as.integer(x)), x)
  }
  lib <- unique(codes_ess[, .(cle_ess = norm_espar(get(names(codes_ess)[1])),
                              libelle_essence = get(names(codes_ess)[2]))])
  lib <- lib[!is.na(cle_ess) & !duplicated(cle_ess)]
  tbl[, cle_ess := norm_espar(espar)]
  tbl <- merge(tbl, lib, by = "cle_ess", all.x = TRUE)
  tbl[, cle_ess := NULL]
  num <- setdiff(names(tbl)[vapply(tbl, is.numeric, logical(1))],
                 c("n_plac_presence", "n_plac_maille"))
  tbl[, (num) := lapply(.SD, round, 4), .SDcols = num]
  tbl[, `:=`(millesime = millesime, source = source_txt)]
  setcolorder(tbl, c("niveau", "ser", "greco", "espar"))
  setorder(tbl, niveau, ser, greco, espar, na.last = TRUE)
  fwrite(tbl, file.path("inst/extdata", fichier), na = "")
  message(nrow(tbl), " lignes -> inst/extdata/", fichier)
}

# --- 3. Volume sur pied (1re visite, arbres vivants) -----------------
pl1 <- pl[VISITE == "1"]
v1  <- merge(ar[VEGET == "0" & !is.na(V) & !is.na(W) & ESPAR != ""],
             pl1[, .(CAMPAGNE, IDP)], by = c("CAMPAGNE", "IDP"))
vol_plac <- v1[, .(val = sum(V * W)), by = .(IDP, ESPAR)]
ecrire(agreger(vol_plac, pl1),
       "ifn_volume_essence_ser.csv",
       paste0("IGN IFN donnees brutes ", millesime,
              ", Licence Ouverte Etalab v2.0 ; methode PPtools::CarteEssenceSer"))

# --- 4. Prélèvement (revisite, VEGET5 == "6") ------------------------
# PIÈGE VÉRIFIÉ SUR LA DONNÉE : la ligne de revisite ne porte QUE le sort de
# l'arbre. Sur les 69 785 lignes VEGET5 == "6" de l'export 2005-2024, `V` et
# `ESPAR` sont vides à 100 % (seul `W` est parfois là). Mesure et essence
# vivent sur la ligne de PREMIÈRE VISITE du même arbre, clé (IDP, A) — d'où
# la jointure ci-dessous. Agréger directement sur les lignes de revisite
# donne une table vide (constaté), ou pire, un volume faux.
#
# VEGET5 = 6 « arbre coupé VIDANGÉ » : le bois sort de la forêt, donc charge
# le réseau de desserte. Le code 7 (« coupé non vidangé ») reste sur place et
# est volontairement EXCLU — c'est la distinction qui compte ici.
#
# Le volume récolté est approché par le volume de l'arbre au PREMIER passage :
# il a crû un peu avant d'être coupé. Approximation assumée (spec 040 §5.c).
coupes <- ar[VEGET5 == "6", .(IDP, A)]
mesures <- ar[VEGET == "0" & !is.na(V) & !is.na(W) & ESPAR != "",
              .(IDP, A, ESPAR, V, W)]
c2 <- merge(coupes, mesures, by = c("IDP", "A"))
message(nrow(coupes), " arbres coupes, dont ", nrow(c2),
        " avec une mesure de 1re visite (", round(100 * nrow(c2) / nrow(coupes)),
        " %)")

# Placettes revisitees : le denominateur du taux.
pl2 <- unique(pl[VISITE == "2", .(IDP, SER, GRECO)])
prelev_plac <- c2[IDP %in% pl2$IDP, .(val = sum(V * W)), by = .(IDP, ESPAR)]

# Diviseur 5 : l'intervalle entre les deux visites -> m3/ha/an.
ecrire(agreger(prelev_plac, pl2, diviseur = 5,
               noms = c("prelev_ha_an_present", "prelev_ha_an_maille")),
       "ifn_prelevement_essence_ser.csv",
       paste0("IGN IFN donnees brutes ", millesime,
              ", Licence Ouverte Etalab v2.0 ; VEGET5==6 (coupe vidange) / 5 ans"))

# --- 5. Correspondance des codes essence (spec 040, D9) --------------
# Trois nomenclatures coexistent dans le projet, sans clé commune directe :
#   espar IFN        "09"              (ARBRE.csv, tables de reference IFN)
#   code P1          "FASY"            (ifn_volume_equations.csv, 24 essences)
#   code tolerances  "fagus_sylvatica" (european_species_tolerances.csv, 194)
# Le PIVOT est le nom latin (`lib_cdref` du referentiel IGN). La table de
# correspondance est construite par ce pivot, et non par des heuristiques sur
# les libelles francais.
message("Correspondance des codes essence...")

corr <- unique(data.table(
  espar       = codes_ess[[1]],
  lib_espar   = codes_ess[[2]],
  espece_sci  = codes_ess[[4]]
))
corr <- corr[!is.na(espar) & espar != ""]

# ZEROS NON SIGNIFICATIFS — deuxieme occurrence du meme piege. Le referentiel
# espar-cdref13 ecrit les codes numeriques sur un caractere ("9", "2", "3")
# alors que ARBRE.csv — donc les tables ifn_*_essence_ser — les ecrit sur deux
# ("09", "02", "03"). Sans cette normalisation, resoudre_espar() renvoie "9",
# qui n'apparie AUCUNE ligne des tables de reference : un pont qui ne relie
# rien, et en silence. On aligne sur la convention ARBRE.csv.
corr[, espar := fifelse(grepl("^[0-9]$", espar), paste0("0", espar), espar)]

# Normalisation du latin : minuscules, espaces/traits d'union unifies. Les
# hybrides ("x") et sous-especes restent tels quels, la comparaison se fait
# sur la chaine normalisee des deux cotes.
norm_sci <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- gsub("[[:space:]]+", " ", x)
  gsub("-", " ", x)
}
corr[, cle_sci := norm_sci(espece_sci)]

# Le referentiel IGN descend souvent au rang infraspecifique ("Picea abies
# subsp. abies", "Quercus robur var. robur"), la ou nos tables portent le
# binome nu ("Picea abies"). On apparie donc AUSSI sur l'AUTONYME : la
# sous-espece/variete nominale, dont l'epithete infraspecifique repete
# l'epithete specifique — taxonomiquement equivalente a l'espece.
# Quand il n'existe pas d'autonyme (Pinus nigra n'a que des varietes
# calabrica/corsicana/salzmannii), on laisse NA plutot que d'en choisir une
# arbitrairement.
autonyme <- function(x) {
  m <- regmatches(x, regexec(
    "^([a-z]+) ([a-z]+) (subsp\\.|var\\.) ([a-z]+)$", x))
  vapply(m, function(g) {
    if (length(g) == 5L && identical(g[3], g[5])) paste(g[2], g[3]) else NA_character_
  }, character(1))
}
corr[, cle_auto := autonyme(cle_sci)]

eq <- as.data.table(utils::read.csv("inst/extdata/ifn_volume_equations.csv",
                                    stringsAsFactors = FALSE))
eq <- unique(eq[, .(code_p1 = species_code, cle_sci = norm_sci(species_name))])
eq <- eq[!duplicated(cle_sci)]

tol <- as.data.table(utils::read.csv("inst/extdata/european_species_tolerances.csv",
                                     encoding = "UTF-8", stringsAsFactors = FALSE))
tol <- unique(tol[, .(code_tolerances = code, cle_sci = norm_sci(species_sci))])
tol <- tol[!duplicated(cle_sci)]

joindre <- function(base, ref, col) {
  out <- merge(base, ref, by = "cle_sci", all.x = TRUE)
  # Second passage sur l'autonyme pour ce qui n'a pas apparie au binome nu.
  reste <- is.na(out[[col]]) & !is.na(out$cle_auto)
  if (any(reste)) {
    idx <- match(out$cle_auto[reste], ref$cle_sci)
    out[[col]][reste] <- ref[[col]][idx]
  }
  out
}
corr <- joindre(corr, eq,  "code_p1")
corr <- joindre(corr, tol, "code_tolerances")
corr[, c("cle_sci", "cle_auto") := NULL]
setcolorder(corr, c("espar", "lib_espar", "espece_sci", "code_p1",
                    "code_tolerances"))
setorder(corr, espar)
corr[, `:=`(millesime = millesime,
            source = "IGN espar-cdref13 (Etalab v2.0), pivot nom latin")]
fwrite(corr, "inst/extdata/ifn_espar_correspondance.csv", na = "")
message(nrow(corr), " correspondances -> inst/extdata/ifn_espar_correspondance.csv",
        " | code_p1 resolu : ", sum(!is.na(corr$code_p1)),
        " | code_tolerances resolu : ", sum(!is.na(corr$code_tolerances)))
