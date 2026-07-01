# ============================================================
# pixel_dieback_prep.R — derived series for the pixel-dieback plot
# ------------------------------------------------------------
# Pure, testable transform of a RECONFORT pixel CRswir/CRre series
# (from read_reconfort_pixel_series()) into the layers the app's
# 4-panel plotly needs. NO plotting, NO Shiny: the app's fct_/mod_
# only renders what this returns (ADR-009 / CLAUDE.md rule 3 —
# business logic stays in `nemeton`).
# ============================================================


# Empty grid/obs frame with the documented columns and types, so
# downstream binding/plotting never chokes on a degenerate pixel.
.pdb_empty_grid <- function() {
  data.frame(date = as.Date(character(0)), val = numeric(0),
             year = integer(0), doy = integer(0),
             stringsAsFactors = FALSE)
}


# Regularize one index series onto a `step`-day grid, gap-fill by linear
# interpolation (stats::approx, iota2-equivalent) and optionally apply a
# light Savitzky-Golay smooth. Returns a grid frame (date, val, year,
# doy). Fewer than two valid observations -> empty grid (never errors).
.pdb_regularize <- function(dates, vals, step, smooth) {
  ok <- !is.na(dates) & !is.na(vals)
  dates <- as.Date(dates[ok]); vals <- as.numeric(vals[ok])
  if (length(vals) < 2L) return(.pdb_empty_grid())
  ord   <- order(dates)
  dates <- dates[ord]; vals <- vals[ord]
  t     <- as.integer(dates - min(dates))
  if (length(unique(t)) < 2L) return(.pdb_empty_grid())
  gg    <- seq(0L, max(t), by = as.integer(step))
  # approx(ties = mean) folds any same-day duplicates; rule = 2 holds the
  # end values flat rather than returning NA past the observed range.
  yi    <- stats::approx(t, vals, xout = gg, rule = 2, ties = mean)$y
  if (identical(smooth, "light") && length(yi) >= 5L) {
    yi <- signal::sgolayfilt(yi, p = 2L, n = 5L)
  }
  d <- min(dates) + gg
  data.frame(date = d, val = as.numeric(yi),
             year = as.integer(format(d, "%Y")),
             doy  = as.integer(format(d, "%j")),
             stringsAsFactors = FALSE)
}


# Real (non-interpolated) valid observations of one index, as a
# (date, val, year, doy) frame — feeds the raw-points overlay and the
# summer extrema (measured on real data, not the smoothed curve).
.pdb_observations <- function(dates, vals) {
  ok <- !is.na(dates) & !is.na(vals)
  if (!any(ok)) return(.pdb_empty_grid())
  d <- as.Date(dates[ok]); v <- as.numeric(vals[ok])
  ord <- order(d)
  data.frame(date = d[ord], val = v[ord],
             year = as.integer(format(d[ord], "%Y")),
             doy  = as.integer(format(d[ord], "%j")),
             stringsAsFactors = FALSE)
}


