#' RECONFORT feature persistence: CRswir / CRre stacks (L5, spec 021)
#'
#' @description
#' Write side of the RECONFORT pixel diagnostic (parity with the FORDEAD
#' diagnostic bundle, spec 008 §14). The `persist` phase of
#' [run_reconfort_dieback()] recomputes the two vegetation indices used
#' by the RF model — **CRswir** (canopy water) and **CRre** (chlorophyll)
#' — per Sentinel-2 acquisition date from the ingested bands, and stores
#' them as dated multi-band rasters so [read_reconfort_pixel_series()]
#' can plot the observed series at a clicked pixel.
#'
#' Option B (spec 021 L5 decision): the indices are **recomputed from the
#' ingested S2** with the production formulas (§4.1), not extracted from
#' IOTA² intermediates. This is self-contained and deterministic; it
#' yields the *observed* (not interpolated) series, which is the honest
#' signal for a per-pixel diagnostic plot.
#'
#' @name reconfort_outputs
NULL


# Sentinel-2 central wavelengths (nm) used by the continuum-removal
# indices (spec 021 §4.1): B04=665, B05=704, B06=741, B8A=865,
# B11=1610, B12=2190.

#' Continuum-removal SWIR index (canopy water)
#'
#' `CRswir = B11 / [ B8A + (1610-865) * (B12-B8A) / (2190-865) ]`
#' (spec 021 §4.1, production formula, no additive offset). Works on
#' numeric vectors or `terra::SpatRaster`s (terra arithmetic).
#'
#' @param b8a,b11,b12 NIR-narrow / SWIR1 / SWIR2 reflectances.
#' @return CRswir (same type as the inputs).
#' @keywords internal
.reconfort_crswir <- function(b8a, b11, b12) {
  b11 / (b8a + (1610 - 865) * (b12 - b8a) / (2190 - 865))
}

#' Continuum-removal red-edge index (chlorophyll)
#'
#' `CRre = B5 / [ B4 + (704-665) * (B6-B4) / (741-665) ]`
#' (spec 021 §4.1).
#'
#' @param b4,b5,b6 Red / red-edge-1 / red-edge-2 reflectances.
#' @return CRre (same type as the inputs).
#' @keywords internal
.reconfort_crre <- function(b4, b5, b6) {
  b5 / (b4 + (704 - 665) * (b6 - b4) / (741 - 665))
}


# THEIA/MUSCATE SCL-like cloud & shadow classes to mask out, when an SCL
# band is supplied (Sen2Cor classes: 3 shadow, 8/9 cloud med/high,
# 10 cirrus, 11 snow). Best-effort: if no SCL is available the raw index
# is kept.
.RECONFORT_SCL_MASK_CLASSES <- c(3L, 8L, 9L, 10L, 11L)


