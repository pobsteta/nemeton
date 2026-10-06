#' Social & Recreational Services Indicators (Family S)
#'
#' Functions for calculating social and recreational use indicators:
#' - S1: Distance to roads (accessibility via road network)
#' - S2: Distance to buildings (proximity to built areas)
#' - S3: Population proximity (visitor pressure potential)
#'
#' @name indicators-social
#' @keywords internal
#' @family indicators
NULL

#' S1: Distance to Roads Indicator
#'
#' Calculates the mean distance (in metres) from each spatial unit to the
#' nearest road, using rasterized road data and \code{terra::distance()}.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param roads sf object (LINESTRING) of road network. If NULL, resolved from layers.
#' @param dem SpatRaster. Digital elevation model used as reference grid.
#'   If NULL, resolved from layers.
#' @param layers A nemeton_layers object (optional). Used to resolve roads/dem
#'   when not provided directly.
#' @param column_name Character. Name for output column. Default "S1".
#' @param dem_target_res Numeric. Working resolution (metres) the DEM grid is
#'   aggregated to before roads are rasterised and the distance transform runs.
#'   The DEM is only a grid template here, and a 0.5-1 m LiDAR HD MNT makes that
#'   transform cost gigabytes for a mean distance per unit. Default: the
#'   package-wide topographic working resolution, 2 m — see
#'   \code{options("nemeton.topo_target_res")}; \code{NULL} keeps the native
#'   resolution.
#' @param max_dist Numeric. Search radius (metres) around the units, default
#'   2000 m (the distance at which the normalised score reaches 0). The
#'   working grid covers the units' extent widened by `max_dist`, not the DEM
#'   extent, so features just outside the DEM are no longer ignored. Distances
#'   are exact up to `max_dist` and censored at `max_dist` beyond (a unit
#'   with no feature within `max_dist` gets `max_dist`, i.e. "at least
#'   `max_dist`"); with no feature at all, the indicator is `NA`.
#'
#' @return sf object with added column: S1 (mean distance to nearest road in metres)
#'
#' @details
#' **Calculation** (tuto 03 method):
#' \itemize{
#'   \item Rasterize road geometries onto a grid with the DEM resolution,
#'     covering the units' extent widened by \code{max_dist}
#'   \item Compute distance raster via \code{terra::distance()}, censored at
#'     \code{max_dist}
#'   \item Extract mean distance per spatial unit
#' }
#'
#' Returns NA when DEM or roads are unavailable.
#'
#' @export
#' @examples
#' \dontrun{
#' result <- indicateur_s1_routes(
#'   units = parcels,
#'   roads = roads_sf,
#'   dem = dem_raster
#' )
#' }
indicateur_s1_routes <- function(units,
                                    roads = NULL,
                                    dem = NULL,
                                    layers = NULL,
                                    column_name = "S1",
                                    dem_target_res = .topo_target_res(),
                                    max_dist = 2000) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  # Resolve roads from layers if not provided
 if (is.null(roads) && !is.null(layers)) {
    roads <- resolve_vector_layer(layers, "roads")
  }

  # Resolve DEM from layers if not provided
  if (is.null(dem) && !is.null(layers)) {
    dem <- resolve_raster_layer(layers, "dem")
    if (is.null(dem)) dem <- resolve_raster_layer(layers, "lidar_mnt")
  }

  # Répare un éventuel CRS LiDAR HD dégénéré (« EPSG:2154 » sans autorité) avant
  # tout st_transform/rasterize, sinon terra rejette (« CRS do not match ») et S1
  # rend NA — même correctif que R1/R2/R3/W3 (indicators-risk.R, v0.138.1).
  dem <- .normalize_crs(dem)
  # Le MNT ne sert ici que de grille : rasteriser les routes puis calculer une
  # transformée de distance sur 120 M cellules de LiDAR HD coûte des Go pour une
  # distance moyenne par unité (cf. .dem_working_res).
  dem <- .dem_working_res(dem, target_res = dem_target_res, context = "S1")

  result <- units

  # Fallback: no DEM or no roads → NA
  if (is.null(dem) || is.null(roads) || nrow(roads) == 0) {
    cli::cli_alert_warning("S1: DEM or roads unavailable, returning NA")
    result[[column_name]] <- rep(NA_real_, nrow(units))
    return(result)
  }

  .check_max_dist(max_dist)
  result[[column_name]] <- .distance_moyenne_entites(units, roads, dem,
                                                     max_dist, "S1")

  cli::cli_alert_success("Calculated {column_name}: Distance to roads (m)")

  return(result)
}

