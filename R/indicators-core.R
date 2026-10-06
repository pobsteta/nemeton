#' Calculate Nemeton indicators for spatial units
#'
#' Main function to compute biophysical indicators for forest units from spatial layers.
#' Orchestrates indicator calculation with automatic preprocessing and error handling.
#'
#' @param units A \code{nemeton_units} or \code{sf} object representing analysis units
#' @param layers A \code{nemeton_layers} object containing spatial data layers
#' @param indicators Character vector of indicator names to calculate, or "all" for all
#'   41 indicators of \code{\link{list_indicators}} (the source-conditional ones
#'   included: without their source they come back \code{NA} with their status).
#'   Use \code{list_indicators(conditionnels = FALSE)} for the 31 base indicators.
#' @param preprocess Logical. Automatically harmonize CRS and crop layers? Default TRUE.
#' @param parallel Logical. Use parallel computation? (Not implemented in MVP, will error if TRUE)
#' @param progress Logical. Show progress bar? Default TRUE.
#' @param ... Additional arguments passed to indicator functions
#'
#' @return An \code{sf} object with original columns plus one column per calculated
#'   indicator, and the indicator's status column (\code{<code>_status}, e.g.
#'   \code{a3_status = "skipped_no_micro"}) when the indicator writes one.
#'
#' @details
#' The function performs the following steps:
#' \enumerate{
#'   \item Validates inputs (units and layers)
#'   \item If \code{preprocess = TRUE}:
#'     \itemize{
#'       \item Reprojects layers to units CRS
#'       \item Crops layers to units extent
#'     }
#'   \item For each indicator:
#'     \itemize{
#'       \item Calls corresponding \code{indicator_*()} function
#'       \item Handles errors gracefully (warning + NA column)
#'       \item Updates metadata
#'     }
#'   \item Returns enriched sf object
#' }
#'
#' If an indicator calculation fails, a warning is issued and the indicator column
#' is filled with NA, but computation continues for other indicators.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' # Create units
#' units <- nemeton_units(sf::st_read("parcels.gpkg"))
#'
#' # Create layer catalog
#' layers <- nemeton_layers(
#'   rasters = list(
#'     biomass = "biomass.tif",
#'     dem = "dem.tif"
#'   ),
#'   vectors = list(
#'     roads = "roads.gpkg"
#'   )
#' )
#'
#' # Calculate all indicators
#' results <- nemeton_compute(units, layers)
#'
#' # Calculate specific indicators
#' results <- nemeton_compute(
#'   units, layers,
#'   indicators = c("carbon", "biodiversity")
#' )
#' }
#'
#' @seealso
#' \code{\link{list_indicators}} for available indicators in the 12-family framework
#'
#' @export
nemeton_compute <- function(units,
                            layers,
                            indicators = "all",
                            preprocess = TRUE,
                            parallel = FALSE,
                            progress = TRUE,
                            ...) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an {.cls sf} or {.cls nemeton_units} object")
  }

  if (!inherits(layers, "nemeton_layers")) {
    cli::cli_abort("{.arg layers} must be a {.cls nemeton_layers} object")
  }

  # Check parallel (not implemented in MVP)
  if (parallel) {
    cli::cli_abort(c(
      "!" = "Parallel computing not implemented in v0.1.0",
      "i" = "Available in v0.4.0+",
      ">" = "Set {.code parallel = FALSE}"
    ))
  }

  # Get list of available indicators from the 12-family framework
  available_indicators <- list_indicators()

  # Handle "all"
  if (length(indicators) == 1 && indicators[1] == "all") {
    indicators <- available_indicators
  }

  # Validate indicator names
  unknown <- setdiff(indicators, available_indicators)
  if (length(unknown) > 0) {
    n_unknown <- length(unknown)
    cli::cli_warn(c(
      "!" = "Unknown indicator{cli::qty(n_unknown)}{?s}: {.field {unknown}}",
      "i" = "Available: {.field {available_indicators}}",
      ">" = "Skipping unknown indicator{cli::qty(n_unknown)}{?s}"
    ))
    indicators <- intersect(indicators, available_indicators)
  }

  if (length(indicators) == 0) {
    msg_error("indicator_no_valid")
  }

  # Preprocessing
  if (preprocess) {
    msg_info("preprocess_start")
    msg_info("preprocess_harmonizing")

    # Harmonize CRS
    target_crs <- sf::st_crs(units)
    layers <- harmonize_crs(layers, target_crs, verbose = TRUE)

    # Crop to extent
    layers <- crop_to_units(layers, units, buffer = 0)
  }

  # Les indicateurs composites lisent des valeurs déjà calculées sous leur code
  # court : T2 lit N2, E2 lit E1, N3 lit N1/N2/L1/B3. On les calcule en dernier
  # et on leur passe `work`, une copie des unités enrichie des codes courts au
  # fil de la boucle. Avant 0.208.0, chaque indicateur recevait les unités
  # d'origine : N3 et E2 valaient toujours NA et T2 retombait sur 50 (audit 1.0).
  composites <- c("indicateur_t2_changement", "indicateur_e2_evitement",
                  "indicateur_n3_naturalite")
  indicators <- c(setdiff(indicators, composites), intersect(composites, indicators))
  work <- units

  # Initialize result as copy of units
  results <- units

  # Store original metadata if exists
  orig_metadata <- attr(units, "metadata")

  # Calculate each indicator
  n_indicators <- length(indicators)
  msg_info("indicator_computing", n_indicators)

  computed_indicators <- character()
  layers_used <- character()

  for (ind in indicators) {
    if (progress) {
      msg_info("indicator_calculated", ind)
    }

    tryCatch(
      {
        # Dispatch to appropriate indicator function
        res <- .compute_indicator_result(ind, work, layers, ...)
        values <- extract_indicator_value(res, ind)

        # Add to results
        results[[ind]] <- values
        code <- .indicator_short_code(ind)
        if (!is.na(code) && !code %in% names(units)) work[[code]] <- values
        # Statut de l'indicateur (`a3_status`, `r7_status`, ...) : un
        # indicateur conditionnel sans sa source rend NA et dit pourquoi
        # (`skipped_no_micro`, `skipped_no_sufosat`, ...).
        st_col <- if (!is.na(code)) paste0(tolower(code), "_status")
        if (!is.null(st_col) && st_col %in% names(res)) {
          results[[st_col]] <- as.character(res[[st_col]])
        }

        computed_indicators <- c(computed_indicators, ind)
      },
      error = function(e) {
        msg_warn("indicator_failed", ind)
        cli::cli_alert_info("{ind}: {conditionMessage(e)}")
        msg_info("indicator_set_na", ind)
        results[[ind]] <<- rep(NA_real_, nrow(results))
      }
    )
  }

  # Update metadata
  new_metadata <- c(
    orig_metadata,
    list(
      computed_at = Sys.time(),
      indicators_computed = computed_indicators,
      layers_used = names(c(layers$rasters, layers$vectors))
    )
  )

  attr(results, "metadata") <- new_metadata

  n_computed <- length(computed_indicators)
  n_total <- length(indicators)
  msg_success("indicator_computed", n_computed, n_total)

  results
}

