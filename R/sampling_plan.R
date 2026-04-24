#' Sampling Plan Generator (GRTS + stratification)
#'
#' @description
#' Build a field sampling plan from a study area, with optional
#' stratification on CHM height, forest type (BD Foret polygons) and
#' topographic position (TPI from a DEM). The draw prefers
#' \pkg{spsurvey} GRTS (spatially balanced, stratified), falls back to
#' \pkg{BalancedSampling} LPM2 (spatially balanced only), then to a
#' plain spatial random draw.
#'
#' This is a library version of the pipeline taught in tutorial
#' \code{09-sampling}. It degrades gracefully: without any optional
#' input it produces a spatial random draw equivalent to a single call
#' to \code{\link[sf]{st_sample}}.
#'
#' @name sampling_plan
NULL


# ---- internal helpers --------------------------------------------------

# Traveling-salesman walking tour for a set of sampling plots.
#
# Uses the \pkg{TSP} package (Suggests) with the same recipe as the
# 09-sampling tutorial: nearest_insertion to seed, 2-opt to refine.
# Falls back to a hand-rolled nearest-neighbor + 2-opt when \pkg{TSP}
# is not installed so the function never hard-fails.
#
# The tour returned by \code{TSP::solve_TSP()} is closed (loop)
# and rotation-invariant. We rotate it so the start is at the
# user-supplied \code{start_idx}, or the south-easternmost point by
# default (likeliest road access in French forests), and return the
# sequence as an OPEN path (no closing edge — the walker does not
# return to the start).
#
# @param coords numeric matrix n x 2 of projected coordinates.
# @param start_idx optional index of the first plot to visit.
#
# @return integer vector of indices in visit order.
.tsp_tour <- function(coords, start_idx = NULL) {
  n <- nrow(coords)
  if (n <= 1L) return(seq_len(n))
  if (is.null(start_idx)) {
    start_idx <- which.max(coords[, 1] - coords[, 2])  # SE-most
  }

  if (requireNamespace("TSP", quietly = TRUE) && n >= 3L) {
    dist_matrix <- as.matrix(stats::dist(coords))
    tsp_obj  <- TSP::TSP(dist_matrix)
    tour_ni  <- TSP::solve_TSP(tsp_obj, method = "nearest_insertion")
    tour_opt <- tryCatch(
      TSP::solve_TSP(tsp_obj, method = "2-opt",
                     control = list(tour = tour_ni)),
      error = function(e) tour_ni
    )
    tour <- as.integer(tour_opt)
  } else {
    tour <- .tsp_fallback(coords, start_idx)
  }

  # Rotate so start_idx comes first. TSP tours are rotation-invariant
  # (closed loops) but we want a well-defined open walking path.
  pos <- match(start_idx, tour)
  if (!is.na(pos) && pos > 1L) {
    tour <- c(tour[pos:length(tour)], tour[seq_len(pos - 1L)])
  }
  tour
}


# Hand-rolled fallback (nearest-neighbor + open-path 2-opt). Used
# when the TSP package is not available. Result is materially worse
# than TSP's 2-opt on dense draws but still a valid tour.
.tsp_fallback <- function(coords, start_idx, iter_max = 20L) {
  n <- nrow(coords)
  tour <- integer(n)
  tour[1] <- start_idx
  remaining <- setdiff(seq_len(n), start_idx)
  for (k in 2:n) {
    cur <- tour[k - 1]
    d <- (coords[remaining, 1] - coords[cur, 1])^2 +
         (coords[remaining, 2] - coords[cur, 2])^2
    nxt <- remaining[which.min(d)]
    tour[k] <- nxt
    remaining <- setdiff(remaining, nxt)
  }
  if (n < 4L) return(tour)

  seg_len <- function(i, j) {
    sqrt(sum((coords[i, ] - coords[j, ])^2))
  }
  for (pass in seq_len(iter_max)) {
    improved <- FALSE
    for (i in seq_len(n - 2L)) {
      if (i + 2L > n - 1L) next
      for (j in (i + 2L):(n - 1L)) {
        a <- tour[i];     b <- tour[i + 1L]
        c <- tour[j];     d <- tour[j + 1L]
        old_d <- seg_len(a, b) + seg_len(c, d)
        new_d <- seg_len(a, c) + seg_len(b, d)
        if (new_d + 1e-9 < old_d) {
          tour[(i + 1L):j] <- rev(tour[(i + 1L):j])
          improved <- TRUE
        }
      }
    }
    if (!improved) break
  }
  tour
}