#' S2: Distance to Buildings Indicator
#'
#' Calculates the mean distance (in metres) from each spatial unit to the
#' nearest building, using rasterized building data and \code{terra::distance()}.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param buildings sf object (POLYGON) of buildings. If NULL, resolved from layers.
#' @param dem SpatRaster. Digital elevation model used as reference grid.
#'   If NULL, resolved from layers.
#' @param layers A nemeton_layers object (optional). Used to resolve buildings/dem
#'   when not provided directly.
#' @param column_name Character. Name for output column. Default "S2".
#' @param dem_target_res Numeric. Working resolution (metres) the DEM grid is
#'   aggregated to before buildings are rasterised and the distance transform
#'   runs. The DEM is only a grid template here, and a 0.5-1 m LiDAR HD MNT makes
#'   that transform cost gigabytes for a mean distance per unit. Default: the
#'   package-wide topographic working resolution, 2 m — see
#'   \code{options("nemeton.topo_target_res")}; \code{NULL} keeps the native
#'   resolution.
#' @param max_dist Numeric. Search radius (metres) around the units, default
#'   2000 m (the distance at which the normalised score reaches 0). The
#'   working grid covers the units' extent widened by `max_dist`, not the DEM
#'   extent, so features just outside the DEM are no longer ignored. Distances
#'   are exact up to `max_dist` and censored at `max_dist` beyond (a unit
#'   with no feature within `max_dist` gets `max_dist`, i.e. "at least
#'   `max_dist`"); with no feature at all, the indicator is `NA`.
#'
#' @return sf object with added column: S2 (mean distance to nearest building in metres)
#'
#' @details
#' **Calculation** (tuto 03 method):
#' \itemize{
#'   \item Rasterize building geometries onto a grid with the DEM resolution,
#'     covering the units' extent widened by \code{max_dist}
#'   \item Compute distance raster via \code{terra::distance()}, censored at
#'     \code{max_dist}
#'   \item Extract mean distance per spatial unit
#' }
#'
#' Returns NA when DEM or buildings are unavailable.
#'
#' @export
#' @examples
#' \dontrun{
#' result <- indicateur_s2_bati(
#'   units = parcels,
#'   buildings = buildings_sf,
#'   dem = dem_raster
#' )
#' }
indicateur_s2_bati <- function(units,
                                           buildings = NULL,
                                           dem = NULL,
                                           layers = NULL,
                                           column_name = "S2",
                                           dem_target_res = .topo_target_res(),
                                           max_dist = 2000) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  # Resolve buildings from layers if not provided
  if (is.null(buildings) && !is.null(layers)) {
    buildings <- resolve_vector_layer(layers, "buildings")
  }

  # Resolve DEM from layers if not provided
  if (is.null(dem) && !is.null(layers)) {
    dem <- resolve_raster_layer(layers, "dem")
    if (is.null(dem)) dem <- resolve_raster_layer(layers, "lidar_mnt")
  }

  # Répare un éventuel CRS LiDAR HD dégénéré (« EPSG:2154 » sans autorité) avant
  # tout st_transform/rasterize, sinon terra rejette (« CRS do not match ») et S2
  # rend NA — même correctif que R1/R2/R3/W3 (indicators-risk.R, v0.138.1).
  dem <- .normalize_crs(dem)
  # Grille de travail bornée, comme S1 : la transformée de distance sur le bâti
  # se fait sur la même grille que la rasterisation (cf. .dem_working_res).
  dem <- .dem_working_res(dem, target_res = dem_target_res, context = "S2")

  result <- units

  # Fallback: no DEM or no buildings → NA
  if (is.null(dem) || is.null(buildings) || nrow(buildings) == 0) {
    cli::cli_alert_warning("S2: DEM or buildings unavailable, returning NA")
    result[[column_name]] <- rep(NA_real_, nrow(units))
    return(result)
  }

  .check_max_dist(max_dist)
  result[[column_name]] <- .distance_moyenne_entites(units, buildings, dem,
                                                     max_dist, "S2")

  cli::cli_alert_success("Calculated {column_name}: Distance to buildings (m)")

  return(result)
}

