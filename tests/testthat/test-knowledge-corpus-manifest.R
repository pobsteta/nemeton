# test-knowledge-corpus-manifest.R — integrity guards for the packaged
# RAG knowledge-corpus manifest (spec 009.1).
#
# `inst/extdata/knowledge_corpus_v1.csv` is the SINGLE SOURCE OF TRUTH for
# the corpus: a document enters the knowledge base only if it has a row
# here, and `data-raw/build_knowledge_corpus.R` trusts these columns
# blindly (license gate D5, ingest strategy, metadata). A typo in an enum
# column or an unknown family/profile code would silently mis-ingest or
# skip a document, so the manifest deserves the same guardrails as code.
#
# These tests read the *packaged* CSV (via system.file when installed,
# falling back to the source tree), so they also catch a manifest that
# ships malformed.

# ---- controlled vocabularies (single source of truth) ----------------

# Consume the package's controlled vocabularies instead of duplicating
# them here (spec 009.2 A2): knowledge_manifest_vocab() is now the single
# source of truth, shared with validate_knowledge_manifest().
.vocab      <- knowledge_manifest_vocab()
.LICENSES   <- .vocab$licenses
.STATUSES   <- .vocab$statuses
.STRATEGIES <- .vocab$strategies
.LANGS      <- .vocab$langs
.DOC_TYPES  <- .vocab$doc_types
.PROFILES   <- .vocab$profiles
.FAMILY_RE  <- .vocab$family_regex
.REQUIRED_COLS <- .vocab$columns

.read_manifest <- function() {
  path <- system.file("extdata", "knowledge_corpus_v1.csv", package = "nemeton")
  if (!nzchar(path)) path <- testthat::test_path("..", "..", "inst",
                                                 "extdata", "knowledge_corpus_v1.csv")
  testthat::skip_if_not(file.exists(path), "knowledge_corpus_v1.csv not found")
  m <- utils::read.csv(path, stringsAsFactors = FALSE,
                       colClasses = "character", na.strings = "NA")
  m[is.na(m)] <- ""
  m
}

.tokens <- function(x) {
  out <- trimws(unlist(strsplit(x, "|", fixed = TRUE)))
  out[nzchar(out)]
}


# ---- structure -------------------------------------------------------

test_that("manifest has exactly the expected columns", {
  m <- .read_manifest()
  expect_setequal(names(m), .REQUIRED_COLS)
})

test_that("manifest has rows and unique, slug-shaped doc_id", {
  m <- .read_manifest()
  expect_gt(nrow(m), 0L)
  expect_false(any(duplicated(m$doc_id)), info = "duplicate doc_id")
  expect_true(all(nzchar(m$doc_id)))
  expect_true(all(grepl("^[a-z0-9_]+$", m$doc_id)),
              info = paste("non-slug doc_id:",
                           paste(m$doc_id[!grepl("^[a-z0-9_]+$", m$doc_id)],
                                 collapse = ", ")))
  expect_true(all(nzchar(m$title)))
})


# ---- controlled enums ------------------------------------------------

test_that("manifest enum columns use only known values", {
  m <- .read_manifest()
  expect_true(all(m$lang            %in% .LANGS),      info = "lang")
  expect_true(all(m$status          %in% .STATUSES),   info = "status")
  expect_true(all(m$ingest_strategy %in% .STRATEGIES), info = "ingest_strategy")
  expect_true(all(m$doc_type        %in% .DOC_TYPES),  info = "doc_type")
  expect_true(all(toupper(m$license_commercial_ok) %in% c("TRUE", "FALSE")),
              info = "license_commercial_ok")
  bad_lic <- setdiff(unique(m$license), .LICENSES)
  expect_true(length(bad_lic) == 0L,
              info = paste("unknown license(s):", paste(bad_lic, collapse = ", ")))
})

test_that("family and profile codes are all recognised", {
  m <- .read_manifest()
  fam <- unique(.tokens(paste(m$family_codes, collapse = "|")))
  bad_fam <- fam[!grepl(.FAMILY_RE, fam)]
  expect_true(length(bad_fam) == 0L,
              info = paste("unknown family code(s):", paste(bad_fam, collapse = ", ")))

  prof <- unique(.tokens(paste(m$profile_codes, collapse = "|")))
  bad_prof <- setdiff(prof, .PROFILES)
  expect_true(length(bad_prof) == 0L,
              info = paste("unknown profile code(s):", paste(bad_prof, collapse = ", ")))

  # Every document is routed to at least one family and one profile,
  # otherwise the hybrid metadata filter in retrieve_knowledge() can
  # never surface it.
  expect_true(all(nzchar(m$family_codes)),  info = "row with no family_codes")
  expect_true(all(nzchar(m$profile_codes)), info = "row with no profile_codes")
})


# ---- license-gate safety invariants (spec 009.1 D5 / §3 / §5) --------

test_that("a cleared row never carries an unconfirmed license", {
  # status == cleared means build_knowledge_corpus.R WILL ingest it, so a
  # cleared row must have a real, confirmed license — never empty and
  # never the literal `to-confirm` placeholder (that contradicts D5).
  m <- .read_manifest()
  cleared <- m[m$status == "cleared", , drop = FALSE]
  expect_true(all(nzchar(cleared$license)), info = "cleared row with empty license")
  offenders <- cleared$doc_id[cleared$license == "to-confirm"]
  expect_true(length(offenders) == 0L,
              info = paste("cleared row with `to-confirm` license:",
                           paste(offenders, collapse = ", ")))
})

test_that("copyrighted documents are never full-text ingested", {
  # A `copyright` license may only be referenced (abstract_only /
  # link_only), never `full` — full-text ingestion of a copyrighted PDF
  # is exactly what spec 009.1 §5 forbids.
  m <- .read_manifest()
  bad <- m$doc_id[m$license == "copyright" & m$ingest_strategy == "full"]
  expect_true(length(bad) == 0L,
              info = paste("copyright doc marked full:", paste(bad, collapse = ", ")))
})


# ---- source resolvability -------------------------------------------

test_that("a declared local_path has an ingestible extension", {
  # build_knowledge_corpus.R only knows how to read PDF/markdown sources;
  # a local_path pointing at anything else would be silently skipped.
  m <- .read_manifest()
  lp <- m$local_path[nzchar(m$local_path)]
  ok <- grepl("\\.(pdf|rmd|md|markdown|qmd)$", lp, ignore.case = TRUE)
  expect_true(all(ok),
              info = paste("non-ingestible local_path:", paste(lp[!ok], collapse = ", ")))
})
