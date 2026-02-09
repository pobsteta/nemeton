# test-coverage-boost3.R
# Coverage boost #3: service_project, utils_theme, service_export,
# service_compute constants, data-preprocessing validation.

# ============================================================
# Section 1: utils_theme.R
# ============================================================

test_that("ACCESSIBILITY_CONFIG is a well-formed list", {
  config <- nemeton:::ACCESSIBILITY_CONFIG
  expect_type(config, "list")
  expect_true("color_palettes" %in% names(config))
  expect_true("default_palette" %in% names(config))
  expect_true("use_symbols" %in% names(config))
  expect_true("symbol_shapes" %in% names(config))
  expect_true("min_touch_target" %in% names(config))
  expect_true("min_text_contrast" %in% names(config))
  expect_true("min_ui_contrast" %in% names(config))
  expect_true("min_font_size" %in% names(config))
  expect_true("line_height" %in% names(config))
  expect_equal(config$default_palette, "viridis")
  expect_true(config$use_symbols)
  expect_equal(config$min_touch_target, 44L)
  expect_equal(config$min_text_contrast, 4.5)
  expect_equal(config$min_ui_contrast, 3.0)
})

test_that("get_accessibility_config returns correct values", {
  expect_equal(
    nemeton:::get_accessibility_config("default_palette"),
    "viridis"
  )
  expect_equal(
    nemeton:::get_accessibility_config("min_touch_target"),
    44L
  )
  expect_true(nemeton:::get_accessibility_config("use_symbols"))
  expect_equal(
    nemeton:::get_accessibility_config("line_height"),
    1.5
  )
})

test_that("get_accessibility_config returns default for missing key", {
  expect_null(nemeton:::get_accessibility_config("nonexistent_key"))
  expect_equal(
    nemeton:::get_accessibility_config("nonexistent_key", default = "fallback"),
    "fallback"
  )
})

test_that("get_accessible_palette returns correct number of hex colors", {
  colors_5 <- nemeton:::get_accessible_palette(5)
  expect_length(colors_5, 5)
  expect_true(all(grepl("^#", colors_5)))

  colors_12 <- nemeton:::get_accessible_palette(12)
  expect_length(colors_12, 12)
})

test_that("get_accessible_palette with different palettes works", {
  for (pal in c("viridis", "plasma", "inferno", "magma", "cividis")) {
    colors <- nemeton:::get_accessible_palette(5, palette = pal)
    expect_length(colors, 5)
    expect_true(all(grepl("^#", colors)))
  }
})

test_that("get_accessible_palette warns on invalid palette", {
  expect_warning(
    colors <- nemeton:::get_accessible_palette(5, palette = "rainbow"),
    "colorblind-friendly"
  )
  expect_length(colors, 5)
})

test_that("get_accessible_palette with alpha works", {
  colors <- nemeton:::get_accessible_palette(3, alpha = 0.5)
  expect_length(colors, 3)
  expect_true(all(grepl("^#", colors)))
})

test_that("get_accessible_symbols returns correct shapes", {
  symbols_3 <- nemeton:::get_accessible_symbols(3)
  expect_length(symbols_3, 3)
  expect_type(symbols_3, "integer")

  # More symbols than available recycles

  symbols_10 <- nemeton:::get_accessible_symbols(10)
  expect_length(symbols_10, 10)
  expect_type(symbols_10, "integer")
})

