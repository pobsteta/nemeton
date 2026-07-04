#' NDP System (Niveau De Precision)
#'
#' @description
#' NDP measures the QUALITY of input data, not the number of families calculated.
#' All 12 families are always calculated, but with increasing precision as NDP rises.
#'
#' The system uses Fibonacci weighting (1, 1, 2, 3, 5) and golden ratio confidence
#' (phi) to express data reliability.
#'
#' @name ndp
#' @keywords internal
NULL


# ================================================================
# NDP_LEVELS: Configuration des 5 niveaux de precision
# ================================================================

#' NDP level definitions
#'
#' Each level defines its Fibonacci weight, cumulative confidence, and
#' the data sources that characterize it.
#'
#' @format A list of 5 elements, each with: ndp, key, name, fibonacci,
#'   confidence, sources.
#' @keywords internal
NDP_LEVELS <- list(
  list(
    ndp = 0L,
    key = "ndp_decouverte",
    name = "D\u00e9couverte",
    fibonacci = 1L,
    confidence = 1 / 12,
    sources = c("sentinel_2", "worldclim", "bd_topo", "mnt_25m")
  ),
  list(
    ndp = 1L,
    key = "ndp_observation",
    name = "Observation",
    fibonacci = 1L,
    confidence = 2 / 12,
    sources = c("ign_rge_alti", "bd_ortho", "lidar_hd")
  ),
  list(
    ndp = 2L,
    key = "ndp_exploration",
    name = "Exploration",
    fibonacci = 2L,
    confidence = 4 / 12,
    sources = c("drone_rgb", "lidar_drone")
  ),
  list(
    ndp = 3L,
    key = "ndp_diagnostic",
    name = "Diagnostic",
    fibonacci = 3L,
    confidence = 7 / 12,
    sources = c("inventaire_terrain")
  ),
  list(
    ndp = 4L,
    key = "ndp_jumeau",
    name = "Jumeau",
    fibonacci = 5L,
    confidence = 12 / 12,
    sources = c("scanner_terrestre", "modele_3d")
  )
)


# ================================================================
# Accessors
# ================================================================

#' Get NDP level configuration
#'
#' Returns the full configuration list for a given NDP level.
#'
#' @param ndp Integer. NDP level (0-4).
#'
#' @return A list with elements: ndp, key, name, fibonacci, confidence, sources.
#'
#' @examples
#' get_ndp_level(0)
#' get_ndp_level(4)
#'
#' @export
get_ndp_level <- function(ndp) {
  ndp <- as.integer(ndp)
  if (length(ndp) != 1 || is.na(ndp) || ndp < 0L || ndp > 4L) {
    stop("ndp must be a single integer between 0 and 4", call. = FALSE)
  }
  NDP_LEVELS[[ndp + 1L]]
}


#' Get NDP level name
#'
#' @param ndp Integer. NDP level (0-4).
#'
#' @return Character. French name of the level.
#'
#' @examples
#' get_ndp_name(0) # "Decouverte"
#' get_ndp_name(4) # "Jumeau"
#'
#' @export
get_ndp_name <- function(ndp) {
  get_ndp_level(ndp)$name
}


#' Get NDP Fibonacci weight
#'
#' @param ndp Integer. NDP level (0-4).
#'
#' @return Integer. Fibonacci weight (1, 1, 2, 3, or 5).
#'
#' @examples
#' get_ndp_weight(0) # 1
#' get_ndp_weight(4) # 5
#'
#' @export
get_ndp_weight <- function(ndp) {
  get_ndp_level(ndp)$fibonacci
}


#' Get NDP confidence ratio
#'
#' Returns the cumulative confidence phi, calculated as the ratio of
#' cumulative Fibonacci weight up to this level over the total (12).
#'
#' @param ndp Integer. NDP level (0-4).
#'
#' @return Numeric. Confidence ratio between 0 and 1.
#'
#' @examples
#' get_ndp_confidence(0) # 1/12 ~ 0.083
#' get_ndp_confidence(4) # 1.0
#'
#' @export
get_ndp_confidence <- function(ndp) {
  get_ndp_level(ndp)$confidence
}


# ================================================================
# ndp_table
# ================================================================

