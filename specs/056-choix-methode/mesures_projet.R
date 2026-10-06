# Spec 056 — mesures des cinq choix de méthode laissés ouverts par l'audit 1.0.
#
# Mesure, pour UN projet en cache, les grandeurs brutes et les variantes de
# score utiles aux cinq décisions (R2/R3, W3/F2, N1, P3, indice de station).
# Ne modifie rien dans le paquet ni dans le dossier du projet : tout cache
# (TWI, vent NASA POWER) est redirigé vers un répertoire temporaire, où les
# caches du projet sont COPIÉS (jamais liés) pour éviter un recalcul.
#
# Usage (depuis la racine du dépôt) :
#   Rscript specs/056-choix-methode/mesures_projet.R <dossier_projet> <out_dir>
# Produit <out_dir>/<id_projet>.rds. L'agrégation est dans agrege.R.
#
# Garde-fou mémoire : MNT LiDAR 0,5 m ramené à 2 m (résolution de travail du
# paquet, .dem_working_res) avant tout dérivé de terrain.

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(sf)
  library(terra)
})
options(nemeton.topo_target_res = 2)
terra::terraOptions(memfrac = 0.4, progress = 0)

args <- commandArgs(trailingOnly = TRUE)
proj_dir <- normalizePath(args[1])
out_dir  <- args[2]
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

meta  <- jsonlite::fromJSON(file.path(proj_dir, "metadata.json"))
lyr   <- file.path(proj_dir, "cache", "layers")
tmpc  <- file.path(tempdir(), "cache056")
dir.create(tmpc, showWarnings = FALSE)
# Copie (lecture seule du projet) des caches réutilisables.
for (f in c(Sys.glob(file.path(lyr, "twi_*.tif")),
            Sys.glob(file.path(lyr, "nasapower*.rds")))) {
  file.copy(f, tmpc, overwrite = TRUE)
}

res <- list(id = basename(proj_dir), name = meta$name)
cli::cli_h1("{res$name} ({res$id})")

# ---- Unités : UGF = ténements dissous par ug_id, en Lambert-93 -------------
ten <- st_read(file.path(proj_dir, "data", "tenements.gpkg"), quiet = TRUE)
ten <- st_make_valid(st_transform(ten, 2154))
units <- do.call(rbind, lapply(split(ten, ten$ug_id), function(g) {
  st_sf(ug_id = g$ug_id[1], geometry = st_union(st_geometry(g)))
}))
units$surface_ha <- as.numeric(st_area(units)) / 1e4
res$units <- st_drop_geometry(units)

# ---- 1-2. Terrain : TRI, TWI, R2, R3, W3, F2 --------------------------------
lidar_path <- file.path(lyr, "lidar_mnt_mosaic.tif")
dem_src <- if (file.exists(lidar_path)) "lidar_mnt_2m" else "dem_ign_lonlat"
dem_raw <- .normalize_crs(rast(if (file.exists(lidar_path)) lidar_path else file.path(lyr, "dem.tif")))
if (is.na(crs(dem_raw, describe = TRUE)$code) && is.lonlat(dem_raw)) crs(dem_raw) <- "EPSG:4326"
dem <- .dem_working_res(dem_raw, target_res = 2, context = "056")
res$dem_src <- dem_src
res$dem_res <- res(dem)[1]

# Résolution métrique du pixel (m), pour TRI/res
res_m <- if (is.lonlat(dem)) {
  ctr <- st_coordinates(st_transform(st_centroid(st_union(units)), 4326))
  res(dem)[1] * 111320 * cos(ctr[2] * pi / 180)
} else res(dem)[1]
res$res_m <- res_m

terrain_block <- function(dem, label) {
  aspect <- terrain(dem, v = "aspect", unit = "degrees")
  pente  <- terrain(dem, v = "slope",  unit = "degrees")
  tri    <- terrain(dem, v = "TRI")
  twi    <- get_or_compute_twi(dem, cache_dir = tmpc, twi_target_res = 2)
  if (!compareGeom(twi, aspect, stopOnError = FALSE)) twi <- resample(twi, aspect, method = "bilinear")
  list(label = label, aspect = aspect, pente = pente, tri = tri, twi = twi,
       res_m = if (is.lonlat(dem)) res_m else res(dem)[1])
}

tb <- terrain_block(dem, dem_src)

# Pixels dans les UGF (distributions), dans le CRS du raster
pix_in <- function(r) {
  u_v <- vect(st_transform(units, crs(r)))
  m <- mask(crop(r, u_v), u_v)
  v <- values(m, mat = FALSE)
  v[is.finite(v)]
}