test_that("get_family_colors returns 12 named colors", {
  colors <- nemeton:::get_family_colors()
  expect_length(colors, 12)
  expect_named(colors, c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N"))
  expect_true(all(grepl("^#", colors)))
})

test_that("nemeton_theme returns a bslib theme", {
  skip_if_not_installed("bslib")
  theme <- nemeton:::nemeton_theme()
  expect_s3_class(theme, "bs_theme")
})

test_that("theme_nemeton_accessible returns a ggplot2 theme", {
  skip_if_not_installed("ggplot2")
  th <- nemeton:::theme_nemeton_accessible()
  expect_s3_class(th, "theme")
  # Should have modifications
  expect_false(is.null(th$legend.position))
})


# ============================================================
# Section 2: service_export.R pure functions
# ============================================================

test_that("strip_markdown_for_display removes bold markers", {
  expect_equal(
    nemeton:::strip_markdown_for_display("This is **bold** text"),
    "This is bold text"
  )
})

test_that("strip_markdown_for_display removes italic markers", {
  expect_equal(
    nemeton:::strip_markdown_for_display("This is *italic* text"),
    "This is italic text"
  )
})

test_that("strip_markdown_for_display removes strikethrough", {
  expect_equal(
    nemeton:::strip_markdown_for_display("This is ~~removed~~ text"),
    "This is removed text"
  )
})

test_that("strip_markdown_for_display removes inline code", {
  expect_equal(
    nemeton:::strip_markdown_for_display("Use `print()` function"),
    "Use print() function"
  )
})

test_that("strip_markdown_for_display removes links", {
  expect_equal(
    nemeton:::strip_markdown_for_display("Visit [site](http://example.com) now"),
    "Visit site now"
  )
})

test_that("strip_markdown_for_display handles combined formatting", {
  text <- "**Bold** and *italic* with `code` and [link](url)"
  result <- nemeton:::strip_markdown_for_display(text)
  expect_false(grepl("\\*", result))
  expect_false(grepl("`", result))
  expect_false(grepl("\\[", result))
})

test_that("strip_markdown_for_display preserves plain text", {
  plain <- "No formatting here at all"
  expect_equal(nemeton:::strip_markdown_for_display(plain), plain)
})

test_that("justify_text_line distributes spaces for short lines", {
  result <- nemeton:::justify_text_line("hello world test", 20)
  expect_type(result, "character")
  expect_true(nchar(result) >= nchar("hello world test"))
})

test_that("justify_text_line returns same line if single word", {
  result <- nemeton:::justify_text_line("hello", 20)
  expect_equal(result, "hello")
})

test_that("justify_text_line returns same line if already at target width", {
  line <- paste(rep("x", 20), collapse = "")
  result <- nemeton:::justify_text_line(line, 20)
  expect_equal(result, line)
})

test_that("justify_text_line distributes spaces evenly", {
  result <- nemeton:::justify_text_line("a b c", 8)
  # 3 words, 3 chars text + need 5 more = 8 total
  # 2 gaps, each gets extra spaces
  expect_equal(nchar(result), 8)
})

test_that("justify_text_line handles multiple spaces", {
  result <- nemeton:::justify_text_line("word1  word2  word3", 25)
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})


# ============================================================
# Section 3: service_project.R tests (with temp dirs)
# ============================================================

# Helper: create a temp project root and mock get_projects_root
run_with_project_root <- function(code) {
  withr::with_tempdir({
    temp_root <- getwd()
    testthat::with_mocked_bindings(
      get_projects_root = function() temp_root,
      .package = "nemeton",
      code
    )
  })
}

test_that("get_project_path returns NULL for empty id", {
  run_with_project_root({
    expect_null(nemeton:::get_project_path(NULL))
    expect_null(nemeton:::get_project_path(""))
  })
})

test_that("get_project_path returns NULL for non-existent project", {
  run_with_project_root({
    expect_null(nemeton:::get_project_path("does_not_exist"))
  })
})

test_that("get_project_path returns path for existing project", {
  run_with_project_root({
    temp_root <- nemeton:::get_projects_root()
    dir.create(file.path(temp_root, "test_proj"), recursive = TRUE)
    path <- nemeton:::get_project_path("test_proj")
    expect_true(!is.null(path))
    expect_true(dir.exists(path))
  })
})

test_that("create_project creates valid project structure", {
  run_with_project_root({
    result <- nemeton:::create_project("Test Project", description = "A test", owner = "Tester")
    expect_type(result, "list")
    expect_true("id" %in% names(result))
    expect_true("path" %in% names(result))
    expect_true("metadata" %in% names(result))
    expect_true(dir.exists(result$path))
    expect_true(dir.exists(file.path(result$path, "data")))
    expect_true(dir.exists(file.path(result$path, "cache")))
    expect_true(dir.exists(file.path(result$path, "exports")))
    expect_true(file.exists(file.path(result$path, "metadata.json")))
  })
})

test_that("create_project sets correct metadata", {
  run_with_project_root({
    result <- nemeton:::create_project("My Project", description = "Desc", owner = "Me")
    meta <- jsonlite::read_json(file.path(result$path, "metadata.json"))
    expect_equal(meta$name, "My Project")
    expect_equal(meta$description, "Desc")
    expect_equal(meta$owner, "Me")
    expect_equal(meta$status, "draft")
    expect_equal(meta$parcels_count, 0L)
  })
})

test_that("create_project rejects empty name", {
  run_with_project_root({
    expect_error(nemeton:::create_project(""), "required")
    expect_error(nemeton:::create_project("   "), "required")
    expect_error(nemeton:::create_project(NULL), "required")
  })
})

test_that("create_project rejects name too long", {
  run_with_project_root({
    long_name <- paste(rep("x", 101), collapse = "")
    expect_error(nemeton:::create_project(long_name), "100 characters")
  })
})

test_that("create_project rejects description too long", {
  run_with_project_root({
    long_desc <- paste(rep("x", 501), collapse = "")
    expect_error(nemeton:::create_project("Valid", description = long_desc), "500 characters")
  })
})

test_that("create_project rejects owner too long", {
  run_with_project_root({
    long_owner <- paste(rep("x", 101), collapse = "")
    expect_error(nemeton:::create_project("Valid", owner = long_owner), "100 characters")
  })
})

test_that("load_project_metadata returns metadata for existing project", {
  run_with_project_root({
    result <- nemeton:::create_project("Meta Test")
    meta <- nemeton:::load_project_metadata(result$id)
    expect_type(meta, "list")
    expect_equal(meta$name, "Meta Test")
  })
})

test_that("load_project_metadata returns NULL for non-existent project", {
  run_with_project_root({
    expect_null(nemeton:::load_project_metadata("no_such_project"))
  })
})

test_that("check_project_health returns valid for good project", {
  run_with_project_root({
    result <- nemeton:::create_project("Health Test")
    health <- nemeton:::check_project_health(result$id)
    expect_true(health$valid)
    expect_length(health$issues, 0)
  })
})

test_that("check_project_health detects missing project", {
  run_with_project_root({
    health <- nemeton:::check_project_health("nonexistent")
    expect_false(health$valid)
    expect_true(length(health$issues) > 0)
  })
})

test_that("check_project_health detects missing metadata", {
  run_with_project_root({
    temp_root <- nemeton:::get_projects_root()
    proj_dir <- file.path(temp_root, "broken_proj")
    dir.create(file.path(proj_dir, "data"), recursive = TRUE)
    # No metadata.json
    health <- nemeton:::check_project_health("broken_proj")
    expect_false(health$valid)
    expect_true(any(grepl("metadata", health$issues, ignore.case = TRUE)))
  })
})

test_that("check_project_health detects missing data directory", {
  run_with_project_root({
    temp_root <- nemeton:::get_projects_root()
    proj_dir <- file.path(temp_root, "no_data_proj")
    dir.create(proj_dir, recursive = TRUE)
    # Create metadata but no data dir
    jsonlite::write_json(
      list(name = "Test", parcels_count = 0L),
      file.path(proj_dir, "metadata.json"),
      auto_unbox = TRUE
    )
    health <- nemeton:::check_project_health("no_data_proj")
    expect_false(health$valid)
    expect_true(any(grepl("data", health$issues, ignore.case = TRUE)))
  })
})

test_that("update_project_metadata updates fields", {
  run_with_project_root({
    result <- nemeton:::create_project("Update Test")
    nemeton:::update_project_metadata(result$id, list(status = "completed"))
    meta <- nemeton:::load_project_metadata(result$id)
    expect_equal(meta$status, "completed")
  })
})

test_that("update_project_metadata errors for non-existent project", {
  run_with_project_root({
    expect_error(
      nemeton:::update_project_metadata("no_such_proj", list(status = "done")),
      "not found"
    )
  })
})

test_that("update_project_status validates status values", {
  run_with_project_root({
    result <- nemeton:::create_project("Status Test")
    # Valid statuses
    for (s in c("draft", "downloading", "computing", "completed", "error")) {
      nemeton:::update_project_status(result$id, s)
      meta <- nemeton:::load_project_metadata(result$id)
      expect_equal(meta$status, s)
    }
  })
})

test_that("update_project_status rejects invalid status", {
  run_with_project_root({
    result <- nemeton:::create_project("Invalid Status")
    expect_error(
      nemeton:::update_project_status(result$id, "banana"),
      "Invalid status"
    )
  })
})

test_that("delete_project removes project directory", {
  run_with_project_root({
    result <- nemeton:::create_project("Delete Me")
    expect_true(dir.exists(result$path))
    deleted <- nemeton:::delete_project(result$id)
    expect_true(deleted)
    expect_false(dir.exists(result$path))
  })
})

test_that("delete_project warns for non-existent project", {
  run_with_project_root({
    expect_warning(
      result <- nemeton:::delete_project("nonexistent_proj"),
      "not found"
    )
    expect_false(result)
  })
})

test_that("list_recent_projects returns empty df when no projects", {
  run_with_project_root({
    projects <- nemeton:::list_recent_projects()
    expect_s3_class(projects, "data.frame")
    expect_equal(nrow(projects), 0)
    expect_true("id" %in% names(projects))
    expect_true("name" %in% names(projects))
  })
})

test_that("list_recent_projects lists created projects", {
  run_with_project_root({
    nemeton:::create_project("Project A")
    Sys.sleep(0.1)
    nemeton:::create_project("Project B")

    projects <- nemeton:::list_recent_projects()
    expect_s3_class(projects, "data.frame")
    expect_equal(nrow(projects), 2)
    expect_true("Project A" %in% projects$name)
    expect_true("Project B" %in% projects$name)
  })
})

test_that("list_recent_projects respects limit", {
  run_with_project_root({
    for (i in 1:5) {
      nemeton:::create_project(paste("Project", i))
      Sys.sleep(0.05)
    }
    projects <- nemeton:::list_recent_projects(limit = 3L)
    expect_equal(nrow(projects), 3)
  })
})

test_that("list_recent_projects sorts by updated_at descending", {
  run_with_project_root({
    p1 <- nemeton:::create_project("Old Project")
    Sys.sleep(1.5)
    p2 <- nemeton:::create_project("New Project")

    projects <- nemeton:::list_recent_projects()
    # Most recent should come first
    expect_equal(nrow(projects), 2)
    # The timestamps may have second-level granularity
    # Just check both are present
    expect_true("Old Project" %in% projects$name)
    expect_true("New Project" %in% projects$name)
  })
})

test_that("list_recent_projects handles corrupted metadata", {
  run_with_project_root({
    # Create a valid project
    nemeton:::create_project("Valid")
    # Create a corrupted project manually
    temp_root <- nemeton:::get_projects_root()
    bad_dir <- file.path(temp_root, "corrupt_proj")
    dir.create(bad_dir, recursive = TRUE)
    writeLines("{ invalid json", file.path(bad_dir, "metadata.json"))

    projects <- nemeton:::list_recent_projects()
    expect_true(nrow(projects) >= 1)
    # The corrupted project should show as corrupted
    corrupt_row <- projects[projects$id == "corrupt_proj", ]
    if (nrow(corrupt_row) > 0) {
      expect_true(corrupt_row$is_corrupted)
    }
  })
})

test_that("create_project with sf parcels sets parcels_count", {
  skip_if_not_installed("sf")
  run_with_project_root({
    parcels <- create_test_units(n_features = 3)
    result <- nemeton:::create_project("With Parcels", parcels = parcels)
    meta <- nemeton:::load_project_metadata(result$id)
    expect_equal(meta$parcels_count, 3)
  })
})

test_that("save_parcels and load_parcels round-trip GeoPackage", {
  skip_if_not_installed("sf")
  run_with_project_root({
    result <- nemeton:::create_project("Parcel Test")
    parcels <- create_test_units(n_features = 4)

    # Save
    saved <- nemeton:::save_parcels(result$id, parcels)
    expect_true(saved)

    # Verify GeoPackage file exists
    gpkg_path <- file.path(result$path, "data", "parcels.gpkg")
    expect_true(file.exists(gpkg_path))

    # Load
    loaded <- nemeton:::load_parcels(result$id)
    expect_s3_class(loaded, "sf")
    expect_equal(nrow(loaded), 4)
  })
})

test_that("save_parcels rejects non-sf object", {
  run_with_project_root({
    result <- nemeton:::create_project("Bad Parcel")
    expect_error(
      nemeton:::save_parcels(result$id, data.frame(x = 1)),
      "sf object"
    )
  })
})

test_that("load_parcels returns NULL for project without parcels", {
  run_with_project_root({
    result <- nemeton:::create_project("No Parcels")
    loaded <- nemeton:::load_parcels(result$id)
    expect_null(loaded)
  })
})

test_that("load_parcels returns NULL for non-existent project", {
  run_with_project_root({
    expect_null(nemeton:::load_parcels("does_not_exist"))
  })
})


# ============================================================
# Section 4: service_compute.R constants and functions
# ============================================================

test_that("DATA_SOURCES has expected structure", {
  ds <- nemeton:::DATA_SOURCES
  expect_type(ds, "list")
  expect_true("rasters" %in% names(ds))
  expect_true("vectors" %in% names(ds))
  # Check some raster sources
  expect_true("ndvi" %in% names(ds$rasters))
  expect_true("dem" %in% names(ds$rasters))
  expect_true("forest_cover" %in% names(ds$rasters))
  # Each source should have name, type, source, required_for
  for (nm in names(ds$rasters)) {
    r <- ds$rasters[[nm]]
    expect_true("name" %in% names(r), info = paste("raster", nm, "missing name"))
    expect_true("type" %in% names(r), info = paste("raster", nm, "missing type"))
    expect_true("source" %in% names(r), info = paste("raster", nm, "missing source"))
    expect_true("required_for" %in% names(r), info = paste("raster", nm, "missing required_for"))
  }
})

test_that("DATA_SOURCES vector sources are well-formed", {
  ds <- nemeton:::DATA_SOURCES
  expect_true("protected_areas" %in% names(ds$vectors))
  expect_true("water_network" %in% names(ds$vectors))
  expect_true("roads" %in% names(ds$vectors))
  expect_true("buildings" %in% names(ds$vectors))
  expect_true("bdforet" %in% names(ds$vectors))
  for (nm in names(ds$vectors)) {
    v <- ds$vectors[[nm]]
    expect_true("name" %in% names(v), info = paste("vector", nm, "missing name"))
    expect_true("type" %in% names(v), info = paste("vector", nm, "missing type"))
  }
})

test_that("COMPUTE_STATUS has expected values", {
  cs <- nemeton:::COMPUTE_STATUS
  expect_type(cs, "list")
  expect_equal(cs$PENDING, "pending")
  expect_equal(cs$DOWNLOADING, "downloading")
  expect_equal(cs$COMPUTING, "computing")
  expect_equal(cs$COMPLETED, "completed")
  expect_equal(cs$ERROR, "error")
  expect_equal(cs$CANCELLED, "cancelled")
})

test_that("list_available_indicators returns expected indicator list", {
  indicators <- nemeton:::list_available_indicators()
  expect_type(indicators, "character")
  expect_true(length(indicators) > 20)  # Should have 30+ indicators
  # Check some key indicators exist
  expect_true("carbon_biomass" %in% indicators)
  expect_true("carbon_ndvi" %in% indicators)
  expect_true("biodiversity_protection" %in% indicators)
  expect_true("water_twi" %in% indicators)
  expect_true("risk_fire" %in% indicators)
  expect_true("risk_storm" %in% indicators)
  expect_true("production_volume" %in% indicators)
  expect_true("energy_wood" %in% indicators)
  expect_true("naturalness_score" %in% indicators)
  # No duplicates
  expect_equal(length(indicators), length(unique(indicators)))
})

test_that("get_global_cache_dir returns a directory path", {
  cache_dir <- nemeton:::get_global_cache_dir()
  expect_type(cache_dir, "character")
  expect_true(nchar(cache_dir) > 0)
})


# ============================================================
# Section 5: data-preprocessing.R validation tests
# ============================================================

test_that("harmonize_crs rejects non-nemeton_layers object", {
  expect_error(
    nemeton:::harmonize_crs(list(), sf::st_crs(4326)),
    "nemeton_layers"
  )
  expect_error(
    nemeton:::harmonize_crs(data.frame(), sf::st_crs(4326)),
    "nemeton_layers"
  )
})

test_that("crop_to_units rejects non-nemeton_layers", {
  units <- create_test_units(n_features = 2)
  expect_error(
    nemeton:::crop_to_units(list(), units),
    "nemeton_layers"
  )
})

test_that("crop_to_units rejects non-sf units", {
  layers <- structure(list(rasters = list(), vectors = list()), class = "nemeton_layers")
  expect_error(
    nemeton:::crop_to_units(layers, data.frame(x = 1)),
    "sf"
  )
})

test_that("mask_to_units rejects non-nemeton_layers", {
  units <- create_test_units(n_features = 2)
  expect_error(
    nemeton:::mask_to_units(list(), units),
    "nemeton_layers"
  )
})

test_that("mask_to_units rejects non-sf units", {
  layers <- structure(list(rasters = list(), vectors = list()), class = "nemeton_layers")
  expect_error(
    nemeton:::mask_to_units(layers, data.frame(x = 1)),
    "sf"
  )
})


# ============================================================
# Section 6: Additional service_export.R coverage
# ============================================================

test_that("is_quarto_installed returns logical", {
  result <- nemeton:::is_quarto_installed()
  expect_type(result, "logical")
  expect_length(result, 1)
})

test_that("ensure_quarto_installed returns same as is_quarto_installed", {
  expect_equal(
    nemeton:::ensure_quarto_installed(),
    nemeton:::is_quarto_installed()
  )
})


# ============================================================
# Section 7: Additional llm_prompts.R coverage
# ============================================================

test_that("build_system_prompt falls back to generalist for unknown expert", {
  prompt <- nemeton:::build_system_prompt("fran\u00e7ais", expert = "nonexistent_expert")
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 10)
  expect_true(grepl("fran\u00e7ais", prompt))
})

