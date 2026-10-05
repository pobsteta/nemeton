# logique-metier-app.R
# Trois calculs métier longtemps faits dans nemetonshiny et rapatriés dans le
# cœur (audit 1.0 de l'app, constats n° 64-66 ; règle stricte n° 1 : aucune
# logique métier dans l'app). Le comportement d'origine de l'app est conservé,
# aux garde-fous près.

# ---- n° 64 : composite NDVI Sentinel-2 de saison ---------------------------

#' Season NDVI composite from cached Sentinel-2 scenes
#'
#' Builds the single-layer NDVI composite that feeds indicator C2 from the
#' on-disk Sentinel-2 cache: scenes of the growing season (1 June - 30
#' September by default) are selected, at most the `max_scenes` most recent
#' are kept, their NDVI is computed by [build_index_stack()] and reduced to the
#' per-pixel **median**, then clamped to `[0, 1]`.
#'
#' The median rather than the mean: a residual cloud veil is an outlier, not
#' centred noise. The lower bound 0 matches the ortho-derived NDVI: a negative
#' value means water or bare soil and would drag the unit mean down. Outside
#' the season, a broadleaf NDVI describes a bare crown, a different quantity;
#' when no scene falls in the season, every scene is used.
#'
#' Bands are read through [read_s2_band_raster()], so the L2A radiometric
#' offset of scenes processed since 2022-01-25 is removed (spec 055).
#'
#' @param cache_dir Character(1). Sentinel-2 cache root, i.e.
#'   `<project>/cache/layers/sentinel2` (one sub-directory per scene).
#' @param scenes Optional `data.frame` with `scene_id` and `obs_date`. `NULL`
#'   (default) lists the populated scene directories of `cache_dir`.
#' @param mask_polygon Optional `sf`/`sfc` polygon; pixels outside become NA.
#' @param season_doy Integer(2). Day-of-year window of the growing season.
#'   Default `c(152, 273)` (1 June - 30 September).
#' @param max_scenes Integer(1). Maximum number of (most recent) scenes kept.
#'   Default 12.
#' @param clamp Numeric(2) or `NULL`. Bounds applied to the composite. Default
#'   `c(0, 1)`; `NULL` disables clamping.
#'
#' @return A single-layer [terra::SpatRaster] named `"ndvi"`, with attribute
#'   `"scenes"` (the `scene_id` / `obs_date` used), or `NULL` when no scene is
#'   usable.
#'
#' @family spectral
#' @export
#'
#' @examples
#' \dontrun{
#' ndvi <- build_ndvi_season_composite("project/cache/layers/sentinel2",
#'                                     mask_polygon = aoi)
#' attr(ndvi, "scenes")
#' }
build_ndvi_season_composite <- function(cache_dir,
                                        scenes = NULL,
                                        mask_polygon = NULL,
                                        season_doy = c(152L, 273L),
                                        max_scenes = 12L,
                                        clamp = c(0, 1)) {
  if (!is.character(cache_dir) || length(cache_dir) != 1L || is.na(cache_dir)) {
    cli::cli_abort("{.arg cache_dir} must be a single path.")
  }
  if (!is.numeric(season_doy) || length(season_doy) != 2L ||
      anyNA(season_doy) || season_doy[1] > season_doy[2]) {
    cli::cli_abort("{.arg season_doy} must be two increasing day-of-year values.")
  }
  if (!is.numeric(max_scenes) || length(max_scenes) != 1L ||
      is.na(max_scenes) || max_scenes < 1) {
    cli::cli_abort("{.arg max_scenes} must be a positive integer.")
  }
  if (!is.null(clamp) &&
      (!is.numeric(clamp) || length(clamp) != 2L || anyNA(clamp) ||
       clamp[1] > clamp[2])) {
    cli::cli_abort("{.arg clamp} must be {.code NULL} or two increasing bounds.")
  }

  if (is.null(scenes)) scenes <- .list_cached_s2_scenes(cache_dir)
  if (is.null(scenes) || !nrow(scenes)) return(NULL)
  .validate_scenes_df(scenes)
  scenes$obs_date <- as.Date(scenes$obs_date)

  doy <- as.integer(format(scenes$obs_date, "%j"))
  in_season <- !is.na(doy) & doy >= season_doy[1] & doy <= season_doy[2]
  sel <- if (any(in_season)) scenes[in_season, , drop = FALSE] else scenes
  sel <- sel[order(sel$obs_date), , drop = FALSE]
  if (nrow(sel) > max_scenes) sel <- utils::tail(sel, as.integer(max_scenes))

  stack <- build_index_stack(cache_dir, sel, index = "NDVI",
                             mask_polygon = mask_polygon)
  if (is.null(stack) || terra::nlyr(stack) == 0L) return(NULL)

  ndvi <- if (terra::nlyr(stack) == 1L) {
    stack[[1]]
  } else {
    terra::app(stack, fun = function(x) stats::median(x, na.rm = TRUE))
  }
  if (!is.null(clamp)) {
    ndvi <- terra::clamp(ndvi, lower = clamp[1], upper = clamp[2])
  }
  names(ndvi) <- "ndvi"
  attr(ndvi, "scenes") <- sel[, c("scene_id", "obs_date")]
  ndvi
}

