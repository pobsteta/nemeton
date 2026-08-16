# indicators-risk.R
# Risk & Resilience Family (R) Indicators
# Aligned with tuto 03 methodology (fireexposuR, microclima, SPEI)

#' @importFrom terra terrain extract rasterize global clamp
#' @importFrom sf st_centroid st_distance st_transform st_coordinates
#' @importFrom stats median weighted.mean ts
#' @importFrom utils getFromNamespace
#' @keywords internal
NULL

# ==============================================================================
# T031: R1 - Fire Risk Index
# ==============================================================================

# Borne (m) de la résolution de travail du chemin `fireexposuR`.
#
# `fire_exp()` construit sa fenêtre avec
# `MultiscaleDTM::annulus_window(c(res, t_dist), "map", res)` puis
# `terra::focal(haz, w, fun = sum)` : la fenêtre est exprimée en mètres mais
# matérialisée en CELLULES, soit ~(2 * t_dist / res)^2 poids par pixel. Le coût
# total varie donc en 1/res^4.
#
#   res = 30 m : fenêtre 33 x 33 (~1 100)      -> coût 1x
#   res =  2 m : fenêtre 501 x 501 (~251 000)  -> coût ~52 000x
#
# Le 2026-08-16 sur le projet Fordead (mosaïque lidar_mnt 8000 x 10000 à 0,5 m,
# ramenée à 2 m par .dem_working_res, soit 5 M cellules), R1 tournait depuis plus
# de 75 min à 51 % d'un cœur, sans I/O ni pression mémoire : ~1,25e12 opérations
# mono-thread. fireexposuR est calibré pour du ~30 m (Landsat) ; on borne donc la
# grille du `hazard` indépendamment de `.topo_target_res()`, qui reste à 2 m là
# où il a raison de l'être (R2, R3, W3 sur MNT LiDAR).
.NEMETON_FIRE_EXP_RES <- 30

# MNT ramené à la grille de travail de `fire_exp()`. La grille est au moins
# aussi grossière que la borne feu ET que la résolution topographique de travail,
# mais jamais plus fine que le MNT natif : le `max()` évite de ré-agréger pour
# rien un BD ALTI 25 m (NDP 0) et interdit tout sur-échantillonnage. On part du
# MNT natif plutôt que du MNT déjà ramené à 2 m : une seule agrégation
# (0,5 m -> 30 m) au lieu de deux, sur des dizaines de millions de cellules.
# `fire_exp_res = NULL` retombe sur `dem_target_res`, soit le comportement
# d'avant la borne ; les deux à NULL gardent la résolution native.
.fire_exp_working_dem <- function(dem, fire_exp_res = .NEMETON_FIRE_EXP_RES,
                                  dem_target_res = .topo_target_res()) {
  if (is.null(dem) || !inherits(dem, "SpatRaster")) return(dem)
  bounds <- c(fire_exp_res, dem_target_res)
  bounds <- bounds[is.finite(bounds) & bounds > 0]
  if (length(bounds) == 0L) return(dem)
  cur <- terra::res(dem)[1]
  target <- max(bounds, if (is.finite(cur)) cur else numeric(0))
  .dem_working_res(dem, target_res = target, context = "R1/fire_exp")
}

# --- Composantes partagées entre le chemin fireexposuR et le repli ------------
#
# Les deux chemins de R1 lisent la même pente et la même sécheresse climatique.
# Le chemin fireexposuR les tire de la grille du `hazard` (30 m) : c'est la
# résolution à laquelle les modèles de propagation raisonnent, et la pente d'un
# MNT LiDAR à 2 m décrit surtout des cloisonnements et des fossés — de la
# micro-topographie qui n'est pas la pente que remonte un front de feu.

.r1_slope_factor <- function(dem, units) {
  if (is.null(dem) || !inherits(dem, "SpatRaster")) return(NULL)
  slope_raster <- tryCatch(
    terra::terrain(dem, v = "slope", unit = "degrees"),
    error = function(e) NULL
  )
  if (is.null(slope_raster)) return(NULL)
  slope_values <- safe_extract(slope_raster,
    as_pure_sf(units), fun = "mean", progress = FALSE)
  # 30 degres et au-dela : facteur maximal (le feu remonte la pente).
  pmin(slope_values / 30, 1) * 100
}

.r1_climate_factor <- function(climate, units) {
  if (is.null(climate) ||
      !all(c("temperature", "precipitation") %in% names(climate))) {
    return(NULL)
  }
  # `safe_extract` et non `terra::extract` : les rasters climatiques arrivent en
  # EPSG:4326 (WorldClim) quand les unites peuvent etre en Lambert-93, et un
  # desaccord de CRS y passait jusqu ici sans bruit (meme famille de bug que la
  # BD Foret non reprojetee, cf. safe_rasterize).
  temp_values <- safe_extract(climate$temperature,
    as_pure_sf(units), fun = "mean", progress = FALSE)
  precip_values <- safe_extract(climate$precipitation,
    as_pure_sf(units), fun = "mean", progress = FALSE)
  temp_norm <- pmin(pmax((temp_values - 8) / 8, 0), 1) * 100
  precip_norm <- pmin(pmax((1400 - precip_values) / 900, 0), 1) * 100
  (temp_norm + precip_norm) / 2
}

# Somme ponderee des composantes disponibles. Une composante absente (NULL) sort
# du calcul et son poids est redistribue au prorata sur les autres, plutot que
# d etre remplace par un 50 arbitraire : ne pas savoir n est pas « moyen ».
.r1_weighted_score <- function(components, weights) {
  present <- names(components)[!vapply(components, is.null, logical(1))]
  w <- weights[intersect(names(weights), present)]
  w <- w[is.finite(w) & w > 0]
  if (length(w) == 0L) return(NULL)
  w <- w / sum(w)
  score <- Reduce(`+`, lapply(names(w), function(k) w[[k]] * components[[k]]))
  list(score = pmin(pmax(score, 0), 100), weights = w)
}

