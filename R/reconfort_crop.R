# reconfort_crop.R — AOI-scoped preprocessing for the RECONFORT chain
# (spec 021, productionisation 2026-06-24).
#
# IOTA2 processes a whole MGRS tile (10980x10980 px) regardless of the AOI.
# For a small monitoring zone that is ~2 000 000:1 wasted compute (7 h for
# ~60 useful pixels). These helpers clip + reproject the extracted Sentinel-2
# scenes to the AOI (+ buffer) IN THE OUTPUT PROJECTION before IOTA2, which:
#   * cuts the run from hours to ~minutes,
#   * sidesteps an IOTA2 reference-grid bug seen when the input is in the tile
#     CRS (EPSG:32631) but the output projection is EPSG:2154 — pre-reprojecting
#     the clip to 2154 makes IOTA2's SuperImpose / envelope footprint correct,
#   * keeps the result valid: gap-filling, the CRswir/CRre indices and the
#     SharkRF v3 model are all per-pixel, so clipping changes nothing for the
#     kept pixels.
#
# Everything stays per-run and AOI-local: the ground-truth points (1+ per class
# for IOTA2's dummy part-1 sampling) and the OSO broadleaf mask are regenerated
# inside the AOI window, never the global/national footprint.

# Resolve the national OSO land-cover raster (used to cut the AOI broadleaf
# mask). Overridable via `options(nemeton.reconfort_oso_national)`; defaults to
# `<global cache>/oso/oso.tif`. Returns NULL when absent.
.reconfort_oso_national_path <- function() {
  p <- getOption("nemeton.reconfort_oso_national",
                 file.path(get_global_cache_dir(), "oso", "oso.tif"))
  if (length(p) == 1L && file.exists(p)) p else NULL
}

# Buffer (m) added around the AOI bbox before clipping. Generous enough that
# IOTA2's envelope step (which needs a non-degenerate footprint and a ~600 m
# nodata management offset) and the AOI ground-truth points have room.
.RECONFORT_AOI_BUFFER_M <- 3000

# Resolve the AOI bbox (xmin, ymin, xmax, ymax) in `target_crs`, padded by
# `buffer_m` and snapped to a 20 m grid (so 10 m and 20 m bands align).
.reconfort_aoi_window <- function(aoi, target_crs = 2154,
                                  buffer_m = .RECONFORT_AOI_BUFFER_M) {
  g  <- sf::st_transform(sf::st_geometry(aoi), target_crs)
  bb <- sf::st_bbox(g)
  snap <- function(v, down) {
    if (down) floor(v / 20) * 20 else ceiling(v / 20) * 20
  }
  c(xmin = snap(bb[["xmin"]] - buffer_m, TRUE),
    ymin = snap(bb[["ymin"]] - buffer_m, TRUE),
    xmax = snap(bb[["xmax"]] + buffer_m, FALSE),
    ymax = snap(bb[["ymax"]] + buffer_m, FALSE))
}

# Clip + reproject one raster to `target_crs` over `win`, preserving the
# source pixel size. Masks use nearest-neighbour (categorical), reflectance
# bands too (IOTA2 resamples internally to its own grid; nearest keeps the
# clip honest and fast).
.reconfort_warp_one <- function(src, dst, win, target_crs) {
  res <- terra::res(terra::rast(src))
  sf::gdal_utils(
    "warp", source = src, destination = dst,
    options = c(
      "-t_srs", sprintf("EPSG:%s", target_crs),
      "-te", win[["xmin"]], win[["ymin"]], win[["xmax"]], win[["ymax"]],
      "-te_srs", sprintf("EPSG:%s", target_crs),
      "-tr", res[1], res[2],
      "-r", "near", "-overwrite", "-q"
    )
  )
  invisible(dst)
}

