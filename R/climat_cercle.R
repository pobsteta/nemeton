# climat_cercle.R — contexte climatique estival sur un cercle autour du projet
# (spec 063). Remplace, pour la carte « Contexte régional » de reGénération, la
# chaîne E-OBS 12 ans + KED (spec 034) par la méthode des scripts de Pascal
# (carte_bivariee_tmax_precip_safran.R, figure1_IF49.R,
# nuages_bfc_chelsa_safran.R) :
#   - mensualisation (Tmax moyenne, précipitations cumulées, na.rm = FALSE) ;
#   - saison `mois` (défaut mai-septembre), années complètes seulement ;
#   - tendance = pente MCO × (an_max - an_min) : variation TOTALE (°C, mm) ;
#   - classification bivariée sur la palette 10 × 10 de la Figure 1 de L'IF 49.
# Trois sources, rendues à leur résolution native (aucun downscaling) :
# E-OBS 0,1° (KNMI, cache machine), CHELSA v2.1 30″ (COG distants), SAFRAN 8 km
# (API OGC-EDR GéoSAS). eobs_downscale*() et tendances_estivales_eobs() restent
# en place pour leurs autres usages.

# ---- Constantes ----------------------------------------------------------------

# Palette 10 × 10 relevée sur la légende de la Figure 1 de L'IF n° 49
# (figure1_IF49.R) : ligne 1 = réchauffement maximal, colonne 1 = assèchement
# maximal.
.CLIMAT_PALETTE_IF49 <- matrix(c(
  "#E52521","#E6292B","#E62D3C","#E73553","#E83E6B","#EA4B84","#EB589A","#DC6BA6","#CC7DB2","#C688BA",
  "#E62F20","#E63429","#E7373A","#E83C51","#E9436B","#E64D84","#DD589B","#C765A4","#B273AD","#AA7BB4",
  "#E7411F","#E84226","#E84438","#E74850","#E04E6C","#D95286","#CD579C","#B160A2","#9A67A8","#8F6BAC",
  "#EA581E","#EA5622","#E95635","#DE5652","#D3576C","#C95588","#BA579C","#9D5AA0","#835CA2","#755CA4",
  "#EE721D","#ED6D22","#E36735","#D66452","#C85F6D","#BA5C89","#AA579D","#88569E","#6D509D","#5F509D",
  "#F28C1B","#EF841C","#DD7A38","#CC7253","#BC696E","#AB5F8A","#99579E","#75509B","#5B4C9A","#4F4C9B",
  "#F7A815","#EC9C1B","#D78E38","#C47F53","#B0726F","#9E648B","#88579F","#654C9A","#4D4999","#424C9B",
  "#FDC609","#E8B21E","#D1A038","#BC8E53","#A37B70","#90698C","#75569F","#544999","#404898","#384B9B",
  "#FFE209","#E5CA1F","#CCB237","#B29B54","#998471","#7F6D8C","#6656A0","#474999","#364898","#2E4C9B",
  "#F3E600","#E0DE29","#C7C638","#AAAA56","#8C8D72","#72718D","#5656A2","#3C4898","#2F4899","#2B4C9B"),
  nrow = 10, byrow = TRUE)

# Couleurs d'angle de la variante interpolée (carte_bivariee_tmax_precip_safran.R).
.CLIMAT_COINS <- c(sec_frais = "#F2E01E", sec_chaud = "#E3171C",
                   hum_frais = "#2B3F9C", hum_chaud = "#C893C6")

# Période et bornes de la Figure 1 (variation totale 2006-2020).
.CLIMAT_PERIODE_IF49 <- c(2006L, 2020L)
.CLIMAT_BORNES_IF49 <- list(tmax = c(-0.7, 4), precip = c(-270, 120))

# Emprise de l'agrégat mensuel E-OBS « France » (métropole + Corse, EPSG:4326).
.CLIMAT_EXT_FRANCE <- c(-5.5, 10, 41, 51.5)

# Années couvertes par défaut, par source.
.CLIMAT_ANNEES_CHELSA <- 1979:2021

.CLIMAT_RESOLUTION <- c(eobs = "0.1deg", chelsa = "30arcsec", safran = "8km")
.CLIMAT_ATTRIBUTION <- c(
  eobs = "Copernicus C3S / ECA&D, E-OBS (0,1\u00b0), usage non commercial",
  chelsa = "CHELSA v2.1 (Karger et al.), 30\u2033 (~1 km)",
  safran = "M\u00e9t\u00e9o-France SAFRAN (8 km), API OGC-EDR G\u00e9oSAS (INRAE)")

.SAFRAN_EDR_URL <- "https://api.geosas.fr/edr/collections/safran-isba/cube"
# France métropolitaine + Corse en Lambert-93 (SAFRAN_BBOX des scripts).
.SAFRAN_BBOX_FRANCE <- c(60000, 6040000, 1250000, 7120000)

# ---- Helpers communs (purs) ------------------------------------------------------

# Cercle de `rayon_km` autour du centroïde du projet, construit en EPSG:3035
# (métrique, ADR-008) puis rendu en EPSG:4326.
.climat_cercle <- function(aoi, rayon_km) {
  g <- sf::st_union(sf::st_geometry(aoi))
  if (is.na(sf::st_crs(g))) {
    cli::cli_abort("{.arg aoi} has no CRS.")
  }
  centre <- sf::st_centroid(sf::st_transform(g, 3035))
  sf::st_transform(sf::st_buffer(centre, rayon_km * 1000), 4326)
}

# Découpe d'un raster au cercle : les mailles qui TOUCHENT le cercle restent
# entières (une maille E-OBS de 11 km doit rester visible pour un rayon de 10 km).
.climat_decouper <- function(r, cercle) {
  v <- terra::vect(sf::st_transform(cercle, terra::crs(r)))
  r <- terra::crop(r, v, snap = "out")
  terra::mask(r, v, touches = TRUE)
}

# Dates d'un raster mensuel nommé "AAAA-MM" (ou portant terra::time()).
.climat_dates_mensuelles <- function(m) {
  nm <- names(m)
  if (all(grepl("^\\d{4}-\\d{2}$", nm))) return(as.Date(paste0(nm, "-01")))
  tt <- terra::time(m)
  if (length(tt) && !all(is.na(tt))) return(as.Date(tt))
  cli::cli_abort("Monthly raster needs layer names {.val AAAA-MM} or {.fun terra::time}.")
}

