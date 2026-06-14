# Per-pixel Sentinel-2 visualization helpers (spec 010).
#
# Exposes the cropped Sentinel-2 bands cached on disk by
# `ingest_sentinel2_timeseries(..., cache_dir = ...)` as SpatRaster
# objects, plus index stacks (NDVI / NBR) and per-pixel time series
# extraction. The cache layout
# `<cache_dir>/{scene_id}/{B04,B08,B12}.tif` is owned by R/monitoring.R
# (`.s2_band_cache_path`) — both sides resolve the path through the
# shared private helper `.s2_safe_scene_id()` to guarantee write/read
# agreement.
#
# All functions are read-only (no HTTP, no DB write). Missing scenes
# are tolerated and reported via a single aggregated warning rather
# than per-scene errors — the goal is "useful map even with a
# partially populated cache" rather than "fail loud on first hole".

#' Read a single cached Sentinel-2 band as a SpatRaster
#'
#' Opens `<cache_dir>/<sanitized_scene_id>/<band>.tif` and returns the
#' corresponding [terra::SpatRaster] object. No HTTP. The file is
#' produced by [ingest_sentinel2_timeseries()] when called with a
#' non-NULL `cache_dir`.
#'
#' Returns `NULL` (not an error) when the file is absent — callers like
#' [read_s2_band_stack()] use this to skip missing scenes silently and
#' emit a single aggregated warning.
#'
#' @param cache_dir Character(1). Path to the S2 cache root, e.g.
#'   `<project>/cache/layers/sentinel2`.
#' @param scene_id Character(1). The Sentinel-2 scene id as returned
#'   by the STAC search and stored in `obs_pixel.scene_id`. The on-disk
#'   directory name is its sanitized form (cf.
#'   `nemeton:::.s2_safe_scene_id`).
#' @param band Character(1). One of `"B04"` (Red, 10 m), `"B08"`
#'   (NIR, 10 m), `"B12"` (SWIR2, 20 m), `"B11"` (SWIR1, 20 m, used by
#'   NDMI), `"B05"` (Red-edge 1, 20 m) or `"B8A"` (NIR narrow, 20 m,
#'   both used by NDRE, spec 022).
#'
#' @return A 1-layer [terra::SpatRaster] in the source CRS (typically
#'   EPSG:32631 or 32632 — UTM zones over France), or `NULL` if the
#'   file is missing. The raster is **not** reprojected — leaflet /
#'   leafem handles that downstream.
#'
#' @examples
#' \dontrun{
#'   cache <- "/home/user/projects/myforest/cache/layers/sentinel2"
#'   r <- read_s2_band_raster(cache,
#'                            "S2A_MSIL2A_20260508T103651_R008_T31TFN_20260508T191011",
#'                            "B04")
#'   terra::plot(r)
#' }
#'
#' @seealso [read_s2_band_stack()] for multi-temporal stacks,
#'   [build_index_stack()] for NDVI / NBR, [extract_pixel_timeseries()]
#'   for per-pixel time series, [diagnose_s2_cache()] to inspect what's
#'   on disk, [ingest_sentinel2_timeseries()] for the write path.
#' @export
read_s2_band_raster <- function(cache_dir, scene_id, band) {
  if (!is.character(cache_dir) || length(cache_dir) != 1L ||
      is.na(cache_dir) || !nzchar(cache_dir)) {
    stop("`cache_dir` must be a single non-empty character path.",
         call. = FALSE)
  }
  if (!is.character(scene_id) || length(scene_id) != 1L ||
      is.na(scene_id) || !nzchar(scene_id)) {
    stop("`scene_id` must be a single non-empty character.",
         call. = FALSE)
  }
  band <- match.arg(band, c("B04", "B08", "B12", "B11", "B05", "B8A"))

  path <- file.path(cache_dir, .s2_safe_scene_id(scene_id),
                    paste0(band, ".tif"))
  if (!file.exists(path)) return(NULL)
  terra::rast(path)
}

