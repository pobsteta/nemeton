#' CHM (Canopy Height Model) utilities
#'
#' Helpers to sanitize and exploit Canopy Height Model rasters produced
#' by external sources such as the \code{opencanopy} package
#' (pobsteta/opencanopynemeton) or LiDAR HD.
#'
#' The main entry point is \code{\link{sanitize_chm}}, a 5-step pipeline
#' that masks out pixels where a forest height is implausible (outside
#' forest areas, buildings/water, low-NDVI, out-of-range values, steep
#' slopes). Sanitized CHMs are suitable inputs for \code{P1} (volume),
#' \code{P2} (site index) and other indicators that exploit height
#' information (see spec 005).
#'
#' @name utils-chm
#' @keywords internal
NULL


# ================================================================
# sanitize_chm — 5-step masking pipeline
# ================================================================

#' Sanitize a Canopy Height Model raster
#'
#' Applies a sequence of masks to filter out pixels where the reported
#' canopy height is implausible for forest analysis. All masks are
#' optional: only the ones for which an input is provided are applied.
#'
#' Pipeline steps (in order):
#' \enumerate{
#'   \item \strong{Forest mask} (if \code{forest_mask} supplied): keep
#'         only pixels marked as forest (e.g. from BD Forêt v2 or OSO).
#'   \item \strong{Buildings + water} (if \code{buildings} or \code{water}
#'         supplied): mask out pixels intersecting either layer.
#'   \item \strong{NDVI threshold} (if \code{ndvi} supplied): keep only
#'         pixels where \code{ndvi >= ndvi_threshold}.
#'   \item \strong{Plausible value range}: set to \code{NA} any pixel
#'         with \code{chm < 0} or \code{chm > max_height}.
#'   \item \strong{Slope coherence} (if \code{slope} supplied): mask out
#'         pixels where \code{slope > 60} degrees (cliffs).
#' }
#'
#' A warning is emitted if more than 50\% of the originally valid pixels
#' are masked — this usually signals an alignment / resolution / vintage
#' problem between the CHM and the reference layers.
#'
#' @param chm A \code{SpatRaster} of canopy heights in metres.
#' @param forest_mask A \code{SpatRaster} (logical / 0-1) or an
#'   \code{sf} polygon layer marking forest areas. Optional.
#' @param buildings An \code{sf} polygon layer of buildings. Optional.
#' @param water An \code{sf} polygon layer of water surfaces. Optional.
#' @param ndvi A \code{SpatRaster} of NDVI values aligned with \code{chm}.
#'   Optional.
#' @param max_height Numeric. Upper plausibility bound in metres
#'   (default \code{50}).
#' @param slope A \code{SpatRaster} of slope in degrees aligned with
#'   \code{chm}. Optional.
#' @param ndvi_threshold Numeric. Minimum NDVI to keep a pixel
#'   (default \code{0.2}). Beech/oak in summer sit at 0.7-0.9, but
#'   conifer plantations, shadowed pixels and edges commonly dip
#'   under 0.3, so the default was softened from 0.3 to 0.2 to
#'   keep enough pixels on realistic stands.
#' @param forest_coverage_threshold Numeric in \code{[0, 1]}.
#'   When \code{forest_mask} is an \code{sf} layer, skip the
#'   forest-mask step if the mask covers less than this fraction
#'   of the CHM extent (default \code{0.5}). Avoids wiping 95 %+
#'   of pixels when BD Forêt simply does not map the area. Set to
#'   \code{0} to force the mask regardless of coverage.
#' @param verbose Logical. If \code{TRUE} (default), emit a
#'   \code{cli::cli_alert_info} after every step with the
#'   cumulative fraction of masked pixels, which helps spot a
#'   single offending step.
#'
#' @return A list with:
#'   \describe{
#'     \item{chm_clean}{\code{SpatRaster}. The masked CHM (same extent,
#'       resolution, and CRS as the input).}
#'     \item{pct_masked}{Numeric in \code{[0, 1]}. Fraction of originally
#'       non-NA pixels that were masked out.}
#'     \item{steps_applied}{Character vector. Names of the masks actually
#'       applied (\code{"forest"}, \code{"buildings"}, \code{"water"},
#'       \code{"ndvi"}, \code{"range"}, \code{"slope"}).}
#'   }
#'
#' @note
#' \code{sanitize_chm()} is idempotent and does not mutate the input
#' raster. It returns a new \code{SpatRaster}.
#'
#' @examples
#' \dontrun{
#' # Minimal: just apply the plausible range step
#' chm <- terra::rast(system.file("extdata/chm_demo.tif", package = "nemeton"))
#' out <- sanitize_chm(chm)
#' out$pct_masked
#'
#' # Full pipeline with a forest mask and buildings/water vectors
#' out <- sanitize_chm(
#'   chm,
#'   forest_mask = bd_foret,
#'   buildings   = bd_topo_batiments,
#'   water       = bd_carthage,
#'   ndvi        = ndvi_rast,
#'   max_height  = 50
#' )
#' terra::plot(out$chm_clean)
#' }
#'
#' @export
sanitize_chm <- function(chm,
                         forest_mask  = NULL,
                         buildings    = NULL,
                         water        = NULL,
                         ndvi         = NULL,
                         max_height   = 50,
                         slope        = NULL,
                         ndvi_threshold = 0.2,
                         forest_coverage_threshold = 0.5,
                         verbose = TRUE) {
  if (!inherits(chm, "SpatRaster")) {
    stop("chm must be a terra SpatRaster", call. = FALSE)
  }

  steps <- character(0)
  n_valid_before <- sum(!is.na(terra::values(chm)))

  chm_out <- chm

  # Each step is wrapped in a named tryCatch so that a downstream
  # failure (typically terra choking on an sf layer with weird
  # columns) surfaces with the step name instead of a cryptic
  # "[subset] invalid name(s)" from terra internals.
  step <- function(name, expr) {
    tryCatch(expr, error = function(e) {
      stop(sprintf("sanitize_chm step '%s' failed: %s",
                   name, conditionMessage(e)),
           call. = FALSE)
    })
  }

  # Log cumulative masking after each applied step. Helps spot a
  # single offending step when the overall ratio looks suspicious.
  log_step <- function(name) {
    if (!verbose) return(invisible(NULL))
    n_now <- sum(!is.na(terra::values(chm_out)))
    pct   <- if (n_valid_before > 0) 1 - (n_now / n_valid_before) else 0
    cli::cli_alert_info(
      "sanitize_chm step '{name}': {round(100 * pct, 1)}% cumulative masked"
    )
  }

  # Etape 1 : masque foret — skipped if the mask is an sf layer that
  # covers too little of the CHM (typical when BD Forêt simply does
  # not map the area): applying it would wipe 95 %+ of the pixels.
  if (!is.null(forest_mask)) {
    coverage <- .forest_mask_coverage(chm_out, forest_mask)
    if (!is.na(coverage) && coverage < forest_coverage_threshold) {
      cli::cli_warn(c(
        "sanitize_chm: forest mask covers only \\
         {round(100 * coverage, 1)}% of the CHM extent \\
         (< {round(100 * forest_coverage_threshold, 1)}%).",
        "i" = "Skipping forest step. Pass forest_coverage_threshold = 0 \\
               to force the mask anyway."
      ))
    } else {
      chm_out <- step("forest", .apply_forest_mask(chm_out, forest_mask))
      steps <- c(steps, "forest")
      log_step("forest")
    }
  }

  # Etape 2 : masque bati + eau
  if (!is.null(buildings)) {
    chm_out <- step("buildings",
      .apply_vector_mask(chm_out, buildings, inverse = TRUE))
    steps <- c(steps, "buildings")
    log_step("buildings")
  }
  if (!is.null(water)) {
    chm_out <- step("water",
      .apply_vector_mask(chm_out, water, inverse = TRUE))
    steps <- c(steps, "water")
    log_step("water")
  }

  # Etape 3 : seuillage NDVI
  if (!is.null(ndvi)) {
    if (!inherits(ndvi, "SpatRaster")) {
      stop("ndvi must be a SpatRaster", call. = FALSE)
    }
    chm_out <- step("ndvi", {
      ndvi_aligned <- .align_to(ndvi, chm_out)
      terra::ifel(ndvi_aligned < ndvi_threshold, NA, chm_out)
    })
    steps <- c(steps, "ndvi")
    log_step("ndvi")
  }

  # Etape 4 : bornes plausibles (toujours appliquee)
  chm_out <- step("range",
    terra::ifel(chm_out < 0 | chm_out > max_height, NA, chm_out))
  steps <- c(steps, "range")
  log_step("range")

  # Etape 5 : pente
  if (!is.null(slope)) {
    if (!inherits(slope, "SpatRaster")) {
      stop("slope must be a SpatRaster", call. = FALSE)
    }
    chm_out <- step("slope", {
      slope_aligned <- .align_to(slope, chm_out)
      terra::ifel(slope_aligned > 60, NA, chm_out)
    })
    steps <- c(steps, "slope")
    log_step("slope")
  }

  n_valid_after <- sum(!is.na(terra::values(chm_out)))
  pct_masked <- if (n_valid_before > 0) {
    1 - (n_valid_after / n_valid_before)
  } else {
    0
  }

  if (pct_masked > 0.5) {
    cli::cli_warn(c(
      "sanitize_chm: {round(100 * pct_masked, 1)}% of pixels masked.",
      "i" = "This is unusually high; check alignment/vintage of input layers."
    ))
  }

  list(
    chm_clean     = chm_out,
    pct_masked    = pct_masked,
    steps_applied = steps
  )
}


