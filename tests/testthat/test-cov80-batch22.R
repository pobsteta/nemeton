# test-cov80-batch22.R
# Coverage boost for R/service_communes.R — deeper coverage of all code paths
# Targets: get_departments, validate_insee_code, format_communes_for_selectize,
#          search_communes, search_by_postal_code, get_commune_geometry,
#          get_commune_centroid, get_communes_in_department

# ==============================================================================
# 1. get_departments — structural properties
# ==============================================================================

test_that("get_departments returns at least 100 departments", {
  depts <- nemeton:::get_departments()
  expect_true(length(depts) >= 100)
})

test_that("get_departments returns a character vector", {
  depts <- nemeton:::get_departments()
  expect_type(depts, "character")
})

test_that("get_departments returns named vector", {
  depts <- nemeton:::get_departments()
  expect_false(is.null(names(depts)))
  expect_true(all(nchar(names(depts)) > 0))
})

test_that("get_departments names follow 'XX - Name' format", {
  depts <- nemeton:::get_departments()
  # Every name should match "code - label" pattern
  expect_true(all(grepl("^[0-9A-B]{2,3} - .+", names(depts))))
})

test_that("get_departments includes Corsican departments 2A and 2B", {
  depts <- nemeton:::get_departments()
  expect_true("2A" %in% depts)
  expect_true("2B" %in% depts)
  # Verify their labels
  idx_2a <- which(depts == "2A")
  expect_true(grepl("Corse", names(depts)[idx_2a]))
  idx_2b <- which(depts == "2B")
  expect_true(grepl("Corse", names(depts)[idx_2b]))
})

test_that("get_departments includes all overseas departments", {
  depts <- nemeton:::get_departments()
  overseas <- c("971", "972", "973", "974", "976")
  for (code in overseas) {
    expect_true(code %in% depts, info = paste("Missing overseas dept:", code))
  }
})

test_that("get_departments has unique values (no duplicate department codes)", {
  depts <- nemeton:::get_departments()
  expect_equal(length(depts), length(unique(depts)))
})

test_that("get_departments has unique names (no duplicate labels)", {
  depts <- nemeton:::get_departments()
  expect_equal(length(names(depts)), length(unique(names(depts))))
})

test_that("get_departments includes specific known departments", {
  depts <- nemeton:::get_departments()
  known <- c("01", "13", "33", "59", "69", "75", "73", "74")
  for (code in known) {
    expect_true(code %in% depts, info = paste("Missing dept:", code))
  }
})

test_that("get_departments does not include 20 (old Corsica code)", {
  depts <- nemeton:::get_departments()
  expect_false("20" %in% depts)
})

# ==============================================================================
# 2. validate_insee_code — exhaustive edge cases
# ==============================================================================

test_that("validate_insee_code accepts standard 5-digit codes", {
  expect_true(nemeton:::validate_insee_code("73001"))
  expect_true(nemeton:::validate_insee_code("75056"))
  expect_true(nemeton:::validate_insee_code("97101"))
  expect_true(nemeton:::validate_insee_code("00000"))
  expect_true(nemeton:::validate_insee_code("99999"))
})

test_that("validate_insee_code accepts Corsican codes with A", {
  expect_true(nemeton:::validate_insee_code("2A004"))
  expect_true(nemeton:::validate_insee_code("A0001"))
  expect_true(nemeton:::validate_insee_code("0000A"))
})

test_that("validate_insee_code accepts Corsican codes with B", {
  expect_true(nemeton:::validate_insee_code("2B033"))
  expect_true(nemeton:::validate_insee_code("B0001"))
  expect_true(nemeton:::validate_insee_code("0000B"))
})

test_that("validate_insee_code accepts codes with mixed A and B", {
  expect_true(nemeton:::validate_insee_code("AABBB"))
  expect_true(nemeton:::validate_insee_code("12AB3"))
  expect_true(nemeton:::validate_insee_code("BBBBB"))
  expect_true(nemeton:::validate_insee_code("AAAAA"))
})

test_that("validate_insee_code rejects NULL", {
  expect_false(nemeton:::validate_insee_code(NULL))
})

