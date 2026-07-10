# test-soil-water.R — PTF Saxton & Rawls + ewm SoilGrids (spec 035).

# --- Valeurs de référence NRCS (m3/m3) par classe texturale USDA, OM = 2.5 %.
# Centroïdes approximatifs ; servent de garde-fou d'ordre de grandeur, pas de
# vérité au 3e chiffre.
usda_ref <- data.frame(
  nom    = c("sable", "limon sableux", "limon", "limon argileux",
             "argile limoneuse", "argile"),
  sand   = c(0.92, 0.65, 0.40, 0.32, 0.10, 0.20),
  clay   = c(0.03, 0.10, 0.20, 0.34, 0.47, 0.60),
  fc_ref = c(0.10, 0.21, 0.29, 0.34, 0.38, 0.39),
  wp_ref = c(0.05, 0.09, 0.14, 0.21, 0.25, 0.27),
  stringsAsFactors = FALSE
)

test_that("awc_saxton_rawls returns a plausible AWC for the loam optimum", {
  # Limon : la classe de réserve utile maximale en pédologie.
  awc <- awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 2.5)
  expect_length(awc, 1)
  expect_true(awc > 0.10 && awc < 0.20)
})

test_that("AWC is positive and bounded across every USDA texture class", {
  awc <- awc_saxton_rawls(clay = usda_ref$clay, sand = usda_ref$sand, om = 2.5)
  expect_length(awc, nrow(usda_ref))
  expect_true(all(awc > 0), info = "une RU negative revele un coefficient faux")
  expect_true(all(awc < 0.30))
})

test_that("AWC peaks on loam, not on sand nor on heavy clay", {
  awc <- awc_saxton_rawls(clay = usda_ref$clay, sand = usda_ref$sand, om = 2.5)
  names(awc) <- usda_ref$nom
  expect_equal(unname(which.max(awc)), which(usda_ref$nom == "limon"))
  expect_lt(awc[["sable"]], awc[["limon"]])
  expect_lt(awc[["argile"]], awc[["limon"]])
})

# GARDE-FOU DE COEFFICIENTS (spec 035 D3).
# Plusieurs transcriptions en ligne donnent `- 0.002` au lieu de `- 0.02`
# (point de flétrissement) et `- 0.15` au lieu de `- 0.015` (capacité au champ).
# Ce test verrouille les bonnes constantes en montrant que les variantes
# fautives produisent une capacité au champ négative pour un sable.
test_that("the published constants beat the mistranscribed web variants", {
  t33t <- function(S, C, OM) {
    -0.251 * S + 0.195 * C + 0.011 * OM + 0.006 * (S * OM) -
      0.027 * (C * OM) + 0.452 * (S * C) + 0.299
  }
  sable <- t33t(0.92, 0.03, 2.5)
  fc_bon    <- sable + (1.283 * sable^2 - 0.374 * sable - 0.015)
  fc_faux   <- sable + (1.283 * sable^2 - 0.374 * sable - 0.15)

  expect_gt(fc_bon, 0)                 # capacité au champ d'un sable : ~0.08
  expect_lt(fc_faux, 0)                # la variante web : physiquement absurde

  # Et le RMSE de la variante retenue contre les références NRCS reste faible.
  t <- t33t(usda_ref$sand, usda_ref$clay, 2.5)
  fc <- t + (1.283 * t^2 - 0.374 * t - 0.015)
  expect_lt(sqrt(mean((fc - usda_ref$fc_ref)^2)), 0.06)
})

test_that("coarse fragments scale the AWC down linearly", {
  base <- awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 2.5)
  half <- awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 2.5, coarse = 50)
  expect_equal(half, base * 0.5, tolerance = 1e-9)

  none <- awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 2.5, coarse = 100)
  expect_equal(none, 0)
})

test_that("organic matter increases the available water capacity", {
  poor <- awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 0.5)
  rich <- awc_saxton_rawls(clay = 0.20, sand = 0.40, om = 6)
  expect_gt(rich, poor)
})

test_that("awc_saxton_rawls rejects percentages given as fractions", {
  expect_error(awc_saxton_rawls(clay = 20, sand = 40, om = 2.5),
               "fractions")
  expect_error(awc_saxton_rawls(clay = 0.2, sand = 0.4, om = 2.5, coarse = 150),
               "volume percentage")
})

test_that("awc_saxton_rawls is NA in, NA out and recycles scalars", {
  awc <- awc_saxton_rawls(clay = c(0.2, NA), sand = 0.4, om = 2.5)
  expect_length(awc, 2)
  expect_false(is.na(awc[1]))
  expect_true(is.na(awc[2]))
})

# --- SOILGRIDS_DEPTHS / échelles ---

test_that("SOILGRIDS_DEPTHS covers the six standard ISRIC intervals", {
  expect_equal(nrow(SOILGRIDS_DEPTHS), 6)
  expect_equal(SOILGRIDS_DEPTHS$top_cm, c(0, 5, 15, 30, 60, 100))
  expect_equal(SOILGRIDS_DEPTHS$bottom_cm, c(5, 15, 30, 60, 100, 200))
})

