# indicators-biodiversity.R
# Biodiversity Family (B) Indicators
# MVP v0.3.0 - Multi-Family Indicator Extension

#' @importFrom sf st_sf st_sfc st_crs st_transform st_area st_intersects st_intersection st_distance st_centroid
#' @importFrom stats median
#' @keywords internal
NULL

# ==============================================================================
# T019: B1 - Protected Area Coverage
# ==============================================================================

# Borne absolue du nombre de statuts de protection superposes (B1) :
# empilement courant en France = ZNIEFF 1 + ZNIEFF 2 + Natura 2000 + parc ou
# reserve. Au-dela, le sous-score est plafonne a 100.
B1_NB_STATUTS_MAX <- 4L

#' Calculate Protected Area Coverage (B1)
#'
#' Computes the percentage of each forest parcel covered by designated protected
#' areas (ZNIEFF, Natura2000, National/Regional Parks).
#'
#' @param units An sf object with forest parcels (POLYGON or MULTIPOLYGON).
#' @param protected_areas An sf object with protected area polygons. If NULL and
#'   source="wfs", will attempt to fetch from INPN WFS service.
#' @param source Character. Data source: "local" (use protected_areas parameter)
#'   or "wfs" (fetch from INPN). Default "local".
#' @param protection_types Character vector. Types of protected areas to include
#'   when using WFS. Default c("ZNIEFF1", "ZNIEFF2", "N2000_SCI").
#' @param preprocess Logical. If TRUE, harmonize CRS automatically. Default TRUE.
#'
#' @return The input sf object with added columns:
#'   \itemize{
#'     \item B1: protection score (0-100)
#'     \item B1_pct: weighted protected coverage of the parcel (0-100)
#'     \item B1_nb: number of distinct protection statuses intersecting
#'       the parcel
#'   }
#'
#' @details
#' **Calculation**: with a protection-type column (`type_protection`,
#' `zone_type`, `type` or `statut`),
#' B1 = 0.7 * B1_pct + 0.3 * min(B1_nb, 4) / 4 * 100, where B1_pct is the
#' coverage of each status averaged with weights by protection strength
#' (strong 1.0, medium 0.6, weak 0.3, unknown 0.5). The number of statuses is
#' scaled by a fixed bound of 4 stacked statuses (ZNIEFF 1 + ZNIEFF 2 +
#' Natura 2000 + park/reserve), so the score of a parcel does not depend on
#' the other parcels of the batch. Without a type column, B1 = B1_pct
#' (plain coverage; the number of statuses is unknown).
#'
#' A NULL `protected_areas` gives NA (no measurement; the `"wfs"` source is
#' not fetched by this function); an empty `protected_areas` gives 0.
#'
#' **Interpretation**: Higher values indicate better protection status.
#'
#' @family biodiversity-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#' library(sf)
#'
#' # Load demo data
#' data(massif_demo_units)
#'
#' # Option A: Use local protected area data
#' protected_zones <- st_read("path/to/protected_areas.shp")
#' result <- indicateur_b1_protection(
#'   massif_demo_units,
#'   protected_areas = protected_zones,
#'   source = "local"
#' )
#'
#' # Option B: Fetch from INPN WFS (requires internet)
#' result <- indicateur_b1_protection(
#'   massif_demo_units,
#'   source = "wfs",
#'   protection_types = c("ZNIEFF1", "ZNIEFF2", "N2000_SCI")
#' )
#'
#' # View results
#' summary(result$B1)
#' }
indicateur_b1_protection <- function(units,
                                              protected_areas = NULL,
                                              source = c("local", "wfs"),
                                              protection_types = c("ZNIEFF1", "ZNIEFF2", "N2000_SCI"),
                                              preprocess = TRUE) {
  # Validate inputs
  validate_sf(units)
  source <- match.arg(source)

  # Absent input is NOT a measurement.
  #
  # `0` says "we looked, nothing protects this unit". `NA` says "we could not
  # look". They do not weigh the same downstream: `create_family_index()`
  # averages with `na.rm = TRUE`, so a fabricated 0 drags the Biodiversity
  # score down while an honest NA steps aside.
  #
  # Both branches used to fabricate that 0 — the local one openly ("setting
  # coverage to 0%"), the WFS one by building an EMPTY dataset when the INPN
  # fetch is unavailable, which then reads exactly like a successful query that
  # found nothing. Converting "I could not ask" into "I asked and there is
  # none" is the defect this guard removes.
  #
  # A protected_areas WITH ZERO ROWS, supplied by the caller, keeps returning
  # 0: that one IS a measurement.
  if (is.null(protected_areas)) {
    if (source == "wfs") {
      msg_info("biodiversity_wfs_fetching")
      msg_warn("biodiversity_wfs_failed")
      cli::cli_alert_info(
        "B1: INPN WFS fetch unavailable, returning NA (no measurement made)."
      )
    } else {
      cli::cli_alert_info(
        "B1: no protected-areas data provided, returning NA (no measurement made)."
      )
    }
    units$B1 <- rep(NA_real_, nrow(units))
    return(units)
  }

  # Preprocess: harmonize CRS
  if (preprocess && !sf::st_crs(units) == sf::st_crs(protected_areas)) {
    protected_areas <- sf::st_transform(protected_areas, sf::st_crs(units))
  }

  # Initialize columns
  units$B1 <- numeric(nrow(units))

  if (nrow(protected_areas) == 0) {
    msg_info("indicateur_b1_protection")
    return(units)
  }

  # Detect protection type column (tutorial uses type_protection, fixture uses zone_type)
  type_col <- NULL
  for (candidate in c("type_protection", "zone_type", "type", "statut")) {
    if (candidate %in% names(protected_areas)) {
      type_col <- candidate
      break
    }
  }

  # Protection level weights — stronger protections count more
  # Level 3 (strong): reserves, national park cores, APB
  # Level 2 (medium): Natura 2000, ZNIEFF1
  # Level 1 (weak/informational): PNR, Ramsar, ZNIEFF2
  protection_weights <- c(
    # Strong protection (weight 1.0)
    "rnn" = 1.0, "rnr" = 1.0, "apb" = 1.0, "rb" = 1.0, "rncfs" = 1.0,
    "pn" = 1.0, "coeur" = 1.0,
    # Medium protection (weight 0.6)
    "sic" = 0.6, "zps" = 0.6, "zsc" = 0.6, "natura" = 0.6,
    "znieff1" = 0.6,
    # Weak/informational (weight 0.3)
    "pnr" = 0.3, "ramsar" = 0.3, "pnm" = 0.3,
    "znieff2" = 0.3
  )

  # Function to get weight for a zone type string
  get_protection_weight <- function(type_str) {
    type_lower <- tolower(type_str)
    for (key in names(protection_weights)) {
      if (grepl(key, type_lower, fixed = TRUE)) {
        return(protection_weights[[key]])
      }
    }
    0.5  # default for unknown types
  }

  pa_valid <- sf::st_make_valid(protected_areas)

  for (i in seq_len(nrow(units))) {
    parcel <- sf::st_make_valid(units[i, ])
    parcel_area <- as.numeric(sf::st_area(parcel))

    if (is.null(type_col)) {
      # No type column: simple coverage with default weight
      pa_union <- tryCatch(sf::st_union(pa_valid), error = function(e) sf::st_geometry(pa_valid))
      inter <- tryCatch(sf::st_intersection(pa_union, sf::st_geometry(parcel)), error = function(e) NULL)
      pct <- 0
      if (!is.null(inter) && length(inter) > 0 && !all(sf::st_is_empty(inter))) {
        pct <- min(100, as.numeric(sum(sf::st_area(inter))) / parcel_area * 100)
      }
      # Sans type : la couverture seule (le nombre de statuts est inconnu)
      units$B1[i] <- pct
      units$B1_pct[i] <- pct
      units$B1_nb[i] <- 0L
      next
    }

    # Compute weighted coverage per protection type
    types <- unique(pa_valid[[type_col]])
    weighted_score <- 0
    weight_sum <- 0
    nb_types <- 0

    for (tp in types) {
      zones_tp <- pa_valid[pa_valid[[type_col]] == tp, ]
      zones_union <- tryCatch(sf::st_union(sf::st_make_valid(zones_tp)),
                              error = function(e) sf::st_geometry(zones_tp))
      inter <- tryCatch(sf::st_intersection(zones_union, sf::st_geometry(parcel)),
                        error = function(e) NULL)

      if (!is.null(inter) && length(inter) > 0 && !all(sf::st_is_empty(inter))) {
        coverage <- min(1, as.numeric(sum(sf::st_area(inter))) / parcel_area)
        weight <- get_protection_weight(tp)
        weighted_score <- weighted_score + coverage * weight
        weight_sum <- weight_sum + weight
        nb_types <- nb_types + 1
      }
    }

    # B1_pct: weighted average coverage (normalized by sum of weights)
    # A parcel 100% covered by one strong protection (w=1.0) scores 100
    # A parcel 100% covered by one weak protection (w=0.3) scores 100
    # A parcel 50% covered by one strong protection scores 50
    units$B1_pct[i] <- if (weight_sum > 0) {
      min(100, weighted_score / weight_sum * 100)
    } else {
      0
    }
    units$B1_nb[i] <- as.integer(nb_types)
  }

  # Score combine : 70 % couverture ponderee + 30 % nombre de statuts.
  # Le nombre de statuts est rapporte a une borne ABSOLUE (B1_NB_STATUTS_MAX),
  # pas au maximum du lot : une unite seule ou un lot homogene ne doit pas
  # obtenir 100 pour un unique statut, et le score d'une unite ne doit pas
  # dependre de ses voisines.
  if (!is.null(type_col)) {
    nb_score <- pmin(units$B1_nb, B1_NB_STATUTS_MAX) / B1_NB_STATUTS_MAX * 100
    units$B1 <- 0.7 * units$B1_pct + 0.3 * nb_score
  }

  # Cap at 100%
  units$B1 <- pmin(units$B1, 100)

  msg_info("indicateur_b1_protection")

  units
}