#' Build the CRswir / CRre dated stacks from per-date S2 scenes
#'
#' Pure function of the inputs (testable without IOTA² / a real run).
#' Each scene is a named list with the six reconfort bands as
#' `terra::SpatRaster`s (or readable paths) plus an optional `scl` band
#' and an `obs_date`. Returns the two multi-band stacks, one band per
#' date, with `terra::time()` and `YYYY-MM-DD` layer names set.
#'
#' @param scenes A list; each element is
#'   `list(obs_date = <Date>, B04=, B05=, B06=, B8A=, B11=, B12=,
#'   scl = NULL)`. Bands are `SpatRaster`s or single file paths.
#' @return `list(crswir = <SpatRaster>, crre = <SpatRaster>,
#'   dates = <Date>)`, or `NULL` when `scenes` is empty.
#' @keywords internal
.build_reconfort_feature_stacks <- function(scenes) {
  if (!length(scenes)) return(NULL)
  load_one <- function(x) {
    if (is.null(x)) return(NULL)
    if (inherits(x, "SpatRaster")) x else terra::rast(x)
  }
  dates <- as.Date(vapply(scenes, function(s) as.character(s$obs_date),
                          character(1)))
  ord   <- order(dates)
  scenes <- scenes[ord]; dates <- dates[ord]

  # Every date is streamed to disk and only its path is kept: holding the N
  # in-memory layers of both indices was the run's largest R-side allocation
  # (~6 GB for a 2000x2000 AOI over 100 dates, on top of the IOTA2 subprocess).
  # `tmpdir` is returned so the caller can drop the intermediates once the
  # bundle is written — see `run_reconfort_dieback()`.
  tmpdir <- scratch_dir(paste0("reconfort_feat_", as.integer(Sys.getpid())))
  # The stacks scale with pixels x dates (~800 MB for 0.89 Mpx over 115 dates,
  # tens of GB department-wide). Warn early rather than let the run die on a
  # full disk half-way through — advisory only, the estimate is rough and the
  # scratch dir may live on a filesystem `df` cannot read.
  need_gb <- tryCatch(
    terra::ncell(load_one(scenes[[1L]]$B04)) * length(scenes) * 2 * 8 / 1024^3,
    error = function(e) NA_real_)
  free_gb <- .free_space_gb(tmpdir)
  if (!is.na(need_gb) && !is.na(free_gb) && free_gb < need_gb) {
    cli::cli_warn(c(
      "RECONFORT feature stacks need roughly {round(need_gb, 1)} GB of scratch space; {.path {tmpdir}} has {round(free_gb, 1)} GB free.",
      i = "Point the scratch dir elsewhere with {.code options(nemeton.scratch_dir=)} or {.envvar NEMETON_SCRATCH_DIR}."
    ))
  }
  crswir_files <- character(length(scenes))
  crre_files   <- character(length(scenes))
  for (i in seq_along(scenes)) {
    s   <- scenes[[i]]
    b4  <- load_one(s$B04)
    # The FRE bands mix 10 m (B04) and 20 m (B05/B06/B8A/B11/B12); terra
    # cannot combine rasters of different dimensions ("number of rows and/or
    # columns"). Align every band to B04's 10 m grid before the indices.
    ali <- function(x, method = "bilinear") {
      if (is.null(x)) return(NULL)
      if (terra::nrow(x) == terra::nrow(b4) &&
          terra::ncol(x) == terra::ncol(b4)) return(x)
      terra::resample(x, b4, method = method)
    }
    b5  <- ali(load_one(s$B05)); b6  <- ali(load_one(s$B06))
    b8a <- ali(load_one(s$B8A)); b11 <- ali(load_one(s$B11))
    b12 <- ali(load_one(s$B12))
    cw <- .reconfort_crswir(b8a, b11, b12)
    cr <- .reconfort_crre(b4, b5, b6)
    scl <- ali(load_one(s$scl), method = "near")
    if (!is.null(scl)) {
      # terra::mask() streams; the previous values()/ifelse() route pulled scl,
      # cw and cr fully into RAM (plus ifelse's temporaries) on every scene.
      cw <- terra::mask(cw, scl, maskvalues = .RECONFORT_SCL_MASK_CLASSES,
                        updatevalue = NA)
      cr <- terra::mask(cr, scl, maskvalues = .RECONFORT_SCL_MASK_CLASSES,
                        updatevalue = NA)
    }
    crswir_files[i] <- file.path(tmpdir, sprintf("crswir_%04d.tif", i))
    crre_files[i]   <- file.path(tmpdir, sprintf("crre_%04d.tif", i))
    terra::writeRaster(cw, crswir_files[i], overwrite = TRUE)
    terra::writeRaster(cr, crre_files[i], overwrite = TRUE)
    rm(b4, b5, b6, b8a, b11, b12, cw, cr, scl)
  }
  # File-backed stacks: terra reads them by window, nothing is held in RAM.
  crswir <- terra::rast(crswir_files)
  crre   <- terra::rast(crre_files)
  names(crswir) <- names(crre) <- format(dates, "%Y-%m-%d")
  terra::time(crswir) <- dates
  terra::time(crre)   <- dates
  list(crswir = crswir, crre = crre, dates = dates, tmpdir = tmpdir)
}


