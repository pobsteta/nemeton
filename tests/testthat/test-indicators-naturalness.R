# Test Suite for Naturalness & Wilderness Indicators (Family N)
# N1: Distance to infrastructure, N2: Forest continuity, N3: Composite

# ==============================================================================
# N1: Distance to Infrastructure
# ==============================================================================

test_that("indicateur_n1_distance (N1) works with roads + buildings", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Create test units: one near infrastructure, one far
  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(
        605000, 6601000,
        605200, 6601000,
        605200, 6601200,
        605000, 6601200,
        605000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Road close to unit 1
  roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  # Building close to unit 1
  buildings <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        601000, 6601000,
        601050, 6601000,
        601050, 6601050,
        601000, 6601050,
        601000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n1_distance(
    units = test_units,
    roads = roads,
    buildings = buildings
  )

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  expect_type(result$N1, "double")

  # Both should have values in 0-100 range
  expect_true(all(!is.na(result$N1)))
  expect_true(all(result$N1 >= 0 & result$N1 <= 100))

  # Unit near infrastructure should have lower N1 (less remote)
  expect_true(result$N1[1] < result$N1[2])
})

test_that("indicateur_n1_distance (N1) returns default scores without roads/buildings", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n1_distance(units = test_units)

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  # Default distances: routes=1000, batiments=500, urbain=2000
  # N1 = 0.40*pmin(100,1000/20) + 0.35*pmin(100,500/20) + 0.25*pmin(100,2000/20)
  # N1 = 0.40*50 + 0.35*25 + 0.25*100 = 20 + 8.75 + 25 = 53.75
  expect_equal(result$N1[1], 53.75)
})

test_that("indicateur_n1_distance validates input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_n1_distance(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicateur_n1_distance uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n1_distance(test_units, column_name = "remoteness")

  expect_true("remoteness" %in% names(result))
  expect_false("N1" %in% names(result))
})

test_that("indicateur_n1_distance (N1) handles empty roads sf (0 rows)", {
  skip_if_not_installed("terra")

  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Empty roads sf (no features) -- triggers the else branch for roads
  empty_roads <- sf::st_sf(
    id = integer(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  # Non-empty buildings
  buildings <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        500, 500, 510, 500, 510, 510, 500, 510, 500, 500
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n1_distance(
    units = test_units,
    roads = empty_roads,
    buildings = buildings
  )

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  # roads default to 1000m distance, buildings have real distance
  expect_true(result$N1[1] >= 0 & result$N1[1] <= 100)
})

test_that("indicateur_n1_distance (N1) handles empty buildings sf (0 rows)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Non-empty roads
  roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(500, 0, 500, 1000), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  # Empty buildings sf (no features) -- triggers the else branch for buildings
  empty_buildings <- sf::st_sf(
    id = integer(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  result <- indicateur_n1_distance(
    units = test_units,
    roads = roads,
    buildings = empty_buildings
  )

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  # roads have real distance, buildings default to 500m
  expect_true(result$N1[1] >= 0 & result$N1[1] <= 100)
})

test_that("indicateur_n1_distance (N1) handles non-sf roads/buildings (ignored)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Pass non-sf objects for roads and buildings: they should be ignored (treated as NULL)
  result <- indicateur_n1_distance(
    units = test_units,
    roads = data.frame(x = 1),
    buildings = list(a = 1)
  )

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  # Both fall back to defaults: same as no roads/buildings
  expect_equal(result$N1[1], 53.75)
})

test_that("indicateur_n1_distance (N1) resolves layers via nemeton_layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Create sf objects to embed in a fake nemeton_layers
  roads_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  buildings_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        601000, 6601000,
        601050, 6601000,
        601050, 6601050,
        601000, 6601050,
        601000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Create a mock nemeton_layers object (class + vectors list)
  mock_layers <- list(
    vectors = list(
      roads = roads_sf,
      buildings = buildings_sf
    ),
    rasters = list(),
    metadata = list(n_rasters = 0, n_vectors = 2)
  )
  class(mock_layers) <- "nemeton_layers"

  # Use layers argument (roads/buildings = NULL, so they get resolved from layers)
  result <- indicateur_n1_distance(
    units = test_units,
    layers = mock_layers
  )

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  expect_true(result$N1[1] >= 0 & result$N1[1] <= 100)
  # With real roads nearby, the road component should give a low score
  # (centroid is near the road at x=601000)
  expect_true(result$N1[1] < 53.75)  # Less than the default
})

test_that("indicateur_n1_distance (N1) with layers but no matching vector names", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Create nemeton_layers with no roads/buildings keys
  mock_layers <- list(
    vectors = list(rivers = sf::st_sf(id = 1, geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(0, 0, 1000, 1000), ncol = 2, byrow = TRUE)),
      crs = 2154
    ))),
    rasters = list(),
    metadata = list(n_rasters = 0, n_vectors = 1)
  )
  class(mock_layers) <- "nemeton_layers"

  result <- indicateur_n1_distance(
    units = test_units,
    layers = mock_layers
  )

  # resolve_vector_layer returns NULL for "roads" and "buildings" -> defaults used
  expect_equal(result$N1[1], 53.75)
})

