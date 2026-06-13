# Tests for the knowledge-corpus manifest API (spec 009.2):
# knowledge_manifest_vocab(), read/validate/write_knowledge_manifest(),
# knowledge_manifest_path(). No DB, no network.

# A minimal, valid one-row manifest data.frame.
.valid_manifest <- function() {
  data.frame(
    doc_id = "doc_a", title = "Doc A", author = "Auth", publisher = "Pub",
    pub_date = "2024-01-01", lang = "fr", doc_type = "report",
    source_url = "", license = "MIT", license_commercial_ok = "TRUE",
    family_codes = "R5|C1", profile_codes = "chercheur|technicien",
    ingest_strategy = "full", local_path = "", status = "cleared",
    notes = "ok", stringsAsFactors = FALSE)
}


# ---- vocab -----------------------------------------------------------

test_that("knowledge_manifest_vocab exposes the controlled vocabularies", {
  v <- knowledge_manifest_vocab()
  expect_named(v, c("columns", "licenses", "statuses", "strategies",
                    "langs", "doc_types", "profiles", "family_regex"))
  expect_length(v$columns, 16L)
  expect_true("cleared" %in% v$statuses && "to_confirm" %in% v$statuses)
  expect_true(all(c("full", "abstract_only", "link_only") %in% v$strategies))
})


# ---- validate: happy path -------------------------------------------

test_that("a valid manifest yields zero issues", {
  expect_equal(nrow(validate_knowledge_manifest(.valid_manifest())), 0L)
})

test_that("the packaged manifest is valid", {
  man <- read_knowledge_manifest()
  issues <- validate_knowledge_manifest(man)
  errs <- issues[issues$severity == "error", , drop = FALSE]
  expect_equal(nrow(errs), 0L,
               info = paste(errs$doc_id, errs$field, errs$message, collapse = " ; "))
})


# ---- validate: each invariant ---------------------------------------

test_that("unknown enum values are flagged", {
  m <- .valid_manifest(); m$doc_type <- "bogus"
  iss <- validate_knowledge_manifest(m)
  expect_true(any(iss$field == "doc_type" & iss$severity == "error"))
})

test_that("duplicate doc_id is flagged", {
  m <- rbind(.valid_manifest(), .valid_manifest())
  iss <- validate_knowledge_manifest(m)
  expect_true(any(iss$field == "doc_id" & grepl("duplicate", iss$message)))
})

test_that("non-slug doc_id is flagged", {
  m <- .valid_manifest(); m$doc_id <- "Doc A!"
  iss <- validate_knowledge_manifest(m)
  expect_true(any(iss$field == "doc_id" & grepl("slug", iss$message)))
})

test_that("a cleared row with a to-confirm license is flagged (D5)", {
  m <- .valid_manifest(); m$license <- "to-confirm"
  iss <- validate_knowledge_manifest(m)
  expect_true(any(iss$field == "license" & grepl("to-confirm", iss$message)))
})

test_that("a copyright document marked full is flagged", {
  m <- .valid_manifest()
  m$license <- "copyright"; m$status <- "to_confirm"; m$ingest_strategy <- "full"
  iss <- validate_knowledge_manifest(m)
  expect_true(any(iss$field == "ingest_strategy" & grepl("copyright", iss$message)))
})

test_that("unknown family / profile codes are flagged", {
  m <- .valid_manifest(); m$family_codes <- "R5|ZZ"; m$profile_codes <- "wizard"
  iss <- validate_knowledge_manifest(m)
  expect_true(any(iss$field == "family_codes"))
  expect_true(any(iss$field == "profile_codes"))
})

test_that("a non-ingestible local_path is a warning", {
  m <- .valid_manifest(); m$local_path <- "foo/bar.docx"
  iss <- validate_knowledge_manifest(m)
  expect_true(any(iss$field == "local_path" & iss$severity == "warning"))
})