# ================================================================
# Helpers internes
# ================================================================

#' Apply a forest mask to a raster
#'
#' Accepts either a \code{SpatRaster} (logical / 0-1) or an \code{sf}
#' polygon layer. Non-forest pixels become \code{NA}.
#'
#' @param chm A SpatRaster.
#' @param mask A SpatRaster or sf polygon.
#'
#' @return A SpatRaster.
#'
#' @keywords internal
#' @noRd
.apply_forest_mask <- function(chm, mask) {
  if (inherits(mask, "SpatRaster")) {
    aligned <- .align_to(mask, chm)
    return(terra::mask(chm, aligned, maskvalues = c(NA, 0, FALSE)))
  }
  if (inherits(mask, c("sf", "sfc"))) {
    return(terra::mask(chm, .sf_to_vect_geom(mask, chm)))
  }
  stop("forest_mask must be a SpatRaster or sf layer", call. = FALSE)
}


#' Mask pixels covered by a vector layer
#'
#' When \code{inverse = TRUE} (default for buildings/water), pixels that
#' intersect the polygons become \code{NA}.
#'
#' @param chm A SpatRaster.
#' @param vec An sf polygon layer.
#' @param inverse Logical. If TRUE, mask pixels INSIDE the polygons.
#'
#' @return A SpatRaster.
#'
#' @keywords internal
#' @noRd
.apply_vector_mask <- function(chm, vec, inverse = TRUE) {
  if (!inherits(vec, c("sf", "sfc"))) {
    stop("vector mask must be an sf/sfc object", call. = FALSE)
  }
  terra::mask(chm, .sf_to_vect_geom(vec, chm), inverse = inverse)
}


