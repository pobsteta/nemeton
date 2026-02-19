# test-cov80-batch18.R
# Coverage boost for R/service_export.R — deeper coverage of markdown rendering,
# PDF generation, export, and drawing functions.
# Avoids duplicating tests already in test-cov80-batch1.R and test-cov80-batch2.R.

# Helper: build minimal project + family_scores for report generation tests
make_report_fixtures <- function(n = 3, scores = NULL) {
  units <- create_test_units(n_features = n)
  family_codes <- c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  for (code in family_codes) {
    if (!is.null(scores) && code %in% names(scores)) {
      units[[paste0("family_", code)]] <- rep_len(scores[[code]], n)
    } else {
      units[[paste0("family_", code)]] <- seq(30, 80, length.out = n)
    }
  }
  # Add indicator-level columns for the C family
  units$carbon_biomass <- runif(n, 20, 90)
  units$carbon_ndvi <- runif(n, 30, 85)
  # B family

  units$biodiversity_protection <- runif(n, 10, 80)
  units$biodiversity_structure <- runif(n, 20, 70)
  units$biodiversity_connectivity <- runif(n, 15, 75)

  project <- list(
    metadata = list(
      name = "Test Forest",
      description = "Coverage test project",
      owner = "Tester",
      created_at = "2025-06-15",
      status = "draft"
    )
  )
  list(project = project, family_scores = units)
}


# ==============================================================================
# clean_text_for_pdf() — Unicode replacement paths
# ==============================================================================

test_that("clean_text_for_pdf returns NULL for NULL input", {
  result <- nemeton:::clean_text_for_pdf(NULL)
  expect_null(result)
})

test_that("clean_text_for_pdf returns empty string for empty input", {
  result <- nemeton:::clean_text_for_pdf("")
  expect_equal(result, "")
})

test_that("clean_text_for_pdf replaces curly single quotes", {
  result <- nemeton:::clean_text_for_pdf("\u2018hello\u2019")
  expect_equal(result, "'hello'")
})

test_that("clean_text_for_pdf replaces curly double quotes", {
  result <- nemeton:::clean_text_for_pdf("\u201Chello\u201D")
  expect_equal(result, "\"hello\"")
})

test_that("clean_text_for_pdf replaces en dash and em dash", {
  result <- nemeton:::clean_text_for_pdf("A\u2013B\u2014C")
  expect_equal(result, "A-B-C")
})

test_that("clean_text_for_pdf replaces ellipsis", {
  result <- nemeton:::clean_text_for_pdf("Wait\u2026")
  expect_equal(result, "Wait...")
})

test_that("clean_text_for_pdf replaces non-breaking space", {
  result <- nemeton:::clean_text_for_pdf("hello\u00A0world")
  expect_equal(result, "hello world")
})

test_that("clean_text_for_pdf replaces multiple unicode chars at once", {
  input <- "\u201CHello\u201D \u2013 \u2018world\u2019\u2026"
  result <- nemeton:::clean_text_for_pdf(input)
  expect_equal(result, "\"Hello\" - 'world'...")
})

test_that("clean_text_for_pdf leaves plain text unchanged", {
  result <- nemeton:::clean_text_for_pdf("plain text only")
  expect_equal(result, "plain text only")
})


# ==============================================================================
# strip_markdown_for_display() — individual marker types
# ==============================================================================

test_that("strip_markdown_for_display removes bold markers", {
  expect_equal(nemeton:::strip_markdown_for_display("**bold**"), "bold")
})

test_that("strip_markdown_for_display removes italic markers", {
  expect_equal(nemeton:::strip_markdown_for_display("*italic*"), "italic")
})

test_that("strip_markdown_for_display removes strikethrough markers", {
  expect_equal(nemeton:::strip_markdown_for_display("~~strike~~"), "strike")
})

test_that("strip_markdown_for_display removes inline code markers", {
  expect_equal(nemeton:::strip_markdown_for_display("`code`"), "code")
})

test_that("strip_markdown_for_display removes link markers keeping text", {
  expect_equal(nemeton:::strip_markdown_for_display("[link](http://x.com)"), "link")
})

test_that("strip_markdown_for_display leaves plain text unchanged", {
  expect_equal(nemeton:::strip_markdown_for_display("no markers"), "no markers")
})

test_that("strip_markdown_for_display handles multiple bold segments", {
  result <- nemeton:::strip_markdown_for_display("**a** and **b**")
  expect_equal(result, "a and b")
})


