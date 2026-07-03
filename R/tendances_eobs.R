# tendances_eobs.R — branche A reGénération : tendances estivales E-OBS (spec 027 §6)
# ------------------------------------------------------------------
# Contexte régional de la carte bivariée « L'IF n°49 » (IGN), RECADRÉ sur
# l'emprise des UGF + un buffer (décision §10.4, défaut 25 km) — PAS national.
# Le cœur calcule, par maille E-OBS de l'emprise, la TENDANCE estivale (pente
# linéaire ~ année) de la T°max et des précipitations, puis une CLASSIFICATION
# BIVARIÉE (réchauffement × assèchement). L'app (nemetonshiny) rend la carte.
#
# E-OBS (NetCDF tx/rr, licence recherche non commerciale) est une donnée
# externe : la fonction offre un chemin `precomputed` pur, calcule depuis des
# SpatRaster par-année (logique terra testable), ou échoue proprement.

# Pente linéaire par maille (closed-form, NA-safe), pour terra::app.
.eobs_slope <- function(v, x) {
  ok <- is.finite(v) & is.finite(x)
  if (sum(ok) < 2L) return(NA_real_)
  xx <- x[ok]; yy <- v[ok]
  mx <- mean(xx); denom <- sum((xx - mx)^2)
  if (denom == 0) return(NA_real_)
  sum((xx - mx) * (yy - mean(yy))) / denom
}

# Classe 1-3 par tertiles (ou bornes fixes `br`). NA -> NA.
.eobs_class3 <- function(v, br = NULL) {
  if (is.null(br)) {
    q <- stats::quantile(v, c(1/3, 2/3), na.rm = TRUE, names = FALSE)
    br <- unname(q)
  }
  # Bornes dégénérées (peu de variance) -> tout en classe médiane.
  if (length(unique(br)) < 2L || any(!is.finite(br))) {
    return(ifelse(is.na(v), NA_integer_, 2L))
  }
  as.integer(cut(v, c(-Inf, br[1], br[2], Inf), labels = FALSE))
}

# Emprise UGF + buffer, exprimée dans le CRS `crs_out`. Buffer métrique via
# EPSG:3035 (LAEA paneuropéen, ADR-008) pour un rayon en mètres correct.
.eobs_aoi_buffer <- function(aoi, buffer_m, crs_out) {
  g <- sf::st_union(sf::st_geometry(aoi))
  gm <- sf::st_transform(g, 3035)
  buf <- sf::st_buffer(gm, buffer_m)
  sf::st_transform(buf, crs_out)
}

# sf de points (centres de maille) trends -> classes bivariées + crop AOI+buffer.
.eobs_finalise <- function(pts, aoi_buf, breaks) {
  keep <- lengths(sf::st_intersects(pts, aoi_buf)) > 0
  pts <- pts[keep, , drop = FALSE]
  brt <- if (is.list(breaks)) breaks$tmax else NULL
  brp <- if (is.list(breaks)) breaks$precip else NULL
  pts$classe_tmax   <- .eobs_class3(pts$trend_tmax, brt)     # 3 = plus chaud
  pts$classe_precip <- .eobs_class3(pts$trend_precip, brp)   # 3 = plus humide
  # Bivariée 1-9 : (chaud-1)*3 + précip. « chaud & sec » = classe_tmax 3 & precip 1.
  pts$classe_bivariee <- (pts$classe_tmax - 1L) * 3L + pts$classe_precip
  pts
}