#' NDP levels as a data.frame
#'
#' Returns a data.frame summarizing the 5 NDP levels with their
#' Fibonacci weights and confidence ratios.
#'
#' @return A data.frame with columns: ndp, key, name, fibonacci, confidence.
#'
#' @examples
#' ndp_table()
#'
#' @export
ndp_table <- function() {
  data.frame(
    ndp = vapply(NDP_LEVELS, `[[`, integer(1), "ndp"),
    key = vapply(NDP_LEVELS, `[[`, character(1), "key"),
    name = vapply(NDP_LEVELS, `[[`, character(1), "name"),
    fibonacci = vapply(NDP_LEVELS, `[[`, integer(1), "fibonacci"),
    confidence = vapply(NDP_LEVELS, `[[`, numeric(1), "confidence"),
    stringsAsFactors = FALSE
  )
}


# ================================================================
# detect_ndp
# ================================================================

#' Detect NDP level and ML augmentation from data
#'
#' Determines the NDP level and ML-augmented flags from the data sources present
#' on the dataset. Detection is based on attributes set on the data (e.g.
#' \code{has_lidar_hd}, \code{has_drone_rgb}, \code{chm_source}).
#'
#' The NDP is the highest level for which ALL required sources are present.
#' ML-augmented flags (ADR-011 amended) do NOT change the base NDP level —
#' they are reported separately via the \code{augmented} vector.
#'
#' @param data An sf object or data.frame with source attributes.
#'
#' @return An object of class \code{"ndp_result"} — a list with:
#'   \describe{
#'     \item{level}{Integer. Detected NDP level (0-4).}
#'     \item{confidence}{Numeric. Fibonacci confidence phi for \code{level}.}
#'     \item{augmented}{Character vector. ML-augmentation flags (e.g.
#'       \code{"height_ml"} when \code{chm_source = "opencanopy"}).}
#'     \item{sources}{Character vector. Data sources detected as present.}
#'   }
#'   The object also carries \code{level} as an integer attribute so
#'   \code{as.integer(result)} and arithmetic comparisons still work.
#'
#' @details
#' Source attributes checked (cumulative):
#' \itemize{
#'   \item NDP 0: Always available (public: Sentinel-2, WorldClim, BD TOPO, MNT 25m)
#'   \item NDP 1: \code{has_lidar_hd = TRUE}
#'   \item NDP 2: NDP 1 + \code{has_drone_rgb = TRUE}
#'   \item NDP 3: NDP 2 + \code{has_inventaire_terrain = TRUE}
#'   \item NDP 4: NDP 3 + \code{has_scanner_terrestre = TRUE}
#' }
#'
#' ML-augmentation flags recognised:
#' \itemize{
#'   \item \code{"height_ml"} : \code{attr(data, "chm_source") == "opencanopy"}
#'   \item \code{"species_ml"} : \code{attr(data, "species_source") \%in\% c("tree_sat", "maestro")}
#'   \item \code{"texture_ml"} : \code{attr(data, "texture_source") == "maestro"}
#'   \item \code{"lai_ml"} : \code{attr(data, "lai_source") == "prosail_s2"} (spec 033)
#' }
#'
#' @note
#' Breaking change in nemeton 0.16.0: \code{detect_ndp()} used to return a
#' plain integer. It now returns an \code{ndp_result} list.
#' Use \code{result$level} or \code{as.integer(result)} for the numeric level.
#'
#' @examples
#' # Default: NDP 0, no ML augmentation
#' df <- data.frame(x = 1)
#' r <- detect_ndp(df)
#' r$level
#' r$augmented
#'
#' # With LiDAR HD: NDP 1
#' attr(df, "has_lidar_hd") <- TRUE
#' detect_ndp(df)$level
#'
#' # With opencanopy CHM: NDP 0 but augmented
#' df2 <- data.frame(x = 1)
#' attr(df2, "chm_source") <- "opencanopy"
#' detect_ndp(df2)$augmented  # "height_ml"
#'
#' @export
detect_ndp <- function(data) {
  if (is.null(data)) {
    return(new_ndp_result(0L, character(0), character(0)))
  }

  # Source markers par niveau (cumulatifs)
  # NDP 0 est toujours disponible (donnees publiques)
  level_checks <- list(
    # NDP 1 requiert LiDAR HD
    function(d) isTRUE(attr(d, "has_lidar_hd")),
    # NDP 2 requiert drone
    function(d) isTRUE(attr(d, "has_drone_rgb")) || isTRUE(attr(d, "has_lidar_drone")),
    # NDP 3 requiert inventaire terrain
    function(d) isTRUE(attr(d, "has_inventaire_terrain")),
    # NDP 4 requiert scanner terrestre
    function(d) isTRUE(attr(d, "has_scanner_terrestre")) || isTRUE(attr(d, "has_modele_3d"))
  )

  level <- 0L
  for (check in level_checks) {
    if (check(data)) {
      level <- level + 1L
    } else {
      break
    }
  }

  # Alternative path for QField data: users who collect field plots
  # without going through drone/LiDAR still get an NDP bump.
  # Heuristic:
  #   * >=1 placette recorded        -> at least NDP 2 (Exploration)
  #   * >=10 trees per plot on avg   -> NDP 3 (Diagnostic)
  field_plots <- as.integer(attr(data, "field_plots_count") %||% 0L)
  field_trees <- as.integer(attr(data, "field_trees_count") %||% 0L)
  if (field_plots >= 1L) {
    trees_per_plot <- field_trees / max(1L, field_plots)
    field_level <- if (trees_per_plot >= 10) 3L else 2L
    level <- max(level, field_level)
  }

  # Sources presentes (cumulatif)
  sources <- c("sentinel_2", "worldclim", "bd_topo", "mnt_25m")
  if (isTRUE(attr(data, "has_lidar_hd"))) {
    sources <- c(sources, "ign_rge_alti", "bd_ortho", "lidar_hd")
  }
  if (isTRUE(attr(data, "has_drone_rgb"))) sources <- c(sources, "drone_rgb")
  if (isTRUE(attr(data, "has_lidar_drone"))) sources <- c(sources, "lidar_drone")
  if (isTRUE(attr(data, "has_inventaire_terrain"))) {
    sources <- c(sources, "inventaire_terrain")
  }
  if (isTRUE(attr(data, "has_scanner_terrestre"))) {
    sources <- c(sources, "scanner_terrestre")
  }
  if (isTRUE(attr(data, "has_modele_3d"))) sources <- c(sources, "modele_3d")
  n_plots_attr <- attr(data, "field_plots_count")
  if (!is.null(n_plots_attr) && as.integer(n_plots_attr) > 0L) {
    sources <- c(sources, "field_qfield")
  }

  # Flags d'augmentation ML (ADR-011 amende)
  #   - "height_ml"    : CHM prédit par apprentissage (Open-Canopy,
  #                      NDP de base inchangé — reste à 0)
  #   - "height_lidar" : CHM mesuré directement (LiDAR HD IGN,
  #                      déjà pris en compte dans le niveau via
  #                      has_lidar_hd -> NDP 1 "Observation").
  augmented <- character(0)
  chm_source <- attr(data, "chm_source")
  if (!is.null(chm_source) && identical(as.character(chm_source), "opencanopy")) {
    augmented <- c(augmented, "height_ml")
  }
  if (!is.null(chm_source) && identical(as.character(chm_source), "lidar_hd")) {
    augmented <- c(augmented, "height_lidar")
  }
  species_source <- attr(data, "species_source")
  if (!is.null(species_source) &&
      as.character(species_source) %in% c("tree_sat", "maestro")) {
    augmented <- c(augmented, "species_ml")
  }
  texture_source <- attr(data, "texture_source")
  if (!is.null(texture_source) && identical(as.character(texture_source), "maestro")) {
    augmented <- c(augmented, "texture_ml")
  }
  # spec 027 / ADR-014 : indicateurs microclimatiques modélisés (microclimf),
  # augmentés par la structure LiDAR HD / CHM. NDP de base inchangé.
  micro_source <- attr(data, "microclimate_source")
  if (!is.null(micro_source) && identical(as.character(micro_source), "microclimf")) {
    augmented <- c(augmented, "microclimate_model")
  }
  # spec 033 : LAI restitué par inversion PROSAIL sur Sentinel-2 (repli canopée
  # NDP 0, sans LiDAR HD). Flag ML séparé, NDP de base inchangé.
  lai_source <- attr(data, "lai_source")
  if (!is.null(lai_source) && identical(as.character(lai_source), "prosail_s2")) {
    augmented <- c(augmented, "lai_ml")
  }

  new_ndp_result(level, augmented, sources)
}


