# Controle de centrage de T4 sur Dabo (spec 068, T4-3) : cellules hexagonales
# de 4 ha dans les peuplements BD Foret purs, essence de la BD Foret.
suppressMessages({library(sf); library(terra)}); pkgload::load_all(quiet = TRUE)
P <- path.expand("~/.local/share/nemeton/projects/20261007_084619_tcyv")
b <- st_read(file.path(P, "cache/layers/bdforet.gpkg"), quiet = TRUE)
b <- st_transform(b[b$essence %in% c("Sapin, épicéa", "Hêtre", "Pin sylvestre"), ], 2154)
hex <- st_make_grid(b, cellsize = sqrt(2 * 4e4 / (3 * sqrt(3))) * sqrt(3), square = FALSE)
hex <- st_sf(geometry = hex)
j <- st_join(st_centroid(hex), b[, "essence"], join = st_within)
hex$essence_bdf <- j$essence
hex <- hex[!is.na(hex$essence_bdf), ]
hex <- hex[as.numeric(st_area(st_intersection(hex, st_union(b)))) / as.numeric(st_area(hex)) > 0.9, ]
cat(nrow(hex), "cellules\n"); print(table(hex$essence_bdf))
e <- ext(st_bbox(st_buffer(hex, 100)))
f <- rast(path.expand(sprintf("~/.cache/nemeton/forms_t/Height_%d.tif", 2019:2024)))
f <- crop(f, project(e, "EPSG:2154", crs(f))); names(f) <- 2019:2024
for (resineux in "61") {
  code <- c("Sapin, épicéa" = resineux, "Hêtre" = "09", "Pin sylvestre" = "52")[hex$essence_bdf]
  r <- suppressMessages(indicateur_t4_vitalite(hex, f, essence = code, ser = rep("D11", nrow(hex))))
  cat("\n=== Sapin, épicéa codé", resineux, "===\n")
  print(table(r$t4_status)); print(summary(r$t4_h_dom[r$t4_status == "skipped_no_analogues"])); print(quantile(r$T4[r$t4_status=="calculated" & code=="61"], c(.05,.1,.25,.5,.75,.9,.95)))
  ok <- r$t4_status == "calculated"
  print(do.call(rbind, tapply(seq_len(nrow(r))[ok], code[ok], function(i) round(c(n = length(i),
    T4_med = median(r$T4[i]), sup90 = 100 * mean(r$T4[i] > 90), inf10 = 100 * mean(r$T4[i] < 10),
    obs = median(r$t4_accroissement_obs[i]), att = median(r$t4_accroissement_att[i]),
    h = median(r$t4_h_dom[i]), n_ana = median(r$t4_n_analogues[i])), 2))))
}
