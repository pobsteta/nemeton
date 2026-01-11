# Tests for Tutorial 06: Analyse Multi-Critères et Export
# Validates structure and content of inst/tutorials/06-analysis/06-analysis.Rmd

test_that("Tutorial 06 file exists", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  expect_true(file.exists(tutorial_path), info = "Tutorial 06 Rmd file should exist")
})

test_that("Tutorial 06 has valid YAML header", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- readLines(tutorial_path, warn = FALSE)

  # Check YAML delimiters
  yaml_starts <- which(content == "---")
  expect_gte(length(yaml_starts), 2, info = "Should have YAML header delimiters")

  # Check for learnr output
  yaml_content <- paste(content[yaml_starts[1]:yaml_starts[2]], collapse = "\n")
  expect_match(yaml_content, "learnr::tutorial", info = "Should use learnr output format")
})

test_that("Tutorial 06 contains required sections", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Required sections for analysis tutorial
  required_sections <- c(
    "Carte|Map",
    "Radar",
    "Corrélation",
    "Hotspot",
    "Pareto|Compromis",
    "Cluster",
    "Export",
    "Leaflet|Interactive"
  )

  for (section in required_sections) {
    expect_match(content, section, ignore.case = TRUE,
                 info = paste("Should contain section:", section))
  }
})

test_that("Tutorial 06 contains exercise chunks", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for exercise chunks
  exercise_pattern <- "exercise\\s*=\\s*TRUE"
  exercises <- gregexpr(exercise_pattern, content)[[1]]
  n_exercises <- sum(exercises > 0)

  expect_gte(n_exercises, 10, info = "Should have at least 10 exercise chunks")
})

test_that("Tutorial 06 contains quiz sections", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for quiz
  expect_match(content, "quiz\\(", info = "Should contain at least one quiz")
  expect_match(content, "question\\(", info = "Should contain quiz questions")
})

test_that("Tutorial 06 covers thematic maps", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Map visualization
  expect_match(content, "ggplot|geom_sf", info = "Should use ggplot for maps")
  expect_match(content, "viridis|scale_fill", ignore.case = TRUE,
               info = "Should use color scales for maps")
})

test_that("Tutorial 06 covers radar charts", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Radar chart
  expect_match(content, "radar|fmsb", ignore.case = TRUE,
               info = "Should cover radar charts")
  expect_match(content, "radarchart", info = "Should use radarchart function")
})

test_that("Tutorial 06 covers correlation analysis", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Correlation analysis
  expect_match(content, "cor\\(|corrélation", ignore.case = TRUE,
               info = "Should cover correlation calculation")
  expect_match(content, "corrplot", info = "Should use corrplot for visualization")
  expect_match(content, "synergie|compromis", ignore.case = TRUE,
               info = "Should explain synergies and trade-offs")
})

test_that("Tutorial 06 covers hotspot identification", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Hotspot analysis
  expect_match(content, "hotspot", ignore.case = TRUE,
               info = "Should cover hotspot identification")
  expect_match(content, "quantile|percentile|P90|seuil", ignore.case = TRUE,
               info = "Should explain threshold selection")
})

test_that("Tutorial 06 covers Pareto analysis", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Pareto analysis
  expect_match(content, "Pareto|pareto", info = "Should cover Pareto front")
  expect_match(content, "dominé|optimal|front", ignore.case = TRUE,
               info = "Should explain Pareto optimality")
})

test_that("Tutorial 06 covers clustering", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Clustering
  expect_match(content, "cluster|hclust", ignore.case = TRUE,
               info = "Should cover clustering")
  expect_match(content, "dendrogramme|ward", ignore.case = TRUE,
               info = "Should explain hierarchical clustering")
})

test_that("Tutorial 06 covers GeoPackage export", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Export
  expect_match(content, "GeoPackage|\\.gpkg|st_write", ignore.case = TRUE,
               info = "Should cover GeoPackage export")
  expect_match(content, "CSV|write\\.csv", ignore.case = TRUE,
               info = "Should cover CSV export")
})

test_that("Tutorial 06 covers Leaflet interactive map", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Leaflet
  expect_match(content, "leaflet", ignore.case = TRUE,
               info = "Should cover Leaflet maps")
  expect_match(content, "addPolygons|addProviderTiles", ignore.case = TRUE,
               info = "Should use Leaflet functions")
})

test_that("Tutorial 06 contains analysis sections after exercises", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Analysis sections
  expect_match(content, "ANALYSE", info = "Should contain analysis sections")
  expect_match(content, "INTERPRÉTATION", info = "Should contain interpretation guidance")
})

test_that("Tutorial 06 references cache directory", {
  tutorial_path <- system.file("tutorials/06-analysis/06-analysis.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Should use nemeton cache pattern
  expect_match(content, "cache_dir|rappdirs",
               info = "Should reference cache directory for data")
})