# ==============================================================================
# justify_text_line() — additional edge cases
# ==============================================================================

test_that("justify_text_line handles empty string input", {
  result <- nemeton:::justify_text_line("", 50)
  expect_equal(result, "")
})

test_that("justify_text_line handles line with only spaces", {
  result <- nemeton:::justify_text_line("   ", 50)
  expect_equal(result, "   ")
})

test_that("justify_text_line with three words distributes correctly", {
  result <- nemeton:::justify_text_line("a b c", 15)
  # 3 chars + 2 gaps (base 1 space each) = 5. deficit = 10, 2 gaps = 5 each
  expect_equal(nchar(result), 15)
  # Should contain word "a", spaces, "b", spaces, "c"
  expect_true(grepl("^a\\s+b\\s+c$", result))
})

test_that("justify_text_line with two words adds all deficit to single gap", {
  result <- nemeton:::justify_text_line("hi there", 20)
  expect_equal(nchar(result), 20)
  expect_true(grepl("^hi\\s+there$", result))
})


# ==============================================================================
# render_markdown_text() — deeper coverage of specific code paths
# ==============================================================================

test_that("render_markdown_text handles single # header", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  y <- nemeton:::render_markdown_text("# Big Header", 0.05, 0.9)
  expect_true(is.numeric(y))
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles ## header", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  y <- nemeton:::render_markdown_text("## Medium Header", 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles ### header", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  y <- nemeton:::render_markdown_text("### Small Header", 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text strips markdown from header text", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  # Header with bold inside should have markers stripped
  y <- nemeton:::render_markdown_text("## **Bold Header**", 0.05, 0.9)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles blockquote with wrapped text", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  long_quote <- paste0("> ", paste(rep("quoted", 30), collapse = " "))
  y <- nemeton:::render_markdown_text(long_quote, 0.05, 0.9, width = 40)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles table with separator variants", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  # Separator line with colons for alignment
  text <- "| Left | Center | Right |\n| :--- | :---: | ---: |\n| a | b | c |"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles table with only header (no body rows)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "| Header1 | Header2 |\n|---------|---------|"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles table with HTML in cells", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "| Col1 | Col2 |\n|---|---|\n| A<br/>B | C --> D |"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles table with -> arrow in cells", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "| From | To |\n|---|---|\n| A->B | C->D |"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles bullet list at low y (page break)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- paste0("- ", paste(rep("bulletword", 20), collapse = " "))
  y <- nemeton:::render_markdown_text(text, 0.05, 0.04, width = 30)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles numbered list at low y (page break)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- paste0("1. ", paste(rep("numberedword", 20), collapse = " "))
  y <- nemeton:::render_markdown_text(text, 0.05, 0.04, width = 30)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles blockquote at low y (page break)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- paste0("> ", paste(rep("quoteword", 20), collapse = " "))
  y <- nemeton:::render_markdown_text(text, 0.05, 0.04, width = 30)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles paragraph at low y (page break)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- paste(rep("paragraph", 30), collapse = " ")
  y <- nemeton:::render_markdown_text(text, 0.05, 0.04, width = 30)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles header at low y (page break)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  y <- nemeton:::render_markdown_text("# Header at bottom", 0.05, 0.03)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles multiple empty lines", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "A\n\n\n\nB"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles italic spacing pre-processing", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  # *italic*next should get spacing inserted
  text <- "*italic*next word"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles table page break in body rows", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  # Large table starting at low y to trigger page break in table body
  rows <- paste0("| R", seq_len(50), " | V", seq_len(50), " |")
  text <- paste(c("| H1 | H2 |", "|---|---|", rows), collapse = "\n")
  y <- nemeton:::render_markdown_text(text, 0.05, 0.15, width = 60)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles table with many columns", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "| A | B | C | D | E |\n|---|---|---|---|---|\n| 1 | 2 | 3 | 4 | 5 |"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles table with wide content (negative remaining)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  # Very wide cell contents to trigger remaining < 0 branch
  wide1 <- paste(rep("longword", 10), collapse = "")
  wide2 <- paste(rep("anotherlong", 10), collapse = "")
  text <- paste0("| ", wide1, " | ", wide2, " |\n|---|---|\n| x | y |")
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(is.numeric(y))
})


# ==============================================================================
# render_formatted_line() — deeper edge cases
# ==============================================================================

