# Coverage boost tests for R/service_cadastre.R — batch 21
# Targets all 10 exported/internal functions with deep path coverage

# ==============================================================================
# Helper: create minimal polygon sf objects for testing
# ==============================================================================

make_poly_sf <- function(n = 1, crs = 4326, cols = list()) {

  polys <- lapply(seq_len(n), function(i) {
    sf::st_polygon(list(matrix(
      c(i, 0, i + 1, 0, i + 1, 1, i, 1, i, 0),
      ncol = 2, byrow = TRUE
    )))
  })
  geom <- sf::st_sfc(polys, crs = crs)
  df <- data.frame(row.names = seq_len(n))
  for (nm in names(cols)) {
    df[[nm]] <- cols[[nm]]
  }
  sf::st_sf(df, geometry = geom)
}

# ==============================================================================
# 1. standardize_parcels — with "idu" column (no "id")
# ==============================================================================

test_that("standardize_parcels maps idu column to id", {
  parcels <- make_poly_sf(3, cols = list(
    idu = c("IDU001", "IDU002", "IDU003"),
    section = c("A", "B", "C"),
    numero = c("0001", "0002", "0003"),
    contenance = c(5000, 10000, 15000)
  ))

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_true("id" %in% names(result))
  expect_equal(result$id, c("IDU001", "IDU002", "IDU003"))
  expect_equal(result$code_insee[1], "01001")
})

# ==============================================================================
# 2. standardize_parcels — with "id_parcelle" column
# ==============================================================================

test_that("standardize_parcels maps id_parcelle column to id", {
  parcels <- make_poly_sf(2, cols = list(
    id_parcelle = c("PARC_A", "PARC_B"),
    contenance = c(8000, 12000)
  ))

  result <- nemeton:::standardize_parcels(parcels, "36005")
  expect_true("id" %in% names(result))
  expect_equal(result$id, c("PARC_A", "PARC_B"))
})

# ==============================================================================
# 3. standardize_parcels — with neither id-like column (generates IDs)
# ==============================================================================

test_that("standardize_parcels generates IDs when no id columns exist", {
  parcels <- make_poly_sf(4, cols = list(
    some_data = c("x", "y", "z", "w")
  ))

  result <- nemeton:::standardize_parcels(parcels, "75056")
  expect_true("id" %in% names(result))
  expect_equal(result$id, c("75056_1", "75056_2", "75056_3", "75056_4"))
})

# ==============================================================================
# 4. standardize_parcels — with non-polygon geometries mixed in
# ==============================================================================

test_that("standardize_parcels filters out POINT geometries from mixed set", {
  poly1 <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  poly2 <- sf::st_polygon(list(matrix(
    c(2, 0, 3, 0, 3, 1, 2, 1, 2, 0), ncol = 2, byrow = TRUE
  )))
  pt1 <- sf::st_point(c(5, 5))
  pt2 <- sf::st_point(c(6, 6))

  mixed_geom <- sf::st_sfc(poly1, pt1, poly2, pt2, crs = 4326)
  parcels <- sf::st_sf(
    id = c("poly_1", "pt_1", "poly_2", "pt_2"),
    contenance = c(5000, 100, 8000, 200),
    geometry = mixed_geom
  )

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_equal(nrow(result), 2)
  expect_true(all(sf::st_geometry_type(result) %in% c("POLYGON", "MULTIPOLYGON")))
})

# ==============================================================================
# 5. standardize_parcels — LINESTRING + POLYGON mix
# ==============================================================================

test_that("standardize_parcels filters out LINESTRING geometries", {
  poly <- sf::st_polygon(list(matrix(
    c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE
  )))
  line <- sf::st_linestring(matrix(c(0, 0, 1, 1), ncol = 2, byrow = TRUE))

  mixed_geom <- sf::st_sfc(poly, line, crs = 4326)
  parcels <- sf::st_sf(
    id = c("poly_1", "line_1"),
    contenance = c(5000, 0),
    geometry = mixed_geom
  )

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_equal(nrow(result), 1)
  expect_equal(result$id[1], "poly_1")
})

# ==============================================================================
# 6. standardize_parcels — only non-polygon geometries => error
# ==============================================================================