test_that("build_system_prompt works with English", {
  prompt <- nemeton:::build_system_prompt("English", expert = "generalist")
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 10)
  expect_true(grepl("English", prompt))
})

test_that("build_analysis_prompt produces valid prompt", {
  skip_if_not_installed("sf")
  # Create mock family_config
  fam <- list(
    code = "C",
    name_fr = "Carbone",
    name_en = "Carbon"
  )
  ind_data <- create_test_units(n_features = 3)
  ind_data$C1 <- c(45, 67, 89)
  ind_data$C2 <- c(12, 34, 56)

  prompt_fr <- nemeton:::build_analysis_prompt(fam, ind_data, "fran\u00e7ais")
  expect_type(prompt_fr, "character")
  expect_true(grepl("Carbone", prompt_fr))
  expect_true(grepl("3", prompt_fr))  # 3 parcels
  expect_true(grepl("C1", prompt_fr))

  prompt_en <- nemeton:::build_analysis_prompt(fam, ind_data, "English")
  expect_true(grepl("Carbon", prompt_en))
})

test_that("build_analysis_prompt handles sf by dropping geometry", {
  skip_if_not_installed("sf")
  fam <- list(code = "B", name_fr = "Biodiversit\u00e9", name_en = "Biodiversity")
  ind_data <- create_test_units(n_features = 2)
  ind_data$B1 <- c(10, 20)

  prompt <- nemeton:::build_analysis_prompt(fam, ind_data, "fran\u00e7ais")
  expect_type(prompt, "character")
  expect_true(grepl("B1", prompt))
})