#' Calculate Fire Risk Index (R1)
#'
#' Computes fire risk using fire exposure analysis from BD Foret fuel mapping
#' (via \pkg{fireexposuR}). Falls back to slope + species + climate method
#' when \pkg{fireexposuR} or BD Foret data is unavailable.
#'
#' @param units An sf object with forest parcels.
#' @param dem A SpatRaster with digital elevation model (meters).
#' @param layers A nemeton_layers object. Used to extract DEM and BD Foret.
#' @param bdforet An sf object with BD Foret V2 polygons, or NULL.
#' @param species_field Character. Column name with species names (fallback only).
#' @param climate List with 'temperature' and 'precipitation' SpatRasters,
#'   or NULL (fallback only).
#' @param weights Named numeric vector. Weights for fallback components:
#'   c(slope, species, climate). Default c(1/3, 1/3, 1/3).
#' @param dem_target_res Numeric. Working resolution (metres) the DEM is
#'   aggregated to before terrain derivatives are computed. A LiDAR HD MNT
#'   comes at 0.5-1 m, i.e. hundreds of millions of cells per derived layer over a
#'   whole massif, for an index that is averaged per unit anyway. Default: the
#'   package-wide topographic working resolution, 2 m — see
#'   \code{options("nemeton.topo_target_res")}; \code{NULL} keeps the native
#'   resolution. Never upsamples, and is a no-op on a lon/lat DEM.
#' @param fire_exp_res Numeric. Upper bound (metres) on the working resolution
#'   of the \pkg{fireexposuR} path only: the hazard raster handed to
#'   \code{fire_exp()} is aggregated to at least this cell size. Default 30 m,
#'   the Landsat-like resolution \pkg{fireexposuR} is calibrated for. The
#'   fallback method is unaffected and keeps \code{dem_target_res}. Never
#'   upsamples a DEM that is already coarser; \code{NULL} disables the bound.
#' @param fire_exp_weights Named numeric vector weighting the components of the
#'   \pkg{fireexposuR} path: \code{exposure} (fire transmission exposure),
#'   \code{slope} and \code{climate}. Default
#'   \code{c(exposure = 0.5, slope = 0.25, climate = 0.25)}. Exposure alone
#'   saturates near 100 over a continuous forest — every unit has ~all its
#'   500 m neighbourhood burnable — so slope and climatic dryness modulate it,
#'   as in the fallback. A component that cannot be computed (no climate raster)
#'   drops out and its weight is redistributed proportionally.
#'   \code{c(exposure = 1)} restores the raw exposure.
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item R1: Fire risk index (0-100). Higher = higher risk.
#'   }
#'
#' @details
#' **Primary method** (requires \pkg{fireexposuR} + BD Foret):
#' Rasterizes BD Foret as a hazard layer, then computes fire exposure
#' with a 500m transmission distance. The 0-1 exposure is scaled to 0-100.
#' The hazard grid is bounded to \code{fire_exp_res} (30 m) because the
#' annular kernel of \code{fire_exp()} costs \code{(2 * t_dist / res)^2}
#' operations per cell: at 2 m it is ~52 000x the cost at 30 m.
#'
#' **Fallback method**: R1 = w1*slope + w2*species_flammability + w3*climate_dryness
#'
#' @family risk-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#' library(terra)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#'
#' dem <- rast("path/to/dem.tif")
#' result <- indicateur_r1_feu(units, dem = dem)
#' summary(result$R1)
#' }
indicateur_r1_feu <- function(units,
                                dem = NULL,
                                layers = NULL,
                                bdforet = NULL,
                                species_field = "species",
                                climate = NULL,
                                weights = c(slope = 1 / 3, species = 1 / 3, climate = 1 / 3),
                                dem_target_res = .topo_target_res(),
                                fire_exp_res = .NEMETON_FIRE_EXP_RES,
                                fire_exp_weights = c(exposure = 0.5, slope = 0.25,
                                                     climate = 0.25)) {
  # Validate inputs
  validate_sf(units)

  # Extract DEM from layers if not provided directly (prefer LiDAR HD MNT)
  if (is.null(dem) && !is.null(layers)) {
    dem <- get_dem_raster(layers)
  }
  # Répare un CRS LiDAR HD « sans autorité » aussi quand `dem` est fourni
  # directement (le chemin `layers` passe déjà par get_dem_raster).
  dem <- .normalize_crs(dem)

  if (is.null(dem) || !inherits(dem, "SpatRaster")) {
    cli::cli_alert_warning("R1: No DEM available for fire risk, returning NA")
    units$R1 <- rep(NA_real_, nrow(units))
    return(units)
  }

  # Resolve BD Foret from layers if not provided directly
  if (is.null(bdforet) && !is.null(layers)) {
    bdforet <- resolve_vector_layer(layers, "bdforet")
  }

  # --- Primary method: fireexposuR + BD Foret ---
  has_fireexposur <- requireNamespace("fireexposuR", quietly = TRUE)
  if (has_fireexposur && !is.null(bdforet) && inherits(bdforet, "sf") && nrow(bdforet) > 0) {
    tryCatch({
      cli::cli_alert_info("R1: Using fireexposuR with BD For\u00eat hazard layer")
      # Grille du hazard bornée à ~30 m : le noyau annulaire de fire_exp() coûte
      # (2 * t_dist / res)^2 par cellule (cf. .fire_exp_working_dem). Le repli,
      # lui, garde la résolution topographique de travail.
      hazard_dem <- .fire_exp_working_dem(dem, fire_exp_res, dem_target_res)
      # Rasterize BD Foret onto DEM grid: forest = 1 (fuel), non-forest = 0.
      # `safe_rasterize` aligne le CRS : la BD Forêt arrive en EPSG:4326 du WFS
      # IGN quand le MNT LiDAR est en Lambert-93, et `terra::rasterize()` ne
      # reprojette pas — il rend silencieusement un raster tout-à-`background`.
      hazard <- safe_rasterize(bdforet, hazard_dem, field = 1, background = 0)
      # Un `hazard` sans une seule cellule de combustible n'est pas un « risque
      # nul » : c'est une absence de donnée (emprises disjointes, BD Forêt vide).
      # On bascule sur le repli plutôt que de rendre 0 partout — c'est ce qu'a
      # produit le projet Fordead le 2026-08-16, sans le moindre avertissement.
      if (!isTRUE(terra::global(hazard, "max", na.rm = TRUE)[1, 1] > 0)) {
        stop("BD For\u00eat does not overlap the DEM grid (hazard has no fuel cell)")
      }
      # Fire exposure with 500m transmission distance
      exposure <- fireexposuR::fire_exp(hazard, t_dist = 500)
      # Extract mean exposure per parcel (0-1 scale)
      exposure_mean <- safe_extract(exposure,
        as_pure_sf(units), fun = "mean", progress = FALSE)
      exposure_factor <- pmin(pmax(exposure_mean * 100, 0), 100)

      # L'exposition seule sature : sur un massif continu, chaque unité a ~tout
      # son voisinage de 500 m combustible (93 % sur Fordead, R1 = 98,7-100 sur
      # les 30 unités) et l'indicateur ne classe plus rien. On la module par la
      # pente et la sécheresse climatique, comme le repli. La pente est dérivée
      # de la grille du `hazard` : pas de retour au MNT plein format.
      scored <- .r1_weighted_score(
        list(
          exposure = exposure_factor,
          slope    = .r1_slope_factor(hazard_dem, units),
          climate  = .r1_climate_factor(climate, units)
        ),
        fire_exp_weights
      )
      if (is.null(scored)) {
        stop("no usable component for the fire_exp weighting")
      }
      cli::cli_alert_info(
        "R1: fire_exp score = {paste(sprintf('%.2f x %s', scored$weights, names(scored$weights)), collapse = ' + ')}"
      )
      units$R1 <- scored$score
      msg_info("indicateur_r1_feu")
      return(units)
    }, error = function(e) {
      cli::cli_alert_warning("R1: fireexposuR failed ({e$message}), using fallback")
    })
  }

  # --- Fallback method: slope + species + climate ---
  if (!has_fireexposur || is.null(bdforet)) {
    cli::cli_alert_info("R1: Using fallback method (slope + species + climate)")
  }

  # Borne la résolution de travail : un MNT LiDAR HD à 0,5 m ferait dériver la
  # pente sur 120 M cellules pour une moyenne par unité (cf. .dem_working_res).
  # Agrégation faite ici et pas en tête de fonction : quand le chemin
  # fireexposuR aboutit, elle n'a pas lieu d'être payée.
  dem <- .dem_working_res(dem, target_res = dem_target_res, context = "R1")

  # Normalize weights
  weights <- weights / sum(weights)

  # Component 1: Slope factor
  slope_factor <- .r1_slope_factor(dem, units)
  if (is.null(slope_factor)) {
    cli::cli_alert_warning("R1: slope could not be derived, using a neutral value")
    slope_factor <- rep(50, nrow(units))
  }

  # Component 2: Species flammability (or NDVI-based proxy)
  if (species_field %in% names(units)) {
    species <- units[[species_field]]
    species_factor <- get_species_flammability(species)
  } else {
    ndvi_raster_r1 <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
    if (!is.null(ndvi_raster_r1)) {
      ndvi_mean <- safe_extract(ndvi_raster_r1,
        as_pure_sf(units), fun = "mean", progress = FALSE)
      species_factor <- pmax(0, pmin(100, 100 - ndvi_mean * 100))
    } else {
      species_factor <- rep(50, nrow(units))
    }
    weights["slope"] <- weights["slope"] + weights["species"] / 2
    weights["climate"] <- weights["climate"] + weights["species"] / 2
    weights["species"] <- 0
  }

  # Component 3: Climate dryness (if available)
  climate_factor <- .r1_climate_factor(climate, units)
  if (is.null(climate_factor)) {
    climate_factor <- rep(50, nrow(units))
    weights["slope"] <- weights["slope"] + weights["climate"] / 2
    weights["species"] <- weights["species"] + weights["climate"] / 2
    weights["climate"] <- 0
  }

  # Renormalize weights
  total_w <- sum(weights)
  if (total_w > 0) weights <- weights / total_w

  # Composite R1
  units$R1 <- weights["slope"] * slope_factor +
    weights["species"] * species_factor +
    weights["climate"] * climate_factor

  units$R1 <- pmin(pmax(units$R1, 0), 100)
  msg_info("indicateur_r1_feu")
  units
}