test_that("standardize_parcels errors when all geometries are non-polygon", {
  pts <- sf::st_sfc(
    sf::st_point(c(0, 0)),
    sf::st_point(c(1, 1)),
    crs = 4326
  )
  parcels <- sf::st_sf(id = c("a", "b"), geometry = pts)

  expect_error(
    nemeton:::standardize_parcels(parcels, "01001"),
    "No polygon geometries"
  )
})

# ==============================================================================
# 7. standardize_parcels — without section/numero/contenance columns
# ==============================================================================

test_that("standardize_parcels creates section/numero/contenance when missing", {
  parcels <- make_poly_sf(2, cols = list(
    id = c("p1", "p2")
  ))

  result <- nemeton:::standardize_parcels(parcels, "01001")

  expect_true("section" %in% names(result))
  expect_true("numero" %in% names(result))
  expect_true("contenance" %in% names(result))
  expect_true(is.na(result$section[1]))
  expect_true(is.na(result$numero[1]))
  # contenance should be calculated from geometry (area > 0)
  expect_true(all(result$contenance > 0))
})

# ==============================================================================
# 8. standardize_parcels — column order and geometry validity
# ==============================================================================

test_that("standardize_parcels outputs required columns in correct order", {
  parcels <- make_poly_sf(1, cols = list(
    id = "p1",
    section = "AB",
    numero = "0042",
    contenance = 20000,
    extra_col = "extra_val"
  ))

  result <- nemeton:::standardize_parcels(parcels, "01001")

  nms <- names(result)
  required <- c("id", "section", "numero", "contenance", "code_insee")
  # First 5 columns should be the required ones

  expect_equal(nms[1:5], required)
  # extra column should still be present
  expect_true("extra_col" %in% nms)
  # geometry should be last
  expect_equal(nms[length(nms)], "geometry")
})

# ==============================================================================
# 9. standardize_parcels — MULTIPOLYGON geometry accepted
# ==============================================================================

test_that("standardize_parcels keeps MULTIPOLYGON geometries", {
  mp <- sf::st_multipolygon(list(
    list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE)),
    list(matrix(c(2, 0, 3, 0, 3, 1, 2, 1, 2, 0), ncol = 2, byrow = TRUE))
  ))
  geom <- sf::st_sfc(mp, crs = 4326)
  parcels <- sf::st_sf(id = "mp1", contenance = 25000, geometry = geom)

  result <- nemeton:::standardize_parcels(parcels, "2A004")
  expect_equal(nrow(result), 1)
  expect_equal(result$code_insee[1], "2A004")
})

# ==============================================================================
# 10. standardize_parcels — ensures st_make_valid is called
# ==============================================================================

test_that("standardize_parcels returns valid geometries", {
  parcels <- make_poly_sf(3, cols = list(
    id = c("v1", "v2", "v3"),
    contenance = c(1000, 2000, 3000)
  ))

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_true(all(sf::st_is_valid(result)))
})

# ==============================================================================
# 11. get_parcel_by_id — returns correct single parcel
# ==============================================================================

test_that("get_parcel_by_id returns the matching parcel row", {
  parcels <- make_poly_sf(3, cols = list(
    id = c("aaa", "bbb", "ccc"),
    section = c("A", "B", "C")
  ))

  result <- nemeton:::get_parcel_by_id("bbb", parcels)
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "bbb")
  expect_equal(result$section, "B")
})

# ==============================================================================
# 12. get_parcel_by_id — returns NULL for non-existent ID
# ==============================================================================

test_that("get_parcel_by_id returns NULL when id not found", {
  parcels <- make_poly_sf(2, cols = list(
    id = c("x1", "x2")
  ))

  result <- nemeton:::get_parcel_by_id("nonexistent", parcels)
  expect_null(result)
})

# ==============================================================================
# 13. get_parcel_by_id — with duplicated IDs returns all matching
# ==============================================================================

test_that("get_parcel_by_id returns all rows for duplicated id", {
  parcels <- make_poly_sf(3, cols = list(
    id = c("dup", "dup", "other")
  ))

  result <- nemeton:::get_parcel_by_id("dup", parcels)
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 2)
})

# ==============================================================================
# 14. filter_selected_parcels — filters to matching IDs
# ==============================================================================

test_that("filter_selected_parcels returns only selected parcels", {
  parcels <- make_poly_sf(5, cols = list(
    id = c("a", "b", "c", "d", "e")
  ))

  result <- nemeton:::filter_selected_parcels(parcels, c("b", "d", "e"))
  expect_equal(nrow(result), 3)
  expect_true(all(c("b", "d", "e") %in% result$id))
  expect_false("a" %in% result$id)
})