wind_dir <- tryCatch(get_nasapower_wind(units, default_dir = 270, cache_dir = tmpc),
                     error = function(e) 270)
res$wind_dir <- wind_dir

ext_mean <- function(r) safe_extract(r, as_pure_sf(units), fun = "mean", progress = FALSE)

terrain_measures <- function(tb) {
  tri_pix <- pix_in(tb$tri); twi_pix <- pix_in(tb$twi)
  tri_max <- global(tb$tri, "max", na.rm = TRUE)$max
  twi_max <- global(tb$twi, "max", na.rm = TRUE)$max
  # Max sur l'emprise restreinte aux UGF + 250 m : même terrain, autre emprise.
  bb <- vect(st_buffer(st_as_sfc(st_bbox(st_transform(units, crs(tb$tri)))), 250))
  tri_max_loc <- global(crop(tb$tri, bb), "max", na.rm = TRUE)$max
  twi_max_loc <- global(crop(tb$twi, bb), "max", na.rm = TRUE)$max

  diff_angle <- abs(tb$aspect - wind_dir)
  diff_angle <- app(sds(diff_angle, 360 - diff_angle), fun = "min")
  expo <- 1 - diff_angle / 180
  pente_n <- clamp(tb$pente / 45, 0, 1)
  aspect_risk <- app(tb$aspect, function(a) (1 + cos((a - 180) * pi / 180)) / 2)
  pente_risk  <- clamp(tb$pente / 30, 0, 1)

  per_unit <- data.frame(
    ug_id    = units$ug_id,
    tri_mean = ext_mean(tb$tri),
    twi_mean = ext_mean(tb$twi),
    expo_s   = ext_mean(expo * pente_n),   # partie de R2 hors TRI
    expo     = ext_mean(expo),
    topo_rest = ext_mean(0.4 * aspect_risk + 0.3 * pente_risk) # partie de R3 hors TWI
  )
  # Fractions de pixels saturés dans les UGF (W3 [2,5;4,5], F2 [2,5;10])
  sat <- function(lo, hi) c(bas = mean(twi_pix <= lo), haut = mean(twi_pix >= hi))
  # Moyennes par unité des termes normalisés (linéaires dans les bornes =>
  # on stocke TRI et TWI bruts, la normalisation se fait à l'agrégation, sauf
  # pour la composante R2 qui multiplie expo par TRI pixel à pixel)
  per_unit$expo_tri <- ext_mean(expo * tb$tri)       # E[expo * TRI]
  per_unit$tri_over_res <- per_unit$tri_mean / tb$res_m

  # Échantillon de pixels par UGF (pondéré par la fraction couverte) : permet
  # de recalculer EXACTEMENT, à l'agrégation, R2/R3/W3/F2 pour n'importe quelles
  # bornes (le clamp est non linéaire, une moyenne par UGF ne suffit pas).
  stk <- c(expo, pente_n, tb$tri, tb$twi, aspect_risk, pente_risk)
  names(stk) <- c("expo", "pente_n", "tri", "twi", "aspect_risk", "pente_risk")
  px <- safe_extract(stk, as_pure_sf(units), progress = FALSE)
  pixels <- do.call(rbind, lapply(seq_along(px), function(i) {
    d <- px[[i]]
    d <- d[stats::complete.cases(d), , drop = FALSE]
    if (!nrow(d)) return(NULL)
    if (nrow(d) > 20000) {
      d <- d[sample.int(nrow(d), 20000, prob = d$coverage_fraction), ]
      d$w <- 1                      # déjà pondéré par le tirage
    } else {
      d$w <- d$coverage_fraction    # moyenne pondérée comme exact_extract
    }
    d$coverage_fraction <- NULL
    d$ug_id <- units$ug_id[i]
    d
  }))
  list(
    per_unit = per_unit,
    pixels = pixels,
    tri_q = quantile(tri_pix, c(.05, .5, .95, .99)),
    twi_q = quantile(twi_pix, c(.05, .5, .95, .99)),
    tri_max = tri_max, twi_max = twi_max,
    tri_max_loc = tri_max_loc, twi_max_loc = twi_max_loc,
    tri_pix_sample = sample(tri_pix, min(2e5, length(tri_pix))),
    twi_pix_sample = sample(twi_pix, min(2e5, length(twi_pix))),
    sat_w3 = sat(2.5, 4.5), sat_f2 = sat(2.5, 10),
    res_m = tb$res_m
  )
}
set.seed(56)
res$terrain <- terrain_measures(tb)
res$terrain$label <- dem_src

