# soil_water.R — réserve utile (ewm) par UGF, spec 035.
# ------------------------------------------------------------------
# Deux briques :
#   * awc_saxton_rawls()      — fonction de pédotransfert, R pur, testable.
#   * ewm_depuis_soilgrids()  — ewm (mm) par UGF, intégrée sur la profondeur
#                               d'enracinement, depuis les VRT SoilGrids 250 m.
#
# Le TWI n'entre PAS ici : c'est un indice topographique de convergence
# latérale, pas une capacité de stockage, et il alimente déjà R3 en direct
# (double comptage). Décision D1 de la spec 035.

# Intervalles de profondeur standard SoilGrids (FAQ ISRIC).
SOILGRIDS_DEPTHS <- data.frame(
  interval  = c("0-5", "5-15", "15-30", "30-60", "60-100", "100-200"),
  top_cm    = c(0, 5, 15, 30, 60, 100),
  bottom_cm = c(5, 15, 30, 60, 100, 200),
  stringsAsFactors = FALSE
)

# Facteurs d'échelle SoilGrids : valeur_brute / facteur = unité conventionnelle.
# Vérifiés dans la FAQ ISRIC (docs.isric.org), NON présumés. `soc` est en
# dg/kg : brut/10 = g/kg, donc %OC = brut/100 (piège d'un facteur 10).
SOILGRIDS_SCALE <- c(clay = 10, sand = 10, silt = 10, soc = 10,
                     cfvo = 10, bdod = 100, cec = 10)

# Facteur de van Bemmelen : matière organique (%) = carbone organique (%) x 1.724
.OM_FROM_OC <- 1.724


#' Available water capacity from soil texture — Saxton & Rawls (2006)
#'
#' @description
#' Pedotransfer function giving the **available water capacity** (AWC) of a soil
#' horizon from its texture and organic-matter content: the difference between
#' water content at field capacity (-33 kPa) and at the permanent wilting point
#' (-1500 kPa). Feeds [ewm_depuis_soilgrids()], which integrates it over the
#' rooting depth to produce the `ewm` of [biljouR::biljou_soil()].
#'
#' Closed-form equations of Saxton & Rawls (2006), Table 1:
#' \deqn{\theta_{1500t} = -0.024 S + 0.487 C + 0.006 OM + 0.005 (S \cdot OM)
#'   - 0.013 (C \cdot OM) + 0.068 (S \cdot C) + 0.031}
#' \deqn{\theta_{1500} = \theta_{1500t} + (0.14\, \theta_{1500t} - 0.02)}
#' \deqn{\theta_{33t} = -0.251 S + 0.195 C + 0.011 OM + 0.006 (S \cdot OM)
#'   - 0.027 (C \cdot OM) + 0.452 (S \cdot C) + 0.299}
#' \deqn{\theta_{33} = \theta_{33t} + (1.283\, \theta_{33t}^2
#'   - 0.374\, \theta_{33t} - 0.015)}
#'
#' Several online transcriptions give `-0.002` instead of `-0.02`, and `-0.15`
#' instead of `-0.015`. Those variants yield a **negative** field capacity for
#' sand and a negative AWC across every USDA texture class; they are wrong. The
#' constants above reproduce the NRCS reference values (see
#' `tests/testthat/test-soil-water.R`).
#'
#' When `coarse` is supplied, the fine-earth AWC is scaled to bulk soil by
#' `(1 - coarse / 100)`: stones store no plant-available water.
#'
#' This is a published pedotransfer function, not a calibration of this project.
#' It is exported so that a pedologist can audit it. NA in, NA out.
#'
#' @param clay,sand Numeric vectors, clay and sand content as **fractions**
#'   (0-1). Silt is implicit (`1 - clay - sand`).
#' @param om Numeric vector, organic-matter content in **percent** by mass.
#'   Derive from organic carbon with `om = oc_percent * 1.724`.
#' @param coarse Optional numeric vector of coarse-fragment content in **volume
#'   percent** (0-100). Default `NULL` (no correction, fine-earth AWC).
#' @return Numeric vector of available water capacity in m3/m3, clamped to
#'   `[0, 1]`.
#' @references
#' Saxton K.E., Rawls W.J. (2006). Soil Water Characteristic Estimates by
#' Texture and Organic Matter for Hydrologic Solutions. *Soil Science Society of
#' America Journal* 70:1569-1578.
#' @seealso [ewm_depuis_soilgrids()]
#' @export
#' @examples
#' # Limon (loam) : AWC ~ 0.14 m3/m3
#' awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 2.5)
#'
#' # Le meme sol avec 30 % de cailloux
#' awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 2.5, coarse = 30)
awc_saxton_rawls <- function(clay, sand, om, coarse = NULL) {
  n <- max(length(clay), length(sand), length(om))
  clay <- rep(as.numeric(clay), length.out = n)
  sand <- rep(as.numeric(sand), length.out = n)
  om   <- rep(as.numeric(om), length.out = n)

  if (any(clay > 1 | sand > 1, na.rm = TRUE)) {
    cli::cli_abort(c(
      "{.arg clay} and {.arg sand} must be fractions in {.val [0, 1]}, not percentages.",
      i = "Divide by 100 (or by 1000 for raw SoilGrids g/kg values)."))
  }

  # Point de fletrissement permanent (-1500 kPa).
  t1500 <- -0.024 * sand + 0.487 * clay + 0.006 * om +
    0.005 * (sand * om) - 0.013 * (clay * om) + 0.068 * (sand * clay) + 0.031
  wp <- t1500 + (0.14 * t1500 - 0.02)

  # Capacite au champ (-33 kPa).
  t33 <- -0.251 * sand + 0.195 * clay + 0.011 * om +
    0.006 * (sand * om) - 0.027 * (clay * om) + 0.452 * (sand * clay) + 0.299
  fc <- t33 + (1.283 * t33^2 - 0.374 * t33 - 0.015)

  awc <- fc - wp

  # Correction elements grossiers : la terre fine seule retient l'eau.
  if (!is.null(coarse)) {
    coarse <- rep(as.numeric(coarse), length.out = n)
    if (any(coarse > 100, na.rm = TRUE)) {
      cli::cli_abort("{.arg coarse} must be a volume percentage in {.val [0, 100]}.")
    }
    awc <- awc * (1 - pmin(pmax(coarse, 0), 100) / 100)
  }

  pmin(pmax(awc, 0), 1)
}


