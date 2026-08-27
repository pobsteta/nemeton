# Spectral diversity (spec 028) — indicators B4 (alpha) and L3 (beta),
# derived from optical imagery (Sentinel-2 at NDP 0) via biodivMapR.
#
# biodivMapR (GPL-3) implements the spectral variation hypothesis:
# PCA -> k-means spectral species -> per-window alpha diversity (Shannon)
# and between-window beta diversity (Bray-Curtis turnover). We run the
# one-call wrapper biodivMapR::biodivMapR_full(), then aggregate the alpha
# and beta rasters per spatial unit with exactextractr.

# --- Calibration of the B4 / L3 scales (spec 028 D3, §10) ---------------
#
# Both bounds are anchored on the reference run documented in spec 028 §10
# (Sentinel-2 tile T31UFQ, scene S2A_MSIL2A_20170814, 649 windows of 100 m,
# 30 UGF, nbclusters = 50). They are SINGLE-SCENE calibrations: honest about
# the amplitude the pipeline actually produces, but to be revisited as soon
# as a second massif is measured. Both are clamped, so a more diverse scene
# saturates at 100 rather than being rejected.

# B4 ceiling, expressed as an effective number of spectral species: the
# score reaches 100 when a window holds the Shannon equivalent of this many
# equally abundant spectral species. Reference run: best window 11.7,
# typical unit 2.2.
.B4_MAX_SPECTRAL_SPECIES <- 10

# L3 ceiling on the per-unit multivariate dispersion in Bray-Curtis PCoA
# space. Bray-Curtis is nominally bounded by 1, but a 3-axis PCoA recovers
# only part of the dissimilarity structure (GOF 0.56/0.62 on the reference
# run) and per-unit dispersions measured there span 0.064 to 0.440.
.L3_MAX_DISPERSION <- 0.5

# Names biodivMapR gives to the *dispersion* companion of a diversity map
# (e.g. "shannon_sd.tiff" next to "shannon_mean.tiff"). These are never the
# primary map, and they are SHORTER than the map they accompany -- which is
# exactly how the length-based tie-break below used to pick the wrong file.
.DIVERSITY_DISPERSION_RE <- "_(sd|std|stdev|var|variance|cv|se)\\.[^.]+$"

# Locate a diversity raster written by biodivMapR under `dir`, matching a
# case-insensitive keyword (e.g. "shannon", "beta") among GeoTIFFs. The
# exact output layout of biodivMapR_full varies with version, so we glob
# recursively rather than hard-code paths.
#
# Selection order, in decreasing priority:
#   1. drop dispersion companions (`*_sd`, `*_var`, ...) -- they are not the
#      map, and dropping them is what stops `shannon_sd.tiff` (15 chars)
#      from outranking `shannon_mean.tiff` (17) on name length;
#   2. prefer an explicit `*_mean` central-tendency map when one exists;
#   3. among what is left, the shortest name (the primary map rather than a
#      per-class or intermediate product).
.find_diversity_raster <- function(dir, keyword) {
  tifs <- list.files(dir, pattern = "\\.(tif|tiff)$",
                     recursive = TRUE, full.names = TRUE,
                     ignore.case = TRUE)
  hit <- grep(keyword, basename(tifs), ignore.case = TRUE, value = TRUE)
  if (length(hit) == 0L) return(NA_character_)
  full <- tifs[basename(tifs) %in% hit]

  primary <- full[!grepl(.DIVERSITY_DISPERSION_RE, basename(full),
                         ignore.case = TRUE)]
  # All candidates are dispersion maps: keep them rather than return NA --
  # a wrong-but-present map is still better diagnosed downstream than a
  # silent absence.
  if (length(primary) == 0L) primary <- full

  mean_maps <- grep("mean", basename(primary), ignore.case = TRUE, value = FALSE)
  if (length(mean_maps) > 0L) primary <- primary[mean_maps]

  primary[order(nchar(basename(primary)))][1]
}

