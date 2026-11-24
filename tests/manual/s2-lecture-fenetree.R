# Mesure réelle (hors CI) — mission 044, cas 5 : lecture d'une bande S2
# Planetary Computer recadrée sur la Colombière (5,05 E / 47,30 N, ~35 ha),
# URL nue (avant) contre /vsicurl/ (après). Réseau requis.
#
# Usage : Rscript tests/manual/s2-lecture-fenetree.R
devtools::load_all(quiet = TRUE)
pt  <- sf::st_sfc(sf::st_point(c(5.05, 47.30)), crs = 4326)
aoi <- sf::st_buffer(sf::st_transform(pt, 2154), 330)  # ~35 ha
cat("Recherche STAC PC...\n")
sc <- nemeton:::stac_search_s2_pc(sf::st_bbox(sf::st_transform(aoi, 4326)),
                                  "2024-06-01", "2024-08-31", max_cloud = 20, limit = 5L)
col <- intersect(c("B04", "href_B04", "href_b04"), names(sc))[1]
href <- nemeton:::.pc_ensure_fresh_href(sc[[col]][1])
lire <- function(chemin) {
  r <- terra::rast(chemin)
  v <- terra::vect(sf::st_transform(aoi, terra::crs(r)))
  terra::values(terra::crop(r, v))
}
t_apres <- system.time(
  a <- nemeton:::.with_s2_gdal_opts(lire(nemeton:::.s2_vsi_path(href))))[3]
cat(sprintf("apres (/vsicurl/) : %.1f s\n", t_apres))
t_avant <- system.time(b <- lire(href))[3]
cat(sprintf("avant (URL nue)   : %.1f s\n", t_avant))
cat("identique :", isTRUE(all.equal(a, b)), "\n")
