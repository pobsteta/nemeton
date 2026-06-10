# Test Suite for Energy & Climate Indicators (Family E)
# US3: E1 (fuelwood potential), E2 (carbon avoidance)

# ==============================================================================
# Helper: create a simple polygon sf for energy tests
# ==============================================================================
make_energy_sf <- function(n = 1, extra_cols = list(), crs = 2154) {
  polys <- lapply(seq_len(n), function(i) {
    xmin <- (i - 1) * 1000
    sf::st_polygon(list(matrix(
      c(xmin, 0, xmin + 1000, 0, xmin + 1000, 1000, xmin, 1000, xmin, 0),
      ncol = 2, byrow = TRUE
    )))
  })
  df <- data.frame(id = seq_len(n))
  for (nm in names(extra_cols)) {
    df[[nm]] <- extra_cols[[nm]]
  }
  sf::st_sf(df, geometry = sf::st_sfc(polys, crs = crs))
}

# ==============================================================================
# indicateur_e1_bois_energie (E1)
# ==============================================================================

test_that("indicateur_e1_bois_energie (E1) calculates biomass potential", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(3, list(
    volume = c(200, 150, 180),
    species = c("FASY", "PIAB", "QUPE")
  ))

  result <- indicateur_e1_bois_energie(
    units = test_units,
    volume_field = "volume",
    species_field = "species"
  )

  expect_s3_class(result, "sf")
  expect_true(all(c("E1", "E1_residues", "E1_coppice") %in% names(result)))
  expect_type(result$E1, "double")
  expect_true(all(result$E1 > 0, na.rm = TRUE))
})

test_that("indicateur_e1_bois_energie validates input is sf", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_e1_bois_energie(data.frame(x = 1:3)),
    "must be an sf object"
  )
  expect_error(
    indicateur_e1_bois_energie(NULL),
    "must be an sf object"
  )
  expect_error(
    indicateur_e1_bois_energie("not_sf"),
    "must be an sf object"
  )
})

test_that("indicateur_e1_bois_energie requires volume field", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1)

  expect_error(
    indicateur_e1_bois_energie(test_units, volume_field = "volume"),
    "Required field missing"
  )
  expect_error(
    indicateur_e1_bois_energie(test_units, volume_field = "nonexistent"),
    "Required field missing"
  )
})

test_that("indicateur_e1_bois_energie handles NA volume values", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(3, list(
    volume = c(200, NA, 180),
    species = c("FASY", "PIAB", "QUPE")
  ))

  result <- indicateur_e1_bois_energie(test_units, volume_field = "volume", species_field = "species")

  expect_false(is.na(result$E1[1]))
  expect_true(is.na(result$E1[2]))
  expect_false(is.na(result$E1[3]))
  # E1_residues and E1_coppice should remain 0 for the NA row (default numeric(n))
  expect_equal(result$E1_residues[2], 0)
  expect_equal(result$E1_coppice[2], 0)
})

test_that("indicateur_e1_bois_energie uses species-specific density when species field present", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(
    volume = 200,
    species = "FASY"
  ))

  result <- indicateur_e1_bois_energie(
    test_units,
    volume_field = "volume",
    species_field = "species"
  )

  # With FASY (beech), density should be looked up. E1 should be positive.
  expect_true(result$E1[1] > 0)
  expect_true(result$E1_residues[1] > 0)
  expect_equal(result$E1_coppice[1], 0)
})

test_that("indicateur_e1_bois_energie falls back to BROADLEAF_GENUS when species field absent", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # No 'species' column at all -- should use "BROADLEAF_GENUS" fallback
  test_units <- make_energy_sf(1, list(volume = 200))

  result <- indicateur_e1_bois_energie(
    test_units,
    volume_field = "volume",
    species_field = "species"  # not in names(units)
  )

  expect_true(result$E1[1] > 0)
  expect_true(result$E1_residues[1] > 0)
})