#' Compute spectral diversity rasters (alpha & beta) via biodivMapR
#'
#' Runs the biodivMapR spectral-diversity pipeline on an optical
#' reflectance raster (typically a Sentinel-2 scene at NDP 0) and returns
#' the alpha (Shannon of spectral species) and beta (Bray-Curtis turnover)
#' diversity rasters. This is the shared primitive behind indicators
#' \strong{B4} (alpha) and \strong{L3} (beta); compute it once and pass the
#' result to both indicator functions to avoid running biodivMapR twice.
#'
#' @param reflectance A \code{terra} \code{SpatRaster} of surface
#'   reflectance (one layer per spectral band) \emph{or} a file path to
#'   such a raster. When a \code{SpatRaster} is given it is written to a
#'   temporary GeoTIFF, as biodivMapR operates on files.
#' @param mask Optional binary \code{SpatRaster} / file path masking the
#'   pixels to process (e.g. a forest / UGF mask). \code{NULL} (default)
#'   processes the full extent — crop \code{reflectance} to the AOI
#'   beforehand.
#' @param window_size Integer. Side (in pixels) of the square spatial unit
#'   over which diversity is computed (default \code{10L}, i.e. ~100 m at
#'   10 m Sentinel-2). See spec 028 D2.
#' @param nb_cpu Integer. Number of CPU workers passed to biodivMapR
#'   (default \code{1L}).
#' @param output_dir Directory for biodivMapR outputs (default a fresh
#'   temporary directory).
#' @param options Optional named list forwarded to
#'   \code{biodivMapR::biodivMapR_full(options = )} (e.g. \code{nbclusters},
#'   \code{alpha_metrics}). \code{NULL} (default) uses biodivMapR defaults
#'   — notably \code{nbclusters = 50} spectral species (spec 028 D2).
#' @param reuse_existing Logical. When \code{TRUE} (default) and
#'   \code{output_dir} already contains the diversity rasters from a prior
#'   run, reuse them instead of re-running the (expensive) biodivMapR
#'   pipeline. Pass a persistent \code{output_dir} (e.g. a project cache)
#'   to benefit; the default \code{tempfile()} directory never hits.
#'
#' @return A list with:
#'   \describe{
#'     \item{alpha}{a \code{SpatRaster} of Shannon alpha diversity (or
#'       \code{NULL} if not produced),}
#'     \item{beta}{a 3-layer \code{SpatRaster} holding the first three
#'       PCoA axes of the Bray-Curtis dissimilarity between windows — an
#'       ordination, not a scalar dissimilarity; see
#'       [indicateur_l3_het_spectrale()] for how a per-unit value is derived
#'       from it (or \code{NULL}),}
#'     \item{output_dir}{the directory holding the raw biodivMapR outputs.}
#'     \item{reused}{\code{TRUE} if the rasters were loaded from a cached
#'       \code{output_dir} rather than recomputed.}
#'   }
#'
#' @seealso [indicateur_b4_div_spectrale()], [indicateur_l3_het_spectrale()]
#' @export
compute_spectral_diversity <- function(reflectance,
                                       mask = NULL,
                                       window_size = 10L,
                                       nb_cpu = 1L,
                                       output_dir = tempfile("biodivmapr_"),
                                       options = NULL,
                                       reuse_existing = TRUE) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("Package 'terra' is required.", call. = FALSE)
  }

  # Cache-hit: when the caller passes a persistent `output_dir` (e.g. a
  # project cache) that already holds the diversity rasters from a prior
  # run, reuse them instead of re-running the expensive biodivMapR
  # PCA + k-means. The default tempfile() dir is always fresh, so this
  # never fires by accident. `biodivMapR` is not even needed on reuse.
  if (isTRUE(reuse_existing) && dir.exists(output_dir)) {
    a <- .find_diversity_raster(output_dir, "shannon")
    b <- .find_diversity_raster(output_dir, "beta")
    if (!is.na(a) && !is.na(b)) {
      return(list(alpha = terra::rast(a), beta = terra::rast(b),
                  output_dir = output_dir, reused = TRUE))
    }
  }

  if (!requireNamespace("biodivMapR", quietly = TRUE)) {
    stop("Package 'biodivMapR' is required for spectral diversity (B4/L3). ",
         "Install it with remotes::install_github('jbferet/biodivMapR').",
         call. = FALSE)
  }

  # Resolve the reflectance to a file path (biodivMapR works on files).
  reflectance_path <- if (inherits(reflectance, "SpatRaster")) {
    p <- tempfile("reflectance_", fileext = ".tif")
    terra::writeRaster(reflectance, p, overwrite = TRUE)
    p
  } else if (is.character(reflectance) && file.exists(reflectance)) {
    reflectance
  } else {
    stop("reflectance must be a SpatRaster or an existing raster file path",
         call. = FALSE)
  }

  mask_path <- if (is.null(mask)) {
    NULL
  } else if (inherits(mask, "SpatRaster")) {
    p <- tempfile("mask_", fileext = ".tif")
    terra::writeRaster(mask, p, overwrite = TRUE)
    p
  } else if (is.character(mask) && file.exists(mask)) {
    mask
  } else {
    stop("mask must be NULL, a SpatRaster, or an existing raster file path",
         call. = FALSE)
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  biodivMapR::biodivMapR_full(
    input_raster_path = reflectance_path,
    input_mask_path   = mask_path,
    output_dir        = output_dir,
    window_size       = as.integer(window_size),
    nbCPU             = as.integer(nb_cpu),
    options           = options
  )

  alpha_path <- .find_diversity_raster(output_dir, "shannon")
  beta_path  <- .find_diversity_raster(output_dir, "beta")

  list(
    alpha      = if (!is.na(alpha_path)) terra::rast(alpha_path) else NULL,
    beta       = if (!is.na(beta_path))  terra::rast(beta_path)  else NULL,
    output_dir = output_dir,
    reused     = FALSE
  )
}


