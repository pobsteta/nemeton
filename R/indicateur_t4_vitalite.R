# ==============================================================================
# T4 - Vitalite dynamique (spec 068)
# ==============================================================================

#' Calculate dynamic vitality (T4)
#'
#' Compares the dominant-height growth of each unit, observed on the FORMS-T
#' annual canopy-height series, with the growth expected by the FINN forest
#' model for comparable stands (spec 068). 50 means the unit grows as
#' expected; low values flag a growth deficit, high values a growth above
#' expectation. Source-conditional: without FORMS-T, T4 is `NA`.
#'
#' @param units An sf object with forest units.
#' @param forms_t A `SpatRaster` of yearly canopy heights, one layer per year
#'   named by year (as returned by [charger_forms_t_hauteurs()]), or file
#'   paths. `NULL` (default): T4 is not computed (`NA`).
#' @param essence Dominant species of each unit, as IFN `ESPAR` codes (for
#'   example `"03"` sessile oak, `"09"` beech, `"62"` Norway spruce): a
#'   character vector of length `nrow(units)`, a single code for every unit,
#'   or the name of a column of `units`. `NULL` (default): the column
#'   `essence` of `units` when present.
#' @param ser Optional sylvo-ecoregion (SER) code of each unit, vector or
#'   column name. `NULL` (default): the column `ser` of `units` when
#'   present; otherwise analogues are taken in every SER.
#' @param coupes Optional logical vector, `TRUE` for units with a cut
#'   detected over the series (for instance `T3 > 0`). `NULL` (default): the
#'   `T3` column of `units` is used when present.
#' @param attendu Optional data frame of expected increments simulated on the
#'   unit's own inventory with [accroissement_hdom_finn()], with columns
#'   `unite` (row number in `units`) and `accroissement` (m over 5 years).
#'   For those units it replaces the IFN analogues.
#' @param tolerance_h Numeric, half-width (m) of the initial dominant-height
#'   window for the analogues. Default 2.
#' @param min_analogues Integer, minimum number of analogue plots. Default 30.
#' @param min_pixels Integer, minimum number of canopy pixels (>= 5 m) per
#'   unit and year. Default 50 (0.5 ha at 10 m).
#' @param unite_hauteur Unit of the FORMS-T heights, `"cm"` (default, as
#'   distributed) or `"m"`.
#'
#' @return `units` with the numeric column `T4` (0-100) and:
#'   \itemize{
#'     \item `t4_status`: `"calculated"`, `"skipped_no_forms_t"`,
#'       `"skipped_no_coverage"`, `"skipped_cut"`, `"skipped_drop"` (dominant
#'       height fell by more than 3 m from one year to the next),
#'       `"skipped_no_essence"` or `"skipped_no_analogues"`;
#'     \item `t4_accroissement_obs`: observed dominant-height increment (m per
#'       5 years);
#'     \item `t4_accroissement_att`: median of the reference distribution
#'       (m per 5 years);
#'     \item `t4_h_dom`: dominant height of the first year (m);
#'     \item `t4_n_analogues`: number of analogue plots (`NA` with `attendu`).
#'   }
#'
#' @details
#' **Observed.** Each year, the dominant height of the unit is the 90th
#' percentile of its FORMS-T pixels at least 5 m high. The increment is the
#' Theil-Sen slope of that series, times 5.
#'
#' **Expected.** IFN plots of Bourgogne-Franche-Comte measured in 2017-2021
#' (3 398 plots) were run through one FINN step (5 years) under the E-OBS
#' 2019-2023 climate, 20 draws each (`data-raw/t4_analogues_bfc.R`). The
#' analogues of a unit share its dominant species and SER and have an initial
#' dominant height within `tolerance_h` of the unit's first-year value; when
#' fewer than `min_analogues` are found, the SER is dropped, then the window
#' is doubled.
#'
#' **Score.** FORMS-T varies far more than FINN draws (standard deviation
#' 1.35 m against 0.1 m per 5 years around IFN plots): the reference adds to
#' the simulated increments the residuals observed minus simulated measured
#' around the IFN plots of the same species and initial dominant height
#' (within `tolerance_h`, then twice that, then all species), mean bias
#' included (`data-raw/t4_residus_forms_bfc.R`): beyond 28 m FORMS-T keeps
#' growing while the height-diameter curves level off, so the bias depends
#' on height.
#' `T4 = 100 * P(simulated + residual < observed)`.
#'
#' **Not computed** after a cut (`coupes`) or a fall of the dominant height
#' of more than 3 m between two years: a cut is not a vitality defect; excess
#' mortality ([surmortalite_finn()]) and R5 cover those cases.
#'
#' **Limits.** The residuals are measured on discs of about 20 ha around
#' blurred IFN coordinates: they include stand-to-stand variability, which
#' makes T4 cautious; a smaller unit is noisier than the reference assumes.
#' FORMS-T is a height predicted from Sentinel-1/2 and GEDI, not measured.
#' The analogues cover Bourgogne-Franche-Comte (FINN calibration domain).
#'
#' **Centring check** (spec 068, 2026-11-15): on 1 072 fir and spruce cells
#' of 4 ha at Dabo (Vosges, no known disturbance), median 57, 5 % and 95 %
#' quantiles 13 and 98; stands over about 33 m find no analogue.
#'
#' @family temporal-indicators
#' @seealso [accroissement_hdom_finn()], [charger_forms_t_hauteurs()]
#' @export
indicateur_t4_vitalite <- function(units, forms_t = NULL, essence = NULL, ser = NULL,
                                   coupes = NULL, attendu = NULL, tolerance_h = 2,
                                   min_analogues = 30L, min_pixels = 50L,
                                   unite_hauteur = c("cm", "m")) {
  validate_sf(units)
  unite_hauteur <- match.arg(unite_hauteur)
  n <- nrow(units)
  essence <- .t4_colonne(units, essence, "essence")
  ser <- .t4_colonne(units, ser, "ser")
  if (is.null(coupes) && "T3" %in% names(units)) coupes <- units$T3 > 0
  if (!is.null(coupes) && length(coupes) != n) {
    cli::cli_abort("{.arg coupes} must have one value per unit.")
  }
  if (!is.null(attendu) && !all(c("unite", "accroissement") %in% names(attendu))) {
    cli::cli_abort("{.arg attendu} must have columns {.field unite} and {.field accroissement}.")
  }

  out <- .indicateur_resultat(units, "T4", rep(NA_real_, n))
  out$t4_status <- rep("skipped_no_forms_t", n)
  out$t4_accroissement_obs <- NA_real_
  out$t4_accroissement_att <- NA_real_
  out$t4_h_dom <- NA_real_
  out$t4_n_analogues <- NA_integer_
  if (is.character(forms_t)) forms_t <- terra::rast(forms_t)
  if (is.null(forms_t)) {
    cli::cli_alert_warning("T4: no FORMS-T canopy-height series, returning NA")
    return(out)
  }

  H <- .t4_hdom_annuelle(units, forms_t, unite_hauteur, min_pixels)
  annees <- as.integer(colnames(H))
  ok <- stats::complete.cases(H)
  chute <- rep(FALSE, n)
  chute[ok] <- apply(H[ok, , drop = FALSE], 1L, function(h) any(diff(h) < -3))
  acc <- rep(NA_real_, n)
  if (any(ok)) acc[ok] <- 5 * .theil_sen_pentes(H[ok, , drop = FALSE], annees)
  out$t4_accroissement_obs <- acc
  out$t4_h_dom <- H[, 1L]

  statut <- ifelse(ok, "calculated", "skipped_no_coverage")
  statut[ok & chute] <- "skipped_drop"
  if (!is.null(coupes)) statut[ok & coupes %in% TRUE] <- "skipped_cut"
  sans_ess <- is.na(essence) & statut == "calculated"
  if (!is.null(attendu)) sans_ess <- sans_ess & !(seq_len(n) %in% attendu$unite)
  statut[sans_ess] <- "skipped_no_essence"

  ana <- .t4_analogues()
  res <- .t4_residus()
  for (i in which(statut == "calculated")) {
    if (!is.null(attendu) && i %in% attendu$unite) {
      s <- attendu$accroissement[attendu$unite == i]
      s <- s[is.finite(s)]
    } else {
      sel <- .t4_choisir_analogues(ana, essence[i], ser[i], H[i, 1L], tolerance_h,
                                   min_analogues)
      if (is.null(sel)) {
        statut[i] <- "skipped_no_analogues"
        next
      }
      out$t4_n_analogues[i] <- nrow(sel)
      s <- unlist(sel[, grep("^a[0-9]+$", names(sel)), drop = FALSE], use.names = FALSE)
      s <- s[is.finite(s)]
    }
    e <- .t4_choisir_residus(res, essence[i], H[i, 1L], tolerance_h, min_analogues)
    out$T4[i] <- 100 * mean(stats::ecdf(s)(acc[i] - e))
    out$t4_accroissement_att[i] <- stats::median(outer(s, e, `+`))
  }
  out$t4_status <- statut
  cli::cli_alert_info("T4: dynamic vitality for {sum(statut == 'calculated')}/{n} units")
  out
}

