# ============================================================
# build_fordead_validity_zones.R
# ------------------------------------------------------------
# Generates inst/extdata/fordead_validity_zones.geojson — the
# five French departments where the FORDEAD calibration is
# validated by the ONF/DSF report (Bernard & Doridant, 2024) :
# 88 (Vosges), 39 (Jura), 01 (Ain), 73 (Savoie), 74 (Haute-Savoie).
#
# Used by `R/fordead_validity.R::check_fordead_validity()` (G3,
# spec 008) to flag projects whose AOI lies outside the
# calibrated geographic extent.
#
# Source : per-department GeoJSON files from
# https://github.com/gregoiredavid/france-geojson (snapshot of
# IGN ADMIN-EXPRESS, Etalab 2.0 — French free-reuse licence).
# We use this static GitHub mirror instead of geo.api.gouv.fr
# because the live `format=geojson&geometry=contour` endpoint
# was decommissioned in 2025 and now returns attributes only.
#
# Output schema (one feature per department) :
#   code_dept   chr  INSEE code (2 chars)
#   nom_dept    chr  Department name
#   source      chr  Provenance string
#   reference   chr  Validation reference (ONF/DSF report)
#
# CRS: EPSG:4326 (web compatibility — used downstream for fast
# st_intersection with project AOIs reprojected on the fly).
# Geometries are simplified with a 100 m tolerance (in
# Lambert-93 metric space) — well below the 50% intersection
# threshold used by the validity check.
#
# Run :
#   Rscript data-raw/build_fordead_validity_zones.R
# Requires : sf, jsonlite. No authentication needed.
# ============================================================

stopifnot(
  requireNamespace("sf", quietly = TRUE),
  requireNamespace("jsonlite", quietly = TRUE)
)

DEPARTMENTS <- list(
  list(code = "88", slug = "88-vosges",        nom = "Vosges"),
  list(code = "39", slug = "39-jura",          nom = "Jura"),
  list(code = "01", slug = "01-ain",           nom = "Ain"),
  list(code = "73", slug = "73-savoie",        nom = "Savoie"),
  list(code = "74", slug = "74-haute-savoie",  nom = "Haute-Savoie")
)
URL_TPL <- paste0(
  "https://raw.githubusercontent.com/gregoiredavid/",
  "france-geojson/master/departements/%s/departement-%s.geojson"
)
OUT_PATH    <- file.path("inst", "extdata", "fordead_validity_zones.geojson")
SIMPLIFY_M  <- 100  # tolerance in metres (Lambert-93)
SOURCE      <- "gregoiredavid/france-geojson (IGN ADMIN-EXPRESS, Etalab 2.0)"
REFERENCE   <- "Bernard & Doridant (ONF/DSF) 2024"

fetch_one <- function(d) {
  url <- sprintf(URL_TPL, d$slug, d$slug)
  message(sprintf("[fordead-validity] fetching %s ...", url))
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
  "[fordead-validity] wrote %s (%d features, %.1f km^2, %s ko)",
  OUT_PATH, nrow(zones), total_km2, size_kb
))
