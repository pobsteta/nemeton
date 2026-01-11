# Tests for Tutorial 01: Acquisition des Données
# Validates structure and content of inst/tutorials/01-acquisition/01-acquisition.Rmd

test_that("Tutorial 01 file exists", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  expect_true(file.exists(tutorial_path), info = "Tutorial 01 Rmd file should exist")
})

test_that("Tutorial 01 has valid YAML header", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- readLines(tutorial_path, warn = FALSE)

  # Check YAML delimiters
  yaml_starts <- which(content == "---")
  expect_gte(length(yaml_starts), 2, info = "Should have YAML header delimiters")

  # Check for learnr output
  yaml_content <- paste(content[yaml_starts[1]:yaml_starts[2]], collapse = "\n")
  expect_match(yaml_content, "learnr::tutorial", info = "Should use learnr output format")
})

test_that("Tutorial 01 contains required sections", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Required sections for acquisition tutorial
  required_sections <- c(
    "Introduction",
    "Zone.*étude|Emprise",
    "IGN|BD.*TOPO|Télécharg",
    "LiDAR|Nuage.*points",
    "Cache|Sauvegarde"
  )

  for (section in required_sections) {
    expect_match(content, section, ignore.case = TRUE,
                 info = paste("Should contain section:", section))
  }
})

test_that("Tutorial 01 contains exercise chunks", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for exercise chunks
  exercise_pattern <- "exercise\\s*=\\s*TRUE"
  exercises <- gregexpr(exercise_pattern, content)[[1]]
  n_exercises <- sum(exercises > 0)

  expect_gte(n_exercises, 3, info = "Should have at least 3 exercise chunks")
})

test_that("Tutorial 01 contains quiz sections", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for quiz
  expect_match(content, "quiz\\(", info = "Should contain at least one quiz")
  expect_match(content, "question\\(", info = "Should contain quiz questions")
})

test_that("Tutorial 01 uses sf package for spatial data", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Should use sf package
  expect_match(content, "library\\(sf\\)", info = "Should load sf package")
  expect_match(content, "st_read|st_write|st_bbox", info = "Should use sf functions")
})

test_that("Tutorial 01 covers zone of study definition", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Zone definition
  expect_match(content, "emprise|bbox|zone.*étude|périmètre", ignore.case = TRUE,
               info = "Should cover zone of study definition")
  expect_match(content, "CRS|EPSG|2154|Lambert", ignore.case = TRUE,
               info = "Should mention coordinate reference system")
})

test_that("Tutorial 01 covers data download", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Data download patterns
  expect_match(content, "télécharg|download|API|WFS", ignore.case = TRUE,
               info = "Should cover data download")
  expect_match(content, "IGN|BD.*TOPO|Forêt|LiDAR", ignore.case = TRUE,
               info = "Should mention IGN data sources")
})

test_that("Tutorial 01 sets up cache directory", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Cache directory setup
  expect_match(content, "cache_dir|rappdirs|user_data_dir", ignore.case = TRUE,
               info = "Should set up cache directory")
  expect_match(content, "nemeton.*tutorial|tutorial.*data", ignore.case = TRUE,
               info = "Should reference nemeton tutorial data location")
})

test_that("Tutorial 01 exports data for subsequent tutorials", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Data export
  expect_match(content, "st_write|\\.gpkg|GeoPackage", ignore.case = TRUE,
               info = "Should export data to GeoPackage")
  expect_match(content, "parcelles|units|zone", ignore.case = TRUE,
               info = "Should create parcels/units data")
})

test_that("Tutorial 01 is foundation for all other tutorials", {
  tutorial_path <- system.file("tutorials/01-acquisition/01-acquisition.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Foundation role
  expect_match(content, "tutoriel.*suivant|suite|T02|tutorial.*02", ignore.case = TRUE,
               info = "Should mention subsequent tutorials")
})
