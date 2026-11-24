#!/usr/bin/env Rscript
# Étude FAST contre décoloration — point d'entrée unique (mission 045).
#
#   Rscript data-raw/etude_fast_decoloration/etude.R <dossier_sortie> [--zone=Z01_...]
#
# <dossier_sortie> : HORS du dépôt. Cache par zone et par étape (<zone>/<etape>.rds) :
# relancer la commande reprend là où elle s'est arrêtée. Zones : zones.csv (14 lignes,
# tirées par choisir_zones.R). Variable : DECOLORATION_DIR (défaut ~/dev/rapport_decoloration_bfc).
# FAST tourne sur une base SQLite LOCALE <sortie>/etude.sqlite ; NEMETON_DB_URL (base de
# production) est effacée de l'environnement dès le démarrage, jamais lue.
# Étapes : verite -> decoloration -> volume -> fast -> mesures ; tables + rapport.md à la fin.

Sys.unsetenv("NEMETON_DB_URL")   # garde-fou : jamais la base de production
suppressPackageStartupMessages({ library(terra); library(sf) })
args <- commandArgs(trailingOnly = TRUE)
rep_script <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]), mustWork = FALSE))
source(file.path(rep_script, "fonctions.R")); source(file.path(rep_script, "fonctions_comparaison.R"))

dossier <- args[!grepl("^--", args)][1]
if (is.na(dossier)) stop("usage : etude.R <dossier_sortie> [--zone=Z]")
dir.create(dossier, recursive = TRUE, showWarnings = FALSE); dossier <- normalizePath(dossier)
une_zone <- sub("^--zone=", "", grep("^--zone=", args, value = TRUE))
DEC <- Sys.getenv("DECOLORATION_DIR", path.expand("~/dev/rapport_decoloration_bfc"))
ANNEES_TEST <- 2021:2023            # 2021 et 2022 complètes à 24 mois ; 2023 censurée
ANNEES_FAST_SEUL <- 2018:2020       # à part, sans comparaison
ANNEES <- c(ANNEES_FAST_SEUL, ANNEES_TEST)
TAILLE <- 3000
ESS_ID <- c(chene = 1L, hetre = 2L, sapin_epicea = 3L, douglas = 4L)
zones <- utils::read.csv(file.path(rep_script, "zones.csv"))
if (length(une_zone)) zones <- zones[zones$zone %in% une_zone, ]
msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), sprintf(...), "\n", file = stderr())
etendue <- function(z, marge = 0) ext(z$xmin - marge, z$xmin + TAILLE + marge, z$ymin - marge, z$ymin + TAILLE + marge)
grille20 <- function(z) rast(etendue(z), resolution = 20, crs = "EPSG:2154")

# ---- verite : coupe SUFOSAT 20 m sur la grille de la décoloration + masque forestier
etape_verite <- function(z) {
  g20 <- grille20(z)
  g10 <- rast(etendue(z), resolution = 10, crs = "EPSG:2154")          # alignée sur g20
  t10 <- resample(crop(rast(file.path(DEC, "donnees/sufosat_tcoupe_p90_r27.tif")), etendue(z, 40)), g10, method = "near")
  m <- matrix(values(t10, mat = FALSE), nrow(t10), ncol(t10), byrow = TRUE)
  sous <- sapply(list(c(0, 0), c(0, 1), c(1, 0), c(1, 1)), function(o)
    as.vector(t(m[seq(1 + o[1], nrow(m), 2), seq(1 + o[2], ncol(m), 2)])))
  r <- g20; values(r) <- coupe_20m(sous)
  zf <- st_as_sfc(st_bbox(c(xmin = z$xmin, ymin = z$ymin, xmax = z$xmin + TAILLE, ymax = z$ymin + TAILLE), crs = st_crs(2154)))
  bf <- suppressWarnings(st_read(file.path(DEC, "donnees/ign_bdforet_v2_r27.gpkg"), quiet = TRUE, wkt_filter = st_as_text(zf)))
  bf <- st_make_valid(st_transform(bf, 2154))
  if (z$groupe == "melange") {      # forêt publique hors 4 essences
    pb <- suppressWarnings(st_read(file.path(DEC, "donnees/ign_forets_publiques_r27.gpkg"), quiet = TRUE, wkt_filter = st_as_text(zf)))
    pb <- st_make_valid(st_transform(pb, 2154))
    f <- st_difference(st_union(st_geometry(pb)), if (nrow(bf)) st_union(st_geometry(bf)) else st_sfc(st_polygon(), crs = 2154))
  } else f <- st_union(st_geometry(bf[bf$ess_id == ESS_ID[[z$groupe]], ]))
  f <- st_intersection(st_make_valid(f), zf)
  f <- if (length(f) && !all(st_is_empty(f))) st_buffer(f, -10) else f     # lisière de 10 m
  foret <- if (length(f) && !all(st_is_empty(f))) rasterize(vect(f), g20, field = 1, background = 0) else g20 * 0
  list(t_coupe = wrap(r), foret = wrap(foret))
}