#' Constructor for ndp_result objects
#'
#' Internal helper used by \code{detect_ndp()}. Keeps the NDP result
#' structure consistent and attaches the S3 class.
#'
#' @param level Integer. NDP level (0-4).
#' @param augmented Character vector. ML-augmentation flags.
#' @param sources Character vector. Sources detected.
#'
#' @return An \code{ndp_result} list.
#'
#' @keywords internal
#' @noRd
new_ndp_result <- function(level, augmented = character(0),
                           sources = character(0)) {
  level <- as.integer(level)
  structure(
    list(
      level = level,
      confidence = get_ndp_confidence(level),
      augmented = augmented,
      sources = sources
    ),
    class = c("ndp_result", "list")
  )
}


#' Extract augmentation flags from a detect_ndp() result
#'
#' Convenience accessor for the \code{augmented} slot of an
#' \code{ndp_result} object.
#'
#' @param x An \code{ndp_result} object from \code{detect_ndp()}.
#'
#' @return Character vector of augmentation flags (possibly empty).
#'
#' @examples
#' df <- data.frame(x = 1)
#' attr(df, "chm_source") <- "opencanopy"
#' get_ndp_augmented(detect_ndp(df))  # "height_ml"
#'
#' @export
get_ndp_augmented <- function(x) {
  if (!inherits(x, "ndp_result")) {
    stop("x must be an ndp_result object returned by detect_ndp()", call. = FALSE)
  }
  x$augmented
}