# Scènes peuplées du cache : un dossier par scène contenant au moins un .tif,
# date d'acquisition = premier bloc AAAAMMJJ de l'identifiant.
.list_cached_s2_scenes <- function(cache_dir) {
  if (!dir.exists(cache_dir)) return(NULL)
  dirs <- list.dirs(cache_dir, recursive = FALSE, full.names = FALSE)
  if (!length(dirs)) return(NULL)
  populated <- vapply(dirs, function(s) {
    any(grepl("\\.tif$", list.files(file.path(cache_dir, s))))
  }, logical(1))
  dirs <- dirs[populated]
  if (!length(dirs)) return(NULL)
  d <- regmatches(dirs, regexpr("[0-9]{8}", dirs))
  obs <- rep(as.Date(NA), length(dirs))
  has <- grepl("[0-9]{8}", dirs)
  obs[has] <- as.Date(d, format = "%Y%m%d")
  keep <- !is.na(obs)
  if (!any(keep)) return(NULL)
  out <- data.frame(scene_id = dirs[keep], obs_date = obs[keep],
                    stringsAsFactors = FALSE)
  out[order(out$obs_date), , drop = FALSE]
}


# ---- n° 65 : indices ombrothermiques ----------------------------------------

#' Gaussen-Bagnouls dry months and De Martonne aridity index
#'
#' Computes two forest-climatology indices from monthly climatologies of
#' precipitation and temperature:
#'
#' * **Gaussen-Bagnouls dry months**: a month is dry when `P < 2 T`
#'   (precipitation in mm, temperature in °C);
#' * **De Martonne index**: `sum(P) / (mean(T) + 10)` over the year.
#'
#' Months are matched by `month`. A month with no finite P or T is never
#' counted dry; with no matching month, the result is empty / `NA`.
#'
#' @param clim_rr `data.frame` with columns `month` and `value`: monthly
#'   precipitation (mm/month), e.g. from [eobs_monthly_climatology()].
#' @param clim_t `data.frame` with columns `month` and `value`: monthly mean
#'   temperature (°C).
#'
#' @return A list with `dry_idx` (integer, the dry months), `dry_months`
#'   (integer, their count; `NA` when no month matches) and `demartonne`
#'   (numeric; `NA` when not computable).
#'
#' @family climate
#' @export
#'
#' @examples
#' rr <- data.frame(month = 1:12,
#'                  value = c(70, 60, 55, 50, 40, 20, 8, 15, 45, 80, 90, 80))
#' tt <- data.frame(month = 1:12,
#'                  value = c(8, 9, 11, 13, 17, 21, 24, 24, 21, 16, 12, 9))
#' climate_ombrothermic_indices(rr, tt)
climate_ombrothermic_indices <- function(clim_rr, clim_t) {
  empty <- list(dry_idx = integer(0), dry_months = NA_integer_,
                demartonne = NA_real_)
  if (!is.data.frame(clim_rr) || !is.data.frame(clim_t) ||
      !all(c("month", "value") %in% names(clim_rr)) ||
      !all(c("month", "value") %in% names(clim_t))) {
    return(empty)
  }
  m <- merge(
    data.frame(month = clim_rr$month,
               P = suppressWarnings(as.numeric(clim_rr$value))),
    data.frame(month = clim_t$month,
               Tm = suppressWarnings(as.numeric(clim_t$value))),
    by = "month", all = FALSE)
  if (!nrow(m)) return(empty)
  m <- m[order(m$month), , drop = FALSE]
  dry <- is.finite(m$P) & is.finite(m$Tm) & (m$P < 2 * m$Tm)
  tot_p  <- sum(m$P, na.rm = TRUE)
  mean_t <- mean(m$Tm[is.finite(m$Tm)])
  list(
    dry_idx    = as.integer(m$month[dry]),
    dry_months = as.integer(sum(dry)),
    # Un dénominateur nul (moyenne de -10 °C) n'a pas de sens : NA.
    demartonne = if (is.finite(mean_t) && mean_t + 10 != 0) {
      tot_p / (mean_t + 10)
    } else {
      NA_real_
    }
  )
}


