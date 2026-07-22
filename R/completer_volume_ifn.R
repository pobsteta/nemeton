# completer_volume_ifn.R — suppléer P1 par la référence IFN (spec 040, D8)
# ==========================================================================
# En NDP 0 — l'état normal de l'application, données publiques seules — P1 est
# `NA` faute d'inventaire terrain et de CHM. La table IFN essence × SER fournit
# alors un volume de référence régional, sourcé, à la place d'un trou.
#
# Principe : ne JAMAIS écraser une mesure. Le volume mesuré prime toujours ;
# seuls les NA sont comblés, et la provenance de chaque valeur est écrite dans
# une colonne dédiée — un volume régional ne doit pas pouvoir se faire passer
# pour un volume mesuré.

#' Fill missing P1 volumes with the IFN regional reference
#'
#' @description
#' Where the standing-volume column is `NA`, substitutes the IFN reference
#' volume for that species and sylvoecoregion, walking the mesh down
#' SER -> GRECO -> national as needed ([ifn_volume_reference()]).
#'
#' This addresses the ordinary NDP 0 case: with public data only,
#' [indicateur_p1_volume()] has neither a field inventory nor a CHM to work
#' from, and returns `NA`. A sourced regional figure is more useful than a
#' hole — provided nobody mistakes it for a measurement, hence `source_col`.
#'
#' @section A measurement is never overwritten:
#' Rows where `volume_col` is already filled are left strictly untouched. Only
#' `NA`s are completed. The added `source_col` records, per row, where each
#' value came from: `"mesure"` for the original values, `"ifn_ser"`,
#' `"ifn_greco"` or `"ifn_national"` for completed ones, and `NA` where no
#' reference could be found. Any downstream reader can therefore separate
#' measured from imputed — which the caller **should** do before reporting.
#'
#' @section Which figure is substituted:
#' `mesure = "present"` (default) uses the mean volume over the plots where
#' the species actually occurs — a stand-level figure, comparable to a P1
#' computed on a forest unit of that species. `"maille"` would use the
#' species' contribution to the regional mean, which is a resource figure and
#' far too low for this purpose.
#'
#' @param units An `sf` object.
#' @param volume_col Standing-volume column, m3/ha. Default `"P1"`.
#' @param species_field Column holding the species code, in **any** of the
#'   project's nomenclatures — IFN `espar`, four-letter P1 code, snake-case
#'   tolerance code or Latin name. Resolved by [resoudre_espar()].
#' @param ser SER code for the units, a single string, or `NULL` for national
#'   references.
#' @param min_plac Minimum plots for a mesh level to qualify. Default `30`.
#' @param mesure `"present"` (default) or `"maille"`; see above.
#' @param source_col Name of the added provenance column. Default
#'   `"volume_source"`.
#'
#' @return `units` with `volume_col` completed and `source_col` added.
#'
#' @seealso [ifn_volume_reference()], [volume_mobilisable()].
#' @export
#' @examples
#' \dontrun{
#' units <- indicateur_p1_volume(units)          # NA en NDP 0
#' units <- completer_volume_ifn(units, species_field = "species", ser = "C20")
#' table(units$volume_source)
#' }
completer_volume_ifn <- function(units,
                                 volume_col = "P1",
                                 species_field = "species",
                                 ser = NULL,
                                 min_plac = 30,
                                 mesure = c("present", "maille"),
                                 source_col = "volume_source") {
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an sf object.")
  }
  mesure <- match.arg(mesure)
  if (!volume_col %in% names(units)) {
    cli::cli_abort(c(
      "Column {.val {volume_col}} not found in {.arg units}.",
      "i" = "Run {.fn indicateur_p1_volume} first, or set {.arg volume_col}."
    ))
  }
  if (!species_field %in% names(units)) {
    cli::cli_abort(c(
      "Column {.val {species_field}} not found in {.arg units}.",
      "i" = "A species code is required to pick an IFN reference."
    ))
  }

  vol <- as.numeric(units[[volume_col]])
  manque <- is.na(vol)

  # La provenance est posée AVANT toute complétion : ce qui est déjà là est
  # une mesure, définitivement.
  provenance <- rep(NA_character_, length(vol))
  provenance[!manque] <- "mesure"

  if (!any(manque)) {
    units[[source_col]] <- provenance
    cli::cli_alert_info("No missing {.val {volume_col}}: nothing to complete.")
    return(units)
  }

  espar <- resoudre_espar(as.character(units[[species_field]]))
  n_non_resolu <- sum(manque & is.na(espar))

  a_chercher <- unique(espar[manque & !is.na(espar)])
  if (length(a_chercher) > 0L) {
    ref <- ifn_volume_reference(a_chercher, ser = ser, min_plac = min_plac,
                               mesure = mesure)
    idx <- match(espar, ref$espar)
    vol_ref <- ref$vol_ha[idx]
    niv_ref <- ref$niveau_utilise[idx]

    comble <- manque & !is.na(vol_ref)
    vol[comble] <- vol_ref[comble]
    provenance[comble] <- paste0("ifn_", niv_ref[comble])
  }

  n_comble <- sum(!is.na(provenance)) - sum(!manque)
  n_reste  <- sum(is.na(provenance))
  cli::cli_alert_info(
    "{.val {volume_col}}: {sum(!manque)} measured, {n_comble} completed from \\
     the IFN reference, {n_reste} still missing."
  )
  if (n_non_resolu > 0L) {
    cli::cli_warn(
      "{n_non_resolu} unit{?s} with a species code that resolves to no IFN \\
       code: left NA. See {.fn resoudre_espar}."
    )
  }

  units[[volume_col]] <- vol
  units[[source_col]] <- provenance
  units
}
