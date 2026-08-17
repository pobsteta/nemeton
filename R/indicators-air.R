# indicators-air.R
# Air Quality & Microclimate Family (A) Indicators
# MVP v0.3.0 - Multi-Family Indicator Extension

#' @importFrom sf st_buffer st_area st_intersection st_distance st_as_sf
#' @importFrom terra extract
#' @importFrom stats median
#' @keywords internal
NULL

# ==============================================================================
# T048: A1 - Tree Coverage Buffer Index
# ==============================================================================

#' Calculate Tree Coverage Buffer Index (A1)
#'
#' Computes forest coverage percentage within a buffer around each parcel
#' to assess local air quality and microclimate regulation potential.
#'
#' @param units An sf object with forest parcels.
#' @param land_cover A SpatRaster with land cover classification.
#'   Required in legacy mode; may be \code{NULL} when \code{fvc} is
#'   supplied.
#' @param forest_classes Numeric vector. Land cover class codes for forests
#'   (OSO codes: 16 = coniferous, 17 = broadleaf, 18 = mixed).
#'   Default c(16, 17, 18).
#' @param buffer_radius Numeric. Buffer radius in meters. Default 1000.
#' @param fvc Optional \code{SpatRaster} of Fractional Vegetation
#'   Cover in \code{[0, 1]} (typically the Theia
#'   \code{s2_biophysical} FVC product, loaded via
#'   \code{\link{load_raster_source}}). When supplied, activates
#'   FVC mode: A1 is the per-buffer mean FVC rescaled to a 0-100
#'   percentage, and \code{land_cover} is ignored. The raster is
#'   expected in the CRS of \code{units}.
#'
#' @return The input sf object with added column:
#'   \itemize{
#'     \item A1: Forest coverage percentage (0-100) within buffer.
#'   }
#'
#' @details
#' **Formula** (legacy mode): A1 = (forest_area_in_buffer / total_buffer_area) × 100
#'
#' **FVC mode** (Theia \code{s2_biophysical}, phase 3a): A1 = mean(FVC) × 100
#' over the buffer.
#'
#' **Interpretation**:
#' \itemize{
#'   \item 0-20\%: Low forest coverage (poor air quality regulation)
#'   \item 20-50\%: Moderate forest coverage
#'   \item 50-80\%: Good forest coverage
#'   \item 80-100\%: Excellent forest coverage (optimal air quality)
#' }
#'
#' @family air-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#' library(terra)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units[1:10, ]
#'
#' land_cover <- rast("path/to/corine_land_cover.tif")
#'
#' # Calculate A1 with 1km buffer
#' result <- indicateur_a1_couverture(units, land_cover = land_cover, buffer_radius = 1000)
#' summary(result$A1)
#'
#' # Calculate with 500m buffer
#' result <- indicateur_a1_couverture(units, land_cover = land_cover, buffer_radius = 500)
#' }
indicateur_a1_couverture <- function(units,
                                   land_cover = NULL,
                                   forest_classes = c(16, 17, 18),
                                   buffer_radius = 1000,
                                   fvc = NULL) {
  # Validate inputs
  validate_sf(units)

  if (buffer_radius <= 0) {
    stop("buffer_radius must be positive", call. = FALSE)
  }

  # Create buffers around each parcel
  buffers <- sf::st_buffer(units, dist = buffer_radius)

  # --- FVC mode (Theia s2_biophysical, phase 3a) ----------------
  if (!is.null(fvc)) {
    if (!inherits(fvc, "SpatRaster")) {
      stop("fvc must be a SpatRaster object", call. = FALSE)
    }
    cli::cli_alert_info("A1: tree coverage from FVC (Theia s2_biophysical)")
    fvc_mean <- safe_extract(
      fvc,
      as_pure_sf(buffers),
      fun = "mean",
      progress = FALSE
    )
    units$A1 <- fvc_mean * 100
    msg_info("indicateur_a1_couverture")
    return(units)
  }

  # Legacy mode requires a land-cover raster
  if (!inherits(land_cover, "SpatRaster")) {
    stop("land_cover must be a SpatRaster object", call. = FALSE)
  }

  # Extract land cover classes within each buffer
  coverage_pct <- numeric(nrow(units))

  if (requireNamespace("exactextractr", quietly = TRUE)) {
    # Use exactextractr for efficient zonal statistics
    for (i in seq_len(nrow(units))) {
      # Extract land cover values for this buffer
      lc_values <- safe_extract(land_cover, buffers[i, ], progress = FALSE)[[1]]$value

      if (length(lc_values) > 0) {
        # Count forest pixels
        forest_pixels <- sum(lc_values %in% forest_classes, na.rm = TRUE)
        total_pixels <- sum(!is.na(lc_values))

        # Calculate percentage
        if (total_pixels > 0) {
          coverage_pct[i] <- (forest_pixels / total_pixels) * 100
        } else {
          coverage_pct[i] <- NA_real_
        }
      } else {
        coverage_pct[i] <- NA_real_
      }
    }
  } else {
    # Fallback using terra::extract
    for (i in seq_len(nrow(units))) {
      lc_values <- terra::extract(land_cover, buffers[i, ], ID = FALSE)[, 1]

      if (length(lc_values) > 0) {
        forest_pixels <- sum(lc_values %in% forest_classes, na.rm = TRUE)
        total_pixels <- sum(!is.na(lc_values))

        if (total_pixels > 0) {
          coverage_pct[i] <- (forest_pixels / total_pixels) * 100
        } else {
          coverage_pct[i] <- NA_real_
        }
      } else {
        coverage_pct[i] <- NA_real_
      }
    }
  }

  # A1 score (already 0-100 percentage)
  units$A1 <- coverage_pct

  msg_info("indicateur_a1_couverture")

  units
}