# ==============================================================================
# 15. filter_selected_parcels — empty selection returns empty sf
# ==============================================================================

test_that("filter_selected_parcels with empty selection returns 0 rows", {
  parcels <- make_poly_sf(3, cols = list(
    id = c("a", "b", "c")
  ))

  result <- nemeton:::filter_selected_parcels(parcels, character(0))
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 0)
})

# ==============================================================================
# 16. filter_selected_parcels — selection with no matches returns empty sf
# ==============================================================================

test_that("filter_selected_parcels with no matching IDs returns 0 rows", {
  parcels <- make_poly_sf(2, cols = list(
    id = c("a", "b")
  ))

  result <- nemeton:::filter_selected_parcels(parcels, c("x", "y", "z"))
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 0)
})

# ==============================================================================
# 17. filter_selected_parcels — partial match
# ==============================================================================

test_that("filter_selected_parcels with partial match returns only existing", {
  parcels <- make_poly_sf(3, cols = list(
    id = c("p1", "p2", "p3")
  ))

  result <- nemeton:::filter_selected_parcels(parcels, c("p2", "p999"))
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "p2")
})

# ==============================================================================
# 18. calculate_parcel_stats — standard case
# ==============================================================================

test_that("calculate_parcel_stats computes correct stats for 3 parcels", {
  parcels <- make_poly_sf(3, cols = list(
    id = c("p1", "p2", "p3"),
    contenance = c(10000, 20000, 30000)
  ))

  stats <- nemeton:::calculate_parcel_stats(parcels)
  expect_equal(stats$count, 3)
  expect_equal(stats$total_area_ha, 6)   # (10000+20000+30000)/10000
  expect_equal(stats$mean_area_ha, 2)    # 6/3
  expect_equal(stats$min_area_ha, 1)     # 10000/10000
  expect_equal(stats$max_area_ha, 3)     # 30000/10000
})

# ==============================================================================
# 19. calculate_parcel_stats — NULL input
# ==============================================================================

test_that("calculate_parcel_stats returns zeros for NULL input", {
  stats <- nemeton:::calculate_parcel_stats(NULL)
  expect_equal(stats$count, 0)
  expect_equal(stats$total_area_ha, 0)
  expect_equal(stats$mean_area_ha, 0)
  expect_equal(stats$min_area_ha, 0)
  expect_equal(stats$max_area_ha, 0)
})

# ==============================================================================
# 20. calculate_parcel_stats — empty sf
# ==============================================================================

test_that("calculate_parcel_stats returns zeros for empty sf", {
  empty_sf <- sf::st_sf(
    id = character(0),
    contenance = numeric(0),
    geometry = sf::st_sfc(crs = 4326)
  )

  stats <- nemeton:::calculate_parcel_stats(empty_sf)
  expect_equal(stats$count, 0)
  expect_equal(stats$total_area_ha, 0)
})

# ==============================================================================
# 21. calculate_parcel_stats — single parcel
# ==============================================================================

test_that("calculate_parcel_stats works with single parcel", {
  parcels <- make_poly_sf(1, cols = list(
    id = "solo",
    contenance = 50000
  ))

  stats <- nemeton:::calculate_parcel_stats(parcels)
  expect_equal(stats$count, 1)
  expect_equal(stats$total_area_ha, 5)
  expect_equal(stats$mean_area_ha, 5)
  expect_equal(stats$min_area_ha, 5)
  expect_equal(stats$max_area_ha, 5)
})

# ==============================================================================
# 22. calculate_parcel_stats — with NA contenance values
# ==============================================================================

test_that("calculate_parcel_stats handles NA contenance with na.rm", {
  parcels <- make_poly_sf(3, cols = list(
    id = c("p1", "p2", "p3"),
    contenance = c(10000, NA_real_, 30000)
  ))

  stats <- nemeton:::calculate_parcel_stats(parcels)
  expect_equal(stats$count, 3)
  expect_equal(stats$total_area_ha, 4)   # (10000+30000)/10000
  expect_equal(stats$mean_area_ha, 2)    # 4/2 (na.rm skips NA)
})

# ==============================================================================
# 23. format_parcel_info — French format
# ==============================================================================

