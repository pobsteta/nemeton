#' Naturalness & Wilderness Character Indicators (Family N)
#'
#' Functions for calculating naturalness and wilderness indicators:
#' - N1: Infrastructure distance (remoteness from human influence)
#' - N2: Forest continuity (continuous patch size)
#' - N3: Composite naturalness index (integrating multiple dimensions)
#'
#' @name indicators-naturalness
#' @keywords internal
#' @family indicators
NULL

#' N1: Infrastructure Distance Indicator
#'
#' Calculates distance to infrastructure (roads, buildings, urban zones)
#' as a measure of remoteness from human influence. Follows tuto 04 methodology:
#' distances from parcel centroids to roads (BD TOPO) and buildings, normalized
#' to 0-100 and combined with weights (40% roads, 35% buildings, 25% urban).
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param roads sf object (LINESTRING/MULTILINESTRING). Road network (BD TOPO). NULL = default 1000m.
#' @param buildings sf object (POLYGON/MULTIPOLYGON). Buildings. NULL = default 500m.
#' @param layers nemeton_layers object. Used to resolve roads/buildings if not provided directly.
#' @param column_name Character. Name for output column. Default "N1".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added column N1 (score 0-100, 100 = very remote)
#'
#' @export
indicateur_n1_distance <- function(units,
                                           roads = NULL,
                                           buildings = NULL,
                                           layers = NULL,
                                           column_name = "N1",
                                           lang = "en") {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)

  result <- units
  centroids <- suppressWarnings(sf::st_centroid(units))

  # Resolve from layers if not provided directly
  if (is.null(roads) && !is.null(layers) && inherits(layers, "nemeton_layers")) {
    roads <- resolve_vector_layer(layers, "roads")
  }
  if (is.null(buildings) && !is.null(layers) && inherits(layers, "nemeton_layers")) {
    buildings <- resolve_vector_layer(layers, "buildings")
  }

  # Distance to roads (BD TOPO)
  if (!is.null(roads) && inherits(roads, "sf") && nrow(roads) > 0) {
    roads <- sf::st_transform(roads, sf::st_crs(units))
    roads <- sf::st_make_valid(roads)
    dist_routes <- as.numeric(sf::st_distance(centroids, sf::st_union(roads)))
  } else {
    dist_routes <- rep(1000, nrow(units)) # default like tuto 04
  }

  # Distance to buildings
  if (!is.null(buildings) && inherits(buildings, "sf") && nrow(buildings) > 0) {
    buildings <- sf::st_transform(buildings, sf::st_crs(units))
    buildings <- sf::st_make_valid(buildings)
    dist_batiments <- as.numeric(sf::st_distance(centroids, sf::st_union(buildings)))
  } else {
    dist_batiments <- rep(500, nrow(units)) # default like tuto 04
  }

  # Distance to urban zones (no dedicated layer, use default)
  dist_urbain <- rep(2000, nrow(units))

  # Normalize: 0m = score 0, 2000m+ = score 100
  N1_routes <- pmin(100, dist_routes / 20)
  N1_batiments <- pmin(100, dist_batiments / 20)
  N1_urbain <- pmin(100, dist_urbain / 20)

  # Composite: 40% routes, 35% buildings, 25% urban (tuto 04)
  result[[column_name]] <- 0.40 * N1_routes + 0.35 * N1_batiments + 0.25 * N1_urbain

  cli::cli_alert_success("Calculated {column_name}: Infrastructure distance (0-100)")
  return(result)
}

