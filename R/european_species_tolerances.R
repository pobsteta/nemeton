# european_species_tolerances.R — table de référence essences UE (spec 027)
# ------------------------------------------------------------------
# Accessor de la table de tolérances au repeuplement pour ~193 essences
# européennes (data-raw/european_species_tolerances.R). Sourcée/calibrée par
# espèce, elle complète regeneration_tolerances() (11 classes broad, mapping
# UGF) : mêmes axes tmax_tol_c/vpd_tol_kpa, plus riches (N&V, gel, thermophilie).

#' European tree-species regeneration tolerances
#'
#' @description
#' Reference table of restocking tolerances for ~193 European tree species,
#' calibrated per species (spec 027). Complements the broad 11-class
#' [regeneration_tolerances()] (kept for the UGF-class mapping) with the same
#' `tmax_tol_c`/`vpd_tol_kpa` axes plus richer autecology: Niinemets &
#' Valladares (2006) drought / shade / waterlogging tolerances (1–5), winter
#' cold and frost, air-humidity affinity and thermophily (1–9).
#'
#' Three stacked scopes in `statut`: `"frm_1999"` (Directive 1999/105/CE Annex I
#' in force, 47), `"frm_2025"` (additions of the forthcoming FRM regulation,
#' political agreement 2025-12-08, 17) and `"atlas_jrc"` (European Atlas of
#' Forest Tree Species dendroflora outside the FRM list, ~130, **rule-derived
#' draft** — validate before operational use). The `confidence` column
#' (`"eleve"`/`"moyen"`/`"faible"`) grades reliability; `invasif` flags
#' INTRO/INVASIVE taxa (listed for completeness — **presence is not a
#' recommendation**).
#'
#' @param statut Optional character vector filter on `statut`. The convenience
#'   value `"frm"` expands to both `"frm_1999"` and `"frm_2025"` (the
#'   regulatory FRM species).
#' @param confiance Optional filter on `confidence`
#'   (`"eleve"`/`"moyen"`/`"faible"`).
#' @param type Optional filter on `type` (`"conifere"`/`"feuillu"`).
#' @param include_invasif Logical; keep INTRO/INVASIVE taxa. Default `TRUE`.
#'
#' @return A data.frame with `code`, `species_sci`, `species_fr`, `type`,
#'   `statut`, `tmax_tol_c`, `vpd_tol_kpa`, `drought_tol`, `shade_tol`,
#'   `waterlog_tol`, `frost_winter_min_c`, `frost_late`, `frost_early`,
#'   `air_humidity`, `thermophily`, `confidence`, `invasif`, `notes`.
#' @references European Atlas of Forest Tree Species (San-Miguel-Ayanz et al.
#'   2016); Caudullo, Welk & San-Miguel-Ayanz (2017); Niinemets & Valladares
#'   (2006); Directive 1999/105/EC. See `inst/REFERENCES.md`.
#' @seealso [regeneration_tolerances()], [indice_priorite_regen()],
#'   [regen_species_choices()]
#' @export
european_species_tolerances <- function(statut = NULL, confiance = NULL,
                                        type = NULL, include_invasif = TRUE) {
  path <- system.file("extdata", "european_species_tolerances.csv",
                      package = "nemeton")
  if (!nzchar(path) || !file.exists(path)) {
    stop("european_species_tolerances.csv not found in the installed package",
         call. = FALSE)
  }
  d <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")

  if (!is.null(statut)) {
    if ("frm" %in% statut) statut <- unique(c(statut, "frm_1999", "frm_2025"))
    d <- d[d$statut %in% statut, , drop = FALSE]
  }
  if (!is.null(confiance)) d <- d[d$confidence %in% confiance, , drop = FALSE]
  if (!is.null(type))      d <- d[d$type %in% type, , drop = FALSE]
  if (!isTRUE(include_invasif)) d <- d[!d$invasif, , drop = FALSE]

  rownames(d) <- NULL
  d
}