# Mensuel -> une couche par été (ete_annuel() des scripts) : seules les années
# où TOUS les mois de `mois` sont présents sont gardées ; un mois NA (incomplet)
# rend la maille NA pour l'été (na.rm = FALSE).
.climat_ete_annuel <- function(m, mois, fun) {
  d <- .climat_dates_mensuelles(m)
  mo <- as.integer(format(d, "%m"))
  an <- as.integer(format(d, "%Y"))
  sel <- mo %in% mois
  # Un mois en double ne doit pas compléter l'été.
  cles <- unique(data.frame(an = an[sel], mo = mo[sel]))
  complets <- as.integer(names(which(table(cles$an) == length(mois))))
  keep <- which(sel & an %in% complets & !duplicated(paste(an, mo)))
  if (!length(keep)) return(NULL)
  e <- terra::tapp(m[[keep]], index = an[keep], fun = fun, na.rm = FALSE)
  ans <- sort(unique(an[keep]))
  names(e) <- as.character(ans)
  terra::time(e) <- as.Date(sprintf("%d-07-15", ans))
  e
}

# Pente MCO par ligne d'une matrice cellules × années, NA ignorés ligne par
# ligne ; NA si moins de `min_frac` des années sont valides.
.climat_pente_mat <- function(Y, t, min_frac = 0.8) {
  ok <- is.finite(Y)
  Tm <- matrix(t, nrow(Y), ncol(Y), byrow = TRUE)
  Yz <- Y; Yz[!ok] <- 0; Tm[!ok] <- 0
  n <- rowSums(ok)
  mt <- rowSums(Tm) / n
  my <- rowSums(Yz) / n
  dt <- (Tm - mt) * ok
  sxx <- rowSums(dt^2)
  sxy <- rowSums(dt * (Yz - my) * ok)
  pente <- sxy / sxx
  pente[n < min_frac * ncol(Y) | n < 2L | !is.finite(pente) | sxx == 0] <- NA_real_
  pente
}

# Variation totale sur la période = pente MCO × (an_max - an_min) (tendance()
# des scripts). `e` : une couche par année, nommée par l'année.
.climat_tendance <- function(e, debut = NULL, fin = NULL, min_frac = 0.8) {
  ans <- as.integer(names(e))
  if (!is.null(debut)) {
    k <- which(ans >= debut & ans <= fin)
    e <- e[[k]]; ans <- ans[k]
  }
  Y <- terra::values(e, mat = TRUE)
  out <- terra::rast(e[[1]])
  terra::values(out) <- .climat_pente_mat(Y, ans, min_frac) * (max(ans) - min(ans))
  out
}

# Classe 1..n d'une valeur sur [lo, hi], valeurs hors bornes écrêtées.
.climat_classer <- function(x, lo, hi, n) {
  x <- pmin(pmax(x, lo), hi)
  as.integer(pmin(floor((x - lo) / (hi - lo) * n), n - 1) + 1)
}

# Bornes d'un axe tirées des données : quantiles 1 % et 99 % étendus à 0.
.climat_bornes_quantiles <- function(v, probs = c(0.01, 0.99)) {
  v <- v[is.finite(v)]
  if (!length(v)) return(c(NA_real_, NA_real_))
  q <- stats::quantile(v, probs, names = FALSE)
  b <- c(min(q[1], 0), max(q[2], 0))
  if (b[1] == b[2]) b <- b + c(-1, 1) * max(abs(b[1]) * 0.1, 1e-6)
  b
}

# Couleurs indexées par la classe bivariée (ct - 1) * n + cp, avec ct = 1 la
# moindre hausse de Tmax (n = la plus forte) et cp = 1 le plus sec (n = le plus
# humide) — même convention que eobs_downscale_bivariate().
.climat_palette <- function(palette, n) {
  if (identical(palette, "if49_10x10")) {
    if (n != 10L) {
      cli::cli_abort("{.code palette = \"if49_10x10\"} needs {.code n = 10}; use {.code palette = \"coins\"} for another {.arg n}.")
    }
    ct <- rep(seq_len(n), each = n); cp <- rep(seq_len(n), times = n)
    return(.CLIMAT_PALETTE_IF49[cbind(n - ct + 1L, cp)])
  }
  C <- lapply(.CLIMAT_COINS, function(h) grDevices::col2rgb(h)[, 1])
  ct <- rep(seq_len(n), each = n); cp <- rep(seq_len(n), times = n)
  u <- (cp - 1) / (n - 1); v <- (ct - 1) / (n - 1)
  vapply(seq_along(u), function(i) {
    x <- (1 - u[i]) * (1 - v[i]) * C$sec_frais + (1 - u[i]) * v[i] * C$sec_chaud +
      u[i] * (1 - v[i]) * C$hum_frais + u[i] * v[i] * C$hum_chaud
    grDevices::rgb(x[1], x[2], x[3], maxColorValue = 255)
  }, character(1))
}

# Méta d'échec homogène (jamais de stop() réseau non rattrapé).
.climat_echec <- function(status, reason, source = NA_character_, ...) {
  list(status = status, reason = reason, source = source, ...)
}

# Clé de cache stable d'un cercle (centre arrondi au mètre en EPSG:3035).
.climat_cle_cercle <- function(cercle, rayon_km, mois, source) {
  xy <- sf::st_coordinates(sf::st_centroid(sf::st_transform(cercle, 3035)))
  sprintf("%s_r%g_m%d-%d_%d_%d", source, rayon_km, min(mois), max(mois),
          round(xy[1, 1]), round(xy[1, 2]))
}

.climat_write_meta <- function(meta, path) {
  tryCatch(jsonlite::write_json(meta, path, auto_unbox = TRUE, digits = NA,
                                pretty = TRUE, null = "null", na = "null"),
           error = function(e) cli::cli_warn("Climate meta not written: {conditionMessage(e)}"))
}

# ---- E-OBS (KNMI, cache machine partagé) -------------------------------------------

.eobs_knmi_url <- function(var, version) sprintf(
  "https://knmi-ecad-assets-prd.s3.amazonaws.com/ensembles/data/Grid_0.1deg_reg_ensemble/%s_ens_mean_0.1deg_reg_v%s.nc",
  var, version)

.climat_eobs_dir <- function(eobs_cache_dir = NULL) {
  eobs_cache_dir %||% file.path(get_global_cache_dir(), "eobs")
}

.climat_eobs_mensuel_path <- function(var, version, dir) {
  file.path(dir, sprintf("eobs_%s_mensuel_france_v%s.tif", var, version))
}