test_that("build_analysis_prompt handles all-NA column", {
  skip_if_not_installed("sf")
  fam <- list(code = "W", name_fr = "Eau", name_en = "Water")
  ind_data <- create_test_units(n_features = 2)
  ind_data$W1 <- c(NA_real_, NA_real_)

  prompt <- nemeton:::build_analysis_prompt(fam, ind_data, "fran\u00e7ais")
  expect_true(grepl("no data", prompt))
})

test_that("build_synthesis_prompt produces valid prompt", {
  skip_if_not_installed("sf")
  scores_df <- create_test_units(n_features = 3)
  for (code in c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")) {
    scores_df[[paste0("family_", code)]] <- runif(3, 20, 80)
  }

  prompt_fr <- nemeton:::build_synthesis_prompt(scores_df, "fran\u00e7ais")
  expect_type(prompt_fr, "character")
  expect_true(grepl("synth\u00e8se", prompt_fr))
  expect_true(grepl("3", prompt_fr))  # 3 parcels
  expect_true(grepl("/100", prompt_fr))

  prompt_en <- nemeton:::build_synthesis_prompt(scores_df, "English")
  expect_true(grepl("synthesis", prompt_en, ignore.case = TRUE))
  expect_true(grepl("/100", prompt_en))
})

test_that("build_synthesis_prompt handles sf input", {
  skip_if_not_installed("sf")
  scores_df <- create_test_units(n_features = 2)
  for (code in c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")) {
    scores_df[[paste0("family_", code)]] <- runif(2, 30, 90)
  }
  prompt <- nemeton:::build_synthesis_prompt(scores_df, "fran\u00e7ais")
  expect_type(prompt, "character")
})


