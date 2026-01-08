# data-hunting.R
# Hunting Statistics Data Acquisition for Game Pressure Indicator (R4)
# Data source: data.gouv.fr - Tableaux de chasse departementaux

#' @importFrom utils read.csv download.file
#' @keywords internal
NULL

# ==============================================================================
# Data source URLs (data.gouv.fr - OFB/ONCFS)
# ==============================================================================

#' URLs for hunting statistics datasets (data.gouv.fr - OFB)
#' Updated 2025-06-05 with all 8 large game species
#' @noRd
HUNTING_DATA_URLS <- list(

  # Principal browsers - high impact on forest regeneration

  chevreuil = "https://static.data.gouv.fr/resources/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973/20250605-140029/chevreuil-departement.csv",
  cerf = "https://static.data.gouv.fr/resources/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973/20250605-140037/cerf-elaphe-departement.csv",
  sanglier = "https://static.data.gouv.fr/resources/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973/20250605-140017/sanglier-departement.csv",


  # Mountain ungulates - localized impact

  chamois = "https://static.data.gouv.fr/resources/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973/20250605-140032/chamois-departement.csv",
  isard = "https://static.data.gouv.fr/resources/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973/20250605-140024/isard-departement.csv",
  mouflon = "https://static.data.gouv.fr/resources/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973/20250605-140020/mouflon-departement.csv",

  # Other deer species

  daim = "https://static.data.gouv.fr/resources/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973/20250605-140026/daim-departement.csv",
  cerf_sika = "https://static.data.gouv.fr/resources/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973/20250605-140034/cerf-sika-departement.csv"
)

# ==============================================================================
# Download and Process Hunting Data
# ==============================================================================

#' Download Hunting Statistics from data.gouv.fr
#'
#' Downloads departmental hunting harvest statistics (tableaux de chasse) for
#' major game species from the French open data portal.
#'
#' @param species Character vector. Species to download: "chevreuil" (roe deer),
#'   "cerf" (red deer), "sanglier" (wild boar), or "all" (default).
#' @param cache_dir Character. Directory to cache downloaded files.
#'   Default uses rappdirs::user_cache_dir("nemeton").
#' @param force_download Logical. Force re-download even if cached. Default FALSE.
#'
#' @return A data.frame with columns:
#'   \itemize{
#'     \item code_dept: Department code (01-95, 2A, 2B, 971-976)
#'     \item nom_dept: Department name
#'     \item espece: Species name
#'     \item saison: Hunting season (e.g., "2022-2023")
#'     \item tableau: Number of animals harvested
#'   }
#'
#' @details
#' Data source: Office Francais de la Biodiversite (OFB), formerly ONCFS.
#' URL: https://www.data.gouv.fr/datasets/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973
#'
#' The hunting statistics provide a proxy for local game population density.
#' Higher harvest numbers generally indicate higher population pressure.
#'
#' @family data-acquisition
#' @export
#'
#' @examples
#' \dontrun{
#' # Download roe deer statistics
#' chevreuil_data <- download_hunting_data(species = "chevreuil")
#'
#' # Download all species
#' all_data <- download_hunting_data(species = "all")
#'
#' # Get latest season for department 33 (Gironde)
#' gironde <- subset(all_data, code_dept == "33")
#' }
download_hunting_data <- function(species = "all",
                                   cache_dir = NULL,
                                   force_download = FALSE) {
  # Set cache directory

  if (is.null(cache_dir)) {
    if (requireNamespace("rappdirs", quietly = TRUE)) {
      cache_dir <- file.path(rappdirs::user_cache_dir("nemeton"), "hunting_data")
    } else {
      cache_dir <- file.path(tempdir(), "nemeton_hunting_data")
    }
  }

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  # Determine species to download

  if ("all" %in% species) {
    species <- names(HUNTING_DATA_URLS)
  }

  # Validate species

  valid_species <- intersect(species, names(HUNTING_DATA_URLS))
  if (length(valid_species) == 0) {
    stop("No valid species specified. Use: ", paste(names(HUNTING_DATA_URLS), collapse = ", "),
         call. = FALSE)
  }

  # Download and combine data
  all_data <- list()

  for (sp in valid_species) {
    cache_file <- file.path(cache_dir, paste0(sp, "_tableaux_chasse.csv"))

    # Download if needed
    if (!file.exists(cache_file) || force_download) {
      cli::cli_alert_info("Downloading hunting data for {sp}...")

      tryCatch({
        download.file(
          url = HUNTING_DATA_URLS[[sp]],
          destfile = cache_file,
          mode = "wb",
          quiet = TRUE
        )
        cli::cli_alert_success("Downloaded {sp} data")
      }, error = function(e) {
        cli::cli_alert_warning("Failed to download {sp}: {e$message}")
        return(NULL)
      })
    }

    # Read data
    if (file.exists(cache_file)) {
      tryCatch({
        # Try different encodings and separators
        data <- tryCatch({
          read.csv(cache_file, stringsAsFactors = FALSE, encoding = "UTF-8")
        }, error = function(e) {
          read.csv(cache_file, stringsAsFactors = FALSE, encoding = "latin1", sep = ";")
        })

        # Standardize column names
        data <- standardize_hunting_columns(data, sp)

        if (nrow(data) > 0) {
          all_data[[sp]] <- data
        }
      }, error = function(e) {
        cli::cli_alert_warning("Failed to read {sp} data: {e$message}")
      })
    }
  }

  # Combine all species
  if (length(all_data) > 0) {
    result <- do.call(rbind, all_data)
    rownames(result) <- NULL
    return(result)
  } else {
    warning("No hunting data could be downloaded", call. = FALSE)
    return(NULL)
  }
}