# ==============================================================================
# T032: R2 - Storm Vulnerability Index
# ==============================================================================

#' Calculate Storm Vulnerability Index (R2)
#'
#' Computes storm vulnerability using wind shelter coefficient from
#' \pkg{microclima}. Falls back to DEM-derived terrain exposure when
#' \pkg{microclima} is unavailable.
#'
#' When a Canopy Height Model is supplied (spec 005 phase 4), the
#' base terrain score is modulated by a canopy-vulnerability
#' factor \code{f(H_CHM, species)}: tall stands are more
#' vulnerable than short ones, and at equal height conifers are
#' more vulnerable than broadleaves (straighter trunks, shallower
#' roots). The modulation is multiplicative and clamped to
#' \code{[0, 100]}.
#'
#' @param units An sf object with forest parcels.
#' @param dem A SpatRaster with digital elevation model (meters).
#' @param layers A nemeton_layers object. Used to extract DEM if
#'   \code{dem} is NULL.
#' @param chm Optional \code{SpatRaster} of canopy heights in
#'   metres. When supplied, activates CHM mode (spec 005 phase
#'   4).
#' @param species_field Character. Column of \code{units} holding
#'   the species code. Used only in CHM mode. Default
#'   \code{"species"}.
#' @param h_dom_percentile Numeric in \code{[0, 1]}. Percentile
#'   of CHM pixels used for dominant height. Default \code{0.9}.
#' @param h_reference Numeric. Reference height (metres) at which
#'   the canopy-vulnerability factor equals the species baseline.
#'   Default \code{30}.
#' @param dem_target_res Numeric. Working resolution (metres) the DEM is
#'   aggregated to before terrain derivatives are computed. R2 is the heaviest
#'   terrain indicator (nine full-size layers), so a 0.5-1 m LiDAR HD MNT can push
#'   a session into the OOM killer. Default: the package-wide topographic
#'   working resolution, 2 m — see \code{options("nemeton.topo_target_res")};
#'   \code{NULL} keeps the native resolution. Never upsamples, and is a no-op
#'   on a lon/lat DEM.
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item R2: Storm vulnerability (0-100). Higher = more vulnerable.
#'   }
#'
#' @details
#' **Primary method** (requires \pkg{microclima}):
#' Uses \code{microclima::windcoef()} to compute wind shelter coefficient
#' from the DEM. Dominant wind direction is obtained from NASA POWER
#' climatology (\pkg{nasapower}), defaulting to 270 degrees (west) for France.
#' R2 = (1 - shelter_coef) * 100.
#'
#' **Fallback method** (DEM terrain derivatives):
#' Combines aspect-wind alignment, slope, and terrain ruggedness (TRI):
#' R2 = wind_exposure * (0.6 * slope_norm + 0.4 * TRI_norm) * 100.
#'
#' @family risk-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#' dem <- rast("path/to/dem.tif")
#'
#' result <- indicateur_r2_tempete(units, dem = dem)
#' summary(result$R2)
#' }
indicateur_r2_tempete <- function(units,
                                 dem = NULL,
                                 layers = NULL,
                                 chm = NULL,
                                 species_field = "species",
                                 h_dom_percentile = 0.9,
                                 h_reference = 30,
                                 dem_target_res = .topo_target_res()) {
  # Validate inputs
  validate_sf(units)

  # Extract DEM from layers if not provided directly (prefer LiDAR HD MNT)
  if (is.null(dem) && !is.null(layers)) {
    dem <- get_dem_raster(layers)
  }
  # Répare un CRS LiDAR HD « sans autorité » aussi quand `dem` est fourni
  # directement (le chemin `layers` passe déjà par get_dem_raster).
  dem <- .normalize_crs(dem)
  # R2 est le plus gourmand des indicateurs de terrain : aspect, pente, TRI,
  # l'écart angulaire, son min, puis quatre couches composites — neuf rasters
  # plein format. À 1 m c'est ~10 Go et l'OOM killer (cf. .dem_working_res).
  dem <- .dem_working_res(dem, target_res = dem_target_res, context = "R2")

  if (is.null(dem) || !inherits(dem, "SpatRaster")) {
    cli::cli_alert_warning("R2: No DEM available for storm risk, returning NA")
    units$R2 <- rep(NA_real_, nrow(units))
    return(units)
  }

  # Optional canopy-vulnerability modulation (spec 005 phase 4).
  canopy_factor <- NULL
  if (!is.null(chm)) {
    if (!inherits(chm, "SpatRaster")) {
      stop("chm must be a terra SpatRaster", call. = FALSE)
    }
    h_dom <- extract_h_dom(chm, units, percentile = h_dom_percentile)
    sp    <- if (species_field %in% names(units)) units[[species_field]] else NA
    canopy_factor <- vapply(seq_len(nrow(units)), function(i) {
      h <- h_dom[i]
      if (is.na(h)) return(1)
      species_factor <- if (!is.na(sp[i]) && is_conifer(sp[i])) 1.2 else 0.8
      f <- (h / h_reference) * species_factor
      # Clamp so the modulation stays meaningful: [0.5, 1.5].
      max(0.5, min(1.5, f))
    }, numeric(1))
  }

  # --- Get dominant wind direction (cached) ---

  wind_cache_dir <- if (!is.null(layers)) layers$cache_dir else NULL
  wind_dir <- get_nasapower_wind(units, default_dir = 270, cache_dir = wind_cache_dir)

  # --- Primary method: microclima windcoef (optional, not on CRAN) ---
  has_microclima <- nzchar(suppressWarnings(system.file(package = "microclima")))
  if (has_microclima) {
    tryCatch({
      cli::cli_alert_info("R2: Using microclima windcoef (wind direction = {wind_dir}\u00b0)")
      windcoef_fn <- getFromNamespace("windcoef", "microclima")
      shelter_coef <- windcoef_fn(
        dsm = dem,
        direction = wind_dir,
        hgt = 10,
        reso = terra::res(dem)[1]
      )
      # Vulnerability = 1 - shelter (exposed sites have low shelter)
      r2_raster <- 1 - shelter_coef
      r2_mean <- safe_extract(r2_raster,
        as_pure_sf(units), fun = "mean", progress = FALSE)
      r2_final <- r2_mean * 100
      if (!is.null(canopy_factor)) r2_final <- r2_final * canopy_factor
      units$R2 <- pmin(pmax(r2_final, 0), 100)
      msg_info("indicateur_r2_tempete")
      return(units)
    }, error = function(e) {
      cli::cli_alert_warning("R2: microclima failed ({e$message}), using terrain fallback")
    })
  }

  # --- Fallback method: DEM terrain derivatives ---
  cli::cli_alert_info("R2: Using terrain fallback (aspect + slope + TRI)")

  aspect <- terra::terrain(dem, v = "aspect", unit = "degrees")
  pente <- terra::terrain(dem, v = "slope", unit = "degrees")
  tri <- terra::terrain(dem, v = "TRI")

  # Wind exposure: max when aspect is aligned with wind direction
  diff_angle <- abs(aspect - wind_dir)
  diff_angle <- terra::app(terra::sds(diff_angle, 360 - diff_angle), fun = "min")
  expo_vent <- 1 - (diff_angle / 180)

  # Normalize slope: 0-45 degrees -> 0-1
  pente_norm <- terra::clamp(pente / 45, lower = 0, upper = 1)

  # Normalize TRI
  tri_max <- terra::global(tri, "max", na.rm = TRUE)$max
  if (is.na(tri_max) || tri_max == 0) tri_max <- 1
  tri_norm <- terra::clamp(tri / tri_max, lower = 0, upper = 1)

  # Composite: wind exposure modulated by terrain steepness/roughness
  r2_raster <- expo_vent * (0.6 * pente_norm + 0.4 * tri_norm)

  r2_mean <- safe_extract(r2_raster,
    as_pure_sf(units), fun = "mean", progress = FALSE)
  r2_final <- r2_mean * 100
  if (!is.null(canopy_factor)) r2_final <- r2_final * canopy_factor
  units$R2 <- pmin(pmax(r2_final, 0), 100)
  msg_info("indicateur_r2_tempete")
  units
}