# Téléchargement KNMI avec reprise (multi_download, 3 essais). Renvoie le
# chemin du netCDF ou échoue avec un message explicite.
.eobs_knmi_fetch <- function(var, version, dir, emit) {
  if (!requireNamespace("curl", quietly = TRUE)) {
    cli::cli_abort("The KNMI E-OBS download needs the {.pkg curl} package.")
  }
  url <- .eobs_knmi_url(var, version)
  dest <- file.path(dir, basename(url))
  for (k in 1:3) {
    emit(list(current = "climat:telechargement", source = "eobs", var = var,
              file = basename(dest), essai = k))
    res <- tryCatch(curl::multi_download(url, destfiles = dest, resume = TRUE,
                                         progress = FALSE),
                    error = function(e) NULL)
    # 206 = reprise réussie, 416 = fichier déjà complet.
    if (!is.null(res) && (isTRUE(res$success[1]) ||
                          res$status_code[1] %in% c(200, 206, 416))) {
      return(dest)
    }
  }
  cli::cli_abort("KNMI E-OBS download failed for {.val {var}} (v{version}).")
}

# Quotidien -> mensuel sur l'emprise France, année par année (mémoire bornée),
# écrit UNE FOIS dans le cache machine. `daily` : chemin(s) netCDF ou
# SpatRaster quotidien daté.
.eobs_mensuel_france <- function(daily, var, fun, dest, emit) {
  r <- if (inherits(daily, "SpatRaster")) daily else {
    if (length(daily) == 1L) terra::rast(daily, subds = var) else terra::rast(daily)
  }
  dates <- as.Date(terra::time(r))
  if (!length(dates) || all(is.na(dates))) {
    cli::cli_abort("E-OBS daily raster carries no dates.")
  }
  e <- terra::ext(.CLIMAT_EXT_FRANCE)
  an <- as.integer(format(dates, "%Y"))
  ans <- sort(unique(an))
  morceaux <- lapply(seq_along(ans), function(i) {
    emit(list(current = "climat:mensualisation", source = "eobs", var = var,
              annee = ans[i], i = i, n = length(ans)))
    idx <- which(an == ans[i])
    x <- terra::crop(r[[idx]], e, snap = "out")
    ym <- format(dates[idx], "%Y-%m")
    m <- terra::tapp(x, index = ym, fun = fun, na.rm = FALSE)
    names(m) <- sort(unique(ym))
    m
  })
  m <- terra::rast(morceaux)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  m <- terra::writeRaster(m, dest, overwrite = TRUE)
  m
}

# Agrégats mensuels France (tx, rr) depuis le cache, construits au besoin
# depuis KNMI, puis le CDS en repli.
.eobs_mensuel_assurer <- function(version, dir, emit) {
  out <- list()
  for (var in c("tx", "rr")) {
    dest <- .climat_eobs_mensuel_path(var, version, dir)
    if (file.exists(dest)) {
      emit(list(current = "climat:cache_hit", source = "eobs", file = basename(dest)))
      out[[var]] <- terra::rast(dest)
      next
    }
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    fun <- if (var == "tx") "mean" else "sum"
    nc <- tryCatch(.eobs_knmi_fetch(var, version, dir, emit), error = function(e) e)
    if (inherits(nc, "error")) {
      cli::cli_warn(c("KNMI E-OBS unavailable, falling back to the CDS.",
                      x = conditionMessage(nc)))
      nc <- .eobs_cds_fetch(.eobs_var_spec(var)$cds,
                            years = 1950:(as.integer(format(Sys.Date(), "%Y")) - 1L),
                            cache_dir = dir, version = version,
                            resolution = "0.1deg", emit = emit)
    }
    out[[var]] <- .eobs_mensuel_france(nc, var, fun, dest, emit)
  }
  out
}

# ---- CHELSA v2.1 (COG distants, découpés au cercle) ---------------------------------

.chelsa_urls <- function(var, an, nom) c(
  sprintf("https://os.unil.cloud.switch.ch/chelsa02/chelsa/global/monthly/%s/%d/%s", var, an, nom),
  sprintf("https://os.zhdk.cloud.switch.ch/chelsav2/GLOBAL/monthly/%s/%s", var, nom),
  sprintf("https://os.zhdk.cloud.switch.ch/envicloud/chelsa/chelsa_V2/GLOBAL/monthly/%s/%s", var, nom))

# Ouverture distante d'un COG (point de mock des tests).
.chelsa_ouvrir <- function(url) {
  tryCatch(terra::rast(paste0("/vsicurl/", url)), error = function(e) NULL)
}

# Conversions robustes, selon que GDAL applique ou non scale/offset.
.chelsa_conv_tasmax <- function(r) {
  m <- terra::global(r, "mean", na.rm = TRUE)[1, 1]
  if (!is.finite(m)) return(r)
  if (m > 1000) r * 0.1 - 273.15 else if (m > 200) r - 273.15 else r
}
.chelsa_conv_pr <- function(r) {
  m <- terra::global(r, "max", na.rm = TRUE)[1, 1]
  if (is.finite(m) && m > 2000) r / 100 else r
}

# Un mois CHELSA découpé à `e` (SpatExtent EPSG:4326), en cache ; NA si aucune
# URL ne répond.
.chelsa_un <- function(var, an, mois, e, dest) {
  if (file.exists(dest)) return(dest)
  nom <- sprintf("CHELSA_%s_%02d_%d_V.2.1.tif", var, mois, an)
  for (u in .chelsa_urls(var, an, nom)) {
    r <- .chelsa_ouvrir(u)
    if (is.null(r)) next
    r <- tryCatch(terra::crop(r, e, snap = "out"), error = function(err) NULL)
    if (is.null(r)) next
    r <- if (var == "tasmax") .chelsa_conv_tasmax(r) else .chelsa_conv_pr(r)
    terra::writeRaster(r, dest, overwrite = TRUE)
    return(dest)
  }
  NA_character_
}

.climat_series_chelsa <- function(cercle, mois, annees, dir, emit) {
  e <- terra::ext(terra::vect(cercle)) + 0.01
  grille <- expand.grid(mois = mois, an = annees)
  lire <- function(var) {
    f <- character(nrow(grille))
    for (i in seq_len(nrow(grille))) {
      if (grille$mois[i] == mois[1]) {
        emit(list(current = "climat:annee", source = "chelsa", var = var,
                  annee = grille$an[i], i = match(grille$an[i], annees),
                  n = length(annees)))
      }
      dest <- file.path(dir, sprintf("chelsa_%s_%d_%02d.tif", var,
                                     grille$an[i], grille$mois[i]))
      f[i] <- .chelsa_un(var, grille$an[i], grille$mois[i], e, dest)
    }
    ok <- !is.na(f)
    if (!any(ok)) return(NULL)
    r <- terra::rast(f[ok])
    names(r) <- sprintf("%d-%02d", grille$an[ok], grille$mois[ok])
    r
  }
  tx <- lire("tasmax"); pr <- lire("pr")
  if (is.null(tx) || is.null(pr)) return(NULL)
  list(tx = .climat_ete_annuel(tx, mois, "mean"),
       rr = .climat_ete_annuel(pr, mois, "sum"))
}