# Couches du catalogue à passer aux indicateurs sans argument `layers`.
.INDICATOR_LAYER_ARGS <- list(
  indicateur_b1_protection   = list(protected_areas = c("vector", "protected_areas")),
  indicateur_b3_connectivite = list(bdforet = c("vector", "bdforet"),
                                    dem     = c("raster", "dem"))
)

# Code court d'un indicateur NMT : "indicateur_n1_distance" -> "N1".
.indicator_short_code <- function(indicator) {
  m <- regmatches(indicator, regexec("^indicateur_([a-z][0-9]+)_", indicator))[[1]]
  if (length(m) < 2L) NA_character_ else toupper(m[[2]])
}

# Contrat 1.0 (spec 057 §1) : tout indicateur rend l'objet `units` d'entrée
# (même classe, mêmes lignes, même ordre) augmenté de la colonne de valeur
# nommée par son code court ("C1", "W3", ...). Jamais de vecteur nu.
.indicateur_resultat <- function(units, code, valeur) {
  units[[code]] <- as.numeric(valeur)
  units
}

#' Dispatch indicator calculation to appropriate function
#'
#' Internal function that routes indicator name to corresponding calculation function.
#'
#' @param indicator Character. Name of indicator
#' @param units Spatial units
#' @param layers Layer catalog
#' @param ... Additional arguments
#'
#' @return Numeric vector of indicator values
#' @keywords internal
#' @noRd
compute_indicator <- function(indicator, units, layers, ...) {
  extract_indicator_value(.compute_indicator_result(indicator, units, layers, ...),
                          indicator)
}