# Même terrain, MNT IGN 25 m reprojeté en Lambert-93 (contrôle : TWI métrique
# sur les projets sans LiDAR, et dépendance à la résolution sur les autres).
dem_ign <- .normalize_crs(rast(file.path(lyr, "dem.tif")))
if (is.na(crs(dem_ign, describe = TRUE)$code) && is.lonlat(dem_ign)) crs(dem_ign) <- "EPSG:4326"
dem_ign_m <- project(dem_ign, "EPSG:2154", res = 25, method = "bilinear")
tb25 <- terrain_block(dem_ign_m, "dem_ign_25m_l93")
res$terrain25 <- terrain_measures(tb25)
res$terrain25$label <- "dem_ign_25m_l93"
rm(tb, tb25); gc()

# ---- 3. N1 -----------------------------------------------------------------
rd <- file.path(lyr, "roads.gpkg"); bt <- file.path(lyr, "buildings.gpkg")
roads <- if (file.exists(rd)) st_read(rd, quiet = TRUE) else NULL
blds  <- if (file.exists(bt)) st_read(bt, quiet = TRUE) else NULL
n1 <- indicateur_n1_distance(units, roads = roads, buildings = blds)
res$n1 <- data.frame(ug_id = units$ug_id, N1 = n1$N1,
                     has_roads = !is.null(roads), has_buildings = !is.null(blds))

# ---- 4-5. P2 (indice de station) et P3 -------------------------------------
mnh <- file.path(lyr, "lidar_mnh_mosaic.tif")
oc  <- file.path(lyr, "opencanopy", "chm_predicted_1_5m.tif")
chm_src <- meta$chm_source
chm_path <- if (identical(chm_src, "lidar_hd") && file.exists(mnh)) mnh else if (file.exists(oc)) oc else NA
res$chm_path <- chm_path
bdf <- file.path(lyr, "bdforet.gpkg")
if (!is.na(chm_path) && file.exists(bdf)) {
  chm <- .normalize_crs(rast(chm_path))
  if (is.na(crs(chm, describe = TRUE)$code)) crs(chm) <- "EPSG:2154"
  bd <- st_read(bdf, quiet = TRUE)
  enr <- enrich_parcels_bdforet(units, bd)
  u2 <- units; u2$species <- enr$species; u2$age <- enr$age
  h_dom <- extract_h_dom(chm, u2, percentile = 0.9)
  si <- compute_site_index(h_dom, u2$age, u2$species)

  # Position de H_dom par rapport aux courbes (à l'âge observé)
  curves <- read_site_index_curves()
  avail <- unique(curves$species)
  pos <- vapply(seq_len(nrow(u2)), function(i) {
    h <- h_dom[i]; a <- u2$age[i]; s <- u2$species[i]
    if (is.na(h) || is.na(a) || is.na(s) || h < 1.3 || a <= 0) return("non_estimable")
    k <- resolve_species_code(s, avail)
    if (is.na(k)) return("essence_inconnue")
    sub <- curves[curves$species == k, ]; sub <- sub[order(sub$age), ]
    hh <- vapply(paste0("class_", 1:5), function(cl)
      stats::approx(sub$age, sub[[cl]], xout = a, rule = 1)$y, numeric(1))
    if (anyNA(hh)) return("age_hors_table")
    if (h > hh[1]) return("au_dessus_classe1")
    if (h < hh[5]) return("sous_classe5")
    "dans_courbes"
  }, character(1))
  si_na <- ifelse(pos %in% c("au_dessus_classe1", "sous_classe5"), NA_real_, si)

  # P3 : dbh synthétique depuis le CHM, puis trois options
  p3 <- indicateur_p3_qualite_bois(u2, chm = chm)
  diam <- (p3$P3 - 0.4 * 70 - 0.2 * 85) / 0.4  # composante diamètre (défauts actifs)
  res$prod <- data.frame(ug_id = units$ug_id, species = u2$species, age = u2$age,
                         h_dom = h_dom, si = si, si_na = si_na, position = pos,
                         dbh = p3$dbh, P3 = p3$P3, diam_score = diam)
} else {
  res$prod <- NULL
  cli::cli_alert_warning("P2/P3 : CHM ou BD Forêt manquant, sauté")
}

saveRDS(res, file.path(out_dir, paste0(res$id, ".rds")))
cli::cli_alert_success("OK {res$name}")