test_that("indicateur_n1_distance (N1) roads/buildings override layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Direct roads (very close)
  direct_roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  # Layers with far-away roads (should not be used since direct roads are provided)
  far_roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(700000, 6601000, 700000, 6602000), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )
  mock_layers <- list(
    vectors = list(roads = far_roads),
    rasters = list(),
    metadata = list(n_rasters = 0, n_vectors = 1)
  )
  class(mock_layers) <- "nemeton_layers"

  result <- indicateur_n1_distance(
    units = test_units,
    roads = direct_roads,
    layers = mock_layers
  )

  # Direct roads are close -> small road distance -> score should be low
  # The layers roads (far away) should NOT be used
  expect_true(result$N1[1] < 53.75)
})

test_that("indicateur_n1_distance (N1) transforms CRS for roads in different CRS", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Units in Lambert 93 (EPSG:2154)
  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Create road in WGS84 (EPSG:4326) -- the function should transform it
  road_2154 <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(601000, 6600000, 601000, 6602500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )
  road_4326 <- sf::st_transform(road_2154, 4326)

  result <- indicateur_n1_distance(
    units = test_units,
    roads = road_4326
  )

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  expect_true(result$N1[1] >= 0 & result$N1[1] <= 100)
})

test_that("indicateur_n1_distance (N1) handles multiple units", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 5)

  result <- indicateur_n1_distance(units = test_units)

  expect_equal(nrow(result), 5)
  expect_true(all(!is.na(result$N1)))
  expect_true(all(result$N1 >= 0 & result$N1 <= 100))
})

test_that("indicateur_n1_distance (N1) normalization caps at 100", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Unit far from everything -- default dist_urbain = 2000 -> 2000/20 = 100 (capped)
  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Very far roads and buildings (>2000m distance)
  far_roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(100000, 0, 100000, 100), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )
  far_buildings <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        100000, 0, 100010, 0, 100010, 10, 100000, 10, 100000, 0
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n1_distance(
    units = test_units,
    roads = far_roads,
    buildings = far_buildings
  )

  # All components capped at 100 -> N1 = 0.40*100 + 0.35*100 + 0.25*100 = 100
  expect_equal(result$N1[1], 100)
})

# ==============================================================================
# N2: Forest Continuity
# ==============================================================================

test_that("indicateur_n2_continuite (N2) works with bdforet", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Test unit
  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200, 0, 300, 0, 300, 100, 200, 100, 200, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # BD Foret covering unit 1 entirely, not unit 2
  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet
  )

  expect_s3_class(result, "sf")
  expect_true("N2" %in% names(result))
  expect_type(result$N2, "double")

  # Unit 1 has forest -> score 30-60 range (recent forest)
  expect_true(result$N2[1] > 30 & result$N2[1] <= 60)
  # Unit 2 has no forest -> score 15
  expect_equal(result$N2[2], 15)
})

