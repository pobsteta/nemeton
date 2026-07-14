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
#' @param source Character. Tag stored on every row (`"FORDEAD"`,
#'   `"FAST"` or `"RECONFORT"`) so the field crew knows which pipeline
#'   raised the alert. Default `"FORDEAD"`. The function samples any
#'   single-layer categorical `alert_raster` by `classes`; for
#'   `"RECONFORT"` the caller passes the broadleaf class raster (codes
#'   1 sain / 2 dépérissant / 3 très-dépérissant) with
#'   `classes = c(2, 3)`, `control_classes = c(1)`.
#' @param weighting One of `"uniform"` (default) or `"continuous"`.
#'   `"uniform"` keeps the historical behaviour: the validation draw is a
#'   per-class unequal-probability GRTS (a class-4 cell outweighs a class-3
#'   one). `"continuous"` instead weights the inclusion probability by an
#'   **external continuous severity raster** (`weight_raster`), so two cells in
#'   the same class are still separated by their raw severity — parity with
#'   [create_trend_sanitary_plan()] (which does this for FAST via `|slope|`).
#'   In continuous mode `classes` becomes a pure **eligibility mask** (no
#'   per-class stratification).
#' @param weight_raster A single-layer `terra::SpatRaster` of **continuous**
#'   severity (e.g. FORDEAD `anomaly_index`, or a RECONFORT score/probability),
#'   **required** when `weighting = "continuous"` (a `NULL` is an explicit
#'   error — no silent fallback). Aligned onto the alert grid (reprojected /
#'   resampled bilinearly if needed); a raster without a CRS or not
#'   reprojectable raises a typed `validation_weight_raster_mismatch` error.
#'   Ignored when `weighting = "uniform"`.
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
#'     \item{`alert_weight`}{Numeric. **Only when `weighting = "continuous"`.**
#'       Raw value of `weight_raster` at the drawn point (severity that drove
#'       the inclusion probability), for traceability. Absent in uniform mode.}
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
#' degenerate plan. In `weighting = "continuous"` mode the same typed
#' error is raised when `weight_raster` has no finite or no varying value
#' over the alert cells (empty / all-NA / constant); a `weight_raster`
#' that cannot be aligned onto the alert grid raises the distinct
#' `validation_weight_raster_mismatch` error instead.
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
                                            source          = c("FORDEAD", "FAST", "RECONFORT"),
                                            weighting       = c("uniform", "continuous"),
                                            weight_raster   = NULL,
                                            seed            = NULL) {
  source    <- match.arg(source)
  weighting <- match.arg(weighting)
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
  # Continuous weighting needs an external severity raster. A NULL here is an
  # explicit error (no silent fallback to uniform) so a mis-wired caller fails
  # loudly rather than shipping a plan that ignores the severity it asked for.
  if (identical(weighting, "continuous")) {
    if (is.null(weight_raster)) {
      cli::cli_abort(c(
        "{.arg weight_raster} is required when {.arg weighting} = {.val continuous}.",
        i = "Pass a continuous severity raster (FORDEAD {.field anomaly_index} or a RECONFORT score/probability)."))
    }
    if (!inherits(weight_raster, "SpatRaster")) {
      cli::cli_abort("{.arg weight_raster} must be a {.cls SpatRaster}.")
    }
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
  n_alert_cells <- sum(terra::global(priority, "notNA")[[1L]], na.rm = TRUE)
  if (n_alert_cells == 0L) {
    cli::cli_abort(
      c("No alert cell in {.arg alert_raster} for {.arg classes} = {.val {classes}}.",
        i = "Zone may be currently healthy — nothing to validate."),
      class = "nemeton_empty_alert_mask"
    )
  }

  # --- 2. Draw the validation plots over the alert priority ---------
  if (identical(weighting, "continuous")) {
    # Align the external severity raster onto the alert grid, restrict it to the
    # eligible alert cells (`classes` acts as an eligibility MASK — no per-class
    # stratification here) and min-max normalise to a strictly-positive
    # inclusion weight, so the continuous-probability GRTS favours the most
    # severe pixels proportionally while every eligible cell keeps p > 0.
    aligned <- .align_weight_raster(weight_raster, priority)
    wv <- terra::values(aligned)[, 1L]
    # `priority` is read once and dropped; re-reading it inside the subset would
    # materialise the whole raster a second time.
    pv <- terra::values(priority)[, 1L]
    wv[is.na(pv)] <- NA_real_
    rm(pv)
    finite <- wv[is.finite(wv)]
    if (length(finite) == 0L) {
      cli::cli_abort(
        c("{.arg weight_raster} holds no finite value over the alert cells.",
          i = "The severity raster may not overlap the alerts, or is fully NA there."),
        class = "nemeton_empty_alert_mask")
    }
    rng <- range(finite)
    if (rng[2L] - rng[1L] <= 0) {
      cli::cli_abort(
        c("{.arg weight_raster} is constant over the alert cells — no gradient to weight by.",
          i = "Use {.code weighting = \"uniform\"} or provide a varying severity raster."),
        class = "nemeton_empty_alert_mask")
    }
    eps  <- 1e-3
    norm <- (wv - rng[1L]) / (rng[2L] - rng[1L])   # [0, 1]
    norm <- norm * (1 - eps) + eps                 # (eps, 1] : lowest eligible cell keeps p > 0
    norm[!is.finite(wv)] <- NA_real_
    wnorm <- priority
    terra::values(wnorm) <- norm
    validation_pts <- .draw_grts_continuous(wnorm, n_validation, seed = seed)
  } else {
    validation_pts <- .draw_grts_weighted(priority, n_validation, seed = seed)
  }
  if (is.null(validation_pts) || nrow(validation_pts) == 0L) {
    cli::cli_abort(
      c("Failed to draw any validation plot from the alert mask.",
        i = "Check that {.pkg spsurvey} is installed and the alert mask has enough cells."),
      class = "nemeton_empty_alert_mask"
    )
  }
  if (identical(weighting, "continuous")) {
    # Traceability : raw severity + actual raster class at each drawn point
    # (`.draw_grts_continuous()` returns the normalised value as `alert_value`,
    # which we drop in favour of the raw `alert_weight`).
    vv <- terra::vect(validation_pts)
    validation_pts$alert_weight <- as.numeric(
      terra::extract(aligned, vv, ID = FALSE)[[1L]])
    validation_pts$alert_class <- as.integer(
      terra::extract(alert_raster, vv, ID = FALSE)[[1L]])
    validation_pts$alert_value <- NULL
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

    # `is_control` already says which cells survived — re-reading `healthy` here
    # would materialise the raster again for a count we hold in RAM.
    if (sum(is_control) == 0L) {
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
  # Columns shared by both sub-samples (so rbind aligns cleanly). `alert_weight`
  # is present only in continuous weighting — uniform output stays byte-identical
  # to the pre-existing schema.
  common_cols <- c("plot_id", "type", "alert_class",
                   if (identical(weighting, "continuous")) "alert_weight")
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
    if (identical(weighting, "continuous")) {
      # Severity at the control point too (should be low — traceability parity).
      control_pts$alert_weight <- as.numeric(
        terra::extract(aligned, terra::vect(control_pts$geometry),
                       ID = FALSE)[[1L]])
    }
    plan <- rbind(validation_pts[, common_cols], control_pts[, common_cols])
  } else {
    plan <- validation_pts[, common_cols]
  }

  plan$source  <- source
  plan$classes <- paste(classes, collapse = ",")
  plan$seed    <- if (is.null(seed)) NA_integer_ else as.integer(seed)

  # --- 5. Reorder columns + TSP visit order -------------------------
  out_cols <- c("plot_id", "type", "alert_class",
                if (identical(weighting, "continuous")) "alert_weight",
                "source", "classes", "seed", "geometry")
  plan <- plan[, out_cols, drop = FALSE]
  plan$visit_order <- .compute_visit_order(plan)
  plan <- plan[order(plan$visit_order), , drop = FALSE]

  plan
}


#' Create a SANITARY plot plan on the multi-year `trend` (spec 025)
#'
#' Draws **placettes sanitaires** over the FAST `trend` raster of a
#' spectral index (default NDRE), weighting inclusion by the **continuous**
#' decline magnitude (`|slope|`, NDRE/yr) via an unequal-probability GRTS —
#' the steeper the chronic decline, the higher the inclusion probability.
#' Optional control plots are drawn on the **stable** cells.
#'
#' This is a **standalone sanitary plan**: it has **no relationship** with
#' the terrain / inventory plots (`plot` table, [create_sampling_plan()],
#' [create_validation_sampling_plan()]). It never reads the `plot` table and,
#' unlike the terrain validation plan, it does **not** compute a TSP walking
#' tour — the sanitary plots are returned ordered by **descending decline
#' severity** (`S01` = steepest), not by a field-campaign route.
#'
#' Unlike [create_validation_sampling_plan()] (which discretises any 0-4 mask
#' and weights by class), this weights by the raw `|slope|`, so a pixel
#' declining at 0.04 NDRE/yr is prioritised over one at 0.012 even if both
#' land in the same quartile class. The trend raster is read via
#' [read_fast_alert_raster()] `mode = "trend"` (scene-by-scene per tile then a
#' common-grid mosaic — immune to the multi-tile resolution bug), with the UGF
#' mask already applied.
#'
#' @param con A `DBIConnection`. Used **only** to resolve the UGF zone
#'   polygon (the mask) — never for plot / inventory data.
#' @param zone_id Integer scalar. Existing zone in `monitoring_zone`.
#' @param date_from,date_to Date or character `"YYYY-MM-DD"` bounding the
#'   trend window (typically several years).
#' @param cache_dir Character scalar. COG cache root (must exist).
#' @param index One of `"NDRE"` (default), `"NDMI"`, `"NDVI"`, `"NBR"`.
#' @param n_plots Integer. Target number of sanitary plots on the declining
#'   cells. Default `20L`. **Target only** (GRTS may return fewer on a small
#'   frame).
#' @param n_control Integer. Target number of control plots on the stable
#'   cells (`trend == 0`). Default `5L`; `0` to skip.
#' @param months,min_years,min_obs_per_year,alpha,min_slope Trend
#'   parameters, identical in meaning and default to
#'   [read_fast_alert_raster()] `mode = "trend"` (`min_slope` is the minimum
#'   decline magnitude for a pixel to count as a candidate, default `0.005`).
#' @param apply_zone_mask,mask_polygon UGF mask, forwarded to
#'   [read_fast_alert_raster()]. When `apply_zone_mask = TRUE` (default) the
#'   plan **must** stay inside the zone: the polygon is resolved up front
#'   (from `mask_polygon`, else `con` / `zone_id`) and the function aborts
#'   with a typed `nemeton_zone_mask_unresolved` error if it cannot be
#'   obtained — it never falls back to sampling the full S2 tile. Pass
#'   `mask_polygon` explicitly (the zone `sf` you already hold) to skip the
#'   DB round-trip.
#' @param seed Integer or `NULL`. Makes the GRTS draw reproducible.
#'
#' @return An `sf` POINT object in EPSG:2154 with columns `plot_id`
#'   (`S01…` sanitary, `T01…` control), `type` (`"Sanitaire"` / `"Temoin"`),
#'   `alert_value` (the `|slope|` at the plot; `0` for controls), `index`,
#'   `source` (`"FAST_TREND"`) and `seed`. Sanitary plots come first, ordered
#'   by descending `alert_value`. **No `visit_order` column** (no TSP).
#'
#' @section Edge case — nothing to validate:
#' When the trend raster is empty (no in-season scene / too few years) or
#' holds no significant decline (every cell `0` or `NA`), the function raises
#' a typed `nemeton_empty_alert_mask` error so the app can render a clean
#' \dQuote{Aucun déclin significatif} message.
#'
#' @seealso [read_fast_alert_raster()] (`mode = "trend"`),
#'   [extract_pixel_trend()] (the per-pixel diagnostic behind `alert_value`),
#'   [create_validation_sampling_plan()] (the separate terrain plan).
#'
#' @examples
#' \dontrun{
#'   con <- db_connect(Sys.getenv("NEMETON_DB_URL"))
#'   on.exit(db_disconnect(con), add = TRUE)
#'   plan <- create_trend_sanitary_plan(
#'     con, zone_id = 1L, index = "NDRE",
#'     date_from = "2017-01-01", date_to = "2024-12-31",
#'     cache_dir = "/proj/cache/layers/sentinel2",
#'     n_plots = 20L, n_control = 5L, seed = 42L)
#'   table(plan$type)
#' }
#'
#' @export
create_trend_sanitary_plan <- function(con, zone_id,
                                       date_from, date_to, cache_dir,
                                       index = c("NDRE", "NDMI", "NDVI", "NBR"),
                                       n_plots          = 20L,
                                       n_control        = 5L,
                                       months           = 6:9,
                                       min_years        = 4L,
                                       min_obs_per_year = 2L,
                                       alpha            = 0.05,
                                       min_slope        = 0.005,
                                       apply_zone_mask  = TRUE,
                                       mask_polygon     = NULL,
                                       seed             = NULL) {
  index <- match.arg(index)
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg terra} required.")
  }
  n_plots   <- as.integer(n_plots)
  n_control <- as.integer(n_control)
  if (n_plots < 1L)   cli::cli_abort("{.arg n_plots} must be >= 1.")
  if (n_control < 0L) cli::cli_abort("{.arg n_control} must be >= 0.")
  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed)) {
      cli::cli_abort("{.arg seed} must be a single integer or NULL.")
    }
    set.seed(as.integer(seed))
  }

  # --- 1. Resolve the UGF mask up front and REQUIRE it --------------------
  # A sanitary plan must stay inside the monitoring zone. `read_fast_alert_
  # raster()` silently returns an UNMASKED, full-tile raster when the zone
  # polygon can't be resolved (`.apply_zone_mask(r, NULL)` is a no-op), which
  # would make GRTS scatter plots across the whole S2 tile (~100 km) instead
  # of the UGF. Resolve the polygon here and abort loudly if missing, rather
  # than drawing a tile-wide plan.
  if (isTRUE(apply_zone_mask)) {
    mask_polygon <- mask_polygon %||% tryCatch(
      .get_zone_aoi(con, zone_id), error = function(e) NULL)
    if (is.null(mask_polygon)) {
      cli::cli_abort(
        c("Could not resolve the UGF mask polygon for zone {.val {zone_id}}.",
          i = "A sanitary plan must stay inside the zone; refusing to sample the full tile.",
          i = "Pass {.arg mask_polygon} explicitly, or check the zone geometry ({.field zone_wkt})."),
        class = "nemeton_zone_mask_unresolved")
    }
  }

  # --- 2. Continuous trend raster (|slope| if significant, 0 stable, NA few)
  cont <- read_fast_alert_raster(
    con, zone_id, index = index, date_from = date_from, date_to = date_to,
    mode = "trend", months = months, min_years = min_years,
    min_obs_per_year = min_obs_per_year, alpha = alpha, min_slope = min_slope,
    cache_dir = cache_dir,
    apply_zone_mask = apply_zone_mask, mask_polygon = mask_polygon,
    cache_result = FALSE)
  if (is.null(cont)) {
    cli::cli_abort(
      c("No usable {.field {index}} trend raster for zone {.val {zone_id}}.",
        i = "No in-season scene in the window, or fewer than {min_years} valid years."),
      class = "nemeton_empty_alert_mask")
  }

  # --- 3. Significant-decline priority (value > 0), weighted by |slope| ----
  priority  <- terra::ifel(cont > 0, cont, NA_real_)
  n_decline <- sum(!is.na(terra::values(priority)))
  if (n_decline == 0L) {
    cli::cli_abort(
      c("No significant {.field {index}} decline in zone {.val {zone_id}}.",
        i = "Every pixel is stable (trend value 0) or has too few years (NA)."),
      class = "nemeton_empty_alert_mask")
  }

  # --- 4. Continuous-probability GRTS for the sanitary plots ---------------
  sanitary_pts <- .draw_grts_continuous(priority, n_plots, seed = seed)
  if (is.null(sanitary_pts) || nrow(sanitary_pts) == 0L) {
    cli::cli_abort(
      c("Failed to draw any sanitary plot from the {.field {index}} trend.",
        i = "Check that {.pkg spsurvey} is installed and the decline mask has enough cells."),
      class = "nemeton_empty_alert_mask")
  }

  # --- 5. Equiprobable controls on the STABLE cells (trend == 0) -----------
  control_pts <- if (n_control > 0L) {
    stable <- terra::ifel(cont == 0, 0, NA_real_)
    if (sum(!is.na(terra::values(stable))) == 0L) {
      cli::cli_warn(c(
        "No stable (trend value 0) cell to draw controls from in zone {.val {zone_id}}.",
        i = "Skipping {n_control} control plot{?s}."))
      NULL
    } else {
      .draw_grts_equiprobable(stable, n_control, seed = seed)
    }
  } else NULL

  # --- 6. Assemble — sanitary first, by DESCENDING severity (no TSP) -------
  sanitary_pts <- sanitary_pts[order(-sanitary_pts$alert_value), , drop = FALSE]
  sanitary_pts$plot_id <- sprintf("S%02d", seq_len(nrow(sanitary_pts)))
  sanitary_pts$type    <- "Sanitaire"
  keep <- c("plot_id", "type", "alert_value", "geometry")

  if (!is.null(control_pts) && nrow(control_pts) > 0L) {
    control_pts$plot_id     <- sprintf("T%02d", seq_len(nrow(control_pts)))
    control_pts$type        <- "Temoin"
    control_pts$alert_value <- 0
    plan <- rbind(sanitary_pts[, keep], control_pts[, keep])
  } else {
    plan <- sanitary_pts[, keep]
  }

  plan$index  <- index
  plan$source <- "FAST_TREND"
  plan$seed   <- if (is.null(seed)) NA_integer_ else as.integer(seed)
  plan[, c("plot_id", "type", "alert_value", "index", "source", "seed",
           "geometry"), drop = FALSE]
}