test_that("indicateur_e1_bois_energie uses default density 550 when lookup returns NA", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(
    volume = 200,
    species = "FASY"
  ))

  # Mock lookup_species_threshold to return NA so fallback density 550 is used
  # Must patch both the namespace AND the function's environment (which may differ
  # under pkgload after local_mocked_bindings is used in earlier tests)
  fn_env <- environment(indicateur_e1_bois_energie)
  ns <- asNamespace("nemeton")
  mock_fn <- function(species_code, parameter, table_name) NA_real_

  # Deduplicate environments: if ns and fn_env are the same environment,
  # patching twice would cause the cleanup to save the mock as "original"
  # on the second iteration and leak the mock into the namespace.
  candidate_envs <- list(ns)
  if (!identical(fn_env, ns)) {
    candidate_envs <- c(candidate_envs, list(fn_env))
  }
  envs_to_patch <- list()
  for (env in candidate_envs) {
    if (exists("lookup_species_threshold", envir = env, inherits = FALSE)) {
      envs_to_patch <- c(envs_to_patch, list(env))
    }
  }

  orig_fns <- list()
  for (env in envs_to_patch) {
    tryCatch({
      orig_fns <- c(orig_fns, list(list(env = env, fn = get("lookup_species_threshold", envir = env))))
      if (bindingIsLocked("lookup_species_threshold", env)) {
        unlockBinding("lookup_species_threshold", env)
      }
      assign("lookup_species_threshold", mock_fn, envir = env)
    }, error = function(e) NULL)
  }
  on.exit({
    for (item in orig_fns) {
      tryCatch({
        if (bindingIsLocked("lookup_species_threshold", item$env)) {
          unlockBinding("lookup_species_threshold", item$env)
        }
        assign("lookup_species_threshold", item$fn, envir = item$env)
        lockBinding("lookup_species_threshold", item$env)
      }, error = function(e) NULL)
    }
  }, add = TRUE)

  result <- indicateur_e1_bois_energie(
    test_units,
    volume_field = "volume",
    species_field = "species"
  )

  # Should still produce a result using default density 550
  expect_true(result$E1[1] > 0)
  # Manually verify: volume=200, harvest_rate=0.02, residue_fraction=0.3, density=550
  # annual_harvest = 200 * 0.02 = 4
  # residues_m3 = 4 * 0.3 = 1.2
  # residues_tonnes_dm = 1.2 * 550 / 1000 * 0.5 = 0.33
  expect_equal(result$E1_residues[1], 1.2 * 550 / 1000 * 0.5)
})

test_that("indicateur_e1_bois_energie uses custom harvest rate and residue fraction", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(volume = 200, species = "FASY"))

  result_low <- indicateur_e1_bois_energie(
    test_units, volume_field = "volume", harvest_rate = 0.01
  )

  result_high <- indicateur_e1_bois_energie(
    test_units, volume_field = "volume", harvest_rate = 0.04
  )

  # Higher harvest rate should produce more fuelwood
  expect_true(result_high$E1[1] > result_low$E1[1])

  # Test custom residue_fraction
  result_low_res <- indicateur_e1_bois_energie(
    test_units, volume_field = "volume", residue_fraction = 0.1
  )
  result_high_res <- indicateur_e1_bois_energie(
    test_units, volume_field = "volume", residue_fraction = 0.5
  )
  expect_true(result_high_res$E1[1] > result_low_res$E1[1])
})

test_that("indicateur_e1_bois_energie uses coppice area if provided", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(
    volume = c(200, 200),
    species = c("FASY", "FASY"),
    coppice_fraction = c(0, 0.5)
  ))

  result <- indicateur_e1_bois_energie(
    test_units,
    volume_field = "volume",
    species_field = "species",
    coppice_area_field = "coppice_fraction"
  )

  # Unit with coppice should have higher E1 and non-zero E1_coppice
  expect_true(result$E1[2] > result$E1[1])
  expect_equal(result$E1_coppice[1], 0)
  expect_true(result$E1_coppice[2] > 0)
  # Coppice formula: coppice_fraction * 2
  expect_equal(result$E1_coppice[2], 0.5 * 2)
})