# ==============================================================================
# T020: B2 - Structural Diversity
# ==============================================================================

#' Calculate Structural Diversity (B2)
#'
#' Computes forest vertical structural diversity from canopy height
#' variability (CHM or LiDAR MNH), or NDVI variability as a fallback.
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object. Used as fallback for structural
#'   diversity estimation via LiDAR MNH or NDVI when strata/age fields are missing.
#' @param strata_field Character. Column name containing canopy strata classes
#'   (e.g., "Emergent", "Dominant", "Intermediate", "Suppressed").
#' @param age_class_field Character. Column name containing age classes
#'   (e.g., "young", "mature", "old", "ancient").
#' @param species_field Character. Optional column name containing species names.
#'   If NULL, species diversity is not included in calculation. Default NULL.
#' @param method Character. Diversity calculation method. Currently only "shannon"
#'   is supported.
#' @param weights Named numeric vector. Weights for strata, age, and species components.
#'   Default c(strata = 0.4, age = 0.3, species = 0.3).
#' @param use_height_cv Logical. If TRUE and strata_field is NULL, use coefficient
#'   of variation of height as proxy for vertical diversity. Default FALSE.
#' @param chm Optional \code{SpatRaster} of canopy heights in
#'   metres. When supplied, the CV(CHM) per unit is computed and
#'   blended into the final B2 score with weight
#'   \code{cv_chm_weight}. If strata/age fields are absent, the
#'   CV(CHM) becomes the primary score (spec 005 phase 4).
#' @param cv_chm_weight Numeric in \code{[0, 1]}. Additive weight
#'   of the CV(CHM) component in the final B2 score. Default
#'   \code{0.2}. Ignored when \code{chm} is \code{NULL}.
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item B2: Structural diversity index (0-100). Higher = more diverse.
#'   }
#'
#' @details
#' **Measure**: vertical structure, in this order of preference — the
#' coefficient of variation of the supplied `chm`, the standard deviation of the
#' LiDAR MNH (`layers$lidar_mnh`), then the coefficient of variation of NDVI.
#' Without any of them B2 is `NA`.
#'
#' `strata_field`, `age_class_field`, `species_field`, `method`, `weights` and
#' `use_height_cv` are kept for compatibility and no longer change the score:
#' one category per unit carries no within-unit diversity (since 0.208.0).
#'
#' **Interpretation**: Multi-layered, multi-age stands score high (>75).
#' Monocultures or even-aged stands score low (<25).
#'
#' @family biodiversity-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units
#'
#' # Add structure attributes (normally from BD Forêt)
#' units$strata <- sample(c("Emergent", "Dominant", "Intermediate"),
#'   nrow(units),
#'   replace = TRUE
#' )
#' units$age_class <- sample(c("Young", "Mature", "Old"),
#'   nrow(units),
#'   replace = TRUE
#' )
#'
#' result <- indicateur_b2_structure(
#'   units,
#'   strata_field = "strata",
#'   age_class_field = "age_class",
#'   species_field = "species"
#' )
#'
#' hist(result$B2, main = "Structural Diversity Distribution")
#' }
indicateur_b2_structure <- function(units,
                                             layers = NULL,
                                             strata_field = "strata",
                                             age_class_field = "age_class",
                                             species_field = NULL,
                                             method = "shannon",
                                             weights = c(strata = 0.4, age = 0.3, species = 0.3),
                                             use_height_cv = FALSE,
                                             chm = NULL,
                                             cv_chm_weight = 0.2) {
  # Validate inputs
  validate_sf(units)

  if (!is.numeric(cv_chm_weight) || length(cv_chm_weight) != 1L ||
      cv_chm_weight < 0 || cv_chm_weight > 1) {
    cli::cli_abort("cv_chm_weight must be a scalar in [0, 1]")
  }

  # Precompute CV(CHM) once (spec 005 phase 4). Applied as an
  # additive weighted component at the end of the function when
  # cv_chm_weight > 0 and a CHM is supplied.
  cv_chm_score <- NULL
  if (!is.null(chm)) {
    if (!inherits(chm, "SpatRaster")) {
      cli::cli_abort("chm must be a terra SpatRaster")
    }
    units_proj <- sf::st_transform(as_pure_sf(units), terra::crs(chm))
    if (requireNamespace("exactextractr", quietly = TRUE)) {
      vals_list <- exactextractr::exact_extract(
        chm, units_proj, progress = FALSE, include_cell = FALSE
      )
      cv <- vapply(vals_list, function(v) {
        x <- if (is.data.frame(v)) v$value else v
        x <- x[!is.na(x) & x >= 0]
        if (length(x) < 10 || mean(x) <= 0) return(NA_real_)
        stats::sd(x) / mean(x)
      }, numeric(1))
    } else {
      ext_df <- terra::extract(chm, terra::vect(units_proj),
                               touches = TRUE)
      grouped <- split(ext_df[, 2], ext_df[, 1])
      cv <- vapply(grouped, function(x) {
        x <- x[!is.na(x) & x >= 0]
        if (length(x) < 10 || mean(x) <= 0) return(NA_real_)
        stats::sd(x) / mean(x)
      }, numeric(1))
    }
    # Heterogeneous peuplements score higher. CV ~ 0.4 is the
    # typical ceiling on mixed multi-strata mature stands.
    cv_chm_score <- pmin(cv / 0.4, 1) * 100
  }

  # Les colonnes strate / classe d'âge portent UNE valeur par unité : elles ne
  # décrivent aucune répartition intra-unité, donc aucune diversité (Shannon d'une
  # seule catégorie = 0). L'ancien chemin fabriquait un score à partir de la
  # diversité du LOT entier, plus un terme dépendant du numéro de ligne
  # (`i %% 4`) : trier le sf changeait B2 (audit 1.0, v0.208.0). La structure se
  # mesure donc sur la hauteur (CHM / MNH) ou, à défaut, sur le NDVI.
  has_strata <- strata_field %in% names(units)
  has_age <- age_class_field %in% names(units)
  if (has_strata || has_age) {
    cli::cli_alert_info(
      "B2: strata/age columns hold one value per unit (no within-unit distribution); structure is measured on canopy height or NDVI instead.")
  }

  {
    # Fallback 0: use CHM from the direct `chm` argument
    # (spec 005 phase 4). Same formula as the LiDAR MNH path
    # below, but computed from the supplied SpatRaster.
    if (!is.null(cv_chm_score) && cv_chm_weight > 0) {
      cli::cli_alert_info("B2: Using direct CHM (spec 005 phase 4)")
      units$B2 <- cv_chm_score
      return(units)
    }

    # Fallback 1: use LiDAR MNH (Canopy Height Model) for structural diversity
    # Height variability (std dev) is a direct measure of vertical structure
    mnh_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "lidar_mnh") else NULL
    if (!is.null(mnh_raster)) {
      cli::cli_alert_info("B2: Using LiDAR MNH for structural diversity")
      units_sf <- as_pure_sf(units)
      mnh_sd <- safe_extract(mnh_raster, units_sf,
        fun = "stdev", progress = FALSE)
      mnh_mean <- safe_extract(mnh_raster, units_sf,
        fun = "mean", progress = FALSE)
      # Height standard deviation as structural diversity:
      # Mature mixed forest: sd ~ 8-12m (high diversity)
      # Even-aged plantation: sd ~ 2-4m (low diversity)
      # Scale: sd 0m -> 0, sd 10m -> 100
      units$B2 <- pmin(mnh_sd / 10, 1) * 100
      return(units)
    }

    # Fallback 2: use NDVI standard deviation as proxy for structural diversity
    # Higher NDVI variance within a parcel = more structural heterogeneity
    ndvi_raster <- if (!is.null(layers)) resolve_raster_layer(layers, "ndvi") else NULL
    if (!is.null(ndvi_raster)) {
      cli::cli_alert_info("B2: No strata/age/MNH; estimating structure from NDVI variability")
      units_sf <- as_pure_sf(units)
      ndvi_sd <- safe_extract(ndvi_raster, units_sf,
        fun = "stdev", progress = FALSE)
      ndvi_mean <- safe_extract(ndvi_raster, units_sf,
        fun = "mean", progress = FALSE)
      # CV of NDVI as diversity proxy: typical range 0-0.5
      cv <- ifelse(ndvi_mean > 0, ndvi_sd / ndvi_mean, 0)
      # Scale CV (0-0.5) to B2 score (0-100)
      units$B2 <- pmin(cv / 0.4, 1) * 100
    } else {
      cli::cli_alert_warning("B2: no CHM, LiDAR MNH or NDVI available; B2 is NA")
      units$B2 <- rep(NA_real_, nrow(units))
    }
    return(units)
  }
}