test_that("validate_insee_code rejects NA", {
  expect_false(nemeton:::validate_insee_code(NA))
  expect_false(nemeton:::validate_insee_code(NA_character_))
})

test_that("validate_insee_code rejects non-character input", {
  expect_false(nemeton:::validate_insee_code(12345))
  expect_false(nemeton:::validate_insee_code(73001L))
  expect_false(nemeton:::validate_insee_code(TRUE))
  expect_false(nemeton:::validate_insee_code(list("73001")))
})

test_that("validate_insee_code rejects empty string", {
  expect_false(nemeton:::validate_insee_code(""))
})

test_that("validate_insee_code rejects too short codes", {
  expect_false(nemeton:::validate_insee_code("123"))
  expect_false(nemeton:::validate_insee_code("1234"))
  expect_false(nemeton:::validate_insee_code("1"))
})

test_that("validate_insee_code rejects too long codes", {
  expect_false(nemeton:::validate_insee_code("123456"))
  expect_false(nemeton:::validate_insee_code("1234567"))
})

test_that("validate_insee_code rejects lowercase letters", {
  expect_false(nemeton:::validate_insee_code("2a004"))
  expect_false(nemeton:::validate_insee_code("2b033"))
  expect_false(nemeton:::validate_insee_code("abcde"))
})

test_that("validate_insee_code rejects codes with disallowed letters (C-Z)", {
  expect_false(nemeton:::validate_insee_code("2C001"))
  expect_false(nemeton:::validate_insee_code("1234X"))
  expect_false(nemeton:::validate_insee_code("XYZAB"))
  expect_false(nemeton:::validate_insee_code("12C45"))
})

test_that("validate_insee_code rejects codes with special characters", {
  expect_false(nemeton:::validate_insee_code("7500!"))
  expect_false(nemeton:::validate_insee_code("750 6"))
  expect_false(nemeton:::validate_insee_code("75-06"))
})

# ==============================================================================
# 3. format_communes_for_selectize — additional edge cases
# ==============================================================================