#' Summer E-OBS climate trends over the project area (spec 027 §6, branch A)
#'
#' @description
#' Per-cell **summer trend** of maximum temperature and precipitation from the
#' **E-OBS** grid, over the **union of the units plus a buffer** (decision
#' §10.4, default 25 km — *not* national), with a **bivariate classification**
#' (warming × drying) for the reGénération context map (spec 027 branch A). The
#' core computes the trends and classes; the app renders the bivariate map.
#'
#' Trends are the least-squares slope of the per-year summer values against the
#' year. Classes are tertiles by default (data-driven over the cropped area),
#' or fixed `breaks`. `classe_bivariee` runs 1-9 with
#' `(classe_tmax - 1) * 3 + classe_precip`; "hot & dry" is
#' `classe_tmax == 3 & classe_precip == 1`.
#'
#' **Data path & degradation**: E-OBS NetCDF is external (research, non
#' commercial). Supply `tx` / `rr` as per-year summer `SpatRaster`s (one layer
#' per year) to compute the trends, or a `precomputed` result (an `sf` of cells
#' with `trend_tmax`/`trend_precip`, or a 2-layer trend `SpatRaster`) to only
#' crop + classify. With neither, the function fails cleanly.
#'
#' @param aoi An `sf`/`sfc` of the management units (their union is buffered).
#' @param tx Per-year summer maximum-temperature `SpatRaster` (one layer per
#'   year). Engine path.
#' @param rr Per-year summer precipitation `SpatRaster` (one layer per year).
#' @param years Optional numeric years matching the raster layers (default
#'   `seq_len(nlyr)`).
#' @param buffer_m Numeric buffer radius in metres around the units. Default
#'   `25000` (§10.4).
#' @param breaks Optional `list(tmax=, precip=)` of two cut points each for a
#'   fixed classification; `NULL` → tertiles.
#' @param precomputed Optional pre-built trends: an `sf` with `trend_tmax` /
#'   `trend_precip`, or a 2-layer `SpatRaster` named `trend_tmax`/`trend_precip`.
#' @param ... Reserved.
#'
#' @return An `sf` of E-OBS cell-centre points within the buffered area, with
#'   `trend_tmax`, `trend_precip`, `classe_tmax`, `classe_precip` (1-3) and
#'   `classe_bivariee` (1-9).
#' @seealso [indice_priorite_regen()]
#' @export
tendances_estivales_eobs <- function(aoi, tx = NULL, rr = NULL, years = NULL,
                                     buffer_m = 25000, breaks = NULL,
                                     precomputed = NULL, ...) {
  if (!inherits(aoi, c("sf", "sfc"))) {
    stop("aoi must be an sf or sfc object", call. = FALSE)
  }

  # --- precomputed: crop + classify only ---
  if (!is.null(precomputed)) {
    if (inherits(precomputed, "SpatRaster")) {
      if (!all(c("trend_tmax", "trend_precip") %in% names(precomputed))) {
        stop("precomputed SpatRaster must have layers 'trend_tmax' and 'trend_precip'",
             call. = FALSE)
      }
      df <- terra::as.data.frame(precomputed, xy = TRUE, na.rm = FALSE)
      pts <- sf::st_as_sf(df, coords = c("x", "y"), crs = terra::crs(precomputed))
    } else if (inherits(precomputed, "sf")) {
      if (!all(c("trend_tmax", "trend_precip") %in% names(precomputed))) {
        stop("precomputed sf must have columns 'trend_tmax' and 'trend_precip'",
             call. = FALSE)
      }
      pts <- precomputed
    } else {
      stop("precomputed must be an sf or a SpatRaster", call. = FALSE)
    }
    aoi_buf <- .eobs_aoi_buffer(aoi, buffer_m, sf::st_crs(pts))
    return(.eobs_finalise(pts, aoi_buf, breaks))
  }

  # --- engine path: compute trends from per-year summer rasters ---
  if (is.null(tx) || is.null(rr)) {
    cli::cli_abort(c(
      "tendances_estivales_eobs(): E-OBS data required.",
      i = "Supply per-year summer {.arg tx}/{.arg rr} SpatRasters, or a {.arg precomputed} trend result."
    ))
  }
  if (!inherits(tx, "SpatRaster") || !inherits(rr, "SpatRaster")) {
    stop("tx and rr must be terra SpatRasters (one layer per year)", call. = FALSE)
  }
  if (is.null(years)) years <- seq_len(terra::nlyr(tx))
  if (length(years) != terra::nlyr(tx) || terra::nlyr(tx) != terra::nlyr(rr)) {
    stop("years, tx and rr must all describe the same number of years",
         call. = FALSE)
  }

  aoi_buf <- .eobs_aoi_buffer(aoi, buffer_m, terra::crs(tx))
  box <- terra::vect(aoi_buf)
  tx <- terra::crop(tx, box, snap = "out")
  rr <- terra::crop(rr, box, snap = "out")

  tt <- terra::app(tx, function(v) .eobs_slope(v, years))
  tp <- terra::app(rr, function(v) .eobs_slope(v, years))
  names(tt) <- "trend_tmax"; names(tp) <- "trend_precip"

  df <- terra::as.data.frame(c(tt, tp), xy = TRUE, na.rm = FALSE)
  pts <- sf::st_as_sf(df, coords = c("x", "y"), crs = terra::crs(tx))
  .eobs_finalise(pts, aoi_buf, breaks)
}