# Small internal helper: linearly blend the legacy B2 score with
# the CV(CHM) score according to `w`. If the legacy B2 is NA for
# a unit and the CV(CHM) score is available, the CV(CHM) score
# becomes the fallback.
#
# @keywords internal
.blend_cv_chm <- function(units, cv_chm_score, w) {
  blended <- numeric(nrow(units))
  for (i in seq_len(nrow(units))) {
    b <- units$B2[i]
    h <- cv_chm_score[i]
    if (is.na(b) && is.na(h)) {
      blended[i] <- NA_real_
    } else if (is.na(b)) {
      blended[i] <- h
    } else if (is.na(h)) {
      blended[i] <- b
    } else {
      blended[i] <- (1 - w) * b + w * h
    }
  }
  units$B2 <- pmin(pmax(blended, 0), 100)
  units
}

# ==============================================================================
# T021: B3 - Ecological Connectivity (multi-method approach)
# ==============================================================================

#' Calculate Ecological Connectivity (B3)
#'
#' Computes ecological connectivity using a multi-method approach combining
#' structural metrics, cost distance, graph theory, and kernel dispersal,
#' as described in tutorial 04.
#' Uses BD Foret data and DEM when available.
#'
#' @param units An sf object with forest parcels.
#' @param bdforet An sf object with BD Foret V2 polygons. If NULL, B3 is NA
#'   for all parcels (connectivity not measurable). Default NULL.
#' @param dem A SpatRaster with digital elevation model. Used for cost distance
#'   refinement. Default NULL.
#' @param max_distance Numeric. Maximum distance threshold (meters) for local
#'   connectivity scoring. Default 5000.
#'
#' @return The input sf object with added column B3 (0-100 score, higher = better).
#'
#' @details
#' Four components are combined (25% each):
#' \enumerate{
#'   \item **Structural** (landscapemetrics): cohesion, nearest-neighbour distance,
#'     aggregation index of forest patches.
#'   \item **Cost distance** (terra): resistance-weighted distance from parcels
#'     to nearest forest patch.
#'   \item **Graph** (igraph): proportion of forest patches in the largest
#'     connected component (threshold 500m).
#'   \item **Kernel dispersal** (adehabitatHR): kernel density estimation of
#'     forest parcel centroids, ratio of 95% home range area to parcel area
#'     as proxy for functional connectivity.
#' }
#'
#' Final score: B3 = 0.7 * B3_global + 0.3 * local_connectivity
#' where local_connectivity is distance-based (sf) per-parcel adjustment
#' (distance from the unit centroid to the nearest forest polygon, 0 when the
#' centroid lies inside forest).
#'
#' A component that cannot be measured (missing package, error, fewer than 5
#' forest units for the kernel) is NA: it is excluded and the remaining
#' weights are renormalised, instead of entering the mean as a fixed 50.
#' Computations run in metres: geographic inputs are projected to
#' ETRS89-LAEA (EPSG:3035) and the result is attached to the original units.
#'
#' @family biodiversity-indicators
#' @export
indicateur_b3_connectivite <- function(units,
                                                bdforet = NULL,
                                                dem = NULL,
                                                max_distance = 5000) {
  # Validate inputs
  validate_sf(units)

  # Handle NULL bdforet (use fallback scoring)
  # Sans BD Foret, la connectivite des massifs n'est pas mesurable : elle est
  # inconnue, pas moyenne. Le 50 d'origine entrait dans la moyenne de famille
  # comme s'il avait ete constate.
  if (is.null(bdforet)) {
    msg_warn("biodiversity_no_bdforet")
    units$B3 <- rep(NA_real_, nrow(units))
    return(units)
  }

  if (!inherits(bdforet, "sf")) {
    cli::cli_abort("bdforet must be an sf object when provided")
  }

  # Toutes les composantes travaillent en metres (grille 25 m, tampons 1-2 km,
  # seuils de distance). En CRS geographique, ces constantes etaient lues en
  # degres : grille de 25 degres, tampon de 2000 degres. On calcule donc dans
  # une projection metrique (ETRS89-LAEA, ADR-008) et on rattache le resultat
  # aux unites d'origine.
  units_orig <- units
  units <- .b3_metric(units)
  bdforet <- sf::st_transform(bdforet, sf::st_crs(units))

  # Crop bdforet to study area with buffer (2km like tutorial)
  study_bbox <- sf::st_bbox(units)
  study_buffer <- sf::st_buffer(sf::st_as_sfc(study_bbox), 2000)
  bdforet_local <- tryCatch(
    suppressWarnings(sf::st_intersection(bdforet, study_buffer)),
    error = function(e) bdforet
  )
  # Remove empty geometries
  bdforet_local <- bdforet_local[!sf::st_is_empty(bdforet_local), ]

  # BD Foret fournie mais aucun polygone sur l'emprise : la connectivite des
  # massifs reste indefinie (il n'y a pas de massif a relier), elle ne vaut pas
  # « moyenne ».
  if (nrow(bdforet_local) == 0) {
    msg_warn("biodiversity_no_bdforet")
    units_orig$B3 <- rep(NA_real_, nrow(units_orig))
    return(units_orig)
  }

  n_parcels <- nrow(units)

  # Chaque composante vaut NA quand elle n'a pas pu etre mesuree (paquet
  # absent, erreur, donnees insuffisantes). L'ancien repli a 50 entrait dans
  # la moyenne comme une mesure ; il est exclu et les poids sont renormalises.

  # Component 1: Structural connectivity (landscapemetrics)
  structural_score <- tryCatch({
    if (!requireNamespace("landscapemetrics", quietly = TRUE)) {
      NA_real_
    } else {
      .b3_structural(bdforet_local, units)
    }
  }, error = function(e) NA_real_)

  # Component 2: Cost distance (terra)
  cost_score <- tryCatch({
    .b3_cost_distance(bdforet_local, units, dem)
  }, error = function(e) NA_real_)

  # Component 3: Graph connectivity (igraph)
  graph_score <- tryCatch({
    if (!requireNamespace("igraph", quietly = TRUE)) {
      NA_real_
    } else {
      .b3_graph(bdforet_local, units, threshold = 500)
    }
  }, error = function(e) NA_real_)

  # Component 4: Kernel dispersal (adehabitatHR)
  kernel_score <- tryCatch({
    if (!requireNamespace("adehabitatHR", quietly = TRUE) ||
        !requireNamespace("sp", quietly = TRUE)) {
      NA_real_
    } else {
      .b3_kernel(bdforet_local, units)
    }
  }, error = function(e) NA_real_)

  # Local connectivity (sf distance) — per-parcel adjustment
  local_connectivity <- tryCatch({
    .b3_local(bdforet_local, units, max_distance)
  }, error = function(e) rep(NA_real_, n_parcels))

  units_orig$B3 <- .b3_combine(
    c(structural = structural_score, cost = cost_score,
      graph = graph_score, kernel = kernel_score),
    local_connectivity
  )

  msg_info("indicateur_b3_connectivite")
  msg_info("biodiversity_b3_components",
           format(round(structural_score)), format(round(cost_score)),
           format(round(graph_score)), format(round(kernel_score)))

  units_orig
}

