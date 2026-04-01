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
#' @param foret_ancienne sf object. Historical forest cover (~1850). NULL = only use bdforet.
#' @param layers nemeton_layers object. Used to resolve bdforet if not provided directly.
#' @param column_name Character. Name for output column. Default "N2".
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
        ancienne_area <- sum(as.numeric(sf::st_area(inter_ancienne)))
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