# Per-year summer extremum (which.min for the CRswir trough, which.max
# for the CRre peak) picked on REAL observations within the DOY window.
.pdb_summer_extrema <- function(obs, summer, pick) {
  empty <- data.frame(year = integer(0), date = as.Date(character(0)),
                      val = numeric(0), stringsAsFactors = FALSE)
  if (!nrow(obs)) return(empty)
  s <- obs[obs$doy >= summer[1L] & obs$doy <= summer[2L], , drop = FALSE]
  if (!nrow(s)) return(empty)
  parts <- by(s, s$year, function(d) {
    i <- pick(d$val)
    data.frame(year = d$year[i], date = d$date[i], val = d$val[i],
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out[order(out$year), , drop = FALSE]
}


# Long-gap interpolated spans: consecutive real observations more than
# `gap_flag_days` apart (union of both indices), so the app can shade the
# over-interpolated winter stretches (avoid over-reading them).
.pdb_gaps <- function(dates, gap_flag_days) {
  d <- sort(unique(as.Date(dates[!is.na(dates)])))
  if (length(d) < 2L) {
    return(data.frame(from = as.Date(character(0)),
                      to = as.Date(character(0)), stringsAsFactors = FALSE))
  }
  diffs <- as.integer(diff(d))
  hit   <- which(diffs > as.integer(gap_flag_days))
  data.frame(from = d[hit], to = d[hit + 1L], stringsAsFactors = FALSE)
}


#' Prepare the derived series for the pixel-dieback plot (CRswir + CRre)
#'
#' Pure transform of a RECONFORT pixel series (from
#' [read_reconfort_pixel_series()]) into the derived layers the app's
#' 4-panel plotly needs: a regular gap-filled grid (optionally
#' light-smoothed), the raw valid observations, the annual summer extrema
#' (CRswir trough / CRre peak), the annual state-space centroids, and the
#' long-gap interpolated spans. No plotting, no Shiny — testable on its
#' own, so the app's rendering function stays free of business logic
#' (CLAUDE.md rule 3).
#'
#' @param df A `data.frame` from [read_reconfort_pixel_series()]: columns
#'   `obs_date` (Date), `crswir_obs`, `crre_obs`. A per-index validity is
#'   derived as `!is.na()` (an `NA` marks a cloud-masked date).
#' @param grid_step Integer number of days of the regular grid.
#'   Default `10L`.
#' @param smooth `"light"` (Savitzky-Golay, `p = 2`, `n = 5`) or `"none"`.
#'   Default `"light"`. Strong smoothing is intentionally not offered: it
#'   razes the summer extrema, which are the signal being tracked.
#' @param summer Integer length-2 day-of-year window `c(start, end)` of
#'   the growing-season peak. Default `c(152L, 273L)` (1 Jun - 30 Sep).
#' @param gap_flag_days Long-gap threshold in days above which an
#'   interpolated span is flagged in `gaps`. Default `45L`.
#'
#' @return A named list, each element a `data.frame`:
#'   \describe{
#'     \item{grid_swir, grid_re}{`date`, `val`, `year`, `doy` — the
#'       regular grid, gap-filled and optionally smoothed, per index.}
#'     \item{obs_swir, obs_re}{`date`, `val`, `year`, `doy` — the raw
#'       valid observations per index (raw-points overlay).}
#'     \item{trough_swir}{`year`, `date`, `val` — annual summer CRswir
#'       minimum, on real observations.}
#'     \item{peak_re}{`year`, `date`, `val` — annual summer CRre maximum.}
#'     \item{state}{`date`, `year`, `val_sw`, `val_re` — summer dates where
#'       both indices are valid (state-space cloud).}
#'     \item{centroids}{`year`, `val_sw`, `val_re` — annual mean of
#'       `state` (state-space trajectory).}
#'     \item{gaps}{`from`, `to` — interpolated spans longer than
#'       `gap_flag_days`.}
#'   }
#'   The input attributes (`species`, `v_model`, `n_classes`, `date_from`,
#'   `date_to`, `dans_zone_validite`) are carried over onto the list.
#'
#' @seealso [read_reconfort_pixel_series()]
#' @examples
#' df <- data.frame(
#'   obs_date   = as.Date("2023-01-01") + seq(0, 700, by = 15),
#'   crswir_obs = 0.8 - 0.1 * sin(seq(0, 700, by = 15) / 58),
#'   crre_obs   = 0.5 + 0.1 * sin(seq(0, 700, by = 15) / 58)
#' )
#' prep <- prepare_pixel_dieback_series(df)
#' names(prep)
#' @export
prepare_pixel_dieback_series <- function(df, grid_step = 10L,
                                         smooth = c("light", "none"),
                                         summer = c(152L, 273L),
                                         gap_flag_days = 45L) {
  smooth <- match.arg(smooth)
  if (!is.data.frame(df) ||
      !all(c("obs_date", "crswir_obs", "crre_obs") %in% names(df))) {
    cli::cli_abort(
      "{.arg df} must be a data.frame with columns {.field obs_date}, \\
       {.field crswir_obs}, {.field crre_obs} (see \\
       {.fn read_reconfort_pixel_series}).")
  }
  grid_step <- as.integer(grid_step)
  if (is.na(grid_step) || grid_step < 1L) {
    cli::cli_abort("{.arg grid_step} must be a positive integer (days).")
  }
  if (length(summer) != 2L || anyNA(summer) ||
      any(summer < 1L | summer > 366L) || summer[1L] > summer[2L]) {
    cli::cli_abort("{.arg summer} must be an increasing DOY pair in 1:366.")
  }
  summer <- as.integer(summer)
  gap_flag_days <- as.integer(gap_flag_days)
  if (is.na(gap_flag_days) || gap_flag_days < 1L) {
    cli::cli_abort("{.arg gap_flag_days} must be a positive integer (days).")
  }
  if (!requireNamespace("signal", quietly = TRUE) &&
      identical(smooth, "light")) {
    cli::cli_abort(
      "Package {.pkg signal} is required for {.code smooth = \"light\"}.")
  }

  dates <- as.Date(df$obs_date)

  grid_swir <- .pdb_regularize(dates, df$crswir_obs, grid_step, smooth)
  grid_re   <- .pdb_regularize(dates, df$crre_obs,   grid_step, smooth)
  obs_swir  <- .pdb_observations(dates, df$crswir_obs)
  obs_re    <- .pdb_observations(dates, df$crre_obs)

  trough_swir <- .pdb_summer_extrema(obs_swir, summer, which.min)
  peak_re     <- .pdb_summer_extrema(obs_re,   summer, which.max)

  # State-space: summer dates where BOTH indices are observed.
  both <- merge(
    obs_swir[, c("date", "year", "val")],
    obs_re[,   c("date", "val")],
    by = "date", suffixes = c("_sw", "_re"))
  state <- both[both$date %in% dates &
                  as.integer(format(both$date, "%j")) >= summer[1L] &
                  as.integer(format(both$date, "%j")) <= summer[2L], ,
                drop = FALSE]
  state <- state[order(state$date), c("date", "year", "val_sw", "val_re"),
                 drop = FALSE]
  rownames(state) <- NULL

  centroids <- if (nrow(state)) {
    c0 <- stats::aggregate(cbind(val_sw, val_re) ~ year, state, mean)
    c0[order(c0$year), , drop = FALSE]
  } else {
    data.frame(year = integer(0), val_sw = numeric(0), val_re = numeric(0),
               stringsAsFactors = FALSE)
  }

  gaps <- .pdb_gaps(dates, gap_flag_days)

  out <- list(
    grid_swir = grid_swir, grid_re = grid_re,
    obs_swir  = obs_swir,  obs_re  = obs_re,
    trough_swir = trough_swir, peak_re = peak_re,
    state = state, centroids = centroids, gaps = gaps)

  # Carry over the RECONFORT metadata attributes from the input series.
  for (a in c("species", "v_model", "n_classes", "date_from", "date_to",
              "dans_zone_validite")) {
    attr(out, a) <- attr(df, a)
  }
  out
}