#' Project to a metric CRS when the input is geographic (ETRS89-LAEA)
#' @noRd
.b3_metric <- function(x) {
  if (isTRUE(sf::st_is_longlat(x))) sf::st_transform(x, 3035) else x
}

#' Combine B3 components, excluding unmeasured ones
#'
#' B3 = 0.7 * mean(global components) + 0.3 * local, i.e. weight 0.175 per
#' landscape component and 0.3 for the local one, renormalised over the
#' components actually measured (NA = not measured).
#' @noRd
.b3_combine <- function(global, local) {
  w_global <- ifelse(is.na(global), 0, 0.7 / length(global))
  g_val <- ifelse(is.na(global), 0, global)
  b3 <- vapply(seq_along(local), function(i) {
    loc <- local[i]
    w_loc <- if (is.na(loc)) 0 else 0.3
    w_tot <- sum(w_global) + w_loc
    if (w_tot == 0) return(NA_real_)
    (sum(w_global * g_val) + w_loc * (if (is.na(loc)) 0 else loc)) / w_tot
  }, numeric(1))

  missing <- names(global)[is.na(global)]
  if (length(missing) > 0) {
    cli::cli_alert_warning(
      "B3: component{?s} {.val {missing}} not measurable, excluded and weights renormalised."
    )
  }
  pmin(100, pmax(0, b3))
}

