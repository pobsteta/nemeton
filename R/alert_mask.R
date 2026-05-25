#' Extract an alert mask from a categorical 0-4 raster (spec 014 A1)
#'
#' Selects the cells of a categorical 0-4 SpatRaster (the FORDEAD
#' `dieback_mask` produced by [run_fordead_dieback()], or the FAST
#' alert mask produced by [compute_fast_alert_mask()]) that fall in
#' the requested `classes`, optionally dilating the mask by `buffer_m`
#' metres.
#'
#' The output preserves the **class value** on selected cells (so the
#' raster doubles as a *priority raster* for an unequal-probability
#' GRTS draw), and is `NA` elsewhere. Cells added by the buffer (not
#' alert at origin) take `min(classes)` so they are samplable but with
#' the lowest priority.
#'
#' @param alert_raster A `terra::SpatRaster` (single layer) with integer
#'   class values in `[0, 4]`. Typically produced by
#'   [run_fordead_dieback()] (categorical dieback mask) or by
#'   [compute_fast_alert_mask()] (FAST 0-4 mask).
#' @param classes Integer vector. Class values to retain as alert
#'   cells. Default `c(3L, 4L)` (the strong-alert + bare-ground
#'   classes, cf. spec 008 garde-fou G1).
#' @param buffer_m Numeric scalar in metres. Optional dilation around
#'   alert cells (`0` = no buffer, default). Useful to ensure that
#'   validation plots fall *around* a detection rather than exactly on
#'   it.
#'
#' @return A `terra::SpatRaster` with the same geometry as
#'   `alert_raster`. Alert cells keep their class value, buffer cells
#'   get `min(classes)`, all other cells are `NA`. Layer name
#'   `alert_priority`.
#'
#' @examples
#' \dontrun{
#'   mask <- read_fordead_dieback_mask(con, zone_id = 1L,
#'             cache_dir = "/proj/cache/layers/fordead")
#'   alert <- fordead_alert_mask(mask, classes = c(3L, 4L), buffer_m = 20)
#'   terra::plot(alert)
#' }
#'
#' @seealso [create_validation_sampling_plan()] which consumes the
#'   output of this function.
#'
#' @export
fordead_alert_mask <- function(alert_raster,
                               classes  = c(3L, 4L),
                               buffer_m = 0) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }
  if (!inherits(alert_raster, "SpatRaster")) {
    cli::cli_abort("{.arg alert_raster} must be a {.cls SpatRaster}.")
  }
  if (terra::nlyr(alert_raster) != 1L) {
    cli::cli_abort("{.arg alert_raster} must have exactly one layer (got {terra::nlyr(alert_raster)}).")
  }
  if (!is.numeric(classes) || length(classes) < 1L ||
      any(is.na(classes))) {
    cli::cli_abort("{.arg classes} must be a non-empty integer vector with no NA.")
  }
  classes <- as.integer(classes)
  if (!is.numeric(buffer_m) || length(buffer_m) != 1L ||
      is.na(buffer_m) || buffer_m < 0) {
    cli::cli_abort("{.arg buffer_m} must be a single non-negative numeric.")
  }

  # Step 1: mask everything outside `classes`, preserving the class value.
  in_classes <- terra::values(alert_raster) %in% classes
  out <- alert_raster
  vals <- terra::values(out)
  vals[!in_classes] <- NA
  terra::values(out) <- vals

  # Step 2: optional buffer (dilation in metres). Skipped when 0 or
  # when there are no alert cells (nothing to dilate).
  if (buffer_m > 0 && any(in_classes, na.rm = TRUE)) {
    # `terra::buffer()` on a SpatRaster dilates non-NA cells by the
    # requested distance (in CRS units — assumes a projected CRS, m).
    # Cells added by the buffer carry `1` (binary). We re-merge with
    # the original priority values: where the original had a class
    # value, keep it; where only the buffer added, assign min(classes).
    dilated <- terra::buffer(out, width = buffer_m,
                             background = NA)
    # `dilated` is a binary 0/1 raster (1 = inside buffer including
    # the original alert cells). We restore the priority semantics:
    out_vals     <- terra::values(out)
    dilated_vals <- terra::values(dilated)
    added <- !is.na(dilated_vals) & dilated_vals == 1 & is.na(out_vals)
    out_vals[added] <- as.integer(min(classes))
    terra::values(out) <- out_vals
  }

  names(out) <- "alert_priority"
  out
}