# Charge une propriete SoilGrids a un intervalle de profondeur, recadree sur
# l'AOI, et renvoie la moyenne par UGF en unite CONVENTIONNELLE (facteur
# d'echelle applique). NULL si la couche est indisponible (best-effort).
.sg_property_by_unit <- function(units, property, interval, country = "FR") {
  key <- paste0("soilgrids_", property, "_", interval)
  r <- tryCatch(load_raster_source(key, country = country, aoi = units),
                error = function(e) NULL)
  if (is.null(r)) return(NULL)
  v <- tryCatch(
    safe_extract(r, as_pure_sf(units), fun = "mean", progress = FALSE),
    error = function(e) NULL)
  if (is.null(v)) return(NULL)
  scale <- SOILGRIDS_SCALE[[property]]
  as.numeric(v) / scale
}


#' Maximum extractable water (`ewm`) per unit, from SoilGrids
#'
#' @description
#' Per-unit **maximum extractable water** (`ewm`, mm) — the plant-available water
#' reservoir that drives the whole BILJOU water balance, since
#' `rew = sw / ewm_total` and stress starts below `rew_c = 0.4`.
#'
#' Built from SoilGrids 250 m (ISRIC): for each standard depth interval within
#' `rooting_depth_cm`, the available water capacity is estimated by the
#' [awc_saxton_rawls()] pedotransfer function from clay, sand and organic
#' carbon, corrected for coarse fragments, then integrated over the horizon
#' thickness:
#'
#' \deqn{ewm = \sum_{layers} AWC_i \times thickness_i \times 10}
#'
#' (the factor 10 converts cm of horizon x m3/m3 into mm of water).
#'
#' The topographic wetness index is deliberately **not** used here: it measures
#' lateral convergence, not storage capacity, and it already feeds
#' [indicateur_r3_secheresse()] directly (spec 035, decision D1).
#'
#' @param units An `sf` of management units.
#' @param rooting_depth_cm Rooting depth in cm (default 100). Depth intervals are
#'   truncated at this value; an interval starting below it is skipped.
#' @param country ISO country code for the datasource lookup. Default `"FR"`.
#' @param depths Optional character vector of SoilGrids depth intervals to use
#'   (default: all those within `rooting_depth_cm`, see [SOILGRIDS_DEPTHS]).
#' @param progress_callback Optional function called with
#'   `list(current = "ewm:layer", interval = , i = , n = )` per depth interval,
#'   and `list(current = "ewm:complete")` at the end (monitoring pattern).
#'
#' @return Numeric vector of `ewm` in mm, length `nrow(units)`. `NA` for a unit
#'   whose soil data could not be resolved. `NULL` if **no** depth interval could
#'   be loaded at all (graceful degradation — the caller falls back to a uniform
#'   `ewm`).
#' @references
#' Poggio L. et al. (2021). SoilGrids 2.0. *SOIL* 7:217-240.
#' @seealso [awc_saxton_rawls()], [build_biljou_soil()]
#' @export
ewm_depuis_soilgrids <- function(units, rooting_depth_cm = 100,
                                 country = "FR", depths = NULL,
                                 progress_callback = NULL) {
  validate_sf(units)
  emit <- function(payload) {
    if (!is.null(progress_callback))
      tryCatch(progress_callback(payload), error = function(e) invisible(NULL))
  }
  if (!is.numeric(rooting_depth_cm) || length(rooting_depth_cm) != 1L ||
      is.na(rooting_depth_cm) || rooting_depth_cm <= 0) {
    cli::cli_abort("{.arg rooting_depth_cm} must be a single positive number.")
  }

  d <- SOILGRIDS_DEPTHS
  if (!is.null(depths)) {
    unknown <- setdiff(depths, d$interval)
    if (length(unknown)) {
      cli::cli_abort("Unknown SoilGrids depth interval{?s}: {.val {unknown}}.")
    }
    d <- d[d$interval %in% depths, , drop = FALSE]
  }
  # Horizons entierement sous la profondeur d'enracinement : ecartes.
  d <- d[d$top_cm < rooting_depth_cm, , drop = FALSE]
  if (!nrow(d)) {
    cli::cli_abort("No SoilGrids depth interval lies within {.arg rooting_depth_cm}.")
  }
  # Le dernier horizon est tronque a la profondeur d'enracinement.
  d$bottom_cm <- pmin(d$bottom_cm, rooting_depth_cm)
  d$thickness_cm <- d$bottom_cm - d$top_cm

  n <- nrow(units)
  ewm <- rep(0, n)
  any_layer <- FALSE

  for (i in seq_len(nrow(d))) {
    itv <- d$interval[i]
    emit(list(current = "ewm:layer", interval = itv, i = i, n = nrow(d)))

    clay <- .sg_property_by_unit(units, "clay", itv, country)  # %
    sand <- .sg_property_by_unit(units, "sand", itv, country)  # %
    soc  <- .sg_property_by_unit(units, "soc",  itv, country)  # g/kg
    cfvo <- .sg_property_by_unit(units, "cfvo", itv, country)  # vol %

    if (is.null(clay) || is.null(sand)) next
    any_layer <- TRUE

    # SoilGrids -> unites de la PTF : texture en fractions, OM en % massique.
    # soc est en g/kg apres mise a l'echelle -> %OC = soc / 10.
    om <- if (is.null(soc)) 0 else (soc / 10) * .OM_FROM_OC

    awc <- awc_saxton_rawls(clay = clay / 100, sand = sand / 100,
                            om = om, coarse = cfvo)
    # cm d'horizon x m3/m3 -> mm d'eau
    ewm <- ewm + awc * d$thickness_cm[i] * 10
  }

  if (!any_layer) {
    emit(list(current = "ewm:unavailable"))
    return(NULL)
  }
  emit(list(current = "ewm:complete", n_layers = nrow(d)))
  ewm[!is.finite(ewm)] <- NA_real_
  ewm
}