#' Read a multi-temporal stack for one Sentinel-2 band
#'
#' Stacks the cached `<band>.tif` files of several scenes into a
#' single [terra::SpatRaster] with one layer per observation date.
#' Layers are named by `as.character(obs_date)` and the corresponding
#' [terra::time()] attribute is set, so callers can index by date.
#'
#' Missing scenes (no `<band>.tif` on disk) are skipped silently and
#' reported via a **single aggregated warning** — never one warning
#' per missing scene. Returns `NULL` if every scene is missing.
#'
#' @param cache_dir Character(1). Same as [read_s2_band_raster()].
#' @param scenes_df A `data.frame` with at minimum columns
#'   `scene_id` (character) and `obs_date` (Date, or coercible). Extra
#'   columns are ignored. Rows are re-ordered by `obs_date` internally.
#'   In practice this is the listing of scenes present in the COG cache
#'   directory for the zone.
#' @param band Character(1). One of `"B04"`, `"B08"`, `"B12"`, `"B11"`.
#'
#' @return A multi-layer [terra::SpatRaster] in source CRS, with
#'   `names(out)` = `as.character(obs_date)` and `terra::time(out)`
#'   set to the dates of the surviving scenes. `NULL` when no scene
#'   could be opened.
#'
#' @examples
#' \dontrun{
#'   cache <- "/proj/cache/layers/sentinel2"
#'   # scenes is a data.frame of (scene_id, obs_date); typically the
#'   # cache directory listing for the zone.
#'   scenes <- data.frame(
#'     scene_id = "S2A_MSIL2A_20250610T103031_R108_T31TGM",
#'     obs_date = as.Date("2025-06-10"))
#'   stack  <- read_s2_band_stack(cache, scenes, "B04")
#'   terra::time(stack)        # the dates as a vector
#'   terra::plot(stack[[1]])   # first scene
#' }
#'
#' @seealso [read_s2_band_raster()], [build_index_stack()] for
#'   computed NDVI / NBR layers, [extract_pixel_timeseries()].
#' @export
read_s2_band_stack <- function(cache_dir, scenes_df, band) {
  .validate_scenes_df(scenes_df)
  band <- match.arg(band, c("B04", "B08", "B12", "B11"))

  scenes_df <- scenes_df[order(as.Date(scenes_df$obs_date)), , drop = FALSE]

  rasters <- lapply(seq_len(nrow(scenes_df)), function(i) {
    read_s2_band_raster(cache_dir, scenes_df$scene_id[i], band)
  })
  ok <- !vapply(rasters, is.null, logical(1))
  n_total   <- nrow(scenes_df)
  n_missing <- sum(!ok)

  if (n_missing > 0L) {
    cli::cli_warn(c(
      "Skipped {n_missing}/{n_total} scene{?s} (no cached {.field {band}}).",
      i = "Run {.fn ingest_sentinel2_timeseries} with the same {.code cache_dir} to refill."
    ))
  }
  if (!any(ok)) return(NULL)

  out <- terra::rast(rasters[ok])
  names(out)       <- as.character(scenes_df$obs_date[ok])
  terra::time(out) <- as.Date(scenes_df$obs_date[ok])
  out
}

