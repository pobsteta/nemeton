# Forçage ERA5 horaire par le jeu CDS `reanalysis-era5-single-levels-timeseries`.
#
# Le jeu classique passe par la file CDS (~4 h par requête mensuelle, ~48 h pour
# 24 mois). Le jeu `timeseries` sert une série horaire EN UN POINT (la maille
# la plus proche) en ~2 min par année. Il ne porte ni masque terre-mer ni les
# flux moyens `msdwlwrf` : le rayonnement thermique descendant vient de `strd`.
#
# Même data.frame que `.rsen_forcage_era5()` par le chemin classique
# (mcera5::extract_clim(format = "microclimf")) : obs_time, temp, relhum, pres,
# swdown, difrad, lwdown, windspeed, winddir, precip.
#
# Choix, relevés dans le code de mcera5::extract_clim() :
# - Interpolation : extract_clim() pondère 4 mailles voisines par l'inverse de
#   la distance (focal_dist). Reprise à l'identique : 4 requêtes par point et
#   par année, un fichier par MAILLE (partagé entre points voisins).
# - Masque terre-mer : extract_clim() ne l'utilise que dans coastal_correct()
#   (m = (1 - lsm) * 1.285 + 1). Avec lsm = 1 (terre), m = 1 : la correction est
#   l'identité. Absent du jeu `timeseries`, on pose donc 1 : aucune correction
#   côtière (différence assumée pour un point littoral).
# - Horodatage : extract_clim() ne décale pas obs_time, mais rad_calc() recale le
#   rayonnement d'une demi-heure (valeur instantanée à t). Ici les flux du jeu
#   sont déjà horaires (J m-2 par heure, moyenne de l'heure) : aucun décalage,
#   aucune dé-accumulation.
# - Rayonnement : DIFFÉRENT de mcera5, par décision. swdown = ssrd / 3600, lwdown
#   = strd / 3600, difrad = (ssrd - fdir) / 3600 borné à [0, swdown], sans
#   rad_calc. fdir d'ERA5 est mesuré sur un plan horizontal ; mcera5 le traite
#   comme un direct normal (x sin h) et surestime le diffus (~x2 par ciel clair).
# - Aucun repli automatique vers le chemin classique (voir `.rsen_era5ts_abort`).

.RSEN_ERA5TS_DATASET <- "reanalysis-era5-single-levels-timeseries"
.RSEN_ERA5TS_VARS <- c("2m_temperature", "2m_dewpoint_temperature",
                       "surface_pressure", "10m_u_component_of_wind",
                       "10m_v_component_of_wind", "total_precipitation",
                       "total_cloud_cover", "surface_solar_radiation_downwards",
                       "total_sky_direct_solar_radiation_at_surface",
                       "surface_thermal_radiation_downwards")
.RSEN_ERA5TS_NC <- c("t2m", "d2m", "sp", "u10", "v10", "tp", "tcc", "ssrd",
                     "fdir", "strd")

# Source ERA5 : argument > option `nemeton.era5_source` > "timeseries".
# "classique" (alias "mcera5") = ancien chemin, mensuel, par mcera5.
.rsen_era5_source <- function(source = NULL) {
  s <- if (!is.null(source)) source else getOption("nemeton.era5_source", "timeseries")
  s <- match.arg(as.character(s)[1L], c("timeseries", "classique", "mcera5"))
  if (identical(s, "mcera5")) "classique" else s
}

# Les 4 mailles voisines et leurs poids : copie de mcera5:::focal_dist().
# Un point sur la grille (multiple de 0.25) n'a qu'une maille, de poids 1.
.rsen_era5ts_mailles <- function(lon, lat, pas = 0.25) {
  if (isTRUE(all.equal((lon %% pas) + (lat %% pas), 0))) {
    return(data.frame(x = lon, y = lat, w = 1))
  }
  xr <- round(lon / pas) * pas
  yr <- round(lat / pas) * pas
  fx <- if (lon >= xr) c(xr, xr, xr + pas, xr + pas) else c(xr - pas, xr - pas, xr, xr)
  fy <- if (lat >= yr) c(yr, yr + pas, yr, yr + pas) else c(yr - pas, yr, yr - pas, yr)
  d <- sqrt((lon - fx)^2 + (lat - fy)^2)
  # Maille confondue avec le point : distance nulle, poids tout entier.
  if (any(d == 0)) return(data.frame(x = fx[d == 0][1], y = fy[d == 0][1], w = 1))
  w <- (1 / d) / sum(1 / d)
  data.frame(x = fx, y = fy, w = w)
}