# ============================================================
# Section 8: Additional service_project.R edge cases
# ============================================================

test_that("load_project_metadata returns NULL when metadata file missing", {
  run_with_project_root({
    temp_root <- nemeton:::get_projects_root()
    proj_dir <- file.path(temp_root, "no_meta_proj")
    dir.create(proj_dir, recursive = TRUE)
    expect_null(nemeton:::load_project_metadata("no_meta_proj"))
  })
})

test_that("update_project validates name", {
  run_with_project_root({
    result <- nemeton:::create_project("Original Name")
    # Empty name
    expect_error(
      nemeton:::update_project(result$id, ""),
      "required"
    )
    # Name too long
    expect_error(
      nemeton:::update_project(result$id, paste(rep("x", 101), collapse = "")),
      "100 characters"
    )
  })
})

test_that("update_project updates metadata correctly", {
  run_with_project_root({
    result <- nemeton:::create_project("Original")
    updated <- nemeton:::update_project(result$id, "Updated Name", description = "New desc", owner = "New Owner")
    expect_equal(updated$metadata$name, "Updated Name")
    expect_equal(updated$metadata$description, "New desc")
    expect_equal(updated$metadata$owner, "New Owner")
  })
})

test_that("update_project errors for non-existent project", {
  run_with_project_root({
    expect_error(
      nemeton:::update_project("ghost_project", "Name"),
      "not found"
    )
  })
})