#' @export
as.integer.ndp_result <- function(x, ...) x$level


#' @export
print.ndp_result <- function(x, ...) {
  cat(sprintf("NDP %d (confidence %.1f%%)\n",
              x$level, 100 * x$confidence))
  if (length(x$augmented) > 0) {
    cat(sprintf("  augmented: %s\n", paste(x$augmented, collapse = ", ")))
  }
  if (length(x$sources) > 0) {
    cat(sprintf("  sources:   %s\n", paste(x$sources, collapse = ", ")))
  }
  invisible(x)
}


#' @export
format.ndp_result <- function(x, ...) {
  sprintf("NDP %d", x$level)
}


#' Detect NDP level from nemeton_layers object
#'
#' Inspects a \code{nemeton_layers} object returned by the download pipeline
#' to determine which data sources were actually available.
#'
#' @param layers A \code{nemeton_layers} object from \code{download_layers_for_parcels()}.
#'
#' @return Integer. Detected NDP level (0-4).
#'
#' @keywords internal
#' @noRd
detect_ndp_from_layers <- function(layers) {
  if (!inherits(layers, "nemeton_layers")) return(0L)

  # NDP 1 : LiDAR HD present (MNH ou MNT ou nuages de points)
  has_lidar_hd <- !is.null(layers$rasters$lidar_mnh) ||
                  !is.null(layers$rasters$lidar_mnt) ||
                  length(layers$point_clouds) > 0

  if (!has_lidar_hd) return(0L)

  # NDP 2+ : drone, inventaire terrain, scanner - pas encore dans le pipeline
  # La detection sera etendue quand ces sources seront integrees
  1L
}


#' Set NDP source attributes on a data object
#'
#' Marks which data sources were available during computation.
#' These attributes are read by \code{\link{detect_ndp}}.
#'
#' @param data An sf object or data.frame.
#' @param layers A \code{nemeton_layers} object, or NULL.
#'
#' @return The data object with NDP attributes set.
#'
#' @keywords internal
#' @noRd
set_ndp_attributes <- function(data, layers = NULL) {
  if (!is.null(layers) && inherits(layers, "nemeton_layers")) {
    attr(data, "has_lidar_hd") <- !is.null(layers$rasters$lidar_mnh) ||
                                   !is.null(layers$rasters$lidar_mnt) ||
                                   length(layers$point_clouds) > 0
  } else {
    attr(data, "has_lidar_hd") <- FALSE
  }

  # Sources NDP 2+ : pas encore dans le pipeline

  attr(data, "has_drone_rgb") <- FALSE
  attr(data, "has_lidar_drone") <- FALSE
  attr(data, "has_inventaire_terrain") <- FALSE
  attr(data, "has_scanner_terrestre") <- FALSE
  attr(data, "has_modele_3d") <- FALSE

  # Stocker le NDP detecte (niveau integer uniquement pour retrocompat)
  attr(data, "ndp_detected") <- detect_ndp(data)$level

  data
}