test_that("indicateur_e1_bois_energie handles NA coppice_fraction", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(
    volume = c(200, 200),
    species = c("FASY", "FASY"),
    coppice_fraction = c(NA, 0.3)
  ))

  result <- indicateur_e1_bois_energie(
    test_units,
    volume_field = "volume",
    species_field = "species",
    coppice_area_field = "coppice_fraction"
  )

  # NA coppice should yield 0 coppice contribution
  expect_equal(result$E1_coppice[1], 0)
  # Non-NA coppice should contribute
  expect_equal(result$E1_coppice[2], 0.3 * 2)
})

test_that("indicateur_e1_bois_energie ignores coppice when field not in data", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(
    volume = 200,
    species = "FASY"
  ))

  result <- indicateur_e1_bois_energie(
    test_units,
    volume_field = "volume",
    coppice_area_field = "nonexistent_field"
  )

  # Since the coppice field does not exist, all coppice should be 0
  expect_equal(result$E1_coppice[1], 0)
  expect_true(result$E1[1] > 0)
})

test_that("indicateur_e1_bois_energie uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(volume = 200))

  result <- indicateur_e1_bois_energie(
    test_units,
    volume_field = "volume",
    column_name = "fuelwood_potential"
  )

  expect_true("fuelwood_potential" %in% names(result))
  expect_true("E1_residues" %in% names(result))
  expect_true("E1_coppice" %in% names(result))
})

test_that("indicateur_e1_bois_energie preserves original sf columns", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(
    volume = c(200, 150),
    species = c("FASY", "PIAB"),
    extra_col = c("a", "b")
  ))

  result <- indicateur_e1_bois_energie(test_units, volume_field = "volume", species_field = "species")

  expect_true("extra_col" %in% names(result))
  expect_equal(result$extra_col, c("a", "b"))
  expect_equal(nrow(result), 2)
})

test_that("indicateur_e1_bois_energie handles zero volume", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(volume = 0, species = "FASY"))

  result <- indicateur_e1_bois_energie(test_units, volume_field = "volume")

  expect_equal(result$E1[1], 0)
  expect_equal(result$E1_residues[1], 0)
})

# ==============================================================================
# indicateur_e2_evitement (E2)
# ==============================================================================

test_that("indicateur_e2_evitement (E2) calculates CO2 substitution", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(E1 = c(5.0, 3.5)))

  result <- indicateur_e2_evitement(
    units = test_units,
    fuelwood_field = "E1",
    energy_scenario = "vs_natural_gas"
  )

  expect_s3_class(result, "sf")
  expect_true(all(c("E2", "E2_energy", "E2_material") %in% names(result)))
  expect_true(all(result$E2 > 0, na.rm = TRUE))
  expect_true(all(result$E2_energy > 0, na.rm = TRUE))
  # No material substitution requested, so E2_material should be 0
  expect_true(all(result$E2_material == 0))
})

test_that("indicateur_e2_evitement validates input is sf", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_e2_evitement(data.frame(x = 1:3)),
    "must be an sf object"
  )
  expect_error(
    indicateur_e2_evitement(NULL),
    "must be an sf object"
  )
  expect_error(
    indicateur_e2_evitement(list(a = 1)),
    "must be an sf object"
  )
})

test_that("indicateur_e2_evitement handles missing fuelwood field gracefully", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1)

  result <- indicateur_e2_evitement(test_units, fuelwood_field = "E1")

  expect_true("E2" %in% names(result))
  expect_equal(result$E2[1], 0)
  expect_equal(result$E2_energy[1], 0)
  expect_equal(result$E2_material[1], 0)
})

test_that("indicateur_e2_evitement handles NA fuelwood values", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(3, list(E1 = c(5.0, NA, 3.0)))

  result <- indicateur_e2_evitement(test_units, fuelwood_field = "E1")

  expect_true(result$E2_energy[1] > 0)
  expect_equal(result$E2_energy[2], 0)  # NA fuelwood => no energy calculation
  expect_true(result$E2_energy[3] > 0)
})