#' Write a RECONFORT feature bundle to disk
#'
#' Persists `crswir_stack.tif`, `crre_stack.tif` and `run_meta.json`
#' under `bundle_dir`, mirroring [.write_fordead_model_bundle()].
#' Best-effort: returns the bundle dir invisibly.
#'
#' @param bundle_dir Target directory (created if absent).
#' @param stacks The list returned by [.build_reconfort_feature_stacks()].
#' @param run_meta Named list of provenance metadata.
#' @return `bundle_dir` (invisibly), or `NULL` when `stacks` is `NULL`.
#' @keywords internal
.write_reconfort_features_bundle <- function(bundle_dir, stacks,
                                             run_meta = list()) {
  if (is.null(stacks)) return(NULL)
  if (!dir.exists(bundle_dir)) {
    dir.create(bundle_dir, recursive = TRUE, showWarnings = FALSE)
  }
  terra::writeRaster(stacks$crswir, file.path(bundle_dir, "crswir_stack.tif"),
                     overwrite = TRUE)
  terra::writeRaster(stacks$crre, file.path(bundle_dir, "crre_stack.tif"),
                     overwrite = TRUE)
  meta <- utils::modifyList(
    list(tool = "reconfort_features",
         n_dates = length(stacks$dates),
         date_min = as.character(min(stacks$dates)),
         date_max = as.character(max(stacks$dates))),
    run_meta)
  jsonlite::write_json(meta, file.path(bundle_dir, "run_meta.json"),
                       auto_unbox = TRUE, pretty = TRUE)
  invisible(bundle_dir)
}


#' Enumerate ingested Sentinel-2 scenes for RECONFORT (best-effort)
#'
#' Walks the ingested S2 root (THEIA/MUSCATE L2A layout produced by
#' [reconfort_ingest_s2()]) and groups the per-date FRE band files into
#' the scene list consumed by [.build_reconfort_feature_stacks()].
#'
#' **Layout assumption — validate on a real run.** Band files are
#' matched by the `*_FRE_B<band>.tif` THEIA convention and the
#' acquisition date by the leading `..._YYYYMMDD-...` token. If the real
#' MUSCATE naming differs, this returns an empty list and the `persist`
#' phase skips (best-effort) — the run is never harmed.
#'
#' @param s2_root Directory holding the ingested S2 (recursive search).
#' @return A list of scenes (possibly empty).
#' @keywords internal
.enumerate_reconfort_s2_scenes <- function(s2_root) {
  if (is.null(s2_root) || !nzchar(s2_root) || !dir.exists(s2_root)) {
    return(list())
  }
  bands <- c("B04", "B05", "B06", "B8A", "B11", "B12")
  # THEIA/MUSCATE FRE bands; names use single-digit B4/B5/B6 (not zero
  # padded) and B8A/B11/B12 — match leniently and canonicalise.
  files <- list.files(s2_root, pattern = "FRE_B[0-9]+A?\\.tif$",
                      recursive = TRUE, full.names = TRUE,
                      ignore.case = TRUE)
  if (!length(files)) return(list())
  date_chr <- function(f) {
    m <- regmatches(basename(f), regexpr("[0-9]{8}", basename(f)))
    if (length(m)) m else NA_character_
  }
  band_of <- function(f) {
    m <- regmatches(basename(f), regexpr("FRE_B[0-9]+A?", basename(f),
                                         ignore.case = TRUE))
    if (!length(m)) return(NA_character_)
    tok <- toupper(sub("FRE_B", "", m))            # "4", "8A", "11", ...
    if (grepl("^[0-9]$", tok)) tok <- paste0("0", tok)   # B4 -> B04
    paste0("B", tok)
  }
  df <- data.frame(path = files,
                   date = vapply(files, date_chr, character(1)),
                   band = vapply(files, band_of, character(1)),
                   stringsAsFactors = FALSE)
  df <- df[!is.na(df$date) & df$band %in% bands, , drop = FALSE]
  scenes <- list()
  for (dch in sort(unique(df$date))) {
    sub <- df[df$date == dch, , drop = FALSE]
    if (!all(bands %in% sub$band)) next            # require all six bands
    bset <- stats::setNames(
      lapply(bands, function(b) sub$path[match(b, sub$band)]), bands)
    scl <- list.files(s2_root, pattern = sprintf("%s.*_SCL.*\\.tif$", dch),
                      recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
    bset$scl <- if (length(scl)) scl[1L] else NULL
    bset$obs_date <- as.Date(dch, format = "%Y%m%d")
    scenes[[length(scenes) + 1L]] <- bset
  }
  scenes
}
