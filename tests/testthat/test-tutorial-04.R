# Tests for Tutorial 04: Indicateurs Écologiques
# Validates structure and content of inst/tutorials/04-ecological/04-ecological.Rmd

test_that("Tutorial 04 file exists", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  expect_true(file.exists(tutorial_path), info = "Tutorial 04 Rmd file should exist")
})

test_that("Tutorial 04 has valid YAML header", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- readLines(tutorial_path, warn = FALSE)

  # Check YAML delimiters
  yaml_starts <- which(content == "---")
  expect_gte(length(yaml_starts), 2)

  # Check for learnr output
  yaml_content <- paste(content[yaml_starts[1]:yaml_starts[2]], collapse = "\n")
  expect_match(yaml_content, "learnr::tutorial", info = "Should use learnr output format")
})

test_that("Tutorial 04 contains required sections", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Required sections for ecological tutorial
  required_sections <- c(
    "Introduction|BD Forêt",
    "Biodiversité|Protection",
    "Paysage|Landscape",
    "Temporel|Ancienneté",
    "Naturalité"
  )

  for (section in required_sections) {
    expect_match(content, section, ignore.case = TRUE,
                 info = paste("Should contain section:", section))
  }
})

test_that("Tutorial 04 contains exercise chunks", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for exercise chunks
  exercise_pattern <- "exercise\\s*=\\s*TRUE"
  exercises <- gregexpr(exercise_pattern, content)[[1]]
  n_exercises <- sum(exercises > 0)

  expect_gte(n_exercises, 5)
})

test_that("Tutorial 04 contains quiz sections", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for quiz
  expect_match(content, "quiz\\(", info = "Should contain at least one quiz")
  expect_match(content, "question\\(", info = "Should contain quiz questions")
})

test_that("Tutorial 04 covers biodiversity indicators (B1-B3)", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Biodiversity family indicators
  expect_match(content, "B1|protection|INPN|zonage", ignore.case = TRUE,
               info = "Should cover B1 (protection zones)")
  expect_match(content, "B2|structure|diversité", ignore.case = TRUE,
               info = "Should cover B2 (structure diversity)")
  expect_match(content, "B3|connectivité|corridor", ignore.case = TRUE,
               info = "Should cover B3 (connectivity)")
})

test_that("Tutorial 04 covers landscape indicators (L1-L3)", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Landscape family indicators
  expect_match(content, "L1|lisière|edge", ignore.case = TRUE,
               info = "Should cover L1 (edge)")
  expect_match(content, "L2|fragmentation", ignore.case = TRUE,
               info = "Should cover L2 (fragmentation)")
  expect_match(content, "L3|TVB|Trame.*Verte", ignore.case = TRUE,
               info = "Should cover L3 (TVB)")
})

test_that("Tutorial 04 covers temporal indicators (T1-T2)", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Temporal family indicators
  expect_match(content, "T1|ancienneté|âge", ignore.case = TRUE,
               info = "Should cover T1 (forest age)")
  expect_match(content, "T2|changement|évolution", ignore.case = TRUE,
               info = "Should cover T2 (land use change)")
})

test_that("Tutorial 04 covers naturalness indicators (N1-N3)", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Naturalness family indicators
  expect_match(content, "N1|distance|infrastructure", ignore.case = TRUE,
               info = "Should cover N1 (distance to infrastructure)")
  expect_match(content, "N2|continuité|couverture", ignore.case = TRUE,
               info = "Should cover N2 (forest continuity)")
  expect_match(content, "N3|composite|naturalité", ignore.case = TRUE,
               info = "Should cover N3 (composite naturalness)")
})

test_that("Tutorial 04 references cache directory", {
  tutorial_path <- system.file("tutorials/04-ecological/04-ecological.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Should use nemeton cache pattern
  expect_match(content, "cache_dir|rappdirs",
               info = "Should reference cache directory for data")
})
