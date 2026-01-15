# Tests for Tutorial 07: LiDAR Avancé — LAScatalog, lasR et BABA
# Validates structure and content of inst/tutorials/07-lidar-advanced/07-lidar-advanced.Rmd

test_that("Tutorial 07 file exists", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  expect_true(file.exists(tutorial_path), info = "Tutorial 07 Rmd file should exist")
})

test_that("Tutorial 07 has valid YAML header", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- readLines(tutorial_path, warn = FALSE)

  # Check YAML delimiters
  yaml_starts <- which(content == "---")
  expect_gte(length(yaml_starts), 2)

  # Check for learnr output
  yaml_content <- paste(content[yaml_starts[1]:yaml_starts[2]], collapse = "\n")
  expect_match(yaml_content, "learnr::tutorial", info = "Should use learnr output format")
})

test_that("Tutorial 07 contains all 9 required sections", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Required sections for LiDAR advanced tutorial
  required_sections <- c(
    "LAScatalog",
    "lasR|Pipeline",
    "Segmentation|Arbres",
    "Trouées|Lisières",
    "Métriques|Structure",
    "BABA|Buffered",
    "Coregistration",
    "Dérivés|Export",
    "Quiz Final"
  )

  for (section in required_sections) {
    expect_match(content, section, ignore.case = TRUE,
                 info = paste("Should contain section:", section))
  }
})

test_that("Tutorial 07 contains exercise chunks", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for exercise chunks
  exercise_pattern <- "exercise\\s*=\\s*TRUE"
  exercises <- gregexpr(exercise_pattern, content)[[1]]
  n_exercises <- sum(exercises > 0)

  expect_gte(n_exercises, 10)
})

test_that("Tutorial 07 contains quiz sections", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Check for quiz
  expect_match(content, "quiz\\(", info = "Should contain at least one quiz")
  expect_match(content, "question\\(", info = "Should contain quiz questions")
})

test_that("Tutorial 07 covers LAScatalog concept", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # LAScatalog functions
  expect_match(content, "readLAScatalog", info = "Should use readLAScatalog function")
  expect_match(content, "chunk_size|buffer", ignore.case = TRUE,
               info = "Should explain chunk and buffer options")
})

test_that("Tutorial 07 covers lasR pipelines", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # lasR pipeline
  expect_match(content, "lasR", info = "Should mention lasR package")
  expect_match(content, "reader_las|rasterize|pipeline", ignore.case = TRUE,
               info = "Should cover lasR pipeline components")
})

test_that("Tutorial 07 covers tree segmentation", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Tree segmentation (lidaRtRee uses tree_segmentation, not lidR's segment_trees)
  expect_match(content, "tree_segmentation|segment_crowns|segment_trees", ignore.case = TRUE,
               info = "Should cover tree detection and segmentation")
  expect_match(content, "lmf|dalponte", ignore.case = TRUE,
               info = "Should mention segmentation algorithms")
})

test_that("Tutorial 07 covers gaps and edges", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Gaps and edges
  expect_match(content, "trouée|gap", ignore.case = TRUE,
               info = "Should cover forest gaps")
  expect_match(content, "lisière|edge", ignore.case = TRUE,
               info = "Should cover forest edges")
})

test_that("Tutorial 07 covers BABA approach", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # BABA
  expect_match(content, "BABA|Buffered Area-Based", ignore.case = TRUE,
               info = "Should cover BABA approach")
  expect_match(content, "res\\s*=\\s*c\\(10,\\s*20\\)|10m.*20m|fenêtre",
               ignore.case = TRUE,
               info = "Should explain BABA resolution concept")
})

test_that("Tutorial 07 covers coregistration", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Coregistration
  expect_match(content, "coregistration|coregistr", ignore.case = TRUE,
               info = "Should cover coregistration")
  expect_match(content, "placette|terrain|field", ignore.case = TRUE,
               info = "Should explain field plot alignment")
})

test_that("Tutorial 07 covers structure metrics", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Structure metrics
  expect_match(content, "zmax|zq95|zmean", ignore.case = TRUE,
               info = "Should cover height metrics")
  expect_match(content, "pzabove|couverture|couvert", ignore.case = TRUE,
               info = "Should cover canopy cover metrics")
  expect_match(content, "strat|vertical", ignore.case = TRUE,
               info = "Should cover vertical stratification")
})

test_that("Tutorial 07 links to nemeton indicators", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # nemeton indicators linkage
  expect_match(content, "C1|P1|B2|A1", info = "Should reference nemeton indicators")
  expect_match(content, "nemeton|indicateur", ignore.case = TRUE,
               info = "Should mention nemeton integration")
})

test_that("Tutorial 07 contains final quiz with 8 questions", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # Final quiz questions
  quiz_pattern <- "question\\("
  questions <- gregexpr(quiz_pattern, content)[[1]]
  n_questions <- sum(questions > 0)

  expect_gte(n_questions, 8)
})

test_that("Tutorial 07 mentions lidaRtRee package", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # lidaRtRee package
  expect_match(content, "lidaRtRee", info = "Should mention lidaRtRee package")
})

test_that("Tutorial 07 has appropriate length", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- readLines(tutorial_path, warn = FALSE)
  n_lines <- length(content)

  # Advanced tutorial should be substantial (at least 800 lines)
  expect_gte(n_lines, 800)
})

test_that("Tutorial 07 contains learnr quiz validation", {
  tutorial_path <- system.file("tutorials/07-lidar-advanced/07-lidar-advanced.Rmd", package = "nemeton")
  skip_if(tutorial_path == "", message = "Tutorial file not found")

  content <- paste(readLines(tutorial_path, warn = FALSE), collapse = "\n")

  # learnr quiz validation (uses quiz() and question(), not gradethis)
  expect_match(content, "quiz\\(|question\\(", ignore.case = TRUE,
               info = "Should contain learnr quiz validation")
})
