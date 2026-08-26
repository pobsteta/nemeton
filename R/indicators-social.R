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
#' @param lang Character. Message language ("en" or "fr"). Default "en".
#' @param dem_target_res Numeric. Working resolution (metres) the DEM grid is
#'   aggregated to before roads are rasterised and the distance transform runs.
#'   The DEM is only a grid template here, and a 0.5-1 m LiDAR HD MNT makes that
#'   transform cost gigabytes for a mean distance per unit. Default: the
#'   package-wide topographic working resolution, 2 m — see
#'   \code{options("nemeton.topo_target_res")}; \code{NULL} keeps the native
#'   resolution.
#'
#' @return sf object with added column: S1 (mean distance to nearest road in metres)
#'
#' @details
#' **Calculation** (tuto 03 method):
#' \itemize{
#'   \item Rasterize road geometries onto the DEM grid
#'   \item Compute distance raster via \code{terra::distance()}
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
                                    lang = "en",
                                    dem_target_res = .topo_target_res()) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
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

  # Rasterize roads onto DEM grid
  roads_vect <- terra::vect(sf::st_transform(roads, terra::crs(dem)))
  roads_rast <- terra::rasterize(roads_vect, dem, field = 1, background = NA)

  # Compute distance to nearest road (metres)
  s1_raster <- terra::distance(roads_rast)

  # Extract mean distance per unit
  s1_values <- safe_extract(s1_raster, units, fun = "mean", progress = FALSE)

  result[[column_name]] <- as.numeric(s1_values)

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
#' @param lang Character. Message language. Default "en".
#' @param dem_target_res Numeric. Working resolution (metres) the DEM grid is
#'   aggregated to before buildings are rasterised and the distance transform
#'   runs. The DEM is only a grid template here, and a 0.5-1 m LiDAR HD MNT makes
#'   that transform cost gigabytes for a mean distance per unit. Default: the
#'   package-wide topographic working resolution, 2 m — see
#'   \code{options("nemeton.topo_target_res")}; \code{NULL} keeps the native
#'   resolution.
#'
#' @return sf object with added column: S2 (mean distance to nearest building in metres)
#'
#' @details
#' **Calculation** (tuto 03 method):
#' \itemize{
#'   \item Rasterize building geometries onto the DEM grid
#'   \item Compute distance raster via \code{terra::distance()}
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
                                           lang = "en",
                                           dem_target_res = .topo_target_res()) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
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

  # Rasterize buildings onto DEM grid
  bat_vect <- terra::vect(sf::st_transform(buildings, terra::crs(dem)))
  bat_rast <- terra::rasterize(bat_vect, dem, field = 1, background = NA)

  # Compute distance to nearest building (metres)
  s2_raster <- terra::distance(bat_rast)

  # Extract mean distance per unit
  s2_values <- safe_extract(s2_raster, units, fun = "mean", progress = FALSE)

  result[[column_name]] <- as.numeric(s2_values)

  cli::cli_alert_success("Calculated {column_name}: Distance to buildings (m)")

  return(result)
}

#' S3: Population Proximity Indicator
#'
#' Calculates population counts within buffer zones (5km, 10km, 20km) to estimate
#' visitor pressure potential and recreational use intensity.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param population_grid sf object or SpatRaster of population data. If NULL, uses proxy.
#' @param method Character. Data source: "insee" (INSEE Carroyage), "local", or "proxy". Default "proxy".
#' @param buffer_radii Numeric vector. Buffer distances (m) for population counts. Default c(5000, 10000, 20000).
#' @param column_name Character. Name for output column (main indicator). Default "S3".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added columns: S3 (population within primary buffer), S3_5km, S3_10km, S3_20km
#'
#' @details
#' **Calculation**:
#' \itemize{
#'   \item Create buffer zones around each unit (5km, 10km, 20km)
#'   \item Sum population within each buffer from INSEE Carroyage 1km grid
#'   \item S3 = population within closest buffer (highest pressure)
#' }
#'
#' **Data Sources**:
#' \itemize{
#'   \item INSEE Carroyage 1km or 200m population grids (France)
#'   \item WorldPop or GPW for international applications
#'   \item Proxy: Distance to nearest urban area if no population data
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' data(massif_demo_units)
#' result <- indicateur_s3_population(
#'   units = massif_demo_units,
#'   method = "proxy",
#'   buffer_radii = c(5000, 10000, 20000)
#' )
#' }
indicateur_s3_population <- function(units,
                                       population_grid = NULL,
                                       population_field = NULL,
                                       method = c("insee", "local", "proxy"),
                                       buffer_radii = c(5000, 10000, 20000),
                                       column_name = "S3",
                                       lang = "en") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  method <- match.arg(method)

  # `"proxy"` etait le nom du chemin fabrique : il rendait
  # `surface_du_tampon x 100 hab/km2` sans jamais lire de grille. Le retirer
  # des choix aurait fait tomber les appels existants sur un `match.arg`
  # cryptique ; il est donc conserve pour DIRE ce qui a change, une fois.
  if (identical(method, "proxy")) {
    cli::cli_abort(c(
      "{.val proxy} no longer exists: it never read a population grid.",
      i = "It returned buffer area x 100 inhabitants/km2 — a number that varied \\
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
    vapply(seq_len(nrow(buffers)), function(i) {
      inter <- suppressWarnings(sf::st_intersection(grille, buffers[i, ]))
      if (nrow(inter) == 0L) return(0)
      # Part de chaque carreau reellement dans le tampon : un carreau a cheval
      # ne compte pas pour sa population entiere.
      idx <- match(
        sf::st_drop_geometry(inter)[[champ]], sf::st_drop_geometry(grille)[[champ]])
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
  result[[column_name]] <- pop_5km # Primary indicator is 5km buffer

  msg_info("social_population_calculated", as.integer(median(pop_5km)), as.integer(median(pop_10km)), as.integer(median(pop_20km)))

  cli::cli_alert_success("Calculated {column_name}: Population proximity (5/10/20km buffers)")

  return(result)
}