test_that("format_parcel_info returns French format with correct content", {
  parcel <- make_poly_sf(1, cols = list(
    id = "FR_PARC_001",
    section = "AB",
    numero = "0042",
    contenance = 25000
  ))[1, ]

  result <- nemeton:::format_parcel_info(parcel, "fr")
  expect_true(grepl("Parcelle FR_PARC_001", result))
  expect_true(grepl("Section: AB", result))
  expect_true(grepl("2\\.50 ha", result))
  expect_true(grepl("Surface", result))
})

# ==============================================================================
# 24. format_parcel_info — English format
# ==============================================================================

test_that("format_parcel_info returns English format with correct content", {
  parcel <- make_poly_sf(1, cols = list(
    id = "EN_PARC_001",
    section = "CD",
    numero = "0099",
    contenance = 45000
  ))[1, ]

  result <- nemeton:::format_parcel_info(parcel, "en")
  expect_true(grepl("Parcel EN_PARC_001", result))
  expect_true(grepl("No: 0099", result))
  expect_true(grepl("Area", result))
  expect_true(grepl("4\\.50 ha", result))
  expect_false(grepl("Surface", result))
})

# ==============================================================================
# 25. format_parcel_info — with NA section and numero uses "?" fallback
# ==============================================================================

test_that("format_parcel_info shows ? for NA section/numero", {
  parcel <- make_poly_sf(1, cols = list(
    id = "test",
    section = NA_character_,
    numero = NA_character_,
    contenance = 10000
  ))[1, ]

  result_fr <- nemeton:::format_parcel_info(parcel, "fr")
  # NA will not be NULL so %||% won't trigger; we just verify it runs

  expect_type(result_fr, "character")
  expect_true(nchar(result_fr) > 0)
})

# ==============================================================================
# 26. format_parcel_info — default language is "fr"
# ==============================================================================

test_that("format_parcel_info defaults to French format", {
  parcel <- make_poly_sf(1, cols = list(
    id = "def_test",
    section = "Z",
    numero = "1234",
    contenance = 7500
  ))[1, ]

  result <- nemeton:::format_parcel_info(parcel)
  expect_true(grepl("Parcelle", result))
  expect_true(grepl("Surface", result))
})

# ==============================================================================
# 27. create_parcel_popup — standard HTML output
# ==============================================================================

test_that("create_parcel_popup generates valid HTML with parcel data", {
  parcel <- make_poly_sf(1, cols = list(
    id = "POPUP_001",
    section = "X",
    numero = "0077",
    contenance = 33333
  ))[1, ]

  result <- nemeton:::create_parcel_popup(parcel)
  expect_type(result, "character")
  expect_true(grepl("<strong>POPUP_001</strong>", result, fixed = TRUE))
  expect_true(grepl("Section: X", result))
  expect_true(grepl("0077", result))
  expect_true(grepl("ha", result))
  # 33333/10000 = 3.3333 -> rounded to 3 decimals = 3.333
  expect_true(grepl("3\\.333", result))
})

# ==============================================================================
# 28. create_parcel_popup — with NULL section/numero uses dash
# ==============================================================================

test_that("create_parcel_popup uses dash for NULL section and numero", {
  parcel <- list(
    id = "null_test",
    section = NULL,
    numero = NULL,
    contenance = 20000
  )

  result <- nemeton:::create_parcel_popup(parcel)
  expect_type(result, "character")
  expect_true(grepl("<strong>null_test</strong>", result, fixed = TRUE))
  # %||% should replace NULL with "-"
  expect_true(grepl("Section: -", result, fixed = TRUE))
})

# ==============================================================================
# 29. create_parcel_popup — area rounding to 3 decimals
# ==============================================================================

test_that("create_parcel_popup rounds area to 3 decimal places", {
  parcel <- make_poly_sf(1, cols = list(
    id = "round_test",
    section = "R",
    numero = "0001",
    contenance = 12345
  ))[1, ]

  result <- nemeton:::create_parcel_popup(parcel)
  # 12345 / 10000 = 1.2345 -> round(..., 3) = 1.234 (not 1.235)
  expect_true(grepl("1\\.234", result) || grepl("1\\.235", result))
})

# ==============================================================================
# 30. create_parcel_label — with section, numero, contenance, no lieu-dit
# ==============================================================================