# ---- decoloration : classe 0/1/2 et ICD min déjà calculés (lecture seule) ; NULL si « non_applicable »
etape_decoloration <- function(z) {
  if (z$groupe == "melange") return(NULL)
  g20 <- grille20(z)
  annees <- (min(ANNEES) - 1L):max(ANNEES)
  setNames(lapply(annees, function(a) {
    f <- file.path(DEC, "sortie_decoloration/indicateurs", sprintf("alerte_%d.vrt", a))
    if (!file.exists(f)) return(NULL)
    wrap(resample(crop(rast(f), etendue(z, 40)), g20, method = "near"))
  }), annees)
}

# ---- volume : FORMS-T de l'année a-1 sur la grille 20 m (pondération)
etape_volume <- function(z) {
  g20 <- grille20(z)
  setNames(lapply(ANNEES_TEST, function(a) {
    f <- file.path(DEC, "donnees/forms_t", sprintf("WVD_%d.tif", a - 1L))
    if (!file.exists(f)) return(NULL)
    wrap(resample(crop(rast(f), etendue(z, 200)), g20, method = "average"))
  }), ANNEES_TEST)
}

# ---- fast : nemeton année par année, base SQLite locale, lecture par fenêtre
etape_fast <- function(z, con) {
  g20 <- grille20(z)
  mois <- MOIS_ICD[[z$groupe]]
  poly <- st_as_sfc(st_bbox(c(xmin = z$xmin, ymin = z$ymin, xmax = z$xmin + TAILLE, ymax = z$ymin + TAILLE), crs = st_crs(2154)))
  ex <- nemeton::find_zones_by_project(con, "etude-fast-decoloration")
  id <- ex$id[ex$name == z$zone]
  id <- if (length(id)) id[1] else nemeton::create_monitoring_zone(con, z$zone, poly, project_uuid = "etude-fast-decoloration")
  cache <- file.path(dossier, "cache_fast"); dir.create(cache, showWarnings = FALSE)
  res <- list(statut = "ok", zone_id = id)
  for (a in ANNEES) {                    # saisons de a-3 ... a : une ingestion par saison
    w <- fenetres_fast(a, mois)$saison
    nemeton::ingest_sentinel2_timeseries(con, id, start = w[["from"]], end = w[["to"]],
                                         bands = c("NDVI", "NBR"), cache_dir = cache)
  }
  lire <- function(mode, from, to) {
    r <- nemeton::read_fast_alert_raster(con, id, index = "NDVI", date_from = from, date_to = to, mode = mode,
                                         months = mois, cache_dir = cache)
    if (is.null(r)) return(NULL)
    wrap(fast_vers_20m(r, g20))          # 10 m -> grille commune 20 m (moyenne pour le score)
  }
  for (a in ANNEES) {
    w <- fenetres_fast(a, mois)
    res[[as.character(a)]] <- list(count = lire("count", w$saison[["from"]], w$saison[["to"]]),
                                   rolling = lire("rolling", w$saison[["from"]], w$saison[["to"]]),
                                   trend = if (a %in% ANNEES_TEST) lire("trend", w$trend[["from"]], w$trend[["to"]]))
  }
  res
}

