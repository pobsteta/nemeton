# ============================================================
# houppiers_lsms.R — crown delineation by Large-Scale Mean-Shift (OTB)
# ------------------------------------------------------------
# Spec 051. An ALTERNATIVE delineation for `segment_houppiers()`, driven by the
# spectral signal of an orthophoto rather than by the shape of the CHM.
#
# The measurements that shape this file (spec 051 §2, on a 200 x 200 m window of
# the Fordead massif, mature high forest closed at 89 %):
#
#   * LSMS costs 160,5 s where the CHM route costs 2,3 s -- about 70x. At
#     4 Mpx, 716 s. On the full 292 Mpx extent that extrapolates to 13-20 h.
#     LSMS IS NOT AN EXTENT ALGORITHM: it is bounded by a compute budget, and
#     refuses beyond it rather than running for hours (D1, D4).
#   * LSMS SEGMENTS AN IMAGE, IT DOES NOT MEASURE A HEIGHT. `h_max` comes from a
#     zonal max on the CHM -- measured, 876 segments out of 886 land inside the
#     1-70 m band Marculus requires. Hence two explicit uses and no silent
#     middle ground (D2): "martelage" REQUIRES the CHM and refuses without it,
#     "couvert" owns up to producing no height at all.
# ============================================================


# --- Coût : le modèle, et ce qu'il vaut ------------------------------------
#
# t = A * (P/1e6)^B * (spatialr/15)^C, P en pixels, t en secondes.
#
# A et B sont calés sur DEUX points (1,0 Mpx -> 160,5 s ; 4,0 Mpx -> 716 s) et
# les reproduisent à la seconde près. C vient de deux points également
# (spatialr 15 -> 178 s, 20 -> 321 s à minsize égal), soit un coût en carré du
# rayon spatial — ce qui est cohérent avec une fenêtre de recherche, mais reste
# une extrapolation à deux points.
#
# Ce n'est PAS une prédiction : les mesures viennent toutes de la fenêtre la
# plus texturée du massif, et le mean-shift converge selon le contenu. C'est un
# MAJORANT, dont on se sert pour refuser un travail manifestement trop long, pas
# pour promettre une durée.
.LSMS_COUT_A <- 160.5
.LSMS_COUT_B <- 1.0787
.LSMS_COUT_C <- 2.04
.LSMS_SPATIALR_REF <- 15

# Défauts calibrés (spec 051 §3.3) contre la voie CHM sur la même fenêtre
# (596 houppiers, 149/ha, diamètre équivalent médian 8,04 m) : ce réglage rend
# 7,88 m, soit -0,15 m — 2 % d'écart. Le compte reste 12 % au-dessus, aucun
# réglage mesuré ne satisfaisant les deux à la fois.
#
# `spatialr = 20` est DOMINÉ : 321 s contre 178 s à `minsize` égal, pour un
# diamètre plus éloigné de la cible. Il n'y a pas d'arbitrage à faire là.
#
# Portée : UNE fenêtre, UN peuplement (futaie mature fermée à 89 %). Un taillis
# dense n'appelle pas le même `spatialr`, comme `ws` côté `lmf`. Point de départ
# documenté, pas valeur validée.
.LSMS_DEFAUTS <- list(spatialr = 15L, ranger = 20, minsize = 700L)


#' Estimate the LSMS compute time for a pixel count
#'
#' Upper-bound estimate used by [segment_houppiers()] to refuse a job that
#' would exceed its compute budget. See spec 051 §3.1 for the model and its
#' limits — it is calibrated on two points, on the most textured stand of the
#' reference massif, and is deliberately pessimistic.
#'
#' @param n_pixels Number of pixels of the image LSMS would segment.
#' @param spatialr Spatial radius passed to LSMS (cost grows roughly with its
#'   square).
#'
#' @return Estimated wall-clock seconds.
#' @export
lsms_duree_estimee <- function(n_pixels, spatialr = .LSMS_DEFAUTS$spatialr) {
  if (!is.numeric(n_pixels) || length(n_pixels) != 1L || !is.finite(n_pixels) ||
      n_pixels < 0) {
    cli::cli_abort("{.arg n_pixels} must be a single non-negative number.")
  }
  if (!is.numeric(spatialr) || length(spatialr) != 1L || !is.finite(spatialr) ||
      spatialr <= 0) {
    cli::cli_abort("{.arg spatialr} must be a single positive number.")
  }
  .LSMS_COUT_A * (n_pixels / 1e6)^.LSMS_COUT_B *
    (spatialr / .LSMS_SPATIALR_REF)^.LSMS_COUT_C
}


#' Pixel budget affordable within a compute budget
#'
#' The inverse of [lsms_duree_estimee()]. Reported to the caller when a job is
#' refused, because the useful answer is not "too big" but "how much fits".
#'
#' @param budget_s Compute budget, in seconds.
#' @param spatialr Spatial radius passed to LSMS.
#'
#' @return Number of pixels affordable within `budget_s`.
#' @export
lsms_budget_pixels <- function(budget_s, spatialr = .LSMS_DEFAUTS$spatialr) {
  if (!is.numeric(budget_s) || length(budget_s) != 1L || !is.finite(budget_s) ||
      budget_s <= 0) {
    cli::cli_abort("{.arg budget_s} must be a single positive number of seconds.")
  }
  ratio <- budget_s / (.LSMS_COUT_A * (spatialr / .LSMS_SPATIALR_REF)^.LSMS_COUT_C)
  1e6 * ratio^(1 / .LSMS_COUT_B)
}