# ---- SAFRAN (API OGC-EDR GéoSAS) ------------------------------------------------------

.safran_url <- function(bbox, an, mois) {
  fin <- seq(as.Date(sprintf("%d-%02d-01", an, mois)), by = "month",
             length.out = 2)[2] - 1
  sprintf(paste0("%s?bbox=%s&datetime=%d-%02d-01/%s",
                 "&parameter-name=TSUP_H_Q,PRELIQ_Q,PRENEI_Q&f=CSV&crs=EPSG:2154"),
          .SAFRAN_EDR_URL, paste(format(round(bbox), scientific = FALSE, trim = TRUE),
                                 collapse = ","), an, mois, fin)
}

# Un mois SAFRAN (CSV) sur `bbox` (Lambert-93) ; 3 essais, attente croissante ;
# NULL en cas d'échec (le JSON d'erreur servi à la place du CSV est détecté).
.safran_mois <- function(an, mois, bbox) {
  if (!requireNamespace("curl", quietly = TRUE)) return(NULL)
  url <- .safran_url(bbox, an, mois)
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  for (k in 1:3) {
    ok <- tryCatch({ curl::curl_download(url, tmp, quiet = TRUE); TRUE },
                   error = function(e) FALSE)
    if (ok && file.size(tmp) > 0 &&
        !grepl("^\\s*\\{", readLines(tmp, n = 1, warn = FALSE))) {
      return(utils::read.csv(tmp, stringsAsFactors = FALSE))
    }
    Sys.sleep(5 * k)
  }
  NULL
}

# Agrégat estival d'une année (mis en cache) : une ligne par maille complète.
.safran_ete <- function(an, mois, bbox, cache) {
  if (file.exists(cache)) return(utils::read.csv(cache))
  lst <- lapply(mois, function(m) .safran_mois(an, m, bbox))
  if (any(vapply(lst, is.null, TRUE))) return(NULL)
  d <- do.call(rbind, lst)
  attendu <- .eobs_jours_attendus(an, mois)
  d$x <- round(d$x); d$y <- round(d$y)
  d$pr <- d$PRELIQ_Q + d$PRENEI_Q
  cle <- paste(d$x, d$y)
  a <- data.frame(
    x = tapply(d$x, cle, `[`, 1), y = tapply(d$y, cle, `[`, 1),
    tmax = tapply(d$TSUP_H_Q, cle, mean), pr = tapply(d$pr, cle, sum),
    n = tapply(d$pr, cle, length))
  a <- a[a$n == attendu, c("x", "y", "tmax", "pr")]   # été incomplet -> écartée
  if (!nrow(a)) return(NULL)
  rownames(a) <- NULL
  utils::write.csv(a, cache, row.names = FALSE)
  a
}

# Grille SAFRAN reconstruite depuis les centres de mailles (safran_rasters()) :
# `annuels` = liste nommée par année de data.frame(x, y, tmax, pr).
.safran_rasters <- function(annuels, pas = 8000) {
  d <- do.call(rbind, lapply(names(annuels), function(a) {
    cbind(annuels[[a]][, c("x", "y", "tmax", "pr")], annee = as.integer(a))
  }))
  ux <- sort(unique(d$x)); uy <- sort(unique(d$y))
  dx <- if (length(ux) > 1) stats::median(diff(ux)) else pas
  dy <- if (length(uy) > 1) stats::median(diff(uy)) else pas
  g <- terra::rast(xmin = min(ux) - dx / 2, xmax = max(ux) + dx / 2,
                   ymin = min(uy) - dy / 2, ymax = max(uy) + dy / 2,
                   ncols = round((max(ux) - min(ux)) / dx) + 1,
                   nrows = round((max(uy) - min(uy)) / dy) + 1, crs = "EPSG:2154")
  cell <- terra::cellFromXY(g, cbind(d$x, d$y))
  ans <- sort(unique(d$annee))
  remplir <- function(v) {
    m <- matrix(NA_real_, terra::ncell(g), length(ans))
    m[cbind(cell, match(d$annee, ans))] <- d[[v]]
    r <- terra::rast(g, nlyrs = length(ans))
    terra::values(r) <- m
    names(r) <- as.character(ans)
    terra::time(r) <- as.Date(sprintf("%d-07-15", ans))
    r
  }
  list(tx = remplir("tmax"), rr = remplir("pr"))
}

.climat_series_safran <- function(cercle, mois, annees, dir, emit) {
  c93 <- sf::st_transform(cercle, 2154)
  # Marge d'une demi-diagonale de maille : les mailles qui touchent le cercle
  # ont leur centre hors de son emprise.
  bbox <- as.numeric(sf::st_bbox(c93)) + c(-6000, -6000, 6000, 6000)
  # Été en cours non terminé : ignoré.
  fin_ete <- function(an) seq(as.Date(sprintf("%d-%02d-01", an, max(mois))),
                              by = "month", length.out = 2)[2] - 1
  annees <- annees[vapply(annees, function(a) fin_ete(a) < Sys.Date(), TRUE)]
  annuels <- list()
  for (i in seq_along(annees)) {
    emit(list(current = "climat:annee", source = "safran", annee = annees[i],
              i = i, n = length(annees)))
    a <- .safran_ete(annees[i], mois, bbox,
                     file.path(dir, sprintf("safran_ete_%d.csv", annees[i])))
    if (!is.null(a)) annuels[[as.character(annees[i])]] <- a
  }
  if (!length(annuels)) return(NULL)
  .safran_rasters(annuels)
}

# ---- API exportée --------------------------------------------------------------------

