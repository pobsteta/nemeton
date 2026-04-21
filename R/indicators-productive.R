#' Productive & Economic Services Indicators (Family P)
#'
#' Functions for calculating timber production and economic value indicators:
#' - P1: Standing timber volume (m3/ha) via allometric models
#' - P2: Site productivity index (growth potential)
#' - P3: Timber quality score (commercial value potential)
#'
#' @name indicators-productive
#' @keywords internal
#' @family indicators
NULL

#' P1: Standing Timber Volume Indicator
#'
#' Calculates standing timber volume (m3/ha) using IFN allometric equations
#' based on species, diameter (DBH), and height data.
#'
#' In CHM mode (spec 005 phase 3), the height fed to the IFN
#' tarif is the dominant height extracted from a Canopy Height
#' Model (see \code{\link{extract_h_dom}}) rather than the rough
#' Näslund approximation used by default when \code{height} is
#' absent. This typically improves the P1 RMSE by 20 to 40 \%.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param species_field Character. Column name containing species codes (IFN format). Default "species".
#' @param dbh_field Character. Column name containing diameter at breast height (cm). Default "dbh".
#' @param height_field Character. Column name containing tree height (m). Optional, can be estimated.
#' @param density_field Character. Column name containing tree density (stems/ha). Default "density".
#' @param method Character. Volume calculation method: "ifn_tarif" (IFN tariff) or "allometric". Default "ifn_tarif".
#' @param column_name Character. Name for output column. Default "P1".
#' @param lang Character. Message language. Default "en".
#' @param chm Optional \code{SpatRaster} of canopy heights in
#'   metres. When supplied, activates CHM mode (spec 005 phase
#'   3). Heights are taken from the CHM (per-unit 90th
#'   percentile) instead of \code{height_field} or the Näslund
#'   approximation.
#' @param h_dom_percentile Numeric in \code{[0, 1]}. Percentile
#'   of CHM pixels used to derive dominant height per unit.
#'   Default \code{0.9}. Ignored when \code{chm} is \code{NULL}.
#' @param pct_masked Numeric in \code{[0, 1]} or \code{NULL}.
#'   Optionally, the fraction of the CHM that was masked by
#'   \code{\link{sanitize_chm}} upstream. When supplied and
#'   greater than \code{0.3}, a warning is emitted: a
#'   heavily-masked CHM is unreliable for volume estimation.
#'
#' @return sf object with added column: P1 (standing volume in m3/ha)
#'
#' @details
#' **Calculation** (IFN tarif method):
#' \itemize{
#'   \item Lookup species-specific IFN equation: \code{V = a x DBH^b x H^c}
#'   \item Calculate individual tree volume
#'   \item Scale by tree density: \code{P1 = V_individual x density_stems_ha}
#' }
#'
#' **Height source priority**:
#' \enumerate{
#'   \item \code{chm} (CHM mode), when supplied;
#'   \item \code{height_field} column in \code{units}, if present;
#'   \item Näslund approximation \code{H = 1.3 + 0.65 * DBH} as a
#'         last-resort fallback.
#' }
#'
#' **Species Fallback**:
#' If species code not found in IFN tables, uses genus-level
#' equations — \code{BROADLEAF_GENUS} for non-conifers,
#' \code{CONIFER_GENUS} for conifers (see internal
#' \code{is_conifer()}).
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
#' result <- indicateur_p1_volume(
#'   units = units,
#'   species_field = "species",
#'   dbh_field = "dbh",
#'   height_field = "height",
#'   density_field = "density"
#' )
#' }
indicateur_p1_volume <- function(units,
                                        species_field = "species",
                                        dbh_field = "dbh",
                                        height_field = "height",
                                        density_field = "density",
                                        method = c("ifn_tarif", "allometric"),
                                        column_name = "P1",
                                        lang = "en",
                                        chm = NULL,
                                        h_dom_percentile = 0.9,
                                        pct_masked = NULL,
                                        use_climate_drift = FALSE) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  method <- match.arg(method)

  # Auto-fill dbh / density from the CHM when they are missing,
  # before the required-field check. The synthetic path derives
  # D_g from H_dom via a species allometry, then N from the
  # Charru 2012 self-thinning law. Fields already present on the
  # units are respected as-is. No-op when chm is NULL.
  units <- ensure_inventory_fields(
    units,
    species_field = species_field,
    dbh_field     = dbh_field,
    density_field = density_field,
    chm           = chm,
    h_dom_percentile = h_dom_percentile
  )

  # Check required fields
  required_fields <- c(species_field, dbh_field, density_field)
  missing_fields <- setdiff(required_fields, names(units))

  if (length(missing_fields) > 0) {
    stop(paste("Missing required fields:", paste(missing_fields, collapse = ", ")), call. = FALSE)
  }

  # ---- CHM mode height precomputation (spec 005 phase 3) ------
  h_chm <- NULL
  if (!is.null(chm)) {
    if (!inherits(chm, "SpatRaster")) {
      stop("chm must be a terra SpatRaster", call. = FALSE)
    }
    if (!is.null(pct_masked) && is.numeric(pct_masked) &&
        length(pct_masked) == 1L && !is.na(pct_masked) &&
        pct_masked > 0.3) {
      cli::cli_warn(
        "CHM is heavily masked (pct_masked = {round(pct_masked, 2)}); \\
         P1 estimates may be unreliable."
      )
    }
    h_chm <- extract_h_dom(chm, units, percentile = h_dom_percentile)
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

    # Height source priority: CHM > height_field > Naslund fallback
    if (!is.null(h_chm) && !is.na(h_chm[i])) {
      height_m <- h_chm[i]
    } else if (height_field %in% names(units) &&
               !is.na(units[[height_field]][i])) {
      height_m <- units[[height_field]][i]
    } else {
      # Simple height estimation from DBH (Naslund approximation)
      height_m <- 1.3 + (dbh_cm * 0.65)
    }

    # Lookup IFN equation — use the right genus fallback
    fallback <- if (is_conifer(species_code)) "conifer" else "broadleaf"
    equation <- lookup_ifn_equation(species_code, fallback_genus = fallback)

    if (is.null(equation)) {
      cli::cli_warn("Species {species_code} not found in IFN tables, using generic")
      equation <- lookup_ifn_equation(
        if (fallback == "conifer") "CONIFER_GENUS" else "BROADLEAF_GENUS"
      )
    }

    # Calculate individual tree volume using IFN tarif formula
    # V = a x DBH^b x H^c
    a <- as.numeric(equation$a)
    b <- as.numeric(equation$b)
    c <- as.numeric(equation$c)

    volume_individual_m3 <- a * (dbh_cm^b) * (height_m^c)

    # Scale by density to get m3/ha
    volume_per_ha <- volume_individual_m3 * density_ha

    p1_values[i] <- volume_per_ha

    msg_info("productive_volume_calculated", volume_per_ha, species_code)
    msg_info("productive_allometry_applied", species_code, dbh_cm, height_m)
  }

  # Optional Charru 2017 climate drift correction (off by default).
  # Multiplies per-unit volume by a species-specific BAI_chg factor
  # over 1980-2007 (e.g. 1.25 for PIAB in mountain contexts, 0.72
  # for PIHA in Mediterranean). See bai_drift_factor().
  if (isTRUE(use_climate_drift)) {
    drift <- bai_drift_factor(result[[species_field]])
    p1_values <- p1_values * drift
    cli::cli_alert_info(
      "{column_name}: Charru 2017 climate drift applied \\
       (range {round(min(drift, na.rm = TRUE), 2)}..\\
       {round(max(drift, na.rm = TRUE), 2)})"
    )
  }

  # Add to result
  result[[column_name]] <- p1_values

  cli::cli_alert_success("Calculated {column_name}: Standing timber volume (m3/ha)")

  return(result)
}

