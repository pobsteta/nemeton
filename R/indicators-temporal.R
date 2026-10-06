# indicators-temporal.R
# Temporal Dynamics Family (T) Indicators
# MVP v0.3.0 - Multi-Family Indicator Extension
# Aligned with tuto 04 methodology (BD Forêt TFV age estimation)

#' @importFrom stats median weighted.mean
#' @keywords internal
NULL

# ==============================================================================
# T038: T1 - Stand Age Index
# ==============================================================================

#' Calculate Stand Age Index (T1)
#'
#' Estimates stand age per unit, a measured age taking precedence over an
#' estimate: direct age field, then establishment year, then BD Forêt TFV
#' (Type de Formation Végétale, area-weighted, tuto 04 methodology), then an
#' NDVI proxy. Each source only fills the units left \code{NA} by the
#' previous ones.
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object (optional). Used to resolve bdforet.
#' @param bdforet An sf object with BD Forêt V2 polygons. If NULL and layers
#'   provided, resolved from layers.
#' @param age_field Character. Column name with stand age (years). Default "age".
#'   A measured age takes precedence over every estimate.
#' @param establishment_year_field Character. Column name with establishment year.
#'   Used for units with no measured age.
#' @param current_year Integer. Current year for age calculation from establishment year.
#'   Default uses current system year.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{T1}: estimated age in years -- NOT a
#' 0-100 score. **Higher = older = more favourable**, so it is not
#' inverted; normalize_indicator() rescales it against a ref_max of 200
#' years, beyond which ancientness counts as maximal. Until 0.196.0 it was
#' wrongly declared natively 0-100 and merely clamped, so 150 and 250 years
#' both came out at 100. See spec 048 section 10.
#'   \code{NA} for a unit no source can date (no default age).
#'
#' @details
#' **Order of precedence** (per unit): measured age, establishment year,
#' BD Forêt TFV, NDVI proxy.
#'
#' **BD Forêt TFV method**:
#' \itemize{
#'   \item Spatial intersection of parcels with BD Forêt polygons
#'   \item Age estimated from vegetation type (TFV field):
#'     - Forêt fermée feuillus / Futaie feuillus: 100 years
#'     - Forêt fermée conifères / Futaie conifères: 80 years
#'     - Forêt ouverte / Taillis: 45 years
#'     - Peupleraie: 20 years
#'     - Jeune peuplement / Lande boisée: 15 years
#'     - Other: not recognised, left out (no default age)
#'   \item Area-weighted average across overlapping polygons with a
#'     recognised TFV
#' }
#'
#' @family temporal-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' layers <- massif_demo_layers()
#'
#' # Primary method: BD Forêt
#' result <- indicateur_t1_anciennete(massif_demo_units, layers = layers)
#' summary(result$T1)
#'
#' # Direct age field
#' units <- massif_demo_units
#' units$age <- runif(nrow(units), 20, 250)
#' result <- indicateur_t1_anciennete(units, age_field = "age")
#' }
indicateur_t1_anciennete <- function(units,
                                   layers = NULL,
                                   bdforet = NULL,
                                   age_field = "age",
                                   establishment_year_field = NULL,
                                   current_year = NULL) {
  # Validate inputs
  validate_sf(units)
  n <- nrow(units)

  # Cascade PAR UNITE : une mesure (age, annee d'installation) passe avant
  # une estimation (TFV de la BD Foret, puis NDVI) ; chaque source ne comble
  # que les unites restees NA. Auparavant, la seule presence d'une BD Foret
  # faisait ignorer un age mesure, et un TFV non reconnu valait 50 ans.
  age_values <- rep(NA_real_, n)
  a_combler <- function() is.na(age_values)

  # --- 1. Age mesure ---
  if (!is.null(age_field) && age_field %in% names(units)) {
    age_values <- suppressWarnings(as.numeric(units[[age_field]]))
  }

  # --- 2. Annee d'installation ---
  if (any(a_combler()) && !is.null(establishment_year_field) &&
      establishment_year_field %in% names(units)) {
    if (is.null(current_year)) {
      current_year <- as.integer(format(Sys.Date(), "%Y"))
    }
    depuis_annee <- current_year -
      suppressWarnings(as.numeric(units[[establishment_year_field]]))
    k <- a_combler()
    age_values[k] <- depuis_annee[k]
  }

  # --- 3. BD Foret TFV (tuto 04), moyenne ponderee par la surface ---
  if (any(a_combler())) {
    if (is.null(bdforet) && !is.null(layers) && inherits(layers, "nemeton_layers")) {
      bdforet <- resolve_vector_layer(layers, "bdforet")
    }
    if (!is.null(bdforet) && inherits(bdforet, "sf") && nrow(bdforet) > 0) {
      if (!identical(sf::st_crs(bdforet), sf::st_crs(units))) {
        bdforet <- sf::st_transform(bdforet, sf::st_crs(units))
      }
      tfv_field <- NULL
      for (field in c("TFV", "tfv", "CODE_TFV", "code_tfv", "ESSENCE", "essence",
                      "LIB_FV", "lib_fv", "LIBELLE", "libelle")) {
        if (field %in% names(bdforet)) {
          tfv_field <- field
          break
        }
      }
      if (!is.null(tfv_field)) {
        cli::cli_alert_info("T1: Using BD For\u00eat field '{tfv_field}' for age estimation")
        for (i in which(a_combler())) {
          inter <- suppressWarnings(
            tryCatch(sf::st_intersection(bdforet, units[i, ]),
                     error = function(e) NULL)
          )
          if (is.null(inter) || nrow(inter) == 0) next
          aire <- as.numeric(sf::st_area(inter))
          age_est <- .estimate_age_tfv(inter[[tfv_field]])
          # Seule la surface dont le TFV est reconnu entre dans la moyenne :
          # un TFV inconnu n'est pas « 50 ans ».
          ok <- !is.na(age_est) & is.finite(aire) & aire > 0
          if (any(ok)) {
            age_values[i] <- sum(aire[ok] * age_est[ok]) / sum(aire[ok])
          }
        }
      }
    }
  }

  # --- 4. Proxy NDVI ---
  if (any(a_combler())) {
    ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
    if (!is.null(ndvi_raster)) {
      cli::cli_alert_info("T1: Estimating maturity from NDVI where no age data")
      ndvi_mean <- safe_extract(ndvi_raster,
        as_pure_sf(units), fun = "mean", progress = FALSE)
      # NDVI 0.2 ~ young (20yr), NDVI 0.8 ~ mature (120yr)
      depuis_ndvi <- 20 + pmax(0, ndvi_mean - 0.2) / 0.6 * 100
      k <- a_combler()
      age_values[k] <- depuis_ndvi[k]
    }
  }

  if (all(is.na(age_values))) {
    cli::cli_alert_warning("T1: No age data available, returning NA")
  } else {
    msg_info("indicateur_t1_anciennete")
  }
  .indicateur_resultat(units, "T1", age_values)
}