test_that("indicateur_n2_continuite (N2) with ancient forest", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  foret_ancienne <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet,
    foret_ancienne = foret_ancienne
  )

  # Ancient forest -> score 60 + 40*taux_ancienne (approx 100)
  expect_true(result$N2[1] >= 60 & result$N2[1] <= 100)
})

test_that("indicateur_n2_continuite (N2) returns 50 without data", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n2_continuite(units = test_units)

  expect_equal(result$N2[1], 50)
})

test_that("indicateur_n2_continuite validates input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_n2_continuite(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicateur_n2_continuite uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n2_continuite(test_units, column_name = "forest_cont")

  expect_true("forest_cont" %in% names(result))
  expect_false("N2" %in% names(result))
})

test_that("indicateur_n2_continuite (N2) handles empty bdforet sf (0 rows)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Empty bdforet with 0 rows -> gets set to NULL on line 127-128
  empty_bdforet <- sf::st_sf(
    id = integer(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  # With foret_ancienne as NULL and bdforet effectively NULL (empty),
  # the function still enters the for loop (since bdforet was not NULL initially
  # but foret_ancienne is). After bdforet gets nullified, taux_boisement=0
  # and taux_ancienne=0 => score=15
  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = empty_bdforet
  )

  expect_s3_class(result, "sf")
  expect_true("N2" %in% names(result))
  expect_equal(result$N2[1], 15)
})

test_that("indicateur_n2_continuite (N2) handles empty foret_ancienne sf (0 rows)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Empty foret_ancienne (0 rows) -> gets set to NULL on line 133-134
  empty_ancienne <- sf::st_sf(
    id = integer(0),
    geometry = sf::st_sfc(crs = 2154)
  )

  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet,
    foret_ancienne = empty_ancienne
  )

  expect_s3_class(result, "sf")
  # With bdforet covering the unit fully but no ancient forest,
  # taux_boisement > 0, taux_ancienne = 0 -> score = 30 + 30 * taux_boisement
  expect_true(result$N2[1] > 30 & result$N2[1] <= 60)
})

test_that("indicateur_n2_continuite (N2) with partial bdforet coverage", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Unit is 100x100
  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # BD Foret covers only roughly half the unit (left half: 0-50)
  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 50, 0, 50, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet
  )

  # taux_boisement ~ 0.5, score = 30 + 30*0.5 = 45
  expect_true(result$N2[1] > 30 & result$N2[1] <= 60)
  # More specifically, approximately 45
  expect_equal(result$N2[1], 45, tolerance = 2)
})

test_that("indicateur_n2_continuite (N2) with partial ancient forest", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # Unit is 100x100
  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Ancient forest covers half the unit (left half: 0-50)
  foret_ancienne <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 50, 0, 50, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet,
    foret_ancienne = foret_ancienne
  )

  # taux_ancienne ~ 0.5, score = 60 + 40*0.5 = 80
  expect_true(result$N2[1] >= 60 & result$N2[1] <= 100)
  expect_equal(result$N2[1], 80, tolerance = 2)
})

test_that("indicateur_n2_continuite (N2) with foret_ancienne only (no bdforet)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  foret_ancienne <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # bdforet = NULL, foret_ancienne provided -> enters the loop
  # taux_boisement = 0 (no bdforet), taux_ancienne ~ 1.0
  # score = 60 + 40 * 1.0 = 100
  result <- indicateur_n2_continuite(
    units = test_units,
    foret_ancienne = foret_ancienne
  )

  expect_true(result$N2[1] >= 60 & result$N2[1] <= 100)
})