# Appelle la fonction d'un indicateur et rend son resultat brut (l'objet
# `units` augmente de la colonne de valeur et, le cas echeant, de sa colonne
# de statut `<code>_status`).
.compute_indicator_result <- function(indicator, units, layers, ...) {
  # Le nom NMT de l'indicateur est aussi le nom de la fonction
  func_name <- indicator

  # Check if function exists
  if (!exists(func_name, mode = "function")) {
    cli::cli_abort(c(
      "Unknown indicator: {indicator}",
      "i" = "Available indicators: {paste(list_indicators(), collapse = ', ')}"
    ))
  }

  # Call the indicator function dynamically. Match the supplied
  # arguments (units, layers and any `...` such as `chm`) to the
  # target function's formals: an indicator that does not declare
  # `layers` / `chm` (e.g. indicateur_p1_volume, which has neither
  # `layers` nor `...`) would otherwise abort with "unused argument".
  # Functions that DO declare `...` receive every argument unchanged.
  func      <- get(func_name, mode = "function")
  call_args <- list(units = units, layers = layers, ...)
  fmls      <- names(formals(func))
  # Indicateurs qui n'acceptent pas `layers` mais prennent leurs couches en
  # arguments nommés : on les alimente depuis le catalogue, sans écraser un
  # argument passé explicitement. Sans cela B1 et B3 rendaient NA alors que
  # `layers$bdforet` existait (audit 1.0).
  depuis_layers <- .INDICATOR_LAYER_ARGS[[indicator]]
  for (arg in names(depuis_layers)) {
    if (!arg %in% fmls || !is.null(call_args[[arg]])) next
    spec <- depuis_layers[[arg]]
    val <- if (identical(spec[[1]], "raster")) resolve_raster_layer(layers, spec[[2]])
           else resolve_vector_layer(layers, spec[[2]])
    if (!is.null(val)) call_args[[arg]] <- val
  }
  if (!"..." %in% fmls) {
    call_args <- call_args[names(call_args) %in% fmls]
  }
  do.call(func, call_args)
}


#' Extract an indicator's value column from its result
#'
#' Single source of truth for the Nemeton indicator naming convention:
#' every indicator function returns the `units` object (an `sf` /
#' `data.frame`) with the computed value added under a column named by the
#' family short code (`indicateur_p1_volume` -> `"P1"`,
#' `indicateur_r1_feu` -> `"R1"`, ...). This helper resolves that column to
#' a plain numeric vector so both the core dispatcher
#' ([nemeton_compute()] via `compute_indicator()`) and downstream callers
#' (e.g. the `nemetonshiny` compute loop) share **one** convention and can
#' never drift apart.
#'
#' Resolution order for an `sf` / `data.frame` result:
#' \enumerate{
#'   \item the short code derived from the indicator name
#'     (`indicateur_<code>_...` -> upper-case `<code>`, e.g. `P1`);
#'   \item the NMT indicator name itself (or its upper-case form);
#'   \item any single `"<Letter><digit>"` column (optionally suffixed
#'     `_norm`), preferring columns \strong{not} present in `exclude`
#'     (pass the pre-existing input column names so a freshly added value
#'     column wins over a same-shaped attribute already on the units).
#' }
#' A bare vector is an error: since 1.0.0 (spec 057) no indicator returns
#' one.
#'
#' @param result The raw return value of an indicator function (an `sf` or
#'   a `data.frame`).
#' @param indicator Character. The NMT indicator name (function name),
#'   e.g. `"indicateur_p1_volume"`.
#' @param exclude Character vector of column names to treat as
#'   pre-existing (not the freshly computed value) when falling back to
#'   the `"<Letter><digit>"` pattern. Default none.
#'
#' @return A numeric vector of the indicator's per-unit values.
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @seealso [nemeton_compute()]
#' @export
extract_indicator_value <- function(result, indicator,
                                    exclude = character(0)) {
  if (inherits(result, "sf") || inherits(result, "data.frame")) {
    short <- toupper(sub("^indicateur_([a-z][0-9]+)_.*$", "\\1", indicator))
    if (short %in% names(result)) {
      return(result[[short]])
    }
    hit <- intersect(c(indicator, toupper(indicator)), names(result))
    if (length(hit) >= 1L) {
      return(result[[hit[1]]])
    }
    code_cols <- grep("^[A-Z][0-9](_norm)?$", names(result), value = TRUE)
    fresh     <- setdiff(code_cols, exclude)
    if (length(fresh) >= 1L) {
      return(result[[fresh[1]]])
    }
    if (length(code_cols) >= 1L) {
      return(result[[code_cols[1]]])
    }
    # Message court sur deux lignes : cli replie a la largeur du terminal
    cli::cli_abort(c(
      "Indicator '{indicator}' returned a data frame",
      "x" = "It has no recognizable value column."
    ))
  }

  cli::cli_abort(c(
    "Indicator '{indicator}' did not return a data frame",
    "x" = "Since 1.0.0 an indicator returns {.arg units} with its value column."
  ))
}