# Nom du fichier d'une maille et d'une année. Préfixe `era5ts_` : jamais pris
# pour un fichier classique (`era5_<lon>_<lat>_<annee>*.nc`), ni l'inverse.
.rsen_era5ts_nom <- function(cache_dir, x, y, annee) {
  enc <- function(v) {
    s <- sprintf("%.2f", round(as.numeric(v), 2) + 0)
    sub(".", "p", sub("^-", "m", s), fixed = TRUE)
  }
  file.path(cache_dir, sprintf("era5ts_%s_%s_%d.nc", enc(x), enc(y), annee))
}

# Une requête du jeu `timeseries` pour une maille et une année.
.rsen_era5ts_requete <- function(x, y, annee, cache_dir) {
  list(dataset_short_name = .RSEN_ERA5TS_DATASET,
       variable = .RSEN_ERA5TS_VARS,
       location = list(longitude = x, latitude = y),
       date = sprintf("%d-01-01/%d-12-31", annee, annee),
       data_format = "netcdf",
       target = sub("\\.nc$", ".zip", basename(.rsen_era5ts_nom(cache_dir, x, y, annee))))
}

# Tâches de lot (mêmes champs que `.rsen_era5_taches()`) d'un point et d'une année.
.rsen_era5ts_taches <- function(lon, lat, annee, cache_dir, category = NA) {
  m <- .rsen_era5ts_mailles(lon, lat)
  lapply(seq_len(nrow(m)), function(k) list(
    req = .rsen_era5ts_requete(m$x[k], m$y[k], annee, cache_dir),
    nc = .rsen_era5ts_nom(cache_dir, m$x[k], m$y[k], annee),
    year = annee, category = category))
}

# Toutes les mailles d'un point et d'une année sont en cache, complètes.
.rsen_era5ts_en_cache <- function(cache_dir, lon, lat, annee) {
  m <- .rsen_era5ts_mailles(lon, lat)
  all(vapply(seq_len(nrow(m)), function(k) {
    f <- .rsen_era5ts_nom(cache_dir, m$x[k], m$y[k], annee)
    .rsen_era5_cache_ok(f) && isTRUE(.rsen_era5ts_couvre(f, annee))
  }, logical(1)))
}

# Extraction d'un zip `timeseries` : un seul NetCDF dedans.
.rsen_era5ts_extraire <- function(recu, nc) {
  if (grepl("\\.zip$", recu)) {
    d <- tempfile("era5ts_"); dir.create(d)
    on.exit(unlink(d, recursive = TRUE), add = TRUE)
    f <- utils::unzip(recu, exdir = d)
    f <- f[grepl("\\.nc$", f)]
    if (!length(f)) stop("ERA5 timeseries archive holds no NetCDF file.", call. = FALSE)
    file.copy(f[1L], nc, overwrite = TRUE)
  } else if (!identical(normalizePath(recu, mustWork = FALSE),
                        normalizePath(nc, mustWork = FALSE))) {
    file.rename(recu, nc)
  }
  invisible(nc)
}

# Humidité relative (%) depuis t, td (°C), même formule que mcera5 (Magnus via
# humfromdew puis converthumidity), plafonnée à 100.
.rsen_era5ts_relhum <- function(tdew, tc) {
  ea <- 0.6108 * exp(17.27 * tdew / (tdew + 237.3))
  e0 <- 0.6108 * exp(17.27 * tc / (tc + 237.3))
  pmin(100, ea / e0 * 100)
}

