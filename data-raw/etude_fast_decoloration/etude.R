#!/usr/bin/env Rscript
# Étude FAST contre décoloration — point d'entrée unique (mission 045).
#
#   Rscript data-raw/etude_fast_decoloration/etude.R <dossier_sortie> [zones.csv] [--zone=Z01]
#
# <dossier_sortie> : HORS du dépôt. Cache par zone et par étape (<zone>/<etape>.rds) :
# relancer la commande reprend là où elle s'est arrêtée. zones.csv : colonnes
# zone, xmin, ymin (carré de 3 km, Lambert 93, coin sud-ouest), groupe, strate.
# Sans zones.csv : zone pilote (Z_PILOTE). Variables : DECOLORATION_DIR
# (défaut ~/dev/rapport_decoloration_bfc), NEMETON_DB_URL (étape FAST).
# Étapes : verite -> decoloration -> fast -> mesures ; rapport.md en fin de run.

suppressPackageStartupMessages({ library(terra); library(sf) })
args <- commandArgs(trailingOnly = TRUE)
rep_script <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]), mustWork = FALSE))
source(file.path(rep_script, "fonctions.R"))

dossier <- args[!grepl("^--", args)][1]
if (is.na(dossier)) stop("usage : etude.R <dossier_sortie> [zones.csv] [--zone=Z]")
dossier <- normalizePath(dossier, mustWork = FALSE); dir.create(dossier, recursive = TRUE, showWarnings = FALSE)
fz <- args[!grepl("^--", args)][2]
une_zone <- sub("^--zone=", "", grep("^--zone=", args, value = TRUE))
DEC <- Sys.getenv("DECOLORATION_DIR", path.expand("~/dev/rapport_decoloration_bfc"))
ANNEES_TEST <- c(2021L, 2022L)
ANNEES_FAST_SEUL <- 2018:2020
TAILLE <- 3000

zones <- if (!is.na(fz) && file.exists(fz)) utils::read.csv(fz) else
  data.frame(zone = "Z_PILOTE", xmin = 775000, ymin = 6571000, groupe = "pilote", strate = "pilote")
if (length(une_zone)) zones <- zones[zones$zone %in% une_zone, ]
msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), sprintf(...), "\n")

# ---- étape verite : coupe SUFOSAT 20 m + masque forestier (lisière 10 m retirée)
etape_verite <- function(z) {
  e <- ext(z$xmin, z$xmin + TAILLE, z$ymin, z$ymin + TAILLE)
  g20 <- rast(e, resolution = 20, crs = "EPSG:2154")
  t10 <- crop(rast(file.path(DEC, "donnees/sufosat_tcoupe_p90_r27.tif")), e)
  # 4 sous-pixels : décalages du bloc 2 x 2 de chaque pixel de 20 m
  v <- values(t10, mat = FALSE); nr <- nrow(t10); nc <- ncol(t10)
  m <- matrix(v, nr, nc, byrow = TRUE)
  sous <- sapply(list(c(0, 0), c(0, 1), c(1, 0), c(1, 1)), function(o)
    as.vector(t(m[seq(1 + o[1], nr, 2), seq(1 + o[2], nc, 2)])))
  tc <- coupe_20m(sous)
  r <- g20; values(r) <- tc
  zf <- st_as_sfc(st_bbox(c(xmin = z$xmin, ymin = z$ymin, xmax = z$xmin + TAILLE, ymax = z$ymin + TAILLE), crs = st_crs(2154)))
  bf <- suppressWarnings(st_read(file.path(DEC, "donnees/ign_bdforet_v2_r27.gpkg"), quiet = TRUE,
                                 wkt_filter = st_as_text(zf)))
  bf <- st_make_valid(st_union(st_intersection(st_make_valid(bf), zf)))
  bf <- if (length(bf)) st_buffer(bf, -10) else bf
  foret <- if (length(bf) && !all(st_is_empty(bf))) rasterize(vect(bf), g20, field = 1, background = 0) else g20 * 0
  list(t_coupe = wrap(r), foret = wrap(foret), derniere_coupe = DERNIERE_COUPE)
}

# ---- étape decoloration : niveaux 0-4 et ICD min déjà calculés (lecture seule)
etape_decoloration <- function(z) {
  e <- ext(z$xmin, z$xmin + TAILLE, z$ymin, z$ymin + TAILLE)
  setNames(lapply(c(ANNEES_TEST, ANNEES_FAST_SEUL), function(a) {
    f <- file.path(DEC, "sortie_decoloration/indicateurs", sprintf("alerte_%d.vrt", a))
    if (!file.exists(f)) return(NULL)
    r <- crop(rast(f), e); wrap(r)
  }), c(ANNEES_TEST, ANNEES_FAST_SEUL))
}