test_that("indicateur_n2_continuite (N2) resolves bdforet from nemeton_layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  bdforet_sf <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Create mock nemeton_layers with bdforet
  mock_layers <- list(
    vectors = list(bdforet = bdforet_sf),
    rasters = list(),
    metadata = list(n_rasters = 0, n_vectors = 1)
  )
  class(mock_layers) <- "nemeton_layers"

  result <- indicateur_n2_continuite(
    units = test_units,
    layers = mock_layers
  )

  # bdforet resolved from layers, covers the unit -> recent forest score
  expect_true(result$N2[1] > 30 & result$N2[1] <= 60)
})

test_that("indicateur_n2_continuite (N2) bdforet arg overrides layers", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Direct bdforet covers the unit
  direct_bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Layers bdforet that does NOT cover the unit at all (far away)
  far_bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(9000, 9000, 9100, 9000, 9100, 9100, 9000, 9100, 9000, 9000), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )
  mock_layers <- list(
    vectors = list(bdforet = far_bdforet),
    rasters = list(),
    metadata = list(n_rasters = 0, n_vectors = 1)
  )
  class(mock_layers) <- "nemeton_layers"

  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = direct_bdforet,
    layers = mock_layers
  )

  # direct bdforet is used (covers the unit), so recent forest score
  expect_true(result$N2[1] > 30 & result$N2[1] <= 60)
})

test_that("indicateur_n2_continuite (N2) with CRS transform", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # bdforet in different CRS (WGS84)
  bdforet_2154 <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )
  bdforet_4326 <- sf::st_transform(bdforet_2154, 4326)

  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet_4326
  )

  expect_s3_class(result, "sf")
  expect_true("N2" %in% names(result))
  # After CRS transform, the bdforet should still cover the unit
  expect_true(result$N2[1] > 30 & result$N2[1] <= 60)
})

test_that("indicateur_n2_continuite (N2) non-sf bdforet treated as NULL", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Non-sf bdforet does not satisfy inherits(bdforet, "sf")
  # and is also not NULL -> but the check on line 123 is: !is.null AND inherits(sf) AND nrow > 0
  # so a non-sf object fails that check, bdforet becomes NULL
  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = data.frame(x = 1)
  )

  # bdforet effectively NULL after check, foret_ancienne is NULL
  # But we don't hit the early return on line 116 because bdforet was not NULL initially
  # Inside the loop, bdforet is NULL -> taux_boisement = 0
  # foret_ancienne is NULL -> taux_ancienne = 0 -> score = 15
  expect_equal(result$N2[1], 15)
})

test_that("indicateur_n2_continuite (N2) multiple units different coverages", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  # 3 units: unit1 fully covered by ancient forest, unit2 half covered by bdforet, unit3 no forest
  test_units <- sf::st_sf(
    id = 1:3,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200, 0, 300, 0, 300, 100, 200, 100, 200, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(500, 0, 600, 0, 600, 100, 500, 100, 500, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # bdforet covers unit 1 and half of unit 2
  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 250, -10, 250, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Ancient forest covers only unit 1
  foret_ancienne <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet,
    foret_ancienne = foret_ancienne
  )

  expect_equal(nrow(result), 3)
  # Unit 1: ancient forest covers it -> score >= 60
  expect_true(result$N2[1] >= 60)
  # Unit 2: no ancient forest, but bdforet partially covers -> 30 < score <= 60
  expect_true(result$N2[2] > 30 & result$N2[2] <= 60)
  # Unit 3: no forest at all -> score = 15
  expect_equal(result$N2[3], 15)
})

# ==============================================================================
# N3: Composite Naturalness
# ==============================================================================