#' Summer climate series on a circle around the project (E-OBS, CHELSA, SAFRAN)
#'
#' @description
#' Per-year **summer** maximum temperature and precipitation on a circle of
#' `rayon_km` around the project centroid, at the **native resolution** of the
#' source (no downscaling, spec 063): E-OBS 0.1° (EPSG:4326), CHELSA v2.1 30″
#' (~1 km, EPSG:4326) or SAFRAN 8 km (EPSG:2154, metropolitan France only).
#' Tmax is the mean of the monthly means of `mois`, precipitation the sum of
#' the monthly totals; only years where every month of `mois` is complete are
#' kept. Cells touching the circle are kept whole.
#'
#' Acquisition:
#' - **E-OBS**: full daily files from KNMI (`version`, default `"33.0e"`,
#'   resumable download, no key), aggregated **once** into monthly France
#'   GeoTIFFs in a machine-wide cache (`eobs_cache_dir`, default
#'   `file.path(get_global_cache_dir(), "eobs")`); falls back to the CDS
#'   ([load_eobs_source()] key) when KNMI is unreachable. Each project then
#'   crops the cached GeoTIFF. Licence: non-commercial use.
#' - **CHELSA**: remote reads (`/vsicurl/`) of the monthly COGs, cropped to the
#'   circle, cached per project and circle (`cache_dir`).
#' - **SAFRAN**: GéoSAS OGC-EDR API (INRAE), one request per month on the
#'   circle's Lambert-93 bounding box, cached per summer.
#'
#' @param aoi An `sf`/`sfc` of the project units (the circle is centred on the
#'   centroid of their union).
#' @param source `"eobs"`, `"chelsa"` or `"safran"`.
#' @param rayon_km Circle radius in kilometres (default 25).
#' @param mois Summer months (default `5:9`, May to September).
#' @param annees Optional years; default all available (E-OBS 1950-, CHELSA
#'   1979-2021, SAFRAN 1959 to the last complete summer).
#' @param cache_dir Optional project cache directory. When given, CHELSA months
#'   and SAFRAN summers are cached under `cache_dir/climat/<source>/<key>/`, and
#'   the resulting series are written as `<key>_tx.tif`, `<key>_rr.tif`,
#'   `<key>_cercle.gpkg` and `<key>.meta.json` under `cache_dir/climat/`
#'   (reused on later calls). The
#'   key encodes source, radius, months and circle centre.
#' @param eobs_cache_dir Machine-wide E-OBS cache (see above).
#' @param version E-OBS version for the KNMI files (default `"33.0e"`).
#' @param progress_callback Optional function receiving
#'   `list(current = <step>, ...)` payloads: `"climat:cache_hit"`,
#'   `"climat:telechargement"` (`var`, `file`, `essai`),
#'   `"climat:mensualisation"` and `"climat:annee"` (`annee`, `i`, `n`),
#'   `"climat:complete"`, `"climat:indisponible"` (`reason`, `message`).
#' @param ... Reserved.
#'
#' @return `list(tx, rr, cercle, meta)`: `tx` and `rr` are `SpatRaster`s with one
#'   layer per year (named by year), `NULL` unless `meta$status == "ok"`;
#'   `cercle` is the circle (`sf`, EPSG:4326); `meta` holds `status` (`"ok"`,
#'   `"hors_couverture"`, `"indisponible"`, `"donnees_insuffisantes"`),
#'   `reason`, `source`, `resolution_native`, `annees`, `mois`, `crs`,
#'   `rayon_km`, `centre` (lon, lat), `attribution` and `fichiers` (cached
#'   paths, when `cache_dir` is given).
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [climat_tendance_bivariee()], [climat_nuages_annuels()]
#' @export
climat_ete_series <- function(aoi, source = c("eobs", "chelsa", "safran"),
                              rayon_km = 25, mois = 5:9, annees = NULL,
                              cache_dir = NULL, eobs_cache_dir = NULL,
                              version = "33.0e", progress_callback = NULL, ...) {
  source <- match.arg(source)
  emit <- function(payload) if (!is.null(progress_callback)) progress_callback(payload)
  if (!inherits(aoi, c("sf", "sfc"))) cli::cli_abort("{.arg aoi} must be an {.cls sf}/{.cls sfc}.")
  if (!is.numeric(rayon_km) || length(rayon_km) != 1L || rayon_km <= 0) {
    cli::cli_abort("{.arg rayon_km} must be a positive number.")
  }
  mois <- sort(unique(as.integer(mois)))
  if (!length(mois) || any(mois < 1L | mois > 12L)) cli::cli_abort("{.arg mois} must be months 1-12.")

  cercle <- .climat_cercle(aoi, rayon_km)
  centre <- as.numeric(sf::st_coordinates(sf::st_centroid(
    sf::st_transform(sf::st_transform(cercle, 3035), 4326))))
  cercle_sf <- sf::st_sf(rayon_km = rayon_km, geometry = cercle)
  base_meta <- list(source = source, resolution_native = .CLIMAT_RESOLUTION[[source]],
                    mois = mois, rayon_km = rayon_km, centre = centre,
                    attribution = .CLIMAT_ATTRIBUTION[[source]])
  rendre <- function(tx, rr, meta) list(tx = tx, rr = rr, cercle = cercle_sf,
                                        meta = c(meta, base_meta))
  echec <- function(status, reason, message = NULL) {
    emit(list(current = "climat:indisponible", source = source, reason = reason,
              message = message))
    rendre(NULL, NULL, list(status = status, reason = reason, message = message))
  }

  # Couverture : SAFRAN = France métropolitaine ; E-OBS = emprise de l'agrégat France.
  c93 <- sf::st_coordinates(sf::st_transform(sf::st_centroid(sf::st_transform(cercle, 3035)), 2154))
  if (source == "safran") {
    b <- .SAFRAN_BBOX_FRANCE
    if (c93[1] < b[1] || c93[1] > b[3] || c93[2] < b[2] || c93[2] > b[4]) {
      return(echec("hors_couverture", "safran_france_only"))
    }
  }
  if (source == "eobs") {
    b <- .CLIMAT_EXT_FRANCE
    if (centre[1] < b[1] || centre[1] > b[2] || centre[2] < b[3] || centre[2] > b[4]) {
      return(echec("hors_couverture", "eobs_cache_france_only"))
    }
  }

  # Cache des séries (projet).
  cle <- .climat_cle_cercle(cercle, rayon_km, mois, source)
  if (!is.null(annees)) cle <- sprintf("%s_a%d-%d", cle, min(annees), max(annees))
  fichiers <- NULL
  if (!is.null(cache_dir)) {
    racine <- file.path(cache_dir, "climat")
    fichiers <- list(tx = file.path(racine, paste0(cle, "_tx.tif")),
                     rr = file.path(racine, paste0(cle, "_rr.tif")),
                     meta = file.path(racine, paste0(cle, ".meta.json")),
                     cercle = file.path(racine, paste0(cle, "_cercle.gpkg")))
    if (all(file.exists(unlist(fichiers)))) {
      emit(list(current = "climat:cache_hit", source = source, file = basename(fichiers$tx)))
      tx <- terra::rast(fichiers$tx); rr <- terra::rast(fichiers$rr)
      ans <- as.integer(names(tx))
      return(rendre(tx, rr, list(status = "ok", reason = NULL, annees = ans,
                                 crs = terra::crs(tx, describe = TRUE)$code,
                                 fichiers = fichiers)))
    }
  }
  travail <- if (is.null(cache_dir)) file.path(tempdir(), "nemeton_climat", cle) else
    file.path(cache_dir, "climat", source, cle)

  res <- tryCatch({
    if (source == "eobs") {
      m <- .eobs_mensuel_assurer(version, .climat_eobs_dir(eobs_cache_dir), emit)
      tx <- .climat_decouper(m$tx, cercle); rr <- .climat_decouper(m$rr, cercle)
      list(tx = .climat_ete_annuel(tx, mois, "mean"),
           rr = .climat_ete_annuel(rr, mois, "sum"))
    } else {
      dir.create(travail, recursive = TRUE, showWarnings = FALSE)
      if (source == "chelsa") {
        s <- .climat_series_chelsa(cercle, mois, annees %||% .CLIMAT_ANNEES_CHELSA,
                                   travail, emit)
      } else {
        s <- .climat_series_safran(cercle, mois,
                                   annees %||% 1959:as.integer(format(Sys.Date(), "%Y")),
                                   travail, emit)
      }
      if (is.null(s)) cli::cli_abort("No {source} month could be read.")
      list(tx = .climat_decouper(s$tx, cercle), rr = .climat_decouper(s$rr, cercle))
    }
  }, error = function(e) e)
  if (inherits(res, "error")) {
    return(echec("indisponible", paste0(source, "_acquisition"), conditionMessage(res)))
  }
  if (is.null(res$tx) || is.null(res$rr)) {
    return(echec("donnees_insuffisantes", "no_complete_summer"))
  }
  communes <- intersect(names(res$tx), names(res$rr))
  if (!is.null(annees)) communes <- intersect(communes, as.character(annees))
  if (length(communes) < 2L) return(echec("donnees_insuffisantes", "too_few_years"))
  tx <- res$tx[[communes]]; rr <- res$rr[[communes]]

  meta <- list(status = "ok", reason = NULL, annees = as.integer(communes),
               crs = terra::crs(tx, describe = TRUE)$code)
  if (!is.null(fichiers)) {
    dir.create(dirname(fichiers$tx), recursive = TRUE, showWarnings = FALSE)
    tx <- terra::writeRaster(tx, fichiers$tx, overwrite = TRUE)
    rr <- terra::writeRaster(rr, fichiers$rr, overwrite = TRUE)
    # Le cercle aussi : l'app le relit pour le tracer.
    sf::st_write(cercle_sf, fichiers$cercle, delete_dsn = TRUE, quiet = TRUE)
    meta$fichiers <- fichiers
    .climat_write_meta(c(meta, base_meta), fichiers$meta)
  }
  emit(list(current = "climat:complete", source = source, n_years = length(communes)))
  rendre(tx, rr, meta)
}

