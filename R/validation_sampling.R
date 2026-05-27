#' Create a validation sampling plan over an alert raster (spec 014 A3)
#'
#' Generates a sampling plan made of two parts:
#'
#' 1. **Validation plots** — drawn over the alert cells of the
#'    `alert_raster` (selected by [fordead_alert_mask()] with the given
#'    `classes` and optional `buffer_m`) using an
#'    **unequal-probability GRTS** that weights inclusion by the alert
#'    intensity (class value): a cell of class 4 has a higher inclusion
#'    probability than a class 3 cell.
#' 2. **Control plots** — drawn over the *healthy* cells (class 0 of
#'    `alert_raster`) using equiprobable GRTS, to serve as the reference
#'    against which a validating field crew can compare the alert plots.
#'
#' The output is a single `sf` POINT object combining both samples,
#' tagged by a `type` column (`"Validation"` / `"Temoin"`), with a
#' `visit_order` column for a single TSP tour over the union (so the
#' field crew minimises driving).
#'
#' Application-level provenance (`zone_id`, `fordead_run_id` /
#' `mask_timestamp`, `generated_at`) is **not** added here — it lives
#' upstream in the app layer.
#'
#' @param zone An `sf` POLYGON in EPSG:2154. Defines the geographic AOI
#'   of the monitoring zone (used to intersect candidate cells; not
#'   used for the alert/control selection itself, which comes from
#'   `alert_raster`).
#' @param alert_raster A `terra::SpatRaster` (single layer) with
#'   integer class values in `[0, 4]`. Typically
#'   [read_fordead_dieback_mask()] or [read_fast_alert_mask()].
#' @param n_validation Integer scalar. Target number of plots in the
#'   alert zone. Default `20L`. **Target only** (GRTS does not always
#'   return the exact count when the candidate frame is small).
#' @param n_control Integer scalar. Target number of plots in the
#'   healthy zone (`alert_raster == 0`). Default `5L`.
#' @param classes Integer vector. Alert classes retained for the
#'   validation draw. Default `c(3L, 4L)`.
#' @param buffer_m Numeric in metres. Optional dilation around alert
#'   cells before drawing (cf. [fordead_alert_mask()]). Default `0`.
#' @param source Character. Tag stored on every row (`"FORDEAD"` or
#'   `"FAST"`) so the field crew knows which pipeline raised the
#'   alert. Default `"FORDEAD"`.
#' @param seed Integer or `NULL`. When non-`NULL`, makes the GRTS draw
#'   reproducible.
#'
#' @return An `sf` POINT object in EPSG:2154 with the following
#'   columns:
#'   \describe{
#'     \item{`plot_id`}{Character. Identifier `V01`, `V02`, ... for
#'       validation plots, `T01`, `T02`, ... for controls.}
#'     \item{`type`}{Character. `"Validation"` or `"Temoin"`.}
#'     \item{`alert_class`}{Integer. Class value of the cell under the
#'       plot (0 for controls; in `classes` for validation; `min(classes)`
#'       for plots that fall on a buffer-added cell).}
#'     \item{`visit_order`}{Integer. TSP-optimised order over the union
#'       of the two samples.}
#'     \item{`source`}{Character. Echo of `source`.}
#'     \item{`classes`}{Character. Comma-separated echo of `classes`.}
#'     \item{`seed`}{Integer or `NA`. Echo of `seed`.}
#'   }
#'
#' @section Edge case — empty alert mask:
#' When no cell of `alert_raster` falls in `classes` (e.g. the zone is
#' currently healthy), the function raises a typed error of class
#' `nemeton_empty_alert_mask` so the app can render a clean message
#' (\dQuote{Zone saine, rien à valider}) rather than producing a
#' degenerate plan.
#'
#' @examples
#' \dontrun{
#'   mask <- read_fordead_dieback_mask(con, 1L, cache_dir = cd_fordead)
#'   zone <- # an sf POLYGON in EPSG:2154
#'   plan <- create_validation_sampling_plan(
#'     zone, alert_raster = mask,
#'     n_validation = 30L, n_control = 8L,
#'     source = "FORDEAD", seed = 42L)
#'   table(plan$type)
#' }
#'
#' @seealso [fordead_alert_mask()] (the cell selector),
#'   [read_fordead_dieback_mask()] / [read_fast_alert_mask()] (the
#'   raster sources), [create_sampling_plan()] (the systemic sampling
#'   plan for unbiased inventory).
#'
#' @export
create_validation_sampling_plan <- function(zone,
                                            alert_raster,
                                            n_validation    = 20L,
                                            n_control       = 5L,
                                            classes         = c(3L, 4L),
                                            control_classes = c(0L),
                                            buffer_m        = 0,
                                            source          = c("FORDEAD", "FAST"),
                                            seed            = NULL) {
  source <- match.arg(source)
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }
  if (!inherits(zone, "sf") && !inherits(zone, "sfc")) {
    cli::cli_abort("{.arg zone} must be an sf / sfc object.")
  }
  if (!inherits(alert_raster, "SpatRaster")) {
    cli::cli_abort("{.arg alert_raster} must be a {.cls SpatRaster}.")
  }
  if (terra::nlyr(alert_raster) != 1L) {
    cli::cli_abort("{.arg alert_raster} must have a single layer.")
  }
  n_validation <- as.integer(n_validation)
  n_control    <- as.integer(n_control)
  if (n_validation < 1L) {
    cli::cli_abort("{.arg n_validation} must be >= 1.")
  }
  if (n_control < 0L) {
    cli::cli_abort("{.arg n_control} must be >= 0.")
  }
  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed)) {
      cli::cli_abort("{.arg seed} must be a single integer or NULL.")
    }
    set.seed(as.integer(seed))
  }

  # --- 1. Build the alert-priority raster (A1) ----------------------
  priority <- fordead_alert_mask(alert_raster,
                                 classes  = classes,
                                 buffer_m = buffer_m)
  n_alert_cells <- sum(!is.na(terra::values(priority)))
  if (n_alert_cells == 0L) {
    cli::cli_abort(
      c("No alert cell in {.arg alert_raster} for {.arg classes} = {.val {classes}}.",
        i = "Zone may be currently healthy — nothing to validate."),
      class = "nemeton_empty_alert_mask"
    )
  }

  # --- 2. Weighted GRTS draw on the alert priority ------------------
  validation_pts <- .draw_grts_weighted(priority, n_validation, seed = seed)
  if (is.null(validation_pts) || nrow(validation_pts) == 0L) {
    cli::cli_abort(
      c("Failed to draw any validation plot from the alert mask.",
        i = "Check that {.pkg spsurvey} is installed and the alert mask has enough cells."),
      class = "nemeton_empty_alert_mask"
    )
  }

  # --- 3. Equiprobable GRTS draw on the "control" cells ------------
  # `control_classes` (v0.49.1) defines which raster classes are
  # eligible for the control plots. Default `c(0L)` = strictly
  # healthy (the cell never crossed the alert threshold). On heavily
  # disturbed AOIs or with permissive thresholds, no class-0 cell
  # may exist — relax to e.g. `c(0L, 1L)` to allow lightly-alerted
  # cells as controls.
  control_pts <- if (n_control > 0L) {
    if (!is.numeric(control_classes) || length(control_classes) < 1L ||
        any(is.na(control_classes))) {
      cli::cli_abort("{.arg control_classes} must be a non-empty integer vector with no NA.")
    }
    control_classes <- as.integer(control_classes)

    healthy <- alert_raster
    h_vals  <- terra::values(healthy)
    cls_dist <- table(h_vals, useNA = "no")
    is_control <- !is.na(h_vals) & h_vals %in% control_classes
    h_vals[!is_control] <- NA
    terra::values(healthy) <- h_vals

    if (sum(!is.na(terra::values(healthy))) == 0L) {
      dist_str <- if (length(cls_dist)) {
        paste(names(cls_dist), "=", cls_dist, collapse = ", ")
      } else "raster fully NA"
      cli::cli_warn(c(
        "No cell matching {.arg control_classes} = {.val {control_classes}} found in {.arg alert_raster}.",
        i = "Class distribution: {dist_str}.",
        i = "Try relaxing {.arg control_classes} (e.g. {.code c(0L, 1L)}) or adjust thresholds/window.",
        i = "Skipping control plots ({n_control} requested)."
      ))
      NULL
    } else {
      .draw_grts_equiprobable(healthy, n_control, seed = seed)
    }
  } else NULL

  # --- 4. Assemble and tag rows -------------------------------------
  validation_pts$plot_id     <- sprintf("V%02d", seq_len(nrow(validation_pts)))
  validation_pts$type        <- "Validation"
  if (!is.null(control_pts) && nrow(control_pts) > 0L) {
    control_pts$plot_id <- sprintf("T%02d", seq_len(nrow(control_pts)))
    control_pts$type    <- "Temoin"
    # v0.49.1 — alert_class reflects the actual raster value at the
    # control point (was hard-coded to 0L). With `control_classes =
    # c(0L)` this is still 0 in practice, but with relaxed values
    # like c(0L, 1L) the column reports the real class of the cell.
    control_pts$alert_class <- as.integer(
      terra::extract(alert_raster,
                     terra::vect(control_pts$geometry),
                     ID = FALSE)[[1L]])
    plan <- rbind(validation_pts, control_pts)
  } else {
    plan <- validation_pts
  }

  plan$source  <- source
  plan$classes <- paste(classes, collapse = ",")
  plan$seed    <- if (is.null(seed)) NA_integer_ else as.integer(seed)

  # --- 5. Reorder columns + TSP visit order -------------------------
  plan <- plan[, c("plot_id", "type", "alert_class",
                   "source", "classes", "seed", "geometry"),
               drop = FALSE]
  plan$visit_order <- .compute_visit_order(plan)
  plan <- plan[order(plan$visit_order), , drop = FALSE]

  plan
}