# ---- étape fast : nemeton année par année (base + réseau requis ; long)
etape_fast <- function(z) {
  if (!nzchar(Sys.getenv("NEMETON_DB_URL")) || !requireNamespace("nemeton", quietly = TRUE))
    return(list(statut = "non_execute", raison = "NEMETON_DB_URL ou paquet nemeton absent"))
  con <- nemeton::db_connect(); on.exit(nemeton::db_disconnect(con), add = TRUE)
  poly <- st_as_sfc(st_bbox(c(xmin = z$xmin, ymin = z$ymin, xmax = z$xmin + TAILLE, ymax = z$ymin + TAILLE), crs = st_crs(2154)))
  id <- nemeton::create_monitoring_zone(con, paste0("etude045_", z$zone), poly, project_uuid = "etude-fast-decoloration")
  res <- list(statut = "ok")
  for (a in c(ANNEES_TEST, ANNEES_FAST_SEUL)) {
    d0 <- sprintf("%d-01-01", a - 3L); d1 <- sprintf("%d-12-31", a)
    nemeton::ingest_sentinel2_timeseries(con, id, start = d0, end = d1, bands = c("NDVI", "NBR", "NDMI", "NDRE"))
    lst <- nemeton::read_fast_alert_rasters(con, id, date_from = d0, date_to = d1, months = 6:9,
                                            cache_dir = file.path(dossier, "cache_fast"))
    res[[as.character(a)]] <- lapply(lst, function(r) if (is.null(r)) NULL else wrap(r))
  }
  res
}

# ---- étape mesures : une ligne par pixel, puis tables
etape_mesures <- function(z, V, D) {
  t_coupe <- rast(V$t_coupe); foret <- rast(V$foret)
  out <- list()
  for (a in ANNEES_TEST) {
    if (is.null(D[[as.character(a)]])) next
    d <- rast(D[[as.character(a)]]); d <- resample(d, t_coupe, method = "near")
    co <- cohorte_pixels(values(t_coupe, mat = FALSE), mois_indice(a), V$derniere_coupe)
    px <- data.frame(zone = z$zone, annee = a, classe = values(d[[1]], mat = FALSE),
                     icd_min = values(d[[2]], mat = FALSE), foret = values(foret, mat = FALSE) == 1, co)
    out[[as.character(a)]] <- px[px$foret & px$garde & !is.na(px$classe), ]
  }
  do.call(rbind, out)
}

# dernière coupe connue de SUFOSAT sur TOUTE la région (censure, § 10) : jamais sur la zone
DERNIERE_COUPE <- etape_cache(dossier, "_region", "derniere_coupe", function()
  as.integer(global(rast(file.path(DEC, "donnees/sufosat_tcoupe_p90_r27.tif")), "max", na.rm = TRUE)[1, 1]))

res <- list()
for (i in seq_len(nrow(zones))) {
  z <- zones[i, ]; msg("zone %s", z$zone)
  V <- etape_cache(dossier, z$zone, "verite", function() etape_verite(z))
  D <- etape_cache(dossier, z$zone, "decoloration", function() etape_decoloration(z))
  etape_cache(dossier, z$zone, "fast", function() etape_fast(z))
  res[[z$zone]] <- etape_cache(dossier, z$zone, "mesures", function() etape_mesures(z, V, D))
}
px <- do.call(rbind, res)

# ---- tables et rapport (décoloration ; FAST s'ajoute quand l'étape fast a tourné)
tab <- do.call(rbind, lapply(split(px, list(px$annee, px$classe), drop = TRUE), function(d)
  data.frame(annee = d$annee[1], classe = d$classe[1], n_pixels = nrow(d),
             t(setNames(km_risque(d$delai, d$evenement), paste0("risque_", HORIZONS))))))
ref <- tab[tab$classe == 0, c("annee", "risque_48")]
tab$lift_48 <- tab$risque_48 / ref$risque_48[match(tab$annee, ref$annee)]
utils::write.csv(tab, file.path(dossier, "risque_par_classe.csv"), row.names = FALSE)
auc <- vapply(ANNEES_TEST, function(a) { d <- px[px$annee == a, ]
  auc_rang(-d$icd_min, d$evenement) }, numeric(1))
dur <- utils::read.csv(file.path(dossier, "durees.csv"))
writeLines(c("# Étude FAST contre décoloration — rapport généré", "",
  sprintf("Zones : %s. Graine de tirage : 45. Années de test : %s.", paste(zones$zone, collapse = ", "), paste(ANNEES_TEST, collapse = ", ")), "",
  "## Décoloration : risque de coupe rase par niveau (Kaplan-Meier, pixels)", "",
  knitr::kable(tab, format = "pipe", digits = 4), "",
  sprintf("AUC de -ICD min contre « coupé sous 48 mois » : %s.", paste(sprintf("%d : %.3f", ANNEES_TEST, auc), collapse = " ; ")), "",
  "## Durées par étape (secondes)", "", knitr::kable(dur, format = "pipe"), "",
  "## Limites de la vérité (brief § 4)", "",
  "Coupe de régénération comptée « atteint » ; dépérissement sans coupe rase invisible (hêtre, chêne, forêt privée, scolytés extraits) ;",
  "prévalence faible : on lit lift, AUC, précision à surface égale, pas le kappa."),
  file.path(dossier, "rapport.md"))
msg("rapport : %s", file.path(dossier, "rapport.md"))