# Contour de la France métropolitaine (union des SER INRAE), mis en cache dans
# le cache E-OBS ; NULL si le WFS est injoignable.
.climat_france_contour <- function(dir) {
  f <- file.path(dir, "france_metropole_ser.gpkg")
  if (file.exists(f)) return(sf::st_read(f, quiet = TRUE))
  ser <- .ser_wfs_read(.SAFRAN_BBOX_FRANCE[c(1, 2, 3, 4)], timeout = 120L)
  if (is.null(ser)) return(NULL)
  ser <- ser[ser$codeser != "-1", ]
  fr <- sf::st_sf(geometry = sf::st_union(sf::st_make_valid(ser)))
  fr <- sf::st_transform(sf::st_simplify(fr, dTolerance = 1000), 4326)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  tryCatch(sf::st_write(fr, f, quiet = TRUE), error = function(e) NULL)
  fr
}

# Bornes « France » d'une période : quantiles 1/99 % (étendus à 0) des
# variations totales E-OBS sur la France métropolitaine, mêmes mois et mêmes
# années. Calculées une fois, mises en cache (JSON). NULL si l'agrégat
# mensuel France E-OBS n'est pas en cache (aucun téléchargement ici).
.climat_bornes_france <- function(debut, fin, mois, dir, version) {
  json <- file.path(dir, sprintf("bornes_france_%d_%d_m%s_v%s.json", debut, fin,
                                 paste(mois, collapse = "-"), version))
  if (file.exists(json)) {
    b <- jsonlite::read_json(json, simplifyVector = TRUE)
    return(list(tmax = b$tmax, precip = b$precip, reference = b$reference))
  }
  ftx <- .climat_eobs_mensuel_path("tx", version, dir)
  frr <- .climat_eobs_mensuel_path("rr", version, dir)
  if (!file.exists(ftx) || !file.exists(frr)) return(NULL)
  etx <- .climat_ete_annuel(terra::rast(ftx), mois, "mean")
  err <- .climat_ete_annuel(terra::rast(frr), mois, "sum")
  if (is.null(etx) || is.null(err)) return(NULL)
  dt <- .climat_tendance(etx, debut, fin)
  dp <- .climat_tendance(err, debut, fin)
  contour <- .climat_france_contour(dir)
  reference <- "eobs_france_metropole"
  if (!is.null(contour)) {
    v <- terra::vect(contour)
    dt <- terra::mask(dt, v); dp <- terra::mask(dp, v)
  } else {
    reference <- "eobs_emprise_france"
  }
  b <- list(tmax = .climat_bornes_quantiles(terra::values(dt)[, 1]),
            precip = .climat_bornes_quantiles(terra::values(dp)[, 1]),
            reference = reference)
  if (anyNA(c(b$tmax, b$precip))) return(NULL)
  # Contour absent : bornes non mises en cache (on retentera le contour).
  if (!is.null(contour)) .climat_write_meta(b, json)
  b
}