test_that("indicateur_n3_naturalite (N3) combines N1 and N2", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    N1 = c(80, 20),
    N2 = c(90, 30),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200, 0, 300, 0, 300, 100, 200, 100, 200, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(units = test_units)

  expect_s3_class(result, "sf")
  expect_true("N3" %in% names(result))
  expect_type(result$N3, "double")

  # N3 = 0.35*N1 + 0.35*N2 + 0.15*50 + 0.15*50 (no L1/B3 -> fallback 50)
  expected_1 <- 0.35 * 80 + 0.35 * 90 + 0.15 * 50 + 0.15 * 50
  expected_2 <- 0.35 * 20 + 0.35 * 30 + 0.15 * 50 + 0.15 * 50
  expect_equal(result$N3[1], expected_1)
  expect_equal(result$N3[2], expected_2)

  # Higher N1+N2 -> higher N3
  expect_true(result$N3[1] > result$N3[2])
})

test_that("indicateur_n3_naturalite (N3) uses L1 and B3 when available", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N1 = 60,
    N2 = 70,
    L1 = 40,  # fragmentation
    B3 = 80,  # connectivity
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(units = test_units)

  # N3 = 0.35*60 + 0.35*70 + 0.15*(100-40) + 0.15*80
  expected <- 0.35 * 60 + 0.35 * 70 + 0.15 * 60 + 0.15 * 80
  expect_equal(result$N3[1], expected)
})

test_that("indicateur_n3_naturalite (N3) without N1/N2 uses fallback 50", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(units = test_units)

  # All fallback to 50 -> N3 = 50
  expect_equal(result$N3[1], 50)
})

test_that("indicateur_n3_naturalite validates input", {
  skip_if_not_installed("terra")
  expect_error(
    indicateur_n3_naturalite(data.frame(x = 1:3)),
    "must be an sf object"
  )
})

test_that("indicateur_n3_naturalite uses custom column name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N1 = 60,
    N2 = 70,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(test_units, column_name = "nat_idx")

  expect_true("nat_idx" %in% names(result))
  expect_false("N3" %in% names(result))
})

test_that("indicateur_n3_naturalite (N3) with only N1 (no N2)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N1 = 80,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(units = test_units)

  # N1 = 80, N2 fallback 50, L1 fallback -> anti_frag=50, B3 fallback -> connectivite=50
  expected <- 0.35 * 80 + 0.35 * 50 + 0.15 * 50 + 0.15 * 50
  expect_equal(result$N3[1], expected)
})

test_that("indicateur_n3_naturalite (N3) with only N2 (no N1)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N2 = 90,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(units = test_units)

  # N1 fallback 50, N2 = 90
  expected <- 0.35 * 50 + 0.35 * 90 + 0.15 * 50 + 0.15 * 50
  expect_equal(result$N3[1], expected)
})

test_that("indicateur_n3_naturalite (N3) with only L1 (no B3)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N1 = 60,
    N2 = 70,
    L1 = 30,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(units = test_units)

  # anti_frag = 100 - 30 = 70, connectivite fallback = 50
  expected <- 0.35 * 60 + 0.35 * 70 + 0.15 * 70 + 0.15 * 50
  expect_equal(result$N3[1], expected)
})

test_that("indicateur_n3_naturalite (N3) with only B3 (no L1)", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N1 = 60,
    N2 = 70,
    B3 = 90,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(units = test_units)

  # anti_frag fallback = 50, connectivite = 90
  expected <- 0.35 * 60 + 0.35 * 70 + 0.15 * 50 + 0.15 * 90
  expect_equal(result$N3[1], expected)
})

test_that("indicateur_n3_naturalite (N3) all columns present", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    N1 = c(100, 0, 50),
    N2 = c(100, 0, 50),
    L1 = c(0, 100, 50),   # L1=0 -> anti_frag=100; L1=100 -> anti_frag=0
    B3 = c(100, 0, 50),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200, 0, 300, 0, 300, 100, 200, 100, 200, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(400, 0, 500, 0, 500, 100, 400, 100, 400, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(units = test_units)

  # Unit 1: all max -> 0.35*100 + 0.35*100 + 0.15*100 + 0.15*100 = 100
  expect_equal(result$N3[1], 100)
  # Unit 2: all min -> 0.35*0 + 0.35*0 + 0.15*0 + 0.15*0 = 0
  expect_equal(result$N3[2], 0)
  # Unit 3: all 50 -> 0.35*50 + 0.35*50 + 0.15*50 + 0.15*50 = 50
  expect_equal(result$N3[3], 50)
})

