#' Energy & Climate Services Indicators (Family E)
#'
#' Functions for calculating energy and climate mitigation indicators:
#' - E1: Mobilizable fuelwood potential (biomass energy)
#' - E2: Carbon emission avoidance through substitution
#'
#' @name indicators-energy
#' @keywords internal
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
#' @param harvest_rate Numeric. Annual harvest rate (fraction of volume). Default 0.02 (2 percent/year).
#' @param residue_fraction Numeric. Fraction of harvest available as residues. Default 0.3 (30 percent).
#' @param coppice_area_field Character. Column name for coppice area fraction. Optional.
#' @param column_name Character. Name for output column. Default "E1".
#' @param lang Character. Message language. Default "en".
#' @param chm Optional `terra::SpatRaster` canopy height model (spec 005).
#'   When supplied and `volume_field` is absent, standing volume is
#'   auto-estimated by running P1 internally. Default `NULL`.
#' @param production_field Character or `NULL` (default). Column holding the
#'   annual volume production (m3/ha/yr), e.g. P2 computed with
#'   `indicateur_p2_station(source = "ifn_fh")`. When supplied, E1 switches
#'   to **flux mode** (spec 054 lot 4): the annual harvest is
#'   `production x taux_mobilisation` instead of 2 percent of the standing
#'   stock, and `volume_field` / `harvest_rate` are not used.
#' @param taux_mobilisation Required in flux mode, no default on purpose:
#'   either a number in `[0, 1]` (share of the production harvested), or
#'   `"ifn_ser"` to use the harvest / production ratio observed by the IFN in
#'   the unit's sylvoecoregion ([ifn_taux_prelevement_production()], capped at
#'   1).
#' @param ser_field Character. SER column used by
#'   `taux_mobilisation = "ifn_ser"`. Default `"ser"`.
#'
#' @section Stock mode and flux mode:
#' The default (**stock mode**) harvests 2 percent of the standing volume
#' every year, whatever the stand: a capitalised, slow-growing stand yields
#' more fuelwood than a young stand in full production. **Flux mode** ties the
#' harvest to what the forest grows. Both modes return the same physical
#' quantity (t DM/ha/yr) and share the same normalisation ceiling.
#'
#' One combination is degenerate: a production taken from the IFN for the
#' SER (provenance `"ifn_prod_*"`, as written by P2 in IFN mode) multiplied
#' by the SER's own harvest / production ratio is simply the **observed
#' harvest** of the SER, identical for every unit of the domain. E1 then
#' warns and writes `E1_mode = "recolte_observee"` instead of
#' `"ressource_flux"`, so that it is not presented as a potential.
#'
#' @return sf object with added columns: E1 (fuelwood potential tonnes DM/ha/yr),
#' E1_residues, E1_coppice; in flux mode also `E1_mode`
#' (`"ressource_flux"` or `"recolte_observee"`). **Higher = more fuelwood available =
#' favourable**, not inverted; normalize_indicator() rescales it against a
#' ref_max of 2.64 t DM/ha/yr -- the yield of a stand at P1's own ceiling
#' (800 m3/ha, density 550), so E1, E2 and P1 score the same stand alike.
#' See spec 048 section 11. A unit with no volume gets `NA` in E1,
#' E1_residues and E1_coppice.
#'
#' @section Wood density:
#' Residue volume is converted to dry matter with the species density of
#' `inst/extdata/wood_density.csv` (`density_kg_m3`), an air-dry density
#' (about 12 percent moisture), used as is as a dry-matter density -- as C1
#' does. Versions up to 0.211.0 multiplied it by a further 0.5 ("dry matter =
#' 50 percent of fresh weight"), which halved E1.
#'
#' @export
indicateur_e1_bois_energie <- function(units,
                                      volume_field = "volume",
                                      species_field = "species",
                                      harvest_rate = 0.02,
                                      residue_fraction = 0.3,
                                      coppice_area_field = NULL,
                                      column_name = "E1",
                                      lang = "en",
                                      chm = NULL,
                                      production_field = NULL,
                                      taux_mobilisation = NULL,
                                      ser_field = "ser") {
  if (!inherits(units, "sf")) stop("units must be an sf object", call. = FALSE)

  # ---- Mode flux (spec 054 lot 4) : la recolte suit la production ----
  if (!is.null(production_field)) {
    if (!production_field %in% names(units)) {
      stop("Required field missing: ", production_field, call. = FALSE)
    }
    if (is.null(taux_mobilisation)) {
      # Pas de defaut invente : un taux suppose serait une decision cachee.
      cli::cli_abort(c(
        "Flux mode needs {.arg taux_mobilisation}.",
        "i" = "Give a share in [0, 1], or {.val ifn_ser} for the IFN harvest / production ratio of the SER."
      ))
    }
    if (!missing(harvest_rate)) {
      cli::cli_warn("{.arg harvest_rate} is ignored in flux mode: the harvest follows {.arg production_field}.")
    }
    production <- as.numeric(units[[production_field]])
    mode <- rep("ressource_flux", nrow(units))
    if (identical(taux_mobilisation, "ifn_ser")) {
      ser <- if (ser_field %in% names(units)) as.character(units[[ser_field]]) else rep(NA_character_, nrow(units))
      ser[!is.na(ser) & !nzchar(ser)] <- NA_character_
      cle <- ifelse(is.na(ser), "<national>", ser)
      r <- vapply(unique(cle), function(k) {
        ifn_taux_prelevement_production(if (k == "<national>") NULL else k)$ratio
      }, numeric(1))
      taux <- pmin(r[cle], 1)
      # Cas degenere : production de la SER x ratio de la SER = prelevement
      # observe de la SER (spec 054 §7.4).
      prov_col <- paste0(production_field, "_provenance")
      if (prov_col %in% names(units)) {
        degen <- grepl("^ifn_prod_", as.character(units[[prov_col]]))
        if (any(degen)) {
          cli::cli_warn(c(
            "{sum(degen)} unit{?s}: IFN production of the SER x IFN harvest ratio of the SER = the SER's observed harvest.",
            "i" = "E1 is then not a potential; flagged {.val recolte_observee} in {.field E1_mode}."
          ))
          mode[degen] <- "recolte_observee"
        }
      }
    } else {
      if (!is.numeric(taux_mobilisation) || any(is.na(taux_mobilisation)) ||
          any(taux_mobilisation < 0 | taux_mobilisation > 1) ||
          !length(taux_mobilisation) %in% c(1L, nrow(units))) {
        cli::cli_abort("{.arg taux_mobilisation} must be in [0, 1] (one value or one per unit), or {.val ifn_ser}.")
      }
      taux <- rep_len(taux_mobilisation, nrow(units))
    }
    units[["..volume_flux.."]] <- production * taux
    res <- indicateur_e1_bois_energie(units, volume_field = "..volume_flux..",
                                      species_field = species_field,
                                      harvest_rate = 1,
                                      residue_fraction = residue_fraction,
                                      coppice_area_field = coppice_area_field,
                                      column_name = column_name, lang = lang)
    res[["..volume_flux.."]] <- NULL
    res$E1_mode <- ifelse(is.na(res[[column_name]]), NA_character_, mode)
    return(res)
  }

  # Auto-estimate volume from CHM when missing: run P1 internally with
  # the same chm (which in turn synthesises dbh/density from the CHM
  # via ensure_inventory_fields) and copy the P1 column back as
  # volume. Keeps E1 self-contained instead of relying on P1 having
  # been run first (indicators are dispatched independently).
  if (!volume_field %in% names(units) && !is.null(chm)) {
    p1 <- tryCatch(
      indicateur_p1_volume(units, species_field = species_field,
                           chm = chm, column_name = "..p1_tmp..",
                           lang = lang),
      error = function(e) {
        cli::cli_warn("E1: synthetic P1 estimation failed: {e$message}")
        NULL
      }
    )
    if (!is.null(p1) && "..p1_tmp.." %in% names(p1)) {
      units[[volume_field]] <- p1[["..p1_tmp.."]]
      attr(units, "inventory_source") <- "synthetic_ml"
    }
  }

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
      # Unite non evaluee : les colonnes de detail suivent le total (un 0
      # laisse en place se lisait « aucun remanent »).
      e1_values[i] <- NA_real_
      e1_residues[i] <- NA_real_
      e1_coppice[i] <- NA_real_
      next
    }

    # Get species-specific wood density
    species_code <- if (species_field %in% names(units)) units[[species_field]][i] else "BROADLEAF_GENUS"
    density_kg_m3 <- lookup_species_threshold(species_code, "density_kg_m3", "wood_density")
    if (is.na(density_kg_m3)) density_kg_m3 <- 550 # Default

    # Calculate harvest residues
    annual_harvest_m3_ha <- volume_m3_ha * harvest_rate
    residues_m3_ha <- annual_harvest_m3_ha * residue_fraction
    # `density_kg_m3` (inst/extdata/wood_density.csv) est une densite de bois
    # SEC a l'air (~12 % d'humidite : chene 690, hetre 680, epicea 450), pas
    # une densite de bois vert. C1 l'emploie d'ailleurs telle quelle comme
    # masse seche par m3. L'ancien facteur « x 0.5 (MS = 50 % du poids frais) »
    # appliquait une correction d'humidite a une densite deja seche et divisait
    # E1 par deux.
    residues_tonnes_dm <- residues_m3_ha * density_kg_m3 / 1000

    # Calculate coppice biomass (if applicable)
    coppice_tonnes_dm <- 0
    if (!is.null(coppice_area_field) && coppice_area_field %in% names(units)) {
      coppice_fraction <- units[[coppice_area_field]][i]
      if (!is.na(coppice_fraction) && coppice_fraction > 0) {
        coppice_tonnes_dm <- coppice_fraction * 2 # Assume 2 tonnes DM/ha/yr for coppice
      }
    }

    e1_residues[i] <- residues_tonnes_dm
    e1_coppice[i] <- coppice_tonnes_dm
    e1_values[i] <- residues_tonnes_dm + coppice_tonnes_dm
  }

  # Un seul message agrege pour l'emprise (auparavant un message par unite).
  msg_info("energy_fuelwood_calculated",
           sum(e1_values, na.rm = TRUE),
           sum(e1_residues, na.rm = TRUE),
           sum(e1_coppice, na.rm = TRUE))

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
#' @return sf object with added columns: E2 (total CO2 avoided tCO2eq/ha/yr),
#' E2_energy, E2_material. **Higher = more emissions avoided =
#' favourable**, not inverted. Same ref_max as E1 (2.64) because it is, to
#' within 0.1 %, the same quantity: E2 = E1 x 4500 kWh x 0.222 kgCO2/kWh /
#' 1000 = E1 x 0.999. See spec 048 section 11.
#'
#' @export
indicateur_e2_evitement <- function(units,
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
  # Was any substitution actually COMPUTED for this unit? The three vectors
  # above start at zero, so a unit whose fuelwood stock is unknown used to be
  # reported as "0 tCO2eq avoided" — an absent input dressed up as a
  # measurement, which then weighs on the Energy family score
  # (`create_family_index()` averages with `na.rm = TRUE`). A unit whose E1 is
  # a genuine 0 still gets 0: nothing to burn IS nothing avoided.
  e2_calcule <- logical(nrow(units))

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
      e2_energy[i] <- energy_kwh * as.numeric(energy_factor$emission_factor_kgCO2eq_per_unit) / 1000 # Convert to tonnes
      e2_calcule[i] <- TRUE
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
          e2_calcule[i] <- TRUE
        }
      }
    }

    e2_total[i] <- e2_energy[i] + e2_material[i]
  }

  # Neither component computable -> no measurement, hence NA. The two detail
  # columns follow the total, so a caller reading `E2_energy` alone is not told
  # "0 avoided" where nothing was assessed.
  e2_total[!e2_calcule]    <- NA_real_
  e2_energy[!e2_calcule]   <- NA_real_
  e2_material[!e2_calcule] <- NA_real_

  if (!any(e2_calcule)) {
    cli::cli_alert_info(
      "{column_name}: no unit carries a usable {.field {fuelwood_field}}, \
       returning NA (no measurement made)."
    )
  }

  result$E2_energy <- e2_energy
  result$E2_material <- e2_material
  result[[column_name]] <- e2_total

  # One aggregate message for the whole AOI (previously emitted per
  # unit, which flooded the log with up to nrow(units) lines).
  msg_info(
    "energy_avoidance_calculated",
    sum(e2_total,    na.rm = TRUE),
    sum(e2_energy,   na.rm = TRUE),
    sum(e2_material, na.rm = TRUE)
  )
  cli::cli_alert_success("Calculated {column_name}: CO2 emission avoidance (tCO2eq/yr)")
  return(result)
}