#' N2: Forest Continuity Indicator
#'
#' Calculates forest continuity using BD Foret (current forest cover) and
#' optionally BD Foret Anciennes (historical forest from ~1850). Follows tuto 04:
#' - Ancient forest (>0% on 1850 map): score = 60 + 40 * taux_anciennete
#' - Recent forest (current cover but not ancient): score = 30 + 30 * taux_boisement
#' - No forest: score = 15
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param bdforet sf object. Current forest cover (BD Foret V2). NULL = default score 50.
#' @param foret_ancienne sf object. Historical forest cover. A single-epoch layer
#'   (e.g. état-major ~1850) or a **tiered** layer from
#'   [build_foret_ancienne_mask()] with an `anciennete` column (multi-epoch
#'   consolidation, e.g. Cassini + état-major). NULL = only use bdforet.
#' @param layers nemeton_layers object. Used to resolve bdforet if not provided directly.
#' @param column_name Character. Name for output column. Default "N2".
#' @param weight_anciennete Logical. When `foret_ancienne` carries an
#'   `anciennete` tier column, weight the ancient-forest coverage by tier depth
#'   (forest present at more epochs counts more). Ignored for single-epoch
#'   layers. Default `TRUE`.
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added column N2 (score 0-100)
#'
#' @export
indicateur_n2_continuite <- function(units,
                                             bdforet = NULL,
                                             foret_ancienne = NULL,
                                             layers = NULL,
                                             column_name = "N2",
                                             weight_anciennete = TRUE,
                                             lang = "en") {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)

  result <- units

  # Resolve from layers if not provided directly
  if (is.null(bdforet) && !is.null(layers) && inherits(layers, "nemeton_layers")) {
    bdforet <- resolve_vector_layer(layers, "bdforet")
  }

  # If no forest data at all, return default score 50
  if (is.null(bdforet) && is.null(foret_ancienne)) {
    result[[column_name]] <- rep(50, nrow(units))
    cli::cli_alert_success("Calculated {column_name}: Forest continuity (default 50, no data)")
    return(result)
  }

  # Ensure matching CRS
  if (!is.null(bdforet) && inherits(bdforet, "sf") && nrow(bdforet) > 0) {
    bdforet <- sf::st_transform(bdforet, sf::st_crs(units))
    bdforet <- sf::st_make_valid(bdforet)
  } else {
    bdforet <- NULL
  }
  if (!is.null(foret_ancienne) && inherits(foret_ancienne, "sf") && nrow(foret_ancienne) > 0) {
    foret_ancienne <- sf::st_transform(foret_ancienne, sf::st_crs(units))
    foret_ancienne <- sf::st_make_valid(foret_ancienne)
  } else {
    foret_ancienne <- NULL
  }

  n2_scores <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    parcelle_area <- as.numeric(sf::st_area(units[i, ]))

    # Current forest coverage (taux_boisement)
    taux_boisement <- 0
    if (!is.null(bdforet)) {
      inter_foret <- suppressWarnings(
        tryCatch(sf::st_intersection(bdforet, sf::st_geometry(units[i, ])),
                 error = function(e) NULL)
      )
      if (!is.null(inter_foret) && nrow(inter_foret) > 0) {
        forest_area <- sum(as.numeric(sf::st_area(inter_foret)))
        taux_boisement <- min(1, forest_area / parcelle_area)
      }
    }

    # Ancient forest coverage (taux_anciennete)
    taux_ancienne <- 0
    if (!is.null(foret_ancienne)) {
      inter_ancienne <- suppressWarnings(
        tryCatch(sf::st_intersection(foret_ancienne, sf::st_geometry(units[i, ])),
                 error = function(e) NULL)
      )
      if (!is.null(inter_ancienne) && nrow(inter_ancienne) > 0) {
        areas <- as.numeric(sf::st_area(inter_ancienne))
        # Paliers d'ancienneté (spec 031) : quand la couche porte `anciennete`
        # (consolidation multi-époques, ex. Cassini + état-major), on pondère
        # par la profondeur du palier (forêt présente à + d'époques = plus
        # ancienne = compte davantage). Sinon : couverture binaire (historique).
        if (weight_anciennete && "anciennete" %in% names(inter_ancienne)) {
          max_tier <- max(foret_ancienne$anciennete, na.rm = TRUE)
          w <- if (is.finite(max_tier) && max_tier > 0) {
            inter_ancienne$anciennete / max_tier
          } else 1
          ancienne_area <- sum(areas * w)
        } else {
          ancienne_area <- sum(areas)
        }
        taux_ancienne <- min(1, ancienne_area / parcelle_area)
      }
    }

    # Score per tuto 04
    if (taux_ancienne > 0) {
      n2_scores[i] <- 60 + taux_ancienne * 40
    } else if (taux_boisement > 0) {
      n2_scores[i] <- 30 + taux_boisement * 30
    } else {
      n2_scores[i] <- 15
    }
  }

  result[[column_name]] <- n2_scores
  cli::cli_alert_success("Calculated {column_name}: Forest continuity (0-100)")
  return(result)
}