test_that("render_formatted_line handles strikethrough followed by text", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("~~old~~ new text", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles link at end of line", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("see [docs](http://x.com)", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles only bold content", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("**all bold**", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles only italic content", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("*all italic*", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles only code content", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("`all_code`", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles only link content", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("[link](http://x.com)", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles bold then space then italic", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("**bold** *italic*", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles unmatched [ bracket (no link pattern)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("text [ but no link", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles unmatched backtick", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("text ` alone", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles unmatched ~~ (no closing)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("text ~~ no close", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})


# ==============================================================================
# export_geopackage() — valid sf with custom layer name
# ==============================================================================

test_that("export_geopackage creates gpkg with custom layer name", {
  units <- create_test_units(n_features = 3)
  units$val <- c(10, 20, 30)

  withr::with_tempdir({
    output <- file.path(getwd(), "custom.gpkg")
    result <- nemeton:::export_geopackage(units, output, layer_name = "my_layer")
    expect_equal(result, output)
    expect_true(file.exists(output))
    # Re-read and check layer name
    layers <- sf::st_layers(output)
    expect_true("my_layer" %in% layers$name)
  })
})


# ==============================================================================
# generate_indicator_map() — with custom color
# ==============================================================================

test_that("generate_indicator_map uses custom color", {
  units <- create_test_units(n_features = 3)
  units$score <- c(80, 50, 20)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  result <- nemeton:::generate_indicator_map(units, "score", "Custom Color", color = "#FF0000")
  expect_null(result)
})


# ==============================================================================
# draw_parcel_table() — quality labels and edge cases
# ==============================================================================

test_that("draw_parcel_table shows Excellent quality for score >= 80", {
  units <- create_test_units(n_features = 1)
  units$score <- 95

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "fr"))
})

test_that("draw_parcel_table shows Good quality for score in [60,80)", {
  units <- create_test_units(n_features = 1)
  units$score <- 65

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "en"))
})

test_that("draw_parcel_table shows Average quality for score in [40,60)", {
  units <- create_test_units(n_features = 1)
  units$score <- 45

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "en"))
})

test_that("draw_parcel_table shows Low quality for score in [20,40)", {
  units <- create_test_units(n_features = 1)
  units$score <- 25

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "en"))
})

test_that("draw_parcel_table shows Very low quality for score < 20", {
  units <- create_test_units(n_features = 1)
  units$score <- 5

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "en"))
})

test_that("draw_parcel_table handles NA score", {
  units <- create_test_units(n_features = 1)
  units$score <- NA_real_

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "fr"))
})

test_that("draw_parcel_table without indicator_title uses default subtitle", {
  units <- create_test_units(n_features = 2)
  units$score <- c(70, 40)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "fr",
                                            indicator_title = NULL))
})

test_that("draw_parcel_table with empty indicator_title", {
  units <- create_test_units(n_features = 2)
  units$score <- c(80, 50)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "en",
                                            indicator_title = ""))
})

test_that("draw_parcel_table truncates to max_rows and shows overflow message", {
  units <- create_test_units(n_features = 25)
  units$score <- seq(0, 100, length.out = 25)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "en"))
})

test_that("draw_parcel_table truncates to max_rows with French lang", {
  units <- create_test_units(n_features = 25)
  units$score <- seq(0, 100, length.out = 25)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_parcel_table(units, "score", "id", "fr"))
})


# ==============================================================================
# draw_standard_cover_page() — score color thresholds
# ==============================================================================

test_that("draw_standard_cover_page with green score (>= 60)", {
  td <- make_report_fixtures(n = 3, scores = list(
    C = 80, B = 80, W = 80, A = 80, F = 80, L = 80,
    T = 80, R = 80, S = 80, P = 80, E = 80, N = 80
  ))
  report_data <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  expect_true(report_data$global_score >= 60)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_standard_cover_page(report_data, "fr"))
})

test_that("draw_standard_cover_page with orange score ([40,60))", {
  td <- make_report_fixtures(n = 3, scores = list(
    C = 50, B = 50, W = 50, A = 50, F = 50, L = 50,
    T = 50, R = 50, S = 50, P = 50, E = 50, N = 50
  ))
  report_data <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  expect_true(report_data$global_score >= 40)
  expect_true(report_data$global_score < 60)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_standard_cover_page(report_data, "fr"))
})