# Distance moyenne de chaque unite a l'entite la plus proche (routes, bati).
#
# Le MNT ne fournit que la resolution et le CRS de travail. Le gabarit couvre
# l'emprise des unites elargie de `max_dist`, et non l'emprise du MNT : une
# route ou un batiment juste hors du MNT etait ignore, d'ou un S1/S2 NA ou
# surestime pour les unites de bordure. Toute entite hors de cette fenetre
# est a plus de `max_dist` de chaque unite ; les distances sont donc exactes
# jusqu'a `max_dist` et censurees a `max_dist` au-dela (la normalisation
# sature de toute facon a 2000 m). Une couche non vide sans entite dans la
# fenetre dit que l'entite la plus proche est a plus de `max_dist` : valeur
# censuree a `max_dist` (et non NA, qui ferait passer un score certain de 0
# pour une donnee manquante). Une couche vide est traitee en amont (NA).
.distance_moyenne_entites <- function(units, entites, dem, max_dist, code) {
  crs_d <- terra::crs(dem)
  units_d <- sf::st_transform(as_pure_sf(units), crs_d)
  bb <- sf::st_bbox(units_d)
  marge_x <- marge_y <- max_dist
  if (isTRUE(terra::is.lonlat(dem))) {
    # Grille en degres : marge convertie a la latitude de l'emprise.
    lat <- mean(c(bb[["ymin"]], bb[["ymax"]]))
    marge_y <- max_dist / 111320
    marge_x <- max_dist / (111320 * max(cos(lat * pi / 180), 0.01))
  }
  fenetre <- terra::ext(bb[["xmin"]] - marge_x, bb[["xmax"]] + marge_x,
                        bb[["ymin"]] - marge_y, bb[["ymax"]] + marge_y)
  fenetre <- terra::align(fenetre, dem, snap = "out")
  gabarit <- terra::rast(fenetre, resolution = terra::res(dem), crs = crs_d)

  entites_r <- safe_rasterize(entites, gabarit, field = 1, background = NA)
  if (!isTRUE(terra::global(entites_r, "notNA")[1, 1] > 0)) {
    cli::cli_alert_info(
      "{code}: no feature within {max_dist} m of the units, distance censored at {max_dist} m"
    )
    return(rep(as.numeric(max_dist), nrow(units)))
  }
  d <- terra::distance(entites_r)
  d <- terra::clamp(d, upper = max_dist, values = TRUE)
  as.numeric(safe_extract(d, units, fun = "mean", progress = FALSE))
}

.check_max_dist <- function(max_dist) {
  if (!is.numeric(max_dist) || length(max_dist) != 1L || is.na(max_dist) ||
      max_dist <= 0) {
    cli::cli_abort("{.arg max_dist} must be a single positive number (metres).")
  }
  invisible(max_dist)
}