#' Bivariate summer-trend map on the project circle (L'IF n° 49 method)
#'
#' @description
#' Crosses the **total change over the period** (least-squares slope ×
#' (last year − first year)) of summer maximum temperature (°C) and summer
#' precipitation (mm) into a bivariate classification, at the native resolution
#' of the series from [climat_ete_series()] (spec 063). A cell needs at least
#' 80% valid years. Each axis is clipped to its bounds and cut into `n` classes.
#'
#' Periods: `"complete"` (all the years of the series), `"if49"` (2006-2020,
#' Figure 1 of *L'IF* n° 49) or `c(debut, fin)`.
#'
#' Bounds (`bornes`): `"if49"` (fixed, ΔT ∈ [−0.7, 4] °C, ΔP ∈ [−270, 120] mm,
#' default for `periode = "if49"`); `"france"` (default otherwise: 1% and 99%
#' quantiles, extended to 0, of the E-OBS changes over metropolitan France for
#' the same years and months — the same colours for neighbouring projects and
#' across sources; needs the machine E-OBS monthly cache, falls back to
#' `"emprise"` with `meta$bornes$reason` otherwise); `"emprise"` (same quantiles
#' on the circle, as in the source scripts); or an explicit
#' `list(tmax = c(lo, hi), precip = c(lo, hi))`.
#'
#' The class is `(ct - 1) * n + cp`, `ct` = 1 for the smallest Tmax rise to `n`
#' for the largest, `cp` = 1 for the driest to `n` for the wettest; so
#' "hot & dry" is `(n - 1) * n + 1`. `meta$palette$colors[classe]` gives the
#' colour: the 10 × 10 palette read on the Figure 1 legend (`"if49_10x10"`,
#' needs `n = 10`), or the bilinear interpolation of four corner colours
#' (`"coins"`, any `n`).
#'
#' @param series The result of [climat_ete_series()].
#' @param periode `"complete"`, `"if49"` or `c(debut, fin)`.
#' @param bornes `NULL` (default, see above), `"france"`, `"if49"`, `"emprise"`
#'   or a list of explicit bounds.
#' @param palette `"if49_10x10"` (default) or `"coins"`.
#' @param n Classes per axis (default 10).
#' @param cache_path Optional `.tif` path: the class raster is written there,
#'   the two change layers to `<name>_tendances.tif` and the meta to
#'   `<name>.meta.json` (the app reads them back across a `future` worker).
#' @param eobs_cache_dir Machine-wide E-OBS cache, for `bornes = "france"`.
#' @param version E-OBS version of that cache (default `"33.0e"`).
#'
#' @return `list(raster, tendances, meta)`: `raster` is an integer
#'   `SpatRaster` `classe_bivariee` (1..n²) on the native grid and CRS of the
#'   source; `tendances` a 2-layer `SpatRaster` (`tendance_tmax` in °C,
#'   `tendance_precip` in mm); `meta` holds `status`, `reason`, `periode`
#'   (`c(debut, fin)` actually used), `n_annees`, `bornes` (`tmax`, `precip`,
#'   `mode`, `reference`, `reason`), `palette` (`name`, `classes`, `colors`,
#'   `ncol = n`, `zero = list(tmax, precip)` — the [0, 1] position of the zero
#'   change on each axis, for the dashed 0/0 lines), `unites`, `source`,
#'   `resolution_native`, `crs`, `attribution` and `fichiers`.
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [climat_ete_series()], [climat_nuages_annuels()]
#' @export
climat_tendance_bivariee <- function(series, periode = "complete", bornes = NULL,
                                     palette = c("if49_10x10", "coins"), n = 10L,
                                     cache_path = NULL, eobs_cache_dir = NULL,
                                     version = "33.0e") {
  palette <- match.arg(palette)
  n <- as.integer(n)
  sm <- series$meta %||% list()
  base <- list(source = sm$source, resolution_native = sm$resolution_native,
               crs = sm$crs, attribution = sm$attribution)
  echec <- function(status, reason) list(raster = NULL, tendances = NULL,
                                         meta = c(list(status = status, reason = reason), base))
  if (!identical(sm$status, "ok") || is.null(series$tx) || is.null(series$rr)) {
    return(echec(sm$status %||% "indisponible", sm$reason %||% "series_unavailable"))
  }
  ans <- as.integer(names(series$tx))
  per <- if (identical(periode, "complete")) range(ans) else
    if (identical(periode, "if49")) .CLIMAT_PERIODE_IF49 else {
      if (!is.numeric(periode) || length(periode) != 2L) {
        cli::cli_abort("{.arg periode} must be {.val complete}, {.val if49} or {.code c(debut, fin)}.")
      }
      as.integer(sort(periode))
    }
  k <- ans >= per[1] & ans <= per[2]
  if (sum(k) < 5L) return(echec("donnees_insuffisantes", "fewer_than_5_years_in_period"))
  per_eff <- range(ans[k])

  dt <- .climat_tendance(series$tx, per[1], per[2])
  dp <- .climat_tendance(series$rr, per[1], per[2])
  names(dt) <- "tendance_tmax"; names(dp) <- "tendance_precip"
  vt <- terra::values(dt)[, 1]; vp <- terra::values(dp)[, 1]
  if (!any(is.finite(vt) & is.finite(vp))) return(echec("donnees_insuffisantes", "no_valid_cell"))

  # Bornes.
  mode <- if (is.list(bornes)) "explicite" else
    bornes %||% (if (identical(periode, "if49")) "if49" else "france")
  b <- NULL; reason_b <- NULL; reference <- NULL
  if (identical(mode, "explicite")) {
    b <- bornes; reference <- "utilisateur"
  } else if (identical(mode, "if49")) {
    b <- .CLIMAT_BORNES_IF49; reference <- "if49_figure1"
  } else if (identical(mode, "france")) {
    b <- tryCatch(.climat_bornes_france(per_eff[1], per_eff[2], sm$mois %||% 5:9,
                                        .climat_eobs_dir(eobs_cache_dir), version),
                  error = function(e) NULL)
    if (is.null(b)) {
      mode <- "emprise"; reason_b <- "france_eobs_cache_missing"
    } else reference <- b$reference
  } else if (!identical(mode, "emprise")) {
    cli::cli_abort("Unknown {.arg bornes} {.val {mode}}.")
  }
  if (identical(mode, "emprise")) {
    b <- list(tmax = .climat_bornes_quantiles(vt), precip = .climat_bornes_quantiles(vp))
    reference <- "emprise"
  }

  ct <- .climat_classer(vt, b$tmax[1], b$tmax[2], n)
  cp <- .climat_classer(vp, b$precip[1], b$precip[2], n)
  biv <- terra::rast(dt)
  terra::values(biv) <- (ct - 1L) * n + cp
  names(biv) <- "classe_bivariee"
  tend <- c(dt, dp)
  zero <- list(tmax = (0 - b$tmax[1]) / diff(b$tmax),
               precip = (0 - b$precip[1]) / diff(b$precip))

  meta <- c(list(
    status = "ok", reason = NULL, periode = per_eff, n_annees = sum(k),
    statistique = "variation_totale",
    bornes = list(tmax = b$tmax, precip = b$precip, mode = mode,
                  reference = reference, reason = reason_b),
    palette = list(name = palette, classes = seq_len(n * n),
                   colors = .climat_palette(palette, n), sense = "bivariate",
                   ncol = n, zero = zero),
    unites = list(tmax = "\u00b0C", precip = "mm")), base)

  if (!is.null(cache_path)) {
    racine <- sub("\\.tif$", "", cache_path)
    fichiers <- list(raster = cache_path, tendances = paste0(racine, "_tendances.tif"),
                     meta = paste0(racine, ".meta.json"))
    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    ok <- tryCatch({
      biv <- terra::writeRaster(biv, fichiers$raster, overwrite = TRUE, datatype = "INT2U")
      tend <- terra::writeRaster(tend, fichiers$tendances, overwrite = TRUE)
      TRUE
    }, error = function(e) {
      cli::cli_warn("climat_tendance_bivariee(): cache not written ({conditionMessage(e)}).")
      FALSE
    })
    if (ok) {
      meta$fichiers <- fichiers
      .climat_write_meta(meta, fichiers$meta)
    }
  }
  list(raster = biv, tendances = tend, meta = meta)
}

