# ifn_espar.R — pont entre les nomenclatures d'essences (spec 040, D9)
# =====================================================================
# Trois nomenclatures coexistent dans le projet, sans clé commune directe :
#
#   espar IFN        "09"               ARBRE.csv, tables ifn_*_essence_ser
#   code P1          "FASY"             ifn_volume_equations.csv (24 essences)
#   code tolérances  "fagus_sylvatica"  european_species_tolerances.csv (194)
#
# Le pivot est le **nom latin**, porté par le référentiel `espar-cdref13` de
# l'IGN. La table de correspondance est construite sur ce pivot par
# data-raw/build_ifn_tables.R, jamais par heuristique sur les libellés.

#' Species-code correspondence across the project's three nomenclatures
#'
#' @description
#' Bridge table between the IFN's own species codes (`espar`, e.g. `"09"`),
#' the four-letter codes used by [indicateur_p1_volume()] (e.g. `"FASY"`) and
#' the snake-case codes of [european_species_tolerances()] (e.g.
#' `"fagus_sylvatica"`). The Latin binomial is the pivot.
#'
#' @section Coverage is uneven, by construction:
#' Every `espar` has a Latin name, so `code_tolerances` resolves for most
#' rows. `code_p1` resolves only for the species present in
#' `ifn_volume_equations.csv` — a short list, since P1 falls back to genus-level
#' equations for anything else. A `NA` in `code_p1` is therefore normal and
#' means "no species-specific IFN tarif", not "unknown species".
#'
#' @param espar Optional filter on the IFN code.
#' @param code_p1 Optional filter on the four-letter code.
#'
#' @return A data.frame with `espar`, `lib_espar`, `espece_sci`, `code_p1`,
#'   `code_tolerances`, `millesime`, `source`.
#'
#' @seealso [resoudre_espar()] to convert a vector of codes.
#' @export
#' @examples
#' \dontrun{
#' ifn_espar_correspondance(espar = "09")
#' }
ifn_espar_correspondance <- function(espar = NULL, code_p1 = NULL) {
  d <- .ifn_table("ifn_espar_correspondance.csv")
  if (!is.null(espar)) {
    d <- d[d$espar %in% as.character(espar), , drop = FALSE]
  }
  if (!is.null(code_p1)) {
    d <- d[!is.na(d$code_p1) & d$code_p1 %in% code_p1, , drop = FALSE]
  }
  rownames(d) <- NULL
  d
}

#' Resolve any species code to the IFN `espar` code
#'
#' @description
#' Accepts whichever nomenclature the caller happens to hold — IFN `espar`,
#' the four-letter P1 code, the snake-case tolerance code, or a plain Latin
#' binomial — and returns the corresponding `espar`. This is what lets
#' [volume_mobilisable()] and [completer_volume_ifn()] take a `species` column
#' as it exists in the caller's data, rather than demanding IFN codes.
#'
#' Resolution is tried in that order and is **case-insensitive** for the
#' non-`espar` forms. Unresolved entries come back as `NA` — never guessed.
#'
#' @param x Character vector of species codes or Latin names.
#'
#' @return A character vector of `espar` codes, same length as `x`, `NA` where
#'   no correspondence exists.
#'
#' @seealso [ifn_espar_correspondance()] for the table itself.
#' @export
#' @examples
#' \dontrun{
#' resoudre_espar(c("09", "FASY", "fagus_sylvatica", "Fagus sylvatica"))
#' # -> tous "09"
#' }
resoudre_espar <- function(x) {
  if (!is.character(x)) x <- as.character(x)
  d <- ifn_espar_correspondance()

  norm <- function(v) {
    v <- tolower(trimws(as.character(v)))
    v <- gsub("[[:space:]]+", " ", v)
    gsub("[-_]", " ", v)
  }
  xn <- norm(x)
  out <- rep(NA_character_, length(x))

  # 1. Déjà un code espar. Comparaison sensible à la casse ("21C" n'est pas
  #    "21c"), mais tolérante au zéro non significatif : selon la table d'où
  #    il sort, le hêtre s'écrit "09" (ARBRE.csv) ou "9" (référentiel
  #    espar-cdref13). On rend toujours la forme de la table de référence.
  depad <- function(v) sub("^0([0-9])$", "\\1", v)
  idx_e <- match(depad(x), depad(d$espar))
  out <- d$espar[idx_e]

  # 2. Code P1 à quatre lettres, 3. code tolérances, 4. nom latin — tous
  #    normalisés, le pivot restant le latin.
  for (col in c("code_p1", "code_tolerances", "espece_sci")) {
    reste <- is.na(out)
    if (!any(reste)) break
    cle <- norm(d[[col]])
    ok <- !is.na(cle) & nzchar(cle)
    idx <- match(xn[reste], cle[ok])
    out[reste] <- d$espar[ok][idx]
  }
  out
}
