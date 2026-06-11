# ============================================================
# build_reconfort_validity_zones.R
# ------------------------------------------------------------
# Generates inst/extdata/reconfort_validity_zones.geojson — the
# six French departments of the Centre-Val de Loire region where
# the RECONFORT oak-dieback model is calibrated (Mouret et al.
# 2023, doi:10.1109/JSTARS.2023.3332420; SYCOMORE programme,
# Région Centre-Val de Loire) :
#   18 (Cher), 28 (Eure-et-Loir), 36 (Indre), 37 (Indre-et-Loire),
#   41 (Loir-et-Cher), 45 (Loiret).
#
# Used by `R/reconfort_validity.R::check_reconfort_validity()` (G3,
# spec 021) to flag projects whose AOI lies outside the calibrated
# geographic extent. NB: unlike FORDEAD, RECONFORT imposes no hard
# geographic lock — the banner WARNS, it does not block (the upstream
# example itself runs outside CVL). This layer only powers the
# advisory check.
#
# Source : per-department GeoJSON files from
# https://github.com/gregoiredavid/france-geojson (snapshot of
# IGN ADMIN-EXPRESS, Etalab 2.0 — French free-reuse licence).
# Same static mirror as build_fordead_validity_zones.R, because the
# live geo.api.gouv.fr `format=geojson&geometry=contour` endpoint was
# decommissioned in 2025 and now returns attributes only.
#
# Output schema (one feature per department) :
#   code_dept   chr  INSEE code (2 chars)
#   nom_dept    chr  Department name
#   source      chr  Provenance string
#   reference   chr  Calibration reference (RECONFORT / Mouret 2023)
#
# CRS: EPSG:4326 (web compatibility — used downstream for fast
# st_intersection with project AOIs reprojected on the fly).
# Geometries are simplified with a 100 m tolerance (in Lambert-93
# metric space) — well below the 50% intersection threshold used by
# the validity check.
#
# Run :
#   Rscript data-raw/build_reconfort_validity_zones.R
# Requires : sf, jsonlite. No authentication needed.
# ============================================================

stopifnot(
  requireNamespace("sf", quietly = TRUE),
  requireNamespace("jsonlite", quietly = TRUE)
)

DEPARTMENTS <- list(
  list(code = "18", slug = "18-cher",            nom = "Cher"),
  list(code = "28", slug = "28-eure-et-loir",    nom = "Eure-et-Loir"),
  list(code = "36", slug = "36-indre",           nom = "Indre"),
  list(code = "37", slug = "37-indre-et-loire",  nom = "Indre-et-Loire"),
  list(code = "41", slug = "41-loir-et-cher",    nom = "Loir-et-Cher"),
  list(code = "45", slug = "45-loiret",          nom = "Loiret")
)
URL_TPL <- paste0(
  "https://raw.githubusercontent.com/gregoiredavid/",
  "france-geojson/master/departements/%s/departement-%s.geojson"
)
OUT_PATH    <- file.path("inst", "extdata", "reconfort_validity_zones.geojson")
SIMPLIFY_M  <- 100  # tolerance in metres (Lambert-93)
SOURCE      <- "gregoiredavid/france-geojson (IGN ADMIN-EXPRESS, Etalab 2.0)"
REFERENCE   <- "Mouret et al. 2023 (RECONFORT, Region Centre-Val de Loire)"

fetch_one <- function(d) {
  url <- sprintf(URL_TPL, d$slug, d$slug)
  message(sprintf("[reconfort-validity] fetching %s ...", url))
  feature <- sf::st_read(url, quiet = TRUE)
  feature$code_dept <- d$code
  feature$nom_dept  <- d$nom
  feature[, c("code_dept", "nom_dept", attr(feature, "sf_column"))]
}

parts <- lapply(DEPARTMENTS, fetch_one)
zones <- do.call(rbind, parts)
sf::st_crs(zones) <- 4326

# Densify-then-simplify in metric CRS (Lambert-93, EPSG:2154)
# so the tolerance is in metres.
zones_m <- sf::st_transform(zones, 2154)
zones_m <- sf::st_simplify(zones_m,
                           dTolerance       = SIMPLIFY_M,
                           preserveTopology = TRUE)
zones <- sf::st_transform(zones_m, 4326)

zones$source    <- SOURCE
zones$reference <- REFERENCE

zones <- zones[, c("code_dept", "nom_dept", "source",
                   "reference", attr(zones, "sf_column"))]

dir.create(dirname(OUT_PATH), recursive = TRUE, showWarnings = FALSE)
if (file.exists(OUT_PATH)) file.remove(OUT_PATH)
sf::st_write(zones, OUT_PATH, driver = "GeoJSON",
             delete_dsn = TRUE, quiet = TRUE)

size_kb <- round(file.info(OUT_PATH)$size / 1024, 1)
total_km2 <- as.numeric(sum(sf::st_area(zones_m))) / 1e6

message(sprintf(
  "[reconfort-validity] wrote %s (%d features, %.1f km^2, %s ko)",
  OUT_PATH, nrow(zones), total_km2, size_kb
))