test_that("format_communes_for_selectize returns empty character for NULL", {
  result <- nemeton:::format_communes_for_selectize(NULL)
  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("format_communes_for_selectize returns empty character for 0-row df", {
  empty_df <- data.frame(
    code_insee = character(0),
    nom = character(0),
    code_postal = character(0),
    departement = character(0),
    label = character(0),
    stringsAsFactors = FALSE
  )
  result <- nemeton:::format_communes_for_selectize(empty_df)
  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("format_communes_for_selectize correctly maps labels to codes", {
  communes <- data.frame(
    code_insee = c("73001", "73002", "73003"),
    nom = c("Aix-les-Bains", "Albertville", "Chambery"),
    code_postal = c("73100", "73200", "73000"),
    label = c("Aix-les-Bains (73100)", "Albertville (73200)", "Chambery (73000)"),
    stringsAsFactors = FALSE
  )
  result <- nemeton:::format_communes_for_selectize(communes)

  expect_length(result, 3)
  expect_equal(unname(result[1]), "73001")
  expect_equal(unname(result[2]), "73002")
  expect_equal(unname(result[3]), "73003")
  expect_equal(names(result)[1], "Aix-les-Bains (73100)")
  expect_equal(names(result)[2], "Albertville (73200)")
  expect_equal(names(result)[3], "Chambery (73000)")
})

test_that("format_communes_for_selectize handles single commune", {
  communes <- data.frame(
    code_insee = "75056",
    nom = "Paris",
    code_postal = "75001",
    label = "Paris (75001)",
    stringsAsFactors = FALSE
  )
  result <- nemeton:::format_communes_for_selectize(communes)

  expect_length(result, 1)
  expect_equal(result[["Paris (75001)"]], "75056")
})

test_that("format_communes_for_selectize preserves special characters in labels", {
  communes <- data.frame(
    code_insee = "07001",
    nom = "Ard\u00e8che-Ville",
    code_postal = "07100",
    label = "Ard\u00e8che-Ville (07100)",
    stringsAsFactors = FALSE
  )
  result <- nemeton:::format_communes_for_selectize(communes)

  expect_length(result, 1)
  expect_equal(unname(result[1]), "07001")
  expect_true(grepl("Ard", names(result)[1]))
})

# ==============================================================================
# 4. search_communes — short query early returns
# ==============================================================================

test_that("search_communes returns empty df for 0-char query", {
  result <- nemeton:::search_communes("")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expected_cols <- c("code_insee", "nom", "code_postal", "departement", "label")
  expect_true(all(expected_cols %in% names(result)))
})

test_that("search_communes returns empty df for 1-char query", {
  result <- nemeton:::search_communes("P")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("search_communes returns empty df for 2-char query", {
  result <- nemeton:::search_communes("Pa")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("search_communes short query df has correct column types", {
  result <- nemeton:::search_communes("ab")
  expect_type(result$code_insee, "character")
  expect_type(result$nom, "character")
  expect_type(result$code_postal, "character")
  expect_type(result$departement, "character")
  expect_type(result$label, "character")
})

# ==============================================================================
# 5. search_communes — mocked API: department filter and empty string department
# ==============================================================================

test_that("search_communes with empty string department does not add filter param", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    list(
      code = "73001",
      nom = "Aix-les-Bains",
      codesPostaux = c("73100"),
      codeDepartement = "73"
    )
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::search_communes("Aix", department = "")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  expect_equal(result$code_insee[1], "73001")
})

test_that("search_communes label format includes nom and postal codes", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    list(
      code = "73001",
      nom = "Aix-les-Bains",
      codesPostaux = c("73100", "73105"),
      codeDepartement = "73"
    )
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::search_communes("Aix")
  expect_true(grepl("Aix-les-Bains", result$label[1]))
  expect_true(grepl("73100", result$label[1]))
  expect_true(grepl("73105", result$label[1]))
})

test_that("search_communes joins multiple postal codes with comma-space", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    list(
      code = "75056",
      nom = "Paris",
      codesPostaux = c("75001", "75002", "75003"),
      codeDepartement = "75"
    )
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::search_communes("Paris")
  expect_equal(result$code_postal[1], "75001, 75002, 75003")
})

test_that("search_communes returns empty for empty API response", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) list(),
    .package = "httr2"
  )

  result <- nemeton:::search_communes("ZzzNonexistent")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("search_communes handles API error with warning and empty df", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("Simulated connection timeout"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::search_communes("Paris"),
    regexp = "Error searching communes"
  )
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true("code_insee" %in% names(result))
})

# ==============================================================================
# 6. search_by_postal_code — input validation early returns
# ==============================================================================

test_that("search_by_postal_code rejects 3-digit code", {
  result <- nemeton:::search_by_postal_code("123")
  expect_equal(nrow(result), 0)
  expect_true(all(c("code_insee", "nom", "code_postal", "departement", "label") %in% names(result)))
})

test_that("search_by_postal_code rejects 6-digit code", {
  result <- nemeton:::search_by_postal_code("123456")
  expect_equal(nrow(result), 0)
})

test_that("search_by_postal_code rejects alphabetic code", {
  result <- nemeton:::search_by_postal_code("ABCDE")
  expect_equal(nrow(result), 0)
})

test_that("search_by_postal_code rejects empty string", {
  result <- nemeton:::search_by_postal_code("")
  expect_equal(nrow(result), 0)
})

test_that("search_by_postal_code rejects mixed alpha-numeric 5-char code", {
  result <- nemeton:::search_by_postal_code("7500X")
  expect_equal(nrow(result), 0)
})

test_that("search_by_postal_code invalid input returns correct columns", {
  result <- nemeton:::search_by_postal_code("bad")
  expected_cols <- c("code_insee", "nom", "code_postal", "departement", "label")
  expect_equal(sort(names(result)), sort(expected_cols))
})

test_that("search_by_postal_code handles empty API response", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) list(),
    .package = "httr2"
  )

  result <- nemeton:::search_by_postal_code("99999")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("search_by_postal_code parses single commune response", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    list(
      code = "73011",
      nom = "Aix-les-Bains",
      codesPostaux = c("73100"),
      codeDepartement = "73"
    )
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::search_by_postal_code("73100")
  expect_equal(nrow(result), 1)
  expect_equal(result$code_insee[1], "73011")
  expect_equal(result$nom[1], "Aix-les-Bains")
  expect_equal(result$departement[1], "73")
  expect_true(grepl("73100", result$code_postal[1]))
  expect_true(grepl("Aix-les-Bains", result$label[1]))
})

test_that("search_by_postal_code handles API error gracefully", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("Network unreachable"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::search_by_postal_code("75001"),
    regexp = "Error searching by postal code"
  )
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

# ==============================================================================
# 7. get_commune_geometry — input validation and error paths
# ==============================================================================

test_that("get_commune_geometry rejects lowercase letter codes", {
  expect_warning(
    result <- nemeton:::get_commune_geometry("2a004"),
    regexp = "Invalid"
  )
  expect_null(result)
})

test_that("get_commune_geometry rejects code with disallowed letter C", {
  expect_warning(
    result <- nemeton:::get_commune_geometry("2C001"),
    regexp = "Invalid"
  )
  expect_null(result)
})

test_that("get_commune_geometry rejects empty string", {
  expect_warning(
    result <- nemeton:::get_commune_geometry(""),
    regexp = "Invalid"
  )
  expect_null(result)
})

test_that("get_commune_geometry rejects 4-char code", {
  expect_warning(
    result <- nemeton:::get_commune_geometry("7505"),
    regexp = "Invalid"
  )
  expect_null(result)
})

test_that("get_commune_geometry rejects 6-char code", {
  expect_warning(
    result <- nemeton:::get_commune_geometry("750560"),
    regexp = "Invalid"
  )
  expect_null(result)
})

test_that("get_commune_geometry returns NULL with warning on missing contour", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    code = "73001",
    nom = "Aix-les-Bains",
    contour = NULL
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::get_commune_geometry("73001"),
    regexp = "No contour"
  )
  expect_null(result)
})

