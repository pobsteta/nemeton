# test-cov60-batch2.R
# Coverage boost batch 2: targeting 65% coverage for 6 source files
#
# Targets:
#   - R/indicators-temporal.R  (41.1% -> 65%)
#   - R/data-hunting.R         (45.0% -> 65%)
#   - R/service_cadastre.R     (46.4% -> 65%)
#   - R/service_communes.R     (49.9% -> 65%)
#   - R/indicators-social.R    (47.7% -> 65%)
#   - R/nemeton-class.R        (48.2% -> 65%)

# ==============================================================================
# indicators-temporal.R
# ==============================================================================

test_that("indicateur_t1_anciennete handles CODE_TFV field", {
  units <- create_test_units(n_features = 2)
  bdforet <- sf::st_sf(
    CODE_TFV = c(
      "For\u00eat ferm\u00e9e de feuillus purs",
      "Peupleraie"
    ),
    geometry = sf::st_geometry(sf::st_buffer(units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(units)
  result <- indicateur_t1_anciennete(units, bdforet = bdforet)
  expect_type(result, "double")
  expect_length(result, 2)
})

test_that("indicateur_t1_anciennete handles CRS mismatch with bdforet", {
  units <- create_test_units(n_features = 2)
  bdforet <- sf::st_sf(
    TFV = c(
      "For\u00eat ouverte de conif\u00e8res",
      "Peupleraie"
    ),
    geometry = sf::st_transform(
      sf::st_geometry(sf::st_buffer(units, 200)),
      4326
    )
  )
  sf::st_crs(bdforet) <- sf::st_crs(4326)
  result <- indicateur_t1_anciennete(units, bdforet = bdforet)
  expect_type(result, "double")
  expect_length(result, 2)
})

test_that("indicateur_t1_anciennete falls through when bdforet has no TFV field", {
  units <- create_test_units(n_features = 2)
  units$age <- c(30, 60)
  bdforet <- sf::st_sf(
    other_field = c("x", "y"),
    geometry = sf::st_geometry(sf::st_buffer(units, 200))
  )
  sf::st_crs(bdforet) <- sf::st_crs(units)
  result <- indicateur_t1_anciennete(units, bdforet = bdforet, age_field = "age")
  expect_equal(result, c(30, 60))
})

test_that("indicateur_t1_anciennete handles empty bdforet", {
  units <- create_test_units(n_features = 2)
  units$age <- c(30, 60)
  bdforet <- sf::st_sf(
    TFV = character(0),
    geometry = sf::st_sfc(crs = 2154)
  )
  result <- indicateur_t1_anciennete(units, bdforet = bdforet, age_field = "age")
  expect_equal(result, c(30, 60))
})

test_that("indicateur_t1_anciennete defaults to 50 when no data", {
  units <- create_test_units(n_features = 3)
  result <- indicateur_t1_anciennete(
    units,
    age_field = NULL,
    establishment_year_field = NULL
  )
  expect_equal(result, rep(50.0, 3))
})

test_that("indicateur_t1_anciennete establishment year uses system year when current_year is NULL", {
  units <- create_test_units(n_features = 2)
  units$planted <- c(2000, 2010)
  result <- indicateur_t1_anciennete(
    units,
    age_field = NULL,
    establishment_year_field = "planted"
  )
  current_year <- as.integer(format(Sys.Date(), "%Y"))
  expect_equal(result, c(current_year - 2000, current_year - 2010))
})

test_that("indicateur_t1_anciennete uses NDVI proxy when available", {
  units <- create_test_units(n_features = 2)
  ndvi_raster <- create_test_raster(values = "constant")
  terra::values(ndvi_raster) <- 0.5

  layers <- structure(list(
    rasters = list(ndvi = ndvi_raster),
    vectors = list()
  ), class = "nemeton_layers")

  local_mocked_bindings(
    resolve_raster_layer = function(layers, name) {
      if (name == "ndvi") return(layers$rasters$ndvi)
      return(NULL)
    },
    .package = "nemeton"
  )

  result <- indicateur_t1_anciennete(units, layers = layers, age_field = NULL)
  expect_type(result, "double")
  expect_length(result, 2)
  expect_true(all(result > 0))
})

test_that(".estimate_age_tfv maps TFV codes to ages correctly", {
  tfv <- c(
    "For\u00eat ferm\u00e9e de feuillus purs",
    "Futaie de feuillus",
    "For\u00eat ferm\u00e9e de conif\u00e8res",
    "Futaie de conif\u00e8res",
    "For\u00eat ouverte mixte",
    "Taillis simple",
    "Peupleraie",
    "Jeune peuplement",
    "Lande bois\u00e9e",
    "Prairie"
  )
  result <- nemeton:::.estimate_age_tfv(tfv)
  expect_equal(result, c(100, 100, 80, 80, 45, 45, 20, 15, 15, 50))
})

test_that("indicateur_t2_changement uses N2 column when present", {
  units <- create_test_units(n_features = 3)
  units$N2 <- c(80, 50, 20)
  result <- indicateur_t2_changement(units)
  expect_equal(result, c(80, 50, 20))
})

test_that("indicateur_t2_changement uses N2_anciennete column", {
  units <- create_test_units(n_features = 3)
  units$N2_anciennete <- c(90, 60, 30)
  result <- indicateur_t2_changement(units)
  expect_equal(result, c(90, 60, 30))
})

test_that("indicateur_t2_changement caps N2 values to 0-100", {
  units <- create_test_units(n_features = 3)
  units$N2 <- c(150, -10, 50)
  result <- indicateur_t2_changement(units)
  expect_equal(result, c(100, 0, 50))
})

test_that("indicateur_t2_changement replaces NA t1_values with 50", {
  units <- create_test_units(n_features = 3)
  result <- indicateur_t2_changement(units, t1_values = c(80, NA, 120))
  expect_equal(result, c(80, 50, 100))
})

test_that("indicateur_t2_changement uses T1 column from units", {
  units <- create_test_units(n_features = 3)
  units$T1 <- c(75, NA, 150)
  result <- indicateur_t2_changement(units)
  expect_equal(result, c(75, 50, 100))
})

test_that("indicateur_t2_changement defaults to 50 when no data", {
  units <- create_test_units(n_features = 3)
  result <- indicateur_t2_changement(units)
  expect_equal(result, rep(50.0, 3))
})


# ==============================================================================
# data-hunting.R
# ==============================================================================

test_that("standardize_hunting_columns handles code_dept pattern", {
  mock_data <- data.frame(
    code_dept = c("01", "02"),
    nom_departement = c("Ain", "Aisne"),
    campagne = c("2022-2023", "2022-2023"),
    realisations = c(1000, 800),
    stringsAsFactors = FALSE
  )
  result <- nemeton:::standardize_hunting_columns(mock_data, "cerf")
  expect_true("espece" %in% names(result))
  expect_equal(result$espece[1], "cerf")
  expect_true("code_dept" %in% names(result))
})

test_that("standardize_hunting_columns handles minimal columns", {
  mock_data <- data.frame(
    x = c(1, 2), y = c(3, 4),
    stringsAsFactors = FALSE
  )
  result <- nemeton:::standardize_hunting_columns(mock_data, "sanglier")
  expect_true("espece" %in% names(result))
  # With <3 standard columns, returns original data with espece added
})

test_that("compute_game_pressure_index works with pre-built data", {
  mock_hunting <- data.frame(
    code_dept = rep(c("01", "02", "03"), each = 2),
    nom_dept = rep(c("Ain", "Aisne", "Allier"), each = 2),
    espece = rep(c("chevreuil", "cerf"), 3),
    saison = rep("2022-2023", 6),
    tableau = c(1000, 500, 1500, 700, 800, 300),
    stringsAsFactors = FALSE
  )

  result <- compute_game_pressure_index(
    hunting_data = mock_hunting,
    season = "2022-2023",
    normalize_by = "rank"
  )

  expect_s3_class(result, "data.frame")
  expect_true("pressure_index" %in% names(result))
  expect_true(all(result$pressure_index >= 0 & result$pressure_index <= 100))
})

test_that("compute_game_pressure_index with minmax normalization", {
  mock_hunting <- data.frame(
    code_dept = rep(c("01", "02", "03"), each = 1),
    nom_dept = rep(c("Ain", "Aisne", "Allier"), each = 1),
    espece = rep("chevreuil", 3),
    saison = rep("2022-2023", 3),
    tableau = c(100, 500, 1000),
    stringsAsFactors = FALSE
  )

  result <- compute_game_pressure_index(
    hunting_data = mock_hunting,
    season = "2022-2023",
    normalize_by = "minmax"
  )

  expect_true("pressure_index" %in% names(result))
  expect_true(all(result$pressure_index >= 0 & result$pressure_index <= 100))
})

test_that("compute_game_pressure_index with latest season", {
  mock_hunting <- data.frame(
    code_dept = c("01", "01", "02", "02"),
    nom_dept = c("Ain", "Ain", "Aisne", "Aisne"),
    espece = rep("chevreuil", 4),
    saison = c("2021-2022", "2022-2023", "2021-2022", "2022-2023"),
    tableau = c(800, 1000, 600, 700),
    stringsAsFactors = FALSE
  )

  result <- compute_game_pressure_index(
    hunting_data = mock_hunting,
    season = "latest"
  )

  expect_true("pressure_index" %in% names(result))
  expect_equal(nrow(result), 2) # 2 departments
})

test_that("compute_game_pressure_index errors on empty season", {
  mock_hunting <- data.frame(
    code_dept = "01",
    nom_dept = "Ain",
    espece = "chevreuil",
    saison = "2020-2021",
    tableau = 100,
    stringsAsFactors = FALSE
  )

  expect_error(
    compute_game_pressure_index(mock_hunting, season = "2025-2026"),
    "No data available"
  )
})

test_that("compute_game_pressure_index handles missing nom_dept", {
  mock_hunting <- data.frame(
    code_dept = c("01", "02"),
    espece = rep("chevreuil", 2),
    saison = rep("2022-2023", 2),
    tableau = c(100, 200),
    stringsAsFactors = FALSE
  )

  result <- compute_game_pressure_index(mock_hunting, season = "2022-2023")
  expect_true("nom_dept" %in% names(result))
  expect_true(all(is.na(result$nom_dept)))
})

test_that("compute_game_pressure_index area normalization falls back to rank", {
  mock_hunting <- data.frame(
    code_dept = c("01", "02"),
    nom_dept = c("Ain", "Aisne"),
    espece = rep("chevreuil", 2),
    saison = rep("2022-2023", 2),
    tableau = c(100, 200),
    stringsAsFactors = FALSE
  )

  # normalize_by = "area" without dept_forest_area should fall back to rank
  result <- compute_game_pressure_index(
    mock_hunting, season = "2022-2023", normalize_by = "area"
  )
  expect_true("pressure_index" %in% names(result))
})

test_that("download_hunting_data reads from cached CSV when present", {
  withr::with_tempdir({
    # Pre-create a cached CSV to exercise the read-from-cache path
    csv_data <- data.frame(
      Departement = c("01", "02"),
      Nom_Departement = c("Ain", "Aisne"),
      Saison = c("2022-2023", "2022-2023"),
      Tableau = c(1500, 2000),
      stringsAsFactors = FALSE
    )
    write.csv(csv_data, "chevreuil_tableaux_chasse.csv", row.names = FALSE)

    result <- download_hunting_data(
      species = "chevreuil",
      cache_dir = getwd(),
      force_download = FALSE
    )
    expect_s3_class(result, "data.frame")
    expect_true(nrow(result) > 0)
  })
})

test_that("HUNTING_DATA_URLS has all 8 species", {
  urls <- nemeton:::HUNTING_DATA_URLS
  expect_type(urls, "list")
  expect_true(length(urls) >= 8)
  expect_true("chevreuil" %in% names(urls))
  expect_true("cerf" %in% names(urls))
  expect_true("sanglier" %in% names(urls))
  expect_true("chamois" %in% names(urls))
  expect_true("isard" %in% names(urls))
  expect_true("mouflon" %in% names(urls))
  expect_true("daim" %in% names(urls))
  expect_true("cerf_sika" %in% names(urls))
})

test_that("download_hunting_data rejects invalid species", {
  expect_error(
    download_hunting_data(species = "licorne"),
    "No valid species"
  )
})


# ==============================================================================
# service_cadastre.R
# ==============================================================================

test_that("get_cadastral_parcels rejects invalid INSEE codes", {
  expect_error(
    nemeton:::get_cadastral_parcels("ABC")
  )
  expect_error(
    nemeton:::get_cadastral_parcels("123456")
  )
  expect_error(
    nemeton:::get_cadastral_parcels("12")
  )
})

test_that("standardize_parcels normalizes column names from idu format", {
  mock_sf <- sf::st_sf(
    idu = c("A001", "A002"),
    section = c("A", "B"),
    numero = c("0001", "0002"),
    contenance = c(5000, 10000),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1,0,2,0,2,1,1,1,1,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )

  result <- nemeton:::standardize_parcels(mock_sf, "12345")
  expect_s3_class(result, "sf")
  expect_true("id" %in% names(result))
  expect_true("section" %in% names(result))
  expect_true("numero" %in% names(result))
  expect_true("contenance" %in% names(result))
  expect_true("code_insee" %in% names(result))
  expect_equal(result$code_insee[1], "12345")
})

test_that("standardize_parcels calculates area when contenance missing", {
  mock_sf <- sf::st_sf(
    id_parcelle = c("P1", "P2"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,100,0,100,100,0,100,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(200,0,300,0,300,100,200,100,200,0), ncol = 2, byrow = TRUE))),
      crs = 2154
    )
  )

  result <- nemeton:::standardize_parcels(mock_sf, "12345")
  expect_true("contenance" %in% names(result))
  expect_true(all(result$contenance > 0))
})