# ==============================================================================
# T033: R3 - Drought Stress Index
# ==============================================================================

#' Calculate Drought Stress Index (R3)
#'
#' Computes drought stress combining a climate component (SPEI-3 index)
#' and a topographic modulation (aspect, slope, TWI). Falls back to
#' topographic-only assessment when \pkg{SPEI} is unavailable.
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object. Used to extract DEM.
#' @param dem A SpatRaster with digital elevation model (meters).
#' @param climate_data Optional list with \code{precip} (monthly precipitation
#'   vector in mm) and \code{temp} (list with \code{tmin} and \code{tmax}
#'   monthly vectors in degrees C). If NULL, uses simulated data.
#' @param snow Optional \code{SpatRaster} of snow-cover duration in
#'   days per year (the Theia \code{theia_snow}
#'   \code{snow_cover_duration} product, loaded via
#'   \code{\link{load_raster_source}}). When supplied, the snowpack
#'   acts as a seasonal water reserve that attenuates drought
#'   stress — see Details. Units with no snow coverage are left
#'   unchanged. Default \code{NULL}.
#' @param snow_relief_strength Numeric in \code{[0, 1]}. Maximum
#'   fractional reduction of R3 applied when the snow-cover
#'   duration reaches the 180-day (6-month) reference. Default
#'   \code{0.3}. Ignored when \code{snow} is \code{NULL}.
#' @param soil_moisture Optional \code{SpatRaster} of surface soil
#'   moisture in \eqn{m^3/m^3} (the Theia \code{theia_soil_moisture}
#'   product, loaded via \code{\link{load_raster_source}}). When
#'   supplied, moist soil attenuates drought stress — see Details.
#'   Default \code{NULL}.
#' @param sm_relief_strength Numeric in \code{[0, 1]}. Maximum
#'   fractional reduction of R3 applied when the soil moisture
#'   reaches the \eqn{0.3\;m^3/m^3} field-capacity reference.
#'   Default \code{0.3}. Ignored when \code{soil_moisture} is
#'   \code{NULL}.
#' @param biljou Optional per-unit soil water-balance metrics from the BILJOU
#'   engine (\code{regen_bilan_hydrique}, spec 027): a \code{data.frame} / list
#'   with numeric columns \code{njstress} (days of hydric stress), \code{istress}
#'   (drought-intensity index) and/or \code{deb_stress} (onset day-of-year).
#'   \code{NULL} (default) → these are read from the same-named columns of
#'   \code{units} when present, else no enrichment. When available, a BILJOU
#'   stress score is blended into R3 (weight \code{biljou_weight}) and the raw
#'   metrics are exposed as columns.
#' @param biljou_weight Numeric in \code{[0, 1]}. Weight of the BILJOU stress
#'   score in the blend with the SPEI/topographic risk. Default \code{0.5}.
#'   Ignored when no BILJOU metric is available.
#' @param dem_target_res Numeric. Working resolution (metres) the DEM is
#'   aggregated to before terrain derivatives and TWI are computed. The same
#'   value drives the TWI grid, so both coincide and the TWI is never resampled
#'   up to a finer grid. Keep it identical across W2/W3/F2/R3 to share a single
#'   cached TWI. Default: the package-wide topographic working resolution, 2 m —
#'   see \code{options("nemeton.topo_target_res")}; \code{NULL} keeps the native
#'   resolution.
#'
#' @return The input sf object with added columns:
#'   \itemize{
#'     \item R3: Drought stress (0-100). Higher = higher stress.
#'     \item r3_njstress, r3_istress, r3_deb_stress: raw BILJOU values
#'       (days / index / day-of-year), when supplied — exposed for
#'       compliance / reporting, not only the score.
#'   }
#'
#' @details
#' **Climate component** (weight 0.6):
#' Uses SPEI-3 (Standardised Precipitation-Evapotranspiration Index at 3-month
#' scale) via \pkg{SPEI}. PET is computed with the Hargreaves method.
#' R3_climat = (-SPEI_recent + 2) / 4, clamped to 0-1.
#' Falls back to 0.5 without \pkg{SPEI}.
#'
#' **Topographic component** (weight 0.4):
#' \itemize{
#'   \item aspect_risk: south-facing = max risk
#'   \item slope_risk: steep slopes = runoff = dry
#'   \item twi_risk: low TWI = dry
#' }
#' topo_risk = 0.4*aspect_risk + 0.3*slope_risk + 0.3*twi_risk
#'
#' R3 = (0.6 * climate + 0.4 * topo) * 100
#'
#' **Snow attenuation** (Theia \code{theia_snow}, optional):
#' when \code{snow} is supplied, the per-unit mean snow-cover
#' duration is rescaled to a 0-1 relief factor against a 180-day
#' reference, and R3 is multiplied by
#' \code{1 - snow_relief_strength * relief}. A forest with a
#' long-lasting snowpack carries a meltwater reserve into the
#' growing season and is therefore less drought-stressed.
#'
#' **Soil-moisture attenuation** (Theia \code{theia_soil_moisture},
#' optional): when \code{soil_moisture} is supplied, the per-unit
#' mean surface soil moisture is rescaled to a 0-1 relief factor
#' against the \eqn{0.3\;m^3/m^3} field-capacity reference, and
#' R3 is multiplied by \code{1 - sm_relief_strength * relief}.
#' Moist soil buffers drought stress.
#'
#' @family risk-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#' dem <- rast("path/to/dem.tif")
#'
#' result <- indicateur_r3_secheresse(units, dem = dem)
#' summary(result$R3)
#' }
# BILJOU stress normalisation bounds (spec 027). Documented, revisable on
# BILJOU calibration (§9.2); consistent with .REGEN_STRESS_BOUNDS.
.R3_BILJOU_BOUNDS <- list(njstress = c(lo = 0, hi = 60),   # days
                          istress  = c(lo = 0, hi = 50))   # intensity index

