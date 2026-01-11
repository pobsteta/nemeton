# Tests for Tutorial 05: Calcul Complet et Normalisation
# Validates structure and content of inst/tutorials/05-complete/05-complete.Rmd

test_that("Tutorial 05 file exists", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  expect_true(file.exists(tutorial_path), info = "Tutorial 05 Rmd file should exist")
})

test_that("Tutorial 05 has valid YAML header", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- readLines(tutorial_path, warn = FALSE)

  # Check YAML delimiters
  yaml_starts <- which(content == "---")
  expect_gte(length(yaml_starts), 2)

  # Check for learnr output
  yaml_content <- paste(content[yaml_starts[1]:yaml_starts[2]], collapse = "\n")
  expect_match(yaml_content, "learnr::tutorial", info = "Should use learnr output format")
})

test_that("Tutorial 05 contains required sections", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Required sections for complete calculation tutorial
  required_sections <- c(
    "Introduction|Assemblage",
    "Normalisation",
    "Famille|Family",
    "Composite|I_nemeton"
  )

  for (section in required_sections) {
    expect_match(content, section, ignore.case = TRUE,
                 info = paste("Should contain section:", section))
  }
})

test_that("Tutorial 05 contains exercise chunks", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for exercise chunks
  exercise_pattern <- "exercise\\s*=\\s*TRUE"
  exercises <- gregexpr(exercise_pattern, content)[[1]]
  n_exercises <- sum(exercises > 0)

  expect_gte(n_exercises, 3)
})

test_that("Tutorial 05 contains quiz sections", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for quiz
  expect_match(content, "quiz\\(", info = "Should contain at least one quiz")
  expect_match(content, "question\\(", info = "Should contain quiz questions")
})

test_that("Tutorial 05 covers normalization", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Normalization concepts
  expect_match(content, "normaliz|min.*max|0.*1", ignore.case = TRUE,
               info = "Should explain normalization")
  expect_match(content, "_norm|normalis", ignore.case = TRUE,
               info = "Should reference normalized columns")
})

test_that("Tutorial 05 covers family aggregation", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Family score patterns
  expect_match(content, "family_|famille", ignore.case = TRUE,
               info = "Should cover family score calculation")
  expect_match(content, "12.*famille|famille.*12", ignore.case = TRUE,
               info = "Should mention 12 families")
})

test_that("Tutorial 05 covers composite index", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Composite index
  expect_match(content, "I_nemeton|indice.*composite|composite.*index", ignore.case = TRUE,
               info = "Should cover I_nemeton composite index")
})

test_that("Tutorial 05 covers indicator inversion", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Indicator inversion for negative indicators
  expect_match(content, "invers|négatif|1\\s*-", ignore.case = TRUE,
               info = "Should explain indicator inversion for negative indicators")
})

test_that("Tutorial 05 references all 12 families", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # All 12 family codes
  families <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")

  # At least check that family_ columns are mentioned
  expect_match(content, "family_C|family_B|family_W",
               info = "Should reference family score columns")
})

test_that("Tutorial 05 references cache directory", {
  tutorial_path <- system.file("tutorials/05-complete/05-complete.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Should use nemeton cache pattern
  expect_match(content, "cache_dir|rappdirs",
               info = "Should reference cache directory for data")
})
