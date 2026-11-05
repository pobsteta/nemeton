# data-raw/aef_bornes_b4.R
#
# Bornes de normalisation de B4 en mode embedding (spec 064) : diversite de
# fenetre = divergence de Jensen-Shannon des appartenances souples (tau =
# .EMBEDDING_TAU). La normalisation est affine,
#   B4_norm = 100 * (H - H_min) / (H_max - H_min), ecretee a [0, 100],
# avec H_min et H_max = 1er et 99e centiles de cette divergence sur les fenetres du
# corpus du dictionnaire (memes 11 massifs, AlphaEarth 2024, EPSG:3035).
# Les valeurs sont ecrites dans inst/extdata/aef_clusters_v1.json (champ
# `bornes_b4`) et recopiees dans R/spectral_diversity.R ; un test verifie
# que les deux concordent.
#
# Usage (racine du paquet, reseau requis au premier passage) :
#   Rscript data-raw/aef_bornes_b4.R

pkgload::load_all(".", quiet = TRUE)
if (!requireNamespace("alphaearthnemeton", quietly = TRUE)) {
  pkgload::load_all("../alphaearthnemeton", quiet = TRUE)
}

json <- "inst/extdata/aef_clusters_v1.json"
meta <- jsonlite::read_json(json, simplifyVector = TRUE)
sites <- meta$sites
demi_cote <- meta$fenetre_m / 2

h <- unlist(lapply(seq_len(nrow(sites)), function(i) {
  s <- sites[i, ]
  centre <- sf::st_transform(sf::st_sfc(sf::st_point(c(s$lon, s$lat)), crs = 4326), 3035)[[1]]
  zone <- sf::st_as_sfc(sf::st_bbox(c(
    xmin = centre[1] - demi_cote, ymin = centre[2] - demi_cote,
    xmax = centre[1] + demi_cote, ymax = centre[2] + demi_cote
  ), crs = sf::st_crs(3035)))
  r <- alphaearthnemeton::aef_fetch(zone, years = meta$annee, crs = 3035)
  v <- terra::values(nemeton:::.embedding_fenetres(r)$shannon)[, 1]
  v[!is.na(v)]
}))

bornes <- list(
  tau = nemeton:::.EMBEDDING_TAU,
  h_min = round(unname(stats::quantile(h, 0.01)), 2),
  h_max = round(unname(stats::quantile(h, 0.99)), 2),
  fenetres = length(h),
  script = "data-raw/aef_bornes_b4.R"
)
meta$bornes_b4 <- bornes
jsonlite::write_json(meta, json, auto_unbox = TRUE, pretty = TRUE, digits = NA)
message(sprintf("tau = %.2f : H_min = %.2f, H_max = %.2f (%d fenetres)",
                bornes$tau, bornes$h_min, bornes$h_max, bornes$fenetres))