# Resolve BILJOU per-unit metrics from `biljou` (data.frame/list) or, failing
# that, from same-named columns of `units`. Returns a named list of numeric
# vectors (length nrow(units)) for the metrics found, or NULL if none.
.r3_resolve_biljou <- function(biljou, units) {
  n <- nrow(units)
  pick <- function(nm) {
    v <- NULL
    if (!is.null(biljou) && (is.data.frame(biljou) || is.list(biljou)))
      v <- biljou[[nm]]
    if (is.null(v) && nm %in% names(units)) v <- units[[nm]]
    if (is.null(v)) return(NULL)
    rep(as.numeric(v), length.out = n)
  }
  out <- list(njstress = pick("njstress"), istress = pick("istress"),
              deb_stress = pick("deb_stress"))
  if (all(vapply(out, is.null, logical(1)))) return(NULL)
  out
}

# BILJOU stress score 0-100 (high = more stress), renormalised mean of the
# available njstress / istress components. NULL if neither is present.
.r3_biljou_stress <- function(b) {
  comps <- list()
  if (!is.null(b$njstress)) {
    bd <- .R3_BILJOU_BOUNDS$njstress
    comps$nj <- 100 * pmin(1, pmax(0, (b$njstress - bd[["lo"]]) / (bd[["hi"]] - bd[["lo"]])))
  }
  if (!is.null(b$istress)) {
    bd <- .R3_BILJOU_BOUNDS$istress
    comps$is <- 100 * pmin(1, pmax(0, (b$istress - bd[["lo"]]) / (bd[["hi"]] - bd[["lo"]])))
  }
  if (!length(comps)) return(NULL)
  mat <- matrix(unlist(comps), ncol = length(comps))
  s <- rowMeans(mat, na.rm = TRUE)
  s[is.nan(s)] <- NA_real_
  s
}

