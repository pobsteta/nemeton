# Spec 047 — comparaison à l'aveugle des expositions R1 (étape préalable au
# câblage de firexpovulnR, ADR-016). Lecture seule des caches projet.
#
#   A : chemin actuel de nemeton (fireexposuR::fire_exp sur la BD Forêt binaire,
#       grille 30 m, hazard élargi de 500 m) — composante « exposition » de R1
#   B : firexpovulnR::fev_exposure sur fev_fuel_binary (même métrique, autre code)
#   C : firexpovulnR::fev_exposure sur fev_fuel_availability (combustible gradué)
#   D : comme B, sur BD Forêt + CORINE 2018 (fev_fuel_merge) : hors forêt, CORINE
#       dit ce qui brûle (landes, pelouses) et ce qui ne brûle pas (bâti, eau)
#   E : comme C, sur BD Forêt + CORINE 2018
#
# Seuls B..E reposent sur une couverture complète si CORINE est fusionnée : sur
# BD Forêt seule, firexpovulnR tient le hors-forêt pour NA (« rien de cartographié »),
# là où A le tient pour 0 (non combustible).
#
# Usage : Rscript specs/047-r1-firexpovulnr/comparaison.R > resultats.txt
devtools::load_all(quiet = TRUE)
suppressPackageStartupMessages({ library(sf); library(terra) })

racine <- "~/.local/share/nemeton/projects"
projets <- list.dirs(path.expand(racine), recursive = FALSE)

stats_vec <- function(x) {
  x <- x[is.finite(x)]
  c(n = length(x), moy = mean(x), et = stats::sd(x), min = min(x),
    q25 = unname(stats::quantile(x, .25)), q75 = unname(stats::quantile(x, .75)),
    max = max(x), sature_95 = mean(x >= 95))
}

lignes <- list()
for (p in projets) {
  nom <- tryCatch(jsonlite::fromJSON(file.path(p, "metadata.json"))$name,
                  error = function(e) basename(p))
  f_u <- file.path(p, "data", "parcels.gpkg")
  f_bd <- file.path(p, "cache", "layers", "bdforet.gpkg")
  f_dem <- file.path(p, "cache", "layers", "dem.tif")
  if (!all(file.exists(c(f_u, f_bd, f_dem)))) next
  u <- sf::st_read(f_u, quiet = TRUE)
  bd <- sf::st_read(f_bd, quiet = TRUE)
  dem <- .normalize_crs(terra::rast(f_dem))
  u2154 <- sf::st_transform(u, 2154)

  # --- A : chemin nemeton actuel --------------------------------------------
  a <- tryCatch({
    hd <- suppressMessages(.fire_exp_working_dem(dem, crs = "EPSG:2154"))
    hz <- safe_rasterize(bd, .fire_exp_hazard_template(hd, bd, 500),
                         field = 1, background = 0)
    ex <- fireexposuR::fire_exp(hz, t_dist = 500)
    safe_extract(ex, as_pure_sf(u2154), fun = "mean", progress = FALSE) * 100
  }, error = function(e) { message(nom, " A: ", conditionMessage(e)); NULL })

  # --- B et C : firexpovulnR --------------------------------------------------
  src <- tryCatch(
    suppressWarnings(firexpovulnR::fev_fuel_source(
      sf::st_transform(bd, 2154), type = "bdforet_v2", res = 30, crs_work = 2154, millesime = NA)),
    error = function(e) { message(nom, " source: ", conditionMessage(e)); NULL })
  expo <- function(fuel) {
    e <- suppressMessages(firexpovulnR::fev_exposure(fuel, type = "ember",
                                                     quiet = TRUE))
    r <- if (inherits(e, "SpatRaster")) e else e[[1]]
    if (!inherits(r, "SpatRaster")) r <- e$exposure %||% e$raster
    safe_extract(r, as_pure_sf(u2154), fun = "mean", progress = FALSE) * 100
  }
  b <- if (!is.null(src)) tryCatch(expo(firexpovulnR::fev_fuel_binary(src)),
        error = function(e) { message(nom, " B: ", conditionMessage(e)); NULL })
  c_ <- if (!is.null(src)) tryCatch(
        expo(suppressWarnings(firexpovulnR::fev_fuel_availability(src))),
        error = function(e) { message(nom, " C: ", conditionMessage(e)); NULL })

  merged <- if (!is.null(src)) tryCatch({
    clc <- firexpovulnR::fev_fetch_corine(sf::st_transform(bd, 2154), year = 2018)
    clc_src <- suppressWarnings(firexpovulnR::fev_fuel_source(clc, type = "clc_2018",
                                                              res = 30, crs_work = 2154))
    suppressWarnings(firexpovulnR::fev_fuel_merge(src, clc_src))
  }, error = function(e) { message(nom, " CORINE: ", conditionMessage(e)); NULL })
  d <- if (!is.null(merged)) tryCatch(expo(firexpovulnR::fev_fuel_binary(merged)),
        error = function(e) { message(nom, " D: ", conditionMessage(e)); NULL })
  e_ <- if (!is.null(merged)) tryCatch(
        expo(suppressWarnings(firexpovulnR::fev_fuel_availability(merged))),
        error = function(e) { message(nom, " E: ", conditionMessage(e)); NULL })

  for (k in c("A", "B", "C", "D", "E")) {
    v <- switch(k, A = a, B = b, C = c_, D = d, E = e_)
    if (is.null(v)) next
    lignes[[length(lignes) + 1]] <- data.frame(projet = nom, chemin = k,
      t(round(stats_vec(v), 2)))
  }
  sp <- function(x, y) {
    if (is.null(x) || is.null(y)) return("NA")
    ok <- is.finite(x) & is.finite(y)
    if (sum(ok) < 3 || stats::sd(x[ok]) == 0 || stats::sd(y[ok]) == 0) return("NA")
    sprintf("%.2f (n=%d)", stats::cor(x[ok], y[ok], method = "spearman"), sum(ok))
  }
  cat(sprintf("%s : Spearman A~D = %s ; A~E = %s ; D~E = %s\n", nom,
              sp(a, d), sp(a, e_), sp(d, e_)))
}
res <- do.call(rbind, lignes)
print(res, row.names = FALSE)
