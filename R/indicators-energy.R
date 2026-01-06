#' Energy & Climate Services Indicators (Family E)
#'
#' Functions for calculating energy and climate mitigation indicators:
#' - E1: Mobilizable fuelwood potential (biomass energy)
#' - E2: Carbon emission avoidance through substitution
#'
#' @name indicators-energy
#' @family indicators
NULL

#' E1: Fuelwood Potential Indicator
#'
#' Calculates mobilizable fuelwood potential (tonnes dry matter/year) from
#' forest harvest residues and coppice biomass.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param volume_field Character. Column name containing standing volume (m³/ha). Default "volume".
#' @param species_field Character. Column name containing species codes. Default "species".
#' @param harvest_rate Numeric. Annual harvest rate (fraction of volume). Default 0.02 (2%/year).
#' @param residue_fraction Numeric. Fraction of harvest available as residues. Default 0.3 (30%).
#' @param coppice_area_field Character. Column name for coppice area fraction. Optional.
#' @param column_name Character. Name for output column. Default "E1".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added columns: E1 (fuelwood potential tonnes DM/yr), E1_residues, E1_coppice
#'
#' @export
indicator_energy_fuelwood <- function(units,
                                       volume_field = "volume",
                                       species_field = "species",
                                       harvest_rate = 0.02,
                                       residue_fraction = 0.3,
                                       coppice_area_field = NULL,
                                       column_name = "E1",
                                       lang = "en") {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)
  if (!volume_field %in% names(units)) {
    stop(paste("Required field missing:", volume_field), call. = FALSE)
  }

  result <- units
  e1_values <- numeric(nrow(units))
  e1_residues <- numeric(nrow(units))
  e1_coppice <- numeric(nrow(units))

  for (i in seq_len(nrow(units))) {
    volume_m3_ha <- units[[volume_field]][i]
    if (is.na(volume_m3_ha)) {
      e1_values[i] <- NA_real_
      next
    }

    # Get species-specific wood density
    species_code <- if (species_field %in% names(units)) units[[species_field]][i] else "BROADLEAF_GENUS"
    density_kg_m3 <- lookup_species_threshold(species_code, "density_kg_m3", "wood_density")
    if (is.na(density_kg_m3)) density_kg_m3 <- 550  # Default

    # Calculate harvest residues
    annual_harvest_m3_ha <- volume_m3_ha * harvest_rate
    residues_m3_ha <- annual_harvest_m3_ha * residue_fraction
    residues_tonnes_dm <- residues_m3_ha * density_kg_m3 / 1000 * 0.5  # DM = 50% of fresh weight

    # Calculate coppice biomass (if applicable)
    coppice_tonnes_dm <- 0
    if (!is.null(coppice_area_field) && coppice_area_field %in% names(units)) {
      coppice_fraction <- units[[coppice_area_field]][i]
      if (!is.na(coppice_fraction) && coppice_fraction > 0) {
        coppice_tonnes_dm <- coppice_fraction * 2  # Assume 2 tonnes DM/ha/yr for coppice
      }
    }

    e1_residues[i] <- residues_tonnes_dm
    e1_coppice[i] <- coppice_tonnes_dm
    e1_values[i] <- residues_tonnes_dm + coppice_tonnes_dm

    msg_info("energy_fuelwood_calculated", e1_values[i], residues_tonnes_dm, coppice_tonnes_dm)
  }

  result$E1_residues <- e1_residues
  result$E1_coppice <- e1_coppice
  result[[column_name]] <- e1_values

  cli::cli_alert_success("Calculated {column_name}: Fuelwood potential (tonnes DM/yr)")
  return(result)
}

#' E2: Carbon Emission Avoidance Indicator
#'
#' Calculates CO2 emission avoidance (tCO2eq/year) through wood energy and
#' material substitution using ADEME emission factors.
#'
#' @param units sf object (POLYGON) of spatial units to assess
#' @param fuelwood_field Character. Column name for fuelwood potential (tonnes DM/yr). Default "E1".
#' @param volume_field Character. Column name for construction timber volume (m³/ha). Optional.
#' @param energy_scenario Character. Energy substitution scenario: "vs_natural_gas", "vs_fuel_oil". Default "vs_natural_gas".
#' @param material_scenario Character. Material substitution: "vs_concrete", "vs_steel", NULL. Default NULL (no material substitution).
#' @param column_name Character. Name for output column. Default "E2".
#' @param lang Character. Message language. Default "en".
#'
#' @return sf object with added columns: E2 (total CO2 avoided tCO2eq/yr), E2_energy, E2_material
#'
#' @export
indicator_energy_avoidance <- function(units,
                                        fuelwood_field = "E1",
                                        volume_field = NULL,
                                        energy_scenario = "vs_natural_gas",
                                        material_scenario = NULL,
                                        column_name = "E2",
                                        lang = "en") {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)

  result <- units
  e2_energy <- numeric(nrow(units))
  e2_material <- numeric(nrow(units))
  e2_total <- numeric(nrow(units))

  # Lookup ADEME emission factors
  energy_factor <- lookup_ademe_factor("wood_energy", energy_scenario)
  if (is.null(energy_factor)) {
    cli::cli_warn("Energy scenario {energy_scenario} not found, using default")
    energy_factor <- list(emission_factor_kgCO2eq_per_unit = 0.222)
  }

  for (i in seq_len(nrow(units))) {
    # Energy substitution
    if (fuelwood_field %in% names(units) && !is.na(units[[fuelwood_field]][i])) {
      fuelwood_tonnes_dm <- units[[fuelwood_field]][i]
      # Convert to kWh: 1 tonne DM = 4500 kWh
      energy_kwh <- fuelwood_tonnes_dm * 4500
      # Calculate avoided CO2
      e2_energy[i] <- energy_kwh * as.numeric(energy_factor$emission_factor_kgCO2eq_per_unit) / 1000  # Convert to tonnes
    }

    # Material substitution (if applicable)
    if (!is.null(material_scenario) && !is.null(volume_field) && volume_field %in% names(units)) {
      construction_volume <- units[[volume_field]][i]
      if (!is.na(construction_volume)) {
        material_factor <- lookup_ademe_factor("wood_construction", material_scenario)
        if (!is.null(material_factor)) {
          # Convert volume to mass (assuming 500 kg/m³ average)
          wood_mass_kg <- construction_volume * 500
          e2_material[i] <- wood_mass_kg * as.numeric(material_factor$emission_factor_kgCO2eq_per_unit) / 1000
        }
      }
    }

    e2_total[i] <- e2_energy[i] + e2_material[i]
    msg_info("energy_avoidance_calculated", e2_total[i], e2_energy[i], e2_material[i])
  }

  result$E2_energy <- e2_energy
  result$E2_material <- e2_material
  result[[column_name]] <- e2_total

  cli::cli_alert_success("Calculated {column_name}: CO2 emission avoidance (tCO2eq/yr)")
  return(result)
}