# Lecture d'un NetCDF `timeseries` -> variables horaires d'une maille, converties.
.rsen_era5ts_lire_maille <- function(nc_path, annee, annee_complete = TRUE) {
  .rsen_era5ts_exiger_ncdf4()
  nc <- ncdf4::nc_open(nc_path)
  on.exit(ncdf4::nc_close(nc), add = TRUE)
  manquantes <- setdiff(.RSEN_ERA5TS_NC, names(nc$var))
  if (length(manquantes)) {
    stop(sprintf("file lacks variable(s): %s.", paste(manquantes, collapse = ", ")),
         call. = FALSE)
  }
  tn <- grep("time", names(nc$dim), value = TRUE)[1L]
  if (is.na(tn)) stop("ERA5 timeseries file has no time dimension.", call. = FALSE)
  td <- nc$dim[[tn]]
  base <- as.POSIXct(gsub(".*since ", "", td$units), tz = "UTC")
  t <- base + as.numeric(td$vals) * (if (grepl("hours", td$units)) 3600 else 1)
  v <- lapply(stats::setNames(.RSEN_ERA5TS_NC, .RSEN_ERA5TS_NC),
              function(k) as.numeric(ncdf4::ncvar_get(nc, k)))
  d <- data.frame(obs_time = t, v)
  d <- d[format(d$obs_time, "%Y", tz = "UTC") == as.character(annee), , drop = FALSE]
  d <- d[order(d$obs_time), , drop = FALSE]
  njours <- .rsen_era5ts_njours(annee)
  if (annee_complete && nrow(d) != 24L * njours) {
    stop(sprintf("ERA5 timeseries %d: %d hourly steps, expected %d.", annee,
                 nrow(d), 24L * njours), call. = FALSE)
  }
  tc <- d$t2m - 273.15
  swdown <- pmax(d$ssrd / 3600, 0)
  data.frame(
    obs_time = d$obs_time,
    temp = tc,
    relhum = .rsen_era5ts_relhum(d$d2m - 273.15, tc),
    pres = d$sp / 1000,
    swdown = swdown,
    difrad = pmin(pmax((d$ssrd - d$fdir) / 3600, 0), swdown),
    lwdown = pmax(d$strd / 3600, 0),
    # Vent à 2 m comme extract_clim() (profil logarithmique 10 m -> 2 m).
    windspeed = sqrt(d$u10^2 + d$v10^2) * log(67.8 * 2 - 5.42) / log(67.8 * 10 - 5.42),
    winddir = (atan2(d$u10, d$v10) * 180 / pi + 180) %% 360,
    precip = pmax(d$tp * 1000, 0))
}

# Forçage d'un point et d'une année : moyenne des mailles pondérée par l'inverse
# de la distance, comme extract_clim(d_weight = TRUE).
.rsen_era5ts_forcage <- function(cache_dir, lon, lat, annee) {
  m <- .rsen_era5ts_mailles(lon, lat)
  parts <- lapply(seq_len(nrow(m)), function(k)
    .rsen_era5ts_lire_maille(.rsen_era5ts_nom(cache_dir, m$x[k], m$y[k], annee), annee))
  cols <- c("temp", "relhum", "pres", "swdown", "difrad", "lwdown",
            "windspeed", "winddir", "precip")
  out <- parts[[1L]]
  if (length(parts) > 1L) {
    for (cn in cols) {
      out[[cn]] <- Reduce(`+`, lapply(seq_along(parts), function(k) parts[[k]][[cn]] * m$w[k]))
    }
  }
  out
}

# ncdf4 est en Suggests : message clair avant usage.
.rsen_era5ts_exiger_ncdf4 <- function() {
  if (!requireNamespace("ncdf4", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg ncdf4} is required to read ERA5 {.field timeseries} files.",
      i = "Install it, or set {.code options(nemeton.era5_source = \"classique\")}."),
      class = "rsen_era5ts_echec")
  }
  invisible(TRUE)
}