test_that("standardize_parcels generates IDs when no id column exists", {
  mock_sf <- sf::st_sf(
    some_field = c("x", "y"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1,0,2,0,2,1,1,1,1,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )

  result <- nemeton:::standardize_parcels(mock_sf, "99999")
  expect_true("id" %in% names(result))
  expect_true(grepl("99999", result$id[1]))
})

test_that("get_cadastral_parcels tries API then falls back", {
  local_mocked_bindings(
    fetch_api_cadastre = function(...) NULL,
    fetch_happign_cadastre = function(...) {
      sf::st_sf(
        id = "MOCK001",
        section = "A",
        numero = "0001",
        contenance = 5000,
        geometry = sf::st_sfc(
          sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
          crs = 4326
        )
      )
    },
    standardize_parcels = function(parcels, ...) parcels,
    .package = "nemeton"
  )

  result <- nemeton:::get_cadastral_parcels("12345")
  expect_s3_class(result, "sf")
})

test_that("calculate_parcel_stats computes correct statistics", {
  mock_sf <- sf::st_sf(
    id = c("P1", "P2", "P3"),
    contenance = c(1000, 2000, 3000),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1,0,2,0,2,1,1,1,1,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2,0,3,0,3,1,2,1,2,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )

  stats <- nemeton:::calculate_parcel_stats(mock_sf)
  expect_type(stats, "list")
  expect_equal(stats$count, 3)
  expect_equal(stats$total_area_ha, sum(c(1000, 2000, 3000) / 10000))
  expect_equal(stats$mean_area_ha, mean(c(1000, 2000, 3000) / 10000))
})

test_that("calculate_parcel_stats handles empty parcels", {
  stats <- nemeton:::calculate_parcel_stats(NULL)
  expect_equal(stats$count, 0)
  expect_equal(stats$total_area_ha, 0)
})

test_that("format_parcel_info returns formatted string in French", {
  mock_sf <- sf::st_sf(
    id = "P001",
    section = "A",
    numero = "0001",
    contenance = 5000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )
  result <- nemeton:::format_parcel_info(mock_sf[1, ], language = "fr")
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
  expect_true(grepl("P001", result))
  expect_true(grepl("Parcelle", result))
})

test_that("format_parcel_info works in English", {
  mock_sf <- sf::st_sf(
    id = "P001",
    section = "B",
    numero = "0002",
    contenance = 10000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )
  result <- nemeton:::format_parcel_info(mock_sf[1, ], language = "en")
  expect_type(result, "character")
  expect_true(grepl("Parcel", result))
})

test_that("create_parcel_popup returns HTML string", {
  mock_sf <- sf::st_sf(
    id = "P001",
    section = "A",
    numero = "0001",
    contenance = 5000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )
  result <- nemeton:::create_parcel_popup(mock_sf[1, ])
  expect_type(result, "character")
  expect_true(grepl("<strong>", result))
  expect_true(grepl("P001", result))
})

test_that("create_parcel_label returns HTML string", {
  mock_sf <- sf::st_sf(
    id = "P001",
    section = "A",
    numero = "0001",
    contenance = 5000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )
  result <- nemeton:::create_parcel_label(mock_sf[1, ])
  expect_type(result, "character")
  expect_true(grepl("<b>", result))
})

test_that("filter_selected_parcels filters correctly", {
  mock_sf <- sf::st_sf(
    id = c("P1", "P2", "P3"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1,0,2,0,2,1,1,1,1,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(2,0,3,0,3,1,2,1,2,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )

  result <- nemeton:::filter_selected_parcels(mock_sf, c("P1", "P3"))
  expect_equal(nrow(result), 2)
  expect_true(all(c("P1", "P3") %in% result$id))
})

test_that("filter_selected_parcels returns empty for no selection", {
  mock_sf <- sf::st_sf(
    id = c("P1", "P2"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1,0,2,0,2,1,1,1,1,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )

  result <- nemeton:::filter_selected_parcels(mock_sf, character(0))
  expect_equal(nrow(result), 0)
})

test_that("get_parcel_by_id returns single parcel", {
  mock_sf <- sf::st_sf(
    id = c("P1", "P2"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1,0,2,0,2,1,1,1,1,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )

  result <- nemeton:::get_parcel_by_id("P1", mock_sf)
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "P1")
})

test_that("get_parcel_by_id returns NULL when not found", {
  mock_sf <- sf::st_sf(
    id = c("P1", "P2"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0,0,1,0,1,1,0,1,0,0), ncol = 2, byrow = TRUE))),
      sf::st_polygon(list(matrix(c(1,0,2,0,2,1,1,1,1,0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )

  result <- nemeton:::get_parcel_by_id("P999", mock_sf)
  expect_null(result)
})


# ==============================================================================
# service_communes.R
# ==============================================================================

test_that("get_departments returns named character vector of departments", {
  depts <- nemeton:::get_departments()
  expect_type(depts, "character")
  expect_true(length(depts) >= 100)
  # Check specific departments exist as values
  expect_true("75" %in% depts)
  expect_true("2A" %in% depts)
  expect_true("2B" %in% depts)
  expect_true("971" %in% depts)
  # Names should contain department names
  expect_true(any(grepl("Paris", names(depts))))
})

test_that("validate_insee_code validates correctly", {
  expect_true(nemeton:::validate_insee_code("75056"))
  expect_true(nemeton:::validate_insee_code("2A004"))
  expect_true(nemeton:::validate_insee_code("2B033"))
  expect_false(nemeton:::validate_insee_code("123"))
  expect_false(nemeton:::validate_insee_code("ABCDE"))
  expect_false(nemeton:::validate_insee_code(NULL))
  expect_false(nemeton:::validate_insee_code(""))
  expect_false(nemeton:::validate_insee_code(NA))
  expect_false(nemeton:::validate_insee_code(12345))
})

test_that("search_communes returns empty for short query", {
  result <- nemeton:::search_communes("ab")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true("code_insee" %in% names(result))
  expect_true("nom" %in% names(result))
})

test_that("search_communes returns empty for single character", {
  result <- nemeton:::search_communes("a")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("search_by_postal_code returns empty for invalid postal code", {
  result <- nemeton:::search_by_postal_code("ABC")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)

  result2 <- nemeton:::search_by_postal_code("1234")
  expect_s3_class(result2, "data.frame")
  expect_equal(nrow(result2), 0)
})

test_that("format_communes_for_selectize creates named vector", {
  communes_df <- data.frame(
    code_insee = c("75056", "13055"),
    nom = c("Paris", "Marseille"),
    code_postal = c("75001", "13001"),
    label = c("Paris (75001)", "Marseille (13001)"),
    stringsAsFactors = FALSE
  )

  result <- nemeton:::format_communes_for_selectize(communes_df)
  expect_type(result, "character")
  expect_equal(length(result), 2)
  expect_true(!is.null(names(result)))
  # Values should be INSEE codes
  expect_true("75056" %in% result)
  expect_true("13055" %in% result)
  # Names should be labels
  expect_true(any(grepl("Paris", names(result))))
})

test_that("format_communes_for_selectize handles empty input", {
  result <- nemeton:::format_communes_for_selectize(NULL)
  expect_equal(length(result), 0)

  result2 <- nemeton:::format_communes_for_selectize(
    data.frame(
      code_insee = character(0),
      nom = character(0),
      label = character(0)
    )
  )
  expect_equal(length(result2), 0)
})

test_that("get_communes_in_department returns empty for NULL department", {
  result <- nemeton:::get_communes_in_department(NULL)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("get_communes_in_department returns empty for empty string", {
  result <- nemeton:::get_communes_in_department("")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("get_commune_geometry returns NULL for invalid INSEE code", {
  result <- suppressWarnings(nemeton:::get_commune_geometry("INVALID"))
  expect_null(result)
})

test_that("get_commune_geometry returns NULL for short code", {
  result <- suppressWarnings(nemeton:::get_commune_geometry("12"))
  expect_null(result)
})


# ==============================================================================
# indicators-social.R
# ==============================================================================

test_that("indicateur_s1_routes returns NA column without roads", {
  units <- create_test_units(n_features = 2)
  result <- indicateur_s1_routes(units)
  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  expect_true(all(is.na(result$S1)))
})

test_that("indicateur_s2_bati returns NA column without buildings", {
  units <- create_test_units(n_features = 2)
  result <- indicateur_s2_bati(units)
  expect_s3_class(result, "sf")
  expect_true("S2" %in% names(result))
  expect_true(all(is.na(result$S2)))
})

test_that("indicateur_s3_population computes buffer-based proximity", {
  units <- create_test_units(n_features = 3)
  result <- indicateur_s3_population(units)

  expect_s3_class(result, "sf")
  expect_true("S3" %in% names(result))
  expect_true("S3_5km" %in% names(result))
  expect_true("S3_10km" %in% names(result))
  expect_true("S3_20km" %in% names(result))
  expect_true(all(result$S3 > 0))
  # Larger buffers should have larger population estimates
  expect_true(all(result$S3_20km >= result$S3_10km))
  expect_true(all(result$S3_10km >= result$S3_5km))
})

test_that("indicateur_s3_population respects custom buffer radii", {
  units <- create_test_units(n_features = 2)
  result <- indicateur_s3_population(
    units,
    buffer_radii = c(1000, 2000, 5000)
  )
  expect_s3_class(result, "sf")
  expect_true("S3" %in% names(result))
  expect_true(all(result$S3 > 0))
})

test_that("indicateur_s1_routes resolves roads from layers", {
  units <- create_test_units(n_features = 2)
  dem <- create_test_raster(values = "constant")
  roads <- create_test_vector(type = "lines")

  layers <- structure(list(
    rasters = list(dem = dem),
    vectors = list(roads = roads)
  ), class = "nemeton_layers")

  local_mocked_bindings(
    resolve_vector_layer = function(layers, name) {
      if (name == "roads") return(layers$vectors$roads)
      return(NULL)
    },
    resolve_raster_layer = function(layers, name) {
      if (name %in% c("dem", "lidar_mnt")) return(layers$rasters$dem)
      return(NULL)
    },
    .package = "nemeton"
  )

  result <- indicateur_s1_routes(units, layers = layers)
  expect_s3_class(result, "sf")
  expect_true("S1" %in% names(result))
  # With roads and DEM available, values should not all be NA
  expect_true(!all(is.na(result$S1)))
})

test_that("indicateur_s1_routes respects custom column_name", {
  units <- create_test_units(n_features = 2)
  result <- indicateur_s1_routes(units, column_name = "road_dist")
  expect_true("road_dist" %in% names(result))
  expect_false("S1" %in% names(result))
})

test_that("indicateur_s2_bati respects custom column_name", {
  units <- create_test_units(n_features = 2)
  result <- indicateur_s2_bati(units, column_name = "bldg_dist")
  expect_true("bldg_dist" %in% names(result))
  expect_false("S2" %in% names(result))
})

test_that("indicateur_s1_routes errors on non-sf input", {
  expect_error(
    indicateur_s1_routes(data.frame(x = 1:3)),
    "sf"
  )
})

test_that("indicateur_s2_bati errors on non-sf input", {
  expect_error(
    indicateur_s2_bati(data.frame(x = 1:3)),
    "sf"
  )
})

test_that("indicateur_s3_population errors on non-sf input", {
  expect_error(
    indicateur_s3_population(data.frame(x = 1:3)),
    "sf"
  )
})

test_that("indicateur_s3_population matches method argument", {
  units <- create_test_units(n_features = 2)
  # proxy is default, should work
  result_proxy <- indicateur_s3_population(units, method = "proxy")
  expect_s3_class(result_proxy, "sf")

  # invalid method should error
  expect_error(
    indicateur_s3_population(units, method = "invalid_method")
  )
})


# ==============================================================================
# nemeton-class.R
# ==============================================================================

test_that("nemeton_layers works with vectors only", {
  withr::with_tempdir({
    sf::st_write(create_test_vector(), "test.gpkg", quiet = TRUE)
    layers <- nemeton_layers(vectors = list(roads = "test.gpkg"))
    expect_s3_class(layers, "nemeton_layers")
    expect_equal(layers$metadata$n_vectors, 1)
    expect_equal(layers$metadata$n_rasters, 0)
    expect_true("roads" %in% names(layers$vectors))
  })
})

test_that("nemeton_layers skips file validation when validate=FALSE", {
  layers <- nemeton_layers(
    rasters = list(fake = "/nonexistent/file.tif"),
    validate = FALSE
  )
  expect_s3_class(layers, "nemeton_layers")
  expect_equal(layers$metadata$n_rasters, 1)
  expect_false(layers$metadata$validated)
})

test_that("nemeton_layers errors on unnamed rasters list", {
  expect_error(
    nemeton_layers(rasters = list("/path/file.tif")),
    "named list"
  )
})

test_that("nemeton_layers errors on unnamed vectors list", {
  expect_error(
    nemeton_layers(vectors = list("/path/file.gpkg")),
    "named list"
  )
})

test_that("nemeton_layers errors when both rasters and vectors are NULL", {
  expect_error(
    nemeton_layers(),
    "At least one"
  )
})

test_that("print.nemeton_units displays metadata", {
  units <- nemeton_units(
    create_test_units(n_features = 3),
    metadata = list(site_name = "Test Forest", year = 2024)
  )
  output <- capture.output(print(units))
  expect_true(any(grepl("nemeton_units", output)))
  expect_true(any(grepl("Test Forest", output)))
  expect_true(any(grepl("2024", output)))
  expect_true(any(grepl("3", output)))
})

test_that("summary.nemeton_units displays full information", {
  units <- nemeton_units(
    create_test_units(n_features = 5),
    metadata = list(site_name = "Summary Test", year = 2025, source = "Test")
  )
  output <- capture.output(summary(units))
  expect_true(any(grepl("Summary", output)))
  expect_true(any(grepl("5", output)))
  expect_true(any(grepl("Test", output)))
  expect_true(any(grepl("2025", output)))
})

test_that("print.nemeton_layers handles empty rasters", {
  withr::with_tempdir({
    sf::st_write(create_test_vector(), "test.gpkg", quiet = TRUE)
    layers <- nemeton_layers(vectors = list(roads = "test.gpkg"))
    output <- capture.output(print(layers))
    expect_true(any(grepl("nemeton_layers", output)))
    expect_true(any(grepl("none", output)))
    expect_true(any(grepl("roads", output)))
  })
})

test_that("summary.nemeton_layers shows counts", {
  withr::with_tempdir({
    sf::st_write(create_test_vector(), "test.gpkg", quiet = TRUE)
    layers <- nemeton_layers(vectors = list(roads = "test.gpkg"))
    output <- capture.output(summary(layers))
    expect_true(any(grepl("Rasters:", output)))
    expect_true(any(grepl("Vectors:", output)))
    expect_true(any(grepl("0", output)))
    expect_true(any(grepl("1", output)))
  })
})

test_that("nemeton_units with validate=FALSE skips sf validation", {
  test_sf <- create_test_units(n_features = 2)
  units <- nemeton_units(test_sf, validate = FALSE)
  expect_s3_class(units, "nemeton_units")
  expect_equal(nrow(units), 2)
})

test_that("print.nemeton_layers shows loaded status", {
  layers <- nemeton_layers(
    rasters = list(fake = "/tmp/fake.tif"),
    validate = FALSE
  )
  # Mark as loaded
  layers$rasters$fake$loaded <- TRUE
  output <- capture.output(print(layers))
  expect_true(any(grepl("loaded", output)))
  expect_true(any(grepl("fake", output)))
})

test_that("nemeton_units generates IDs automatically", {
  test_sf <- create_test_units(n_features = 4)
  units <- nemeton_units(test_sf)
  expect_true("nemeton_id" %in% names(units))
  expect_equal(length(unique(units$nemeton_id)), 4)
})

test_that("nemeton_units uses provided id_col", {
  test_sf <- create_test_units(n_features = 3)
  units <- nemeton_units(test_sf, id_col = "id")
  expect_true("nemeton_id" %in% names(units))
  expect_equal(units$nemeton_id, test_sf$id)
})

test_that("nemeton_units errors on missing id_col", {
  test_sf <- create_test_units(n_features = 2)
  expect_error(
    nemeton_units(test_sf, id_col = "nonexistent_column"),
    "not found"
  )
})

test_that("nemeton_units errors on duplicate IDs", {
  test_sf <- create_test_units(n_features = 3)
  test_sf$dup_id <- c("A", "A", "B")
  expect_error(
    nemeton_units(test_sf, id_col = "dup_id"),
    "unique"
  )
})

test_that("nemeton_units reads from file path", {
  withr::with_tempdir({
    test_sf <- create_test_units(n_features = 2)
    sf::st_write(test_sf, "test_units.gpkg", quiet = TRUE)
    units <- nemeton_units("test_units.gpkg")
    expect_s3_class(units, "nemeton_units")
    expect_equal(nrow(units), 2)
  })
})

test_that("nemeton_units errors on nonexistent file", {
  expect_error(
    nemeton_units("/nonexistent/path/file.gpkg"),
    "not found"
  )
})

test_that("nemeton_layers with rasters only", {
  withr::with_tempdir({
    r <- create_test_raster(values = "random")
    terra::writeRaster(r, "test.tif", overwrite = TRUE)
    layers <- nemeton_layers(rasters = list(ndvi = "test.tif"))
    expect_s3_class(layers, "nemeton_layers")
    expect_equal(layers$metadata$n_rasters, 1)
    expect_equal(layers$metadata$n_vectors, 0)
    expect_true("ndvi" %in% names(layers$rasters))
  })
})