#' N3: Composite Naturalness Index
#'
#' Calculates a composite naturalness index following tuto 04:
#' N3 = 0.35 * N1 + 0.35 * N2 + 0.15 * (100 - L1) + 0.15 * B3
#' Falls back to 50 when L1 or B3 are unavailable.
#'
#' @param units sf object with N1 and N2 columns (optionally L1, B3)
#' @param column_name Character. Name for output column. Default "N3".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added column N3 (score 0-100)
#'
#' @export
indicateur_n3_naturalite <- function(units,
                                            column_name = "N3",
                                            lang = "en") {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)

  result <- units

  # Use existing columns or fallback to 50
  n1 <- if ("N1" %in% names(units)) units$N1 else rep(50, nrow(units))
  n2 <- if ("N2" %in% names(units)) units$N2 else rep(50, nrow(units))
  anti_frag <- if ("L1" %in% names(units)) 100 - units$L1 else rep(50, nrow(units))
  connectivite <- if ("B3" %in% names(units)) units$B3 else rep(50, nrow(units))

  # Tuto 04: 35% N1 + 35% N2 + 15% anti-fragmentation + 15% connectivity
  result[[column_name]] <- 0.35 * n1 + 0.35 * n2 + 0.15 * anti_frag + 0.15 * connectivite

  cli::cli_alert_success("Calculated {column_name}: Composite naturalness (0-100)")
  return(result)
}


# ==============================================================================
# Ancient-forest mask builder (feeds N2 continuity)  [spec 031]
# ==============================================================================

