# Tests for Tutorial 02: Traitement LiDAR
# Validates structure and content of inst/tutorials/02-lidar/02-lidar.Rmd

test_that("Tutorial 02 file exists", {
  tutorial_path <- system.file("tutorials/02-lidar/02-lidar.Rmd", package = "nemeton")
  expect_true(file.exists(tutorial_path), info = "Tutorial 02 Rmd file should exist")
})

test_that("Tutorial 02 has valid YAML header", {
  tutorial_path <- system.file("tutorials/02-lidar/02-lidar.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- readLines(tutorial_path, warn = FALSE)

  # Check YAML delimiters
  yaml_starts <- which(content == "---")
  expect_gte(length(yaml_starts), 2, info = "Should have YAML header delimiters")

  # Check for learnr output
  yaml_content <- paste(content[yaml_starts[1]:yaml_starts[2]], collapse = "\n")
  expect_match(yaml_content, "learnr::tutorial", info = "Should use learnr output format")
})

test_that("Tutorial 02 contains required sections", {
  tutorial_path <- system.file("tutorials/02-lidar/02-lidar.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Required sections for LiDAR tutorial

  required_sections <- c(
    "Introduction",
    "Chargement",
    "Normalisation",
    "MNH|Canopy",
    "Métriques"
  )

  for (section in required_sections) {
    expect_match(content, section, ignore.case = TRUE,
                 info = paste("Should contain section:", section))
  }
})

test_that("Tutorial 02 contains exercise chunks", {
  tutorial_path <- system.file("tutorials/02-lidar/02-lidar.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")


  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for exercise chunks
  exercise_pattern <- "exercise\\s*=\\s*TRUE"
  exercises <- gregexpr(exercise_pattern, content)[[1]]
  n_exercises <- sum(exercises > 0)

  expect_gte(n_exercises, 5, info = "Should have at least 5 exercise chunks")
})

test_that("Tutorial 02 contains quiz sections", {
  tutorial_path <- system.file("tutorials/02-lidar/02-lidar.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for quiz
  expect_match(content, "quiz\\(", info = "Should contain at least one quiz")
  expect_match(content, "question\\(", info = "Should contain quiz questions")
})

test_that("Tutorial 02 uses correct packages", {
  tutorial_path <- system.file("tutorials/02-lidar/02-lidar.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Required packages for LiDAR processing
  required_packages <- c("lidR", "terra", "sf")

  for (pkg in required_packages) {
    expect_match(content, paste0("library\\(", pkg, "\\)"),
                 info = paste("Should load package:", pkg))
  }
})

test_that("Tutorial 02 references cache directory", {
  tutorial_path <- system.file("tutorials/02-lidar/02-lidar.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Should use nemeton cache pattern
  expect_match(content, "cache_dir|rappdirs",
               info = "Should reference cache directory for data")
})
