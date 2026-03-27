#' NDP System (Niveau De Pr\u00e9cision)
#'
#' @description
#' NDP measures the QUALITY of input data, not the number of families calculated.
#' All 12 families are always calculated, but with increasing precision as NDP rises.
#'
#' The system uses Fibonacci weighting (1, 1, 2, 3, 5) and golden ratio confidence
#' (\u03c6) to express data reliability.
#'
#' @name ndp
#' @keywords internal
NULL


# ================================================================
# NDP_LEVELS: Configuration des 5 niveaux de pr\u00e9cision
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
#' get_ndp_name(0) # "D\u00e9couverte"
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
#' Returns the cumulative confidence \u03c6, calculated as the ratio of
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

#' Detect NDP level from data
#'
#' Determines the NDP level based on the data sources present in the dataset.
#' Detection is based on attributes set on the data (e.g., \code{has_lidar_hd},
#' \code{has_drone_rgb}).
#'
#' The NDP is the highest level for which ALL required sources are present.
#'
#' @param data An sf object or data.frame with source attributes.
#'
#' @return Integer. Detected NDP level (0-4).
#'
#' @details
#' Source attributes checked (cumulative):
#' \itemize{
#'   \item NDP 0: Always available (public data: Sentinel-2, WorldClim, BD TOPO, MNT 25m)
#'   \item NDP 1: \code{has_lidar_hd = TRUE}
#'   \item NDP 2: NDP 1 + \code{has_drone_rgb = TRUE}
#'   \item NDP 3: NDP 2 + \code{has_inventaire_terrain = TRUE}
#'   \item NDP 4: NDP 3 + \code{has_scanner_terrestre = TRUE}
#' }
#'
#' @examples
#' # Default: NDP 0
#' df <- data.frame(x = 1)
#' detect_ndp(df)
#'
#' # With LiDAR HD: NDP 1
#' attr(df, "has_lidar_hd") <- TRUE
#' detect_ndp(df)
#'
#' @export
detect_ndp <- function(data) {
  if (is.null(data)) return(0L)

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

  ndp <- 0L
  for (check in level_checks) {
    if (check(data)) {
      ndp <- ndp + 1L
    } else {
      break
    }
  }

  ndp
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

  # NDP 2+ : drone, inventaire terrain, scanner — pas encore dans le pipeline
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

  # Stocker le NDP detecte
  attr(data, "ndp_detected") <- detect_ndp(data)

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
#'   "family_C", "family_B" format.
#' @param ndp Integer. NDP level (0-4). Default 0.
#'
#' @return A list with:
#'   \describe{
#'     \item{score}{Numeric. The weighted general index (0-100).}
#'     \item{ndp}{Integer. The NDP level used.}
#'     \item{confidence}{Numeric. The confidence \u03c6 ratio.}
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

  # Nettoyer les noms (supporter family_C ou C)
  nms <- names(family_scores)
  if (!is.null(nms)) {
    nms <- sub("^family_", "", nms)
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
  # Nettoyer les noms
  nms <- names(family_scores)
  if (!is.null(nms)) {
    nms <- sub("^family_", "", nms)
    names(family_scores) <- nms
  }

  ndp_nms <- names(ndp_per_indicator)
  if (!is.null(ndp_nms)) {
    ndp_nms <- sub("^family_", "", ndp_nms)
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


# ================================================================
# Widgets HTML pour Shiny
# ================================================================

#' NDP badge HTML widget
#'
#' Creates an HTML badge displaying the NDP level with color coding.
#'
#' @param ndp Integer. NDP level (0-4).
#' @param lang Character. Language ("fr" or "en"). Default "fr".
#'
#' @return An htmltools tag object.
#'
#' @keywords internal
#' @noRd
ndp_badge <- function(ndp, lang = "fr") {
  ndp <- as.integer(ndp)
  level <- get_ndp_level(ndp)

  # Couleurs par niveau
  colors <- c(
    "#6c757d",
    "#17a2b8",
    "#28a745",
    "#ffc107",
    "#fd7e14"
  )
  color <- colors[ndp + 1L]

  # Nom traduit
  names_en <- c("Discovery", "Observation", "Exploration", "Diagnostic", "Digital Twin")
  name <- if (lang == "en") names_en[ndp + 1L] else level$name

  htmltools::tags$span(
    class = "badge",
    style = paste0(
      "background-color: ", color, "; ",
      "color: white; ",
      "font-size: 0.85rem; ",
      "padding: 4px 10px;"
    ),
    paste0("NDP ", ndp, " \u2013 ", name)
  )
}


#' NDP confidence progress bar widget
#'
#' Creates an HTML progress bar showing the confidence \u03c6 percentage.
#'
#' @param ndp Integer. NDP level (0-4).
#' @param lang Character. Language ("fr" or "en"). Default "fr".
#'
#' @return An htmltools tag object.
#'
#' @keywords internal
#' @noRd
ndp_progress_bar <- function(ndp, lang = "fr") {
  ndp <- as.integer(ndp)
  level <- get_ndp_level(ndp)
  pct <- round(level$confidence * 100, 1)

  label <- if (lang == "en") {
    paste0("Confidence \u03c6: ", pct, "%")
  } else {
    paste0("Confiance \u03c6 : ", pct, "%")
  }

  htmltools::div(
    class = "mt-1",
    htmltools::tags$small(class = "text-muted", label),
    htmltools::div(
      class = "progress",
      style = "height: 8px;",
      htmltools::div(
        class = "progress-bar bg-success",
        role = "progressbar",
        style = paste0("width: ", pct, "%;"),
        `aria-valuenow` = pct,
        `aria-valuemin` = "0",
        `aria-valuemax` = "100"
      )
    )
  )
}
