# ============================================================
# houppiers.R — crown segmentation on a Canopy Height Model
# ------------------------------------------------------------
# Produces the `houppier` layer of the Marculus GeoPackage: one polygon per
# tree crown, carrying the apex height, so that a stem marked in the field
# gets its height pre-filled by a point-in-polygon on the GNSS position.
#
# The contract is set downstream (`marculus/docs/specs/couche-houppier-mnh.md`)
# and three of its rules shape the code rather than the documentation:
#
#   * heights outside 1-70 m are REJECTED by the phone, so they are not
#     produced here — an empty crown scoring 0 m would silently write nothing
#     into a marking log;
#   * overlapping crowns are FINE — the phone keeps the tallest, the one whose
#     apex physically dominates the operator. The segmentation therefore does
#     not have to partition space, and no gap-filling is attempted: a position
#     inside no crown (gap, stand edge, suppressed stem) writes nothing rather
#     than guessing the neighbouring tree;
#   * the layer must be named `houppier` by the caller — that name is a
#     contract, not a convention.
# ============================================================


# Square aggregation factor bounding a raster under `max_cells`. Same idiom as
# `.eobs_ds_agg_factor()`; kept separate because THIS one aggregates by max.
.houppier_agg_factor <- function(r, resolution, max_cells) {
  res_in <- mean(terra::res(r))
  fac <- if (is.finite(resolution) && resolution > res_in) {
    max(1L, as.integer(round(resolution / res_in)))
  } else {
    1L
  }
  nc <- terra::ncell(r) / fac^2
  if (is.finite(max_cells) && max_cells > 0 && nc > max_cells) {
    fac <- max(fac, as.integer(ceiling(sqrt(terra::ncell(r) / max_cells))))
  }
  fac
}