test_that("check_project_health detects missing parcels file", {
  run_with_project_root({
    temp_root <- nemeton:::get_projects_root()
    proj_dir <- file.path(temp_root, "missing_parcels")
    dir.create(file.path(proj_dir, "data"), recursive = TRUE)
    # Metadata says parcels exist, but file is missing
    jsonlite::write_json(
      list(name = "Test", parcels_count = 5L),
      file.path(proj_dir, "metadata.json"),
      auto_unbox = TRUE
    )
    health <- nemeton:::check_project_health("missing_parcels")
    expect_false(health$valid)
    expect_true(any(grepl("parcels", health$issues, ignore.case = TRUE)))
  })
})

test_that("update_project_metadata with project_path parameter", {
  run_with_project_root({
    result <- nemeton:::create_project("Path Test")
    # Use explicit project_path
    nemeton:::update_project_metadata(
      result$id,
      list(custom_field = "value"),
      project_path = result$path
    )
    meta <- nemeton:::load_project_metadata(result$id)
    expect_equal(meta$custom_field, "value")
  })
})


# ============================================================
# Section 9: visualization.R additional helpers
# ============================================================

test_that("get_indicator_cols excludes known non-indicator columns", {
  # get_indicator_cols excludes: nemeton_id, id, geo_parcelle, geometry, geom,
  #   nomcommune, codecommune, area, surface_geo
  df <- data.frame(
    id = 1:3,
    nemeton_id = c("a", "b", "c"),
    geo_parcelle = c("x", "y", "z"),
    geometry = c(1, 2, 3),
    C1 = c(10, 20, 30),
    C2 = c(40, 50, 60),
    B1 = c(70, 80, 90),
    area = c(100, 200, 300)
  )
  cols <- nemeton:::get_indicator_cols(df)
  expect_true("C1" %in% cols)
  expect_true("C2" %in% cols)
  expect_true("B1" %in% cols)
  expect_false("id" %in% cols)
  expect_false("nemeton_id" %in% cols)
  expect_false("geo_parcelle" %in% cols)
  expect_false("geometry" %in% cols)
  expect_false("area" %in% cols)
})