.compute_forest_cover <- function(buffers, forest_mask) {
  if (is.null(forest_mask)) {
    return(rep(1, nrow(buffers)))
  }
  n <- nrow(buffers)
  out <- numeric(n)
  for (i in seq_len(n)) {
    inter <- tryCatch(sf::st_intersection(buffers[i, ], forest_mask),
                      error = function(e) NULL)
    if (is.null(inter) || nrow(inter) == 0) {
      out[i] <- 0
    } else {
      out[i] <- sum(as.numeric(sf::st_area(inter))) /
                as.numeric(sf::st_area(buffers[i, ]))
    }
  }
  out
}


.extract_mean <- function(raster, buffers) {
  if (is.null(raster) || !requireNamespace("exactextractr", quietly = TRUE)) {
    return(rep(NA_real_, nrow(buffers)))
  }
  tryCatch(exactextractr::exact_extract(raster, buffers, "mean",
                                        progress = FALSE),
           error = function(e) rep(NA_real_, nrow(buffers)))
}


.stratify <- function(frame, chm_ok, mnt_ok, forest_mask) {
  # Height quartiles (CHM)
  if (chm_ok && !all(is.na(frame$mean_height))) {
    br <- stats::quantile(frame$mean_height,
                          probs = c(0, 0.25, 0.5, 0.75, 1),
                          na.rm = TRUE)
    frame$strat_height <- as.character(cut(
      frame$mean_height, breaks = br,
      labels = c("H1", "H2", "H3", "H4"),
      include.lowest = TRUE
    ))
  } else {
    frame$strat_height <- "H0"
  }

  # Type (BD Foret)
  if (!is.null(forest_mask) && "tfv" %in% names(forest_mask)) {
    tfv <- sf::st_join(frame[, attr(frame, "sf_column")],
                       forest_mask[, "tfv"], left = TRUE)$tfv
    frame$strat_type <- dplyr_case_simple(tfv)
  } else {
    frame$strat_type <- "AUT"
  }

  # TPI terciles (DEM)
  if (mnt_ok && !all(is.na(frame$mean_tpi))) {
    br <- stats::quantile(frame$mean_tpi,
                          probs = c(0, 1/3, 2/3, 1),
                          na.rm = TRUE)
    frame$strat_topo <- as.character(cut(
      frame$mean_tpi, breaks = br,
      labels = c("BAS", "MIL", "HAU"),
      include.lowest = TRUE
    ))
  } else {
    frame$strat_topo <- "NA"
  }

  frame$stratum <- paste(frame$strat_height, frame$strat_type, frame$strat_topo,
                         sep = "_")
  frame
}


dplyr_case_simple <- function(tfv) {
  out <- rep("AUT", length(tfv))
  out[is.na(tfv)] <- "AUT"
  out[grepl("Feuillus",           tfv, ignore.case = TRUE)] <- "FEU"
  out[grepl("Conif(è|e)res",      tfv, ignore.case = TRUE)] <- "CON"
  out[grepl("Mixte",              tfv, ignore.case = TRUE)] <- "MIX"
  out[grepl("Peupleraie",         tfv, ignore.case = TRUE)] <- "POP"
  out
}


.allocate_per_stratum <- function(strata_counts, n_main, min_per_stratum) {
  alloc <- round(as.numeric(strata_counts) / sum(strata_counts) * n_main)
  alloc <- pmax(alloc, min_per_stratum)
  alloc <- pmin(alloc, as.integer(strata_counts))
  while (sum(alloc) > n_main) {
    idx <- which.max(alloc)
    alloc[idx] <- alloc[idx] - 1
  }
  stats::setNames(as.integer(alloc), names(strata_counts))
}


.draw_grts <- function(frame, allocation, n_over_per_stratum) {
  # spsurvey::grts prints to stdout on validation errors before throwing.
  # Suppress the noise so users only see the cli warning.
  tryCatch(
    suppressMessages(utils::capture.output(
      res <- spsurvey::grts(
        sframe = frame,
        n_base = allocation,
        stratum_var = "stratum",
        n_over = n_over_per_stratum
      ),
      file = nullfile()
    )),
    error = function(e) {
      cli::cli_warn("spsurvey::grts failed: {e$message}. Falling back.")
      res <<- NULL
    }
  )
  if (!exists("res", inherits = FALSE)) return(NULL)
  res
}


