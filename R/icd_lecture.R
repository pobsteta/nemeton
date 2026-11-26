# ICD : lecture des resultats sur disque et comparaison avec FAST (spec 071).

#' Read an ICD result raster
#'
#' Reads one layer of the yearly ICD result written by
#' [run_icd_decoloration()], for the map of the app. Pixels without ICD (outside
#' the four pure stands, or outside the UGF zone) are `NA`; the counts are
#' attached so the app can say how many and why.
#'
#' @param zone_id Integer. Monitoring zone.
#' @param annee Integer. Year.
#' @param result_dir Character. Root of the ICD results, as given to
#'   [run_icd_decoloration()].
#' @param layer One of `"niveau"` (0 normal to 4 repeated alert), `"classe"`
#'   (0 normal, 1 watch, 2 alert), `"icd_min"`, `"mois_alerte"`,
#'   `"n_mois_valides"`.
#' @param a_date Logical. Read the "to date" set (every year on the months
#'   already available this year) instead of the full season.
#' @return A one-layer [terra::SpatRaster], with attributes `annee`,
#'   `a_date`, `provisoire` (the year under way), `n_pixels_zone`,
#'   `n_pixels_icd`, `n_pixels_sans_icd`; `NULL` when the year has not been
#'   computed.
#' @seealso [run_icd_decoloration()], [read_icd_pixel_series()].
#' @export
read_icd_raster <- function(zone_id, annee, result_dir,
                            layer = c("niveau", "classe", "icd_min",
                                      "mois_alerte", "n_mois_valides"),
                            a_date = FALSE) {
  layer <- match.arg(layer)
  zdir <- .icd_dossier_zone(result_dir, zone_id)
  f <- file.path(zdir, if (isTRUE(a_date)) "annuel_a_date" else "annuel",
                 sprintf("%04d.tif", as.integer(annee)))
  if (!file.exists(f)) return(NULL)
  r <- terra::rast(f)[[layer]]
  meta <- .icd_lire_meta(zdir)
  attr(r, "annee") <- as.integer(annee)
  attr(r, "a_date") <- isTRUE(a_date)
  attr(r, "provisoire") <- meta$annee_provisoire %||% NA_integer_
  for (k in c("n_pixels_zone", "n_pixels_icd", "n_pixels_sans_icd")) {
    attr(r, k) <- meta[[k]] %||% NA_integer_
  }
  r
}