# ---- internal helpers ------------------------------------------------

# Align an external continuous severity raster onto the alert grid (`template`,
# typically the alert-priority raster). Same grid -> returned as-is; otherwise
# reprojected + resampled (bilinear) onto the template geometry so its cells map
# 1:1 to the alert cells. A `weight_raster` without a CRS, or one that cannot be
# reprojected onto the template CRS, raises a typed
# `validation_weight_raster_mismatch` error (the app maps it to a clean
# message). Overlap / all-NA is left to the caller's finite-value guard, which
# raises `nemeton_empty_alert_mask` instead.
.align_weight_raster <- function(weight_raster, template) {
  if (terra::nlyr(weight_raster) != 1L) weight_raster <- weight_raster[[1L]]
  if (!nzchar(terra::crs(weight_raster))) {
    cli::cli_abort(
      c("{.arg weight_raster} has no CRS; cannot align it onto the alert grid.",
        i = "Provide a georeferenced severity raster (same datum as {.arg alert_raster})."),
      class = "validation_weight_raster_mismatch")
  }
  same <- tryCatch(
    terra::compareGeom(weight_raster, template, crs = TRUE, ext = TRUE,
                       rowcol = TRUE, res = TRUE, stopOnError = FALSE),
    error = function(e) FALSE)
  if (isTRUE(same)) return(weight_raster)
  aligned <- tryCatch(
    terra::project(weight_raster, template, method = "bilinear"),
    error = function(e) NULL)
  if (is.null(aligned)) {
    cli::cli_abort(
      c("Cannot reconcile {.arg weight_raster} with the alert grid.",
        i = "Its CRS is not reprojectable onto the {.arg alert_raster} CRS."),
      class = "validation_weight_raster_mismatch")
  }
  aligned
}

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


