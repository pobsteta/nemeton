# ICD : indicateur composite de decoloration (spec 071).
# Methode : note "Suivi de la decoloration anormale du feuillage, BFC", v2 du
# 29 octobre 2026, sections 3 a 8 (copie : specs/071-icd-decoloration/).
# Les valeurs ci-dessous sont celles de la note ; seuls les poids sont des
# arguments (decision de Pascal, 2026-11-26).

# Les cinq indices, dans l'ordre de la formule ICD (note, section 7).
.ICD_INDICES <- c("GRVI", "CIre", "CRSWIR", "CRre", "NDVI")

# Signe de chaque indice dans l'ICD : CRSWIR et CRre montent avec le
# deperissement, on les compte en negatif.
.ICD_SIGNES <- c(GRVI = 1, CIre = 1, CRSWIR = -1, CRre = -1, NDVI = 1)

# Plancher de l'ecart-type robuste (note, section 6).
.ICD_PLANCHERS <- c(GRVI = 0.01, CIre = 0.05, CRSWIR = 0.02, CRre = 0.01,
                    NDVI = 0.01)

# Bandes Sentinel-2 lues (cache commun) ; SCL = couche de classification.
.ICD_BANDES <- c("B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B11",
                 "B12", "SCL")

# Classes SCL masquees (note, section 4) : donnees absentes, saturees, ombres,
# nuages (moyenne/haute probabilite), cirrus, neige. Ne pas confondre avec
# .RECONFORT_SCL_MASK_CLASSES (3, 8, 9, 10, 11).
.ICD_SCL_MASQUE <- c(0L, 1L, 3L, 8L, 9L, 10L, 11L)

# Composite : avril a octobre ; scenes a moins de 70 % de nuages.
.ICD_MOIS_SAISON    <- 4:10
.ICD_NUAGES_MAX     <- 70
.ICD_ANNEE_DEBUT    <- 2017L
# Mois en cours : garde tel quel tant qu'il n'est pas termine depuis 5 jours.
.ICD_JOURS_MOIS_COURS <- 5L
# Indice "a date" : un mois en cours n'est pris que s'il est entame depuis 20 j.
.ICD_JOURS_INDICE_DATE <- 20L

# Anomalie z : au moins 4 annees de reference valides.
.ICD_MIN_REF <- 4L
.ICD_MAD_ECHELLE <- 1.4826

# Alertes (note, section 8).
.ICD_SEUIL_SURVEILLANCE <- -1.5
.ICD_SEUIL_ALERTE       <- -2
.ICD_SEUIL_FORTE        <- -3
.ICD_PERSISTANCE        <- 2L

# Essences : cle NMT, code TFV BD Foret V2 (peuplements purs), mois suivis.
.ICD_ESSENCES <- c("chene", "hetre", "sapin_epicea", "douglas")
.ICD_TFV <- c(chene = "FF1G01-01", hetre = "FF1-09-09",
              sapin_epicea = "FF2G61-61", douglas = "FF2-64-64")
.ICD_MOIS <- list(chene = 6:8, hetre = 7:8, sapin_epicea = 6:10,
                  douglas = 4:9)
.ICD_RESINEUX <- c("sapin_epicea", "douglas")

# Libelles des classes et niveaux (note, section 8).
.ICD_CLASSES <- c("normal", "surveillance", "alerte")
.ICD_NIVEAUX <- c("normal", "surveillance", "alerte", "alerte_forte",
                  "alerte_repetee")

.ICD_ALERT_TYPE <- "icd_decoloration"