#' Estimate age from BD Forêt TFV (vegetation type) field
#'
#' @param tfv Character vector of TFV values.
#' @return Numeric vector of estimated ages in years; NA for an
#'   unrecognised TFV.
#' @noRd
.estimate_age_tfv <- function(tfv) {
  tfv_lower <- tolower(as.character(tfv))
  ifelse(grepl("ferm.*feuill|futaie.*feuill", tfv_lower), 100,
    ifelse(grepl("ferm.*conif|futaie.*conif", tfv_lower), 80,
      ifelse(grepl("ouvert|taillis", tfv_lower), 45,
        ifelse(grepl("peupler", tfv_lower), 20,
          ifelse(grepl("jeune|lande.*bois", tfv_lower), 15, NA_real_)
        )
      )
    )
  )
}


# ==============================================================================
# T039: T2 - Stability / Change Rate Index
# ==============================================================================

#' Calculate Temporal Stability Proxy (T2)
#'
#' Despite its name (\code{changement}), T2 does **not** measure a rate of
#' change: no time series is read. It is a temporal **stability proxy**
#' derived from other indicators -- a copy of N2 (forest continuity) when
#' present, otherwise the T1 stand age capped at 100 -- following tuto 04.
#' It therefore carries no information of its own, and in the T family it
#' may duplicate T1.
#'
#' @param units An sf object with forest parcels. May contain pre-computed
#'   columns: N2 (forest continuity) or T1 (stand age).
#' @param layers A nemeton_layers object (optional). Not directly used but
#'   kept for interface consistency.
#' @param t1_values Numeric vector. Pre-computed T1 age values (same length
#'   as nrow(units)). If NULL and units has no T1 column, T2 is \code{NA}.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{T2}: stability proxy scores (0-100), 100 = very
#'   stable (ancient forest). \code{NA} where the source (N2 or T1) is
#'   unknown -- no default value.
#'
#' @details
#' **Primary method**: copy of the N2 (forest continuity/antiquity) column if
#' present in units, clamped to 0-100.
#'
#' **Fallback**: T1 stand age (years) capped at 100 (\code{t1_values}, then a
#' \code{T1} column). Older forests are assumed more stable.
#'
#' The fallback applies **unit by unit**: a unit whose N2 is \code{NA} takes
#' its T1 age when known.
#'
#' A genuine change-rate indicator (e.g. a Sentinel-2 change detection) is
#' not implemented in T2.
#'
#' @family temporal-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units[1:10, ]
#'
#' # Compute T1 first, then T2: the T1 column of the result feeds T2
#' t1 <- indicateur_t1_anciennete(units, layers = massif_demo_layers())
#' t2 <- indicateur_t2_changement(t1)
#' t2$T2
#' }
indicateur_t2_changement <- function(units,
                                      layers = NULL,
                                      t1_values = NULL) {
  # Validate inputs
  validate_sf(units)

  n <- nrow(units)

  # Sources candidates, par ordre de priorité. Le repli se fait UNITÉ PAR
  # UNITÉ : une colonne N2 présente mais NA sur une unité ne la condamne plus
  # à NA quand son T1 est connu (avant 0.212.1, la colonne N2 était prise
  # entière dès qu'elle existait, NA compris ; l'app devait écarter une N2
  # toute NA pour retomber sur T1, et le cas mixte restait perdu).
  sources <- list()

  # --- Priorité 1 : N2 (continuité / ancienneté forestière) ---
  n2_col <- NULL
  for (col in c("N2_anciennete", "N2_anciennet", "N2")) {
    if (col %in% names(units)) {
      n2_col <- col
      break
    }
  }
  if (!is.null(n2_col)) {
    sources[[n2_col]] <- pmin(pmax(as.numeric(units[[n2_col]]), 0), 100)
  }

  # --- Priorité 2 : âge T1 plafonné à 100, argument puis colonne ---
  # Âge inconnu -> NA : pas de stabilité « moyenne » inventée.
  if (!is.null(t1_values) && is.numeric(t1_values) && length(t1_values) == n) {
    sources[["T1 age values"]] <- pmin(100, t1_values)
  }
  if ("T1" %in% names(units)) {
    sources[["T1 column"]] <- pmin(100, as.numeric(units$T1))
  }

  # --- Aucune source : NA (plus de 50 par défaut) ---
  if (length(sources) == 0L) {
    cli::cli_alert_warning("T2: No N2 or T1 data available, returning NA")
    return(.indicateur_resultat(units, "T2", rep(NA_real_, n)))
  }

  t2 <- rep(NA_real_, n)
  used <- character(0)
  for (nm in names(sources)) {
    fill <- is.na(t2) & !is.na(sources[[nm]])
    if (any(fill)) {
      t2[fill] <- sources[[nm]][fill]
      used <- c(used, sprintf("%s (%d)", nm, sum(fill)))
    }
  }
  if (length(used) == 0L) {
    cli::cli_alert_warning(
      "T2: {paste(names(sources), collapse = ', ')} present but all NA, returning NA"
    )
  } else {
    cli::cli_alert_info("T2: stability proxy from {paste(used, collapse = ', ')}")
    msg_info("indicateur_t2_changement")
  }
  .indicateur_resultat(units, "T2", t2)
}


