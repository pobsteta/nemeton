#' Productive & Economic Services Indicators (Family P)
#'
#' Functions for calculating timber production and economic value indicators:
#' - P1: Standing timber volume (m³/ha) via allometric models
#' - P2: Site productivity index (growth potential)
#' - P3: Timber quality score (commercial value potential)
#'
#' @name indicators-productive
#' @keywords internal
#' @family indicators
NULL

#' P1: Standing Timber Volume Indicator
#'
#' Calculates standing timber volume (m³/ha) using IFN allometric equations
#' based on species, diameter (DBH), and height data.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param species_field Character. Column name containing species codes (IFN format). Default "species".
#' @param dbh_field Character. Column name containing diameter at breast height (cm). Default "dbh".
#' @param height_field Character. Column name containing tree height (m). Optional, can be estimated.
#' @param density_field Character. Column name containing tree density (stems/ha). Default "density".
#' @param method Character. Volume calculation method: "ifn_tarif" (IFN tariff) or "allometric". Default "ifn_tarif".
#' @param column_name Character. Name for output column. Default "P1".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added column: P1 (standing volume in m³/ha)
#'
#' @details
#' **Calculation** (IFN tarif method):
#' \itemize{
#'   \item Lookup species-specific IFN equation: \code{V = a × DBH^b × H^c}
#'   \item Calculate individual tree volume
#'   \item Scale by tree density: \code{P1 = V_individual × density_stems_ha}
#' }
#'
#' **Species Fallback**:
#' If species code not found in IFN tables, uses genus-level equations:
#' \itemize{
#'   \item Broadleaf species → BROADLEAF_GENUS equation
#'   \item Conifer species → CONIFER_GENUS equation
#' }
#'
#' **Data Requirements**:
#' \itemize{
#'   \item species: IFN species code (e.g., "FASY", "QUPE", "PIAB")
#'   \item dbh: Diameter at breast height (1.3m) in cm
#'   \item height: Tree height in meters (can be estimated from DBH if missing)
#'   \item density: Number of stems per hectare
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' # With species and biometric data
#' units$species <- c("FASY", "QUPE", "PIAB")
#' units$dbh <- c(35, 42, 28)
#' units$height <- c(25, 30, 22)
#' units$density <- c(250, 180, 320)
#'
#' result <- indicator_productive_volume(
#'   units = units,
#'   species_field = "species",
#'   dbh_field = "dbh",
#'   height_field = "height",
#'   density_field = "density"
#' )
#' }
indicator_productive_volume <- function(units,
                                         species_field = "species",
                                         dbh_field = "dbh",
                                         height_field = "height",
                                         density_field = "density",
                                         method = c("ifn_tarif", "allometric"),
                                         column_name = "P1",
                                         lang = "en") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  method <- match.arg(method)

  # Check required fields
  required_fields <- c(species_field, dbh_field, density_field)
  missing_fields <- setdiff(required_fields, names(units))

  if (length(missing_fields) > 0) {
    stop(paste("Missing required fields:", paste(missing_fields, collapse = ", ")), call. = FALSE)
  }

  result <- units
  p1_values <- numeric(nrow(units))

  # Calculate volume for each unit
  for (i in seq_len(nrow(units))) {
    species_code <- units[[species_field]][i]
    dbh_cm <- units[[dbh_field]][i]
    density_ha <- units[[density_field]][i]

    # Skip if missing data
    if (is.na(species_code) || is.na(dbh_cm) || is.na(density_ha)) {
      p1_values[i] <- NA_real_
      next
    }

    # Get height (or estimate if missing)
    if (height_field %in% names(units) && !is.na(units[[height_field]][i])) {
      height_m <- units[[height_field]][i]
    } else {
      # Simple height estimation from DBH (Näslund function approximation)
      height_m <- 1.3 + (dbh_cm * 0.65)  # Rough approximation
    }

    # Lookup IFN equation
    equation <- lookup_ifn_equation(species_code, fallback_genus = "broadleaf")

    if (is.null(equation)) {
      cli::cli_warn("Species {species_code} not found in IFN tables, using generic")
      equation <- lookup_ifn_equation("BROADLEAF_GENUS")
    }

    # Calculate individual tree volume using IFN tarif formula
    # V = a × DBH^b × H^c
    a <- as.numeric(equation$a)
    b <- as.numeric(equation$b)
    c <- as.numeric(equation$c)

    volume_individual_m3 <- a * (dbh_cm ^ b) * (height_m ^ c)

    # Scale by density to get m³/ha
    volume_per_ha <- volume_individual_m3 * density_ha

    p1_values[i] <- volume_per_ha

    msg_info("productive_volume_calculated", volume_per_ha, species_code)
    msg_info("productive_allometry_applied", species_code, dbh_cm, height_m)
  }

  # Add to result
  result[[column_name]] <- p1_values

  cli::cli_alert_success("Calculated {column_name}: Standing timber volume (m³/ha)")

  return(result)
}