# ==============================================================================
# T049: A2 - Air Quality Index
# ==============================================================================

#' Calculate Air Quality Index (A2)
#'
#' Computes air quality score using direct ATMO station data (if available)
#' or proxy method based on distance to pollution sources (roads, urban areas).
#'
#' @param units An sf object with forest parcels.
#' @param layers A nemeton_layers object. If provided, roads are extracted
#'   from the "roads" vector layer when the `roads` parameter is NULL.
#' @param atmo_data An sf object with ATMO air quality stations (points).
#'   Must contain columns: NO2 (µg/m³), PM10 (µg/m³). Can be NULL.
#' @param roads An sf object with road network (lines). Used for proxy method.
#' @param urban_areas An sf object with urban zones (polygons). Used for proxy method.
#' @param method Character. Method to use:
#'   \itemize{
#'     \item "auto" (default): Use direct if atmo_data available, else proxy
#'     \item "direct": Require ATMO data (error if NULL)
#'     \item "proxy": Use distance-based proxy
#'   }
#'
#' @return The input sf object with added columns:
#'   \itemize{
#'     \item A2: Air quality index (0-100). Higher = better air quality.
#'     \item A2_method: Method used ("direct" or "proxy")
#'   }
#'
#' @details
#' **Direct Method** (ATMO data):
#' - Interpolate NO2 and PM10 from nearest stations
#' - Convert to quality score: low pollution = high score
#'
#' **Proxy Method** (distance-based):
#' - Calculate distance to nearest road and urban area
#' - Far from pollution sources = high score
#'
#' @family air-indicators
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#'
#' data(massif_demo_units)
#' units <- massif_demo_units[1:10, ]
#'
#' # Direct method with ATMO data
#' atmo_data <- st_read("path/to/atmo_stations.gpkg")
#' result <- indicateur_a2_qualite_air(units, atmo_data = atmo_data, method = "direct")
#'
#' # Proxy method
#' roads <- st_read("path/to/roads.gpkg")
#' urban <- st_read("path/to/urban_areas.gpkg")
#' result <- indicateur_a2_qualite_air(units, roads = roads, urban_areas = urban, method = "proxy")
#' }
indicateur_a2_qualite_air <- function(units,
                                  layers = NULL,
                                  atmo_data = NULL,
                                  roads = NULL,
                                  urban_areas = NULL,
                                  method = "auto") {
  # Validate inputs
  validate_sf(units)

  # Extract roads from layers if not provided directly
  if (is.null(roads) && !is.null(layers)) {
    roads <- resolve_vector_layer(layers, "roads")
  }

  # Harmonize CRS: project roads and atmo_data to same CRS as units
  if (!is.null(roads) && inherits(roads, "sf")) {
    if (!identical(sf::st_crs(roads), sf::st_crs(units))) {
      roads <- sf::st_transform(roads, sf::st_crs(units))
    }
  }
  if (!is.null(atmo_data) && inherits(atmo_data, "sf")) {
    if (!identical(sf::st_crs(atmo_data), sf::st_crs(units))) {
      atmo_data <- sf::st_transform(atmo_data, sf::st_crs(units))
    }
  }

  # Auto-detect method
  if (method == "auto") {
    if (!is.null(atmo_data) && inherits(atmo_data, "sf")) {
      method <- "direct"
    } else if (!is.null(roads)) {
      method <- "proxy"
    } else {
      # No data available at all - return neutral score
      cli::cli_alert_warning("A2: No ATMO data or roads available, returning neutral score")
      units$A2 <- rep(50, nrow(units))
      units$A2_method <- "none"
      return(units)
    }
  }

  # Direct method: ATMO station data
  if (method == "direct") {
    if (is.null(atmo_data) || !inherits(atmo_data, "sf")) {
      stop("atmo_data must be an sf object for direct method", call. = FALSE)
    }

    # Check required columns
    if (!all(c("NO2", "PM10") %in% names(atmo_data))) {
      stop("atmo_data must contain columns: NO2, PM10", call. = FALSE)
    }

    # For each parcel, interpolate pollution from nearest stations (simple IDW)
    a2_scores <- numeric(nrow(units))
    parcel_centroids <- suppressWarnings(sf::st_centroid(units))

    for (i in seq_len(nrow(units))) {
      # Calculate distances to all stations
      distances <- sf::st_distance(parcel_centroids[i, ], atmo_data)[1, ]

      # Inverse distance weighting (nearest 3 stations)
      nearest_idx <- order(distances)[seq_len(min(3, length(distances)))]
      nearest_dist <- as.numeric(distances[nearest_idx])
      nearest_dist[nearest_dist == 0] <- 1 # Avoid division by zero

      weights <- 1 / nearest_dist
      weights <- weights / sum(weights)

      # Weighted average pollution
      NO2_weighted <- sum(atmo_data$NO2[nearest_idx] * weights)
      PM10_weighted <- sum(atmo_data$PM10[nearest_idx] * weights)

      # Convert to quality score (invert pollution)
      # NO2: 0-40 µg/m³ = good (100-0 score)
      # PM10: 0-50 µg/m³ = good (100-0 score)
      NO2_score <- pmin(pmax((40 - NO2_weighted) / 40, 0), 1) * 100
      PM10_score <- pmin(pmax((50 - PM10_weighted) / 50, 0), 1) * 100

      # Average of both pollutants
      a2_scores[i] <- (NO2_score + PM10_score) / 2
    }

    units$A2 <- a2_scores
    units$A2_method <- "direct"
  } else if (method == "proxy") {
    # Proxy method: weighted pollution from roads (tuto 02, exercice 9.2)
    if (is.null(roads)) {
      stop("roads must be provided for proxy method", call. = FALSE)
    }

    # Pollution weights by BD TOPO v3 `nature` field
    pollution_weights <- c(
      "autoroute"          = 1.0,
      "type autoroutier"   = 1.0,
      "quasi-autoroute"    = 0.9,
      "route.*2 chauss"    = 0.8,
      "bretelle"           = 0.7,
      "route.*1 chauss"    = 0.6,
      "rond-point"         = 0.5,
      "route empierr"      = 0.3,
      "chemin"             = 0.1,
      "piste cyclable"     = 0.05,
      "sentier"            = 0.02,
      "escalier"           = 0.02
    )

    # Assign weight to each road segment based on road type field
    # Try multiple possible field names (BD TOPO v3: "nature", demo data: "road_type", etc.)
    nature_field <- NULL
    for (field in c("nature", "NATURE", "classe", "importance", "type", "road_type")) {
      if (field %in% names(roads)) {
        nature_field <- field
        break
      }
    }
    if (!is.null(nature_field)) {
      road_nature <- tolower(roads[[nature_field]])
      road_w <- rep(0.5, nrow(roads))  # default weight
      for (j in seq_along(pollution_weights)) {
        matched <- grepl(names(pollution_weights)[j], road_nature, ignore.case = TRUE)
        road_w[matched] <- pollution_weights[j]
      }
    } else {
      road_w <- rep(0.5, nrow(roads))
    }

    parcel_centroids <- suppressWarnings(sf::st_centroid(units))

    # Compute pollution score per parcel
    pollution_scores <- numeric(nrow(units))

    for (i in seq_len(nrow(units))) {
      dists <- as.numeric(sf::st_distance(parcel_centroids[i, ], roads))
      # Keep roads within 2000m
      within <- dists < 2000
      if (any(within)) {
        d <- pmax(dists[within], 10)  # minimum 10m to avoid extreme values
        w <- road_w[within]
        pollution_scores[i] <- sum(w / (d / 100)^2)
      } else {
        pollution_scores[i] <- 0
      }
    }

    # Normalize across all parcels using log transform
    max_score <- max(pollution_scores, na.rm = TRUE)
    if (max_score > 0) {
      pollution_norm <- log1p(pollution_scores) / log1p(max_score)
    } else {
      pollution_norm <- rep(0, nrow(units))
    }

    # A2: higher = better air quality (invert pollution)
    units$A2 <- round(pmin(pmax((1 - pollution_norm) * 100, 0), 100), 1)
    units$A2_method <- "proxy"
  } else {
    stop("method must be 'auto', 'direct', or 'proxy'", call. = FALSE)
  }

  msg_info("indicateur_a2_qualite_air")

  units
}