# --- B3 sub-components (internal) ---

#' Metric 25 m template covering the units plus a 1 km buffer
#' @noRd
.b3_template <- function(units, value) {
  if (isTRUE(sf::st_is_longlat(units))) {
    cli::cli_abort("B3 rasters need a projected (metric) CRS.")
  }
  bbox <- sf::st_bbox(sf::st_buffer(sf::st_as_sfc(sf::st_bbox(units)), 1000))
  template <- terra::rast(
    xmin = bbox["xmin"], xmax = bbox["xmax"],
    ymin = bbox["ymin"], ymax = bbox["ymax"],
    res = 25, crs = sf::st_crs(units)$wkt
  )
  terra::values(template) <- value
  template
}

#' Structural connectivity via landscapemetrics
#'
#' Weighted mean of cohesion (0.4), ENN (0.3), aggregation index (0.2) and
#' number of patches (0.1); a metric that cannot be computed (e.g. ENN with a
#' single patch) is excluded and the weights renormalised. NA if none.
#' @noRd
.b3_structural <- function(bdforet, units) {
  template <- .b3_template(units, 0L)

  # Rasterisation de la foret ; un echec rend la composante non mesurable
  forest_rast <- terra::rasterize(terra::vect(bdforet), template,
                                  field = 1, background = 0)

  lsm_value <- function(fun) {
    res <- tryCatch(fun(forest_rast), error = function(e) NULL)
    if (is.null(res)) return(NA_real_)
    res <- res[res$class == 1, ]
    if (nrow(res) == 0 || !is.finite(res$value[1])) NA_real_ else res$value[1]
  }

  cohesion_val <- lsm_value(landscapemetrics::lsm_c_cohesion)
  # ENN : NaN avec un seul massif (pas de voisin) -> exclu
  enn <- lsm_value(landscapemetrics::lsm_c_enn_mn)
  enn_norm <- if (is.na(enn)) NA_real_ else max(0, 100 - enn / 10)
  ai_val <- lsm_value(landscapemetrics::lsm_c_ai)
  # Nombre de taches : 1 -> 100, 51+ -> 0
  np <- lsm_value(landscapemetrics::lsm_c_np)
  np_norm <- if (is.na(np)) NA_real_ else max(0, 100 - (np - 1) * 2)

  vals <- c(cohesion_val, enn_norm, ai_val, np_norm)
  w <- c(0.4, 0.3, 0.2, 0.1)
  ok <- !is.na(vals)
  if (!any(ok)) return(NA_real_)
  score <- sum(w[ok] * vals[ok]) / sum(w[ok])
  pmin(100, pmax(0, score))
}

