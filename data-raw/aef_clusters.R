# data-raw/aef_clusters.R
#
# Dictionnaire de clusters FIXE des embeddings AlphaEarth pour B4/L3 en mode
# embedding (spec 064, decision D-6). Un k-means ajuste sur chaque projet
# rendrait B4 aussi incomparable entre projets que la version biodivMapR
# (ecart n° 6). Les centroides sont donc ajustes UNE fois, sur un corpus de
# massifs forestiers, et versionnes dans inst/extdata/.
#
# Corpus : fenetres de 2 x 2 km centrees sur des massifs forestiers de
# Bourgogne-Franche-Comte et sur trois massifs hors de France, annee 2024.
# Les centres sont approximatifs (coeur de massif) : les fenetres peuvent
# contenir des clairieres, des routes ou des lisieres. Le dictionnaire decrit
# donc des paysages forestiers, pas des peuplements purs.
#
# Usage (depuis la racine du paquet, reseau requis) :
#   Rscript data-raw/aef_clusters.R
# Necessite le paquet alphaearthnemeton (aef_fetch()).

K <- 32L
ANNEE <- 2024L
PIXELS_PAR_SITE <- 5000L
DEMI_COTE <- 1000  # m
GRAINE <- 64L
VERSION <- "v1"

SITES <- data.frame(
  site = c("chaux", "citeaux", "bertranges", "joux", "risoux",
           "vosges_saonoises", "morvan_haut_folin", "chatillon",
           "schwarzwald", "bialowieza", "bayerischer_wald"),
  pays = c(rep("FR", 8), "DE", "PL", "DE"),
  lon = c(5.70, 5.08, 3.20, 6.05, 6.10, 6.70, 4.03, 4.70, 8.20, 23.85, 13.45),
  lat = c(47.10, 47.13, 47.13, 46.86, 46.55, 47.83, 47.02, 47.83, 48.30, 52.72, 48.95)
)

if (!requireNamespace("alphaearthnemeton", quietly = TRUE)) {
  pkgload::load_all("../alphaearthnemeton", quiet = TRUE)
}

set.seed(GRAINE)
echantillons <- list()
for (i in seq_len(nrow(SITES))) {
  s <- SITES[i, ]
  centre <- sf::st_transform(sf::st_sfc(sf::st_point(c(s$lon, s$lat)), crs = 4326), 3035)[[1]]
  zone <- sf::st_as_sfc(sf::st_bbox(c(
    xmin = centre[1] - DEMI_COTE, ymin = centre[2] - DEMI_COTE,
    xmax = centre[1] + DEMI_COTE, ymax = centre[2] + DEMI_COTE
  ), crs = sf::st_crs(3035)))
  r <- alphaearthnemeton::aef_fetch(zone, years = ANNEE, crs = 3035)
  v <- terra::values(r)
  v <- v[stats::complete.cases(v), , drop = FALSE]
  v <- v[sample.int(nrow(v), min(PIXELS_PAR_SITE, nrow(v))), , drop = FALSE]
  echantillons[[s$site]] <- v
  message(sprintf("%-18s %6d pixels", s$site, nrow(v)))
}
x <- do.call(rbind, echantillons)

km <- stats::kmeans(x, centers = K, nstart = 10, iter.max = 300,
                    algorithm = "MacQueen")
# Ordre stable : clusters tries par effectif decroissant.
ordre <- order(-km$size)
centres <- km$centers[ordre, , drop = FALSE]
out <- data.frame(cluster = seq_len(K), n_pixels = km$size[ordre],
                  round(centres, 6))
names(out)[-(1:2)] <- sprintf("A%02d", 0:63)

utils::write.csv(out, sprintf("inst/extdata/aef_clusters_%s.csv", VERSION),
                 row.names = FALSE)
jsonlite::write_json(list(
  version = VERSION,
  k = K,
  annee = ANNEE,
  pixels = nrow(x),
  pixels_par_site = PIXELS_PAR_SITE,
  fenetre_m = 2 * DEMI_COTE,
  crs_echantillonnage = "EPSG:3035",
  graine = GRAINE,
  algorithme = "stats::kmeans, MacQueen, nstart = 10, iter.max = 300",
  inertie_intra_sur_totale = km$tot.withinss / km$totss,
  sites = SITES,
  source = "AlphaEarth Foundations Satellite Embedding v1 (annual), CC-BY 4.0",
  attribution = paste("The AlphaEarth Foundations Satellite Embedding dataset is",
                      "produced by Google and Google DeepMind."),
  date = as.character(Sys.Date()),
  script = "data-raw/aef_clusters.R"
), sprintf("inst/extdata/aef_clusters_%s.json", VERSION),
auto_unbox = TRUE, pretty = TRUE, digits = NA)
message("Ecrit inst/extdata/aef_clusters_", VERSION, ".csv (",
        K, " centroides) et .json")