#' Build an ancient-forest polygon layer for N2 continuity
#'
#' Turns a historical forest source into the `foret_ancienne` polygon layer
#' consumed by [indicateur_n2_continuite()] (its `foret_ancienne` argument).
#' Two source forms are accepted:
#'
#' \itemize{
#'   \item an \pkg{sf}/\pkg{sfc} of already-vectorised ancient-forest
#'     polygons (e.g. a digitised Cassini / état-major map, or an IGN
#'     \dQuote{forêt ancienne} layer): it is validated, reprojected and
#'     optionally area-filtered, then returned.
#'   \item a \pkg{terra} SpatRaster historical forest map: a binary forest
#'     mask is derived — by class membership (`forest_class`), by threshold
#'     (`threshold`), or, failing both, as \code{value > 0} — then polygonised,
#'     split into contiguous patches, area-filtered and returned as polygons.
#'   \item a **named list** of several sources (each an sf/sfc/SpatRaster of a
#'     historical epoch, e.g. `list(cassini = ..., etatmajor = ...)`): each is
#'     normalised to forest and dissolved, then consolidated into a
#'     **non-overlapping tiered layer** with an integer `anciennete` column =
#'     the number of epochs covering each polygon (higher = older, stronger
#'     continuity) and an `epoques` label. Ready for the tier-weighted path of
#'     [indicateur_n2_continuite()].
#' }
#'
#' nemeton ships no French historical forest raster: the source is supplied
#' by the caller. Note that the Theia \code{corona-4b} collection is NOT a
#' usable source over France — it covers only the Middle East (spec 031); the
#' French sources are Cassini / état-major scans or IGN forêt-ancienne layers.
#'
#' @param source An sf/sfc of ancient-forest polygons, a terra SpatRaster
#'   historical forest map, or a named list of several such sources (multi-epoch
#'   consolidation).
#' @param forest_class Optional. Raster class value(s) that denote forest
#'   (used only when `source` is a SpatRaster). Selects the mask by
#'   membership.
#' @param threshold Optional numeric. Raster values \code{>= threshold} are
#'   forest (used only when `source` is a SpatRaster and `forest_class` is
#'   NULL) — e.g. a forest-probability or greenness index.
#' @param min_area_m2 Numeric. Drop contiguous patches smaller than this
#'   area (in the working CRS units, m² for a metric CRS). Default 0 = keep
#'   all.
#' @param crs Optional target CRS (anything accepted by [sf::st_transform()]).
#'   NULL (default) keeps the source CRS.
#'
#' @return An sf polygon layer with `foret_ancienne = TRUE`, ready to pass to
#'   `indicateur_n2_continuite(units, foret_ancienne = ...)`. For a list of
#'   sources it also carries `anciennete` (integer epoch-count tier) and
#'   `epoques` (the contributing epoch labels). May have 0 rows if no forest
#'   is found.
#'
#' @export
build_foret_ancienne_mask <- function(source,
                                      forest_class = NULL,
                                      threshold    = NULL,
                                      min_area_m2  = 0,
                                      crs          = NULL) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} is required.")
  }
  if (!is.numeric(min_area_m2) || length(min_area_m2) != 1L || min_area_m2 < 0) {
    cli::cli_abort("{.arg min_area_m2} must be a non-negative scalar.")
  }

  .finalise <- function(fa) {
    if (!is.null(crs)) fa <- sf::st_transform(fa, crs)
    if (min_area_m2 > 0 && nrow(fa) > 0) {
      fa <- suppressWarnings(sf::st_cast(fa, "POLYGON", warn = FALSE))
      keep <- as.numeric(sf::st_area(fa)) >= min_area_m2
      fa <- fa[keep, , drop = FALSE]
    }
    sf::st_sf(foret_ancienne = rep(TRUE, nrow(fa)),
              geometry = sf::st_geometry(fa))
  }

  # --- Multiple historical sources: tiered ancienneté (spec 031) ---
  # Consolidate several epochs (e.g. Cassini ~1750 + état-major ~1850): each
  # source is normalised to forest, dissolved, then a NON-overlapping planar
  # subdivision (`sf::st_intersection` self-overlay) yields `anciennete` = the
  # number of epochs covering each piece (higher = older, stronger continuity).
  if (is.list(source) &&
      !inherits(source, c("sf", "sfc", "SpatRaster", "data.frame"))) {
    if (!length(source)) cli::cli_abort("{.arg source} list is empty.")
    labels <- names(source)
    if (is.null(labels) || any(!nzchar(labels))) {
      labels <- paste0("epoque_", seq_along(source))
    }
    layers <- lapply(source, function(s)
      build_foret_ancienne_mask(s, forest_class = forest_class,
                                threshold = threshold, min_area_m2 = 0,
                                crs = NULL))
    nonempty <- Filter(function(x) nrow(x) > 0, layers)
    work_crs <- crs %||% (if (length(nonempty)) sf::st_crs(nonempty[[1]])
                          else sf::st_crs(layers[[1]]))
    geoms <- lapply(seq_along(layers), function(i) {
      L <- layers[[i]]
      if (nrow(L) == 0) return(NULL)
      g <- sf::st_union(sf::st_geometry(sf::st_transform(L, work_crs)))
      sf::st_sf(epoque = labels[i], geometry = g)
    })
    geoms <- Filter(Negate(is.null), geoms)
    if (!length(geoms)) {
      return(sf::st_sf(foret_ancienne = logical(0), anciennete = integer(0),
                       epoques = character(0), geometry = sf::st_sfc(crs = work_crs)))
    }
    stacked <- do.call(rbind, geoms)
    ov <- suppressWarnings(sf::st_intersection(stacked))
    ov <- sf::st_make_valid(ov)
    ov <- suppressWarnings(sf::st_collection_extract(ov, "POLYGON"))
    ov <- ov[!sf::st_is_empty(ov), , drop = FALSE]
    epoques <- vapply(ov$origins,
                      function(ix) paste(stacked$epoque[ix], collapse = "+"),
                      character(1))
    out <- sf::st_sf(foret_ancienne = rep(TRUE, nrow(ov)),
                     anciennete = as.integer(ov$n.overlaps),
                     epoques = epoques,
                     geometry = sf::st_geometry(ov))
    if (min_area_m2 > 0 && nrow(out) > 0) {
      out <- suppressWarnings(sf::st_cast(out, "POLYGON", warn = FALSE))
      out <- out[as.numeric(sf::st_area(out)) >= min_area_m2, , drop = FALSE]
    }
    return(out)
  }

  # --- Vector source: already-vectorised ancient forest ---
  if (inherits(source, c("sf", "sfc"))) {
    fa <- sf::st_make_valid(sf::st_as_sf(source))
    return(.finalise(fa))
  }

  # --- Raster source: derive a binary forest mask, polygonise ---
  if (inherits(source, "SpatRaster")) {
    if (!requireNamespace("terra", quietly = TRUE)) {
      cli::cli_abort("Package {.pkg terra} is required for a raster source.")
    }
    r <- source[[1]]
    m <- if (!is.null(forest_class)) {
      terra::ifel(r %in% forest_class, 1L, NA)
    } else if (!is.null(threshold)) {
      terra::ifel(r >= threshold, 1L, NA)
    } else {
      # No class/threshold: treat the raster as a 0/nodata forest mask.
      terra::ifel(r > 0, 1L, NA)
    }
    polys <- terra::as.polygons(m, dissolve = TRUE)
    if (length(polys) == 0L) {
      return(sf::st_sf(foret_ancienne = logical(0),
                       geometry = sf::st_sfc(crs = crs %||% terra::crs(r))))
    }
    return(.finalise(sf::st_as_sf(polys)))
  }

  cli::cli_abort("{.arg source} must be an sf/sfc object or a terra SpatRaster.")
}