#' P2: Site Productivity Index Indicator
#'
#' Calculates a site productivity index combining soil fertility, climate suitability,
#' and species-specific growth potential using reference productivity tables.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param species_field Character. Column name containing species codes. Default "species".
#' @param fertility_field Character. Column name containing fertility class (1=high, 2=medium, 3=low). Default "fertility".
#' @param climate_field Character. Column name containing climate zone. Default "climate".
#' @param productivity_table Data.frame. Custom productivity reference table. If NULL, uses bundled ONF/IFN tables.
#' @param column_name Character. Name for output column. Default "P2".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added column: P2 (annual increment in m³/ha/yr)
#'
#' @details
#' **Calculation**:
#' \itemize{
#'   \item Lookup reference productivity from ONF/IFN tables
#'   \item Match by species × fertility class × climate zone
#'   \item P2 = annual increment (m³/ha/year) for the site
#' }
#'
#' **Fertility Classes**:
#' \itemize{
#'   \item 1: High fertility (rich soils, optimal drainage)
#'   \item 2: Medium fertility (average conditions)
#'   \item 3: Low fertility (poor soils, constraints)
#' }
#'
#' **Climate Zones**:
#' \itemize{
#'   \item temperate_oceanic: Atlantic climate (Brittany, Normandy)
#'   \item temperate_continental: Continental (Lorraine, Burgundy)
#'   \item mountainous: Mountain zones (Alps, Pyrenees, Massif Central)
#'   \item atlantic: Southwest Atlantic (Landes, Gironde)
#'   \item mediterranean: Mediterranean (Provence, Languedoc)
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' units$species <- c("FASY", "PIAB", "QUPE")
#' units$fertility <- c(1, 2, 2)
#' units$climate <- c("temperate_oceanic", "mountainous", "temperate_oceanic")
#'
#' result <- indicator_productive_station(
#'   units = units,
#'   species_field = "species",
#'   fertility_field = "fertility",
#'   climate_field = "climate"
#' )
#' }
indicator_productive_station <- function(units,
                                          species_field = "species",
                                          fertility_field = "fertility",
                                          climate_field = "climate",
                                          productivity_table = NULL,
                                          column_name = "P2",
                                          lang = "en") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  # Check required fields
  required_fields <- c(species_field, fertility_field, climate_field)
  missing_fields <- setdiff(required_fields, names(units))

  if (length(missing_fields) > 0) {
    stop(paste("Missing required fields:", paste(missing_fields, collapse = ", ")), call. = FALSE)
  }

  # Load productivity reference table
  if (is.null(productivity_table)) {
    prod_path <- system.file("extdata", "productivity_tables.csv", package = "nemeton")

    if (!file.exists(prod_path)) {
      stop("Productivity tables not found: ", prod_path, call. = FALSE)
    }

    productivity_table <- utils::read.csv(prod_path, stringsAsFactors = FALSE)
  }

  result <- units
  p2_values <- numeric(nrow(units))

  # Calculate productivity for each unit
  for (i in seq_len(nrow(units))) {
    species_code <- units[[species_field]][i]
    fertility_class <- units[[fertility_field]][i]
    climate_zone <- units[[climate_field]][i]

    # Skip if missing data
    if (is.na(species_code) || is.na(fertility_class) || is.na(climate_zone)) {
      p2_values[i] <- NA_real_
      next
    }

    # Lookup in productivity table
    prod_row <- productivity_table[
      productivity_table$species_code == toupper(species_code) &
      productivity_table$fertility_class == fertility_class &
      productivity_table$climate_zone == climate_zone,
    ]

    if (nrow(prod_row) > 0) {
      p2_values[i] <- prod_row$annual_increment_m3_ha_yr[1]
      msg_info("productive_station_score", p2_values[i], fertility_class, climate_zone)
    } else {
      # Fallback to genus average
      genus_row <- productivity_table[
        productivity_table$species_code %in% c("BROADLEAF_GENUS", "CONIFER_GENUS") &
        productivity_table$fertility_class == fertility_class,
      ]

      if (nrow(genus_row) > 0) {
        p2_values[i] <- mean(genus_row$annual_increment_m3_ha_yr, na.rm = TRUE)
      } else {
        p2_values[i] <- NA_real_
      }
    }
  }

  # Add to result
  result[[column_name]] <- p2_values

  cli::cli_alert_success("Calculated {column_name}: Site productivity index (m³/ha/yr)")

  return(result)
}