# Attach the raw BILJOU metrics to `units` (exposed for compliance, §5.1).
.r3_expose_biljou <- function(units, b) {
  if (!is.null(b$njstress))   units$r3_njstress   <- b$njstress
  if (!is.null(b$istress))    units$r3_istress    <- b$istress
  if (!is.null(b$deb_stress)) units$r3_deb_stress <- b$deb_stress
  units
}

indicateur_r3_secheresse <- function(units,
                                   layers = NULL,
                                   dem = NULL,
                                   climate_data = NULL,
                                   snow = NULL,
                                   snow_relief_strength = 0.3,
                                   soil_moisture = NULL,
                                   sm_relief_strength = 0.3,
                                   biljou = NULL,
                                   biljou_weight = 0.5,
                                   dem_target_res = .topo_target_res()) {
  # Validate inputs
  validate_sf(units)

  # Resolve optional BILJOU water-balance metrics (spec 027 enrichment).
  biljou_m <- .r3_resolve_biljou(biljou, units)
  biljou_score <- if (!is.null(biljou_m)) .r3_biljou_stress(biljou_m) else NULL

  # Extract DEM from layers if not provided directly
  if (is.null(dem) && !is.null(layers)) {
    dem <- get_dem_raster(layers)
  }
  # Répare un CRS LiDAR HD « sans autorité » aussi quand `dem` est fourni
  # directement (le chemin `layers` passe déjà par get_dem_raster).
  dem <- .normalize_crs(dem)
  # Même résolution de travail que W2/W3/F2 : le TWI est mis en cache sur
  # l'empreinte du DEM reçu, les quatre consommateurs doivent partager la même
  # grille sous peine de recalculer un TWI par indicateur.
  dem <- .dem_working_res(dem, target_res = dem_target_res, context = "R3")

  if (is.null(dem) || !inherits(dem, "SpatRaster")) {
    if (!is.null(biljou_score)) {
      # No DEM but BILJOU available: R3 from the mechanistic water balance alone.
      cli::cli_alert_info("R3: no DEM; drought stress from BILJOU metrics alone (spec 027).")
      units$R3 <- pmin(pmax(biljou_score, 0), 100)
      return(.r3_expose_biljou(units, biljou_m))
    }
    cli::cli_alert_warning("R3: No DEM available for drought risk, returning NA")
    units$R3 <- rep(NA_real_, nrow(units))
    return(units)
  }

  # --- Component 1: Climate SPEI (weight 0.6) ---
  r3_climat <- 0.5  # Default scalar fallback

  if (requireNamespace("SPEI", quietly = TRUE)) {
    tryCatch({
      # Get latitude for Hargreaves PET
      centroid <- suppressWarnings(sf::st_centroid(sf::st_union(units)))
      coords <- sf::st_coordinates(sf::st_transform(centroid, 4326))
      lat_mean <- coords[1, 2]

      if (!is.null(climate_data) &&
          !is.null(climate_data$precip) &&
          !is.null(climate_data$temp)) {
        # Use provided monthly data
        precip <- climate_data$precip
        tmin <- climate_data$temp$tmin
        tmax <- climate_data$temp$tmax
      } else {
        # Simulated data (same as tuto 03) - representative Mediterranean/continental
        cli::cli_alert_info("R3: Using simulated climate data for SPEI")
        set.seed(42)
        n_months <- 60  # 5 years
        # Monthly precipitation pattern (dry summers)
        base_precip <- rep(c(60, 55, 50, 45, 50, 30, 20, 25, 40, 55, 65, 70), length.out = n_months)
        precip <- pmax(0, base_precip + stats::rnorm(n_months, 0, 15))
        # Temperature pattern
        base_tmax <- rep(c(8, 10, 14, 18, 22, 27, 30, 29, 24, 18, 12, 8), length.out = n_months)
        base_tmin <- rep(c(0, 1, 4, 7, 11, 15, 18, 17, 13, 8, 4, 1), length.out = n_months)
        tmax <- base_tmax + stats::rnorm(n_months, 0, 2)
        tmin <- base_tmin + stats::rnorm(n_months, 0, 2)
      }

      # Compute PET with Hargreaves
      utils::capture.output(
        pet <- SPEI::hargreaves(Tmin = tmin, Tmax = tmax, lat = lat_mean),
        type = "output"
      )
      # SPEI-3
      bal <- precip - as.numeric(pet)
      utils::capture.output(
        spei_result <- SPEI::spei(ts(bal, frequency = 12), scale = 3),
        type = "output"
      )
      spei_vals <- as.numeric(spei_result$fitted)
      # Use most recent valid SPEI value
      valid_spei <- spei_vals[!is.na(spei_vals) & is.finite(spei_vals)]
      if (length(valid_spei) > 0) {
        spei_recent <- utils::tail(valid_spei, 1)
        # Convert SPEI to risk: SPEI -2 = max risk (1), SPEI +2 = no risk (0)
        r3_climat <- max(0, min(1, (-spei_recent + 2) / 4))
        cli::cli_alert_info("R3: SPEI-3 = {round(spei_recent, 2)}, climate risk = {round(r3_climat, 2)}")
      }
    }, error = function(e) {
      cli::cli_alert_warning("R3: SPEI computation failed ({e$message}), using default 0.5")
    })
  } else {
    cli::cli_alert_info("R3: SPEI package not available, using default climate risk 0.5")
  }

  # --- Component 2: Topographic modulation (weight 0.4) ---
  aspect <- terra::terrain(dem, v = "aspect", unit = "degrees")
  pente <- terra::terrain(dem, v = "slope", unit = "degrees")

  # Aspect risk: south-facing (180°) = max drought risk.
  # Écrit en une passe : `(1 + cos((aspect - 180) * pi/180)) / 2` matérialise
  # quatre SpatRaster temporaires pleine taille dans la même expression — le pic
  # mémoire de R3 (2,44 -> 8,70 Go sur le MNT 0,5 m de Dabo) venait de là.
  # `terra::app()` streame par blocs et ne rend qu'un raster.
  aspect_risk <- terra::app(aspect, function(a) (1 + cos((a - 180) * pi / 180)) / 2)

  # Slope risk: steep slopes = more runoff = drier
  pente_risk <- terra::clamp(pente / 30, lower = 0, upper = 1)

  # TWI risk: low TWI = dry.
  # `twi_target_res` suit la résolution de travail : le TWI sort sur la grille
  # de `dem`, donc sur celle d'`aspect`, et la branche `resample` ci-dessous
  # n'est plus empruntée. La laisser à 10 aurait rééchantillonné un TWI
  # grossier vers la grille fine — coûteux et sans information ajoutée.
  twi_cache_dir <- if (!is.null(layers)) layers$cache_dir else NULL
  twi_raster <- get_or_compute_twi(dem, cache_dir = twi_cache_dir,
                                   twi_target_res = dem_target_res)

  # Filet de sécurité : un TWI GRASS ou un cache d'une version antérieure peut
  # encore arriver sur une autre grille.
  if (!terra::compareGeom(twi_raster, aspect, stopOnError = FALSE)) {
    twi_raster <- terra::resample(twi_raster, aspect, method = "bilinear")
  }

  twi_max <- terra::global(twi_raster, "max", na.rm = TRUE)$max
  if (is.na(twi_max) || twi_max == 0) twi_max <- 1
  twi_norm <- terra::clamp(twi_raster / twi_max, lower = 0, upper = 1)
  twi_risk <- 1 - twi_norm

  # Composite topographic risk
  topo_risk <- 0.4 * aspect_risk + 0.3 * pente_risk + 0.3 * twi_risk

  # --- Final R3: climate (0.6) + topo (0.4) ---
  # r3_climat is a scalar, topo_risk is a raster
  r3_raster <- 0.6 * r3_climat + 0.4 * topo_risk

  r3_mean <- safe_extract(r3_raster,
    as_pure_sf(units), fun = "mean", progress = FALSE)
  r3_score <- pmin(pmax(r3_mean * 100, 0), 100)

  # --- BILJOU soil-water-balance enrichment (spec 027 §5.1) ---
  # A direct, mechanistic drought signal refines the SPEI/topo proxy: blend it
  # in (weight biljou_weight, bidirectional), and expose the raw metrics. Per
  # unit, only where the BILJOU score is available (NA -> keep the proxy).
  if (!is.null(biljou_score)) {
    cli::cli_alert_info("R3: drought risk refined by BILJOU water balance (spec 027).")
    w <- pmin(pmax(biljou_weight, 0), 1)
    # Per unit: blend where both are available; fall back to whichever exists
    # (a NA proxy must not poison the blend — 0 * NaN is NaN in R).
    blended <- ifelse(is.na(r3_score), biljou_score,
                      (1 - w) * r3_score + w * biljou_score)
    r3_score <- ifelse(is.na(biljou_score), r3_score,
                       pmin(pmax(blended, 0), 100))
    units <- .r3_expose_biljou(units, biljou_m)
  }

  # --- Snow attenuation (Theia theia_snow, phase 3c) ---
  if (!is.null(snow)) {
    if (!inherits(snow, "SpatRaster")) {
      stop("snow must be a terra SpatRaster", call. = FALSE)
    }
    cli::cli_alert_info("R3: drought stress attenuated by snowpack (Theia theia_snow)")
    snow_days <- safe_extract(snow,
      as_pure_sf(units), fun = "mean", progress = FALSE)
    # Relief 0-1 against a 180-day (6-month) reference snowpack;
    # units with no snow coverage (NA) get no attenuation.
    relief <- pmin(pmax(snow_days / 180, 0), 1)
    relief[is.na(relief)] <- 0
    attenuation <- 1 - snow_relief_strength * relief
    r3_score <- pmin(pmax(r3_score * attenuation, 0), 100)
  }

  # --- Soil-moisture attenuation (Theia theia_soil_moisture, phase 3d) ---
  if (!is.null(soil_moisture)) {
    if (!inherits(soil_moisture, "SpatRaster")) {
      stop("soil_moisture must be a terra SpatRaster", call. = FALSE)
    }
    cli::cli_alert_info("R3: drought stress attenuated by soil moisture (Theia theia_soil_moisture)")
    sm_vals <- safe_extract(soil_moisture,
      as_pure_sf(units), fun = "mean", progress = FALSE)
    # Relief 0-1 against a 0.3 m3/m3 field-capacity reference;
    # units with no coverage (NA) get no attenuation.
    sm_relief <- pmin(pmax(sm_vals / 0.3, 0), 1)
    sm_relief[is.na(sm_relief)] <- 0
    r3_score <- pmin(pmax(r3_score * (1 - sm_relief_strength * sm_relief), 0), 100)
  }

  units$R3 <- r3_score

  msg_info("indicateur_r3_secheresse")
  units
}

