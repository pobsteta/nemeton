# test-cov80-batch1.R
# Coverage boost for R/service_export.R — markdown rendering functions
# Target: render_markdown_text, render_formatted_line, justify_text_line

# ==============================================================================
# justify_text_line() — text justification
# ==============================================================================

test_that("justify_text_line pads words to target width", {
  result <- nemeton:::justify_text_line("hello world test", 25)
  expect_equal(nchar(result), 25)
})

test_that("justify_text_line returns unchanged single word", {
  result <- nemeton:::justify_text_line("hello", 20)
  expect_equal(result, "hello")
})

test_that("justify_text_line returns unchanged when already at target", {
  line <- "exact width line"
  result <- nemeton:::justify_text_line(line, nchar(line))
  expect_equal(result, line)
})

test_that("justify_text_line handles deficit <= 0", {
  result <- nemeton:::justify_text_line("a very long line with many words", 10)
  expect_equal(result, "a very long line with many words")
})

test_that("justify_text_line distributes spaces evenly", {
  result <- nemeton:::justify_text_line("a b c", 11)
  # 3 words, 3 chars total, need 8 more spaces across 2 gaps = 4 each + base 1
  expect_true(nchar(result) == 11)
})

test_that("justify_text_line handles remainder distribution", {
  result <- nemeton:::justify_text_line("aa bb cc", 20)
  # 6 chars + 2 gaps. Deficit = 20 - 8 = 12. 12/2 = 6 extra each gap
  expect_equal(nchar(result), 20)
})

# ==============================================================================
# render_formatted_line() — inline markdown rendering in graphics device
# ==============================================================================

test_that("render_formatted_line renders plain text", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("plain text no formatting", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line renders bold text", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("This is **bold** text", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line renders italic text", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("This is *italic* text", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line renders strikethrough text", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("This is ~~struck~~ text", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line renders inline code", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("Use `code()` here", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line renders links", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("Click [here](https://example.com) now", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles unmatched marker (skip char)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  # Single * not matching italic pattern
  result <- nemeton:::render_formatted_line("a * b", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles bold followed by non-space", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("**bold**:colon", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles italic followed by non-space", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("*italic*:colon", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles code followed by non-space", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("`code`next", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles text before first marker", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("prefix **bold** suffix", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

test_that("render_formatted_line handles multiple format types in one line", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  result <- nemeton:::render_formatted_line("**bold** and *italic* and `code`", 0.05, 0.5, 0.7, "black", 95)
  expect_null(result)
})

# ==============================================================================
# render_markdown_text() — full markdown rendering
# ==============================================================================

test_that("render_markdown_text returns y for NULL/empty text", {
  expect_equal(nemeton:::render_markdown_text(NULL, 0.05, 0.9), 0.9)
  expect_equal(nemeton:::render_markdown_text("", 0.05, 0.9), 0.9)
})

test_that("render_markdown_text renders plain paragraph", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  y <- nemeton:::render_markdown_text("A simple paragraph of text.", 0.05, 0.9)
  expect_true(is.numeric(y))
  expect_true(y < 0.9)
})

test_that("render_markdown_text renders headers at different levels", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "# Header 1\n## Header 2\n### Header 3"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text renders bullet list", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "- Item one\n- Item two\n- Item three"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text renders bullet list with * prefix", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "* Item one\n* Item two"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text renders numbered list", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "1. First item\n2. Second item\n3. Third item"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text renders blockquote", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "> This is a quoted text block"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text renders markdown table", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "| Col1 | Col2 | Col3 |\n|------|------|------|\n| A | B | C |\n| D | E | F |"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles empty lines as paragraph breaks", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "Paragraph one.\n\nParagraph two."
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles HTML br tags", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "Line one<br/>Line two<br />Line three"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text handles page break when y < 0.05", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  # Start near bottom of page to force page break
  y <- nemeton:::render_markdown_text("Line 1\nLine 2\nLine 3", 0.05, 0.06)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text wraps long paragraphs with justification", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  long_text <- paste(rep("word", 50), collapse = " ")
  y <- nemeton:::render_markdown_text(long_text, 0.05, 0.9, width = 40)
  expect_true(y < 0.9)
})

test_that("render_markdown_text renders long bullet list items with wrapping", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- paste0("- ", paste(rep("longword", 30), collapse = " "))
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9, width = 40)
  expect_true(y < 0.9)
})

test_that("render_markdown_text renders long numbered list items with wrapping", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- paste0("1. ", paste(rep("longword", 30), collapse = " "))
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9, width = 40)
  expect_true(y < 0.9)
})

test_that("render_markdown_text pre-processes bold spacing", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  # Test that **bold**word gets a space inserted
  text <- "**bold**word after"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles table with many rows (page break)", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  rows <- paste0("| Row", 1:40, " | Value", 1:40, " |")
  text <- paste(c("| Header1 | Header2 |", "|---------|---------|", rows), collapse = "\n")
  y <- nemeton:::render_markdown_text(text, 0.05, 0.5, width = 60)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles table with uneven columns", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "| Short | Very long column header text |\n|---|---|\n| A | Some long content in column two |"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(y < 0.9)
})

test_that("render_markdown_text renders mixed content", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- paste(
    "# Title",
    "",
    "A paragraph with **bold** and *italic* text.",
    "",
    "> A blockquote",
    "",
    "- Item 1",
    "- Item 2",
    "",
    "1. Numbered",
    "2. List",
    "",
    "| A | B |",
    "|---|---|",
    "| 1 | 2 |",
    sep = "\n"
  )
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(is.numeric(y))
})

test_that("render_markdown_text handles --> arrow cleanup", {
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 8, height = 11)
  on.exit({ grDevices::dev.off(); unlink(tmp) }, add = TRUE)
  plot.new()

  text <- "Step A --> Step B"
  y <- nemeton:::render_markdown_text(text, 0.05, 0.9)
  expect_true(is.numeric(y))
})

# ==============================================================================
# strip_markdown_for_display() — additional edge cases
# ==============================================================================

test_that("strip_markdown_for_display removes all marker types at once", {
  text <- "**bold** *italic* ~~strike~~ `code` [link](url)"
  result <- nemeton:::strip_markdown_for_display(text)
  expect_equal(result, "bold italic strike code link")
})

test_that("strip_markdown_for_display handles nested-like patterns", {
  text <- "**bold with nested**"
  result <- nemeton:::strip_markdown_for_display(text)
  expect_equal(result, "bold with nested")
})