# Reproject `units` onto the raster CRS when the two differ, so that
# exactextractr sees a consistent pair. Shared by both aggregators.
.units_in_raster_crs <- function(raster, units) {
  rc <- terra::crs(raster)
  if (!is.na(rc) && !is.na(sf::st_crs(units)) &&
      sf::st_crs(units)$wkt != terra::crs(raster, describe = FALSE)) {
    return(sf::st_transform(units, terra::crs(raster)))
  }
  units
}

# Aggregate a diversity raster to per-unit mean values, reprojecting the
# units to the raster CRS when needed. Returns a numeric vector aligned
# with `units`, NA where a unit has no valid pixels.
.aggregate_diversity <- function(raster, units) {
  if (is.null(raster)) return(rep(NA_real_, nrow(units)))
  if (!requireNamespace("exactextractr", quietly = TRUE)) {
    stop("Package 'exactextractr' is required.", call. = FALSE)
  }
  u <- .units_in_raster_crs(raster, units)
  ex <- exactextractr::exact_extract(raster, u, "mean", progress = FALSE)
  # A multi-layer raster (e.g. biodivMapR's beta diversity = 3 PCoA/Bray-Curtis
  # axes) makes exact_extract return a data.frame (one mean column per band).
  # `as.numeric()` on a data.frame errors ("list cannot be coerced to double").
  # Collapse to one scalar per unit — the mean across bands (the unit's mean
  # position in the ordination space) — while leaving single-layer extraction
  # (e.g. alpha diversity for B4) numerically unchanged.
  if (is.data.frame(ex)) {
    res <- rowMeans(as.matrix(ex), na.rm = TRUE)
    res[is.nan(res)] <- NA_real_   # all-NA unit (no raster coverage)
    return(res)
  }
  as.numeric(ex)
}


# Aggregate biodivMapR's beta-diversity ordination to one heterogeneity
# value per unit.
#
# biodivMapR does NOT return a scalar dissimilarity raster: `beta.tiff` holds
# the first three axes of a PCoA of the Bray-Curtis dissimilarity between
# windows. Its cell values are ORDINATION COORDINATES, centred on zero and
# roughly symmetric about it — measured on the reference run (spec 028 §10):
# axis ranges [-0.35, 0.54], [-0.55, 0.42], [-0.46, 0.42], all three with a
# mean within 0.006 of zero.
#
# Averaging those coordinates (what this used to do) therefore yields a
# unit's mean POSITION in ordination space, which is near zero by
# construction and carries no diversity meaning — and, once clamped to
# [0, 100], sent every unit sitting on the negative side to exactly 0.
#
# The turnover of a unit is a DISPERSION, not a position: we use the mean
# Euclidean distance of the unit's windows to the unit's own centroid in
# PCoA space — multivariate dispersion in the sense of Anderson's
# betadisper, and the standard way of reading a unit's beta diversity off an
# ordination. It is >= 0, zero for a spectrally uniform unit, and grows with
# the compositional contrast the unit spans.
#
# `min_windows` guards the small-unit case: dispersion around a centroid is
# degenerate below three points, and returning NA there is preferred over a
# fabricated near-zero (the "no invented value" rule of v0.187.0).
.aggregate_beta_dispersion <- function(raster, units, min_windows = 3L) {
  if (is.null(raster)) return(rep(NA_real_, nrow(units)))
  if (!requireNamespace("exactextractr", quietly = TRUE)) {
    stop("Package 'exactextractr' is required.", call. = FALSE)
  }
  min_windows <- max(3L, as.integer(min_windows))
  u <- .units_in_raster_crs(raster, units)

  # exact_extract() with a summary FUNCTION rejects duplicated layer names.
  # biodivMapR names its axes "PCoA#1".."PCoA#3", but a caller assembling the
  # ordination by hand easily ends up with three identical names; the axes are
  # positional here, so renaming them costs nothing.
  names(raster) <- paste0("pcoa_", seq_len(terra::nlyr(raster)))

  # A window counts when the unit covers most of it (majority rule) and all
  # its axes are finite -- is.finite() already screens NA, NaN and Inf.
  dispersion <- function(values, coverage_fraction) {
    m <- as.matrix(as.data.frame(values))
    keep <- coverage_fraction > 0.5 & apply(is.finite(m), 1L, all)
    if (sum(keep) < min_windows) return(NA_real_)
    m <- m[keep, , drop = FALSE]
    centroid <- colMeans(m)
    mean(sqrt(rowSums(sweep(m, 2L, centroid)^2)))
  }

  res <- exactextractr::exact_extract(raster, u, dispersion, progress = FALSE)
  as.numeric(res)
}


