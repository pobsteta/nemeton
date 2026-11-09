# infradensite.R — infradensite du bois par essence IFN (spec 068)
# =================================================================
# Infradensite = masse anhydre / volume frais (g/cm3), la densite qu'il faut
# pour passer d'un volume sur pied a une biomasse seche. Table construite par
# data-raw/infradensite_espar.R depuis la Global Wood Density Database (CC0).

#' Basic wood density (infradensity) of IFN species
#'
#' @description
#' Basic wood density (oven-dry mass over green volume, g/cm3) of each IFN
#' species (`espar`), from the Global Wood Density Database (Chave et al.
#' 2009, Zanne et al. 2009, doi:10.5061/dryad.234, CC0). This is the density
#' that turns a standing volume into a dry biomass; an air-dry density
#' (about 12 % moisture) is 15 to 25 % higher.
#'
#' The `niveau` column tells where the value comes from, from the most to the
#' least precise: `"espece_europe"` (mean of the species' European records),
#' `"espece"` (all regions), `"genre"` (mean of the species means of the genus
#' in Europe and North America) and `"groupe"` (mean of the broadleaved or
#' coniferous IFN species valued at species level). Two generic rows,
#' `"FEUILLU"` and `"RESINEUX"`, carry the group values.
#'
#' @param espar Optional. Species codes in any nomenclature accepted by
#'   [resoudre_espar()] (IFN `espar`, four-letter code, Latin name, French
#'   label). Codes that do not resolve, or the generic `"BROADLEAF_GENUS"` and
#'   `"CONIFER_GENUS"`, take the broadleaved or coniferous group value (by
#'   the package's conifer list). `NULL` (default) returns the whole table.
#'
#' @return Without `espar`, a data.frame with `espar`, `lib_espar`,
#'   `nom_latin`, `groupe`, `infradensite_g_cm3`, `niveau`, `n_valeurs`
#'   (records or species averaged) and `source`. With `espar`, the matching
#'   rows in the order of `espar` (the group row where a code does not
#'   resolve), plus a column `code` holding the input; `NA` for a `NA` input.
#'
#' @section Lifecycle:
#' Experimental: may change in any release, without deprecation (spec 057).
#'
#' @seealso [ifn_espar_correspondance()], [simuler_itineraire()],
#'   [indicateur_c1_biomasse()]
#' @export
#' @examples
#' infradensite_espar(c("09", "PIAB", "Quercus pubescens", "CONIFER_GENUS"))
infradensite_espar <- function(espar = NULL) {
  d <- .ifn_table("infradensite_espar.csv")
  d$espar <- as.character(d$espar)
  if (is.null(espar)) return(d)
  code <- as.character(espar)
  e <- suppressWarnings(resoudre_espar(code))
  i <- match(e, d$espar)
  # sans ESPAR : repli feuillus / resineux
  sans <- is.na(i) & !is.na(code)
  if (any(sans)) {
    i[sans] <- match(ifelse(is_conifer(code[sans]), "RESINEUX", "FEUILLU"), d$espar)
  }
  out <- d[i, , drop = FALSE]
  out <- cbind(code = code, out, stringsAsFactors = FALSE)
  rownames(out) <- NULL
  out
}