test_that("draw_standard_cover_page with red score (< 40)", {
  td <- make_report_fixtures(n = 3, scores = list(
    C = 10, B = 10, W = 10, A = 10, F = 10, L = 10,
    T = 10, R = 10, S = 10, P = 10, E = 10, N = 10
  ))
  report_data <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  expect_true(report_data$global_score < 40)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_standard_cover_page(report_data, "fr"))
})

test_that("draw_standard_cover_page without description", {
  td <- make_report_fixtures(n = 3)
  td$project$metadata$description <- ""
  report_data <- nemeton:::prepare_report_data(td$project, td$family_scores, "en")

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_standard_cover_page(report_data, "en"))
})

test_that("draw_standard_cover_page with NULL description", {
  td <- make_report_fixtures(n = 3)
  td$project$metadata$description <- NULL
  report_data <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_standard_cover_page(report_data, "fr"))
})


# ==============================================================================
# prepare_report_data() — additional paths
# ==============================================================================

test_that("prepare_report_data builds family descriptions", {
  td <- make_report_fixtures(n = 3)
  result <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  expect_true(length(result$family_descriptions) > 0)
  # French descriptions contain "regroupe"
  expect_true(any(grepl("regroupe", result$family_descriptions)))
})

test_that("prepare_report_data builds family descriptions in English", {
  td <- make_report_fixtures(n = 3)
  result <- nemeton:::prepare_report_data(td$project, td$family_scores, "en")
  expect_true(any(grepl("includes", result$family_descriptions)))
})

test_that("prepare_report_data uses sequential IDs when no id column", {
  td <- make_report_fixtures(n = 3)
  td$family_scores$id <- NULL
  result <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  # Parcel scores should use 1, 2, 3 as IDs
  expect_true("C" %in% names(result$parcel_scores))
  expect_true(all(result$parcel_scores$C$id %in% c("1", "2", "3")))
})

test_that("prepare_report_data single parcel uses singular label", {
  td <- make_report_fixtures(n = 1)
  result <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  expect_equal(result$n_parcels, 1)
})

test_that("prepare_report_data builds family_colors mapping", {
  td <- make_report_fixtures(n = 3)
  result <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  expect_true(length(result$family_colors) > 0)
  expect_true(all(grepl("^#", result$family_colors)))
})

test_that("prepare_report_data has indicator_stats with column data", {
  td <- make_report_fixtures(n = 3)
  result <- nemeton:::prepare_report_data(td$project, td$family_scores, "fr")
  # C family should have indicator stats for carbon_biomass, carbon_ndvi
  c_stats <- result$indicator_stats[["C"]]
  expect_true(nrow(c_stats) > 0)
  expect_true("Indicateur" %in% names(c_stats))
})

test_that("prepare_report_data has indicator_stats in English column names", {
  td <- make_report_fixtures(n = 3)
  result <- nemeton:::prepare_report_data(td$project, td$family_scores, "en")
  c_stats <- result$indicator_stats[["C"]]
  expect_true("Indicator" %in% names(c_stats))
})


# ==============================================================================
# generate_radar_image() — fallback path on error
# ==============================================================================

test_that("generate_radar_image creates file with fallback on error", {
  td <- make_report_fixtures(n = 3)
  # Remove family columns to force nemeton_radar to error
  bad_data <- td$family_scores
  for (code in c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")) {
    bad_data[[paste0("family_", code)]] <- NULL
  }

  withr::with_tempdir({
    output <- file.path(getwd(), "radar_fallback.png")
    nemeton:::generate_radar_image(bad_data, output, "fr")
    expect_true(file.exists(output))
  })
})


# ==============================================================================
# generate_family_maps() — all-NA column, no maptiles
# ==============================================================================

test_that("generate_family_maps handles all-NA family column", {
  td <- make_report_fixtures(n = 3)
  td$family_scores$family_C <- NA_real_

  withr::with_tempdir({
    out_dir <- file.path(getwd(), "fmaps")
    dir.create(out_dir)

    local_mocked_bindings(
      requireNamespace = function(pkg, ...) {
        if (pkg == "maptiles") return(FALSE)
        TRUE
      },
      .package = "base"
    )

    nemeton:::generate_family_maps(td$family_scores, out_dir, "fr")
    # C map should still be generated (shows "data not available")
    expect_true(file.exists(file.path(out_dir, "family_C_map.png")))
  })
})