test_that("the SoilGrids scale factor for soc is the dg/kg one", {
  # Piège d'un facteur 10 : soc est en dg/kg, donc %OC = brut / 100 et non /10.
  expect_equal(SOILGRIDS_SCALE[["soc"]], 10)   # brut/10 -> g/kg
  expect_equal(SOILGRIDS_SCALE[["bdod"]], 100) # brut/100 -> kg/dm3
  expect_equal(SOILGRIDS_SCALE[["clay"]], 10)  # brut/10 -> %
})

test_that("every soilgrids_* datasource is declared for the six depths", {
  for (p in c("clay", "sand", "silt", "soc", "cfvo")) {
    for (i in SOILGRIDS_DEPTHS$interval) {
      key <- paste0("soilgrids_", p, "_", i)
      src <- get_data_source(key, "FR")
      expect_false(is.null(src), info = key)
      expect_equal(src$type, "raster_remote", info = key)
      expect_match(src$url, "files\\.isric\\.org", info = key)
      expect_match(src$url, paste0(i, "cm_mean\\.vrt$"), info = key)
    }
  }
})

# --- ewm_depuis_soilgrids : validation d'arguments (offline) ---

test_that("ewm_depuis_soilgrids validates rooting depth and intervals", {
  units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))),
      sf::st_polygon(list(rbind(c(1, 0), c(2, 0), c(2, 1), c(1, 1), c(1, 0)))),
      crs = 2154))

  expect_error(ewm_depuis_soilgrids(units, rooting_depth_cm = -5), "positive")
  expect_error(ewm_depuis_soilgrids(units, rooting_depth_cm = 0), "positive")
  expect_error(ewm_depuis_soilgrids(units, depths = "42-99"),
               "Unknown SoilGrids depth interval")
})

test_that("ewm_depuis_soilgrids degrades to NULL when no layer can be loaded", {
  units <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))),
      crs = 2154))
  # Aucune couche résolvable -> NULL (dégradation propre), pas d'erreur.
  local_mocked_bindings(.sg_property_by_unit = function(...) NULL)
  expect_null(ewm_depuis_soilgrids(units))
})

test_that("ewm integrates AWC over the rooting depth, in mm", {
  units <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))),
      crs = 2154))

  # Sol homogène : AWC constante quelle que soit la profondeur.
  # clay 20 %, sand 40 %, soc 25 g/kg (=> OM 4.31 %), cfvo 0.
  local_mocked_bindings(.sg_property_by_unit = function(units, property, interval, country = "FR") {
    switch(property, clay = 20, sand = 40, soc = 25, cfvo = 0)
  })

  awc <- awc_saxton_rawls(clay = 0.20, sand = 0.40, om = (25 / 10) * 1.724)
  # rooting_depth_cm = 30 -> horizons 0-5, 5-15, 15-30 => 30 cm au total
  ewm <- ewm_depuis_soilgrids(units, rooting_depth_cm = 30)
  expect_equal(ewm, awc * 30 * 10, tolerance = 1e-8)

  # Doubler la profondeur double la réserve sur un sol homogène.
  expect_equal(ewm_depuis_soilgrids(units, rooting_depth_cm = 60),
               awc * 60 * 10, tolerance = 1e-8)
})

test_that("the deepest horizon is truncated at the rooting depth", {
  units <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))),
      crs = 2154))
  local_mocked_bindings(.sg_property_by_unit = function(units, property, interval, country = "FR") {
    switch(property, clay = 20, sand = 40, soc = 25, cfvo = 0)
  })
  awc <- awc_saxton_rawls(clay = 0.20, sand = 0.40, om = (25 / 10) * 1.724)
  # 40 cm : horizons 0-5, 5-15, 15-30 entiers + 30-60 tronqué à 10 cm.
  expect_equal(ewm_depuis_soilgrids(units, rooting_depth_cm = 40),
               awc * 40 * 10, tolerance = 1e-8)
})

test_that("coarse fragments reduce the resulting ewm", {
  units <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))),
      crs = 2154))
  stony <- local({
    local_mocked_bindings(.sg_property_by_unit = function(units, property, interval, country = "FR") {
      switch(property, clay = 20, sand = 40, soc = 25, cfvo = 60)
    })
    ewm_depuis_soilgrids(units, rooting_depth_cm = 30)
  })
  clean <- local({
    local_mocked_bindings(.sg_property_by_unit = function(units, property, interval, country = "FR") {
      switch(property, clay = 20, sand = 40, soc = 25, cfvo = 0)
    })
    ewm_depuis_soilgrids(units, rooting_depth_cm = 30)
  })
  expect_equal(stony, clean * 0.4, tolerance = 1e-8)
})

test_that("ewm_depuis_soilgrids emits the monitoring payloads", {
  units <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))),
      crs = 2154))
  local_mocked_bindings(.sg_property_by_unit = function(units, property, interval, country = "FR") {
    switch(property, clay = 20, sand = 40, soc = 25, cfvo = 0)
  })
  seen <- character(0)
  ewm_depuis_soilgrids(units, rooting_depth_cm = 15,
                       progress_callback = function(p) seen <<- c(seen, p$current))
  expect_true("ewm:layer" %in% seen)
  expect_true("ewm:complete" %in% seen)
  expect_equal(sum(seen == "ewm:layer"), 2L)  # horizons 0-5 et 5-15
})