# Racine d'une installation OTB, ou "" si introuvable. Même idiome que la
# détection GRASS (`GRASS_DIR`) : variable d'environnement d'abord, puis
# chemins usuels — OTB s'installe hors gestionnaire de paquets, la variable est
# donc la voie normale et les candidats un confort.
.lsms_otb_dir <- function() {
  d <- Sys.getenv("OTB_DIR", unset = "")
  if (nzchar(d) && file.exists(file.path(d, "otbenv.profile"))) return(d)
  candidats <- c(
    Sys.glob(file.path(path.expand("~"), "OTB-*-Linux")),
    "/opt/otb", "/usr/local/otb", "/usr/lib/otb"
  )
  for (p in candidats) {
    if (file.exists(file.path(p, "otbenv.profile"))) return(p)
  }
  ""
}


# Lance `otbcli_LargeScaleMeanShift`.
#
# Le lanceur d'OTB source `otbenv.profile` avec `source`, un mot-clé bash, alors
# que son shebang est `#!/bin/sh` : appelé tel quel il échoue sur
# « source: not found » puis « Could not find application ». L'environnement
# doit donc être posé PAR L'APPELANT — d'où l'invocation via `bash -c` avec un
# sourcing explicite.
#
# La sortie est écrite en SHAPEFILE : `-mode.vector.out` en `.gpkg` échoue sur
# OTB 9.1.1 (« Unable to commit transaction for OGR layer »), constat repris du
# brief du 2026-08-24 et non re-testé ici.
.lsms_executer <- function(image_path, sortie_shp, spatialr, ranger, minsize,
                           otb_dir = .lsms_otb_dir()) {
  profile <- file.path(otb_dir, "otbenv.profile")
  cli <- file.path(otb_dir, "bin", "otbcli_LargeScaleMeanShift")
  cmd <- paste(
    shQuote(cli),
    "-in", shQuote(image_path),
    "-spatialr", format(as.integer(spatialr)),
    "-ranger", format(ranger),
    "-minsize", format(as.integer(minsize)),
    "-mode.vector.out", shQuote(sortie_shp)
  )
  code <- system2("bash", c("-c", shQuote(paste(". ", shQuote(profile), "&&", cmd))),
                  stdout = FALSE, stderr = FALSE)
  if (!identical(as.integer(code), 0L) || !file.exists(sortie_shp)) {
    cli::cli_abort(c(
      "OTB {.code LargeScaleMeanShift} failed (exit {code}).",
      i = "Command: {.code {cmd}}",
      i = "Run it by hand after {.code . {profile}} to see its diagnostics."
    ))
  }
  invisible(sortie_shp)
}