# ==============================================================================
# A5 - Urban cooling / relative surface freshness (LST)  [spec 032]
# ==============================================================================

#' Can A5 urban cooling be computed here?
#'
#' Answers, **before** any computation, whether the LST-based cooling indicator
#' applies to a set of units — and if not, which condition fails. The
#' counterpart of [r5_applicabilite()] for the A family.
#'
#' A5 has two independent conditions, and they fail at different scales:
#' \itemize{
#'   \item \strong{coverage} — a Land Surface Temperature product must exist
#'     over the extent. Theia's Thermocity lineage covers a handful of French
#'     metropolises, not rural forests. Checked with
#'     [theia_source_status()], which queries the catalogue without
#'     downloading.
#'   \item \strong{local reference} — each unit is scored against the median
#'     LST of a ring around it (\code{buffer_m}). A unit inside the scene
#'     footprint but with no valid pixel in its ring cannot be scored.
#' }
#'
#' The first is answered at the scale of the **scene**: a STAC query knows
#' bounding boxes, not pixels. A unit 20 km from a covered city may fall inside
#' a scene's bbox without holding a single valid pixel. So the verdict is
#' two-tiered: without \code{lst}, an extent-level answer costing one catalogue
#' query; with a raster already at hand (typically the project cache), a
#' per-unit answer.
#'
#' @param units An sf object with the units.
#' @param lst A SpatRaster of Land Surface Temperature, when one is already
#'   available (project cache). \code{NULL} (default) answers at extent level.
#' @param buffer_m Numeric. Radius (m) of the local-reference ring, as in
#'   [indicateur_a5_rafraichissement()]. Default 500.
#' @param country Character. Country config key for the catalogue query.
#'   Default \code{"FR"}.
#'
#' @return A list with:
#'   \itemize{
#'     \item \code{status}: one of \code{"eligible"},
#'       \code{"eligible_partial"} (coverage, but only some units are
#'       scorable), \code{"no_coverage"}, \code{"no_reference"},
#'       \code{"no_credentials"}, \code{"error"}. A \strong{stable key}, meant
#'       to be translated downstream.
#'     \item \code{n_units}, \code{n_eligible}.
#'     \item \code{n_assets}: LST scenes intersecting the extent
#'       (\code{NA} when \code{lst} was supplied and no query was made).
#'     \item \code{per_unit}: data.frame (\code{has_lst}, \code{has_reference},
#'       \code{eligible}) or \code{NULL} at extent level.
#'   }
#'
#' @seealso [theia_source_status()], [indicateur_a5_rafraichissement()],
#'   [r5_applicabilite()]
#' @export
#'
#' @examples
#' \dontrun{
#' ap <- a5_applicabilite(units)
#' if (ap$status == "no_coverage") {
#'   message("Hors couverture Thermocity - A5 restera NA, ce n'est pas une erreur")
#' }
#' }
a5_applicabilite <- function(units, lst = NULL, buffer_m = 500,
                             country = "FR") {
  if (!inherits(units, "sf")) {
    cli::cli_abort("{.arg units} must be an sf object.")
  }
  n <- nrow(units)
  out <- function(status, n_eligible = 0L, n_assets = NA_integer_,
                  per_unit = NULL) {
    list(status = status, n_units = n, n_eligible = as.integer(n_eligible),
         n_assets = as.integer(n_assets), per_unit = per_unit)
  }
  if (n == 0L) return(out("no_coverage"))

  # --- Niveau emprise : une requête catalogue, aucun téléchargement. ---------
  if (is.null(lst) || !inherits(lst, "SpatRaster")) {
    st <- theia_source_status("theia_lst",
                              sf::st_as_sfc(sf::st_bbox(units)),
                              country = country)
    status <- switch(
      st$reason,
      ok                = "eligible",
      no_asset_over_aoi = "no_coverage",
      no_credentials    = "no_credentials",
      "error"
    )
    # `eligible` est ici un verdict d'EMPRISE : la couverture existe, mais rien
    # ne dit encore que chaque unité porte des pixels. Passer `lst` tranche.
    return(out(status, n_eligible = if (status == "eligible") n else 0L,
               n_assets = st$n_assets))
  }

  # --- Niveau unité : le raster est là, on regarde les pixels. ---------------
  units_r <- sf::st_transform(as_pure_sf(units), terra::crs(lst))
  valid <- function(v) {
    v <- if (is.data.frame(v)) v$value else v
    # Même sentinelle que l'indicateur : -32768 est le nodata des produits LST.
    sum(is.finite(v) & v > -1000) > 0
  }

  ex_u <- exactextractr::exact_extract(lst[[1]], units_r, progress = FALSE)
  has_lst <- vapply(ex_u, valid, logical(1))

  buf <- sf::st_buffer(sf::st_geometry(units_r), buffer_m)
  own <- sf::st_geometry(units_r)
  ring <- sf::st_sf(geometry = sf::st_sfc(
    lapply(seq_len(n), function(i) {
      suppressWarnings(sf::st_difference(buf[[i]], own[[i]]))
    }), crs = sf::st_crs(units_r)))
  ex_r <- exactextractr::exact_extract(lst[[1]], ring, progress = FALSE)
  has_ref <- vapply(ex_r, valid, logical(1))

  eligible <- has_lst & has_ref
  per_unit <- data.frame(has_lst = has_lst, has_reference = has_ref,
                         eligible = eligible)

  status <- if (all(eligible)) {
    "eligible"
  } else if (any(eligible)) {
    # Le cas qui manquait : couverture réelle, mais un axe A5 à moitié vide.
    "eligible_partial"
  } else if (any(has_lst)) {
    # Des pixels sur les unités, aucun anneau exploitable : ce n'est pas un
    # défaut de couverture mais de géométrie (unités trop grandes, bord de
    # scène). L'indicateur rendra `skipped_no_reference`.
    "no_reference"
  } else {
    "no_coverage"
  }
  out(status, n_eligible = sum(eligible), per_unit = per_unit)
}