#' Clip + reproject the extracted Sentinel-2 scenes to the AOI window
#'
#' For each MUSCATE scene under `extracted_dirs`, clips every band + mask to
#' the AOI window (in `target_crs`), preserving the scene directory layout
#' (`<scene>/*.tif`, `<scene>/MASKS/*.tif`, metadata `*.xml` copied verbatim)
#' so IOTA2 reads it unchanged. Returns the new extracted directories.
#'
#' @param extracted_dirs Character. Per-tile extraction dirs (the
#'   `reconfort_ingest_s2()` output, `<s2_root>/extracted/<tile>/`).
#' @param aoi An `sf`/`sfc` AOI (the monitoring zone geometry).
#' @param out_root Character. Root for the cropped layout
#'   (`<out_root>/<tile>/`).
#' @param target_crs Integer EPSG of the output projection (default 2154).
#' @param buffer_m Numeric buffer around the AOI bbox (default 3000).
#' @param quiet Logical.
#' @return Character vector of cropped per-tile extraction dirs.
#' @keywords internal
.reconfort_crop_scenes_to_aoi <- function(extracted_dirs, aoi, out_root,
                                          target_crs = 2154,
                                          buffer_m = .RECONFORT_AOI_BUFFER_M,
                                          quiet = FALSE) {
  win <- .reconfort_aoi_window(aoi, target_crs, buffer_m)
  out_dirs <- character(0)
  for (ext in extracted_dirs) {
    tile <- basename(ext)
    out_tile <- file.path(out_root, tile)
    scenes <- list.dirs(ext, recursive = FALSE)
    n_tif <- 0L
    for (scene in scenes) {
      sc <- basename(scene)
      dir.create(file.path(out_tile, sc, "MASKS"), recursive = TRUE,
                 showWarnings = FALSE)
      tifs <- c(list.files(scene, pattern = "\\.tif$", full.names = TRUE),
                list.files(file.path(scene, "MASKS"), pattern = "\\.tif$",
                           full.names = TRUE))
      for (tif in tifs) {
        rel <- sub(paste0("^", scene, "/?"), "", tif)
        .reconfort_warp_one(tif, file.path(out_tile, sc, rel), win, target_crs)
        n_tif <- n_tif + 1L
      }
      # metadata (MTD XML etc.) copied verbatim — IOTA2 reads dates from it
      xmls <- c(list.files(scene, pattern = "\\.xml$", full.names = TRUE),
                list.files(file.path(scene, "MASKS"), pattern = "\\.xml$",
                           full.names = TRUE))
      for (x in xmls) {
        rel <- sub(paste0("^", scene, "/?"), "", x)
        file.copy(x, file.path(out_tile, sc, rel), overwrite = TRUE)
      }
    }
    if (!quiet) {
      cli::cli_alert_info(
        "RECONFORT: clipped {.val {tile}} to AOI window ({n_tif} rasters).")
    }
    out_dirs <- c(out_dirs, out_tile)
  }
  out_dirs
}