test_that("get_commune_geometry handles API server error gracefully", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("HTTP 500 Internal Server Error"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::get_commune_geometry("73001"),
    regexp = "Error getting commune geometry"
  )
  expect_null(result)
})

# ==============================================================================
# 8. get_commune_centroid — mocked paths
# ==============================================================================

test_that("get_commune_centroid returns named lng/lat vector on success", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    centre = list(
      type = "Point",
      coordinates = c(5.9167, 45.6833)
    )
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::get_commune_centroid("73011")
  expect_type(result, "double")
  expect_length(result, 2)
  expect_equal(names(result), c("lng", "lat"))
  expect_equal(unname(result[1]), 5.9167)
  expect_equal(unname(result[2]), 45.6833)
})

test_that("get_commune_centroid returns NULL when centre is NULL", {
  skip_if_not_installed("httr2")

  mock_response <- list(code = "73001", nom = "Aix-les-Bains")

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::get_commune_centroid("73001")
  expect_null(result)
})

test_that("get_commune_centroid returns NULL when coordinates are NULL", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    centre = list(type = "Point")
    # coordinates missing
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::get_commune_centroid("73001")
  expect_null(result)
})

test_that("get_commune_centroid handles connection error with warning", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("Connection refused"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::get_commune_centroid("73001"),
    regexp = "Error getting commune centroid"
  )
  expect_null(result)
})

# ==============================================================================
# 9. get_communes_in_department — input validation and error paths
# ==============================================================================

test_that("get_communes_in_department returns empty df for NULL", {
  result <- nemeton:::get_communes_in_department(NULL)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true(all(c("code_insee", "nom", "code_postal", "label") %in% names(result)))
})