#' Yearly summer point clouds on the project circle
#'
#' @description
#' Tabular data for the yearly scatter plots of `nuages_bfc_chelsa_safran.R`
#' (spec 063): each cell of the circle is a point, x = precipitation (mm),
#' y = maximum temperature (°C), one cloud per year. The app draws them (an
#' animated year slider and a small-multiples grid replace the GIF/patchwork).
#'
#' Modes: `"anomalie"` — departure of each summer from the mean of the
#' `reference` years (at least 10 of them must be present); `"tendance_cumulee"`
#' — for year *n*, total change (slope × duration) from the first year up to
#' *n*, once there are at least `recul_min` years.
#'
#' @param series The result of [climat_ete_series()].
#' @param mode `"anomalie"` or `"tendance_cumulee"`.
#' @param reference Reference years for the anomalies (default `1981:2010`).
#' @param recul_min Minimum number of years for the cumulative trend (default 10).
#' @param n_points Points sampled per year (default 4000; all cells when fewer).
#' @param seed Random seed of the sampling.
#'
#' @return `list(points, moyennes, limites, meta)`: `points` is a
#'   `data.frame(annee, x, y)`; `moyennes` a `data.frame(annee, x, y)` of the
#'   circle mean of each year (over all cells); `limites` a
#'   `list(x = c(lo, hi), y = c(lo, hi))` shared by every year (0.2% and 99.8%
#'   quantiles extended to 0); `meta` holds `status`, `reason`, `mode`,
#'   `reference`, `annees`, `n_cellules`, `unites`, `source`,
#'   `resolution_native` and `attribution`.
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [climat_ete_series()], [climat_tendance_bivariee()]
#' @export
climat_nuages_annuels <- function(series, mode = c("anomalie", "tendance_cumulee"),
                                  reference = 1981:2010, recul_min = 10L,
                                  n_points = 4000L, seed = 1L) {
  mode <- match.arg(mode)
  sm <- series$meta %||% list()
  base <- list(mode = mode, source = sm$source, resolution_native = sm$resolution_native,
               attribution = sm$attribution, unites = list(x = "mm", y = "\u00b0C"))
  echec <- function(status, reason) list(points = NULL, moyennes = NULL, limites = NULL,
                                         meta = c(list(status = status, reason = reason), base))
  if (!identical(sm$status, "ok") || is.null(series$tx) || is.null(series$rr)) {
    return(echec(sm$status %||% "indisponible", sm$reason %||% "series_unavailable"))
  }
  ans <- as.integer(names(series$tx))
  TX <- terra::values(series$tx, mat = TRUE)
  PR <- terra::values(series$rr, mat = TRUE)
  cellules <- which(rowSums(is.finite(TX)) > 0)
  TX <- TX[cellules, , drop = FALSE]; PR <- PR[cellules, , drop = FALSE]

  if (mode == "anomalie") {
    ref <- which(ans %in% reference)
    if (length(ref) < 10L) return(echec("donnees_insuffisantes", "fewer_than_10_reference_years"))
    VX <- PR - rowMeans(PR[, ref, drop = FALSE], na.rm = TRUE)
    VY <- TX - rowMeans(TX[, ref, drop = FALSE], na.rm = TRUE)
    garde <- seq_along(ans)
  } else {
    garde <- which(ans - ans[1] + 1L >= recul_min)
    if (!length(garde)) return(echec("donnees_insuffisantes", "fewer_years_than_recul_min"))
    pente <- function(M, j) {
      .climat_pente_mat(M[, 1:j, drop = FALSE], ans[1:j], min_frac = 0) * (ans[j] - ans[1])
    }
    VX <- vapply(garde, function(j) pente(PR, j), numeric(nrow(PR)))
    VY <- vapply(garde, function(j) pente(TX, j), numeric(nrow(TX)))
    VX <- matrix(VX, nrow(PR)); VY <- matrix(VY, nrow(TX))
  }
  # Anomalie : une colonne par année ; tendance cumulée : une par année de `garde`.
  col_de <- function(i) if (mode == "anomalie") garde[i] else i

  points <- withr::with_seed(seed, do.call(rbind, lapply(seq_along(garde), function(i) {
    x <- VX[, col_de(i)]; y <- VY[, col_de(i)]
    ok <- which(is.finite(x) & is.finite(y))
    ech <- if (length(ok) > n_points) sample(ok, n_points) else ok
    data.frame(annee = rep(ans[garde[i]], length(ech)), x = x[ech], y = y[ech])
  })))
  moyennes <- do.call(rbind, lapply(seq_along(garde), function(i) {
    x <- VX[, col_de(i)]; y <- VY[, col_de(i)]
    ok <- is.finite(x) & is.finite(y)
    data.frame(annee = ans[garde[i]],
               x = if (any(ok)) mean(x[ok]) else NA_real_,
               y = if (any(ok)) mean(y[ok]) else NA_real_)
  }))
  if (is.null(points) || !nrow(points)) return(echec("donnees_insuffisantes", "no_valid_cell"))
  lim <- function(v) range(stats::quantile(v, c(0.002, 0.998), names = FALSE), 0)
  list(points = points, moyennes = moyennes,
       limites = list(x = lim(points$x), y = lim(points$y)),
       meta = c(list(status = "ok", reason = NULL,
                     reference = if (mode == "anomalie") range(reference) else NULL,
                     recul_min = if (mode == "tendance_cumulee") recul_min else NULL,
                     annees = ans[garde], n_cellules = length(cellules)), base))
}
