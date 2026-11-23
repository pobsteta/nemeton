# Comparaison réelle (hors CI) : forçage ERA5 `timeseries` contre le chemin
# classique (mcera5::extract_clim) — mission 039, cas 13.
#
# Prérequis : clé CDS (ecmwfr) ET un forçage CLASSIQUE déjà en cache pour le point
# et l'année. Ne lance JAMAIS l'ancien chemin (des heures de file CDS) : sans
# fichier classique en cache, le script mesure seulement la durée `timeseries`.
#
# Usage : Rscript tests/manual/era5-timeseries-comparaison.R <cache_dir> [lon] [lat] [annee]
`%||%` <- function(x, y) if (is.null(x) || is.na(x)) y else x
a <- commandArgs(TRUE)
cache_dir <- a[1]; lon <- as.numeric(a[2] %||% 4.8); lat <- as.numeric(a[3] %||% 47.3)
annee <- as.integer(a[4] %||% 2024L)
devtools::load_all(quiet = TRUE)

t0 <- Sys.time()
ts <- nemeton:::.rsen_forcage_era5(lon, lat, annee, cache_dir, source = "timeseries")
cat(sprintf("timeseries : %d h en %.1f min\n", nrow(ts),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

src <- nemeton:::.rsen_era5_src(cache_dir, annee, lon, lat)
if (is.na(src)) {
  cat("Aucun fichier classique en cache : pas de comparaison (ancien chemin non lancé).\n")
  quit(status = 0)
}
st <- as.POSIXct(sprintf("%d-01-01 00:00", annee), tz = "UTC")
en <- as.POSIXct(sprintf("%d-12-31 23:00", annee), tz = "UTC")
cl <- nemeton:::.rsen_clamp_flux(mcera5::extract_clim(src, lon, lat, st, en, format = "microclimf"))
cl_pp <- nemeton:::.rsen_clamp_flux(mcera5::extract_clim(src, lon, lat, st, en,
                                                        d_weight = FALSE, format = "microclimf"))
ecart <- function(a, b) t(vapply(setdiff(names(a), "obs_time"), function(v)
  c(moyenne = mean(a[[v]] - b[[v]], na.rm = TRUE),
    max_abs = max(abs(a[[v]] - b[[v]]), na.rm = TRUE)), numeric(2)))
cat("\nÉcart timeseries - classique (4 mailles interpolées) :\n"); print(round(ecart(ts, cl), 3))
cat("\nÉcart classique maille la plus proche - interpolé :\n"); print(round(ecart(cl_pp, cl), 3))
