# eobs_click_series.R — accesseurs point pour les graphiques au clic de la carte
# « Contexte régional (E-OBS) » (onglet reGénération). Spec 036.
# ------------------------------------------------------------------
# La carte affiche UNE couleur par maille (la pente estivale). Ces accesseurs
# rendent la donnée SOUS la couleur, à la maille cliquée :
#   - eobs_summer_series()      : série estivale annuelle (graphes 1-3) ;
#   - eobs_monthly_climatology(): climatologie mensuelle P/T (graphe 4,
#                                 diagramme ombrothermique) ;
#   - eobs_trend_fit()          : pente/décennie + R²/p (cohérence carte<->graphe).
# Chemin PUR (extraction terra au point) : aucune acquisition, testable offline.

# Unité d'affichage par variable E-OBS (pour l'axe des graphes).
.eobs_var_unit <- function(var) {
  switch(var, tx = , tg = "°C", rr = "mm",
         cli::cli_abort("Unknown E-OBS {.arg var} {.val {var}}; use \"tx\", \"tg\" or \"rr\"."))
}

# Point utilisateur -> SpatVector dans le CRS du raster. Accepte un sf/sfc POINT
# ou un couple numérique c(lon, lat) en EPSG:4326 (le clic leaflet).
.eobs_point_vect <- function(point, crs) {
  if (inherits(point, c("sf", "sfc"))) {
    g <- sf::st_geometry(point)
    if (length(g) != 1L) {
      cli::cli_abort("{.arg point} must be a single POINT, got {length(g)} geometries.")
    }
    terra::vect(sf::st_transform(g, sf::st_crs(crs)))
  } else {
    if (!is.numeric(point) || length(point) != 2L || any(!is.finite(point))) {
      cli::cli_abort("{.arg point} must be an {.cls sf}/{.cls sfc} POINT or {.code c(lon, lat)}.")
    }
    pt <- terra::vect(matrix(as.numeric(point), ncol = 2), type = "points",
                      crs = "EPSG:4326")
    # E-OBS est livré en EPSG:4326, comme le clic leaflet : reprojeter revient
    # alors à demander à PROJ une opération 4326 -> 4326 pour rien. On ne
    # projette que si les CRS diffèrent réellement.
    if (is.na(crs) || !nzchar(crs) || identical(terra::crs(pt), crs)) return(pt)
    terra::project(pt, crs)
  }
}

# Extraction d'une série au point sur toutes les couches (NA-safe).
.eobs_extract_point <- function(r, point) {
  pv <- .eobs_point_vect(point, terra::crs(r))
  ex <- terra::extract(r, pv, ID = FALSE)
  as.numeric(ex[1, ])
}

#' Summer E-OBS series at a point (year -> value)
#'
#' @description
#' Extract the per-year summer (JJA) E-OBS value at a location, feeding charts 1-3
#' of the regional-context click panel (spec 036): annual series + trend line,
#' annual anomalies, and regional distribution. Reduction and acquisition already
#' live in [load_eobs_source()]; this only extracts the per-year stack at `point`,
#' so the app can pass an already-loaded stack and answer every click without
#' re-reducing the daily netCDF.
#'
#' @param stack A per-year summer `SpatRaster` (one layer per year, named by year),
#'   as returned by [load_eobs_source()].
#' @param point An `sf`/`sfc` POINT, or `c(lon, lat)` in EPSG:4326 (the leaflet
#'   click).
#'
#' @return A `data.frame(year, value)`, one row per layer ordered by year,
#'   NA-safe (a masked/out-of-extent point yields `NA` values). Attributes:
#'   `var`, `unit`. `var` is read from the stack's `varnames` when present.
#' @seealso [eobs_monthly_climatology()], [eobs_trend_fit()], [load_eobs_source()]
#' @examples
#' \dontrun{
#' stk <- load_eobs_source(aoi, var = "tx", nc = "eobs_tx.nc", source = "nc")
#' eobs_summer_series(stk, c(6.1, 48.7))
#' }
#' @export
eobs_summer_series <- function(stack, point) {
  if (!inherits(stack, "SpatRaster")) {
    cli::cli_abort("{.arg stack} must be a per-year summer {.cls SpatRaster}.")
  }
  n <- terra::nlyr(stack)
  # Année : les noms de couche (« 2011 », …) posés par load_eobs_source() ;
  # repli sur terra::time si les noms ne sont pas des années.
  yr <- suppressWarnings(as.integer(names(stack)))
  if (anyNA(yr)) {
    tt <- terra::time(stack)
    if (length(tt) == n && !all(is.na(tt))) {
      yr <- as.integer(format(as.Date(tt), "%Y"))
    }
  }
  if (anyNA(yr)) yr <- seq_len(n)   # dernier repli : index de couche
  vals <- .eobs_extract_point(stack, point)
  ord <- order(yr)
  out <- data.frame(year = yr[ord], value = vals[ord])
  var <- tryCatch(terra::varnames(stack)[1], error = function(e) NA_character_)
  attr(out, "var")  <- if (length(var) && !is.na(var) && nzchar(var)) var else NA_character_
  attr(out, "unit") <- NA_character_
  out
}