.draw_lpm2 <- function(frame, n_total) {
  coords <- sf::st_coordinates(frame)
  prob <- rep(n_total / nrow(frame), nrow(frame))
  selected <- BalancedSampling::lpm2(prob, coords)
  selected <- sample(selected)  # shuffle so Base/Over are both balanced
  frame[selected, ]
}


.draw_random <- function(frame, n_total) {
  idx <- sample(nrow(frame), min(n_total, nrow(frame)))
  frame[idx, ]
}


# ---- public API --------------------------------------------------------

#' Generate a forest sampling plan (GRTS with graceful fallback)
#'
#' Given a study area (and optionally a CHM, DEM, and BD Foret polygon
#' layer), build a candidate grid, apply terrain constraints, stratify,
#' and draw Base + Over plots. Prefers \pkg{spsurvey} GRTS, falls back
#' to \pkg{BalancedSampling} LPM2, then to a plain spatial random draw.
#'
#' Without any of the optional inputs, the pipeline degrades to the
#' equivalent of a single \code{\link[sf]{st_sample}} call — useful for
#' quick previews when only the zone is known.
#'
#' The return is ready for \code{\link{create_qfield_project}}.
#'
#' @param zone sf polygon of the study area (any CRS; result uses
#'   \code{zone}'s CRS).
#' @param n_base Integer. Number of base (primary) plots. Optional
#'   when \code{target_error} and \code{cv} are provided — in that
#'   case \code{n_base} is computed via
#'   \code{\link{compute_sample_size}}.
#' @param n_over Integer. Number of replacement (oversample) plots.
#'   Ignored when \code{target_error} is provided and \code{n_over}
#'   is left at 0: an over-ratio is applied to the computed
#'   \code{n_base} instead.
#' @param target_error Optional numeric. Target relative error on the
#'   mean of the target variable (default variable is basal area
#'   G/ha), as a fraction (e.g. 0.10 for \eqn{\pm}10 \%). When
#'   provided together with \code{cv}, \code{n_base} is sized via
#'   \code{\link{compute_sample_size}}.
#' @param cv Optional numeric. Coefficient of variation (fraction)
#'   of the target variable over the AOI. Required when
#'   \code{target_error} is set. Can be derived from BD Forêt v2
#'   via \code{\link{cv_from_bdforet}}.
#' @param alpha Numeric. Significance level for the Cochran formula
#'   (default 0.05 = 95 \% confidence). Only used when
#'   \code{target_error} is provided.
#' @param over_ratio Numeric in [0, 1]. Fraction of \code{n_base} used
#'   as replacement plots when \code{n_over} is left at 0 and
#'   \code{target_error} is provided. Default 0.20.
#' @param chm Optional \code{SpatRaster} of canopy height, used for
#'   height quartile stratification and buffer-mean extraction.
#' @param slope Optional \code{SpatRaster} of slope (percent), used for
#'   the \code{max_slope} constraint.
#' @param forest_mask Optional sf polygon layer. If a \code{tfv} column
#'   is present it's used for the type stratum (Feuillus / Conifères /
#'   Mixte / Peupleraie / Autre); otherwise used only for the
#'   \code{min_forest_cover} constraint.
#' @param mnt Optional \code{SpatRaster} DEM. A TPI (Topographic
#'   Position Index) is computed with a 100 m focal window and used for
#'   the topographic position stratum.
#' @param grid_step Numeric. Spacing (m) of the candidate grid. Default
#'   50.
#' @param plot_radius Numeric. Buffer radius (m) used for the
#'   constraints / metric extraction. Default 15.
#' @param min_forest_cover Numeric in [0, 1]. Minimum forest cover
#'   ratio within the plot buffer. Default 0.7.
#' @param max_slope Numeric. Maximum slope (percent) for a candidate to
#'   be retained. Default 30.
#' @param min_per_stratum Integer. Minimum number of base plots in each
#'   stratum (capped at the number of candidates). Default 2.
#' @param seed Integer random seed. Default 42.
#'
#' @return An sf POINT with columns \code{plot_id}, \code{type} (Base
#'   or Over), \code{visit_order}, \code{stratum}, and optionally
#'   \code{strat_height} / \code{strat_type} / \code{strat_topo} when
#'   the relevant input was supplied. A \code{"method"} attribute
#'   records how the draw was performed (\code{"grts"}, \code{"lpm2"}
#'   or \code{"random"}).
#'
#' @examples
#' \dontrun{
#' library(sf)
#' zone <- st_sf(geometry = st_sfc(st_polygon(list(rbind(
#'   c(0, 0), c(1000, 0), c(1000, 1000), c(0, 1000), c(0, 0)
#' ))), crs = 2154))
#' plan <- create_sampling_plan(zone, n_base = 20, n_over = 5)
#' attr(plan, "method")
#' }
#'
#' @export
create_sampling_plan <- function(zone,
                                 n_base = NULL,
                                 n_over = 0L,
                                 target_error = NULL,
                                 cv = NULL,
                                 alpha = 0.05,
                                 over_ratio = 0.20,
                                 chm = NULL,
                                 slope = NULL,
                                 forest_mask = NULL,
                                 mnt = NULL,
                                 grid_step = 50,
                                 plot_radius = 15,
                                 min_forest_cover = 0.7,
                                 max_slope = 30,
                                 min_per_stratum = 2L,
                                 seed = 42L) {
  if (!inherits(zone, "sf") && !inherits(zone, "sfc")) {
    cli::cli_abort("{.arg zone} must be an sf / sfc object.")
  }
  if (inherits(zone, "sfc")) zone <- sf::st_sf(geometry = zone)

  zone_crs <- sf::st_crs(zone)
  if (is.na(zone_crs$epsg)) {
    cli::cli_warn("{.arg zone} has no CRS; assuming inputs are in the same projected system.")
  }

  # --- Derive n_base from (target_error, cv) when requested ----------
  # When the user provides a target relative error and a CV, compute
  # the minimum sample size via compute_sample_size() and derive
  # n_over from over_ratio (default 20 %). n_base / n_over still take
  # precedence if explicitly given.
  sample_size_result <- NULL
  if (!is.null(target_error)) {
    if (is.null(cv)) {
      cli::cli_abort("{.arg cv} must be provided when {.arg target_error} is set.")
    }
    sample_size_result <- compute_sample_size(
      cv = cv, target_error = target_error, alpha = alpha
    )
    if (is.null(n_base)) n_base <- sample_size_result$n
    if (is.null(n_over) || identical(n_over, 0L)) {
      n_over <- as.integer(ceiling(n_base * over_ratio))
    }
  }

  if (is.null(n_base)) {
    cli::cli_abort("Either {.arg n_base} or ({.arg target_error} + {.arg cv}) must be provided.")
  }
  n_base <- as.integer(n_base)
  n_over <- as.integer(n_over)
  if (n_base < 1) cli::cli_abort("{.arg n_base} must be >= 1.")

  set.seed(seed)

  # --- Build candidate grid ---------------------------------------------
  grid <- sf::st_make_grid(zone, cellsize = grid_step, what = "centers")
  grid <- sf::st_sf(geometry = grid)
  grid <- suppressWarnings(sf::st_intersection(grid, zone))
  grid <- grid[sf::st_geometry_type(grid) == "POINT", , drop = FALSE]
  if (nrow(grid) == 0) {
    cli::cli_abort("No candidate points fell inside {.arg zone} (check grid_step vs. zone size).")
  }
  grid$candidate_id <- sprintf("C%06d", seq_len(nrow(grid)))

  buffers <- suppressWarnings(sf::st_buffer(grid, plot_radius))

  # --- Apply terrain constraints ---------------------------------------
  grid$forest_cover <- .compute_forest_cover(buffers, forest_mask)
  grid$mean_slope   <- .extract_mean(slope, buffers)
  grid$mean_height  <- .extract_mean(chm,   buffers)

  if (!is.null(mnt) && requireNamespace("terra", quietly = TRUE)) {
    tpi <- tryCatch({
      w <- terra::focalMat(mnt, d = 100, type = "circle")
      terra::focal(mnt, w = w, fun = "mean", na.rm = TRUE) -> mnt_f
      mnt - mnt_f
    }, error = function(e) NULL)
    grid$mean_tpi <- .extract_mean(tpi, buffers)
  } else {
    grid$mean_tpi <- NA_real_
  }

  valid <- grid$forest_cover >= min_forest_cover &
           (is.na(grid$mean_slope) | grid$mean_slope <= max_slope)
  frame <- grid[valid, , drop = FALSE]

  if (nrow(frame) == 0) {
    cli::cli_warn("No candidate passed the forest-cover / slope constraints; falling back to the full grid.")
    frame <- grid
  }

  # --- Stratify ---------------------------------------------------------
  chm_ok <- !is.null(chm)
  mnt_ok <- !is.null(mnt)
  frame <- .stratify(frame, chm_ok = chm_ok, mnt_ok = mnt_ok,
                     forest_mask = forest_mask)

  strata_counts <- table(frame$stratum)
  n_strata <- length(strata_counts)
  has_stratification <- n_strata > 1 && (chm_ok || mnt_ok ||
    (!is.null(forest_mask) && "tfv" %in% names(forest_mask)))

  # --- Draw -------------------------------------------------------------
  method <- "random"
  sample_all <- NULL

  if (has_stratification &&
      requireNamespace("spsurvey", quietly = TRUE)) {
    allocation <- .allocate_per_stratum(strata_counts, n_base,
                                        min_per_stratum = min_per_stratum)
    n_over_per_stratum <- max(1L, as.integer(ceiling(n_over / max(1L, n_strata))))

    # GRTS requires that every stratum has at least (base + over) candidates.
    needed <- allocation + n_over_per_stratum
    thin <- needed > as.integer(strata_counts[names(allocation)])
    if (any(thin)) {
      cli::cli_warn(
        "Skipping GRTS: {sum(thin)}/{length(thin)} stratum/strata too thin ({.val {min(strata_counts)}} candidates minimum). Falling back to LPM2 / random."
      )
      grts_res <- NULL
    } else {
      grts_res <- .draw_grts(frame, allocation, n_over_per_stratum)
    }
    if (!is.null(grts_res)) {
      method <- "grts"
      base_sf <- grts_res$sites_base
      over_sf <- grts_res$sites_over
      if (is.null(base_sf)) base_sf <- frame[0, , drop = FALSE]
      if (is.null(over_sf)) over_sf <- frame[0, , drop = FALSE]
      base_sf$type <- "Base"
      over_sf$type <- "Over"
      sample_all <- rbind(base_sf, over_sf)
    }
  }

  if (is.null(sample_all) && requireNamespace("BalancedSampling", quietly = TRUE)) {
    n_total <- min(n_base + n_over, nrow(frame))
    lpm <- tryCatch(.draw_lpm2(frame, n_total),
                    error = function(e) {
                      cli::cli_warn("LPM2 draw failed: {e$message}. Falling back to random.")
                      NULL
                    })
    if (!is.null(lpm)) {
      n_b <- min(n_base, nrow(lpm))
      lpm$type <- c(rep("Base", n_b),
                    rep("Over", max(0L, nrow(lpm) - n_b)))
      sample_all <- lpm
      method <- "lpm2"
    }
  }

  if (is.null(sample_all)) {
    method <- "random"
    n_total <- min(n_base + n_over, nrow(frame))
    draw <- .draw_random(frame, n_total)
    n_b <- min(n_base, nrow(draw))
    draw$type <- c(rep("Base", n_b),
                   rep("Over", max(0L, nrow(draw) - n_b)))
    sample_all <- draw
  }

  # --- Finalise ---------------------------------------------------------
  # Reorder Base plots into a short walking tour (nearest-neighbor +
  # 2-opt). Over (replacement) plots keep their draw-priority order
  # at the tail of the frame.
  is_base <- sample_all$type == "Base"
  if (sum(is_base) >= 2L) {
    base_idx    <- which(is_base)
    base_coords <- sf::st_coordinates(sample_all[base_idx, ])
    tsp_order   <- .tsp_tour(base_coords)
    sample_all[base_idx, ] <- sample_all[base_idx[tsp_order], ]
  }
  sample_all$plot_id <- sprintf("P%03d", seq_len(nrow(sample_all)))
  sample_all$visit_order <- seq_len(nrow(sample_all))

  # Keep the useful columns only
  keep <- c("plot_id", "type", "visit_order", "stratum",
            "strat_height", "strat_type", "strat_topo")
  keep <- intersect(keep, names(sample_all))
  sample_all <- sample_all[, c(keep, attr(sample_all, "sf_column"))]

  attr(sample_all, "method")      <- method
  attr(sample_all, "sample_size") <- sample_size_result
  sample_all
}
