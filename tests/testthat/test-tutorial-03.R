# Tests for Tutorial 03: Indicateurs Terrain
# Validates structure and content of inst/tutorials/03-terrain/03-terrain.Rmd

test_that("Tutorial 03 file exists", {
  tutorial_path <- system.file("tutorials/03-terrain/03-terrain.Rmd", package = "nemeton")
  expect_true(file.exists(tutorial_path), info = "Tutorial 03 Rmd file should exist")
})

test_that("Tutorial 03 has valid YAML header", {
  tutorial_path <- system.file("tutorials/03-terrain/03-terrain.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- readLines(tutorial_path, warn = FALSE)

  # Check YAML delimiters
  yaml_starts <- which(content == "---")
  expect_gte(length(yaml_starts), 2)

  # Check for learnr output
  yaml_content <- paste(content[yaml_starts[1]:yaml_starts[2]], collapse = "\n")
  expect_match(yaml_content, "learnr::tutorial", info = "Should use learnr output format")
})

test_that("Tutorial 03 contains required sections", {
  tutorial_path <- system.file("tutorials/03-terrain/03-terrain.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Required sections for terrain tutorial
  required_sections <- c(
    "Introduction|Topograph",
    "TWI|Humidité",
    "Hydro|Eau",
    "Risque",
    "Accessibilité|Social"
  )

  for (section in required_sections) {
    expect_match(content, section, ignore.case = TRUE,
                 info = paste("Should contain section:", section))
  }
})

test_that("Tutorial 03 contains exercise chunks", {
  tutorial_path <- system.file("tutorials/03-terrain/03-terrain.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for exercise chunks
  exercise_pattern <- "exercise\\s*=\\s*TRUE"
  exercises <- gregexpr(exercise_pattern, content)[[1]]
  n_exercises <- sum(exercises > 0)

  expect_gte(n_exercises, 5)
})

test_that("Tutorial 03 contains quiz sections", {
  tutorial_path <- system.file("tutorials/03-terrain/03-terrain.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for quiz
  expect_match(content, "quiz\\(", info = "Should contain at least one quiz")
  expect_match(content, "question\\(", info = "Should contain quiz questions")
})

test_that("Tutorial 03 covers water indicators (W1-W3)", {
  tutorial_path <- system.file("tutorials/03-terrain/03-terrain.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Water family indicators
  expect_match(content, "W1|TWI|topographique", ignore.case = TRUE,
               info = "Should cover W1 (TWI)")
  expect_match(content, "W2|hydrographique|cours.*eau", ignore.case = TRUE,
               info = "Should cover W2 (hydrographic network)")
  expect_match(content, "W3|humide|wetland", ignore.case = TRUE,
               info = "Should cover W3 (wetlands)")
})

test_that("Tutorial 03 covers risk indicators (R1-R4)", {
  tutorial_path <- system.file("tutorials/03-terrain/03-terrain.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Risk family indicators
  expect_match(content, "R1|incendie|feu", ignore.case = TRUE,
               info = "Should cover R1 (fire risk)")
  expect_match(content, "R2|tempête|vent", ignore.case = TRUE,
               info = "Should cover R2 (storm risk)")
  expect_match(content, "R3|sécheresse|drought", ignore.case = TRUE,
               info = "Should cover R3 (drought risk)")
  expect_match(content, "R4|gibier|abroutissement", ignore.case = TRUE,
               info = "Should cover R4 (game pressure)")
})

test_that("Tutorial 03 covers social indicators (S1-S3)", {
  tutorial_path <- system.file("tutorials/03-terrain/03-terrain.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Social family indicators
  expect_match(content, "S1|sentier|trail", ignore.case = TRUE,
               info = "Should cover S1 (trails)")
  expect_match(content, "S2|accessibilité|route", ignore.case = TRUE,
               info = "Should cover S2 (accessibility)")
  expect_match(content, "S3|proximité|population", ignore.case = TRUE,
               info = "Should cover S3 (proximity)")
})

test_that("Tutorial 03 references cache directory", {
  tutorial_path <- system.file("tutorials/03-terrain/03-terrain.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Should use nemeton cache pattern
  expect_match(content, "cache_dir|rappdirs",
               info = "Should reference cache directory for data")
})