# spec 025 — draw `n` points with inclusion probability proportional to the
# CONTINUOUS cell value (`|slope|`) of `priority_raster` (NA = excluded), via
# spsurvey's unequal-probability `aux_var`. Counterpart of
# `.draw_grts_weighted()` (which bins to discrete classes first): here the
# raw magnitude drives inclusion, so the steepest declines are favoured
# proportionally — without losing resolution to quartile classes. Returns an
# `sf` POINT in the raster CRS with the `alert_value` column preserved.
.draw_grts_continuous <- function(priority_raster, n, seed = NULL) {
  if (!requireNamespace("spsurvey", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg spsurvey} required for continuous-probability GRTS.",
      i = "Install with {.code install.packages(\"spsurvey\")}."
    ))
  }
  pts <- terra::as.points(priority_raster, values = TRUE, na.rm = TRUE)
  pts_sf <- sf::st_as_sf(pts)
  names(pts_sf)[1L] <- "alert_value"
  pts_sf$alert_value <- as.numeric(pts_sf$alert_value)
  if (nrow(pts_sf) == 0L) return(NULL)
  n <- min(as.integer(n), nrow(pts_sf))

  out <- NULL
  log_capture <- character(0)
  tryCatch({
    log_capture <- utils::capture.output({
      # `aux_var` = the continuous decline magnitude -> inclusion probability
      # proportional to it (spsurvey normalises internally). Values are
      # strictly positive by construction (priority = trend > 0).
      out <- suppressMessages(spsurvey::grts(
        sframe = pts_sf, n_base = n, aux_var = "alert_value"))
    })
  }, error = function(e) {
    cli::cli_warn(c(
      "spsurvey::grts (continuous) failed: {.val {conditionMessage(e)}}.",
      i = "stdout: {.val {paste(log_capture, collapse = ' | ')}}"
    ))
  })
  if (is.null(out)) return(NULL)

  sites <- out$sites_base
  if (is.null(sites) || nrow(sites) == 0L) return(NULL)
  sites$alert_value <- as.numeric(sites$alert_value)
  sites[, c("alert_value", "geometry"), drop = FALSE]
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