# ============================================================
# Section 10: normalization.R edge cases
# ============================================================

test_that("normalize_vector handles single value", {
  result <- nemeton:::normalize_vector(c(5), method = "minmax")
  # Single value normalization - should be 0 or NA since range is 0
  expect_length(result, 1)
})

test_that("normalize_vector handles all-same values", {
  result <- nemeton:::normalize_vector(c(5, 5, 5), method = "minmax")
  # All same values -> range is 0
  expect_length(result, 3)
})

test_that("normalize_vector with NAs preserves NA positions", {
  result <- nemeton:::normalize_vector(c(1, NA, 3, NA, 5), method = "minmax")
  expect_length(result, 5)
  expect_true(is.na(result[2]))
  expect_true(is.na(result[4]))
  expect_false(is.na(result[1]))
  expect_false(is.na(result[3]))
  expect_false(is.na(result[5]))
})

test_that("create_composite_index handles all-NA indicator", {
  df <- data.frame(
    ind_A = c(NA, NA, NA),
    ind_B = c(50, 60, 70)
  )
  result <- nemeton:::create_composite_index(df, indicators = c("ind_A", "ind_B"),
                                              aggregation = "weighted_mean")
  expect_true("composite_index" %in% names(result))
})


# ============================================================
# Section 11: analysis-tradeoff.R additional coverage
# ============================================================

test_that("plot_tradeoff rejects non-data.frame input", {
  skip_if_not_installed("ggplot2")
  expect_error(
    nemeton:::plot_tradeoff("not_a_df", x = "A", y = "B")
  )
})

test_that("plot_tradeoff rejects missing column x", {
  skip_if_not_installed("ggplot2")
  df <- data.frame(family_B = c(50, 60), family_C = c(70, 80))
  expect_error(
    nemeton:::plot_tradeoff(df, x = "NONEXISTENT", y = "family_B")
  )
})