#' Cost distance connectivity via terra
#'
#' Friction raster (forest = target, open land = 10 per metre); the
#' accumulated cost from each unit centroid to the nearest forest cell is
#' averaged over the units and mapped to 0-100 (100 - cost / 10). NA when no
#' centroid reaches a forest cell.
#' @noRd
.b3_cost_distance <- function(bdforet, units, dem = NULL) {
  # Friction : 0 sur les cellules forestieres (cibles de terra::costDist,
  # `target` est une VALEUR, pas un raster), 10 hors foret.
  template <- .b3_template(units, 10)
  friction <- terra::rasterize(terra::vect(bdforet), template,
                               field = 0, background = 10)

  cost_dist <- terra::costDist(friction, target = 0)

  # Cout au centroide de chaque unite
  centroids <- suppressWarnings(sf::st_centroid(sf::st_geometry(units)))
  costs <- terra::extract(cost_dist, terra::vect(centroids))
  vals <- costs[[ncol(costs)]]
  vals[!is.finite(vals)] <- NA_real_
  if (all(is.na(vals))) return(NA_real_)
  mean_cost <- mean(vals, na.rm = TRUE)

  # Normalize: low cost = high connectivity (landscape-level)
  pmin(100, pmax(0, 100 - mean_cost / 10))
}