test_that("indicateur_e2_evitement E2 total = E2_energy + E2_material", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(
    E1 = c(5.0, 3.5),
    construction_volume = c(50, 30)
  ))

  result <- indicateur_e2_evitement(
    test_units,
    fuelwood_field = "E1",
    volume_field = "construction_volume",
    material_scenario = "vs_concrete"
  )

  for (i in seq_len(nrow(result))) {
    expect_equal(result$E2[i], result$E2_energy[i] + result$E2_material[i])
  }
})

test_that("indicateur_e2_evitement works with material substitution", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(
    E1 = c(5.0, 3.5),
    construction_volume = c(50, 30)
  ))

  result <- indicateur_e2_evitement(
    test_units,
    fuelwood_field = "E1",
    volume_field = "construction_volume",
    material_scenario = "vs_concrete"
  )

  expect_true("E2" %in% names(result))
  expect_true("E2_material" %in% names(result))
  # Both E2_energy and E2_material should be > 0
  expect_true(all(result$E2_energy > 0))
})

test_that("indicateur_e2_evitement handles NA construction volume in material calc", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(
    E1 = c(5.0, 3.5),
    construction_volume = c(NA, 30)
  ))

  result <- indicateur_e2_evitement(
    test_units,
    fuelwood_field = "E1",
    volume_field = "construction_volume",
    material_scenario = "vs_concrete"
  )

  # First row: NA construction_volume => E2_material = 0
  expect_equal(result$E2_material[1], 0)
  # E2_energy should still be calculated
  expect_true(result$E2_energy[1] > 0)
})

test_that("indicateur_e2_evitement with unknown energy scenario warns and uses default", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(E1 = 5.0))

  # An unknown scenario should trigger lookup_ademe_factor returning NULL,
  # which should emit a warning and use the default factor
  expect_warning(
    result <- indicateur_e2_evitement(
      test_units,
      fuelwood_field = "E1",
      energy_scenario = "vs_unknown_scenario_xyz"
    ),
    "not found"
  )

  expect_true("E2" %in% names(result))
  # Should still calculate using default factor (0.222)
  # 5.0 * 4500 * 0.222 / 1000 = 4.995
  expect_equal(result$E2_energy[1], 5.0 * 4500 * 0.222 / 1000)
})

test_that("indicateur_e2_evitement with material_scenario but missing volume_field in data", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(E1 = 5.0))

  # material_scenario set, volume_field set to something not in the data
  result <- indicateur_e2_evitement(
    test_units,
    fuelwood_field = "E1",
    volume_field = "nonexistent_col",
    material_scenario = "vs_concrete"
  )

  # Material contribution should be 0 because volume_field not found
  expect_equal(result$E2_material[1], 0)
  expect_true(result$E2_energy[1] > 0)
})

test_that("indicateur_e2_evitement uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(E1 = 5.0))

  result <- indicateur_e2_evitement(
    test_units,
    fuelwood_field = "E1",
    column_name = "co2_avoided"
  )

  expect_true("co2_avoided" %in% names(result))
  expect_true("E2_energy" %in% names(result))
  expect_true("E2_material" %in% names(result))
})

test_that("indicateur_e2_evitement handles different energy scenarios", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(E1 = 5.0))

  result_gas <- indicateur_e2_evitement(
    test_units, fuelwood_field = "E1", energy_scenario = "vs_natural_gas"
  )
  expect_true(result_gas$E2[1] > 0)

  result_oil <- indicateur_e2_evitement(
    test_units, fuelwood_field = "E1", energy_scenario = "vs_fuel_oil"
  )
  expect_true("E2" %in% names(result_oil))
})

test_that("indicateur_e2_evitement preserves original sf columns", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(E1 = 5.0, extra = "hello"))

  result <- indicateur_e2_evitement(test_units, fuelwood_field = "E1")

  expect_true("extra" %in% names(result))
  expect_equal(result$extra[1], "hello")
})

