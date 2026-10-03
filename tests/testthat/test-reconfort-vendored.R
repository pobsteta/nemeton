# Traçabilité du code RECONFORT vendorisé (audit 1.0 ; Apache-2.0 §4b).

reconfort_tree <- function() {
  glue <- .reconfort_glue_dir()
  files <- list.files(glue, recursive = TRUE, all.files = FALSE)
  files[grepl("\\.(py|cfg)$", files) & !grepl("__pycache__", files)]
}

test_that("no vendored RECONFORT file claims to be verbatim", {
  glue <- .reconfort_glue_dir()
  for (f in c(reconfort_tree(), "README.md")) {
    txt <- paste(readLines(file.path(glue, f), warn = FALSE), collapse = "\n")
    expect_false(grepl("verbatim|do not edit", txt, ignore.case = TRUE), info = f)
  }
})

test_that("every file patched by nemeton says so and is listed in PATCHES.md", {
  glue <- .reconfort_glue_dir()
  patches <- readLines(file.path(glue, "PATCHES.md"), warn = FALSE)
  authored <- c("list_s2_items.py", "download_s2_item.py", "utils/tls.py")
  for (f in setdiff(reconfort_tree(), authored)) {
    src <- readLines(file.path(glue, f), warn = FALSE)
    patched <- any(grepl("nemeton", src, fixed = TRUE))
    if (!patched) next
    # En-tête sur plusieurs lignes commentées : on recolle le texte.
    head_txt <- gsub("\\s*#\\s*", " ",
                     paste(utils::head(src, 8L), collapse = " "))
    expect_match(head_txt, "modified by nemeton", ignore.case = TRUE, info = f)
    expect_true(any(grepl(paste0("`", f, "`"), patches, fixed = TRUE)), info = f)
  }
})

test_that("nemeton-authored glue is GPL-3, not MIT", {
  glue <- .reconfort_glue_dir()
  for (f in c("list_s2_items.py", "download_s2_item.py", "utils/tls.py")) {
    head_txt <- paste(utils::head(readLines(file.path(glue, f)), 3L), collapse = "\n")
    expect_match(head_txt, "GPL-3", fixed = TRUE, info = f)
    expect_false(grepl("\\bMIT\\b", head_txt), info = f)
  }
})

test_that("inst/NOTICE records the modifications of the RECONFORT code", {
  notice <- system.file("NOTICE", package = "nemeton")
  if (!nzchar(notice)) notice <- file.path("inst", "NOTICE")
  skip_if(!file.exists(notice), "NOTICE not found")
  txt <- paste(readLines(notice, warn = FALSE), collapse = "\n")
  expect_match(txt, "PATCHES.md", fixed = TRUE)
  expect_match(txt, "4(b)", fixed = TRUE)
})