# ---- internal helpers ------------------------------------------------

# Draw `n` points with inclusion probability proportional to the cell
# value of `priority_raster` (NA = excluded). Returns an `sf` POINT
# object in the raster's CRS, with an `alert_class` column copied from
# the priority value.
.draw_grts_weighted <- function(priority_raster, n, seed = NULL) {
  if (!requireNamespace("spsurvey", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg spsurvey} required for weighted GRTS.",
      i = "Install with {.code install.packages(\"spsurvey\")}."
    ))
  }
  # Convert raster cells to point candidates (one per non-NA cell).
  pts <- terra::as.points(priority_raster, values = TRUE, na.rm = TRUE)
  pts_sf <- sf::st_as_sf(pts)
  names(pts_sf)[1L] <- "alert_class"
  pts_sf$alert_class <- as.integer(pts_sf$alert_class)

  if (nrow(pts_sf) == 0L) return(NULL)

  # Unequal-probability via `caty_var` / `caty_n`. Each distinct alert
  # class becomes a category; we allocate `n` proportionally to
  # class weight (= class value), so higher classes draw more.
  pts_sf$caty <- as.character(pts_sf$alert_class)
  classes_present <- sort(unique(pts_sf$alert_class))
  weights <- as.numeric(classes_present)
  alloc_raw <- n * weights / sum(weights)
  # Largest-remainder rounding so we always sum to n.
  alloc_int <- floor(alloc_raw)
  remainder <- n - sum(alloc_int)
  if (remainder > 0L) {
    frac_order <- order(alloc_raw - alloc_int, decreasing = TRUE)
    alloc_int[frac_order[seq_len(remainder)]] <-
      alloc_int[frac_order[seq_len(remainder)]] + 1L
  }
  caty_n <- stats::setNames(as.integer(alloc_int),
                            as.character(classes_present))
  # Cap each category by available candidates.
  for (cls in names(caty_n)) {
    avail <- sum(pts_sf$caty == cls)
    if (caty_n[[cls]] > avail) caty_n[[cls]] <- as.integer(avail)
  }
  caty_n <- caty_n[caty_n > 0L]
  if (!length(caty_n)) return(NULL)

  # spsurvey::grts wants a named *vector* for caty_n (not a list), and
  # its stdout chatter must be silenced separately from the call itself
  # — capturing stdout around the call swallows the error message and
  # leaves us with an empty `e$message`. Use sink() / capture.output()
  # around an inner block, but keep the call's error propagation
  # intact via withCallingHandlers.
  out <- NULL
  log_capture <- character(0)
  tryCatch({
    log_capture <- utils::capture.output({
      out <- suppressMessages(spsurvey::grts(
        sframe   = pts_sf,
        n_base   = sum(caty_n),
        caty_var = "caty",
        caty_n   = caty_n
      ))
    })
  }, error = function(e) {
    cli::cli_warn(c(
      "spsurvey::grts (weighted) failed: {.val {conditionMessage(e)}}.",
      i = "stdout: {.val {paste(log_capture, collapse = ' | ')}}"
    ))
  })
  if (is.null(out)) return(NULL)

  sites <- out$sites_base
  if (is.null(sites) || nrow(sites) == 0L) return(NULL)

  # Keep only what we need; alert_class comes from caty back-mapped to int.
  sites$alert_class <- as.integer(sites$caty)
  sites[, c("alert_class", "geometry"), drop = FALSE]
}