# Vecteur par unite depuis un vecteur ou un nom de colonne de `units`.
.t4_colonne <- function(units, x, nom) {
  n <- nrow(units)
  if (is.null(x)) {
    if (!nom %in% names(units)) return(rep(NA_character_, n))
    x <- nom
  }
  # une chaine seule qui nomme une colonne est une colonne ; sinon une
  # valeur commune a toutes les unites
  if (length(x) == 1L) {
    x <- if (is.character(x) && x %in% names(units)) units[[x]] else rep(x, n)
  }
  if (length(x) != n) cli::cli_abort("{.arg {nom}} must have one value per unit.")
  as.character(x)
}

# Hauteur dominante annuelle (m) par unite : percentile 90 des pixels FORMS-T
# d'au moins 5 m couverts a plus de 50 % par l'unite ; NA sous `min_pixels`.
# Matrice unites x annees (colonnes nommees par annee, triees).
.t4_hdom_annuelle <- function(units, forms_t, unite_hauteur = "cm", min_pixels = 50L) {
  if (!inherits(forms_t, "SpatRaster")) {
    cli::cli_abort("{.arg forms_t} must be a {.cls SpatRaster} or file paths.")
  }
  annees <- suppressWarnings(as.integer(sub("^\\D*", "", names(forms_t))))
  if (anyNA(annees) || anyDuplicated(annees)) {
    cli::cli_abort(c(
      "{.arg forms_t} layers must be named by year.",
      i = "Got {.val {names(forms_t)}}; {.fn charger_forms_t_hauteurs} names them."
    ))
  }
  if (terra::nlyr(forms_t) < 3L) {
    cli::cli_abort("{.arg forms_t} needs at least three years, got {terra::nlyr(forms_t)}.")
  }
  o <- order(annees)
  forms_t <- forms_t[[o]]
  annees <- annees[o]
  div <- if (unite_hauteur == "cm") 100 else 1
  u <- sf::st_transform(sf::st_geometry(units), terra::crs(forms_t))
  zones <- sf::st_as_sf(data.frame(id = seq_along(u)), geometry = u)
  H <- vapply(seq_along(annees), function(j) {
    v <- exactextractr::exact_extract(forms_t[[j]], zones, progress = FALSE)
    vapply(v, function(d) {
      x <- d$value[d$coverage_fraction > 0.5] / div
      x <- x[!is.na(x) & x >= 5]
      if (length(x) < min_pixels) NA_real_ else stats::quantile(x, 0.9, names = FALSE)
    }, numeric(1))
  }, numeric(length(u)))
  H <- matrix(H, nrow = length(u))
  colnames(H) <- annees
  H
}

