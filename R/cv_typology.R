#' CV Typology Lookup for Forest Sampling
#'
#' @description
#' Reference coefficient-of-variation (CV) lookup tables used by
#' \code{\link{compute_sample_size}} to size an inventory plan from a
#' target relative error.
#'
#' Two CSV files back this module (both under \code{inst/extdata}):
#' \itemize{
#'   \item \code{cv_typology.csv} — 8 generic forest contexts with
#'     low / mid / high CV bounds on basal area (G/ha, the IFN / PPtools
#'     convention). Derived from expert literature compiled with
#'     Pascal Obstetar (2026).
#'   \item \code{bdforet_v2_mapping.csv} — the 32 BD Forêt v2 TFV
#'     codes mapped to one of the generic contexts, with a confidence
#'     flag and a secondary candidate for ambiguous classes.
#' }
#'
#' Both files are editable: the user is invited to override them via
#' \code{cv_typology(file = ...)} / \code{bdforet_v2_mapping(file = ...)}
#' to reflect local silvicultural reality.
#'
#' @name cv_typology_lookup
#' @keywords internal
NULL


#' CV typology reference table
#'
#' Loads the generic forest-context / CV lookup table. The returned
#' frame has columns:
#' \itemize{
#'   \item \code{context_key}: NMT snake_case key.
#'   \item \code{context_fr} / \code{context_en}: human labels.
#'   \item \code{variable}: target variable (\code{"G"} for basal area).
#'   \item \code{level}: \code{"peuplement"} (stand-level),
#'     \code{"essence"} (single species within a mixed stand), or
#'     \code{"classe_diametre"} (per diameter class).
#'   \item \code{cv_low}, \code{cv_mid}, \code{cv_high}: CV as a
#'     fraction (e.g., 0.25 for 25 \%).
#'   \item \code{notes_fr}: one-line rationale.
#' }
#'
#' @param file Optional path to a user-supplied CSV (same columns).
#'   Default reads \code{inst/extdata/cv_typology.csv}.
#'
#' @return A data.frame, 8 rows.
#' @export
cv_typology <- function(file = NULL) {
  path <- file %||% system.file("extdata", "cv_typology.csv",
                                package = "nemeton")
  if (!nzchar(path) || !file.exists(path)) {
    cli::cli_abort("cv_typology.csv not found.")
  }
  utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA"))
}


#' BD Forêt v2 -> CV context mapping
#'
#' @param file Optional path to a user-supplied CSV (same columns as
#'   \code{inst/extdata/bdforet_v2_mapping.csv}).
#'
#' @return A data.frame with columns \code{tfv_code}, \code{label_fr},
#'   \code{species_class} (NMT species class, \code{NA} for non-forest / no
#'   canopy TFV), \code{context_key}, \code{confidence} (\code{"clear"} or
#'   \code{"ambiguous"}), \code{alt_context_key}, \code{notes_fr}.
#'
#' @export
bdforet_v2_mapping <- function(file = NULL) {
  path <- file %||% system.file("extdata", "bdforet_v2_mapping.csv",
                                package = "nemeton")
  if (!nzchar(path) || !file.exists(path)) {
    cli::cli_abort("bdforet_v2_mapping.csv not found.")
  }
  utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA"))
}


#' Map BD Forêt v2 TFV codes to NMT species classes
#'
#' @description
#' Translate BD Forêt v2 vegetation-formation-type (TFV) codes into the
#' corresponding NMT species class ([list_species_classes()]), via
#' [bdforet_v2_mapping()]. Named essences map to their class (e.g. `FF1-09-09`
#' hêtre → `essence_hetraie`); generic or mixed formations map to
#' `essence_mixte`; non-forest / no-canopy TFV (bare, moorland, grassland)
#' return `NA`. Lets the app pre-fill the reGénération target-species selector
#' with the classes actually present on a BD Forêt v2 coverage.
#'
#' @param tfv_code Character vector of TFV codes.
#' @param mapping Optional override table (as returned by
#'   [bdforet_v2_mapping()]).
#'
#' @return Character vector of species-class codes (same length as `tfv_code`),
#'   `NA` where the TFV has no forest species class or is unknown.
#' @seealso [bdforet_v2_mapping()], [regen_species_choices()],
#'   [map_bdforet_essence()]
#' @export
map_tfv_to_species_class <- function(tfv_code, mapping = NULL) {
  tbl <- if (is.null(mapping)) bdforet_v2_mapping() else mapping
  tbl$species_class[match(as.character(tfv_code), tbl$tfv_code)]
}