#' Restore NDP attributes from project metadata
#'
#' After loading indicators from parquet (which strips attributes),
#' restores the NDP attributes from the persisted metadata.
#'
#' @param data An sf object.
#' @param ndp_level Integer. The NDP level from project metadata.
#'
#' @return The data object with NDP attributes restored.
#'
#' @keywords internal
#' @noRd
restore_ndp_attributes <- function(data, ndp_level) {
  ndp_level <- as.integer(ndp_level %||% 0L)
  if (is.na(ndp_level)) ndp_level <- 0L

  attr(data, "has_lidar_hd") <- ndp_level >= 1L
  attr(data, "has_drone_rgb") <- ndp_level >= 2L
  attr(data, "has_lidar_drone") <- ndp_level >= 2L
  attr(data, "has_inventaire_terrain") <- ndp_level >= 3L
  attr(data, "has_scanner_terrestre") <- ndp_level >= 4L
  attr(data, "has_modele_3d") <- ndp_level >= 4L
  attr(data, "ndp_detected") <- ndp_level

  data
}


#' Detect NDP level from project cache directory
#'
#' Inspects the project's cache/layers directory for actual data files
#' to determine the NDP level. This is more robust than attribute-based
#' detection because attributes can be lost during serialization.
#'
#' @param project_path Character. Path to the project directory.
#'
#' @return Integer. Detected NDP level (0-4).
#'
#' @keywords internal
#' @noRd
detect_ndp_from_cache <- function(project_path) {
  if (is.null(project_path) || !dir.exists(project_path)) return(0L)

  cache_dir <- file.path(project_path, "cache", "layers")
  if (!dir.exists(cache_dir)) return(0L)

  # NDP 1 : LiDAR HD present (repertoires ou fichiers lidar_mnh / lidar_mnt / lidar_nuage)
  has_lidar_hd <- dir.exists(file.path(cache_dir, "lidar_mnh")) ||
                  dir.exists(file.path(cache_dir, "lidar_mnt")) ||
                  dir.exists(file.path(cache_dir, "lidar_nuage")) ||
                  any(grepl("lidar_mn[ht]", list.files(cache_dir), ignore.case = TRUE))

  if (!has_lidar_hd) return(0L)

  # NDP 2+ : pas encore dans le pipeline
  1L
}


# ================================================================
# compute_general_index
# ================================================================