#' Standardize Hunting Data Column Names
#' @noRd
standardize_hunting_columns <- function(data, species_name) {
  # Common column name patterns (data.gouv.fr format 2025)
  col_patterns <- list(
    code_dept = c("dept", "code_dept", "departement", "code"),
    nom_dept = c("nom_dept", "nom", "libelle", "nom_departement"),
    saison = c("annee", "saison", "campagne", "year", "an"),
    tableau = c("prelevements", "tableau", "realisations", "nb", "nombre", "count", "total")
  )

  # Find and rename columns
  new_names <- names(data)

  for (std_name in names(col_patterns)) {
    for (pattern in col_patterns[[std_name]]) {
      matches <- grep(pattern, names(data), ignore.case = TRUE)
      if (length(matches) > 0) {
        new_names[matches[1]] <- std_name
        break
      }
    }
  }

  names(data) <- new_names

  # Add species column
  data$espece <- species_name

  # Select and return standard columns
  std_cols <- c("code_dept", "nom_dept", "espece", "saison", "tableau")
  available_cols <- intersect(std_cols, names(data))

  if (length(available_cols) >= 3) {
    return(data[, available_cols, drop = FALSE])
  } else {
    return(data)
  }
}

# ==============================================================================
# Compute Game Pressure Index
# ==============================================================================