#' Calculate Urban Cooling Index (A5)
#'
#' Relative surface-temperature freshness of a forest / tree unit compared
#' with its local surroundings, from a Land Surface Temperature (LST) raster
#' (e.g. Theia Thermocity ECOSTRESS/ASTER). High = the unit is markedly
#' **cooler** than its surroundings — the cooling service trees provide in an
#' urban heat-island context.
#'
#' Scope (spec 032, reoriented): this indicator targets the **urban tree /
#' forest-city interface**, precisely where an LST product is available. Over
#' rural forests, where no LST covers the area, it is left `NA`. Surface
#' **albedo is deliberately NOT used**: for a tree it is not a valid cooling
#' proxy (cooling comes from shade + evapotranspiration; canopy albedo is low
#' and second-order), so LST — the direct temperature signal — is the only
#' physically sound basis.
#'
#' The score is a **relative** freshness: the unit's mean LST is compared with
#' a local reference (median LST of a surrounding ring, or a supplied
#' `reference`). Differences are scale-invariant between kelvin and celsius, so
#' either unit works.
#'
#' @param units An sf object with the tree / forest units.
#' @param lst A terra SpatRaster of Land Surface Temperature (K or °C). `NULL`
#'   (default) -> the indicator is not applicable and `A5 = NA` for every unit
#'   (source-conditional, like A3/A4 without a microclimate model).
#' @param reference Optional numeric. A fixed reference temperature (same unit
#'   as `lst`). `NULL` (default) -> a per-unit local reference is used: the
#'   median LST of a ring around the unit (`buffer_m`).
#' @param buffer_m Numeric. Radius (m) of the local-reference ring around each
#'   unit. Default 500.
#' @param delta_scale Numeric. Temperature difference (K/°C) mapped to the full
#'   score swing: a unit `delta_scale` cooler than its reference scores 100,
#'   `delta_scale` hotter scores 0, equal scores 50. Default 5.
#' @param ... Unused.
#'
#' @return `units` with `A5` (0-100, high = cooler than surroundings),
#'   `A5_delta` (raw reference − unit LST) and `a5_status`. `A5 = NA` where
#'   `lst` is `NULL`, the unit does not overlap the raster, or no local
#'   reference is available.
#'
#'   `a5_status` is one of `"calculated"`, `"skipped_no_lst"` (no LST raster
#'   supplied) or `"skipped_no_reference"` (raster supplied but no unit could be
#'   scored — no overlap, or no local reference). It mirrors `r5_status` and
#'   exists so that a consumer can tell an empty indicator apart from a broken
#'   one: outside Thermocity coverage `A5 = NA` is the correct answer, not a
#'   failure.
#'
#' @export
indicateur_a5_rafraichissement <- function(units, lst = NULL,
                                           reference   = NULL,
                                           buffer_m    = 500,
                                           delta_scale = 5, ...) {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)
  n <- nrow(units)

  if (is.null(lst)) {
    cli::cli_alert_info("A5: no LST raster supplied - A5 = NA (indicator skipped).")
    units$A5 <- rep(NA_real_, n)
    units$A5_delta <- rep(NA_real_, n)
    units$a5_status <- rep("skipped_no_lst", n)
    return(units)
  }
  if (!inherits(lst, "SpatRaster")) {
    stop("lst must be a terra SpatRaster", call. = FALSE)
  }
  if (!is.numeric(delta_scale) || length(delta_scale) != 1L || delta_scale <= 0) {
    stop("delta_scale must be a positive scalar", call. = FALSE)
  }
  if (!requireNamespace("exactextractr", quietly = TRUE) ||
      !requireNamespace("terra", quietly = TRUE)) {
    stop("packages exactextractr and terra are required for A5", call. = FALSE)
  }
  if (n == 0L) {
    units$A5 <- numeric(0); units$A5_delta <- numeric(0)
    return(units)
  }

  units_r <- sf::st_transform(as_pure_sf(units), terra::crs(lst))

  # Drop non-finite and the -32768 LST nodata sentinel; keep both K and °C.
  clean <- function(v) {
    v <- if (is.data.frame(v)) v$value else v
    v[is.finite(v) & v > -1000]
  }

  # Mean LST inside each unit.
  ex_u <- exactextractr::exact_extract(lst[[1]], units_r, progress = FALSE)
  unit_lst <- vapply(ex_u, function(df) {
    v <- clean(df); if (!length(v)) NA_real_ else mean(v)
  }, numeric(1))

  # Local reference: fixed value, or median LST of a ring around each unit.
  if (!is.null(reference)) {
    ref_lst <- rep(as.numeric(reference)[1L], n)
  } else {
    # Per-unit ring = buffer(unit_i) minus unit_i, built one geometry at a
    # time so row order is preserved (a whole-set st_difference can drop
    # empty rows and break alignment).
    buf <- sf::st_buffer(sf::st_geometry(units_r), buffer_m)
    own <- sf::st_geometry(units_r)
    ring_geoms <- lapply(seq_len(n), function(i) {
      suppressWarnings(sf::st_difference(buf[[i]], own[[i]]))
    })
    ring <- sf::st_sf(
      geometry = sf::st_sfc(ring_geoms, crs = sf::st_crs(units_r)))
    ex_r <- exactextractr::exact_extract(lst[[1]], ring, progress = FALSE)
    ref_lst <- vapply(ex_r, function(df) {
      v <- clean(df); if (!length(v)) NA_real_ else stats::median(v)
    }, numeric(1))
  }

  delta <- ref_lst - unit_lst                      # positive = unit cooler
  score <- 50 + (delta / delta_scale) * 50
  score <- pmin(100, pmax(0, score))
  score[is.na(delta)] <- NA_real_

  units$A5 <- round(score, 1)
  units$A5_delta <- round(delta, 2)
  # Un raster fourni mais aucune unité notée (emprises disjointes, pas de
  # référence locale) n'est pas la même chose qu'une source absente : l'aval doit
  # pouvoir distinguer les deux sans réinspecter les données.
  units$a5_status <- ifelse(is.na(units$A5), "skipped_no_reference", "calculated")
  msg_info("indicateur_a5_rafraichissement")
  units
}
