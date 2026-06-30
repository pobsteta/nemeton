# indicators-microclimate.R — sous-couvert microclimate indicators (spec 027 L1)
# ------------------------------------------------------------------
# Aptitude microclimatique à la régénération forestière (ADR-014). Three
# sub-indicators inserted into existing families (no 13th family, radar
# kept at 12 axes):
#   * A3 indicateur_a3_microclimat  — summer T°max under canopy (frais = 100)
#   * A4 indicateur_a4_tamponnement — canopy buffering ΔT (tamponné = 100)
#   * W4 indicateur_w4_vpd          — summer VPD under canopy (humide = 100)
# (R6 indicateur_r6_sensibilite comes in L2.)
#
# Each `indicateur_*()` consumes a `micro` set of summer-aggregated rasters
# (produced by microclimate_run(), or supplied precomputed) and returns the
# input `units` enriched with a 0-100 score column (short code, detected by
# create_family_index via the `^[AWR][0-9]` regex), a raw-value column, a
# couverture_pct column, and the `augmented = "microclimate_model"` flag.
# Sens: "higher = more favourable to regeneration".


# Default normalisation bounds — temperate-forest summer microclimate.
# Documented, revisable on field validation (spec 027 §7/§12); NOT calibrated.
.MICRO_BOUNDS <- list(
  a3 = c(lo = 15,  hi = 40),    # T°max JJA understorey (°C): 40 -> 0, 15 -> 100
  a4 = c(lo = 0,   hi = 10),    # buffering ΔT (°C): 0 -> 0, 10 -> 100
  w4 = c(lo = 0.5, hi = 4.0),   # VPD (kPa): 4 -> 0, 0.5 -> 100
  r6 = c(scale_t = 8, scale_v = 2)  # R6: ΔT°max /8°C, ΔVPD /2 kPa standardisation
)

# Linear normalisation to 0-100, clamped. `decreasing = TRUE` maps low raw
# values to 100 (e.g. cooler / moister = better).
.micro_norm <- function(values, lo, hi, decreasing) {
  s <- (values - lo) / (hi - lo)
  s <- pmin(1, pmax(0, s))
  100 * (if (decreasing) (1 - s) else s)
}

# Resolve a named layer from `micro` — a named list of SpatRaster, a
# multi-layer SpatRaster, or NULL. Returns a single-layer SpatRaster or NULL.
.micro_layer <- function(micro, name) {
  if (is.null(micro)) return(NULL)
  if (is.list(micro) && !inherits(micro, "SpatRaster")) {
    r <- micro[[name]]
    return(if (inherits(r, "SpatRaster")) r else NULL)
  }
  if (inherits(micro, "SpatRaster") && name %in% names(micro)) {
    return(micro[[name]])
  }
  NULL
}

# Per-UGF coverage-weighted mean of a raster + non-NA coverage fraction.
.micro_extract <- function(units, r) {
  u <- sf::st_transform(units, terra::crs(r))
  if (requireNamespace("exactextractr", quietly = TRUE)) {
    m <- exactextractr::exact_extract(r, u, "mean", progress = FALSE)
    cov <- exactextractr::exact_extract(r, u, function(values, coverage_fraction) {
      tot <- sum(coverage_fraction)
      if (tot <= 0) return(NA_real_)
      sum(coverage_fraction[!is.na(values)]) / tot
    }, progress = FALSE)
    return(list(mean = as.numeric(m), cover = as.numeric(cov)))
  }
  ex <- terra::extract(r, terra::vect(u))
  names(ex)[2] <- "val"
  ids <- seq_len(nrow(u))
  m   <- tapply(ex$val, factor(ex$ID, levels = ids),
                function(x) mean(x, na.rm = TRUE))
  cov <- tapply(ex$val, factor(ex$ID, levels = ids),
                function(x) if (length(x)) mean(!is.na(x)) else NA_real_)
  list(mean = as.numeric(m), cover = as.numeric(cov))
}

# Augmentation flag for these indicators (ADR-011 amended, ADR-014).
.micro_augmented <- function(units, micro) {
  attr(units, "augmented") <- union(attr(units, "augmented"),
                                    "microclimate_model")
  units
}

# Shared body: extract a micro layer, write the score / raw / coverage
# columns under the family short code `code`, or NA columns when absent.
.micro_indicator <- function(units, r, code, raw_name, lo, hi, decreasing) {
  validate_sf(units)
  if (is.null(r)) {
    units[[code]] <- NA_real_
    units[[raw_name]] <- NA_real_
    units[[paste0(code, "_couverture_pct")]] <- 0
    return(units)
  }
  ex <- .micro_extract(units, r)
  units[[raw_name]] <- ex$mean
  units[[code]] <- .micro_norm(ex$mean, lo, hi, decreasing)
  units[[paste0(code, "_couverture_pct")]] <- 100 * ex$cover
  units
}