# ---- mesures : une ligne par pixel et par année
etape_mesures <- function(z, V, D, VOL, F, derniere) {
  t_coupe <- values(rast(V$t_coupe), mat = FALSE); foret <- values(rast(V$foret), mat = FALSE) == 1
  val <- function(w) if (is.null(w)) NULL else values(rast(w), mat = FALSE)
  out <- lapply(ANNEES, function(a) {
    co <- cohorte_pixels(t_coupe, mois_indice(a), derniere)
    dd <- if (is.null(D[[as.character(a)]])) NULL else rast(D[[as.character(a)]])
    cl <- if (is.null(dd)) NULL else values(dd[[1]], mat = FALSE)
    icd <- if (is.null(dd)) NULL else values(dd[[2]], mat = FALSE)
    prec <- if (is.null(D[[as.character(a - 1L)]])) NULL else values(rast(D[[as.character(a - 1L)]])[[1]], mat = FALSE)
    niv <- if (is.null(cl)) rep(NA_real_, length(t_coupe)) else niveaux_decoloration(cl, icd, prec)
    fa <- F[[as.character(a)]]
    sc <- function(m) { s <- if (identical(F$statut, "ok")) val(fa[[m]]) else NULL; if (is.null(s)) rep(NA_real_, length(t_coupe)) else s }
    s_c <- sc("count"); s_r <- sc("rolling"); s_t <- sc("trend")
    vol <- val(VOL[[as.character(a)]]); if (is.null(vol)) vol <- rep(NA_real_, length(t_coupe))
    data.frame(zone = z$zone, groupe = z$groupe, annee = a, cell = seq_along(t_coupe), foret = foret,
               co, annee_coupe = ifelse(is.na(t_coupe), NA, t_coupe %/% 12),
               niv_dec = etat_pixel(niv, applicable = rep(!is.null(D), length(niv))),
               sc_dec = if (is.null(icd)) NA_real_ else -icd,
               sc_count = s_c, cl_count = classes_fast(s_c),
               sc_rolling = s_r, cl_rolling = classes_fast(s_r),
               sc_trend = s_t, cl_trend = classes_fast(s_t), vol = vol)
  })
  px <- do.call(rbind, out)
  px$comparable <- pixel_comparable(px$annee_coupe)
  px$y24 <- vrai_sous_h(px$delai, px$evenement, px$censure, HORIZON_PRINCIPAL)
  px[px$foret & px$garde, ]
}

# ---- principal
sqlite_url <- isoler_base(dossier)
con <- NULL
fast_dispo <- requireNamespace("nemeton", quietly = TRUE) && !identical(Sys.getenv("ETUDE_SANS_FAST"), "1")
if (fast_dispo) {
  con <- nemeton::db_connect(sqlite_url); on.exit(nemeton::db_disconnect(con), add = TRUE)
  nemeton::db_migrate(con)
}
DERNIERE_COUPE <- etape_cache(dossier, "_region", "derniere_coupe", function()
  as.integer(global(rast(file.path(DEC, "donnees/sufosat_tcoupe_p90_r27.tif")), "max", na.rm = TRUE)[1, 1]))

res <- list()
for (i in seq_len(nrow(zones))) {
  z <- zones[i, ]; msg("zone %s (%d/%d)", z$zone, i, nrow(zones))
  V   <- etape_cache(dossier, z$zone, "verite", function() etape_verite(z))
  D   <- etape_cache(dossier, z$zone, "decoloration", function() etape_decoloration(z))
  VOL <- etape_cache(dossier, z$zone, "volume", function() etape_volume(z))
  Fz  <- etape_cache(dossier, z$zone, "fast", function() if (fast_dispo) etape_fast(z, con) else list(statut = "non_execute"))
  res[[z$zone]] <- etape_cache(dossier, z$zone, "mesures", function() etape_mesures(z, V, D, VOL, Fz, DERNIERE_COUPE))
}
px <- do.call(rbind, res)
source(file.path(rep_script, "rapport.R"), local = TRUE)