#' Compute Game Browsing Pressure Index by Department
#'
#' Calculates a browsing pressure index (0-100) for each department based on
#' hunting harvest statistics. Higher values indicate higher game populations
#' and thus higher browsing pressure on forests.
#'
#' @param hunting_data Data.frame from \code{\link{download_hunting_data}}, or NULL
#'   to download automatically.
#' @param season Character. Hunting season to use (e.g., "2022-2023").
#'   Default "latest" uses most recent available.
#' @param weights Named numeric vector. Weights for species contribution to
#'   browsing pressure. Default weights reflect relative forest impact:
#'   chevreuil (0.30), cerf (0.25), sanglier (0.15), chamois (0.08),
#'   mouflon (0.07), daim (0.06), isard (0.05), cerf_sika (0.04).
#' @param normalize_by Character. How to normalize harvest numbers:
#'   "area" (per km2 of forest, requires dept_forest_area), "rank" (percentile rank),
#'   or "minmax" (min-max scaling). Default "rank".
#' @param dept_forest_area Named numeric vector. Forest area (km2) by department code.
#'   Only needed if normalize_by = "area". If NULL, uses built-in estimates.
#'
#' @return A data.frame with columns:
#'   \itemize{
#'     \item code_dept: Department code
#'     \item nom_dept: Department name
#'     \item pressure_index: Browsing pressure index (0-100)
#'     \item <species>_harvest: Harvest count for each species present
#'   }
#'
#' @details
#' The pressure index combines harvest statistics for 8 large game species
#' affecting forest regeneration:
#' \itemize{
#'   \item Chevreuil (roe deer): Main browser, high impact on regeneration
#'   \item Cerf (red deer): Significant browser, bark stripping
#'   \item Sanglier (wild boar): Root damage, seed predation
#'   \item Chamois: Alpine browser, localized impact
#'   \item Isard (Pyrenean chamois): Pyrenees only
#'   \item Mouflon: Mediterranean zones
#'   \item Daim (fallow deer): Browser, localized populations
#'   \item Cerf sika (sika deer): Bark stripping, limited range
#' }
#'
#' Weights reflect relative impact on forest browsing (not total damage).
#' Mountain ungulates (chamois, isard, mouflon) have lower weights as they
#' primarily affect alpine/subalpine forests.
#'
#' @family data-acquisition
#' @export
#'
#' @examples
#' \dontrun{
#' # Compute pressure index for latest season
#' pressure <- compute_game_pressure_index()
#'
#' # Get departments with highest pressure
#' high_pressure <- pressure[pressure$pressure_index > 75, ]
#'
#' # Use with R4 indicator
#' # (Convert to spatial and join with parcels)
#' }
compute_game_pressure_index <- function(hunting_data = NULL,
                                         season = "latest",
                                         weights = c(chevreuil = 0.30, cerf = 0.25, sanglier = 0.15,
                                                     chamois = 0.08, mouflon = 0.07, daim = 0.06,
                                                     isard = 0.05, cerf_sika = 0.04),
                                         normalize_by = "rank",
                                         dept_forest_area = NULL) {
  # Download data if not provided

  if (is.null(hunting_data)) {
    hunting_data <- download_hunting_data(species = "all")
    if (is.null(hunting_data)) {
      stop("Could not download hunting data", call. = FALSE)
    }
  }

  # Normalize weights
  weights <- weights / sum(weights)

  # Get available seasons
  if ("saison" %in% names(hunting_data)) {
    seasons <- unique(hunting_data$saison)
    seasons <- sort(seasons, decreasing = TRUE)

    if (season == "latest") {
      season <- seasons[1]
    }

    # Filter to selected season
    hunting_data <- hunting_data[hunting_data$saison == season, ]
  }

  if (nrow(hunting_data) == 0) {
    stop("No data available for season: ", season, call. = FALSE)
  }

  cli::cli_alert_info("Computing pressure index for season: {season}")

  # Pivot by species
  depts <- unique(hunting_data$code_dept)

  result <- data.frame(
    code_dept = depts,
    stringsAsFactors = FALSE
  )

  # Add department names (if available)
  if ("nom_dept" %in% names(hunting_data)) {
    nom_lookup <- unique(hunting_data[, c("code_dept", "nom_dept"), drop = FALSE])
    result <- merge(result, nom_lookup, by = "code_dept", all.x = TRUE)
  } else {
    result$nom_dept <- NA_character_
  }

  # Get all species present in data
  all_species <- names(HUNTING_DATA_URLS)
  available_species <- unique(hunting_data$espece)
  species_to_process <- intersect(all_species, available_species)

  cli::cli_alert_info("Processing {length(species_to_process)} species: {paste(species_to_process, collapse = ', ')}")

  # Extract harvest by species
  for (sp in species_to_process) {
    sp_data <- hunting_data[hunting_data$espece == sp, c("code_dept", "tableau")]
    names(sp_data)[2] <- paste0(sp, "_harvest")
    result <- merge(result, sp_data, by = "code_dept", all.x = TRUE)
  }

  # Replace NA with 0

  harvest_cols <- grep("_harvest$", names(result), value = TRUE)
  for (col in harvest_cols) {
    result[[col]][is.na(result[[col]])] <- 0
  }

  # Normalize harvest numbers
  normalized <- list()

  for (sp in species_to_process) {
    col <- paste0(sp, "_harvest")
    if (!col %in% names(result)) next

    values <- result[[col]]

    if (normalize_by == "rank") {
      # Percentile rank (0-100)
      normalized[[sp]] <- rank(values, na.last = "keep") / sum(!is.na(values)) * 100
    } else if (normalize_by == "minmax") {
      # Min-max scaling (0-100)
      rng <- range(values, na.rm = TRUE)
      if (rng[2] > rng[1]) {
        normalized[[sp]] <- (values - rng[1]) / (rng[2] - rng[1]) * 100
      } else {
        normalized[[sp]] <- rep(50, length(values))
      }
    } else if (normalize_by == "area") {
      # Per km2 of forest
      if (is.null(dept_forest_area)) {
        cli::cli_alert_warning("dept_forest_area not provided, using rank normalization")
        normalized[[sp]] <- rank(values, na.last = "keep") / sum(!is.na(values)) * 100
      } else {
        # Density per km2
        density <- values / dept_forest_area[result$code_dept]
        # Then rank normalize the density
        normalized[[sp]] <- rank(density, na.last = "keep") / sum(!is.na(density)) * 100
      }
    }
  }

  # Compute weighted pressure index
  result$pressure_index <- 0
  for (sp in names(weights)) {
    if (sp %in% names(normalized)) {
      result$pressure_index <- result$pressure_index + weights[sp] * normalized[[sp]]
    }
  }

  # Cap at 0-100
  result$pressure_index <- pmin(pmax(result$pressure_index, 0), 100)

  # Round for readability
  result$pressure_index <- round(result$pressure_index, 1)

  # Order by pressure index
  result <- result[order(-result$pressure_index), ]
  rownames(result) <- NULL

  return(result)
}

