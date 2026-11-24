# Essai manuel de la détection de décoloration (mission 046) : 1 km² de chênaie
# de la forêt communale de Couchey (zone témoin de comparaison_nemeton.R),
# comparé à la sortie du script régional.
# Réseau requis (Planetary Computer). À lancer depuis la racine du dépôt :
#   Rscript tests/manual/decoloration-couchey.R [dossier_sortie_regionale]
# Le dossier régional contient tuiles/T*/rasters/alerte_AAAA.tif.

devtools::load_all(quiet = TRUE)
args <- commandArgs(TRUE)
rapport <- path.expand("~/dev/rapport_decoloration_bfc")
sortie_reg <- if (length(args)) args[1] else file.path(rapport, "sortie_decoloration")
cache <- file.path(rapport, "cache_nemeton_decoloration")   # hors dépôt
dir.create(cache, showWarnings = FALSE, recursive = TRUE)

z <- sf::st_transform(sf::st_read(file.path(rapport, "comparaison_nemeton/zones_temoins.gpkg"),
                                  quiet = TRUE), 2154)
z <- z[grepl("Couchey", z$commune) & z$essence == "chene", ][1, ]
ctr <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(z)))
emprise <- sf::st_as_sfc(sf::st_bbox(c(xmin = ctr[1] - 500, ymin = ctr[2] - 500,
                                       xmax = ctr[1] + 500, ymax = ctr[2] + 500), crs = 2154))
g <- nemeton:::.decol_grille(emprise)

# --- essences : le cache BD Forêt n'a que ess_id (1 chêne, 2 hêtre, 3 sapin/épicéa,
# 4 douglas), accepté tel quel par decoloration_carte_essences()
bd <- sf::st_read(file.path(rapport, "donnees/ign_bdforet_v2_r27.gpkg"), quiet = TRUE,
                  wkt_filter = sf::st_as_text(sf::st_transform(emprise, sf::st_crs(2154))))
ess <- decoloration_carte_essences(bd, emprise)

# --- coupes SUFOSAT (même règle que coupes_tuile() du script régional) :
# grille 10 m calée sur la zone, 20 m = coupé si >= 2 sous-pixels sur 4 coupés,
# date la plus précoce ; valeurs en mois absolus annee*12+mois-1, converties en
# dates (1er du mois) pour l'argument `coupes`.
t10 <- terra::rast(file.path(rapport, "donnees/sufosat_tcoupe_p90_r27.tif"))
g10 <- terra::rast(terra::ext(g), resolution = 10, crs = terra::crs(g))
t10 <- terra::resample(terra::crop(t10, terra::ext(g10), snap = "out"), g10, method = "near")
n <- terra::aggregate(!is.na(t10), fact = 2, fun = "sum")
t20 <- terra::aggregate(t10, fact = 2, fun = "min", na.rm = TRUE)
t20 <- terra::ifel(n >= 4 * 0.5, t20, NA)
t20 <- terra::resample(t20, g, method = "near")
tv <- terra::values(t20, mat = FALSE)
dates <- as.Date(ifelse(is.na(tv), NA, sprintf("%d-%02d-01", tv %/% 12, tv %% 12 + 1)))
coupes <- terra::rast(g); terra::values(coupes) <- as.numeric(dates)

# --- détection : mêmes années que le script régional (2017-2026), saison complète
# (le script régional écrit alerte_AAAA.tif sur la saison complète)
annees <- 2017:2026
res <- system.time(
  d <- decoloration_detecter(emprise, annees, ess, coupes = coupes, dossier_cache = cache,
                             mois_a_date = 10,
                             emettre = function(p) message(p$current, " ", p$annee %||% "", " ", p$mois %||% ""))
)
cat("durée :", round(res[["elapsed"]]), "s\n")
cat("pixels au décalage forcé à 0 :", d$diagnostics$n_pixels_decalage_nul, "sur", d$diagnostics$n_pixels, "\n")
for (a in as.character(annees)) {
  v <- terra::values(d$niveaux[[a]], mat = FALSE); o <- terra::values(d$origine[[a]], mat = FALSE)
  cat(a, ": pixels", sum(!is.na(o)), "| niveaux", paste(names(table(v)), table(v), collapse = " "),
      "| origine voisins", sum(o == 2, na.rm = TRUE), "aucune", sum(o == 0, na.rm = TRUE), "\n")
}

# --- comparaison au script régional, sur les pixels communs. Chaque tuile est
# découpée sur l'emprise AVANT la fusion (tuiles de 20 km voisines).
fs <- list.files(sortie_reg, "^alerte_\\d{4}\\.tif$", recursive = TRUE, full.names = TRUE)
if (!length(fs)) {
  cat("Pas de sortie régionale trouvée dans", sortie_reg, ": comparaison non faite.\n")
} else {
  tot <- list()
  for (a in as.character(annees)) {
    fa <- fs[grepl(paste0("alerte_", a, "\\.tif$"), fs)]
    morceaux <- Filter(Negate(is.null), lapply(fa, function(f) {
      r <- terra::rast(f)[[1]]
      if (is.null(terra::intersect(terra::ext(r), terra::ext(g)))) return(NULL)
      terra::crop(r, terra::ext(g), snap = "out")
    }))
    if (!length(morceaux)) next
    reg <- if (length(morceaux) > 1) do.call(terra::merge, morceaux) else morceaux[[1]]
    reg <- terra::resample(reg, d$niveaux, method = "near")
    n_reg <- terra::values(reg, mat = FALSE)     # classe 0 / 1 / 2 du script régional
    n_nem <- terra::values(d$niveaux[[a]], mat = FALSE)
    o <- terra::values(d$origine[[a]], mat = FALSE)
    cl_nem <- pmin(n_nem, 2)                     # niveaux 2, 3, 4 = alerte
    ok <- !is.na(n_reg) & !is.na(cl_nem)
    for (cas in c("propre", "voisins")) {
      k <- ok & o == (if (cas == "propre") 1 else 2)
      if (sum(k, na.rm = TRUE)) cat(a, cas, ": pixels communs", sum(k, na.rm = TRUE),
                                     "| accord de classe", round(100 * mean(cl_nem[k] == n_reg[k]), 1), "%\n")
    }
  }
}