# Fraction of the CHM extent actually covered by the forest mask.
# Returns NA when the fraction cannot be estimated. sf/sfc inputs
# are intersected with the CHM bbox; SpatRaster inputs are re-aligned
# and the fraction of non-NA / non-zero cells is returned.
.forest_mask_coverage <- function(chm, mask) {
  ext_vec <- as.vector(terra::ext(chm))
  chm_bbox <- sf::st_bbox(
    c(xmin = ext_vec[["xmin"]], ymin = ext_vec[["ymin"]],
      xmax = ext_vec[["xmax"]], ymax = ext_vec[["ymax"]]),
    crs = terra::crs(chm)
  )
  chm_poly <- sf::st_as_sfc(chm_bbox)
  chm_area <- as.numeric(sf::st_area(chm_poly))
  if (!is.finite(chm_area) || chm_area <= 0) return(NA_real_)

  if (inherits(mask, c("sf", "sfc"))) {
    mask_proj <- sf::st_transform(sf::st_geometry(mask), terra::crs(chm))
    inter <- tryCatch(
      suppressWarnings(sf::st_intersection(mask_proj, chm_poly)),
      error = function(e) NULL
    )
    if (is.null(inter) || length(inter) == 0) return(0)
    return(as.numeric(sum(sf::st_area(inter))) / chm_area)
  }

  if (inherits(mask, "SpatRaster")) {
    aligned <- .align_to(mask, chm)
    vals <- terra::values(aligned)
    total <- length(vals)
    if (total == 0) return(NA_real_)
    return(sum(!is.na(vals) & vals != 0) / total)
  }

  NA_real_
}