test_that("indicateur_n3_naturalite (N3) handles NA in N1/N2 columns", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    N1 = c(NA_real_, 60),
    N2 = c(70, NA_real_),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200, 0, 300, 0, 300, 100, 200, 100, 200, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- indicateur_n3_naturalite(units = test_units)

  # NA propagates through arithmetic: 0.35*NA + ... = NA
  expect_true(is.na(result$N3[1]))
  expect_true(is.na(result$N3[2]))
})

# ==============================================================================
# Integration
# ==============================================================================

test_that("Naturalness indicators integrate with family system", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2000, 0, 3000, 0, 3000, 1000, 2000, 1000, 2000, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # N1 and N2 without external data -> defaults, N3 combines them
  result <- test_units |>
    indicateur_n1_distance() |>
    indicateur_n2_continuite() |>
    indicateur_n3_naturalite()

  expect_true(all(c("N1", "N2", "N3") %in% names(result)))
  expect_true(all(result$N3 >= 0 & result$N3 <= 100))
})

test_that("Full pipeline with spatial data and L1/B3 produces valid N3", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  roads <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(50, -500, 50, 500), ncol = 2, byrow = TRUE)),
      crs = 2154
    )
  )

  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- test_units |>
    indicateur_n1_distance(roads = roads) |>
    indicateur_n2_continuite(bdforet = bdforet)

  # Manually add L1 and B3 for composite
  result$L1 <- 20
  result$B3 <- 75

  result <- indicateur_n3_naturalite(result)

  expect_true(all(c("N1", "N2", "N3") %in% names(result)))
  expect_true(result$N3[1] >= 0 & result$N3[1] <= 100)

  # Verify exact computation
  expected_n3 <- 0.35 * result$N1[1] + 0.35 * result$N2[1] + 0.15 * (100 - 20) + 0.15 * 75
  expect_equal(result$N3[1], expected_n3)
})

# ==============================================================================
# (migrated from test-cov60-batch4.R)
# ==============================================================================

test_that("indicateur_n1_distance returns N1", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  roads <- create_test_vector(type = "lines")

  result <- indicateur_n1_distance(units, roads = roads)
  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
})

test_that("indicateur_n1_distance without roads returns default", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)

  result <- indicateur_n1_distance(units)
  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
})

test_that("indicateur_n1_distance with custom column_name", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)

  result <- indicateur_n1_distance(units, column_name = "nat_dist")
  expect_true("nat_dist" %in% names(result))
})

test_that("indicateur_n2_continuite returns N2", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)

  result <- indicateur_n2_continuite(units)
  expect_s3_class(result, "sf")
  expect_true("N2" %in% names(result))
})

test_that("indicateur_n2_continuite with bdforet", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)

  bdforet <- sf::st_sf(
    TFV = c("Forêt ancienne", "Forêt récente"),
    geometry = sf::st_geometry(sf::st_buffer(units, 100))
  )
  sf::st_crs(bdforet) <- sf::st_crs(units)

  result <- indicateur_n2_continuite(units, bdforet = bdforet)
  expect_s3_class(result, "sf")
  expect_true("N2" %in% names(result))
})

test_that("indicateur_n3_naturalite returns N3", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 3)
  units$N1 <- c(60, 70, 80)
  units$N2 <- c(50, 60, 70)

  result <- indicateur_n3_naturalite(units)
  expect_s3_class(result, "sf")
  expect_true("N3" %in% names(result))
})

test_that("indicateur_n3_naturalite without N1/N2 returns default", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  units <- create_test_units(n_features = 2)

  result <- indicateur_n3_naturalite(units)
  expect_s3_class(result, "sf")
  expect_true("N3" %in% names(result))
})