#' Series of one pixel for the ICD charts
#'
#' For a point (the click on the map), reads from the rasters already computed
#' by [run_icd_decoloration()] (no network, local reads): per year and month the
#' raw value and the anomaly `z` of the five indices, the ICD, the sensitive
#' months of the species group, the weights used, the thresholds, and the
#' class and level of each year.
#'
#' @param zone_id Integer. Monitoring zone.
#' @param xy Numeric length 2, `c(x, y)` (east, north) in `crs`.
#' @param crs CRS of `xy` (default 4326: longitude, latitude).
#' @param result_dir Character. Root of the ICD results.
#' @param a_date Logical. Read the "to date" annual set.
#' @return `NULL` when the zone has no result or the point is outside the
#'   grid. Otherwise a list: `essence` (`NA` for a pixel without ICD, with
#'   `motif`), `serie` (long `data.frame`: `annee`, `mois`, `indice`, `brut`,
#'   `z`), `icd` (`annee`, `mois`, `icd`, `sensible`), `annuel` (`annee`,
#'   `classe`, `niveau`, `icd_min`, `mois_alerte`, `date_alerte`,
#'   `provisoire`), `poids` (weights used for the species group, rescaled to
#'   1), `indices_actifs`, `mois_sensibles`, `seuils` and `annee_provisoire`.
#' @seealso [run_icd_decoloration()], [read_icd_raster()].
#' @export
read_icd_pixel_series <- function(zone_id, xy, crs = 4326, result_dir,
                                  a_date = FALSE) {
  if (!is.numeric(xy) || length(xy) != 2L || anyNA(xy)) {
    cli::cli_abort("{.arg xy} must be a length-2 numeric, no NA.")
  }
  zdir <- .icd_dossier_zone(result_dir, zone_id)
  fe <- file.path(zdir, "essence.tif")
  meta <- .icd_lire_meta(zdir)
  if (!file.exists(fe) || is.null(meta)) return(NULL)
  ess <- terra::rast(fe)
  pt <- sf::st_transform(sf::st_sfc(sf::st_point(as.numeric(xy)), crs = crs),
                         terra::crs(ess))
  cell <- terra::cellFromXY(ess, sf::st_coordinates(pt))
  if (is.na(cell)) return(NULL)
  code <- terra::values(ess, mat = FALSE)[cell]
  essence <- if (is.na(code)) NA_character_ else .ICD_ESSENCES[code]

  annees <- as.integer(meta$annees)
  lire <- function(dossier, a, m) {
    f <- file.path(zdir, dossier, sprintf("%04d-%02d.tif", a, m))
    if (!file.exists(f)) return(NULL)
    unlist(terra::values(terra::rast(f), mat = TRUE)[cell, ], use.names = TRUE)
  }
  lignes <- list(); icd <- list()
  for (a in annees) for (m in .ICD_MOIS_SAISON) {
    brut <- lire("composites", a, m)
    z <- lire("z", a, m)
    v <- lire("icd", a, m)
    if (is.null(brut) && is.null(z)) next
    lignes[[length(lignes) + 1L]] <- data.frame(
      annee = a, mois = m, indice = .ICD_INDICES,
      brut = if (is.null(brut)) NA_real_ else unname(brut[.ICD_INDICES]),
      z = if (is.null(z)) NA_real_ else unname(z[.ICD_INDICES]),
      stringsAsFactors = FALSE)
    icd[[length(icd) + 1L]] <- data.frame(
      annee = a, mois = m, icd = if (is.null(v)) NA_real_ else unname(v[1L]),
      sensible = !is.na(essence) && m %in% .ICD_MOIS[[essence]],
      stringsAsFactors = FALSE)
  }
  bind <- function(l, vide) if (length(l)) do.call(rbind, l) else vide
  serie <- bind(lignes, data.frame(annee = integer(0), mois = integer(0),
                                   indice = character(0), brut = numeric(0), z = numeric(0)))
  icd <- bind(icd, data.frame(annee = integer(0), mois = integer(0),
                              icd = numeric(0), sensible = logical(0)))
  dossier_an <- if (isTRUE(a_date)) "annuel_a_date" else "annuel"
  annuel <- lapply(annees, function(a) {
    f <- file.path(zdir, dossier_an, sprintf("%04d.tif", a))
    if (!file.exists(f)) return(NULL)
    v <- terra::values(terra::rast(f), mat = TRUE)[cell, ]
    mo <- unname(v["mois_alerte"])
    data.frame(annee = a, classe = unname(v["classe"]), niveau = unname(v["niveau"]),
               icd_min = unname(v["icd_min"]), mois_alerte = mo,
               date_alerte = if (is.na(mo)) as.Date(NA)
                             else as.Date(sprintf("%04d-%02d-01", a, as.integer(mo))),
               provisoire = identical(a, as.integer(meta$annee_provisoire)),
               stringsAsFactors = FALSE)
  })
  annuel <- bind(Filter(Negate(is.null), annuel), NULL)

  poids <- NULL; actifs <- character(0)
  if (!is.na(essence)) {
    pw <- as.data.frame(meta$poids)
    w <- unlist(pw[pw$essence == essence, .ICD_INDICES])
    poids <- w; actifs <- names(w)[w > 0]
  }
  list(essence = essence,
       motif = if (is.na(essence)) "hors des quatre peuplements purs (chene, hetre, sapin/epicea, douglas)" else NA_character_,
       serie = serie, icd = icd, annuel = annuel, poids = poids,
       indices_actifs = actifs,
       mois_sensibles = if (is.na(essence)) integer(0) else .ICD_MOIS[[essence]],
       seuils = c(surveillance = .ICD_SEUIL_SURVEILLANCE, alerte = .ICD_SEUIL_ALERTE,
                  alerte_forte = .ICD_SEUIL_FORTE),
       annee_provisoire = as.integer(meta$annee_provisoire))
}