# ==============================================================================
# Integration with R4 Indicator
# ==============================================================================

#' Get Game Pressure Raster for R4 Indicator
#'
#' Creates a SpatRaster of game pressure index by department for use with
#' the \code{\link{indicator_risk_browsing}} function.
#'
#' @param units sf object. Forest parcels to determine spatial extent and CRS.
#' @param pressure_data Data.frame from \code{\link{compute_game_pressure_index}},
#'   or NULL to compute automatically.
#' @param dept_boundaries sf object. Department boundaries with code_dept column,
#'   or NULL to download from IGN.
#'
#' @return A SpatRaster with game pressure index (0-100) per pixel,
#'   matching the extent and CRS of the input units.
#'
#' @details
#' This function:
#' 1. Downloads/computes game pressure index by department
#' 2. Downloads department boundaries if not provided
#' 3. Rasterizes the pressure values
#' 4. Returns a raster for use with indicator_risk_browsing(game_density = ...)
#'
#' @family data-acquisition
#' @export
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#' library(sf)
#'
#' # Load parcels
#' parcels <- st_read("parcels.gpkg")
#'
#' # Get game pressure raster
#' game_raster <- get_game_pressure_raster(parcels)
#'
#' # Use with R4 indicator
#' result <- indicator_risk_browsing(
#'   parcels,
#'   species_field = "essence",
#'   game_density = game_raster
#' )
#' }
get_game_pressure_raster <- function(units,
                                      pressure_data = NULL,
                                      dept_boundaries = NULL) {
  # Validate input
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  # Get pressure data
  if (is.null(pressure_data)) {
    pressure_data <- compute_game_pressure_index()
  }

  # Get department boundaries
  if (is.null(dept_boundaries)) {
    cli::cli_alert_info("Downloading department boundaries...")

    if (requireNamespace("happign", quietly = TRUE)) {
      # Use happign to get department boundaries
      tryCatch({
        bbox <- sf::st_bbox(units)
        bbox_sfc <- sf::st_as_sfc(bbox)
        sf::st_crs(bbox_sfc) <- sf::st_crs(units)

        dept_boundaries <- happign::get_wfs(
          x = bbox_sfc,
          layer = "ADMINEXPRESS-COG-CARTO.LATEST:departement"
        )

        if (!is.null(dept_boundaries) && nrow(dept_boundaries) > 0) {
          # Standardize column name
          if ("code_insee" %in% names(dept_boundaries)) {
            dept_boundaries$code_dept <- dept_boundaries$code_insee
          } else if ("insee_dep" %in% names(dept_boundaries)) {
            dept_boundaries$code_dept <- dept_boundaries$insee_dep
          }
        }
      }, error = function(e) {
        cli::cli_alert_warning("Could not download boundaries: {e$message}")
        dept_boundaries <- NULL
      })
    }

    if (is.null(dept_boundaries)) {
      stop("Could not get department boundaries. Please provide dept_boundaries parameter.",
           call. = FALSE)
    }
  }

  # Transform to same CRS as units
  dept_boundaries <- sf::st_transform(dept_boundaries, sf::st_crs(units))

  # Join pressure data
  dept_boundaries <- merge(
    dept_boundaries,
    pressure_data[, c("code_dept", "pressure_index")],
    by = "code_dept",
    all.x = TRUE
  )

  # Fill missing with median
  median_pressure <- median(pressure_data$pressure_index, na.rm = TRUE)
  dept_boundaries$pressure_index[is.na(dept_boundaries$pressure_index)] <- median_pressure

  # Create raster template
  bbox <- sf::st_bbox(units)
  # 100m resolution

  template <- terra::rast(
    xmin = bbox["xmin"], xmax = bbox["xmax"],
    ymin = bbox["ymin"], ymax = bbox["ymax"],
    resolution = 100,
    crs = sf::st_crs(units)$wkt
  )

  # Rasterize
  pressure_raster <- terra::rasterize(
    terra::vect(dept_boundaries),
    template,
    field = "pressure_index"
  )

  names(pressure_raster) <- "game_pressure"

  return(pressure_raster)
}