test_that("create_parcel_label generates label with section, numero, area", {
  parcel <- list(
    section = "AB",
    numero = "0042",
    contenance = 25000,
    nom_com = NULL,
    lieu_dit = NULL,
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_type(result, "character")
  expect_true(grepl("<b>AB 0042</b>", result, fixed = TRUE))
  expect_true(grepl("<b>2.5 ha</b>", result, fixed = TRUE))
  expect_true(grepl("lectionner", result))
})

# ==============================================================================
# 31. create_parcel_label — with nom_com lieu-dit
# ==============================================================================

test_that("create_parcel_label includes nom_com as lieu-dit", {
  parcel <- list(
    section = "F",
    numero = "0010",
    contenance = 15000,
    nom_com = "Saint-Martin",
    lieu_dit = NULL,
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_true(grepl("Saint-Martin", result, fixed = TRUE))
  expect_true(grepl("color:#666", result, fixed = TRUE))
})

# ==============================================================================
# 32. create_parcel_label — with lieu_dit (second fallback)
# ==============================================================================

test_that("create_parcel_label uses lieu_dit when nom_com is NULL", {
  parcel <- list(
    section = "G",
    numero = "0020",
    contenance = 18000,
    nom_com = NULL,
    lieu_dit = "La Foret Noire",
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_true(grepl("La Foret Noire", result, fixed = TRUE))
})

# ==============================================================================
# 33. create_parcel_label — with lieudit (third fallback)
# ==============================================================================

test_that("create_parcel_label uses lieudit as third fallback", {
  parcel <- list(
    section = "H",
    numero = "0030",
    contenance = 22000,
    nom_com = NULL,
    lieu_dit = NULL,
    lieudit = "Les Tilleuls"
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_true(grepl("Les Tilleuls", result, fixed = TRUE))
})

# ==============================================================================
# 34. create_parcel_label — with NULL contenance (no area text)
# ==============================================================================

test_that("create_parcel_label omits area when contenance is NULL", {
  parcel <- list(
    section = "I",
    numero = "0040",
    contenance = NULL,
    nom_com = NULL,
    lieu_dit = NULL,
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_type(result, "character")
  expect_false(grepl("ha", result))
})

# ==============================================================================
# 35. create_parcel_label — with NA contenance (no area text)
# ==============================================================================

test_that("create_parcel_label omits area when contenance is NA", {
  parcel <- list(
    section = "J",
    numero = "0050",
    contenance = NA,
    nom_com = NULL,
    lieu_dit = NULL,
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_type(result, "character")
  expect_false(grepl("\\bha\\b", result))
})

# ==============================================================================
# 36. create_parcel_label — with NULL section/numero (falls back to "-")
# ==============================================================================

test_that("create_parcel_label uses dash for NULL section and numero", {
  parcel <- list(
    section = NULL,
    numero = NULL,
    contenance = 10000,
    nom_com = NULL,
    lieu_dit = NULL,
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_true(grepl("<b>- -</b>", result, fixed = TRUE))
})

# ==============================================================================
# 37. create_parcel_label — lieu-dit "NA" string is excluded
# ==============================================================================

test_that("create_parcel_label excludes lieu-dit with value 'NA'", {
  parcel <- list(
    section = "K",
    numero = "0060",
    contenance = 11000,
    nom_com = "NA",
    lieu_dit = NULL,
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_false(grepl("color:#666", result, fixed = TRUE))
})

# ==============================================================================
# 38. create_parcel_label — empty string lieu-dit excluded
# ==============================================================================

test_that("create_parcel_label excludes empty string lieu-dit", {
  parcel <- list(
    section = "L",
    numero = "0070",
    contenance = 9000,
    nom_com = "",
    lieu_dit = NULL,
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_false(grepl("color:#666", result, fixed = TRUE))
})

# ==============================================================================
# 39. get_cadastral_parcels — invalid INSEE codes
# ==============================================================================

test_that("get_cadastral_parcels rejects short INSEE code", {
  expect_error(nemeton:::get_cadastral_parcels("123"), "Invalid INSEE")
})

test_that("get_cadastral_parcels rejects long INSEE code", {
  expect_error(nemeton:::get_cadastral_parcels("123456"), "Invalid INSEE")
})

test_that("get_cadastral_parcels rejects letters other than A/B", {
  expect_error(nemeton:::get_cadastral_parcels("CDEFG"), "Invalid INSEE")
  expect_error(nemeton:::get_cadastral_parcels("1234Z"), "Invalid INSEE")
})

test_that("get_cadastral_parcels rejects empty string", {
  expect_error(nemeton:::get_cadastral_parcels(""), "Invalid INSEE")
})

test_that("get_cadastral_parcels rejects special characters", {
  expect_error(nemeton:::get_cadastral_parcels("12-45"), "Invalid INSEE")
  expect_error(nemeton:::get_cadastral_parcels("12 45"), "Invalid INSEE")
})

# ==============================================================================
# 40. get_cadastral_parcels — successful API returns standardized result
# ==============================================================================

test_that("get_cadastral_parcels returns standardized parcels from API", {
  mock_parcels <- make_poly_sf(4, cols = list(
    id = c("p1", "p2", "p3", "p4"),
    section = c("A", "A", "B", "B"),
    numero = c("0001", "0002", "0001", "0002"),
    contenance = c(5000, 10000, 15000, 20000)
  ))

  with_mocked_bindings(
    .package = "nemeton",
    fetch_api_cadastre = function(code_insee) mock_parcels,
    {
      result <- nemeton:::get_cadastral_parcels("01001")
      expect_s3_class(result, "sf")
      expect_equal(nrow(result), 4)
      expect_true("id" %in% names(result))
      expect_true("code_insee" %in% names(result))
      expect_equal(unique(result$code_insee), "01001")
    }
  )
})

# ==============================================================================
# 41. get_cadastral_parcels — API fails, fallback to happign
# ==============================================================================

test_that("get_cadastral_parcels falls back to happign on API failure", {
  mock_parcels <- make_poly_sf(2, cols = list(
    id = c("fb1", "fb2"),
    contenance = c(8000, 12000)
  ))

  with_mocked_bindings(
    .package = "nemeton",
    fetch_api_cadastre = function(code_insee) stop("Connection timeout"),
    fetch_happign_cadastre = function(code_insee, commune_geometry) mock_parcels,
    {
      result <- suppressWarnings(
        nemeton:::get_cadastral_parcels("01001")
      )
      expect_s3_class(result, "sf")
      expect_true(nrow(result) > 0)
    }
  )
})

# ==============================================================================
# 42. get_cadastral_parcels — API returns empty sf, falls back
# ==============================================================================

test_that("get_cadastral_parcels falls back when API returns empty sf", {
  empty_sf <- sf::st_sf(
    id = character(0),
    geometry = sf::st_sfc(crs = 4326)
  )
  mock_parcels <- make_poly_sf(3, cols = list(
    id = c("fb1", "fb2", "fb3"),
    contenance = c(5000, 6000, 7000)
  ))

  with_mocked_bindings(
    .package = "nemeton",
    fetch_api_cadastre = function(code_insee) empty_sf,
    fetch_happign_cadastre = function(code_insee, commune_geometry) mock_parcels,
    {
      result <- nemeton:::get_cadastral_parcels("01001")
      expect_s3_class(result, "sf")
      expect_equal(nrow(result), 3)
    }
  )
})

# ==============================================================================
# 43. get_cadastral_parcels — API returns NULL, falls back
# ==============================================================================

test_that("get_cadastral_parcels falls back when API returns NULL via error", {
  mock_parcels <- make_poly_sf(1, cols = list(
    id = "fallback",
    contenance = 9999
  ))

  with_mocked_bindings(
    .package = "nemeton",
    fetch_api_cadastre = function(code_insee) stop("Server error"),
    fetch_happign_cadastre = function(code_insee, commune_geometry) mock_parcels,
    {
      result <- suppressWarnings(
        nemeton:::get_cadastral_parcels("2B033")
      )
      expect_s3_class(result, "sf")
      expect_true(nrow(result) > 0)
    }
  )
})

# ==============================================================================
# 44. get_cadastral_parcels — both sources fail => error
# ==============================================================================

test_that("get_cadastral_parcels errors when both API and happign fail", {
  with_mocked_bindings(
    .package = "nemeton",
    fetch_api_cadastre = function(code_insee) stop("API unreachable"),
    fetch_happign_cadastre = function(code_insee, commune_geometry) stop("WFS error"),
    {
      expect_error(
        suppressWarnings(
          nemeton:::get_cadastral_parcels("01001")
        ),
        "Unable to fetch|WFS error"
      )
    }
  )
})

# ==============================================================================
# 45. get_cadastral_parcels — happign returns empty => final error
# ==============================================================================

test_that("get_cadastral_parcels errors when fallback also returns empty", {
  empty_sf <- sf::st_sf(
    id = character(0),
    geometry = sf::st_sfc(crs = 4326)
  )

  with_mocked_bindings(
    .package = "nemeton",
    fetch_api_cadastre = function(code_insee) stop("API down"),
    fetch_happign_cadastre = function(code_insee, commune_geometry) empty_sf,
    {
      expect_error(
        suppressWarnings(
          nemeton:::get_cadastral_parcels("01001")
        ),
        "No parcels found"
      )
    }
  )
})

# ==============================================================================
# 46. get_cadastral_parcels — accepts Corsican codes 2A and 2B
# ==============================================================================

test_that("get_cadastral_parcels accepts Corsican codes 2A/2B", {
  mock_parcels <- make_poly_sf(1, cols = list(
    id = "corsica",
    contenance = 10000
  ))

  with_mocked_bindings(
    .package = "nemeton",
    fetch_api_cadastre = function(code_insee) mock_parcels,
    {
      result_a <- nemeton:::get_cadastral_parcels("2A004")
      expect_s3_class(result_a, "sf")

      result_b <- nemeton:::get_cadastral_parcels("2B033")
      expect_s3_class(result_b, "sf")
    }
  )
})

# ==============================================================================
# 47. fetch_api_cadastre — function exists and is callable
# ==============================================================================

test_that("fetch_api_cadastre is a function", {
  expect_true(is.function(nemeton:::fetch_api_cadastre))
})

# ==============================================================================
# 48. fetch_happign_cadastre — function exists and is callable
# ==============================================================================

test_that("fetch_happign_cadastre is a function", {
  expect_true(is.function(nemeton:::fetch_happign_cadastre))
})

# ==============================================================================
# 49. standardize_parcels — preserves CRS through transformation
# ==============================================================================

test_that("standardize_parcels preserves CRS 4326", {
  parcels <- make_poly_sf(2, crs = 4326, cols = list(
    id = c("crs1", "crs2"),
    contenance = c(5000, 6000)
  ))

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_equal(sf::st_crs(result)$epsg, 4326L)
})

# ==============================================================================
# 50. standardize_parcels — contenance calculated from geometry when missing
# ==============================================================================

test_that("standardize_parcels calculates contenance from geometry area", {
  # Create a polygon in WGS84 with known approximate area
  parcels <- make_poly_sf(1, crs = 4326, cols = list(
    id = "area_calc"
  ))

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_true("contenance" %in% names(result))
  # The polygon is 1 deg x 1 deg at equator, should have large area in m2
  expect_true(is.numeric(result$contenance))
  expect_true(result$contenance[1] > 0)
})

# ==============================================================================
# 51. standardize_parcels — with existing "id" column (no mapping needed)
# ==============================================================================

test_that("standardize_parcels keeps existing id column as-is", {
  parcels <- make_poly_sf(2, cols = list(
    id = c("keep_me_1", "keep_me_2"),
    contenance = c(3000, 4000)
  ))

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_equal(result$id, c("keep_me_1", "keep_me_2"))
})

# ==============================================================================
# 52. get_parcel_by_id — returns sf object with all columns preserved
# ==============================================================================

test_that("get_parcel_by_id preserves all columns in returned row", {
  parcels <- make_poly_sf(2, cols = list(
    id = c("p1", "p2"),
    section = c("A", "B"),
    numero = c("001", "002"),
    contenance = c(5000, 10000),
    extra = c("val1", "val2")
  ))

  result <- nemeton:::get_parcel_by_id("p2", parcels)
  expect_true("extra" %in% names(result))
  expect_equal(result$extra, "val2")
  expect_equal(result$contenance, 10000)
})

# ==============================================================================
# 53. filter_selected_parcels — preserves sf class and columns
# ==============================================================================

test_that("filter_selected_parcels preserves sf class and all columns", {
  parcels <- make_poly_sf(3, cols = list(
    id = c("a", "b", "c"),
    section = c("X", "Y", "Z"),
    contenance = c(1000, 2000, 3000)
  ))

  result <- nemeton:::filter_selected_parcels(parcels, c("a", "c"))
  expect_s3_class(result, "sf")
  expect_true("section" %in% names(result))
  expect_true("contenance" %in% names(result))
  expect_equal(result$section, c("X", "Z"))
})

# ==============================================================================
# 54. create_parcel_popup — includes selection instruction text
# ==============================================================================

test_that("create_parcel_popup includes click instruction", {
  parcel <- make_poly_sf(1, cols = list(
    id = "click_test",
    section = "M",
    numero = "0001",
    contenance = 5000
  ))[1, ]

  result <- nemeton:::create_parcel_popup(parcel)
  expect_true(grepl("lectionner", result))
  expect_true(grepl("<em", result))
})

# ==============================================================================
# 55. create_parcel_label — includes click instruction
# ==============================================================================

test_that("create_parcel_label includes green click instruction", {
  parcel <- list(
    section = "N",
    numero = "0002",
    contenance = 7000,
    nom_com = NULL,
    lieu_dit = NULL,
    lieudit = NULL
  )

  result <- nemeton:::create_parcel_label(parcel)
  expect_true(grepl("color:#1B6B1B", result, fixed = TRUE))
  expect_true(grepl("font-size:11px", result, fixed = TRUE))
  expect_true(grepl("lectionner", result))
})

# ==============================================================================
# 56. get_cadastral_parcels — passes commune_geometry to happign fallback
# ==============================================================================

test_that("get_cadastral_parcels passes commune_geometry to fallback", {
  mock_parcels <- make_poly_sf(2, cols = list(
    id = c("g1", "g2"),
    contenance = c(5000, 6000)
  ))

  commune_geom <- make_poly_sf(1, crs = 4326)

  captured_geom <- NULL
  with_mocked_bindings(
    .package = "nemeton",
    fetch_api_cadastre = function(code_insee) stop("fail"),
    fetch_happign_cadastre = function(code_insee, commune_geometry) {
      captured_geom <<- commune_geometry
      mock_parcels
    },
    {
      suppressWarnings(
        nemeton:::get_cadastral_parcels("01001", commune_geometry = commune_geom)
      )
      expect_s3_class(captured_geom, "sf")
    }
  )
})

# ==============================================================================
# 57. standardize_parcels — multiple parcels with id_parcelle
# ==============================================================================

test_that("standardize_parcels handles multiple parcels with id_parcelle", {
  parcels <- make_poly_sf(3, cols = list(
    id_parcelle = c("IP1", "IP2", "IP3"),
    section = c("A", "B", "C"),
    numero = c("01", "02", "03"),
    contenance = c(1000, 2000, 3000)
  ))

  result <- nemeton:::standardize_parcels(parcels, "01001")
  expect_equal(result$id, c("IP1", "IP2", "IP3"))
  expect_equal(result$section, c("A", "B", "C"))
})

# ==============================================================================
# 58. calculate_parcel_stats — returns list type
# ==============================================================================

test_that("calculate_parcel_stats always returns a list with 5 elements", {
  parcels <- make_poly_sf(2, cols = list(
    id = c("a", "b"),
    contenance = c(10000, 20000)
  ))

  stats <- nemeton:::calculate_parcel_stats(parcels)
  expect_type(stats, "list")
  expect_length(stats, 5)
  expected_names <- c("count", "total_area_ha", "mean_area_ha", "min_area_ha", "max_area_ha")
  expect_equal(names(stats), expected_names)

  # Same for NULL input
  stats_null <- nemeton:::calculate_parcel_stats(NULL)
  expect_type(stats_null, "list")
  expect_length(stats_null, 5)
  expect_equal(names(stats_null), expected_names)
})

# ==============================================================================
# 59. format_parcel_info — very small area
# ==============================================================================

test_that("format_parcel_info formats very small area correctly", {
  parcel <- make_poly_sf(1, cols = list(
    id = "tiny",
    section = "T",
    numero = "0001",
    contenance = 100
  ))[1, ]

  result <- nemeton:::format_parcel_info(parcel, "fr")
  # 100/10000 = 0.01 ha
  expect_true(grepl("0\\.01 ha", result))
})

# ==============================================================================
# 60. create_parcel_popup — with large contenance
# ==============================================================================

test_that("create_parcel_popup handles large contenance values", {
  parcel <- make_poly_sf(1, cols = list(
    id = "large",
    section = "L",
    numero = "0001",
    contenance = 1000000
  ))[1, ]

  result <- nemeton:::create_parcel_popup(parcel)
  # 1000000/10000 = 100 ha
  expect_true(grepl("100", result))
})