#' Segment tree crowns on a Canopy Height Model
#'
#' @description
#' Delineates individual tree crowns from a CHM and returns one polygon per
#' crown with its apex height. This is the `houppier` layer consumed by the
#' Marculus marking application, where a stem's height is pre-filled by a
#' point-in-polygon on the GNSS position.
#'
#' @details
#' **Working resolution is decided here, not by the caller.** A crown is 3 to
#' 10 m across; segmenting a 0.20 m CHM neither adds silvicultural information
#' nor fits in memory — the Couchey CHM is 418 million cells. The CHM is
#' therefore aggregated to `resolution` (default 0.5 m) before anything else,
#' which divides the cost by 6 to 25, and further if the result would still
#' exceed `max_cells`.
#'
#' The aggregation uses **`max`, not `mean`**: the apexes are precisely what
#' local-maximum detection looks for, and a smoothing statistic would flatten
#' them away. This costs a slight upward bias on `h_max` (the tallest cell of
#' each aggregate wins) — deliberate, and preferable to losing a tree.
#'
#' Heights are read back with a zonal statistic on the raster
#' ([terra::zonal()]), never with a global `values()` or `extract()`: the same
#' innocent-looking call cost a 3 h 20 pipeline run on 2026-08-22.
#'
#' Crowns may overlap, and that is not a defect — see the file header.
#'
#' @param chm Canopy Height Model: a `SpatRaster` or a path readable by
#'   [terra::rast()]. Heights in **metres**, in a projected CRS.
#' @param aoi Optional `sf`/`sfc` clipping extent (typically the stand being
#'   marked). Reprojected to the CHM's CRS, then used to crop **and** mask.
#'   Cropping first is what bounds the memory of everything below.
#' @param ws Local-maximum search window, in metres. Roughly the crown radius
#'   of the dominant trees: too small splits a crown into several, too large
#'   merges neighbours.
#' @param hmin Minimum apex height, in metres. Below it, no tree is located.
#' @param algorithme `"dalponte"` (default), `"silva"` or `"watershed"`. The
#'   first two grow regions from located apexes; `"watershed"` ignores them and
#'   floods the inverted surface.
#' @param resolution Working resolution in metres (default `0.5`). Ignored when
#'   the CHM is already coarser.
#' @param max_cells Backstop cell cap for the working raster (default `2e7`).
#'   A CHM that is still too large after `resolution` is aggregated further.
#' @param h_range Admissible apex heights, in metres (default `c(1, 70)`).
#'   Crowns outside are dropped rather than shipped — the phone rejects them.
#'
#' @return An `sf` of POLYGON, one row per crown, with:
#'   \describe{
#'     \item{`houppier_id`}{integer, 1..n, ordered by decreasing `h_max`.}
#'     \item{`h_max`}{apex height in metres — the canonical Marculus name.}
#'     \item{`surface_m2`}{crown area in square metres.}
#'   }
#'   Zero crowns yields a zero-row `sf` with those columns, not `NULL`: the
#'   caller writes an empty layer rather than a missing one.
#'
#' @examples
#' \dontrun{
#' crowns <- segment_houppiers(
#'   "cache/layers/opencanopy/chm_predicted_0_2m.tif",
#'   aoi = ugf, ws = 5, hmin = 5
#' )
#' sf::st_write(crowns, "marculus.gpkg", layer = "houppier", append = FALSE)
#' }
#'
#' @seealso [extract_h_dom()] for the stand-level dominant height, which
#'   answers a different question on the same raster.
#' @export
segment_houppiers <- function(chm,
                              aoi        = NULL,
                              ws         = 5,
                              hmin       = 5,
                              algorithme = c("dalponte", "silva", "watershed"),
                              resolution = 0.5,
                              max_cells  = 2e7,
                              h_range    = c(1, 70)) {
  algorithme <- match.arg(algorithme)

  if (!requireNamespace("lidR", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg lidR} is required to segment crowns on a CHM.",
      i = "Install it: {.code install.packages('lidR')}."
    ))
  }
  if (!is.numeric(ws) || length(ws) != 1L || !is.finite(ws) || ws <= 0) {
    cli::cli_abort("{.arg ws} must be a single positive number of metres.")
  }
  if (!is.numeric(hmin) || length(hmin) != 1L || !is.finite(hmin)) {
    cli::cli_abort("{.arg hmin} must be a single number of metres.")
  }
  if (!is.numeric(h_range) || length(h_range) != 2L || h_range[1] >= h_range[2]) {
    cli::cli_abort("{.arg h_range} must be two increasing numbers, in metres.")
  }

  if (is.character(chm)) {
    if (!file.exists(chm)) cli::cli_abort("CHM not found: {.path {chm}}.")
    chm <- terra::rast(chm)
  }
  if (!inherits(chm, "SpatRaster")) {
    cli::cli_abort("{.arg chm} must be a {.cls SpatRaster} or a path to one.")
  }
  if (terra::nlyr(chm) > 1L) chm <- chm[[1L]]

  # Re-stamp a degenerate WKT with its authority code. The Couchey CHM carries
  # the NAME "EPSG:2154" but no authority, so `sf::st_crs(x)$epsg` reads NA and
  # the GeoPackage would ship a CRS the phone cannot match to a known system.
  # Same class of defect as the cached WMS/LiDAR rasters — recoverable, and
  # cheaper to fix here than to explain downstream.
  chm <- .normalize_crs(chm)

  # `ws` and `hmin` are metres; a geographic CRS would silently read them as
  # degrees and locate one tree per stand.
  if (isTRUE(terra::is.lonlat(chm))) {
    cli::cli_abort(c(
      "The CHM is in a geographic CRS (degrees).",
      i = "{.arg ws} and {.arg hmin} are metres — reproject to a metric CRS first."
    ))
  }

  # 1. Clip FIRST. Everything below is sized by what survives here.
  if (!is.null(aoi)) {
    aoi_v <- terra::vect(sf::st_transform(sf::st_as_sf(aoi), terra::crs(chm)))
    # Check the overlap BEFORE cropping: `terra::crop()` aborts on disjoint
    # extents with "[crop] extents do not overlap", which names neither the
    # argument at fault nor what the caller should do about it.
    if (!terra::relate(terra::ext(chm), terra::ext(aoi_v), "intersects")) {
      cli::cli_abort(c(
        "The {.arg aoi} does not intersect the CHM.",
        i = "Check they describe the same site: the CHM covers {.val {as.character(terra::ext(chm))}}."
      ))
    }
    chm <- terra::crop(chm, aoi_v, mask = TRUE)
    if (terra::ncell(chm) == 0L) {
      cli::cli_abort("The {.arg aoi} does not intersect the CHM.")
    }
  }

  # 2. Working resolution — by max, to keep the apexes (see @details).
  fac <- .houppier_agg_factor(chm, resolution, max_cells)
  if (fac > 1L) {
    chm <- terra::aggregate(chm, fact = fac, fun = "max", na.rm = TRUE)
  }

  # 3. Apexes, then crowns around them.
  seg <- if (identical(algorithme, "watershed")) {
    lidR::watershed(chm, th_tree = hmin)()
  } else {
    tops <- lidR::locate_trees(chm, lidR::lmf(ws = ws, hmin = hmin))
    if (is.null(tops) || nrow(tops) == 0L) return(.houppier_empty(chm))
    if (identical(algorithme, "dalponte")) {
      lidR::dalponte2016(chm, tops, th_tree = hmin)()
    } else {
      lidR::silva2016(chm, tops, ID = "treeID")()
    }
  }
  if (is.null(seg) || all(is.na(terra::minmax(seg)))) return(.houppier_empty(chm))

  # 4. Apex height per crown — zonal, never a global read.
  h <- terra::zonal(chm, seg, fun = "max", na.rm = TRUE)
  names(h) <- c("zone", "h_max")

  polys <- sf::st_as_sf(terra::as.polygons(seg, dissolve = TRUE))
  names(polys)[1L] <- "zone"
  polys <- merge(polys, h, by = "zone", all.x = TRUE)

  # 5. The downstream contract: nothing outside 1-70 m leaves this function.
  keep <- !is.na(polys$h_max) &
    polys$h_max >= h_range[1] & polys$h_max <= h_range[2]
  polys <- polys[keep, , drop = FALSE]
  if (nrow(polys) == 0L) return(.houppier_empty(chm))

  polys <- polys[order(-polys$h_max), , drop = FALSE]
  out <- sf::st_sf(
    houppier_id = seq_len(nrow(polys)),
    h_max       = as.numeric(polys$h_max),
    surface_m2  = as.numeric(sf::st_area(polys)),
    geometry    = sf::st_geometry(polys)
  )
  sf::st_agr(out) <- "constant"
  out
}


# Zero crowns is a legitimate answer (a clearing, a stand under `hmin`): give
# the caller the same columns so it writes an EMPTY layer, not a missing one.
.houppier_empty <- function(chm) {
  sf::st_sf(
    houppier_id = integer(0),
    h_max       = numeric(0),
    surface_m2  = numeric(0),
    geometry    = sf::st_sfc(crs = sf::st_crs(terra::crs(chm)))
  )
}