#' Read a CV value from the typology table
#'
#' @param context_key Character. One of
#'   \code{cv_typology()$context_key}.
#' @param position Character. Which bound to read: \code{"low"},
#'   \code{"mid"} (default, central estimate), or \code{"high"}
#'   (conservative).
#' @param table Optional override table (returned by
#'   \code{\link{cv_typology}}).
#'
#' @return Numeric CV (fraction).
#'
#' @export
cv_lookup <- function(context_key,
                      position = c("mid", "low", "high"),
                      table = NULL) {
  position <- match.arg(position)
  tbl <- table %||% cv_typology()
  row <- tbl[tbl$context_key == context_key, , drop = FALSE]
  if (nrow(row) == 0L) {
    cli::cli_abort("context_key {.val {context_key}} not found.")
  }
  col <- switch(position, low = "cv_low", mid = "cv_mid", high = "cv_high")
  as.numeric(row[[col]][1])
}


#' Compute an area-weighted CV from a BD Forêt v2 coverage
#'
#' For each polygon in \code{bdforet_sf}, look up the generic forest
#' context (via \code{\link{bdforet_v2_mapping}}) and read the CV at
#' the requested \code{position}. The final CV is the arithmetic mean
#' of the per-polygon CVs, weighted by the polygon area (intersected
#' with \code{aoi} when provided). Polygons mapped to \code{NA}
#' (non-forest, coupe rase, lande) are dropped.
#'
#' @param bdforet_sf sf. Polygons from BD Forêt v2 with a TFV code
#'   column (see \code{tfv_col}).
#' @param position Character. CV bound to read (\code{"mid"},
#'   \code{"low"}, \code{"high"}).
#' @param aoi Optional sf polygon. When provided, polygons are
#'   intersected with it before area weighting.
#' @param tfv_col Character. Column name holding the TFV code.
#'   Default \code{"TFV"}.
#' @param mapping Optional override of the BD Forêt mapping (same
#'   columns as \code{bdforet_v2_mapping()}).
#' @param typology Optional override of the typology table (same
#'   columns as \code{cv_typology()}).
#'
#' @return A list with:
#'   \itemize{
#'     \item \code{cv}: the aggregated CV (numeric fraction).
#'     \item \code{position}: the bound used.
#'     \item \code{coverage}: total mapped area / total input area
#'       (sanity check — how much of the AOI was classified).
#'     \item \code{summary}: a per-TFV data.frame (\code{tfv_code},
#'       \code{area_ha}, \code{context_key}, \code{cv}, \code{share}),
#'       sorted by descending area.
#'     \item \code{ambiguous}: data.frame of TFV codes where the
#'       mapping is flagged ambiguous (the user may want to override
#'       via the alt_context_key column).
#'     \item \code{unmapped}: TFV codes present in the data but absent
#'       from the mapping table.
#'   }
#'
#' @export
cv_from_bdforet <- function(bdforet_sf,
                            position = c("mid", "low", "high"),
                            aoi = NULL,
                            tfv_col = "TFV",
                            mapping = NULL,
                            typology = NULL) {
  position <- match.arg(position)
  if (!inherits(bdforet_sf, "sf")) {
    cli::cli_abort("{.arg bdforet_sf} must be an sf object.")
  }
  if (!tfv_col %in% names(bdforet_sf)) {
    cli::cli_abort("Column {.val {tfv_col}} not found in bdforet_sf.")
  }

  map <- mapping %||% bdforet_v2_mapping()
  tbl <- typology %||% cv_typology()

  # Restrict to AOI if provided.
  if (!is.null(aoi)) {
    if (!inherits(aoi, "sf") && !inherits(aoi, "sfc")) {
      cli::cli_abort("{.arg aoi} must be an sf / sfc object.")
    }
    aoi <- sf::st_transform(aoi, sf::st_crs(bdforet_sf))
    bdforet_sf <- suppressWarnings(sf::st_intersection(bdforet_sf, aoi))
  }

  area_m2 <- as.numeric(sf::st_area(bdforet_sf))
  tfv_raw <- as.character(bdforet_sf[[tfv_col]])
  # Normalize TFV values: trim, turn underscores / whitespace into
  # "-", uppercase. Handles both code-style inputs
  # ("FF2-64-64", "FF2_64_64", "ff2 64 64") and the French libellé
  # that IGN WFS exposes in some columns ("Forêt fermée à mélange
  # de conifères" -> "FORÊT-FERMÉE-À-MÉLANGE-DE-CONIFÈRES").
  tfv_key <- trimws(tfv_raw)
  tfv_key <- gsub("[_[:space:]]+", "-", tfv_key)
  tfv_key <- toupper(tfv_key)
  total_area <- sum(area_m2, na.rm = TRUE)

  # Per-value aggregation (both code and label flows end up here).
  df <- data.frame(tfv_key = tfv_key, area_m2 = area_m2,
                   stringsAsFactors = FALSE)
  df <- stats::aggregate(area_m2 ~ tfv_key, data = df, FUN = sum)
  df$area_ha <- df$area_m2 / 10000

  # --- Two-pass join: try the TFV code first, then the normalized
  # French label. The mapping CSV carries both columns since the IGN
  # WFS `tfv` field sometimes exposes the libellé instead of the
  # code.
  lookup_code <- map[, c("tfv_code", "context_key", "confidence"),
                     drop = FALSE]
  names(lookup_code)[1] <- "tfv_key"
  df <- merge(df, lookup_code, by = "tfv_key", all.x = TRUE,
              suffixes = c("", ".map"))
  # Track whether the row was found in the mapping at all (a row with
  # context_key = NA AND found in the mapping is a legitimate
  # "non-forest" entry — FF0, FO0, LA4, LA6 — that should NOT be
  # reported as unmapped).
  known_code <- df$tfv_key %in% map$tfv_code

  if ("label_key" %in% names(map) && any(is.na(df$context_key) & !known_code)) {
    lookup_lab <- map[!is.na(map$label_key),
                      c("label_key", "context_key", "confidence"),
                      drop = FALSE]
    names(lookup_lab) <- c("tfv_key", "context_key_lab", "confidence_lab")
    df <- merge(df, lookup_lab, by = "tfv_key", all.x = TRUE)
    fill <- is.na(df$context_key) & !is.na(df$context_key_lab)
    df$context_key[fill] <- df$context_key_lab[fill]
    df$confidence[fill] <- df$confidence_lab[fill]
    df$context_key_lab <- NULL
    df$confidence_lab  <- NULL
    known_code <- known_code |
                  (df$tfv_key %in% map$label_key[!is.na(map$label_key)])
  }
  names(df)[names(df) == "tfv_key"] <- "tfv_code"

  # Only codes absent from the mapping (both columns) land in
  # `unmapped`. Codes mapped explicitly to NA (non-forest) are known
  # and silently dropped from the CV computation.
  unmapped <- df$tfv_code[!known_code]

  # Drop NA context_key rows (coupe rase, non-forest + any unmapped
  # codes) from the forest-area aggregation.
  keep <- !is.na(df$context_key)
  df_forest <- df[keep, , drop = FALSE]

  # Lookup CV per row.
  df_forest$cv <- vapply(df_forest$context_key, function(k) {
    tryCatch(cv_lookup(k, position = position, table = tbl),
             error = function(e) NA_real_)
  }, numeric(1))

  forest_area <- sum(df_forest$area_m2, na.rm = TRUE)
  if (forest_area <= 0) {
    cli::cli_warn("No mappable forest polygons found; returning NA CV.")
    return(list(cv = NA_real_, position = position,
                coverage = 0, summary = df_forest[0, ],
                ambiguous = df_forest[0, ], unmapped = unmapped))
  }

  df_forest$share <- df_forest$area_m2 / forest_area
  df_forest <- df_forest[order(-df_forest$area_m2), , drop = FALSE]

  cv <- sum(df_forest$cv * df_forest$share, na.rm = TRUE)
  coverage <- if (total_area > 0) forest_area / total_area else NA_real_
  ambiguous <- df_forest[!is.na(df_forest$confidence) &
                          df_forest$confidence == "ambiguous",
                         , drop = FALSE]

  list(
    cv        = cv,
    position  = position,
    coverage  = coverage,
    summary   = df_forest[, c("tfv_code", "area_ha", "context_key",
                              "cv", "share")],
    ambiguous = ambiguous[, c("tfv_code", "area_ha", "context_key"),
                          drop = FALSE],
    unmapped  = unmapped
  )
}