#' Compare FAST and the ICD on a zone and a year
#'
#' Crosses the FAST classes (0 to 4: 0 no alert, 1 to 4 the quartiles of the
#' positive scores) with the ICD levels (0 to 4) over the pixels that have both,
#' in surface (a 20 m pixel = 0.04 ha), and gives the overall agreement and
#' Cohen's kappa. Kappa is an indicator, not a validation: both methods have
#' their own errors. A second comparison is made at **equal alerted surface**
#' (the criterion of the FAST-versus-discoloration study, mission 045): the ICD
#' alert is level >= 2, and FAST is called alert on the same share of pixels,
#' those with the highest scores.
#'
#' @param zone_id Integer. Monitoring zone.
#' @param annee Integer. Year.
#' @param result_dir Character. Root of the ICD results.
#' @param fast A `SpatRaster` of the continuous FAST score (the `"count"`
#'   alert raster of [read_fast_alert_raster()]). When `NULL`, it is read with
#'   `read_fast_alert_raster()` from `con` and `cache_dir` over April to
#'   October of `annee`.
#' @param con,cache_dir Used only when `fast` is `NULL`.
#' @param a_date Logical. Use the "to date" ICD set.
#' @param pixel_ha Pixel surface in hectares (20 m: 0.04).
#' @return A list: `statut` (`"ok"`, `"fast_absent"`, `"icd_absent"`,
#'   `"sans_pixel_commun"`), `annee`, `n_pixels`, `croisement` (`fast`,
#'   `icd`, `n_pixels`, `surface_ha`), `accord_global`, `kappa`,
#'   `surface_egale` (`part_alertee`, `n_alertes`, `accord`, `kappa`, and the
#'   hectares `les_deux`, `fast_seul`, `icd_seul`, `aucune`).
#' @seealso [run_icd_decoloration()], [read_fast_alert_raster()].
#' @export
comparer_fast_icd <- function(zone_id, annee, result_dir, fast = NULL,
                              con = NULL, cache_dir = NULL, a_date = FALSE,
                              pixel_ha = 0.04) {
  vide <- function(statut) list(statut = statut, annee = as.integer(annee),
                                n_pixels = 0L, croisement = NULL,
                                accord_global = NA_real_, kappa = NA_real_,
                                surface_egale = NULL)
  niv <- read_icd_raster(zone_id, annee, result_dir, "niveau", a_date)
  if (is.null(niv)) return(vide("icd_absent"))
  if (is.null(fast)) {
    if (is.null(con) || is.null(cache_dir)) return(vide("fast_absent"))
    fast <- tryCatch(
      read_fast_alert_raster(con, zone_id, index = "NDVI", mode = "count",
                             date_from = sprintf("%d-04-01", as.integer(annee)),
                             date_to = sprintf("%d-10-31", as.integer(annee)),
                             cache_dir = cache_dir),
      error = function(e) NULL)
    if (is.null(fast)) return(vide("fast_absent"))
  }
  # FAST (10 m) -> grille ICD de 20 m : moyenne du score, comme l'etude.
  fast <- fast[[1L]]
  if (all(abs(terra::res(fast) * 2 - terra::res(niv)) < 1e-6)) {
    fast <- terra::aggregate(fast, fact = 2, fun = "mean", na.rm = TRUE)
  }
  if (!terra::compareGeom(fast, niv, stopOnError = FALSE)) {
    fast <- terra::resample(terra::project(fast, terra::crs(niv)), niv,
                            method = "bilinear")
  }
  sc <- terra::values(fast, mat = FALSE)
  nv <- terra::values(niv, mat = FALSE)
  ok <- !is.na(sc) & !is.na(nv)
  if (!any(ok)) return(vide("sans_pixel_commun"))
  sc <- sc[ok]; nv <- nv[ok]
  cl <- .icd_classes_fast(sc)
  tab <- as.data.frame(table(fast = factor(cl, 0:4), icd = factor(nv, 0:4)),
                       responseName = "n_pixels", stringsAsFactors = FALSE)
  tab$fast <- as.integer(tab$fast); tab$icd <- as.integer(tab$icd)
  tab$surface_ha <- tab$n_pixels * pixel_ha

  # A surface alertee egale : les k pixels de plus haut score (egalites
  # departagees par l'ordre), k = part du niveau ICD >= 2.
  alerte_icd <- nv >= 2
  k <- ceiling(mean(alerte_icd) * length(sc))
  alerte_fast <- rep(FALSE, length(sc))
  if (k > 0) alerte_fast[order(-sc, seq_along(sc))[seq_len(k)]] <- TRUE
  ha <- function(x) sum(x) * pixel_ha
  list(statut = "ok", annee = as.integer(annee), n_pixels = length(sc),
       croisement = tab,
       accord_global = mean(cl == nv),
       kappa = .icd_kappa(cl, nv),
       surface_egale = list(
         part_alertee = mean(alerte_icd), n_alertes = as.integer(k),
         accord = mean(alerte_fast == alerte_icd),
         kappa = .icd_kappa(as.integer(alerte_fast), as.integer(alerte_icd)),
         les_deux = ha(alerte_fast & alerte_icd),
         fast_seul = ha(alerte_fast & !alerte_icd),
         icd_seul = ha(!alerte_fast & alerte_icd),
         aucune = ha(!alerte_fast & !alerte_icd)))
}