# ==============================================================================
# T034: R4 - Game Browsing Pressure Index
# ==============================================================================

#' Calculate Game Browsing Pressure Index (R4)
#'
#' Computes browsing pressure risk from ungulates (deer, wild boar) based on
#' species palatability from BD Foret, stand vulnerability from LiDAR,
#' edge exposure, and local game density from hunting statistics.
#'
#' Aligned with tuto 03 methodology: BD Foret intersection for palatability,
#' LiDAR MNH for vulnerability, hunting data (data.gouv.fr) for density.
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object. Used to extract BD Foret and LiDAR MNH.
#' @param bdforet An sf object with BD Foret V2 polygons, or NULL (resolved from layers).
#' @param game_density SpatRaster with game density index (0-100), or NULL
#'   (auto-computed from hunting data if available).
#' @param edge_buffer Numeric. Buffer distance (m) for edge effect calculation.
#'   Default 50.
#'
#' @return The input sf object with added columns:
#'   \itemize{
#'     \item R4: Browsing pressure risk (0-100). Higher = higher risk.
#'     \item R4_palatability: Species palatability score (0-100).
#'     \item R4_vulnerability: Stand vulnerability score (0-100).
#'   }
#'
#' @details
#' **Formula**: R4 = 0.35*palatability + 0.30*vulnerability + 0.20*edge + 0.15*density
#'
#' **Components**:
#' \itemize{
#'   \item palatability: From BD Foret species intersection (pattern matching on
#'     essence names). Quercus=90, Abies=85, Fagus=70, Pinus=30.
#'   \item vulnerability: From LiDAR MNH mean height per parcel.
#'     <2m = 100, 2-10m = decreasing, >10m = 0.
#'   \item edge_exposure: Proportion of parcel within buffer of forest edge.
#'   \item game_density: From departmental hunting harvest statistics
#'     (data.gouv.fr, OFB). Auto-fetched via \code{\link{get_game_pressure_raster}}.
#' }
#'
#' @family risk-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#'
#' result <- indicateur_r4_abroutissement(units)
#' summary(result$R4)
#' }
indicateur_r4_abroutissement <- function(units,
                                    layers = NULL,
                                    bdforet = NULL,
                                    game_density = NULL,
                                    edge_buffer = 50) {
  # Validate inputs
  validate_sf(units)

  # Fixed weights from tuto 03
  w_palatability <- 0.35
  w_vulnerability <- 0.30
  w_edge <- 0.20
  w_density <- 0.15

  n_units <- nrow(units)

  # Resolve BD Foret from layers if not provided
  if (is.null(bdforet) && !is.null(layers)) {
    bdforet <- resolve_vector_layer(layers, "bdforet")
  }

  # ==========================================================================
  # Component 1: Palatability from BD Foret intersection (tuto 03 method)
  # ==========================================================================
  palatability_factor <- rep(50, n_units)  # Default

  if (!is.null(bdforet) && inherits(bdforet, "sf") && nrow(bdforet) > 0) {
    cli::cli_alert_info("R4: Computing palatability from BD For\u00eat intersection")

    # Find species/essence column in BD Foret
    essence_col <- NULL
    for (col in c("essence", "tfv", "libelle", "code_tfv",
                  "TFV", "ESSENCE", "LIB_FV", "LIBELLE")) {
      if (col %in% names(bdforet)) {
        essence_col <- col
        break
      }
    }

    if (!is.null(essence_col)) {
      bdforet_proj <- sf::st_transform(bdforet, sf::st_crs(units))

      for (i in seq_len(n_units)) {
        inter <- tryCatch({
          suppressWarnings(sf::st_intersection(bdforet_proj, sf::st_geometry(units)[i]))
        }, error = function(e) NULL)

        if (!is.null(inter) && nrow(inter) > 0) {
          essence <- tolower(as.character(inter[[essence_col]][1]))
          # Use get_species_palatability for pattern matching
          score <- get_species_palatability(essence)
          if (!is.na(score)) {
            palatability_factor[i] <- score
          }
        }
      }
    }
  } else {
    cli::cli_alert_info("R4: No BD For\u00eat data, using default palatability 50")
  }
  units$R4_palatability <- palatability_factor

  # ==========================================================================
  # Component 2: Vulnerability from LiDAR MNH (tuto 03 method)
  # ==========================================================================
  vulnerability_factor <- rep(50, n_units)  # Default

  mnh_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "lidar_mnh") else NULL

  if (!is.null(mnh_raster)) {
    cli::cli_alert_info("R4: Computing vulnerability from LiDAR MNH")
    mnh_mean <- safe_extract(mnh_raster,
      as_pure_sf(units), fun = "mean", progress = FALSE)
    # Tuto formula: (10 - zmean) / 8 * 100
    vulnerability_factor <- pmax(0, pmin(100, (10 - mnh_mean) / 8 * 100))
  } else {
    cli::cli_alert_info("R4: No LiDAR MNH, using default vulnerability 50")
  }
  units$R4_vulnerability <- vulnerability_factor

  # ==========================================================================
  # Component 3: Edge exposure (same as tuto 03)
  # ==========================================================================
  # Project to metric CRS if needed (st_buffer requires meters, not degrees)
  units_proj <- units
  if (sf::st_is_longlat(units)) {
    units_proj <- sf::st_transform(units, 2154)
  }

  edge_factor <- numeric(n_units)

  for (i in seq_len(n_units)) {
    geom <- sf::st_geometry(units_proj)[i]
    area_total <- as.numeric(sf::st_area(geom))

    if (area_total > 0) {
      inner <- tryCatch({
        sf::st_buffer(geom, -edge_buffer)
      }, error = function(e) NULL)

      if (!is.null(inner) && !sf::st_is_empty(inner)) {
        area_inner <- as.numeric(sf::st_area(inner))
        edge_proportion <- (area_total - area_inner) / area_total
      } else {
        edge_proportion <- 1
      }

      edge_factor[i] <- edge_proportion * 100
    } else {
      edge_factor[i] <- 100
    }
  }

  # ==========================================================================
  # Component 4: Game density (tuto 03: hunting data from data.gouv.fr)
  # ==========================================================================
  density_factor <- rep(50, n_units)  # Default

  if (!is.null(game_density) && inherits(game_density, "SpatRaster")) {
    # Use provided raster
    density_values <- terra::extract(game_density, units, fun = mean, na.rm = TRUE, ID = FALSE)[, 1]
    density_values[is.na(density_values) | is.nan(density_values)] <- 50
    density_factor <- pmin(pmax(density_values, 0), 100)
    cli::cli_alert_info("R4: Using provided game density raster")
  } else {
    # Try auto-fetch from hunting data (tuto 03 method)
    tryCatch({
      game_raster <- get_game_pressure_raster(units)
      if (!is.null(game_raster) && inherits(game_raster, "SpatRaster")) {
        # Match CRS to avoid terra extract warning
        units_ext <- sf::st_transform(units, terra::crs(game_raster))
        density_values <- terra::extract(game_raster, units_ext, fun = mean, na.rm = TRUE, ID = FALSE)[, 1]
        density_values[is.na(density_values) | is.nan(density_values)] <- 50
        density_factor <- pmin(pmax(density_values, 0), 100)
        cli::cli_alert_info("R4: Game density computed from hunting data (data.gouv.fr)")
      }
    }, error = function(e) {
      cli::cli_alert_info("R4: Could not fetch hunting data ({e$message}), using default density 50")
    })
  }

  # ==========================================================================
  # Composite R4 (fixed weights from tuto 03)
  # ==========================================================================
  units$R4 <- w_palatability * palatability_factor +
    w_vulnerability * vulnerability_factor +
    w_edge * edge_factor +
    w_density * density_factor

  # Cap at 0-100
  units$R4 <- pmin(pmax(units$R4, 0), 100)

  msg_info("indicateur_r4_abroutissement")

  units
}