#' S3: Population Proximity Indicator
#'
#' Calculates the population density around each unit (and population counts
#' within buffer zones of 5, 10 and 20 km) to estimate visitor pressure
#' potential and recreational use intensity.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param population_grid sf object (polygons carrying a population count) or
#'   SpatRaster of population counts. If NULL, S3 is NA (no measurement).
#' @param method Character. `"insee"` (default) or `"local"`: both read
#'   `population_grid` the same way (the label is informative). `"proxy"` no
#'   longer exists and raises an error.
#' @param buffer_radii Numeric vector. Buffer distances (m) for population counts. Default c(5000, 10000, 20000).
#' @param column_name Character. Name for output column (main indicator). Default "S3".
#'
#' @param population_field Character or `NULL`. Name of the population column of
#'   `population_grid` when it is an `sf`. `NULL` (default) looks for `ind`,
#'   `pop` or `population` (INSEE Filosofi names it `ind`).
#' @return sf object with added columns: `S3` (named after `column_name`,
#'   population density in inhabitants/km2 within the first buffer),
#'   `S3_densite` (same value), and the population counts `S3_5km`,
#'   `S3_10km`, `S3_20km` within the three buffers of `buffer_radii` (the
#'   names are kept whatever the radii). Without `population_grid`, `S3` and
#'   the counts are NA and `S3_densite` is not added.
#'
#' @details
#' **Calculation**:
#' \itemize{
#'   \item Create buffer zones around each unit (`buffer_radii`, default
#'     5, 10 and 20 km)
#'   \item Sum the population within each buffer; a grid cell straddling the
#'     buffer counts for the share of its area inside it
#'   \item S3 = population of the first buffer / its area (inhabitants/km2)
#' }
#'
#' **Data Sources**:
#' \itemize{
#'   \item INSEE Filosofi gridded population, 200 m or 1 km cells (France;
#'     count field `ind`)
#'   \item WorldPop or GPW for international applications
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' data(massif_demo_units)
#' carreaux <- sf::st_read("path/to/filosofi_carreaux_200m.gpkg")
#' result <- indicateur_s3_population(
#'   units = massif_demo_units,
#'   population_grid = carreaux,
#'   buffer_radii = c(5000, 10000, 20000)
#' )
#' }
indicateur_s3_population <- function(units,
                                       population_grid = NULL,
                                       population_field = NULL,
                                       method = c("insee", "local", "proxy"),
                                       buffer_radii = c(5000, 10000, 20000),
                                       column_name = "S3") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }

  method <- match.arg(method)

  # `"proxy"` etait le nom du chemin fabrique : il rendait
  # `surface_du_tampon x 100 hab/km2` sans jamais lire de grille. Le retirer
  # des choix aurait fait tomber les appels existants sur un `match.arg`
  # cryptique ; il est donc conserve pour DIRE ce qui a change, une fois.
  if (identical(method, "proxy")) {
    cli::cli_abort(c(
      "{.val proxy} no longer exists: it never read a population grid.",
      i = "It returned buffer area x 100 inhabitants/km2 \u2014 a number that varied \\
           plausibly with unit size and therefore looked measured.",
      i = "Pass a {.arg population_grid} (INSEE Filosofi carreaux carry {.field ind}), \\
           or omit {.arg method} to get {.val NA} where nothing can be measured."
    ))
  }

  result <- units

  # Sans grille de population, S3 n'est pas mesurable.
  #
  # Jusqu'a la v0.187.0, cette fonction n'a JAMAIS lu son `population_grid` :
  # elle rendait `surface_du_tampon x 100 hab/km2`, avec ses propres
  # commentaires pour l'avouer (« Placeholder calculation », « In production,
  # would query INSEE Carroyage »). Le resultat variait plausiblement avec la
  # taille de l'UGF, donc ressemblait a une population mesuree — et pesait dans
  # la moyenne de la famille Social & Usages. C'est la forme la plus couteuse
  # d'une valeur fabriquee : celle qui ne se voit pas.
  #
  # Source attendue : INSEE Filosofi, carreaux 200 m ou 1 km (GeoPackage,
  # variable `ind` = nombre d'individus, carroyage INSPIRE en EPSG:3035 — le
  # CRS de l'ADR-008). Ou tout `sf`/`SpatRaster` portant un comptage.
  if (is.null(population_grid)) {
    cli::cli_alert_info(
      "{column_name}: no population grid provided, returning NA \\
       (no measurement made). Supply INSEE Filosofi carreaux, or any layer \\
       carrying a population count."
    )
    na <- rep(NA_real_, nrow(units))
    result$S3_5km <- na
    result$S3_10km <- na
    result$S3_20km <- na
    result[[column_name]] <- na
    return(result)
  }

  # Somme de population dans un tampon. Deux portages de grille acceptes :
  # un `sf` de carreaux (INSEE) pondere par la part de carreau intersectee,
  # un `SpatRaster` de comptage somme par `exactextractr`.
  .s3_somme <- function(buffers) {
    if (inherits(population_grid, "SpatRaster")) {
      if (!requireNamespace("exactextractr", quietly = TRUE)) {
        cli::cli_abort("{.pkg exactextractr} is required to read a raster population grid.")
      }
      b <- sf::st_transform(buffers, sf::st_crs(terra::crs(population_grid)))
      return(as.numeric(exactextractr::exact_extract(population_grid, b, "sum",
                                                     progress = FALSE)))
    }
    if (!inherits(population_grid, "sf")) {
      cli::cli_abort("{.arg population_grid} must be an {.cls sf} or a {.cls SpatRaster}.")
    }
    champ <- population_field %||%
      intersect(c("ind", "pop", "population", "POP", "Ind", "IND"),
                names(population_grid))[1]
    if (is.na(champ) || is.null(champ) || !(champ %in% names(population_grid))) {
      cli::cli_abort(c(
        "No population column found in {.arg population_grid}.",
        i = "INSEE Filosofi names it {.field ind}; name yours with {.arg population_field}."
      ))
    }
    grille <- sf::st_transform(population_grid, sf::st_crs(buffers))
    aire_carreau <- as.numeric(sf::st_area(grille))
    # Identifiant de ligne porte a travers l'intersection : le carreau etait
    # retrouve par sa VALEUR de population, donc deux carreaux de meme effectif
    # se confondaient (audit 1.0).
    grille$.s3_row <- seq_len(nrow(grille))
    vapply(seq_len(nrow(buffers)), function(i) {
      inter <- suppressWarnings(sf::st_intersection(grille, buffers[i, ]))
      if (nrow(inter) == 0L) return(0)
      # Part de chaque carreau reellement dans le tampon : un carreau a cheval
      # ne compte pas pour sa population entiere.
      idx <- inter$.s3_row
      part <- as.numeric(sf::st_area(inter)) /
        ifelse(is.na(idx), NA_real_, aire_carreau[idx])
      part[!is.finite(part)] <- 1
      sum(as.numeric(sf::st_drop_geometry(inter)[[champ]]) * pmin(part, 1),
          na.rm = TRUE)
    }, numeric(1))
  }

  buffer_5km <- sf::st_buffer(units, dist = buffer_radii[1])
  buffer_10km <- sf::st_buffer(units, dist = buffer_radii[2])
  buffer_20km <- sf::st_buffer(units, dist = buffer_radii[3])

  pop_5km <- round(.s3_somme(buffer_5km))
  pop_10km <- round(.s3_somme(buffer_10km))
  pop_20km <- round(.s3_somme(buffer_20km))

  # Add to result
  result$S3_5km <- pop_5km
  result$S3_10km <- pop_10km
  result$S3_20km <- pop_20km

  # S3 = DENSITE dans la couronne d'accessibilite, pas comptage brut.
  #
  # Un effectif ne se compare pas d'un massif a l'autre : le tampon grandit
  # avec l'UGF, donc un grand massif rural totalise plus d'habitants qu'un
  # petit bois periurbain, ce qui inverse le sens de « pression sociale ».
  # Pire, la normalisation historique saturait a 10 000 habitants — mesure sur
  # Couchey : 46 110 habitants dans 5 km, soit un score de 100/100 pour un
  # massif de bourgogne rurale. Presque toute foret francaise y serait a 100.
  #
  # La densite (hab/km2) est comparable, ne sature pas, et dit ce que
  # l'indicateur pretend dire. Couchey : 297 hab/km2, 2,8 fois la moyenne
  # francaise (106). Les effectifs restent en colonnes compagnes : ce sont eux
  # qu'un gestionnaire cite dans un document.
  aire_5km_km2 <- as.numeric(sf::st_area(buffer_5km)) / 1e6
  result$S3_densite <- ifelse(aire_5km_km2 > 0, pop_5km / aire_5km_km2, NA_real_)
  result[[column_name]] <- result$S3_densite

  msg_info("social_population_calculated",
           as.integer(stats::median(pop_5km, na.rm = TRUE)),
           as.integer(stats::median(pop_10km, na.rm = TRUE)),
           as.integer(stats::median(pop_20km, na.rm = TRUE)))
  cli::cli_alert_success(
    "Calculated {column_name}: population density in the 5 km ring \
     (median {round(stats::median(result$S3_densite, na.rm = TRUE))} inhab/km2)"
  )
  result
}
