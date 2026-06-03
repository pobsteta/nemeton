# Tests for build_knowledge_corpus() (spec 009.2). Integration tests use a
# throwaway SQLite file under a temp dir and a mocked embedder, so they run
# offline without NEMETON_DB_URL_TEST and never touch a real corpus.

.fake_embed_bc <- function(texts) {
  # A trivial deterministic embedder: word count over a tiny vocabulary.
  vocab <- c("alpha", "beta", "gamma", "delta")
  M <- vapply(as.character(texts), function(t) {
    w <- unlist(strsplit(tolower(t), "[^a-z]+"))
    as.numeric(vapply(vocab, function(v) sum(w == v), numeric(1)))
  }, numeric(length(vocab)))
  matrix(t(M), nrow = length(texts), ncol = length(vocab))
}

.local_corpus_con <- function(env = parent.frame()) {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("withr")
  dir <- withr::local_tempdir(.local_envir = env)
  con <- db_connect(paste0("sqlite://", file.path(dir, "corpus.sqlite")))
  withr::defer(db_disconnect(con), envir = env)
  suppressMessages(enable_rag(con))
  con
}

# A two-row manifest: one full-text (a local .md), one to_confirm row.
.mini_manifest <- function(dir) {
  md <- file.path(dir, "doc.md")
  writeLines(c("# Title", "alpha beta gamma prose about forests."), md)
  rbind(
    data.frame(
      doc_id = "doc_full", title = "Full Doc", author = "A", publisher = "P",
      pub_date = "2024-01-01", lang = "fr", doc_type = "manual",
      source_url = "", license = "MIT", license_commercial_ok = "TRUE",
      family_codes = "C1", profile_codes = "chercheur",
      ingest_strategy = "full", local_path = md, status = "cleared",
      notes = "", stringsAsFactors = FALSE),
    data.frame(
      doc_id = "doc_ref", title = "Ref Doc", author = "B", publisher = "Q",
      pub_date = "2023-01-01", lang = "en", doc_type = "paper",
      source_url = "https://example.org/x", license = "copyright",
      license_commercial_ok = "FALSE", family_codes = "R5",
      profile_codes = "chercheur", ingest_strategy = "link_only",
      local_path = "", status = "to_confirm", notes = "",
      stringsAsFactors = FALSE))
}


# ---- dry run ---------------------------------------------------------

test_that("dry_run plans without DB or embeddings", {
  skip_if_not_installed("withr")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    rep <- build_knowledge_corpus(con = NULL, manifest = man, dry_run = TRUE)
    expect_equal(nrow(rep), 2L)
    expect_equal(rep$action[rep$doc_id == "doc_full"], "planned")
    # the to_confirm row is not eligible by default -> skipped
    expect_equal(rep$action[rep$doc_id == "doc_ref"], "skipped")
  })
})


# ---- real build ------------------------------------------------------

test_that("a cleared full-text row is ingested; idempotent re-run skips", {
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) .fake_embed_bc(texts),
    .package = "nemeton")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    rep1 <- build_knowledge_corpus(con, manifest = man)
    full <- rep1[rep1$doc_id == "doc_full", ]
    expect_equal(full$action, "ingested")
    expect_gt(full$n_chunks, 0L)
    expect_equal(full$mode, "full")
    # to_confirm row excluded by the license gate
    expect_equal(rep1$action[rep1$doc_id == "doc_ref"], "skipped")
    expect_equal(nrow(list_knowledge_documents(con)), 1L)

    rep2 <- build_knowledge_corpus(con, manifest = man)
    expect_equal(rep2$reason[rep2$doc_id == "doc_full"], "already ingested")
    expect_equal(nrow(list_knowledge_documents(con)), 1L)
  })
})

test_that("include_to_confirm ingests the reference row as one chunk", {
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) .fake_embed_bc(texts),
    .package = "nemeton")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    rep <- build_knowledge_corpus(con, manifest = man, include_to_confirm = TRUE)
    ref <- rep[rep$doc_id == "doc_ref", ]
    expect_equal(ref$action, "ingested")
    expect_equal(ref$mode, "link_only")
    expect_equal(ref$n_chunks, 1L)
    expect_equal(nrow(list_knowledge_documents(con)), 2L)
  })
})

test_that("fresh wipes the corpus before rebuilding", {
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) .fake_embed_bc(texts),
    .package = "nemeton")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    build_knowledge_corpus(con, manifest = man)
    expect_equal(nrow(list_knowledge_documents(con)), 1L)
    rep <- build_knowledge_corpus(con, manifest = man, fresh = TRUE)
    # after a fresh wipe the doc is re-ingested, not skipped
    expect_equal(rep$action[rep$doc_id == "doc_full"], "ingested")
    expect_equal(nrow(list_knowledge_documents(con)), 1L)
  })
})

test_that("the progress callback fires once per row", {
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) .fake_embed_bc(texts),
    .package = "nemeton")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    seen <- 0L
    build_knowledge_corpus(con, manifest = man,
      progress = function(i, n, row, rr) seen <<- seen + 1L)
    expect_equal(seen, nrow(man))
  })
})

test_that("real build requires a connection", {
  skip_if_not_installed("withr")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    expect_error(
      build_knowledge_corpus(con = NULL, manifest = man, dry_run = FALSE),
      "DBIConnection")
  })
})