# ==============================================================================
# (migrated from test-cov80-batch9.R)
# ==============================================================================

# --- N1: indicateur_n1_distance ---

test_that("N1 with layers that have no roads or buildings keys returns defaults", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  mock_layers <- list(
    vectors = list(),
    rasters = list(),
    metadata = list()
  )
  class(mock_layers) <- "nemeton_layers"

  result <- nemeton::indicateur_n1_distance(
    units = test_units,
    layers = mock_layers
  )

  # roads=NULL -> default 1000, buildings=NULL -> default 500
  # N1 = 0.40*pmin(100,1000/20) + 0.35*pmin(100,500/20) + 0.25*pmin(100,2000/20)
  # = 0.40*50 + 0.35*25 + 0.25*100 = 20 + 8.75 + 25 = 53.75
  expect_equal(result$N1[1], 53.75)
})

test_that("N1 layers argument ignored when not nemeton_layers class", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # A plain list that is NOT nemeton_layers
  fake_layers <- list(
    vectors = list(roads = sf::st_sf(
      id = 1,
      geometry = sf::st_sfc(
        sf::st_linestring(matrix(c(500, 0, 500, 1000), ncol = 2, byrow = TRUE)),
        crs = 2154
      )
    ))
  )

  result <- nemeton::indicateur_n1_distance(
    units = test_units,
    layers = fake_layers
  )

  # layers ignored (not nemeton_layers class), roads/buildings NULL -> defaults

  expect_equal(result$N1[1], 53.75)
})

test_that("N1 with lang = 'fr' works correctly", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 2)
  result <- nemeton::indicateur_n1_distance(units = test_units, lang = "fr")
  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  expect_true(all(!is.na(result$N1)))
})

test_that("N1 correctly transforms buildings in different CRS", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        600900, 6601000,
        601100, 6601000,
        601100, 6601200,
        600900, 6601200,
        600900, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  buildings_2154 <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        601000, 6601000,
        601050, 6601000,
        601050, 6601050,
        601000, 6601050,
        601000, 6601000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )
  buildings_4326 <- sf::st_transform(buildings_2154, 4326)

  result <- nemeton::indicateur_n1_distance(
    units = test_units,
    buildings = buildings_4326
  )

  expect_s3_class(result, "sf")
  expect_true("N1" %in% names(result))
  # buildings transformed -> real distance computed, not default 500
  expect_true(result$N1[1] >= 0 & result$N1[1] <= 100)
})

# --- N2: indicateur_n2_continuite ---

test_that("N2 intersection error handling: tryCatch returns NULL on error", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Create a valid bdforet that covers the unit
  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Mock st_intersection to error for the bdforet intersection path
  # The tryCatch in the code catches errors and returns NULL -> taux_boisement=0
  local_mocked_bindings(
    st_intersection = function(...) stop("Intentional error"),
    .package = "sf"
  )

  result <- nemeton::indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet
  )

  # When intersection fails, taux_boisement=0, taux_ancienne=0 -> score=15
  expect_equal(result$N2[1], 15)
})

test_that("N2 with foret_ancienne in different CRS", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  foret_ancienne_2154 <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )
  foret_ancienne_4326 <- sf::st_transform(foret_ancienne_2154, 4326)

  result <- nemeton::indicateur_n2_continuite(
    units = test_units,
    foret_ancienne = foret_ancienne_4326
  )

  # After CRS transform, foret_ancienne should still overlap
  # taux_ancienne > 0 -> score = 60 + 40*taux
  expect_true(result$N2[1] >= 60 & result$N2[1] <= 100)
})

test_that("N2 with non-overlapping bdforet returns score 15", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # bdforet far away from unit
  bdforet_far <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        50000, 50000, 50100, 50000, 50100, 50100, 50000, 50100, 50000, 50000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet_far
  )

  # Intersection yields 0 rows -> taux_boisement=0, no ancient -> score=15
  expect_equal(result$N2[1], 15)
})