#' List available indicators
#'
#' Returns the indicators of the 12-family framework: the **41 indicators**
#' of [indicator_families()], in the same order, including the
#' source-conditional ones.
#'
#' Ten indicators are **conditional**: they need a source that the public
#' NDP 0 layers do not provide, and return `NA` (with a `<code>_status`
#' column such as `"skipped_no_micro"`) when it is absent, never an error.
#' They are B4 and L3 (Sentinel-2 spectral diversity), W4, A3, A4 and R6
#' (precomputed microclimate), A5 (land-surface temperature), R5 (FORDEAD or
#' RECONFORT dieback), R7 (daily minimum temperature) and T3 (SUFOSAT
#' clear-cuts). `conditionnels = FALSE` keeps only the 31 indicators that the
#' base layers can compute.
#'
#' @param category Character. Filter by category: `"all"` (default),
#'   `"biophysical"`, `"landscape"`, `"risk"`, `"temporal"`, `"social"`,
#'   `"productive"`, `"energy"`, `"naturalness"`.
#' @param return_type Character. Return `"names"` (default) or `"details"`
#'   (data.frame with descriptions).
#' @param conditionnels Logical. Include the ten source-conditional
#'   indicators? Default `TRUE` (all 41).
#'
#' @return Character vector of indicator names, or a data.frame with columns
#'   `name`, `code`, `family`, `category`, `description`, `conditionnel`
#'   (logical) and `source_conditionnelle` (the missing source that leaves
#'   the indicator `NA`, `NA` for the base indicators).
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#' Since 1.0.0 the list holds all 41 indicators (31 before) and the details
#' carry `code`, `conditionnel` and `source_conditionnelle`.
#'
#' @examples
#' # All 41 indicator names
#' list_indicators()
#'
#' # Only those computable from the base layers
#' list_indicators(conditionnels = FALSE)
#'
#' # Details
#' head(list_indicators(return_type = "details"))
#'
#' @export
list_indicators <- function(category = "all", return_type = c("names", "details"),
                            conditionnels = TRUE) {
  return_type <- match.arg(return_type)

  # La liste vient de la table des familles (source unique, 41 indicateurs) ;
  # seules la categorie, la description et la source conditionnelle sont
  # propres a cette fonction.
  lab <- indicator_labels(lang = "en")
  meta <- .INDICATOR_META[lab$code, , drop = FALSE]
  if (anyNA(meta$category)) {
    cli::cli_abort(c(
      "Indicator metadata missing for {.val {lab$code[is.na(meta$category)]}}.",
      "i" = "Add it to {.code .INDICATOR_META} (R/indicators-core.R)."
    ))
  }
  indicators <- data.frame(
    name = lab$column_name,
    code = lab$code,
    family = lab$family,
    category = meta$category,
    description = meta$description,
    conditionnel = !is.na(meta$source),
    source_conditionnelle = meta$source,
    stringsAsFactors = FALSE
  )
  rownames(indicators) <- NULL

  if (!isTRUE(conditionnels)) {
    indicators <- indicators[!indicators$conditionnel, , drop = FALSE]
  }
  if (category != "all") {
    indicators <- indicators[indicators$category == category, , drop = FALSE]
  }
  rownames(indicators) <- NULL

  if (return_type == "names") indicators$name else indicators
}