# Échec du jeu `timeseries` : jamais de repli automatique (il rouvrirait des
# heures de file et mélangerait deux diffus).
.rsen_era5ts_abort <- function(cause) {
  cli::cli_abort(c(
    "ERA5 {.field timeseries} forcing failed: {cause}",
    i = "To use the slower classic monthly path explicitly, set {.code options(nemeton.era5_source = \"classique\")}."),
    class = "rsen_era5ts_echec")
}

# Nombre de jours d'une année (règle bissextile unique).
.rsen_era5ts_njours <- function(annee) {
  if (annee %% 4 == 0 && (annee %% 100 != 0 || annee %% 400 == 0)) 366L else 365L
}

# ERA5 n'est disponible qu'avec ~5 jours de latence : une année n'est entière
# qu'à partir du 31 décembre 23 h UTC + 5 jours. `maintenant` injectable.
.RSEN_ERA5TS_LATENCE_JOURS <- 5

.rsen_era5ts_annee_close <- function(annee, maintenant = Sys.time()) {
  fin <- as.POSIXct(sprintf("%d-12-31 23:00:00", as.integer(annee)), tz = "UTC")
  as.numeric(maintenant) >= as.numeric(fin) + .RSEN_ERA5TS_LATENCE_JOURS * 86400
}

# Refus (avant tout appel CDS) d'une année qu'ERA5 ne couvre pas encore entièrement.
.rsen_era5ts_exiger_annees_closes <- function(annees, maintenant = Sys.time()) {
  if (!length(annees)) {
    .rsen_era5ts_abort("no year was requested (empty list); ask for at least one closed year.")
  }
  if (anyNA(annees)) {
    .rsen_era5ts_abort("the requested year is missing (NA); ask for a closed year.")
  }
  ouvertes <- sort(unique(annees[!vapply(annees, .rsen_era5ts_annee_close, NA,
                                         maintenant = maintenant)]))
  if (length(ouvertes)) {
    .rsen_era5ts_abort(sprintf(
      paste0("ERA5 does not yet cover the whole of year(s) %s (latency of about %d days ",
             "after 31 December); ask for a closed year."),
      paste(ouvertes, collapse = ", "), as.integer(.RSEN_ERA5TS_LATENCE_JOURS)))
  }
  invisible(TRUE)
}

# Le fichier est un cache utilisable de l'année : année entière en pas horaires
# (jours entiers de 24 h), les 10 variables présentes et écrites sur tous les pas
# (t2m, d2m, sp : jamais nuls). Une variable absente ou
# restée à zéro (jamais écrite) ne fait pas un cache : le fichier est redemandé
# au lieu de rester en cache et d'échouer à chaque lecture (mission 049).
.rsen_era5ts_couvre <- function(path, annee) {
  # ncdf4 absent : erreur claire, jamais confondue avec un fichier illisible.
  .rsen_era5ts_exiger_ncdf4()
  # TRUE / FALSE (couverture partielle) ; NA si le fichier est illisible.
  tryCatch({
    nc <- ncdf4::nc_open(path)
    on.exit(ncdf4::nc_close(nc), add = TRUE)
    tn <- grep("time", names(nc$dim), value = TRUE)[1L]
    td <- nc$dim[[tn]]
    base <- as.POSIXct(gsub(".*since ", "", td$units), tz = "UTC")
    t <- base + as.numeric(td$vals) * (if (grepl("hours", td$units)) 3600 else 1)
    njours <- .rsen_era5ts_njours(annee)
    if (sum(format(t, "%Y", tz = "UTC") == as.character(annee)) != 24L * njours)
      return(FALSE)
    if (!all(.RSEN_ERA5TS_NC %in% names(nc$var))) return(FALSE)
    # Valeur non écrite d'un NetCDF-4 : 9,97e36 (remplissage par défaut) ou 0.
    for (k in .RSEN_ERA5TS_NC) {
      v <- as.numeric(ncdf4::ncvar_get(nc, k))
      if (!all(is.finite(v) & abs(v) < 1e30)) return(FALSE)
      if (k %in% c("t2m", "d2m", "sp") && !all(v > 0)) return(FALSE)
    }
    TRUE
  }, error = function(e) NA)
}
