# Spectral diversity (spec 028) — indicators B4 (alpha) and L3 (beta),
# derived from optical imagery (Sentinel-2 at NDP 0) via biodivMapR.
#
# biodivMapR (GPL-3) implements the spectral variation hypothesis:
# PCA -> k-means spectral species -> per-window alpha diversity (Shannon)
# and between-window beta diversity (Bray-Curtis turnover). We run the
# one-call wrapper biodivMapR::biodivMapR_full(), then aggregate the alpha
# and beta rasters per spatial unit with exactextractr.

# Locate a diversity raster written by biodivMapR under `dir`, matching a
# case-insensitive keyword (e.g. "shannon", "beta") among GeoTIFFs. The
# exact output layout of biodivMapR_full varies with version, so we glob
# recursively rather than hard-code paths.
.find_diversity_raster <- function(dir, keyword) {
  tifs <- list.files(dir, pattern = "\\.(tif|tiff)$",
                     recursive = TRUE, full.names = TRUE,
                     ignore.case = TRUE)
  hit <- grep(keyword, basename(tifs), ignore.case = TRUE, value = TRUE)
  if (length(hit) == 0L) return(NA_character_)
  # Prefer the shortest matching name (the primary map, not a per-class
  # or intermediate product).
  full <- tifs[basename(tifs) %in% hit]
  full[order(nchar(basename(full)))][1]
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
#'     \item{beta}{a \code{SpatRaster} of Bray-Curtis beta diversity (or
#'       \code{NULL}),}
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


# Aggregate a diversity raster to per-unit mean values, reprojecting the
# units to the raster CRS when needed. Returns a numeric vector aligned
# with `units`, NA where a unit has no valid pixels.
.aggregate_diversity <- function(raster, units) {
  if (is.null(raster)) return(rep(NA_real_, nrow(units)))
  if (!requireNamespace("exactextractr", quietly = TRUE)) {
    stop("Package 'exactextractr' is required.", call. = FALSE)
  }
  u <- units
  rc <- terra::crs(raster)
  if (!is.na(rc) && !is.na(sf::st_crs(u)) &&
      sf::st_crs(u)$wkt != terra::crs(raster, describe = FALSE)) {
    u <- sf::st_transform(u, terra::crs(raster))
  }
  as.numeric(exactextractr::exact_extract(raster, u, "mean", progress = FALSE))
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
#' @inheritParams indicateur_b4_div_spectrale
#' @param column_name Output column name (default \code{"L3"}).
#'
#' @return \code{units} with the numeric \code{column_name} column added.
#' @seealso [compute_spectral_diversity()]
#' @export
indicateur_l3_het_spectrale <- function(units,
                                        spectral = NULL,
                                        reflectance = NULL,
                                        column_name = "L3",
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
    .aggregate_diversity(spectral$beta, units)
  }
  units[[column_name]] <- values
  cli::cli_alert_success(
    "Calculated {column_name}: spectral beta diversity (Bray-Curtis) via biodivMapR"
  )
  units
}