#' Regenerate IOTA2's ground-truth points inside the AOI window
#'
#' IOTA2's part-1 sampling needs at least one labelled point per class within
#' the tile envelope. The vendored `random_points.shp` scatters them across
#' France, so after clipping to a small AOI none intersect and
#' `VectorFormatting` fails. This writes a fresh shapefile with a handful of
#' dummy points per class inside the AOI window — the labels are irrelevant
#' (the real v3 model is grafted in for part 2).
#'
#' @param out_shp Character. Destination shapefile path (overwrites the staged
#'   `iota2/vector_db/random_points.shp`).
#' @param aoi An `sf`/`sfc` AOI.
#' @param n_classes Integer. Number of RECONFORT classes (3 oak/chestnut,
#'   2 pine).
#' @param target_crs Integer EPSG (default 2154).
#' @param per_class Integer points per class (default 4).
#' @keywords internal
.reconfort_write_aoi_ground_truth <- function(out_shp, aoi, n_classes,
                                              target_crs = 2154,
                                              per_class = 4L) {
  win <- .reconfort_aoi_window(aoi, target_crs, buffer_m = 0)
  # inner 60% of the window, to stay clear of the envelope edge
  fx <- function(t) win[["xmin"]] + (win[["xmax"]] - win[["xmin"]]) * t
  fy <- function(t) win[["ymin"]] + (win[["ymax"]] - win[["ymin"]]) * t
  ts <- seq(0.2, 0.8, length.out = per_class)
  recs <- list()
  i <- 0L
  for (cls in seq_len(n_classes)) {
    for (k in seq_len(per_class)) {
      i <- i + 1L
      recs[[i]] <- sf::st_sf(
        dep_cor    = cls,
        point_name = sprintf("AOI_%d_%d", cls, k),
        geometry   = sf::st_sfc(
          sf::st_point(c(fx(ts[k]) + cls * 30, fy(ts[k]) + cls * 30)),
          crs = target_crs))
    }
  }
  gt <- do.call(rbind, recs)
  if (file.exists(out_shp)) {
    for (ext in c(".shp", ".shx", ".dbf", ".prj", ".cpg")) {
      unlink(sub("\\.shp$", ext, out_shp))
    }
  }
  sf::st_write(gt, out_shp, quiet = TRUE, delete_dsn = TRUE)
  invisible(out_shp)
}

#' Build the OSO broadleaf (deciduous) mask for the AOI window
#'
#' Windows the national OSO land-cover raster to the AOI (+ buffer) and keeps
#' the broadleaf-forest class (OSO 23-class code 16 = *forêt de feuillus*) as a
#' binary `uint8` mask (1 = broadleaf, 0 = other), in `target_crs`. This
#' replaces the partial regional mask redistributed upstream, which does not
#' cover most of France.
#'
#' @param oso_path Character. National OSO classification raster
#'   (e.g. `<user cache>/oso/oso.tif`, EPSG:2154, 10 m, 23-class).
#' @param aoi An `sf`/`sfc` AOI.
#' @param out_path Character. Destination GeoTIFF.
#' @param broadleaf_class Integer OSO code for broadleaf forest (default 16).
#' @param target_crs Integer EPSG (default 2154).
#' @param buffer_m Numeric buffer (default 3000).
#' @return `out_path`, invisibly.
#' @keywords internal
.reconfort_oso_broadleaf_mask <- function(oso_path, aoi, out_path,
                                          broadleaf_class = 16L,
                                          target_crs = 2154,
                                          buffer_m = .RECONFORT_AOI_BUFFER_M) {
  win  <- .reconfort_aoi_window(aoi, target_crs, buffer_m)
  oso  <- terra::rast(oso_path)
  ext  <- terra::ext(win[["xmin"]], win[["xmax"]], win[["ymin"]], win[["ymax"]])
  # reproject the AOI window to the OSO CRS for cropping, then (if needed)
  # reproject the small crop to target_crs.
  oso_epsg <- suppressWarnings(as.integer(
    terra::crs(oso, describe = TRUE)$code))
  if (!is.na(oso_epsg) && oso_epsg != target_crs) {
    win_src <- sf::st_bbox(sf::st_transform(
      sf::st_as_sfc(sf::st_bbox(c(xmin = win[["xmin"]], ymin = win[["ymin"]],
                                  xmax = win[["xmax"]], ymax = win[["ymax"]]),
                                crs = target_crs)), oso_epsg))
    ext_src <- terra::ext(win_src[["xmin"]], win_src[["xmax"]],
                          win_src[["ymin"]], win_src[["ymax"]])
    crop <- terra::crop(oso, ext_src)
    crop <- terra::project(crop, sprintf("EPSG:%s", target_crs),
                           method = "near")
    crop <- terra::crop(crop, ext)
  } else {
    crop <- terra::crop(oso, ext)
  }
  mask <- terra::ifel(crop == broadleaf_class, 1L, 0L)
  terra::writeRaster(mask, out_path, overwrite = TRUE, datatype = "INT1U")
  invisible(out_path)
}