test_that("N2 with non-overlapping foret_ancienne but overlapping bdforet", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # bdforet covers the unit
  bdforet <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(-10, -10, 110, -10, 110, 110, -10, 110, -10, -10), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # foret_ancienne far away (no overlap)
  foret_ancienne_far <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(
        50000, 50000, 50100, 50000, 50100, 50100, 50000, 50100, 50000, 50000
      ), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet,
    foret_ancienne = foret_ancienne_far
  )

  # taux_boisement > 0, taux_ancienne = 0 -> score = 30 + 30*taux_boisement
  expect_true(result$N2[1] > 30 & result$N2[1] <= 60)
})

test_that("N2 with both bdforet and foret_ancienne having multiple features", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Two bdforet features
  bdforet <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 50, 0, 50, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(50, 0, 100, 0, 100, 100, 50, 100, 50, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  # Two foret_ancienne features (only left half)
  foret_ancienne <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 50, 0, 50, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicateur_n2_continuite(
    units = test_units,
    bdforet = bdforet,
    foret_ancienne = foret_ancienne
  )

  # taux_ancienne ~ 0.5, score = 60 + 40*0.5 = 80
  expect_true(result$N2[1] >= 60 & result$N2[1] <= 100)
  expect_equal(result$N2[1], 80, tolerance = 2)
})

test_that("N2 lang = 'fr' works correctly", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- create_test_units(n_features = 1)
  result <- nemeton::indicateur_n2_continuite(units = test_units, lang = "fr")
  # No data -> default 50
  expect_equal(result$N2[1], 50)
})

# --- N3: indicateur_n3_naturalite ---

test_that("N3 with pre-computed N1, N2, L1, and B3 columns", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1:3,
    N1 = c(70, 30, 100),
    N2 = c(80, 40, 0),
    L1 = c(10, 80, 50),
    B3 = c(60, 20, 100),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200, 0, 300, 0, 300, 100, 200, 100, 200, 0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(400, 0, 500, 0, 500, 100, 400, 100, 400, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicateur_n3_naturalite(units = test_units)

  # Unit 1: 0.35*70 + 0.35*80 + 0.15*(100-10) + 0.15*60 = 24.5+28+13.5+9 = 75
  expect_equal(result$N3[1], 0.35 * 70 + 0.35 * 80 + 0.15 * 90 + 0.15 * 60)
  # Unit 2: 0.35*30 + 0.35*40 + 0.15*(100-80) + 0.15*20 = 10.5+14+3+3 = 30.5
  expect_equal(result$N3[2], 0.35 * 30 + 0.35 * 40 + 0.15 * 20 + 0.15 * 20)
  # Unit 3: 0.35*100 + 0.35*0 + 0.15*(100-50) + 0.15*100 = 35+0+7.5+15 = 57.5
  expect_equal(result$N3[3], 0.35 * 100 + 0.35 * 0 + 0.15 * 50 + 0.15 * 100)
})

test_that("N3 lang = 'fr' works correctly", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    N1 = 60,
    N2 = 70,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicateur_n3_naturalite(units = test_units, lang = "fr")
  expect_s3_class(result, "sf")
  expect_true("N3" %in% names(result))
  expected <- 0.35 * 60 + 0.35 * 70 + 0.15 * 50 + 0.15 * 50
  expect_equal(result$N3[1], expected)
})

test_that("N3 preserves original columns", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  test_units <- sf::st_sf(
    id = 1,
    name = "forest_a",
    N1 = 80,
    N2 = 90,
    area_ha = 15.5,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 100, 0, 100, 100, 0, 100, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton::indicateur_n3_naturalite(units = test_units)

  expect_true("id" %in% names(result))
  expect_true("name" %in% names(result))
  expect_true("area_ha" %in% names(result))
  expect_equal(result$name, "forest_a")
  expect_equal(result$area_ha, 15.5)
  expect_true("N3" %in% names(result))
})