#' Build a multi-temporal NDVI or NBR stack from cached Sentinel-2 bands
#'
#' For each scene in `scenes_df`, opens the required cached bands and
#' computes the requested spectral index pixel-wise:
#'
#' * **NDVI** = (B08 − B04) / (B08 + B04) — proxy of vegetation vigour
#' * **NBR** = (B08 − B12) / (B08 + B12) — proxy of vegetation /
#'   burned-area discrimination.
#' * **NDMI** = (B08 − B11) / (B08 + B11) — vegetation moisture proxy
#'   (drops under water stress). B11 is natively 20 m, so it is
#'   resampled to the B08 10 m grid like B12.
#' * **NDRE** = (B8A − B05) / (B8A + B05) — red-edge proxy of
#'   chlorophyll content, an early marker of canopy stress (spec 022).
#'   Both B8A and B05 are natively 20 m and share the same grid, so the
#'   index is computed at 20 m without resampling.
#'
#'   B12 (NBR) is natively 20 m, so it is
#'   resampled to the B08 10 m grid via [terra::resample()] with
#'   `method = "bilinear"`.
#'
#' Scenes with incomplete cached bands (missing B04, B08, B12 for NBR,
#' B11 for NDMI, or B05 / B8A for NDRE) are skipped silently with a
#' single aggregated warning. For NDRE specifically, a cache that holds
#' **no** scene with both red-edge bands aborts up front (internal
#' `.assert_cache_has_bands()` guard) rather than returning a silent
#' all-NA raster. NAs
#' propagate naturally through the arithmetic: a NA in any source
#' pixel yields NA in the index.
#'
#' @param cache_dir Character(1). Path to the S2 cache root.
#' @param scenes_df See [read_s2_band_stack()].
#' @param index Character(1). One of `"NDVI"` (default), `"NBR"`,
#'   `"NDMI"` or `"NDRE"` (red-edge, spec 022).
#' @param mask_polygon Optional `sf`/`sfc` polygon. When supplied, pixels
#'   outside it become NA on every layer.
#' @param parallel Logical (spec 017 D4). When `TRUE` and \pkg{furrr} is
#'   installed, the per-scene index computation runs in
#'   `furrr::future_map()` (set a `future::plan()` first); workers return
#'   `terra::wrap()`-ed rasters that the main process unwraps. Default
#'   `FALSE` (sequential, identical results). Falls back to sequential if
#'   \pkg{furrr} is absent.
#'
#' @return A multi-layer [terra::SpatRaster] in source CRS at 10 m,
#'   values in `[-1, 1]` (NAs preserved), layers named by `obs_date`
#'   with `terra::time()` set, and an `"index"` attribute carrying
#'   the chosen index name. `NULL` if no scene survives.
#'
#' @section Why arithmetic alone is enough:
#' Sentinel-2 L2A reflectances are non-negative, so `(a − b) / (a + b)`
#' stays in `[-1, 1]` mathematically. No `clamp()` needed.
#'
#' @section Note on B12 resampling:
#' `extract_pixel_timeseries()` deliberately does **not** resample B12
#' — for a single-point extraction the natively 20 m pixel containing
#' the click is what the user wants. So `build_index_stack()` at
#' point `(x, y)` may differ from `extract_pixel_timeseries()` at the
#' same `(x, y)` by a sub-pixel amount when `index = "NBR"`. This is
#' documented and intentional.
#'
#' @examples
#' \dontrun{
#'   cache <- "/proj/cache/layers/sentinel2"
#'   scenes <- data.frame(
#'     scene_id = "S2A_MSIL2A_20250610T103031_R108_T31TGM",
#'     obs_date = as.Date("2025-06-10"))
#'   ndvi_stack <- build_index_stack(cache, scenes, "NDVI")
#'   terra::plot(ndvi_stack[[1]])
#' }
#'
#' @seealso [read_s2_band_stack()], [extract_pixel_timeseries()].
#' @export
build_index_stack <- function(cache_dir, scenes_df,
                              index = c("NDVI", "NBR", "NDMI", "NDRE"),
                              mask_polygon = NULL,
                              parallel = FALSE) {
  index <- match.arg(index)
  .validate_scenes_df(scenes_df)

  bands_needed <- switch(index,
    NDVI = c("B04", "B08"),
    NBR  = c("B08", "B12"),
    NDMI = c("B08", "B11"),
    NDRE = c("B8A", "B05")
  )

  # spec 022 — NDRE is opt-in (red-edge bands are only cached when an
  # ingestion explicitly requests them). Fail fast with a clear message
  # if the cache holds no scene carrying both bands, rather than letting
  # the per-scene skip below collapse to a silent all-NA / NULL result.
  # NDVI / NBR / NDMI keep their historical tolerant behaviour.
  if (index == "NDRE") .assert_cache_has_bands(cache_dir, bands_needed)

  scenes_df <- scenes_df[order(as.Date(scenes_df$obs_date)), , drop = FALSE]

  # Per-scene index raster: open the cached bands, compute the index.
  # Pure compute, no DB — safe to run concurrently (spec 017 D4).
  one_layer <- function(i) {
    sid <- scenes_df$scene_id[i]
    rs  <- stats::setNames(
      lapply(bands_needed, function(b) read_s2_band_raster(cache_dir, sid, b)),
      bands_needed
    )
    if (any(vapply(rs, is.null, logical(1)))) return(NULL)

    if (index == "NDVI") {
      (rs$B08 - rs$B04) / (rs$B08 + rs$B04)
    } else if (index == "NBR") {
      # B12 at 20 m onto B08's 10 m grid via bilinear resampling.
      b12_10m <- terra::resample(rs$B12, rs$B08, method = "bilinear")
      (rs$B08 - b12_10m) / (rs$B08 + b12_10m)
    } else if (index == "NDMI") {
      # NDMI = (B08 - B11) / (B08 + B11). B11 is native 20 m, resampled
      # to B08's 10 m grid bilinearly, exactly like B12 for NBR.
      b11_10m <- terra::resample(rs$B11, rs$B08, method = "bilinear")
      (rs$B08 - b11_10m) / (rs$B08 + b11_10m)
    } else {
      # NDRE = (B8A - B05) / (B8A + B05). Both bands are native 20 m and
      # share the same grid, so no resampling is needed — the index is a
      # 20 m raster (spec 022).
      (rs$B8A - rs$B05) / (rs$B8A + rs$B05)
    }
  }

  # spec 017 D4 — optional multi-core scene processing. A SpatRaster is
  # an external pointer that can't cross a process boundary, so workers
  # return `terra::wrap()`-ed rasters that the main process unwraps. Off
  # by default; opt-in `parallel = TRUE` (needs the `furrr` Suggest and a
  # `future::plan()` set by the caller). Falls back to sequential
  # `lapply` when `furrr` is absent.
  if (isTRUE(parallel) && requireNamespace("furrr", quietly = TRUE)) {
    packed <- furrr::future_map(
      seq_len(nrow(scenes_df)),
      function(i) { r <- one_layer(i); if (is.null(r)) NULL else terra::wrap(r) },
      .options = furrr::furrr_options(seed = TRUE, packages = "nemeton"))
    layers <- lapply(packed,
                     function(p) if (is.null(p)) NULL else terra::unwrap(p))
  } else {
    if (isTRUE(parallel)) {
      rlang::inform(
        "build_index_stack: `parallel = TRUE` ignored ({.pkg furrr} not installed); running sequentially.",
        .frequency = "once", .frequency_id = "build_index_stack_no_furrr")
    }
    layers <- lapply(seq_len(nrow(scenes_df)), one_layer)
  }

  ok <- !vapply(layers, is.null, logical(1))
  n_total   <- nrow(scenes_df)
  n_missing <- sum(!ok)

  if (n_missing > 0L) {
    # Deduplicated to once-per-session: a Shiny reactive re-evaluates
    # build_index_stack() ~12x per load, and the old `cli_warn` spammed
    # the console with N identical lines. The skip itself is benign
    # (e.g. FORDEAD-only dates that carry B8A but no B08 never render
    # NDVI/NBR by construction), so an informational note is enough.
    rlang::inform(
      cli::format_inline(
        "build_index_stack: skipped {n_missing}/{n_total} scene{?s} \\
         (incomplete cache for {.field {index}}); run \\
         {.fn diagnose_s2_cache} to find the gaps."),
      .frequency    = "once",
      .frequency_id = "build_index_stack_skipped")
  }
  if (!any(ok)) return(NULL)

  valid_layers <- layers[ok]

  # spec 010 / v0.52.x — align all per-scene layers onto the UNION of
  # their extents before stacking, padding the uncovered margins with
  # NA. An AOI that straddles two overlapping MGRS tiles (e.g. villards
  # on T31TFM ⊂ T31TGM) yields per-scene rasters with heterogeneous
  # extents: the narrow tile only covers the overlap strip, the wide
  # tile covers the whole AOI. Cropping to the intersection (the old
  # v0.47.5 behaviour) silently dropped the half of the AOI only the
  # wide tile reached. We now `terra::extend` every layer to the union,
  # so the stack covers the full footprint and the dates whose scene
  # only partially covers it carry honest NA outside their reach — no
  # invented pixels. Downstream consumers (the app's per-date mosaic,
  # `.apply_zone_mask`) are unchanged.
  ref <- valid_layers[[1L]]

  # Guard: layers in a different CRS (rare — an AOI spanning two UTM
  # zones at a zone border) are reprojected onto the reference layer's
  # CRS *before* the union. Same-CRS layers (the nominal case: a single
  # S2 tile grid) are left untouched, so the common path only pads.
  n_reproj <- sum(crs_mismatch <- !vapply(
    valid_layers, function(l) terra::same.crs(l, ref), logical(1)))
  if (n_reproj > 0L) {
    rlang::inform(
      cli::format_inline(
        "build_index_stack: reprojecting {n_reproj} layer{?s} onto the \\
         reference CRS before stacking (multi-zone AOI)."),
      .frequency    = "once",
      .frequency_id = "build_index_stack_reproject")
    valid_layers[crs_mismatch] <- lapply(
      valid_layers[crs_mismatch],
      function(l) terra::project(l, terra::crs(ref), method = "bilinear"))
  }

  # Union extent = outer bounding box of every (possibly reprojected)
  # layer's extent.
  exts <- lapply(valid_layers, terra::ext)
  target_ext <- terra::ext(
    min(vapply(exts, terra::xmin, numeric(1))),
    max(vapply(exts, terra::xmax, numeric(1))),
    min(vapply(exts, terra::ymin, numeric(1))),
    max(vapply(exts, terra::ymax, numeric(1))))

  # Do all layers share the reference grid (same resolution, origin
  # offset an integer number of pixels)? If so, the cheap `extend`
  # (pad NA, values preserved exactly) is enough. Otherwise — sub-pixel
  # origin/res drift, or a reprojected layer — fall back to a single
  # `resample` onto the widest layer's grid extended to the union.
  ref_res  <- terra::res(ref)
  ref_xmin <- terra::xmin(ref)
  ref_ymin <- terra::ymin(ref)
  on_ref_grid <- function(l) {
    rr <- terra::res(l)
    if (!isTRUE(all.equal(rr, ref_res, tolerance = 1e-6))) return(FALSE)
    dx <- (terra::xmin(l) - ref_xmin) / ref_res[1L]
    dy <- (terra::ymin(l) - ref_ymin) / ref_res[2L]
    isTRUE(all.equal(dx, round(dx), tolerance = 1e-4)) &&
      isTRUE(all.equal(dy, round(dy), tolerance = 1e-4))
  }

  if (all(vapply(valid_layers, on_ref_grid, logical(1)))) {
    valid_layers <- lapply(valid_layers,
                           function(l) terra::extend(l, target_ext))
  } else {
    rlang::inform(
      cli::format_inline(
        "build_index_stack: resampling layers onto a common grid \\
         (extents/origins do not coincide)."),
      .frequency    = "once",
      .frequency_id = "build_index_stack_resample")
    areas <- vapply(exts, function(e) {
      (terra::xmax(e) - terra::xmin(e)) * (terra::ymax(e) - terra::ymin(e))
    }, numeric(1))
    template <- terra::extend(valid_layers[[which.max(areas)]], target_ext)
    valid_layers <- lapply(valid_layers,
                           function(l) terra::resample(l, template,
                                                       method = "bilinear"))
  }

  out <- terra::rast(valid_layers)
  names(out)       <- as.character(scenes_df$obs_date[ok])
  terra::time(out) <- as.Date(scenes_df$obs_date[ok])
  attr(out, "index") <- index

  # spec 016 (v0.49.0) — optional UGF zone mask. Pixels outside the
  # polygon become NA on every layer. Unlike the read_*() functions,
  # build_index_stack() has no `con` / `zone_id` so the polygon must
  # be passed explicitly. Callers like `read_fast_alert_raster()`
  # already resolve it and propagate.
  if (!is.null(mask_polygon)) {
    out <- .apply_zone_mask(out, mask_polygon)
  }
  out
}

#' Extract a per-pixel NDVI / NBR time series at one geographic point
#'
#' Reads, for each scene in `scenes_df`, the cached source bands needed
#' for the requested indices and returns the value of the pixel
#' containing the point `xy`. The point is transformed from its input
#' CRS (`crs`, default WGS84 = EPSG:4326 — the convention used by
#' leaflet `input$map_click`) to each scene's source CRS internally.
#'
#' Behaviour at the boundaries:
#'
#' * **Scene with incomplete cache** (e.g. B08 missing) → the row for
#'   that `obs_date` is present in the output with `value = NA`. The
#'   missing-scene case is **not** skipped silently here — the user
#'   wants to see the temporal hole on the plotly, not have it
#'   disappear.
#' * **Point outside the raster footprint** → `value = NA` for every
#'   date / index.
#' * **NA pixel** (cloud mask, no data) → `value = NA` for that date.
#'
#' For NBR, B12 is sampled at its native 20 m resolution (no resample).
#' This intentionally differs from [build_index_stack()] where B12 is
#' resampled bilinearly to the B08 10 m grid — see the *Note on B12
#' resampling* section there. Net effect: NBR at point `(x, y)` from
#' `extract_pixel_timeseries()` may differ from the same point read
#' off `build_index_stack()` by a sub-pixel amount.
#'
#' @param cache_dir Character(1). Path to the S2 cache root.
#' @param scenes_df See [read_s2_band_stack()].
#' @param xy Numeric(2). Coordinates `c(x, y)` of the point of interest
#'   in the CRS specified by `crs`.
#' @param crs Coordinate reference system of `xy`. Accepts anything
#'   [sf::st_crs()] understands: an EPSG integer (default `4326`), a
#'   PROJ string, a WKT. The transformation to each scene's source CRS
#'   happens internally on a per-scene basis.
#' @param indices Character. A non-empty subset of
#'   `c("NDVI", "NBR", "NDMI", "NDRE")`. Default: `c("NDVI", "NBR")`.
#'   `"NDRE"` (red-edge, spec 022) requires the B05 / B8A bands in the
#'   cache; a cache holding none aborts (internal
#'   `.assert_cache_has_bands()` guard).
#'
#' @return A `data.frame` with columns `obs_date` (Date), `index`
#'   (character) and `value` (numeric, possibly NA), sorted by
#'   `(obs_date, index)`. `nrow` = `nrow(scenes_df) * length(indices)`.
#'
#' @examples
#' \dontrun{
#'   cache <- "/proj/cache/layers/sentinel2"
#'   scenes <- data.frame(
#'     scene_id = "S2A_MSIL2A_20250610T103031_R108_T31TGM",
#'     obs_date = as.Date("2025-06-10"))
#'   # A point clicked on the leaflet map at (lng, lat) = (5.0, 47.5)
#'   ts <- extract_pixel_timeseries(cache, scenes, c(5.0, 47.5))
#'   library(ggplot2)
#'   ggplot(ts, aes(obs_date, value, colour = index)) + geom_line()
#' }
#'
#' @seealso [build_index_stack()], [read_s2_band_stack()].
#' @export
extract_pixel_timeseries <- function(cache_dir, scenes_df, xy,
                                     crs = 4326,
                                     indices = c("NDVI", "NBR"),
                                     zone_polygon = NULL,
                                     warn_outside_zone = TRUE) {
  .validate_scenes_df(scenes_df)
  if (!is.numeric(xy) || length(xy) != 2L || anyNA(xy)) {
    stop("`xy` must be a length-2 numeric, no NA.", call. = FALSE)
  }
  indices <- match.arg(indices, c("NDVI", "NBR", "NDMI", "NDRE"),
                       several.ok = TRUE)

  # spec 022 — guard the red-edge index up front: a cache that never
  # ingested B05 / B8A would otherwise yield a silent all-NA NDRE series.
  if ("NDRE" %in% indices) .assert_cache_has_bands(cache_dir, c("B05", "B8A"))

  scenes_df <- scenes_df[order(as.Date(scenes_df$obs_date)), , drop = FALSE]

  # Build the point sf once, reproject per-scene to the raster's CRS.
  pt_in <- sf::st_sfc(sf::st_point(xy), crs = crs)

  # spec 016 (v0.49.0) — optional warn when the requested point sits
  # outside the UGF polygon. The series is still returned (the
  # underlying COG covers a wider area), but the user is informed
  # that the pixel is outside their managed perimeter. No raster
  # mask here — `extract_pixel_timeseries()` is a 1-point query, not
  # an area op.
  if (isTRUE(warn_outside_zone) && !is.null(zone_polygon)) {
    poly_in <- tryCatch(
      sf::st_transform(zone_polygon, crs),
      error = function(e) NULL)
    if (!is.null(poly_in)) {
      inside <- suppressMessages(
        lengths(sf::st_intersects(pt_in, poly_in)) > 0L)
      if (!isTRUE(inside)) {
        cli::cli_warn(c(
          "extract_pixel_timeseries: requested point is outside the
           UGF zone.",
          i = "Series is returned, but values may not be relevant to
               the user's managed forest."
        ))
      }
    }
  }

  # Bands the union of indices needs.
  bands_needed <- unique(unlist(lapply(indices, function(idx) {
    switch(idx,
      NDVI = c("B04", "B08"),
      NBR  = c("B08", "B12"),
      NDMI = c("B08", "B11"),
      NDRE = c("B8A", "B05"))
  })))

  na_row <- function(date_i) {
    data.frame(
      obs_date = rep(date_i, length(indices)),
      index    = indices,
      value    = NA_real_,
      stringsAsFactors = FALSE
    )
  }

  rows <- lapply(seq_len(nrow(scenes_df)), function(i) {
    sid     <- scenes_df$scene_id[i]
    date_i  <- as.Date(scenes_df$obs_date[i])

    rs <- stats::setNames(
      lapply(bands_needed, function(b) read_s2_band_raster(cache_dir, sid, b)),
      bands_needed
    )
    if (any(vapply(rs, is.null, logical(1)))) {
      return(na_row(date_i))
    }

    # Use the CRS of the first loaded band as the canonical native CRS.
    # All S2 bands of the same scene share the same CRS (different
    # resolutions but same tile projection), so any loaded band works —
    # and the guard just above guarantees they are all non-NULL here.
    # (Historically B08 was hard-coded, which crashed for NDRE-only
    # extracts where only B8A/B05 are loaded — spec 022 fix.)
    pt_native <- sf::st_transform(pt_in, terra::crs(rs[[1L]]))
    pt_vect   <- terra::vect(pt_native)

    vals <- vapply(indices, function(idx) {
      if (idx == "NDVI") {
        b04 <- terra::extract(rs$B04, pt_vect)[1L, 2L]
        b08 <- terra::extract(rs$B08, pt_vect)[1L, 2L]
        if (is.na(b04) || is.na(b08) || (b04 + b08) == 0) return(NA_real_)
        (b08 - b04) / (b08 + b04)
      } else if (idx == "NBR") {
        b08 <- terra::extract(rs$B08, pt_vect)[1L, 2L]
        # Native 20 m B12 — no resample for a single-point extraction.
        b12 <- terra::extract(rs$B12, pt_vect)[1L, 2L]
        if (is.na(b08) || is.na(b12) || (b08 + b12) == 0) return(NA_real_)
        (b08 - b12) / (b08 + b12)
      } else if (idx == "NDMI") {
        b08 <- terra::extract(rs$B08, pt_vect)[1L, 2L]
        # Native 20 m B11 — no resample for a single-point extraction,
        # mirroring the B12 treatment for NBR above.
        b11 <- terra::extract(rs$B11, pt_vect)[1L, 2L]
        if (is.na(b08) || is.na(b11) || (b08 + b11) == 0) return(NA_real_)
        (b08 - b11) / (b08 + b11)
      } else { # NDRE = (B8A - B05) / (B8A + B05), both native 20 m
        b8a <- terra::extract(rs$B8A, pt_vect)[1L, 2L]
        b05 <- terra::extract(rs$B05, pt_vect)[1L, 2L]
        if (is.na(b8a) || is.na(b05) || (b8a + b05) == 0) return(NA_real_)
        (b8a - b05) / (b8a + b05)
      }
    }, numeric(1L))

    data.frame(
      obs_date = rep(date_i, length(indices)),
      index    = indices,
      value    = as.numeric(vals),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out[order(out$obs_date, out$index), , drop = FALSE]
}

# Internal: validate the `scenes_df` argument shared by read_s2_band_stack(),
# build_index_stack(), and extract_pixel_timeseries(). Stops on first failure
# rather than collecting — these are programmer-side mistakes, fail fast.
.validate_scenes_df <- function(scenes_df) {
  if (!is.data.frame(scenes_df)) {
    stop("`scenes_df` must be a data.frame.", call. = FALSE)
  }
  missing_cols <- setdiff(c("scene_id", "obs_date"), names(scenes_df))
  if (length(missing_cols) > 0L) {
    stop(sprintf("`scenes_df` is missing column(s): %s.",
                 paste(missing_cols, collapse = ", ")),
         call. = FALSE)
  }
  if (!nrow(scenes_df)) {
    stop("`scenes_df` is empty (0 rows).", call. = FALSE)
  }
  if (anyNA(scenes_df$scene_id) || anyNA(scenes_df$obs_date)) {
    stop("`scenes_df` contains NA in `scene_id` or `obs_date`.",
         call. = FALSE)
  }
  invisible(scenes_df)
}

# spec 022 — assert the COG cache structurally carries every band in
# `bands` (i.e. at least one scene directory holds `<band>.tif`). Used by
# the NDRE path of build_index_stack() / extract_pixel_timeseries() to
# turn "you never ingested the red-edge bands" into an explicit error
# instead of a silent all-NA raster. A scene that simply has the band but
# masked to NA (cloud) is not the target here — that is a legitimate hole
# the per-scene logic keeps. Aborts when `cache_dir` is missing/empty or
# when any requested band is absent from every cached scene.
.assert_cache_has_bands <- function(cache_dir, bands) {
  if (is.null(cache_dir) || !nzchar(cache_dir) || !dir.exists(cache_dir)) {
    cli::cli_abort(c(
      "S2 cache directory not found: {.path {cache_dir %||% '<NULL>'}}.",
      i = "Run {.fn ingest_sentinel2_timeseries} to populate the cache."
    ))
  }
  scene_dirs <- list.dirs(cache_dir, recursive = FALSE)
  present <- vapply(bands, function(b) {
    length(scene_dirs) > 0L &&
      any(file.exists(file.path(scene_dirs, paste0(b, ".tif"))))
  }, logical(1))
  missing <- bands[!present]
  if (length(missing)) {
    # `{qty(missing)}` pins the pluralisation quantity to `missing`: the
    # message interpolates two vectors of differing length (`missing` and
    # the length-1 `cache_dir`), so a bare `{?s}` is ambiguous and recent
    # cli aborts with "Multiple quantities for pluralization".
    cli::cli_abort(c(
      "No cached scene carries the {cli::qty(missing)}band{?s} {.field {missing}} \\
       under {.path {cache_dir}}.",
      i = "These bands feed the requested index but were never ingested.",
      i = "Re-run {.fn ingest_sentinel2_timeseries} with the index that \\
           needs them (e.g. {.code bands = \"NDRE\"} for B05 / B8A)."
    ))
  }
  invisible(TRUE)
}
