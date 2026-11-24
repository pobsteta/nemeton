# Essai manuel de la détection de décoloration (mission 046) : 1 km² de chênaie
# de la forêt communale de Couchey (zone témoin de comparaison_nemeton.R).
# Réseau requis (Planetary Computer). À lancer depuis la racine du dépôt :
#   Rscript tests/manual/decoloration-couchey.R [dossier_sortie_regionale]
# Le dossier régional contient tuiles/*/rasters/alerte_AAAA.tif (script
# suivi_decoloration_bfc.R). Sans lui, seules les chiffres de la détection sont donnés.

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

bd <- sf::st_read(file.path(rapport, "donnees/ign_bdforet_v2_r27.gpkg"), quiet = TRUE,
                  wkt_filter = sf::st_as_text(sf::st_transform(emprise, sf::st_crs(2154))))
col <- intersect(c("tfv", "TFV", "code_tfv"), names(bd))[1]
ess <- decoloration_carte_essences(bd, emprise, tfv_col = col)

annees <- 2017:2025
res <- system.time(
  d <- decoloration_detecter(emprise, annees, ess, cache_dir = cache,
                             emit = function(p) message(p$current, " ", p$annee %||% "", " ", p$mois %||% ""))
)
cat("durée :", round(res[["elapsed"]]), "s\n")
for (a in as.character(annees)) {
  v <- terra::values(d$niveaux[[a]], mat = FALSE); o <- terra::values(d$origine[[a]], mat = FALSE)
  cat(a, ": pixels", sum(!is.na(o)), "| niveaux", paste(names(table(v)), table(v), collapse = " "),
      "| origine voisins", sum(o == 2, na.rm = TRUE), "aucune", sum(o == 0, na.rm = TRUE), "\n")
}

# Comparaison au script régional, sur les pixels communs, hors origine « voisins »
fs <- list.files(sortie_reg, "^alerte_\\d{4}\\.tif$", recursive = TRUE, full.names = TRUE)
if (!length(fs)) {
  cat("Pas de sortie régionale trouvée dans", sortie_reg, ": comparaison non faite.\n")
} else {
  for (a in as.character(annees)) {
    fa <- fs[grepl(paste0("alerte_", a, "\\.tif$"), fs)]
    if (!length(fa)) next
    reg <- do.call(terra::merge, lapply(fa, function(f) terra::rast(f)[[1]]))
    reg <- terra::resample(terra::crop(reg, d$niveaux), d$niveaux, method = "near")
    n_reg <- terra::values(reg, mat = FALSE)    # classe 0/1/2 du script régional
    n_nem <- terra::values(d$niveaux[[a]], mat = FALSE)
    o <- terra::values(d$origine[[a]], mat = FALSE)
    ok <- !is.na(n_reg) & !is.na(n_nem) & o == 1
    cl_nem <- pmin(n_nem, 2) * (n_nem <= 2) + 2 * (n_nem > 2)
    cat(a, ": pixels communs", sum(ok), "| accord de classe",
        round(100 * mean(cl_nem[ok] == n_reg[ok]), 1), "%\n")
  }
}