# ==============================================================================
# T3 - Clear-cut pressure (SUFOSAT)  [spec 030]
# ==============================================================================

#' Calculate Clear-cut Pressure Index (T3)
#'
#' Recency-weighted fraction of a forest unit affected by clear-cuts,
#' derived from the SUFOSAT national product (CNES/CESBIO; Sentinel-1 radar
#' change detection, submonthly, mainland France). High = more recent
#' clear-cutting. This is a \dQuote{high = bad} indicator (like R5 dieback):
#' its normalized radar value is inverted downstream (see `normalization.R`).
#'
#' SUFOSAT rasters (spec 030, band metadata confirmed on the live Theia MTD
#' STAC 2026-07-02):
#' \itemize{
#'   \item `sufosat_dates`: clear-cut date per pixel, encoded `YYDDD` (YY =
#'     year 18-25 -> 2018-2025, DDD = day of year 1-366). `0` = no clear-cut
#'     (nodata).
#'   \item `sufosat_proba`: clear-cut probability in percent (0-100). `0` =
#'     nodata. SUFOSAT publishes detections at >= ~85\%.
#' }
#'
#' The score is coverage-fraction weighted, so equal-area pixels cancel and
#' no cell-area computation is needed: it is the share of the unit footprint
#' under clear-cut within the recency window, weighted linearly by recency.
#'
#' @param units An sf object with forest units.
#' @param sufosat_dates A terra SpatRaster of clear-cut dates (`YYDDD`).
#'   `NULL` (default) -> the indicator is not applicable and `NA` is returned
#'   for every unit (source-conditional, like R5 without FORDEAD).
#' @param sufosat_proba A terra SpatRaster of clear-cut probability (percent).
#'   `NULL` -> no probability filter is applied.
#' @param window_years Integer. Length of the recency window in years.
#'   Default `5`. Clear-cuts older than `reference_year - window_years + 1`
#'   are ignored.
#' @param min_proba Numeric in [0, 1]. Minimum clear-cut probability to count
#'   a pixel, compared against `sufosat_proba / 100`. Default `0.9`.
#' @param reference_year Integer or `NULL`. Most-recent year of the recency
#'   window (weight 1). `NULL` (default) -> derived from the most recent
#'   clear-cut year found across the extracted units.
#'
#'   **Pass a calendar year when scores must be comparable.** With `NULL` the
#'   window is anchored on the *data*, not on the calendar: a massif whose last
#'   clear-cut dates from 2021 is scored over 2017-2021, so a 2018 cut still
#'   counts as "recent", and two projects with different last-cut years are not
#'   comparable at the same `window_years`. Anchoring on the current year —
#'   `reference_year = as.integer(format(Sys.Date(), "%Y"))` — makes
#'   "the last N years" mean exactly that.
#'
#' @return The input \code{units} (same class, rows and order) with an added numeric column \code{T3}, one value per unit: recency-weighted percentage of
#'   the unit footprint under clear-cut within the window (0-100, high = more
#'   clear-cutting). `NA` where `sufosat_dates` is `NULL` or the unit does not
#'   overlap the raster.
#'
#' @export
indicateur_t3_coupes_rases <- function(units,
                                       sufosat_dates  = NULL,
                                       sufosat_proba  = NULL,
                                       window_years   = 5L,
                                       min_proba      = 0.9,
                                       reference_year = NULL) {
  validate_sf(units)
  n <- nrow(units)
  if (n == 0L) return(.indicateur_resultat(units, "T3", numeric(0)))

  # Source-conditional: no dates raster -> indicator not applicable.
  if (is.null(sufosat_dates)) {
    cli::cli_alert_info("T3: no SUFOSAT dates raster supplied - returning NA (indicator skipped).")
    return(.indicateur_resultat(units, "T3", rep(NA_real_, n)))
  }
  if (!inherits(sufosat_dates, "SpatRaster")) {
    cli::cli_abort("{.arg sufosat_dates} must be a terra SpatRaster.")
  }
  if (!is.numeric(window_years) || length(window_years) != 1L || window_years < 1) {
    cli::cli_abort("{.arg window_years} must be a positive scalar.")
  }
  if (!is.numeric(min_proba) || length(min_proba) != 1L ||
      min_proba < 0 || min_proba > 1) {
    cli::cli_abort("{.arg min_proba} must be a scalar in [0, 1].")
  }
  if (!requireNamespace("exactextractr", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg exactextractr} is required for T3.")
  }

  # Build a 2-layer stack (dates + optional proba) so a single extraction
  # returns aligned pixel values and coverage fractions per unit.
  layers <- sufosat_dates[[1]]
  names(layers) <- "dates"
  has_proba <- !is.null(sufosat_proba)
  if (has_proba) {
    if (!inherits(sufosat_proba, "SpatRaster")) {
      cli::cli_abort("{.arg sufosat_proba} must be a terra SpatRaster.")
    }
    proba <- sufosat_proba[[1]]
    names(proba) <- "proba"
    layers <- c(layers, proba)
  }

  units_proj <- sf::st_transform(as_pure_sf(units), terra::crs(layers))
  ex <- exactextractr::exact_extract(layers, units_proj, progress = FALSE)

  # A single-layer extraction names its column "value" (not "dates"); a
  # multi-layer one uses the layer names. Normalise so `df$dates` always
  # resolves regardless of whether a proba layer was stacked.
  ex <- lapply(ex, function(df) {
    if (!"dates" %in% names(df) && "value" %in% names(df)) {
      names(df)[names(df) == "value"] <- "dates"
    }
    df
  })

  # Decode YYDDD -> calendar year.
  decode_year <- function(v) 2000L + (as.integer(v) %/% 1000L)

  # Resolve the reference year (window upper bound, weight 1) when not
  # supplied: the most recent clear-cut year across all extracted pixels.
  if (is.null(reference_year)) {
    yrs <- unlist(lapply(ex, function(df) {
      d <- df$dates
      d <- d[!is.na(d) & d > 0]
      if (!length(d)) return(integer(0))
      decode_year(d)
    }), use.names = FALSE)
    reference_year <- if (length(yrs)) max(yrs) else NA_integer_
  }

  # No clear-cut anywhere: pressure is 0 for units overlapping the raster,
  # NA for units that fall entirely outside it.
  if (is.na(reference_year)) {
    return(.indicateur_resultat(units, "T3", vapply(ex, function(df) {
      cov <- df$coverage_fraction
      if (!length(cov) || sum(cov, na.rm = TRUE) == 0) NA_real_ else 0
    }, numeric(1))))
  }

  window_start <- as.integer(reference_year) - as.integer(window_years) + 1L
  thr <- min_proba * 100

  t3 <- vapply(ex, function(df) {
    cov   <- df$coverage_fraction
    denom <- sum(cov, na.rm = TRUE)
    if (!length(cov) || denom == 0) return(NA_real_)  # unit off-raster

    d  <- df$dates
    ok <- !is.na(d) & d > 0
    if (has_proba) {
      p  <- df$proba
      ok <- ok & !is.na(p) & p >= thr
    }
    if (!any(ok)) return(0)

    year   <- decode_year(d[ok])
    in_win <- year >= window_start & year <= reference_year
    if (!any(in_win)) return(0)

    # Linear recency weight in (0, 1]: most recent year -> 1, oldest year
    # in the window -> 1/window_years.
    w <- (year[in_win] - window_start + 1L) / as.integer(window_years)
    w <- pmin(1, pmax(0, w))

    num <- sum(cov[ok][in_win] * w)
    100 * num / denom
  }, numeric(1))
  .indicateur_resultat(units, "T3", t3)
}