test_that("indicateur_e2_evitement with zero fuelwood produces zero CO2 avoidance", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(1, list(E1 = 0))

  result <- indicateur_e2_evitement(test_units, fuelwood_field = "E1")

  expect_equal(result$E2_energy[1], 0)
  expect_equal(result$E2[1], 0)
})

# ==============================================================================
# E1 + E2 Integration
# ==============================================================================

test_that("Energy family integrates: E1 piped into E2", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(
    volume = c(200, 150),
    species = c("FASY", "PIAB")
  ))

  result <- test_units |>
    indicateur_e1_bois_energie(volume_field = "volume", species_field = "species") |>
    indicateur_e2_evitement(fuelwood_field = "E1")

  expect_true(all(c("E1", "E2", "E1_residues", "E1_coppice", "E2_energy", "E2_material") %in% names(result)))
  expect_true(all(result$E1 > 0))
  expect_true(all(result$E2 > 0))
})

test_that("E1 + E2 chain with coppice and material substitution", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(
    volume = c(200, 150),
    species = c("FASY", "PIAB"),
    coppice_fraction = c(0.3, 0),
    construction_volume = c(40, 25)
  ))

  result <- test_units |>
    indicateur_e1_bois_energie(
      volume_field = "volume",
      species_field = "species",
      coppice_area_field = "coppice_fraction"
    ) |>
    indicateur_e2_evitement(
      fuelwood_field = "E1",
      volume_field = "construction_volume",
      material_scenario = "vs_concrete"
    )

  expect_true(all(c("E1", "E2") %in% names(result)))
  # Unit 1 has coppice => E1 should be higher
  expect_true(result$E1_coppice[1] > 0)
  expect_equal(result$E1_coppice[2], 0)
  # Both should have material contribution
  expect_true(all(result$E2_energy > 0))
})

test_that("Energy family integrates with family system", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- make_energy_sf(2, list(
    volume = c(200, 150),
    species = c("FASY", "PIAB")
  ))

  result <- test_units |>
    indicateur_e1_bois_energie(volume_field = "volume", species_field = "species") |>
    indicateur_e2_evitement(fuelwood_field = "E1")

  expect_true(all(c("E1", "E2") %in% names(result)))

  result_family <- create_family_index(result, family_codes = "E")
  expect_true("famille_energie" %in% names(result_family))
  expect_true(all(result_family$famille_energie > 0))
})

# ==============================================================================
# (migrated from test-cov60-batch4.R)
# ==============================================================================

test_that("indicateur_e1_bois_energie returns E1", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$volume <- c(100, 200, 300)
  units$essence <- c("Quercus", "Fagus", "Pinus")

  result <- indicateur_e1_bois_energie(
    units,
    volume_field = "volume",
    species_field = "essence"
  )
  expect_s3_class(result, "sf")
  expect_true("E1" %in% names(result))
})

test_that("indicateur_e1_bois_energie errors without volume field", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)

  expect_error(indicateur_e1_bois_energie(units), "Required field missing")
})

test_that("indicateur_e1_bois_energie with custom harvest_rate", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)
  units$volume <- c(100, 200)

  result <- indicateur_e1_bois_energie(
    units, volume_field = "volume", harvest_rate = 0.5
  )
  expect_s3_class(result, "sf")
  expect_true("E1" %in% names(result))
})

test_that("indicateur_e2_evitement returns E2", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$E1 <- c(50, 100, 150)
  units$volume <- c(100, 200, 300)

  result <- indicateur_e2_evitement(
    units,
    fuelwood_field = "E1",
    volume_field = "volume"
  )
  expect_s3_class(result, "sf")
  expect_true("E2" %in% names(result))
})

test_that("indicateur_e2_evitement with default fields", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)

  result <- indicateur_e2_evitement(units)
  expect_s3_class(result, "sf")
  expect_true("E2" %in% names(result))
})

test_that("indicateur_e2_evitement with custom column_name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)

  result <- indicateur_e2_evitement(units, column_name = "co2_avoided")
  expect_true("co2_avoided" %in% names(result))
})