#' Indicator B4 — Spectral alpha diversity (family B)
#'
#' Per-unit Shannon alpha diversity of spectral species (biodivMapR),
#' a remote-sensing proxy for compositional biodiversity available from
#' NDP 0 (Sentinel-2). Strictly backward compatible: with neither
#' \code{spectral} nor \code{reflectance}, the column is filled with
#' \code{NA} and the \code{sf} is returned unchanged.
#'
#' @param units sf polygon layer (spatial units / UGF).
#' @param spectral Optional precomputed result of
#'   [compute_spectral_diversity()] (preferred — compute once, share with
#'   L3). When \code{NULL}, falls back to \code{reflectance}.
#' @param reflectance Optional reflectance \code{SpatRaster} / path used to
#'   compute spectral diversity on the fly when \code{spectral} is
#'   \code{NULL}.
#' @param column_name Output column name (default \code{"B4"}).
#' @param ... Passed to [compute_spectral_diversity()] when computing on
#'   the fly (e.g. \code{window_size}, \code{mask}, \code{nb_cpu}).
#'
#' @return \code{units} with the numeric \code{column_name} column added.
#' @seealso [compute_spectral_diversity()]
#' @export
indicateur_b4_div_spectrale <- function(units,
                                        spectral = NULL,
                                        reflectance = NULL,
                                        column_name = "B4",
                                        ...) {
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }
  if (is.null(spectral) && !is.null(reflectance)) {
    spectral <- compute_spectral_diversity(reflectance, ...)
  }
  values <- if (is.null(spectral)) {
    rep(NA_real_, nrow(units))
  } else {
    .aggregate_diversity(spectral$alpha, units)
  }
  units[[column_name]] <- values
  cli::cli_alert_success(
    "Calculated {column_name}: spectral alpha diversity (Shannon) via biodivMapR"
  )
  units
}


#' Indicator L3 — Spectral beta diversity / landscape heterogeneity (family L)
#'
#' Per-unit Bray-Curtis beta diversity (spectral-species turnover,
#' biodivMapR): the compositional heterogeneity of the landscape mosaic,
#' complementary to L2 (geometric fragmentation). Higher = more diverse
#' mosaic (spec 028 D1). Backward compatible like [indicateur_b4_div_spectrale()].
#'
#' @details
#' biodivMapR returns beta diversity as the first three axes of a PCoA of
#' the Bray-Curtis dissimilarity between windows, \emph{not} as a scalar
#' dissimilarity raster. The value reported here is therefore the unit's
#' \strong{multivariate dispersion} in that ordination space: the mean
#' Euclidean distance of the unit's windows to the unit's own centroid
#' (Anderson's betadisper). A spectrally uniform unit scores near zero; a
#' unit spanning contrasted spectral communities scores high.
#'
#' Before v0.190.0 the axes were simply averaged, which measured a unit's
#' mean \emph{position} in ordination space — a quantity centred on zero by
#' construction, and clamped to 0 for every unit on the negative side. See
#' spec 028 §10.
#'
#' @inheritParams indicateur_b4_div_spectrale
#' @param column_name Output column name (default \code{"L3"}).
#' @param min_windows Integer. Minimum number of covered diversity windows
#'   below which the unit's dispersion is undefined and \code{NA} is
#'   returned (default \code{3L}, the floor for a dispersion around a
#'   centroid). Values below 3 are raised to 3.
#'
#' @return \code{units} with the numeric \code{column_name} column added.
#' @seealso [compute_spectral_diversity()]
#' @export
indicateur_l3_het_spectrale <- function(units,
                                        spectral = NULL,
                                        reflectance = NULL,
                                        column_name = "L3",
                                        min_windows = 3L,
                                        ...) {
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }
  if (is.null(spectral) && !is.null(reflectance)) {
    spectral <- compute_spectral_diversity(reflectance, ...)
  }
  values <- if (is.null(spectral)) {
    rep(NA_real_, nrow(units))
  } else {
    .aggregate_beta_dispersion(spectral$beta, units, min_windows = min_windows)
  }
  units[[column_name]] <- values
  cli::cli_alert_success(
    "Calculated {column_name}: spectral beta diversity \\
     (Bray-Curtis PCoA dispersion) via biodivMapR"
  )
  units
}
