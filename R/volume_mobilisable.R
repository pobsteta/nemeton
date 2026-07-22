# volume_mobilisable.R — couplage P1 -> volume_champ desserte (spec 040)
# ----------------------------------------------------------------------
# Jointure entre l'indicateur P1 (volume sur pied, m3/ha) et la colonne de
# volume attendue par les moteurs de desserte de `foretaccess`. Aucun calcul
# de volume ici : indicateur_p1_volume() en reste le seul propriétaire.
#
# Deux consommateurs en aval, de sémantique OPPOSÉE (spec 040 §3) :
#   - calculer_flux()   répartit le volume sur les points sources -> total m3 ;
#   - reseau_desserte() le rasterise par cellule            -> densité m3/ha.
# D'où `unite` : servir la mauvaise unité donne un résultat faux sans erreur.
#
# Jalon « taux saisi » (2026-07-22) : seules les voies scalaire et vecteur sont
# livrées. Le mode table IFN x SER (D4) est différé — cf. spec 040 §5.a et §11.

#' Mobilisable timber volume for road-network sizing
#'
#' @description
#' Turns the P1 standing-volume indicator into the volume column expected by
#' the `foretaccess` road-network engines, applying a harvest rate over a
#' planning horizon and converting to the unit the downstream consumer needs.
#'
#' No volume is computed here: [indicateur_p1_volume()] remains the single
#' owner of the IFN tarif. This function only converts and weights.
#'
#' @section Choosing `unite`:
#' The two `foretaccess` consumers of `volume_champ` expect **opposite**
#' semantics, and neither raises an error on the wrong one:
#' \itemize{
#'   \item `calculer_flux()` splits the parcel volume across its source points
#'     and accumulates it down the network — it expects a **total in m3**
#'     (`unite = "m3_total"`);
#'   \item `reseau_desserte()` / `optimiser_reseau()` rasterise the column onto
#'     the grid, one value per cell — they expect a **density in m3/ha**
#'     (`unite = "m3_ha"`). A total there would be counted once per cell,
#'     mechanically over-weighting large parcels.
#' }
#'
#' @section Harvest rate:
#' `taux_prelevement` is a **yearly flux** in m3/ha/year, not a fraction, so
#' `horizon_ans` is required with it: `volume = P1 x taux x horizon_ans`.
#' A harvest rate describes what **has been** removed, not what **should** be;
#' sizing a road network on it assumes management carries on unchanged.
#'
#' The species x sylvoecoregion table (spec 040, D4) is **not implemented yet**:
#' `taux_prelevement = NULL` errors out rather than serve unsourced figures.
#'
#' @param units An `sf` object carrying the P1 column.
#' @param volume_col Name of the standing-volume column, in m3/ha, as produced
#'   by [indicateur_p1_volume()]. Default `"P1"`.
#' @param unite Output unit: `"m3_total"` (default, for `calculer_flux()`) or
#'   `"m3_ha"` (for `reseau_desserte()` / `optimiser_reseau()`).
#' @param taux_prelevement Harvest rate in m3/ha/year: a single number applied
#'   to every unit, or a numeric vector of `nrow(units)`. `NULL` (default)
#'   would select the not-yet-sourced IFN table and therefore errors.
#' @param horizon_ans Planning horizon in years. Required whenever
#'   `taux_prelevement` is supplied.
#' @param na_policy What to do with units whose volume is `NA` — typically the
#'   NDP 0 case, where P1 has neither field inventory nor CHM. `"na"` (default)
#'   propagates `NA` and warns; `"zero"` maps them to 0 (**paints an
#'   uninventoried parcel as "nothing to haul"**); `"error"` aborts.
#' @param column_name Name of the added column. Default `"volume_mobilisable"`.
#'
#' @return `units` with the `column_name` column added.
#'
#' @seealso [indicateur_p1_volume()] for the volume itself.
#' @export
#' @examples
#' \dontrun{
#' units <- indicateur_p1_volume(units)
#'
#' # For calculer_flux(): a total in m3 over a 10-year horizon.
#' units <- volume_mobilisable(units, taux_prelevement = 4, horizon_ans = 10)
#'
#' # For reseau_desserte(): the same rate as a density.
#' units <- volume_mobilisable(units, unite = "m3_ha",
#'                             taux_prelevement = 4, horizon_ans = 10)
#' }
volume_mobilisable <- function(units,
                               volume_col = "P1",
                               unite = c("m3_total", "m3_ha"),
                               taux_prelevement = NULL,
                               horizon_ans = NULL,
                               na_policy = c("na", "zero", "error"),
                               column_name = "volume_mobilisable") {
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an sf object.")
  }
  unite <- match.arg(unite)
  na_policy <- match.arg(na_policy)

  if (!volume_col %in% names(units)) {
    cli::cli_abort(c(
      "Column {.val {volume_col}} not found in {.arg units}.",
      "i" = "Run {.fn indicateur_p1_volume} first, or set {.arg volume_col}."
    ))
  }

  # --- Taux de prélèvement -------------------------------------------
  # Le mode table (IFN x SER) est différé : échouer explicitement plutôt que
  # de servir des chiffres non sourcés (spec 040 §5.a).
  if (is.null(taux_prelevement)) {
    cli::cli_abort(c(
      "{.arg taux_prelevement} is required.",
      "x" = "The IFN species x sylvoecoregion table is not implemented yet \\
             (spec 040, D4).",
      "i" = "Supply a rate in m3/ha/year, as a single number or one per unit."
    ))
  }
  if (!is.numeric(taux_prelevement) || anyNA(taux_prelevement)) {
    cli::cli_abort("{.arg taux_prelevement} must be numeric and free of NA.")
  }
  if (any(taux_prelevement < 0)) {
    cli::cli_abort("{.arg taux_prelevement} must be non-negative.")
  }
  n <- nrow(units)
  if (length(taux_prelevement) != 1L && length(taux_prelevement) != n) {
    cli::cli_abort(
      "{.arg taux_prelevement} must be length 1 or {n} (nrow of {.arg units}), \\
       not {length(taux_prelevement)}."
    )
  }

  # Un taux IFN est un flux annuel : sans horizon, la conversion n'a pas de
  # sens dimensionnel (spec 040 §5.a-2).
  if (is.null(horizon_ans)) {
    cli::cli_abort(c(
      "{.arg horizon_ans} is required with {.arg taux_prelevement}.",
      "i" = "The rate is a yearly flux (m3/ha/year), not a fraction: \\
             volume = P1 x rate x horizon."
    ))
  }
  if (!is.numeric(horizon_ans) || length(horizon_ans) != 1L ||
      is.na(horizon_ans) || horizon_ans <= 0) {
    cli::cli_abort("{.arg horizon_ans} must be a single positive number.")
  }

  # --- Volume sur pied ------------------------------------------------
  p1 <- as.numeric(units[[volume_col]])
  n_na <- sum(is.na(p1))
  if (n_na > 0L) {
    if (identical(na_policy, "error")) {
      cli::cli_abort(
        "{n_na} unit{?s} ha{?s/ve} a missing {.val {volume_col}} \\
         (na_policy = \"error\")."
      )
    }
    if (identical(na_policy, "zero")) {
      p1[is.na(p1)] <- 0
      cli::cli_warn(
        "{n_na} unit{?s} with missing {.val {volume_col}} mapped to 0 \\
         (na_policy = \"zero\"): they will read as \"nothing to haul\"."
      )
    } else {
      cli::cli_warn(
        "{n_na} unit{?s} with missing {.val {volume_col}}: \\
         {.val {column_name}} stays NA there (na_policy = \"na\")."
      )
    }
  }

  # Densité mobilisable, m3/ha sur l'horizon.
  vol_ha <- p1 * taux_prelevement * horizon_ans

  if (identical(unite, "m3_ha")) {
    units[[column_name]] <- vol_ha
    return(units)
  }

  # --- Passage au total : surface en hectares -------------------------
  # st_area exige une géométrie projetée ; en CRS géographique elle repose sur
  # une géodésique — refuser plutôt que rendre des hectares silencieusement
  # douteux.
  crs <- sf::st_crs(units)
  if (is.na(crs)) {
    cli::cli_abort(c(
      "{.arg units} has no CRS; cannot compute areas for {.val m3_total}.",
      "i" = "Set a projected CRS, or use unite = \"m3_ha\"."
    ))
  }
  if (isTRUE(sf::st_is_longlat(units))) {
    cli::cli_abort(c(
      "{.arg units} is in a geographic CRS; areas would not be in metres.",
      "i" = "Project to a metric CRS (e.g. EPSG:2154), or use \\
             unite = \"m3_ha\"."
    ))
  }
  aire_ha <- as.numeric(sf::st_area(units)) / 1e4

  units[[column_name]] <- vol_ha * aire_ha
  units
}