#' A3 — summer under-canopy maximum temperature (regeneration microclimate)
#'
#' @description
#' Mean per-UGF summer (JJA) **maximum temperature under the canopy**, the
#' core heat-stress driver for forest regeneration (spec 027, ADR-014).
#' Normalised 0-100 **decreasing** (cooler = more favourable = 100).
#'
#' @param units An `sf` of forest management units (UGF).
#' @param micro The summer microclimate rasters (named list / multi-layer
#'   `SpatRaster`) from [microclimate_run()]; the `tmax_understorey` layer
#'   (°C) is used. `NULL` → `A3 = NA`.
#' @param chm Optional canopy-height raster (reserved; structure source for
#'   the augmentation flag).
#' @param bounds Numeric `c(lo, hi)` normalisation bounds in °C
#'   (default `c(15, 40)`).
#' @param ... Unused (signature harmonisation).
#'
#' @return `units` with columns `A3` (0-100), `A3_tmax` (raw °C),
#'   `A3_couverture_pct`, and `attr(., "augmented")` carrying
#'   `"microclimate_model"`.
#' @seealso [indicateur_a4_tamponnement()], [indicateur_w4_vpd()],
#'   [microclimate_run()]
#' @export
indicateur_a3_microclimat <- function(units, micro = NULL, chm = NULL,
                                      bounds = .MICRO_BOUNDS$a3, ...) {
  r <- .micro_layer(micro, "tmax_understorey")
  units <- .micro_indicator(units, r, "A3", "A3_tmax",
                            bounds[["lo"]], bounds[["hi"]], decreasing = TRUE)
  .micro_augmented(units, micro)
}


#' A4 — canopy thermal buffering (regeneration microclimate)
#'
#' @description
#' Mean per-UGF **buffering** = summer T°max in the open minus under the
#' canopy. A larger buffer means the canopy shields the regeneration
#' microsite from heat (spec 027, ADR-014). Normalised 0-100 **increasing**
#' (more buffering = 100).
#'
#' @param units An `sf` of UGF.
#' @param micro Summer microclimate rasters; both `tmax_open` and
#'   `tmax_understorey` (°C) are used. `NULL`/missing layer → `A4 = NA`.
#' @param chm Optional canopy-height raster (reserved).
#' @param bounds Numeric `c(lo, hi)` buffering bounds in °C (default
#'   `c(0, 10)`).
#' @param ... Unused.
#'
#' @return `units` with `A4` (0-100), `A4_buffer` (raw °C),
#'   `A4_couverture_pct`, and the `"microclimate_model"` augmentation flag.
#' @seealso [indicateur_a3_microclimat()], [microclimate_run()]
#' @export
indicateur_a4_tamponnement <- function(units, micro = NULL, chm = NULL,
                                       bounds = .MICRO_BOUNDS$a4, ...) {
  ru <- .micro_layer(micro, "tmax_understorey")
  ro <- .micro_layer(micro, "tmax_open")
  d  <- if (!is.null(ru) && !is.null(ro)) ro - ru else NULL
  units <- .micro_indicator(units, d, "A4", "A4_buffer",
                            bounds[["lo"]], bounds[["hi"]], decreasing = FALSE)
  .micro_augmented(units, micro)
}


#' W4 — summer under-canopy vapour-pressure deficit (regeneration)
#'
#' @description
#' Mean per-UGF summer (JJA) **VPD under the canopy** (kPa), the
#' atmospheric-dryness driver of seedling water stress (spec 027, ADR-014).
#' Normalised 0-100 **decreasing** (moister air = more favourable = 100).
#'
#' @param units An `sf` of UGF.
#' @param micro Summer microclimate rasters; the `vpd` layer (kPa) is used.
#'   `NULL` → `W4 = NA`.
#' @param chm Optional canopy-height raster (reserved).
#' @param bounds Numeric `c(lo, hi)` VPD bounds in kPa (default
#'   `c(0.5, 4.0)`).
#' @param ... Unused.
#'
#' @return `units` with `W4` (0-100), `W4_vpd` (raw kPa),
#'   `W4_couverture_pct`, and the `"microclimate_model"` augmentation flag.
#' @seealso [indicateur_a3_microclimat()], [microclimate_run()]
#' @export
indicateur_w4_vpd <- function(units, micro = NULL, chm = NULL,
                              bounds = .MICRO_BOUNDS$w4, ...) {
  r <- .micro_layer(micro, "vpd")
  units <- .micro_indicator(units, r, "W4", "W4_vpd",
                            bounds[["lo"]], bounds[["hi"]], decreasing = TRUE)
  .micro_augmented(units, micro)
}