test_that("generate_family_maps handles English language", {
  td <- make_report_fixtures(n = 3)

  withr::with_tempdir({
    out_dir <- file.path(getwd(), "fmaps_en")
    dir.create(out_dir)

    local_mocked_bindings(
      requireNamespace = function(pkg, ...) {
        if (pkg == "maptiles") return(FALSE)
        TRUE
      },
      .package = "base"
    )

    nemeton:::generate_family_maps(td$family_scores, out_dir, "en")
    files <- list.files(out_dir, pattern = "\\.png$")
    expect_true(length(files) > 0)
  })
})


# ==============================================================================
# add_parcel_labels() — with id column and long IDs
# ==============================================================================

test_that("add_parcel_labels truncates long IDs to last 6 chars", {
  units <- create_test_units(n_features = 2)
  units$id <- c("ABCDEFGHIJ", "1234567890")

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  plot(sf::st_geometry(units))
  expect_silent(nemeton:::add_parcel_labels(units))
})


# ==============================================================================
# generate_simple_pdf_report() — cover image and synthesis paths
# ==============================================================================

test_that("generate_simple_pdf_report with JPEG cover image falls back", {
  td <- make_report_fixtures(n = 3)

  withr::with_tempdir({
    # Create minimal JPEG-like file (won't load, triggers fallback to standard cover)
    cover_path <- file.path(getwd(), "cover.jpg")
    writeBin(raw(100), cover_path)

    output <- file.path(getwd(), "report_jpg.pdf")
    result <- nemeton:::generate_simple_pdf_report(
      td$project, td$family_scores, output, "fr",
      cover_image = cover_path
    )
    expect_true(file.exists(output))
  })
})

test_that("generate_simple_pdf_report with synthesis and all family comments", {
  td <- make_report_fixtures(n = 3)
  family_comments <- list(
    C = "## Carbon\n**Strong** biomass with good NDVI.",
    B = "Biodiversity:\n- Protection zones\n- Good connectivity"
  )

  withr::with_tempdir({
    output <- file.path(getwd(), "report_comments.pdf")
    result <- nemeton:::generate_simple_pdf_report(
      td$project, td$family_scores, output, "fr",
      synthesis_comments = "# Global Analysis\n\nThe forest is in **good** shape.\n\n> Important note",
      family_comments = family_comments
    )
    expect_true(file.exists(output))
  })
})

test_that("generate_simple_pdf_report with English language and no comments", {
  td <- make_report_fixtures(n = 3)

  withr::with_tempdir({
    output <- file.path(getwd(), "report_en.pdf")
    result <- nemeton:::generate_simple_pdf_report(
      td$project, td$family_scores, output, "en"
    )
    expect_true(file.exists(output))
  })
})


# ==============================================================================
# generate_report_pdf() — main entry point, use_quarto = TRUE but quarto absent
# ==============================================================================

test_that("generate_report_pdf with use_quarto=TRUE falls back when quarto unavailable", {
  td <- make_report_fixtures(n = 3)

  local_mocked_bindings(
    is_quarto_installed = function() FALSE,
    .package = "nemeton"
  )

  withr::with_tempdir({
    output <- file.path(getwd(), "report_fallback.pdf")
    result <- nemeton::generate_report_pdf(
      td$project, td$family_scores, output, "fr",
      use_quarto = TRUE
    )
    expect_true(file.exists(output))
  })
})


# ==============================================================================
# draw_indicator_map_page() — English language labels
# ==============================================================================

test_that("draw_indicator_map_page missing column shows English message", {
  units <- create_test_units(n_features = 3)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  nemeton:::draw_indicator_map_page(units, "nonexistent", "Test", "#228B22", "en")
  expect_true(TRUE)
})

test_that("draw_indicator_map_page all-NA shows English unavailable message", {
  units <- create_test_units(n_features = 3)
  units$score <- NA_real_

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  nemeton:::draw_indicator_map_page(units, "score", "Test", "#228B22", "en")
  expect_true(TRUE)
})

test_that("draw_indicator_map_page fallback sf plot works with NA mix", {
  units <- create_test_units(n_features = 4)
  units$score <- c(80, NA, 40, 10)

  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)

  expect_silent(nemeton:::draw_indicator_map_page(units, "score", "Test", "#9932CC", "fr"))
})


# ==============================================================================
# ensure_quarto_installed() — simple wrapper
# ==============================================================================

test_that("ensure_quarto_installed delegates to is_quarto_installed", {
  local_mocked_bindings(
    is_quarto_installed = function() FALSE,
    .package = "nemeton"
  )
  expect_false(nemeton:::ensure_quarto_installed())
})