test_that("a missing column is a table-level error", {
  m <- .valid_manifest(); m$notes <- NULL
  iss <- validate_knowledge_manifest(m)
  expect_true(any(is.na(iss$row) & iss$field == "notes"))
})


# ---- read / write round-trip ----------------------------------------

test_that("read -> write -> read is a stable round trip", {
  skip_if_not_installed("withr")
  withr::with_tempdir({
    p <- "m.csv"
    write_knowledge_manifest(.valid_manifest(), path = p)
    again <- read_knowledge_manifest(p)
    expect_equal(again$doc_id, "doc_a")
    expect_equal(again$family_codes, "R5|C1")
    # second write produces byte-identical output (deterministic)
    write_knowledge_manifest(again, path = "m2.csv")
    expect_identical(readLines(p), readLines("m2.csv"))
  })
})

test_that("write refuses a manifest with blocking errors", {
  skip_if_not_installed("withr")
  withr::with_tempdir({
    m <- .valid_manifest(); m$doc_type <- "bogus"
    expect_error(write_knowledge_manifest(m, path = "bad.csv"), "blocking")
    expect_false(file.exists("bad.csv"))
    # forcing past validation writes it
    expect_no_error(write_knowledge_manifest(m, path = "forced.csv", validate = FALSE))
  })
})

test_that("fields with commas are quoted, plain fields are not", {
  skip_if_not_installed("withr")
  withr::with_tempdir({
    m <- .valid_manifest(); m$notes <- "a, b, c"
    write_knowledge_manifest(m, path = "q.csv")
    raw <- readLines("q.csv")
    expect_true(any(grepl('"a, b, c"', raw, fixed = TRUE)))
    expect_true(any(grepl("doc_a,Doc A,", raw, fixed = TRUE)))  # doc_id unquoted
  })
})


# ---- path resolution -------------------------------------------------

test_that("knowledge_manifest_path(writable) seeds the project copy", {
  skip_if_not_installed("withr")
  withr::with_tempdir({
    dest <- file.path(getwd(), "writable_manifest.csv")
    withr::with_envvar(c(NEMETON_KNOWLEDGE_MANIFEST = dest), {
      expect_false(file.exists(dest))
      p <- knowledge_manifest_path(writable = TRUE)
      expect_identical(p, dest)
      expect_true(file.exists(dest))
      # seeded from the packaged manifest -> non-empty, valid
      man <- read_knowledge_manifest(p)
      expect_gt(nrow(man), 0L)
    })
  })
})

test_that("reset_knowledge_manifest() needs confirm = TRUE", {
  expect_error(reset_knowledge_manifest(confirm = FALSE), "confirm")
})

test_that("reset_knowledge_manifest() refreshes a stale writable copy", {
  skip_if_not_installed("withr")
  withr::with_tempdir({
    dest <- file.path(getwd(), "writable_manifest.csv")
    withr::with_envvar(c(NEMETON_KNOWLEDGE_MANIFEST = dest), {
      # A stale writable copy with a doc the packaged seed no longer ships.
      writeLines(c(
        paste(readLines(knowledge_manifest_path(), n = 1)),   # header
        'tuto_99,"Stale tutorial",X,nemeton,2020-01-01,fr,manual,,MIT,TRUE,C,chercheur,full,x.Rmd,cleared,stale'
      ), dest)
      expect_equal(nrow(read_knowledge_manifest(dest)), 1L)
      expect_true(any(grepl("tuto_99", readLines(dest))))

      out <- reset_knowledge_manifest()
      expect_identical(out, dest)
      # now equals the packaged seed: same rows, no stale doc
      seed <- read_knowledge_manifest(knowledge_manifest_path())
      after <- read_knowledge_manifest(dest)
      expect_equal(nrow(after), nrow(seed))
      expect_false(any(grepl("tuto_99", readLines(dest))))
    })
  })
})

test_that("knowledge_manifest_path() returns the packaged seed", {
  p <- knowledge_manifest_path()
  expect_true(file.exists(p))
  expect_match(basename(p), "knowledge_corpus")
})