test_that("get_communes_in_department returns empty df for empty string", {
  result <- nemeton:::get_communes_in_department("")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("get_communes_in_department sorts results alphabetically by nom", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    list(code = "73003", nom = "Chambery", codesPostaux = c("73000")),
    list(code = "73001", nom = "Aix-les-Bains", codesPostaux = c("73100")),
    list(code = "73002", nom = "Barby", codesPostaux = c("73230"))
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::get_communes_in_department("73")
  expect_equal(result$nom[1], "Aix-les-Bains")
  expect_equal(result$nom[2], "Barby")
  expect_equal(result$nom[3], "Chambery")
})

test_that("get_communes_in_department label format is 'nom (code)'", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    list(code = "73001", nom = "Aix-les-Bains", codesPostaux = c("73100"))
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::get_communes_in_department("73")
  expect_equal(result$label[1], "Aix-les-Bains (73001)")
})

test_that("get_communes_in_department handles empty postal codes list", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    list(code = "97601", nom = "Mamoudzou", codesPostaux = list())
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::get_communes_in_department("976")
  expect_equal(nrow(result), 1)
  expect_equal(result$code_postal[1], "")
})

test_that("get_communes_in_department returns empty for empty API response", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) list(),
    .package = "httr2"
  )

  result <- nemeton:::get_communes_in_department("99")
  expect_equal(nrow(result), 0)
})

test_that("get_communes_in_department tags network error with attributes", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("Could not resolve host: geo.api.gouv.fr"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::get_communes_in_department("73"),
    regexp = "Error getting communes"
  )
  expect_equal(nrow(result), 0)
  expect_equal(attr(result, "error"), "network")
  expect_equal(attr(result, "error_message"), "no_internet_connection")
})

test_that("get_communes_in_department tags timeout error as network", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("HTTP request timeout after 30 seconds"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::get_communes_in_department("01"),
    regexp = "Error getting communes"
  )
  expect_equal(attr(result, "error"), "network")
  expect_equal(attr(result, "error_message"), "no_internet_connection")
})

test_that("get_communes_in_department tags internet error as network", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("no internet connection available"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::get_communes_in_department("01"),
    regexp = "Error getting communes"
  )
  expect_equal(attr(result, "error"), "network")
})

test_that("get_communes_in_department tags curl error as network", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("curl error: connection refused"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::get_communes_in_department("73"),
    regexp = "Error getting communes"
  )
  expect_equal(attr(result, "error"), "network")
})

test_that("get_communes_in_department tags non-network error as 'other'", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("Unexpected JSON parse failure"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::get_communes_in_department("73"),
    regexp = "Error getting communes"
  )
  expect_equal(attr(result, "error"), "other")
  expect_true(grepl("Unexpected JSON", attr(result, "error_message")))
})

test_that("get_communes_in_department non-network error preserves error message", {
  skip_if_not_installed("httr2")

  local_mocked_bindings(
    req_perform = function(...) stop("Something completely unrelated went wrong"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::get_communes_in_department("73"),
    regexp = "Error getting communes"
  )
  expect_equal(attr(result, "error"), "other")
  expect_equal(attr(result, "error_message"), "Something completely unrelated went wrong")
})

test_that("get_communes_in_department handles multiple postal codes per commune", {
  skip_if_not_installed("httr2")

  mock_response <- list(
    list(
      code = "73001",
      nom = "Aix-les-Bains",
      codesPostaux = c("73100", "73105", "73110")
    )
  )

  local_mocked_bindings(
    req_perform = function(...) structure(list(), class = "httr2_response"),
    resp_body_json = function(...) mock_response,
    .package = "httr2"
  )

  result <- nemeton:::get_communes_in_department("73")
  expect_equal(nrow(result), 1)
  expect_equal(result$code_postal[1], "73100, 73105, 73110")
})

# ==============================================================================
# 10. Cross-function integration scenarios
# ==============================================================================

test_that("format_communes_for_selectize works with search_communes short query output", {
  result <- nemeton:::search_communes("ab")
  formatted <- nemeton:::format_communes_for_selectize(result)
  expect_type(formatted, "character")
  expect_length(formatted, 0)
})

test_that("validate_insee_code works with codes from get_departments values", {
  depts <- nemeton:::get_departments()
  # Department codes are 2-3 chars, not 5, so they should NOT be valid INSEE codes
  # except by coincidence if regex matches
  for (code in depts[1:5]) {
    if (nchar(code) != 5) {
      expect_false(nemeton:::validate_insee_code(code))
    }
  }
})