#' P2: Site Productivity Index Indicator
#'
#' Calculates a site productivity index in one of two modes:
#' \enumerate{
#'   \item \strong{CHM mode} (spec 005 phase 2) — when a Canopy
#'         Height Model is supplied via \code{chm}, the function
#'         extracts a dominant height per unit and converts it
#'         into a site index \eqn{H_0} at \code{reference_age}
#'         using \code{\link{compute_site_index}}. The output is
#'         a dominant height in metres.
#'   \item \strong{Legacy mode} — when \code{chm} is \code{NULL}
#'         (default, preserves pre-spec-005 behaviour), the
#'         function combines soil fertility, climate suitability
#'         and species-specific growth potential using reference
#'         productivity tables. The output is an annual
#'         increment in \eqn{m^3/ha/yr}.
#' }
#'
#' The two modes answer the same forestry question (how
#' productive is this site?) but in different units. Downstream
#' callers should use \code{\link{compute_general_index_mixed}}
#' or a mode-aware normalization when mixing units.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param species_field Character. Column name containing species codes. Default "species".
#' @param fertility_field Character. Column name containing fertility class (1=high, 2=medium, 3=low). Default "fertility".
#' @param climate_field Character. Column name containing climate zone. Default "climate".
#' @param productivity_table Data.frame. Custom productivity reference table. If NULL, uses bundled ONF/IFN tables.
#' @param column_name Character. Name for output column. Default "P2".
#' @param lang Character. Message language. Default "en".
#' @param chm Optional \code{SpatRaster} of canopy heights in
#'   metres. When supplied, activates CHM mode (spec 005 phase
#'   2). Typically the \code{chm_clean} component returned by
#'   \code{\link{sanitize_chm}}.
#' @param age_field Character. Column name containing stand age
#'   (years). Used in CHM mode. Default \code{"age"}.
#' @param reference_age Numeric. Reference age at which the site
#'   index is returned in CHM mode. Default \code{50}.
#' @param h_dom_percentile Numeric in \code{[0, 1]}. Percentile
#'   of CHM pixels used to derive dominant height per unit.
#'   Default \code{0.9}.
#'
#' @return sf object with one added column:
#'   \itemize{
#'     \item Legacy mode: \code{P2} = annual increment (m3/ha/yr).
#'     \item CHM mode:    \code{P2} = site index \eqn{H_0} (m) at
#'           \code{reference_age}.
#'   }
#'
#' @details
#' **Calculation**:
#' \itemize{
#'   \item Lookup reference productivity from ONF/IFN tables
#'   \item Match by species x fertility class x climate zone
#'   \item P2 = annual increment (m3/ha/year) for the site
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
#' result <- indicateur_p2_station(
#'   units = units,
#'   species_field = "species",
#'   fertility_field = "fertility",
#'   climate_field = "climate"
#' )
#' }
indicateur_p2_station <- function(units,
                                         species_field = "species",
                                         fertility_field = "fertility",
                                         climate_field = "climate",
                                         productivity_table = NULL,
                                         column_name = "P2",
                                         lang = "en",
                                         chm = NULL,
                                         age_field = "age",
                                         reference_age = 50,
                                         h_dom_percentile = 0.9) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  # ---- CHM mode (spec 005 phase 2) ---------------------------
  if (!is.null(chm)) {
    if (!inherits(chm, "SpatRaster")) {
      stop("chm must be a terra SpatRaster", call. = FALSE)
    }
    required_fields <- c(species_field, age_field)
    missing_fields  <- setdiff(required_fields, names(units))
    if (length(missing_fields) > 0) {
      stop(paste("Missing required fields for CHM mode:",
                 paste(missing_fields, collapse = ", ")),
           call. = FALSE)
    }

    h_dom <- extract_h_dom(chm, units, percentile = h_dom_percentile)
    site_index <- compute_site_index(
      H_dom   = h_dom,
      age     = units[[age_field]],
      species = units[[species_field]],
      reference_age = reference_age
    )

    result <- units
    result[[column_name]] <- site_index

    cli::cli_alert_success(
      "Calculated {column_name}: site index H0 at {reference_age} years (m) via CHM"
    )
    return(result)
  }

  # ---- Legacy mode (proxy fertility * climate * species) -----

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

  cli::cli_alert_success("Calculated {column_name}: Site productivity index (m3/ha/yr)")

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
#' result <- indicateur_p3_qualite_bois(
#'   units = units,
#'   dbh_field = "dbh",
#'   form_score_field = "form_score",
#'   defects_field = "defects"
#' )
#' }
indicateur_p3_qualite_bois <- function(units,
                                         dbh_field = "dbh",
                                         form_score_field = "form_score",
                                         defects_field = "defects",
                                         species_field = "species",
                                         weights = c(form = 0.4, diameter = 0.4, defects = 0.2),
                                         column_name = "P3",
                                         lang = "en",
                                         chm = NULL) {
  # Validate inputs
  if (!inherits(units, "sf")) {
    stop("units must be an sf object", call. = FALSE)
  }

  # Auto-fill dbh from the CHM when missing (NDP 1 synthetic, see
  # ensure_inventory_fields). Density is not needed by P3 but is
  # produced alongside and dropped if not requested.
  units <- ensure_inventory_fields(
    units,
    species_field = species_field,
    dbh_field     = dbh_field,
    density_field = "density",
    chm           = chm
  )

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
      is_conifer <- grepl("^P[IML]", toupper(species_code)) # PI*, PM*, PL* (pines)
      sawlog_threshold <- if (is_conifer) 30 else 40
      pulp_threshold <- if (is_conifer) 15 else 20
    } else {
      sawlog_threshold <- 35 # Generic
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
      defects_score <- if (has_defects > 0) 50 else 100 # 50% penalty for defects
    } else {
      defects_score <- 85 # Assume minor defects
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