# Convert an sf/sfc to a geometry-only SpatVector aligned to the
# CRS of a reference SpatRaster. Dropping attribute columns avoids
# terra's "[subset] invalid name(s)" error when the sf has
# list-columns, factors with weird levels, or field names with
# characters terra does not like (common with BD Forêt V2 outputs
# that occasionally keep JSON fragments).
.sf_to_vect_geom <- function(x, ref_chm) {
  if (inherits(x, "sfc")) {
    geom <- x
  } else {
    geom <- sf::st_geometry(x)
  }
  geom <- sf::st_transform(geom, terra::crs(ref_chm))
  terra::vect(geom)
}


#' Align a raster to the geometry of another
#'
#' Reprojects and resamples if the CRS, extent or resolution differ.
#'
#' @param r A SpatRaster.
#' @param ref A reference SpatRaster.
#'
#' @return A SpatRaster aligned to \code{ref}.
#'
#' @keywords internal
#' @noRd
.align_to <- function(r, ref) {
  if (terra::same.crs(r, ref) &&
      isTRUE(all.equal(terra::ext(r), terra::ext(ref))) &&
      isTRUE(all.equal(terra::res(r), terra::res(ref)))) {
    return(r)
  }
  terra::project(r, ref, method = "near")
}


# ================================================================
# extract_h_dom — dominant height per spatial unit
# ================================================================

#' Extract dominant height from a CHM for a set of spatial units
#'
#' For each polygon unit, computes the dominant height
#' \eqn{H_{dom}} as a high percentile (default 90\%) of the
#' canopy-height pixels falling inside that unit. Pixels with
#' \code{NA} (typically masked by \code{\link{sanitize_chm}}) are
#' ignored.
#'
#' The convention \eqn{H_{dom} = P_{90}(\mathrm{CHM})} is a
#' practical proxy for the classical definition (mean height of
#' the 100 largest trees per hectare) when only a CHM raster is
#' available. Choosing \code{percentile = 1} yields the maximum
#' height, \code{percentile = 0.5} the median.
#'
#' @param chm A \code{SpatRaster} of canopy heights in metres.
#'   Typically the \code{chm_clean} component returned by
#'   \code{\link{sanitize_chm}}.
#' @param units An \code{sf} polygon layer. One row per spatial
#'   unit.
#' @param percentile Numeric in \code{[0, 1]}. The percentile of
#'   canopy heights to take as dominant height. Default
#'   \code{0.9}.
#' @param min_pixels Integer. Minimum number of non-\code{NA}
#'   pixels required to compute \eqn{H_{dom}}. Units with fewer
#'   pixels get \code{NA}. Default \code{10}.
#'
#' @return A numeric vector of length \code{nrow(units)}
#'   containing the dominant height (in metres) for each unit.
#'   \code{NA} when the unit holds fewer than \code{min_pixels}
#'   valid pixels.
#'
#' @examples
#' \dontrun{
#' chm_clean <- sanitize_chm(chm, forest_mask = bd_foret)$chm_clean
#' units$H_dom <- extract_h_dom(chm_clean, units)
#' }
#'
#' @export
extract_h_dom <- function(chm, units, percentile = 0.9,
                          min_pixels = 10L) {
  if (!inherits(chm, "SpatRaster")) {
    stop("chm must be a terra SpatRaster", call. = FALSE)
  }
  if (!inherits(units, c("sf", "sfc"))) {
    stop("units must be an sf/sfc object", call. = FALSE)
  }
  if (!is.numeric(percentile) || length(percentile) != 1L ||
      is.na(percentile) || percentile < 0 || percentile > 1) {
    stop("percentile must be a scalar in [0, 1]", call. = FALSE)
  }

  units_proj <- sf::st_transform(units, terra::crs(chm))

  if (requireNamespace("exactextractr", quietly = TRUE)) {
    vals <- exactextractr::exact_extract(
      chm, units_proj, progress = FALSE,
      include_cell = FALSE
    )
  } else {
    vals <- terra::extract(chm, terra::vect(units_proj),
                           touches = TRUE)
    vals <- split(vals[, 2], vals[, 1])
  }

  vapply(vals, function(v) {
    x <- if (is.data.frame(v)) v$value else v
    x <- x[!is.na(x)]
    if (length(x) < min_pixels) return(NA_real_)
    stats::quantile(x, probs = percentile, names = FALSE,
                    type = 7)
  }, numeric(1))
}