#' Compute Fibonacci-weighted general index
#'
#' Computes the global score as a Fibonacci-weighted mean of family scores.
#' The NDP determines the weight and confidence level.
#'
#' @param family_scores Named numeric vector of family scores (0-100).
#'   Names should be family codes (e.g., "C", "B", "W") or
#'   "famille_carbone", "famille_biodiversite" format.
#' @param ndp Integer. NDP level (0-4). Default 0.
#'
#' @return A list with:
#'   \describe{
#'     \item{score}{Numeric. The weighted general index (0-100).}
#'     \item{ndp}{Integer. The NDP level used.}
#'     \item{confidence}{Numeric. The confidence phi ratio.}
#'     \item{weight}{Integer. The Fibonacci weight.}
#'     \item{n_families}{Integer. Number of families used.}
#'   }
#'
#' @examples
#' scores <- c(C = 72, B = 45, W = 68, A = 55, F = 60,
#'             L = 40, T = 35, R = 50, S = 65, P = 70,
#'             E = 48, N = 58)
#' result <- compute_general_index(scores, ndp = 0)
#' result$score
#' result$confidence
#'
#' @export
compute_general_index <- function(family_scores, ndp = 0L) {
  ndp <- as.integer(ndp)
  level <- get_ndp_level(ndp)


  # Nettoyer les noms (supporter famille_carbone ou C)
  nms <- names(family_scores)
  if (!is.null(nms)) {
    # Convertir famille_biodiversite -> B, etc.
    nms <- vapply(nms, function(n) {
      code <- get_famille_code(n)
      if (!is.na(code)) code else sub("^famille_", "", n)
    }, character(1), USE.NAMES = FALSE)
    names(family_scores) <- nms
  }

  # Retirer les NA
  valid <- !is.na(family_scores)
  if (!any(valid)) {
    return(list(
      score = NA_real_,
      ndp = ndp,
      confidence = level$confidence,
      weight = level$fibonacci,
      n_families = 0L
    ))
  }

  valid_scores <- family_scores[valid]

  # Indice general : moyenne ponderee Fibonacci

  # En mode uniforme, toutes les familles ont le meme poids Fibonacci,
  # donc le score est simplement la moyenne des scores
  score <- round(mean(valid_scores, na.rm = TRUE), 1)

  list(
    score = score,
    ndp = ndp,
    confidence = level$confidence,
    weight = level$fibonacci,
    n_families = length(valid_scores)
  )
}


#' Compute general index with mixed NDP per indicator
#'
#' When different indicators come from different data sources,
#' each may have a different NDP level. This function uses
#' per-indicator Fibonacci weights.
#'
#' @param family_scores Named numeric vector of family scores (0-100).
#' @param ndp_per_indicator Named integer vector mapping family codes
#'   to NDP levels (0-4). Names must match \code{family_scores} names.
#'
#' @return A list with:
#'   \describe{
#'     \item{score}{Numeric. The weighted general index.}
#'     \item{confidence}{Numeric. Average confidence across indicators.}
#'     \item{n_families}{Integer. Number of families used.}
#'     \item{weights_used}{Named integer vector of Fibonacci weights per family.}
#'   }
#'
#' @examples
#' scores <- c(C = 72, B = 45, W = 68)
#' ndps <- c(C = 2, B = 0, W = 1)
#' compute_general_index_mixed(scores, ndps)
#'
#' @export
compute_general_index_mixed <- function(family_scores, ndp_per_indicator) {
  # Nettoyer les noms (convertir famille_carbone -> C)
  nms <- names(family_scores)
  if (!is.null(nms)) {
    nms <- vapply(nms, function(n) {
      code <- get_famille_code(n)
      if (!is.na(code)) code else sub("^famille_", "", n)
    }, character(1), USE.NAMES = FALSE)
    names(family_scores) <- nms
  }

  ndp_nms <- names(ndp_per_indicator)
  if (!is.null(ndp_nms)) {
    ndp_nms <- vapply(ndp_nms, function(n) {
      code <- get_famille_code(n)
      if (!is.na(code)) code else sub("^famille_", "", n)
    }, character(1), USE.NAMES = FALSE)
    names(ndp_per_indicator) <- ndp_nms
  }

  # Garder seulement les familles presentes dans les deux vecteurs
  common <- intersect(names(family_scores), names(ndp_per_indicator))
  if (length(common) == 0) {
    return(list(
      score = NA_real_,
      confidence = 0,
      n_families = 0L,
      weights_used = integer(0)
    ))
  }

  scores <- family_scores[common]
  ndps <- ndp_per_indicator[common]

  # Retirer les NA
  valid <- !is.na(scores) & !is.na(ndps)
  if (!any(valid)) {
    return(list(
      score = NA_real_,
      confidence = 0,
      n_families = 0L,
      weights_used = integer(0)
    ))
  }

  scores <- scores[valid]
  ndps <- ndps[valid]

  # Poids Fibonacci par famille
  weights <- vapply(ndps, get_ndp_weight, integer(1))

  # Moyenne ponderee
  score <- round(sum(scores * weights) / sum(weights), 1)

  # Confiance moyenne
  confidences <- vapply(ndps, get_ndp_confidence, numeric(1))
  avg_confidence <- mean(confidences)

  list(
    score = score,
    confidence = avg_confidence,
    n_families = length(scores),
    weights_used = weights
  )
}
