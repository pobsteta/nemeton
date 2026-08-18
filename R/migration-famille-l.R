# Migration des colonnes de la famille L (spec 045)
#
# Les deux slugs historiques annoncaient l'inverse de ce qu'ils portaient. Ils
# sont retires definitivement : aucun des deux n'est recycle, faute de quoi une
# donnee deja ecrite changerait de sens sans qu'aucune relecture puisse s'en
# apercevoir. Les jeux produits avant 0.176.0 se renomment ici, sans qu'une
# seule valeur bouge.

# Ancien nom -> nouveau nom. L'ordre est sans importance : les deux ensembles
# sont disjoints, precisement parce qu'aucun slug n'est reutilise.
.L_LEGACY_COLUMNS <- c(
  indicateur_l2_fragmentation = "indicateur_l1_effet_lisiere",
  indicateur_l1_sylvosphere   = "indicateur_l2_morcellement"
)

#' Rename legacy landscape (L) columns
#'
#' @description
#' Renames the two landscape columns that were retired in 0.176.0, **without
#' touching a single value**:
#'
#' ```
#' indicateur_l2_fragmentation -> indicateur_l1_effet_lisiere   (sylvosphere)
#' indicateur_l1_sylvosphere   -> indicateur_l2_morcellement    (fragmentation)
#' ```
#'
#' Both old names announced the opposite of what they carried — see spec 045.
#' The `_norm` variants produced by [normalize_indicators()] follow. Short-code
#' columns (`L1`, `L2`) are left alone: they were already paired correctly.
#'
#' Call it once when reading a dataset computed before 0.176.0 (project
#' parquet, PostGIS table, cached GeoPackage). A dataset that carries neither
#' legacy column is returned unchanged, so the call is safe to keep in a
#' reading path.
#'
#' @param data A `data.frame` or `sf` object holding indicator columns.
#' @param quiet Logical. `TRUE` silences the report of what was renamed.
#'   Default `FALSE`.
#'
#' @return `data`, with the legacy columns renamed. Attributes, row order,
#'   geometry and values are untouched.
#'
#' @section Conflicts:
#' When a legacy column and its target both exist, the target is kept, the
#' legacy one is dropped, and a warning names both — an already migrated
#' dataset re-read alongside a stale export must not silently overwrite the
#' current values.
#'
#' @seealso [indicateur_l1_effet_lisiere()], [indicateur_l2_morcellement()]
#'
#' @examples
#' old <- data.frame(
#'   id = 1:2,
#'   indicateur_l2_fragmentation = c(36.4, 34.5),
#'   indicateur_l1_sylvosphere = c(71.2, 68.0)
#' )
#' names(migrer_colonnes_l(old, quiet = TRUE))
#'
#' @export
migrer_colonnes_l <- function(data, quiet = FALSE) {
  if (!is.data.frame(data)) {
    stop("data must be a data.frame or sf object", call. = FALSE)
  }

  # Les variantes _norm suivent la meme correspondance que les colonnes brutes.
  mapping <- c(
    .L_LEGACY_COLUMNS,
    stats::setNames(
      paste0(unname(.L_LEGACY_COLUMNS), "_norm"),
      paste0(names(.L_LEGACY_COLUMNS), "_norm")
    )
  )

  present <- intersect(names(mapping), names(data))
  if (length(present) == 0) {
    return(data)
  }

  renamed <- character(0)
  for (old in present) {
    new <- mapping[[old]]

    if (new %in% names(data)) {
      cli::cli_warn(c(
        "Both {.field {old}} and {.field {new}} are present.",
        "i" = "Keeping {.field {new}} and dropping the legacy column."
      ))
      data[[old]] <- NULL
      next
    }

    names(data)[names(data) == old] <- new
    renamed <- c(renamed, sprintf("%s -> %s", old, new))
  }

  if (!quiet && length(renamed) > 0) {
    cli::cli_alert_success(
      "Renamed {length(renamed)} legacy L column{?s}: {renamed}"
    )
  }

  data
}
