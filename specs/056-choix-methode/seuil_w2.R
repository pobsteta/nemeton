# Spec 056, complément : seuil TWI de W2 sur le TWI ramené à 2 m (1.0.0).
# Pour chaque projet : TWI à la résolution de travail, puis, pour plusieurs
# seuils, la part des UGF couverte par TWI > seuil, et l'accord avec la couche
# de zones humides en cache (rappel : part des zones humides de référence
# couvertes ; précision : part des pixels TWI > seuil tombant en zone humide).
# Lecture seule des projets ; cache TWI dans tempdir().
suppressMessages(devtools::load_all(quiet = TRUE))
racine <- path.expand("~/.local/share/nemeton/projects")
seuils <- c(8, 9, 10, 11, 12)
lignes <- list()
for (p in list.dirs(racine, recursive = FALSE)) {
  nom <- tryCatch(jsonlite::fromJSON(file.path(p, "metadata.json"))$name, error = function(e) basename(p))
  f_u <- file.path(p, "data", "parcels.gpkg"); f_w <- file.path(p, "cache/layers/wetlands.gpkg")
  dem_f <- file.path(p, "cache/layers/dem.tif")
  lid <- list.files(file.path(p, "cache/layers/lidar_mnt"), pattern = "mosaic.*\\.tif$|\\.tif$", full.names = TRUE)
  if (!file.exists(f_u) || !file.exists(dem_f)) next
  u <- sf::st_read(f_u, quiet = TRUE)
  dem <- .normalize_crs(terra::rast(if (length(lid) == 1) lid else dem_f))
  crs <- .twi_metric_crs(u)
  dem_w <- .dem_working_res(dem, target_res = .topo_target_res())
  twi <- tryCatch(suppressMessages(get_or_compute_twi(dem_w, cache_dir = tempfile("twi"),
                  twi_target_res = .topo_target_res(), crs = crs)), error = function(e) NULL)
  if (is.null(twi)) { message(nom, ": TWI impossible"); next }
  uu <- terra::vect(sf::st_transform(u, terra::crs(twi)))
  tw <- terra::mask(terra::crop(twi, uu), uu)
  ref <- NULL
  if (file.exists(f_w)) {
    w <- sf::st_read(f_w, quiet = TRUE)
    if (nrow(w)) ref <- terra::rasterize(terra::vect(sf::st_transform(w, terra::crs(twi))), tw, field = 1, background = 0)
    if (!is.null(ref)) ref <- terra::mask(ref, uu)
  }
  v <- terra::values(tw)[, 1]; ok <- is.finite(v)
  r <- if (!is.null(ref)) terra::values(ref)[, 1][ok] else NULL
  v <- v[ok]
  for (s in seuils) {
    wet <- v > s
    lignes[[length(lignes) + 1]] <- data.frame(
      projet = nom, res_m = round(terra::res(twi)[1], 1), seuil = s,
      part_ugf_humide = round(100 * mean(wet), 2),
      ref_humide_pct = if (!is.null(r)) round(100 * mean(r == 1), 2) else NA,
      rappel = if (!is.null(r) && any(r == 1)) round(100 * mean(wet[r == 1]), 1) else NA,
      precision = if (!is.null(r) && any(wet)) round(100 * mean(r[wet] == 1), 1) else NA)
  }
}
print(do.call(rbind, lignes), row.names = FALSE)
