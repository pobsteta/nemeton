# ============================================================
# build_s2_mgrs_tiles_fr.R
# ------------------------------------------------------------
# Generates inst/extdata/s2_mgrs_tiles_fr.geojson — the Sentinel-2
# MGRS tiling grid clipped to metropolitan France (+ Corsica).
#
# Used by `R/reconfort_ingest.R::.reconfort_aoi_tiles()` (spec 021
# L2b.2) to resolve which S2 tile(s) cover a project AOI, so the
# RECONFORT/IOTA² chain can fetch the right MUSCATE L2A products.
#
# Source : global Sentinel-2 tiling grid shapefile from
# https://github.com/justinelliotmeyers/Sentinel-2-Shapefile-Index
# (the canonical ESA tiling grid, ~56,984 tiles, EPSG:4326). We clip
# it to a metropolitan-France bounding box (~188 tiles) and keep only
# the tile code, so the bundled file stays small.
#
# Output schema (one feature per tile):
#   tile   chr  MGRS tile code WITHOUT the leading "T" (e.g. "31UDP")
#
# Run :
#   Rscript data-raw/build_s2_mgrs_tiles_fr.R
# Requires : sf. No authentication needed.
# ============================================================

stopifnot(requireNamespace("sf", quietly = TRUE))

BASE <- paste0(
  "https://github.com/justinelliotmeyers/Sentinel-2-Shapefile-Index/",
  "raw/master/sentinel_2_index_shapefile"
)
# Metropolitan France + Corsica bounding box (WGS84).
FR_BBOX  <- c(xmin = -5.5, ymin = 41.0, xmax = 9.8, ymax = 51.6)
OUT_PATH <- file.path("inst", "extdata", "s2_mgrs_tiles_fr.geojson")

tmp <- tempfile("s2grid"); dir.create(tmp)
for (ext in c("shp", "dbf", "shx", "prj")) {
  message(sprintf("[s2-mgrs] fetching .%s ...", ext))
  utils::download.file(paste0(BASE, ".", ext),
                       file.path(tmp, paste0("s2.", ext)),
                       mode = "wb", quiet = TRUE)
}

grid <- sf::st_read(file.path(tmp, "s2.shp"), quiet = TRUE)
grid <- sf::st_zm(grid)                      # drop Z/M (tiles ship as 3D)
sf::st_agr(grid) <- "constant"

fr <- sf::st_as_sfc(sf::st_bbox(FR_BBOX, crs = 4326))
hit <- sf::st_intersects(grid, fr, sparse = FALSE)[, 1]
tiles <- grid[hit, ]

tiles$tile <- as.character(tiles$Name)
tiles <- tiles[order(tiles$tile), c("tile", attr(tiles, "sf_column"))]

dir.create(dirname(OUT_PATH), recursive = TRUE, showWarnings = FALSE)
if (file.exists(OUT_PATH)) file.remove(OUT_PATH)
sf::st_write(tiles, OUT_PATH, driver = "GeoJSON",
             delete_dsn = TRUE, quiet = TRUE)

size_kb <- round(file.info(OUT_PATH)$size / 1024, 1)
message(sprintf("[s2-mgrs] wrote %s (%d tiles, %s ko)",
                OUT_PATH, nrow(tiles), size_kb))