#' Monthly E-OBS climatology at a point (month -> value)
#'
#' @description
#' Twelve-month climatology (averaged over `years`) of an E-OBS variable at a
#' location, for the ombrothermic (Gaussen-Bagnouls) diagram — chart 4 of the
#' regional-context click panel (spec 036). Precipitation is summed within each
#' month then averaged across years (mm/month); temperature is the monthly mean
#' (°C). Reads the full-year daily field (a `SpatRaster` with `terra::time` set,
#' or a cached netCDF path), so tx/rr need no new acquisition; the Gaussen diagram
#' proper wants mean temperature (`tg`), which has its own netCDF (spec 036 §5.4).
#'
#' @param daily A daily E-OBS `SpatRaster` (full year, `terra::time` set), or a
#'   path to the cached daily netCDF.
#' @param point An `sf`/`sfc` POINT, or `c(lon, lat)` in EPSG:4326.
#' @param var `"rr"` (monthly precipitation sum, mm) or `"tg"`/`"tx"` (monthly
#'   mean temperature, °C). Drives the within-month reducer.
#' @param years Optional integer years to average over (default: all present).
#'
#' @return A `data.frame(month = 1:12, value)` (all twelve months, `NA` where a
#'   month has no data). Attributes: `var`, `unit`, `reducer`.
#' @seealso [eobs_summer_series()], [load_eobs_source()]
#' @examples
#' \dontrun{
#' eobs_monthly_climatology("eobs_tg_daily.nc", c(6.1, 48.7), var = "tg")
#' }
#' @export
eobs_monthly_climatology <- function(daily, point, var, years = NULL) {
  if (is.character(daily)) {
    if (!file.exists(daily)) {
      cli::cli_abort("{.arg daily} netCDF not found: {.path {daily}}.")
    }
    daily <- terra::rast(daily)
  }
  if (!inherits(daily, "SpatRaster")) {
    cli::cli_abort("{.arg daily} must be a daily {.cls SpatRaster} or a netCDF path.")
  }
  reducer <- .eobs_var_spec(var)$reducer      # "mean" (tx/tg) | "sum" (rr)
  tt <- terra::time(daily)
  if (length(tt) == 0L || all(is.na(tt))) {
    cli::cli_abort(c(
      "E-OBS raster carries no {.fun terra::time}; cannot group by month.",
      i = "Read the daily E-OBS netCDF so layers keep their dates."))
  }
  dates <- as.Date(tt)
  mo <- as.integer(format(dates, "%m"))
  yr <- as.integer(format(dates, "%Y"))
  vals <- .eobs_extract_point(daily, point)
  keep <- is.finite(vals)
  if (!is.null(years)) keep <- keep & (yr %in% as.integer(years))
  vals <- vals[keep]; mo <- mo[keep]; yr <- yr[keep]
  month_value <- function(m) {
    sel <- mo == m
    if (!any(sel)) return(NA_real_)
    if (identical(reducer, "sum")) {
      # Précip : cumul MENSUEL par année, puis moyenne inter-annuelle (mm/mois).
      mean(tapply(vals[sel], yr[sel], sum), na.rm = TRUE)
    } else {
      # Température : moyenne des valeurs journalières du mois sur toutes les années.
      mean(vals[sel])
    }
  }
  out <- data.frame(month = 1:12,
                    value = vapply(1:12, month_value, numeric(1)))
  attr(out, "var")     <- var
  attr(out, "unit")    <- .eobs_var_unit(var)
  attr(out, "reducer") <- reducer
  out
}

#' Linear trend of an E-OBS summer series (per decade)
#'
#' @description
#' Fit the least-squares trend of a per-year summer series (the output of
#' [eobs_summer_series()]) and return the per-decade slope with its goodness of
#' fit, for the trend line of chart 1 (spec 036). The slope is `10 *` the
#' per-year OLS slope, matching the mapped per-decade slope
#' (`tendances_estivales_eobs()` / `eobs_downscale()`), so the click chart and the
#' map colour agree by construction.
#'
#' @param series A `data.frame` with numeric columns `year` and `value` (as
#'   returned by [eobs_summer_series()]).
#'
#' @return A `list(slope_decade, intercept, r2, p_value, n)`. All `NA` (with
#'   `n` the count of finite pairs) when fewer than two finite points are
#'   available.
#' @seealso [eobs_summer_series()]
#' @examples
#' eobs_trend_fit(data.frame(year = 2011:2020, value = 20 + (0:9) * 0.1))
#' @export
eobs_trend_fit <- function(series) {
  if (!is.data.frame(series) ||
      !all(c("year", "value") %in% names(series))) {
    cli::cli_abort("{.arg series} must be a data.frame with columns {.field year} and {.field value}.")
  }
  x <- as.numeric(series$year); y <- as.numeric(series$value)
  ok <- is.finite(x) & is.finite(y)
  n <- sum(ok)
  na_out <- list(slope_decade = NA_real_, intercept = NA_real_, r2 = NA_real_,
                 p_value = NA_real_, n = n)
  if (n < 2L || length(unique(x[ok])) < 2L) return(na_out)
  fit <- stats::lm(y ~ x, data = data.frame(x = x[ok], y = y[ok]))
  co <- stats::coef(fit)
  # summary.lm avertit sur un ajustement quasi parfait (r2 ~ 1) : bénin ici.
  sm <- suppressWarnings(summary(fit))
  # p-value du terme de pente (repli NA si le modèle est dégénéré).
  pv <- tryCatch(stats::coef(sm)["x", "Pr(>|t|)"], error = function(e) NA_real_)
  list(slope_decade = unname(co[["x"]]) * 10,
       intercept    = unname(co[["(Intercept)"]]),
       r2           = sm$r.squared,
       p_value      = as.numeric(pv),
       n            = n)
}
