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
#'   (default \code{0.3}).
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
                         ndvi_threshold = 0.3) {
  if (!inherits(chm, "SpatRaster")) {
    stop("chm must be a terra SpatRaster", call. = FALSE)
  }

  steps <- character(0)
  n_valid_before <- sum(!is.na(terra::values(chm)))

  chm_out <- chm

  # Etape 1 : masque foret (obligatoire des qu'il est fourni)
  if (!is.null(forest_mask)) {
    chm_out <- .apply_forest_mask(chm_out, forest_mask)
    steps <- c(steps, "forest")
  }

  # Etape 2 : masque bati + eau
  if (!is.null(buildings)) {
    chm_out <- .apply_vector_mask(chm_out, buildings, inverse = TRUE)
    steps <- c(steps, "buildings")
  }
  if (!is.null(water)) {
    chm_out <- .apply_vector_mask(chm_out, water, inverse = TRUE)
    steps <- c(steps, "water")
  }

  # Etape 3 : seuillage NDVI
  if (!is.null(ndvi)) {
    if (!inherits(ndvi, "SpatRaster")) {
      stop("ndvi must be a SpatRaster", call. = FALSE)
    }
    ndvi_aligned <- .align_to(ndvi, chm_out)
    chm_out <- terra::ifel(ndvi_aligned < ndvi_threshold, NA, chm_out)
    steps <- c(steps, "ndvi")
  }

  # Etape 4 : bornes plausibles (toujours appliquee)
  chm_out <- terra::ifel(chm_out < 0 | chm_out > max_height, NA, chm_out)
  steps <- c(steps, "range")

  # Etape 5 : pente
  if (!is.null(slope)) {
    if (!inherits(slope, "SpatRaster")) {
      stop("slope must be a SpatRaster", call. = FALSE)
    }
    slope_aligned <- .align_to(slope, chm_out)
    chm_out <- terra::ifel(slope_aligned > 60, NA, chm_out)
    steps <- c(steps, "slope")
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
    mask_proj <- sf::st_transform(mask, terra::crs(chm))
    return(terra::mask(chm, terra::vect(mask_proj)))
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
  vec_proj <- sf::st_transform(vec, terra::crs(chm))
  terra::mask(chm, terra::vect(vec_proj), inverse = inverse)
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