# Categorie, description et source conditionnelle de chaque indicateur, par
# code court. `source` = NA pour un indicateur calculable depuis les couches
# de base ; sinon la source dont l'absence le laisse a NA (avec son statut).
.INDICATOR_META <- local({
  m <- matrix(c(
    "C1", "biophysical", "Carbon stock via biomass allometric models (C1)", NA,
    "C2", "biophysical", "Vegetation vitality via NDVI (C2)", NA,
    "B1", "biophysical", "Biodiversity protection status (B1)", NA,
    "B2", "biophysical", "Structural diversity (B2)", NA,
    "B3", "biophysical", "Habitat connectivity (B3)", NA,
    "B4", "biophysical", "Spectral alpha diversity, Sentinel-2 (B4)", "spectral",
    "W1", "biophysical", "Water regulation via stream network (W1)", NA,
    "W2", "biophysical", "Water regulation via wetlands (W2)", NA,
    "W3", "biophysical", "Water regulation via Topographic Wetness Index (W3)", NA,
    "W4", "biophysical", "Under-canopy summer vapour-pressure deficit (W4)", "microclimate",
    "A1", "biophysical", "Air quality regulation via canopy coverage (A1)", NA,
    "A2", "biophysical", "Air quality improvement potential (A2)", NA,
    "A3", "biophysical", "Under-canopy summer maximum temperature (A3)", "microclimate",
    "A4", "biophysical", "Canopy thermal buffering (A4)", "microclimate",
    "A5", "biophysical", "Urban cooling from land-surface temperature (A5)", "lst",
    "F1", "biophysical", "Soil fertility assessment (F1)", NA,
    "F2", "biophysical", "Soil erosion risk (F2)", NA,
    "L1", "landscape", "Sylvosphere, edge effect (L1)", NA,
    "L2", "landscape", "Landscape fragmentation (L2)", NA,
    "L3", "landscape", "Spectral beta heterogeneity, Sentinel-2 (L3)", "spectral",
    "T1", "temporal", "Stand age and maturity (T1)", NA,
    "T2", "temporal", "Temporal change detection (T2)", NA,
    "T3", "temporal", "Recent clear-cuts, SUFOSAT (T3)", "sufosat",
    "R1", "risk", "Fire risk assessment (R1)", NA,
    "R2", "risk", "Storm vulnerability (R2)", NA,
    "R3", "risk", "Drought risk (R3)", NA,
    "R4", "risk", "Browsing pressure (R4)", NA,
    "R5", "risk", "Forest dieback, FORDEAD or RECONFORT (R5)", "dieback",
    "R6", "risk", "Microclimate sensitivity to heatwaves (R6)", "microclimate",
    "R7", "risk", "Late frost risk (R7)", "tmin",
    "S1", "social", "Trail network accessibility (S1)", NA,
    "S2", "social", "General accessibility (S2)", NA,
    "S3", "social", "Proximity to population centers (S3)", NA,
    "P1", "productive", "Timber volume production (P1)", NA,
    "P2", "productive", "Site productivity (P2)", NA,
    "P3", "productive", "Wood quality (P3)", NA,
    "E1", "energy", "Fuelwood energy potential (E1)", NA,
    "E2", "energy", "Fossil fuel avoidance via carbon sequestration (E2)", NA,
    "N1", "naturalness", "Distance to natural reference (N1)", NA,
    "N2", "naturalness", "Ecological continuity (N2)", NA,
    "N3", "naturalness", "Composite naturalness index (N3)", NA
  ), ncol = 4, byrow = TRUE)
  data.frame(category = m[, 2], description = m[, 3], source = m[, 4],
             row.names = m[, 1], stringsAsFactors = FALSE)
})