# Placettes analogues : meme essence, meme SER, hauteur dominante initiale a
# +/- tol ; sinon toutes SER ; sinon fenetre doublee ; NULL si trop peu.
.t4_choisir_analogues <- function(ana, essence, ser, h, tol, min_n) {
  if (!is.finite(h)) return(NULL)
  ess <- ana[ana$essence == essence, , drop = FALSE]
  essais <- list(list(ser = TRUE, tol = tol), list(ser = FALSE, tol = tol),
                 list(ser = FALSE, tol = 2 * tol))
  for (e in essais) {
    x <- ess
    if (e$ser) {
      if (is.na(ser)) next
      x <- x[x$ser == ser, , drop = FALSE]
    }
    x <- x[abs(x$h_dom - h) <= e$tol, , drop = FALSE]
    if (nrow(x) >= min_n) return(x)
  }
  NULL
}

# Residus observe - simule de la meme classe que l'unite : meme essence et
# hauteur dominante a +/- tol, puis +/- 2 tol, puis toutes essences a
# +/- 2 tol, puis tous. Le biais depend de la hauteur (FORMS-T croit encore
# au-dela de 28 m quand l'allometrie sature) : un residu toutes hauteurs
# decentrerait T4 (Dabo, 2026-11-15).
.t4_choisir_residus <- function(res, essence, h, tol, min_n) {
  ess <- res$essence %in% essence
  for (k in list(ess & abs(res$h_dom - h) <= tol, ess & abs(res$h_dom - h) <= 2 * tol,
                 abs(res$h_dom - h) <= 2 * tol)) {
    if (sum(k, na.rm = TRUE) >= min_n) return(res$residu[k %in% TRUE])
  }
  res$residu
}

.t4_cache <- new.env(parent = emptyenv())

.t4_analogues <- function() {
  if (is.null(.t4_cache$analogues)) {
    f <- system.file("extdata", "t4_analogues_bfc.csv.gz", package = "nemeton")
    .t4_cache$analogues <- utils::read.csv(
      f, colClasses = c(placette = "character", ser = "character", essence = "character"))
  }
  .t4_cache$analogues
}

.t4_residus <- function() {
  if (is.null(.t4_cache$residus)) {
    f <- system.file("extdata", "t4_residus_forms_bfc.csv", package = "nemeton")
    .t4_cache$residus <- utils::read.csv(f, colClasses = c(essence = "character"))
  }
  .t4_cache$residus
}
