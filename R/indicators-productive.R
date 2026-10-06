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
#' @param density_field Character. Column name containing tree density in
#'   STEMS PER HECTARE. Default "density". Not a 0-1 cover fraction (unlike
#'   the \code{density_col} of \code{\link{indicateur_c1_biomasse}}): values
#'   in (0, 1) are set to NA with a warning.
#' @param method Character. Volume calculation method. Only "ifn_tarif" (the
#'   IFN tariff \code{V = a x DBH^b x H^c}, see Details) is implemented;
#'   "allometric" is accepted for backward compatibility but has no effect and
#'   emits a warning. Default "ifn_tarif".
#' @param column_name Character. Name for output column. Default "P1".
#' @param lang Character. Currently unused (messages are in English); kept for
#'   backward compatibility. Default "en".
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
#' @param use_climate_drift Logical. When \code{TRUE}, the estimated
#'   volume is scaled by the per-species climate-driven BAI drift
#'   factor (Charru et al. 2017, see \code{\link{charru_bai_drift}}).
#'   Default \code{FALSE} (raw synthetic-inventory volume).
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
    cli::cli_abort("units must be an sf object")
  }

  method <- match.arg(method)
  # Le dispatch "allometric" n'a jamais été implémenté : la boucle applique
  # toujours le tarif IFN (V = a·D²·H). Le signaler plutôt que de retourner
  # silencieusement le même résultat que "ifn_tarif" (brief app 2026-07-25).
  if (identical(method, "allometric")) {
    cli::cli_warn(c(
      "!" = "{.arg method = \"allometric\"} is not implemented; the IFN tarif \\
             is used instead.",
      "i" = "Only {.val ifn_tarif} is available. This argument has no effect \\
             and may be removed in a future version."
    ))
  }

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
    cli::cli_abort("Missing required fields: {paste(missing_fields, collapse = ', ')}")
  }

  # ---- CHM mode height precomputation (spec 005 phase 3) ------
  h_chm <- NULL
  if (!is.null(chm)) {
    if (!inherits(chm, "SpatRaster")) {
      cli::cli_abort("chm must be a terra SpatRaster")
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

  # `density` est ici en tiges/ha (pas une fraction de couvert comme en C1)
  dens_vec <- .check_density_unit(units[[density_field]], "stems_ha", "P1")

  result <- units
  p1_values <- numeric(nrow(units))

  # Calculate volume for each unit
  for (i in seq_len(nrow(units))) {
    species_code <- units[[species_field]][i]
    dbh_cm <- units[[dbh_field]][i]
    density_ha <- dens_vec[i]

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
#' A third mode, \code{source = "ifn_fh"} (spec 054), returns
#' the biological volume production measured by the national
#' forest inventory for the unit's sylvoecoregion, estimated by
#' Fay-Herriot (\code{\link{ifn_production_reference}}), in
#' \eqn{m^3/ha/yr}. It is the production of the \strong{domain},
#' not of the stand's own site, all species together: the per-group
#' figures of the table are diluted over the whole forest area. It adds
#' three columns:
#' \code{<column_name>_rse} (relative standard error, percent),
#' \code{<column_name>_provenance} (\code{"ifn_prod_ser"},
#' \code{"ifn_prod_greco"} or \code{"ifn_prod_national"}) and
#' \code{<column_name>_nature} (\code{"fay_herriot"},
#' \code{"direct"} or \code{"synthetique"}). It is opt-in: the
#' default behaviour is unchanged.
#'
#' The modes answer the same forestry question (how
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
#' @param lang Character. Currently unused (messages are in English); kept for
#'   backward compatibility. Default "en".
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
#' @param source \code{"auto"} (default): CHM mode when
#'   \code{chm} is supplied, legacy mode otherwise.
#'   \code{"ifn_fh"}: IFN production of the unit's
#'   sylvoecoregion (spec 054).
#' @param ser_field Character. Column holding the SER code
#'   (e.g. \code{"C30"}), used by \code{source = "ifn_fh"}. A
#'   missing or unknown SER falls back to the GRECO, then to the
#'   national figure. Default \code{"ser"}.
#'
#' @return sf object with one added column:
#'   \itemize{
#'     \item Legacy mode: \code{P2} = annual increment (m3/ha/yr).
#'     \item CHM mode:    \code{P2} = site index \eqn{H_0} (m) at
#'           \code{reference_age}, plus \code{p2_status =
#'           "indice_station_m"} so that normalisation uses a 40 m
#'           ceiling (\code{\link{normalize_indicator}}).
#'     \item IFN mode:    \code{P2} = IFN volume production of the
#'           sylvoecoregion (m3/ha/yr), plus \code{P2_rse},
#'           \code{P2_provenance}, \code{P2_nature}.
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
                                         h_dom_percentile = 0.9,
                                         source = c("auto", "ifn_fh"),
                                         ser_field = "ser") {
  # Validate inputs
  if (!inherits(units, "sf")) {
    cli::cli_abort("units must be an sf object")
  }
  source <- match.arg(source)

  # ---- IFN mode (spec 054) : production de la SER, Fay-Herriot ----
  if (source == "ifn_fh") {
    if (!ser_field %in% names(units)) {
      cli::cli_abort("Missing required field for IFN mode: {ser_field}")
    }
    ser <- as.character(units[[ser_field]])
    ser[!nzchar(ser)] <- NA_character_
    # Toujours le groupe "tous" : dans la table, la production d'un groupe est
    # rapportee a l'hectare de TOUTE la foret de la SER (sa contribution),
    # pas a l'hectare de peuplement de ce groupe. Une pessiere de E10 aurait
    # recu 2,05 m3/ha/an "resineux", dilue par les placettes sans resineux.
    cle <- ifelse(is.na(ser), "<national>", ser)
    refs <- lapply(unique(cle), function(k) {
      ifn_production_reference(if (k == "<national>") NULL else k, "pv", "tous")
    })
    names(refs) <- unique(cle)
    r <- do.call(rbind, refs[cle])
    result <- units
    result[[column_name]] <- r$valeur
    result[[paste0(column_name, "_rse")]] <- r$rse
    result[[paste0(column_name, "_provenance")]] <-
      ifelse(is.na(r$niveau_utilise), NA_character_,
             paste0("ifn_prod_", r$niveau_utilise))
    result[[paste0(column_name, "_nature")]] <- r$nature
    cli::cli_alert_success(
      "Calculated {column_name}: IFN volume production of the sylvoecoregion (m3/ha/yr)"
    )
    return(result)
  }

  # ---- CHM mode (spec 005 phase 2) ---------------------------
  if (!is.null(chm)) {
    if (!inherits(chm, "SpatRaster")) {
      cli::cli_abort("chm must be a terra SpatRaster")
    }
    required_fields <- c(species_field, age_field)
    missing_fields  <- setdiff(required_fields, names(units))
    if (length(missing_fields) > 0) {
      cli::cli_abort(
        "Missing required fields for CHM mode: {paste(missing_fields, collapse = ', ')}"
      )
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
    # Unite de P2 dans ce mode : des metres, pas des m3/ha/an. La colonne de
    # statut voyage jusqu'a la normalisation (normalize_indicator(statut =),
    # create_family_index()) ; l'app la conserve en `.p2_status` (ecart n. 17).
    result$p2_status <- ifelse(is.na(site_index), NA_character_, "indice_station_m")

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
    cli::cli_abort("Missing required fields: {paste(missing_fields, collapse = ', ')}")
  }

  # Load productivity reference table
  if (is.null(productivity_table)) {
    prod_path <- system.file("extdata", "productivity_tables.csv", package = "nemeton")

    if (!file.exists(prod_path)) {
      cli::cli_abort("Productivity tables not found: {prod_path}")
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
#' @param lang Character. Currently unused (messages are in English); kept for
#'   backward compatibility. Default "en".
#' @param chm Optional `terra::SpatRaster` canopy height model (spec 005).
#'   Passed to `ensure_inventory_fields()` to auto-fill `dbh` from the
#'   CHM when the diameter field is missing. Default `NULL`.
#'
#' @return sf object with added columns: P3 (timber quality score 0-100) and
#'   `p3_status`, which tells which components were measured:
#'   `"diametre_seul"`, `"diametre_forme"`, `"diametre_defauts"` or
#'   `"complet"` (NA when P3 is NA).
#'
#'   **Higher = better timber = favourable.** P3 is a weighted mean of the
#'   components that are each already 0-100 and each already oriented that way
#'   (diameter against commercial thresholds, stem form, a defects penalty),
#'   so the composite is 0-100 by construction and `normalize_indicator()`
#'   passes it through (spec 048 section 12).
#'
#'   Only MEASURED components enter the mean, their weights rescaled to sum
#'   to 1. Form and defects are used when the unit carries a non-missing value
#'   in `form_score_field` / `defects_field` (field data, e.g. QField); there
#'   is no default score any more. Before 1.0.0 a missing form counted 70 and
#'   missing defects 85, i.e. 45 constant points out of 100 on every unit
#'   without field data (spec 056): P3 is now the diameter score alone there
#'   (`p3_status = "diametre_seul"`).
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
    cli::cli_abort("units must be an sf object")
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
    cli::cli_abort("Required field missing: {dbh_field}")
  }

  result <- units
  p3_values <- numeric(nrow(units))
  p3_status <- rep(NA_character_, nrow(units))

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
      # Seuils resineux / feuillus : definition unique du paquet. L'ancien
      # motif ^P[IML] ratait ABAL, PSME, LADE, CEAT et prenait PLAC
      # (platane) pour un pin.
      resineux <- is_conifer(species_code)
      sawlog_threshold <- if (resineux) 30 else 40
      pulp_threshold <- if (resineux) 15 else 20
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

    # Composantes 2 et 3 : forme et défauts, SEULEMENT quand une donnée de
    # terrain les fournit. Avant 1.0.0, une forme absente valait 70 et des
    # défauts absents 85 : 45 points constants sur 100 pour toute UGF sans
    # inventaire, soit 58 à 97 % du P3 affiché sur les projets réels (spec 056,
    # décision 2026-10-06). Les poids des composantes mesurées sont ramenés à 1.
    form_score <- NA_real_
    if (form_score_field %in% names(units) && !is.na(units[[form_score_field]][i])) {
      form_score <- units[[form_score_field]][i]
    }
    defects_score <- NA_real_
    if (defects_field %in% names(units) && !is.na(units[[defects_field]][i])) {
      has_defects <- units[[defects_field]][i]
      defects_score <- if (has_defects > 0) 50 else 100 # 50% penalty for defects
    }

    scores <- c(form = form_score, diameter = diameter_score,
                defects = defects_score)
    w <- weights[names(scores)]
    mesure <- !is.na(scores)
    p3_values[i] <- sum(w[mesure] * scores[mesure]) / sum(w[mesure])
    p3_status[i] <- if (mesure[["form"]] && mesure[["defects"]]) {
      "complet"
    } else if (mesure[["form"]]) {
      "diametre_forme"
    } else if (mesure[["defects"]]) {
      "diametre_defauts"
    } else {
      "diametre_seul"
    }

    msg_info("productive_quality_assessed", p3_values[i], form_score, diameter_score, defects_score)
  }

  # Add to result
  result[[column_name]] <- p3_values
  result$p3_status <- p3_status

  cli::cli_alert_success("Calculated {column_name}: Timber quality score (0-100)")

  return(result)
}