#' R6 — microsite climate sensitivity (heatwave vs average year)
#'
#' @description
#' Per-UGF **sensitivity** of the under-canopy microsite to a hot year
#' (spec 027 L2, ADR-014): the change in summer heat stress between a
#' **heatwave** year and an **average** year, with the canopy held fixed
#' (isolates the climatic effect). Combines the standardised ΔT°max and
#' ΔVPD; normalised 0-100 **decreasing** (less sensitive = more resilient =
#' 100).
#'
#' The two years are chosen by the caller — typically auto-detected from
#' the E-OBS summer series via [microclimate_detect_years()], or set
#' manually. This function consumes the **two precomputed `micro` sets**
#' (one per year), each carrying `tmax_understorey` and `vpd`.
#'
#' @param units An `sf` of UGF.
#' @param micro_moyenne Summer microclimate rasters for the **average**
#'   year (needs `tmax_understorey`, `vpd`).
#' @param micro_canicule Summer microclimate rasters for the **heatwave**
#'   year (same layers). `NULL`/missing layers → `R6 = NA`.
#' @param bounds Numeric `c(scale_t, scale_v)` standardisation scales
#'   (default `c(8, 2)` — ΔT in °C, ΔVPD in kPa).
#' @param ... Unused.
#'
#' @return `units` with `R6` (0-100, higher = less sensitive), `R6_dtmax`
#'   (raw ΔT°max, °C), `R6_dvpd` (raw ΔVPD, kPa), `R6_couverture_pct`, and
#'   the `"microclimate_model"` augmentation flag.
#' @seealso [microclimate_detect_years()], [indicateur_a3_microclimat()]
#' @export
indicateur_r6_sensibilite <- function(units, micro_moyenne = NULL,
                                      micro_canicule = NULL,
                                      bounds = .MICRO_BOUNDS$r6, ...) {
  validate_sf(units)
  tm <- .micro_layer(micro_moyenne, "tmax_understorey")
  tc <- .micro_layer(micro_canicule, "tmax_understorey")
  vm <- .micro_layer(micro_moyenne, "vpd")
  vc <- .micro_layer(micro_canicule, "vpd")
  if (is.null(tm) || is.null(tc) || is.null(vm) || is.null(vc)) {
    units$R6 <- NA_real_
    units$R6_dtmax <- NA_real_
    units$R6_dvpd <- NA_real_
    units$R6_couverture_pct <- 0
    return(.micro_augmented(units, micro_canicule))
  }
  exT <- .micro_extract(units, tc - tm)   # ΔT°max (canicule − moyenne)
  exV <- .micro_extract(units, vc - vm)   # ΔVPD
  units$R6_dtmax <- exT$mean
  units$R6_dvpd  <- exV$mean
  sT <- pmin(1, pmax(0, exT$mean / bounds[["scale_t"]]))
  sV <- pmin(1, pmax(0, exV$mean / bounds[["scale_v"]]))
  units$R6 <- 100 * (1 - (0.5 * sT + 0.5 * sV))
  units$R6_couverture_pct <- 100 * pmin(exT$cover, exV$cover, na.rm = FALSE)
  .micro_augmented(units, micro_canicule)
}


#' Run the under-canopy microclimate model (scaffold — spec 027 L1)
#'
#' @description
#' Orchestrator that will produce the summer-aggregated microclimate rasters
#' (`tmax_understorey`, `tmax_open`, `vpd`, `rh`) consumed by the A3/A4/W4
#' indicators, via the mechanistic model **microclimf** forced by ERA5-Land
#' and driven by LiDAR-HD canopy structure (PAI + height), with an
#' \pkg{opencanopy} CHM fallback (ADR-014).
#'
#' **Scaffold**: the heavy dependencies (`microclimf`, `mcera5`, `ecmwfr`,
#' `lidR`, `lasR`) are in `Suggests`; this entry point validates their
#' presence and defines the `micro` contract. The full microclimf
#' orchestration (per the spec §6 pipeline) is wired in a later L1 increment
#' once the forcing/structure data are available — in the meantime the
#' indicators accept a precomputed `micro` set.
#'
#' @param aoi An `sf`/`sfc` AOI (union of parcels + buffer).
#' @param year Integer year of the ERA5-Land forcing.
#' @param structure Canopy structure source: `"lidarhd"` or `"opencanopy"`.
#' @param resolution Working resolution in metres (default 5).
#' @param cache_dir Optional cache directory for the microclimate rasters.
#' @param quiet Suppress progress messages.
#'
#' @return A named list of `terra::SpatRaster` — `tmax_understorey`,
#'   `tmax_open`, `vpd`, `rh` (summer JJA) — the `micro` contract.
#' @seealso [indicateur_a3_microclimat()]
#' @export
microclimate_run <- function(aoi, year, structure = c("lidarhd", "opencanopy"),
                             resolution = 5, cache_dir = NULL, quiet = FALSE) {
  structure <- match.arg(structure)
  needed <- c("microclimf", "mcera5")
  miss <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(miss)) {
    cli::cli_abort(c(
      "microclimate_run() needs the {.pkg {miss}} package{?s} (in Suggests).",
      i = "Install them, or pass a precomputed {.arg micro} list to the indicators."
    ))
  }
  cli::cli_abort(c(
    "microclimate_run(): the microclimf orchestration is not yet wired (spec 027 L1).",
    i = "Supply a precomputed {.arg micro} (list of SpatRaster: tmax_understorey, tmax_open, vpd, rh) in the meantime."
  ))
}