# Le corps de l'algorithme "lsms". Appelé par segment_houppiers() une fois les
# arguments validés ; reçoit l'AOI déjà interprétée.
.houppier_lsms <- function(chm, image, aoi_sel, aoi_v, usage, lsms,
                           resolution_image, budget_s, h_range) {
  otb_dir <- .lsms_otb_dir()
  if (!nzchar(otb_dir)) {
    cli::cli_abort(c(
      "Orfeo ToolBox is required for {.code algorithme = \"lsms\"} and was not found.",
      i = "Set {.envvar OTB_DIR} to an OTB installation (the directory holding {.file otbenv.profile}),",
      i = "or use {.code algorithme = \"dalponte\"}, which needs no external tool."
    ))
  }

  if (is.character(image)) {
    if (!file.exists(image)) cli::cli_abort("Image not found: {.path {image}}.")
    image <- terra::rast(image)
  }
  if (!inherits(image, "SpatRaster")) {
    cli::cli_abort("{.arg image} must be a {.cls SpatRaster} or a path to one.")
  }
  image <- .normalize_crs(image)
  if (isTRUE(terra::is.lonlat(image))) {
    cli::cli_abort(c(
      "The {.arg image} is in a geographic CRS (degrees).",
      i = "{.arg minsize} counts pixels and the budget assumes metres — reproject first."
    ))
  }

  if (!is.null(aoi_v)) {
    if (!terra::relate(terra::ext(image), terra::ext(aoi_v), "intersects")) {
      cli::cli_abort("The {.arg aoi} does not intersect the {.arg image}.")
    }
    image <- terra::crop(image, terra::project(aoi_v, terra::crs(image)))
  }

  # Rééchantillonnage : le SEUL levier d'ordre de grandeur sur le coût. Passer
  # de 0,20 à 0,50 m fait passer le budget de 10 min de 13,6 ha à 84,9 ha (x6),
  # au prix du détail spectral qui justifie LSMS. Exposé, jamais imposé.
  if (!is.null(resolution_image)) {
    res_in <- mean(terra::res(image))
    if (resolution_image > res_in) {
      fac <- max(1L, as.integer(round(resolution_image / res_in)))
      if (fac > 1L) image <- terra::aggregate(image, fact = fac, fun = "mean",
                                              na.rm = TRUE)
    }
  }

  # Garde-fou de budget (D4). Il refuse AVANT d'appeler OTB, et il dit combien
  # tient dans le budget plutôt que « trop grand ».
  n_px <- terra::ncell(image)
  est  <- lsms_duree_estimee(n_px, lsms$spatialr)
  if (is.finite(budget_s) && budget_s > 0 && est > budget_s) {
    tenable <- lsms_budget_pixels(budget_s, lsms$spatialr)
    res_m   <- mean(terra::res(image))
    cli::cli_abort(c(
      "The LSMS job is estimated at {round(est)} s, over the {round(budget_s)} s budget.",
      i = "Image: {n_px} pixels at {round(res_m, 2)} m ({round(n_px * res_m^2 / 1e4, 1)} ha).",
      i = "Budget affords ~{round(tenable)} pixels ({round(tenable * res_m^2 / 1e4, 1)} ha at this resolution).",
      i = "Either shrink the {.arg aoi}, or raise {.arg resolution_image} — coarsening 0.20 m to 0.50 m buys ~6x the area.",
      i = "Raise {.arg budget_s} to accept the wait. The estimate is an upper bound (spec 051 section 3.1)."
    ))
  }

  tmp <- withr::local_tempdir()
  img_path <- file.path(tmp, "lsms_in.tif")
  terra::writeRaster(image, img_path, overwrite = TRUE)
  shp <- file.path(tmp, "lsms_out.shp")
  .lsms_executer(img_path, shp, lsms$spatialr, lsms$ranger, lsms$minsize, otb_dir)

  segs <- sf::st_read(shp, quiet = TRUE)
  if (nrow(segs) == 0L) return(.houppier_empty_lsms(image, usage))
  # OTB écrit un `.prj` depuis le raster, mais un CRS dégénéré à l'entrée en
  # ressort dégénéré : on ré-estampille depuis l'image, qui est passée par
  # `.normalize_crs()`.
  sf::st_crs(segs) <- sf::st_crs(terra::crs(image))
  segs <- segs[!sf::st_is_empty(sf::st_geometry(segs)), , drop = FALSE]
  if (nrow(segs) == 0L) return(.houppier_empty_lsms(image, usage))

  if (identical(usage, "martelage")) {
    # LSMS délimite ; la hauteur vient du CHM par zonale — la mécanique que le
    # cœur applique déjà à l'étape 4 de la voie CHM.
    h <- terra::extract(chm, terra::vect(sf::st_transform(segs, terra::crs(chm))),
                        fun = max, na.rm = TRUE)[, 2L]
    segs$h_max <- as.numeric(h)
    keep <- !is.na(segs$h_max) &
      segs$h_max >= h_range[1] & segs$h_max <= h_range[2]
    segs <- segs[keep, , drop = FALSE]
    if (nrow(segs) == 0L) return(.houppier_empty_lsms(image, usage))
  }

  if (!is.null(aoi_sel)) {
    segs <- sf::st_filter(segs, sf::st_union(sf::st_geometry(
      sf::st_transform(aoi_sel, sf::st_crs(segs)))), .predicate = sf::st_intersects)
    if (nrow(segs) == 0L) return(.houppier_empty_lsms(image, usage))
  }

  if (identical(usage, "martelage")) {
    segs <- segs[order(-segs$h_max), , drop = FALSE]
    out <- sf::st_sf(
      houppier_id = seq_len(nrow(segs)),
      h_max       = as.numeric(segs$h_max),
      surface_m2  = as.numeric(sf::st_area(segs)),
      geometry    = sf::st_geometry(segs)
    )
  } else {
    # `usage = "couvert"` : AUCUNE colonne `h_max`. Absente, pas `NA` — pour
    # qu'aucun consommateur ne la lise comme une mesure manquante, et que le
    # GeoPackage n'arrive pas chez Marculus en promettant une hauteur qu'il
    # ignorerait en silence.
    segs <- segs[order(-as.numeric(sf::st_area(segs))), , drop = FALSE]
    out <- sf::st_sf(
      houppier_id = seq_len(nrow(segs)),
      surface_m2  = as.numeric(sf::st_area(segs)),
      geometry    = sf::st_geometry(segs)
    )
  }
  sf::st_agr(out) <- "constant"
  out
}


# Zéro segment : mêmes colonnes que le cas nominal de l'usage demandé.
.houppier_empty_lsms <- function(image, usage) {
  geom <- sf::st_sfc(crs = sf::st_crs(terra::crs(image)))
  if (identical(usage, "martelage")) {
    sf::st_sf(houppier_id = integer(0), h_max = numeric(0),
              surface_m2 = numeric(0), geometry = geom)
  } else {
    sf::st_sf(houppier_id = integer(0), surface_m2 = numeric(0), geometry = geom)
  }
}