# Draw `n` equiprobable points from the non-NA cells of `raster`.
# Returns an `sf` POINT object in the raster's CRS.
.draw_grts_equiprobable <- function(raster, n, seed = NULL) {
  if (!requireNamespace("spsurvey", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg spsurvey} required for GRTS.",
      i = "Install with {.code install.packages(\"spsurvey\")}."
    ))
  }
  pts <- terra::as.points(raster, values = TRUE, na.rm = TRUE)
  pts_sf <- sf::st_as_sf(pts)
  if (nrow(pts_sf) == 0L) return(NULL)
  n <- min(as.integer(n), nrow(pts_sf))

  out <- NULL
  log_capture <- character(0)
  tryCatch({
    log_capture <- utils::capture.output({
      out <- suppressMessages(spsurvey::grts(sframe = pts_sf, n_base = n))
    })
  }, error = function(e) {
    cli::cli_warn(c(
      "spsurvey::grts (equiprobable) failed: {.val {conditionMessage(e)}}.",
      i = "stdout: {.val {paste(log_capture, collapse = ' | ')}}"
    ))
  })
  if (is.null(out)) return(NULL)

  sites <- out$sites_base
  if (is.null(sites) || nrow(sites) == 0L) return(NULL)
  sites[, "geometry", drop = FALSE]
}


# TSP visit order over the union of plots. Mirrors the helper used by
# `create_sampling_plan()`.
.compute_visit_order <- function(plan) {
  if (!requireNamespace("TSP", quietly = TRUE)) {
    # Fall back to id order if TSP isn't installed.
    return(seq_len(nrow(plan)))
  }
  coords <- sf::st_coordinates(plan)
  d   <- stats::dist(coords)
  tsp <- TSP::TSP(d)
  tour <- tryCatch(
    TSP::solve_TSP(tsp, method = "nearest_insertion"),
    error = function(e) NULL
  )
  if (is.null(tour)) return(seq_len(nrow(plan)))
  order_idx <- as.integer(tour)
  # Convert tour index back to per-row visit order.
  out <- integer(nrow(plan))
  out[order_idx] <- seq_along(order_idx)
  out
}