# ---- n° 66 : agrégation des familles sur les unités -------------------------

#' Aggregate family scores over a set of units
#'
#' Reduces the per-unit family scores (`famille_*` columns of
#' [create_family_index()]) to one score per family for the whole project,
#' the input of [compute_general_index()].
#'
#' With `weights = "surface"` (default) each unit weighs by its area, so a
#' 0.5 ha unit no longer counts as much as a 50 ha one. The area is read from
#' `surface_col`, or computed from the geometry of an `sf` object when the
#' column is absent. When no usable area is available (missing, `NA`, or not
#' strictly positive for some unit), the function falls back to the simple
#' mean and says so. Within each family, units whose score is `NA` are left
#' out and the remaining weights renormalised.
#'
#' @param units An `sf` object or `data.frame` with `famille_*` columns.
#' @param weights `"surface"` (default) or `"none"` (simple mean, the
#'   historical behaviour of the app).
#' @param surface_col Character(1). Column holding the unit area. Default
#'   `"surface_m2"`.
#' @param family_pattern Regular expression selecting the family columns.
#'   Default `"^famille_[a-z]"`.
#'
#' @return A named numeric vector, one score per family column (`NA` for a
#'   family with no scored unit); `numeric(0)` when there is no family column.
#'   Attribute `"weighting"`: `"surface"` or `"none"`, the weighting actually
#'   applied.
#'
#' @family families
#' @export
#'
#' @examples
#' u <- data.frame(famille_carbone = c(80, 20), surface_m2 = c(450000, 5000))
#' aggregate_family_scores(u)                    # ~79.3, the large unit dominates
#' aggregate_family_scores(u, weights = "none")  # 50
aggregate_family_scores <- function(units,
                                    weights = c("surface", "none"),
                                    surface_col = "surface_m2",
                                    family_pattern = "^famille_[a-z]") {
  weights <- match.arg(weights)
  if (is.null(units)) return(numeric(0))
  if (!is.data.frame(units)) {
    cli::cli_abort("{.arg units} must be an {.cls sf} object or a data.frame.")
  }
  family_cols <- grep(family_pattern, names(units), value = TRUE)
  if (!length(family_cols)) return(numeric(0))

  w <- NULL
  applied <- "none"
  if (weights == "surface") {
    w <- if (surface_col %in% names(units)) {
      suppressWarnings(as.numeric(units[[surface_col]]))
    } else if (inherits(units, "sf")) {
      tryCatch(as.numeric(sf::st_area(units)), error = function(e) NULL)
    }
    if (is.null(w) || length(w) != nrow(units) || !all(is.finite(w) & w > 0)) {
      cli::cli_warn(c(
        "No usable unit area ({.field {surface_col}} or geometry): family scores fall back to the simple mean.",
        i = "Every unit needs a finite, strictly positive area to weight by surface."
      ))
      w <- NULL
    } else {
      applied <- "surface"
    }
  }

  df <- if (inherits(units, "sf")) sf::st_drop_geometry(units) else units
  out <- vapply(family_cols, function(col) {
    v <- suppressWarnings(as.numeric(df[[col]]))
    ok <- is.finite(v)
    if (!any(ok)) return(NA_real_)
    if (is.null(w)) mean(v[ok]) else stats::weighted.mean(v[ok], w[ok])
  }, numeric(1))
  attr(out, "weighting") <- applied
  out
}