#' Graph-based connectivity via igraph
#' @noRd
.b3_graph <- function(bdforet, units, threshold = 500) {
  # Dissolve overlapping forest polygons
  patches <- tryCatch({
    merged <- sf::st_union(bdforet)
    cast <- sf::st_cast(merged, "POLYGON")
    sf::st_sf(patch_id = seq_along(cast), geometry = cast)
  }, error = function(e) {
    sf::st_sf(patch_id = seq_len(nrow(bdforet)), geometry = sf::st_geometry(bdforet))
  })

  n_patches <- nrow(patches)
  if (n_patches < 2) return(100)

  centroids <- suppressWarnings(sf::st_centroid(patches))
  dist_mat <- as.numeric(sf::st_distance(centroids))
  dim(dist_mat) <- c(n_patches, n_patches)

  # Adjacency: connected if distance < threshold
  adj_mat <- dist_mat < threshold
  diag(adj_mat) <- FALSE

  g <- igraph::graph_from_adjacency_matrix(adj_mat, mode = "undirected")
  comp <- igraph::components(g)

  # Connectivity = % of nodes in largest component
  (max(comp$csize) / n_patches) * 100
}

#' Kernel dispersal connectivity via adehabitatHR
#' @noRd
.b3_kernel <- function(bdforet, units, h_dispersion = 300) {
  # Find forest parcels (parcels intersecting bdforet)
  forest_idx <- lengths(sf::st_intersects(units, bdforet)) > 0
  parcelles_forest <- units[forest_idx, ]

  # Moins de 5 unites forestieres : estimation a noyau non significative
  if (nrow(parcelles_forest) < 5) return(NA_real_)

  # Reproject to metric CRS if needed (adehabitatHR needs meters)
  centroids_sf <- suppressWarnings(sf::st_centroid(parcelles_forest))
  if (sf::st_is_longlat(centroids_sf)) {
    centroids_sf <- sf::st_transform(centroids_sf, 2154)  # Lambert 93
    parcelles_metric <- sf::st_transform(parcelles_forest, 2154)
  } else {
    parcelles_metric <- parcelles_forest
  }

  # Convert to sp SpatialPoints (only coords, drop attributes)
  coords <- sf::st_coordinates(centroids_sf)
  centroids_sp <- sp::SpatialPoints(
    coords,
    proj4string = sp::CRS(sf::st_crs(centroids_sf)$proj4string)
  )

  # Kernel density estimation with larger extent for robust estimation
  kde <- adehabitatHR::kernelUD(centroids_sp, h = h_dispersion,
                                 grid = 100, extent = 2)

  # 95% home range area
  hr95 <- tryCatch(
    adehabitatHR::kernel.area(kde, percent = 95),
    warning = function(w) {
      # Grid too small: retry with larger extent
      kde2 <- adehabitatHR::kernelUD(centroids_sp, h = h_dispersion,
                                      grid = 200, extent = 5)
      suppressWarnings(adehabitatHR::kernel.area(kde2, percent = 95))
    }
  )
  kernel_area <- hr95[[1]]  # in hectares

  # Ratio kernel area / parcel area (spread index)
  total_parcel_area <- as.numeric(sum(sf::st_area(parcelles_metric))) / 10000
  kernel_ratio <- kernel_area / total_parcel_area

  # Normalize 0-100: ratio > 2 = 100
  pmin(100, kernel_ratio * 50)
}

#' Local connectivity via sf distance (per-parcel)
#'
#' Distance from each unit centroid to the nearest forest polygon (0 when the
#' centroid lies inside forest), mapped to 0-100 as 100 - d / 20.
#' @noRd
.b3_local <- function(bdforet, units, max_distance = 5000) {
  centroids <- suppressWarnings(sf::st_centroid(sf::st_geometry(units)))
  dist_to_forest <- sf::st_distance(centroids, bdforet)
  # Une distance nulle (centroide en foret) est une vraie mesure : elle ne
  # doit pas etre ecartee au profit du polygone suivant.
  min_dist <- apply(matrix(as.numeric(dist_to_forest),
                           nrow = length(centroids)), 1, function(x) {
    x <- x[is.finite(x)]
    if (length(x) > 0) min(x) else NA_real_
  })

  # Normalize: 0m -> 100, like tutorial: 100 - (min_dist / 20)
  pmax(0, 100 - min_dist / 20)
}