#' P3: Timber Quality Score Indicator
#'
#' Calculates a timber quality score (0-100) based on tree form (straightness),
#' commercial diameter thresholds, and defect presence.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param dbh_field Character. Column name containing diameter at breast height (cm). Default "dbh".
#' @param form_score_field Character. Column name containing form quality score (0-100). Optional.
#' @param defects_field Character. Column name containing defect indicator (0=none, 1=present). Optional.
#' @param species_field Character. Column name containing species codes (for diameter thresholds). Default "species".
#' @param weights Named numeric vector. Component weights: c(form = 0.4, diameter = 0.4, defects = 0.2). Default balanced.
#' @param column_name Character. Name for output column. Default "P3".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added column: P3 (timber quality score 0-100)
#'
#' @details
#' **Calculation**:
#' \itemize{
#'   \item Form score (0-100): Straightness and branching quality
#'   \item Diameter score (0-100): Proximity to commercial thresholds
#'     - Broadleaf: 40cm (sawlog), 20cm (pulpwood)
#'     - Conifer: 30cm (sawlog), 15cm (pulpwood)
#'   \item Defect penalty: 100 = no defects, 0 = severe defects
#'   \item P3 = weighted average of components
#' }
#'
#' **Quality Classes**:
#' \itemize{
#'   \item 80-100: Premium quality (sawlog, veneer)
#'   \item 60-80: Good quality (construction timber)
#'   \item 40-60: Average quality (general use)
#'   \item 20-40: Low quality (pulpwood, biomass)
#'   \item 0-20: Very low quality (firewood only)
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' units$dbh <- c(45, 28, 35)
#' units$species <- c("FASY", "PIAB", "QUPE")
#' units$form_score <- c(85, 70, 60)
#' units$defects <- c(0, 0, 1)
#'
#' result <- indicator_productive_quality(
#'   units = units,
#'   dbh_field = "dbh",
#'   form_score_field = "form_score",
#'   defects_field = "defects"
#' )
#' }
indicator_productive_quality <- function(units,
                                          dbh_field = "dbh",
                                          form_score_field = "form_score",
                                          defects_field = "defects",
                                          species_field = "species",
                                          weights = c(form = 0.4, diameter = 0.4, defects = 0.2),
                                          column_name = "P3",
                                          lang = "en") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  if (!dbh_field %in% names(units)) {
    stop(paste("Required field missing:", dbh_field), call. = FALSE)
  }

  result <- units
  p3_values <- numeric(nrow(units))

  # Calculate quality for each unit
  for (i in seq_len(nrow(units))) {
    dbh_cm <- units[[dbh_field]][i]

    if (is.na(dbh_cm)) {
      p3_values[i] <- NA_real_
      next
    }

    # Component 1: Diameter score
    # Score based on commercial thresholds
    if (species_field %in% names(units)) {
      species_code <- units[[species_field]][i]
      # Simple heuristic: conifer vs broadleaf thresholds
      is_conifer <- grepl("^P[IML]", toupper(species_code))  # PI*, PM*, PL* (pines)
      sawlog_threshold <- if (is_conifer) 30 else 40
      pulp_threshold <- if (is_conifer) 15 else 20
    } else {
      sawlog_threshold <- 35  # Generic
      pulp_threshold <- 18
    }

    if (dbh_cm >= sawlog_threshold) {
      diameter_score <- 100
    } else if (dbh_cm >= pulp_threshold) {
      # Linear interpolation between pulp and sawlog
      diameter_score <- 50 + 50 * (dbh_cm - pulp_threshold) / (sawlog_threshold - pulp_threshold)
    } else {
      # Below pulpwood threshold
      diameter_score <- 50 * (dbh_cm / pulp_threshold)
    }

    # Component 2: Form score
    if (form_score_field %in% names(units) && !is.na(units[[form_score_field]][i])) {
      form_score <- units[[form_score_field]][i]
    } else {
      # Default assumption: average form quality
      form_score <- 70
    }

    # Component 3: Defects penalty
    if (defects_field %in% names(units) && !is.na(units[[defects_field]][i])) {
      has_defects <- units[[defects_field]][i]
      defects_score <- if (has_defects > 0) 50 else 100  # 50% penalty for defects
    } else {
      defects_score <- 85  # Assume minor defects
    }

    # Weighted composite
    p3_values[i] <- weights["form"] * form_score +
                    weights["diameter"] * diameter_score +
                    weights["defects"] * defects_score

    msg_info("productive_quality_assessed", p3_values[i], form_score, diameter_score, defects_score)
  }

  # Add to result
  result[[column_name]] <- p3_values

  cli::cli_alert_success("Calculated {column_name}: Timber quality score (0-100)")

  return(result)
}
