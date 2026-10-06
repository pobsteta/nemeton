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

test_that("dry_run never downloads a PDF (audit 1.0)", {
  skip_if_not_installed("withr")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    man$local_path[1] <- ""
    man$source_url[1] <- "https://example.org/rapport.pdf"
    testthat::local_mocked_bindings(.corpus_download = function(url, dest) {
      stop("dry_run must not download")
    })
    pdf_dir <- file.path(getwd(), "pdfs")
    rep <- build_knowledge_corpus(con = NULL, manifest = man, dry_run = TRUE,
                                  pdf_dir = pdf_dir)
    expect_equal(rep$action[rep$doc_id == "doc_full"], "planned")
    expect_equal(rep$reason[rep$doc_id == "doc_full"], "pdf (to download)")
    expect_false(dir.exists(pdf_dir))

    # Une URL mal formée n'est pas planifiée.
    man$source_url[1] <- "file:///etc/rapport.pdf"
    rep <- build_knowledge_corpus(con = NULL, manifest = man, dry_run = TRUE,
                                  pdf_dir = pdf_dir)
    expect_equal(rep$reason[rep$doc_id == "doc_full"], "no ingestible source")
  })
})

# ---- sécurité du manifeste éditable (audit 1.0) ----------------------

test_that("a local_path outside the corpus root is refused, never read", {
  skip_if_not_installed("withr")
  outside <- withr::local_tempdir()
  secret <- file.path(outside, "secret.md")
  writeLines("alpha secret", secret)
  root <- withr::local_tempdir()
  withr::local_options(nemeton.corpus_root = root)
  man <- .mini_manifest(root)
  man$local_path[1] <- secret
  rep <- build_knowledge_corpus(con = NULL, manifest = man, dry_run = TRUE)
  expect_equal(rep$action[rep$doc_id == "doc_full"], "error")
  expect_match(rep$reason[rep$doc_id == "doc_full"], "outside\\s+the\\s+corpus")
  # traversée relative
  man$local_path[1] <- file.path("..", basename(outside), "secret.md")
  rep <- build_knowledge_corpus(con = NULL, manifest = man, dry_run = TRUE)
  expect_equal(rep$action[rep$doc_id == "doc_full"], "error")
  expect_error(.resolve_manifest_source(man[1, ], tempdir()), "outside\\s+the\\s+corpus")
})

test_that("a symlink escaping the corpus root is refused", {
  skip_if_not_installed("withr")
  skip_on_os("windows")
  outside <- withr::local_tempdir()
  writeLines("alpha secret", file.path(outside, "secret.md"))
  root <- withr::local_tempdir()
  file.symlink(file.path(outside, "secret.md"), file.path(root, "lien.md"))
  withr::local_options(nemeton.corpus_root = root)
  row <- .mini_manifest(root)[1, ]
  row$local_path <- "lien.md"
  expect_error(.resolve_manifest_source(row, tempdir()), "outside\\s+the\\s+corpus")
})

test_that("a local_path with a non-text extension is refused", {
  skip_if_not_installed("withr")
  root <- withr::local_tempdir()
  writeLines("x", file.path(root, "id_rsa"))
  withr::local_options(nemeton.corpus_root = root)
  row <- .mini_manifest(root)[1, ]
  row$local_path <- "id_rsa"
  expect_error(.resolve_manifest_source(row, tempdir()), "extension not allowed")
})

test_that("relative local_path resolves against the corpus root", {
  skip_if_not_installed("withr")
  root <- withr::local_tempdir()
  dir.create(file.path(root, "refs"))
  writeLines(c("# T", "alpha beta prose."), file.path(root, "refs", "a.md"))
  withr::local_envvar(NEMETON_CORPUS_ROOT = root)
  withr::local_options(nemeton.corpus_root = NULL)
  row <- .mini_manifest(root)[1, ]
  row$local_path <- "refs/a.md"
  expect_match(.resolve_manifest_source(row, tempdir()), "alpha beta")
})

test_that("a file:// source_url is never downloaded and fails validation", {
  skip_if_not_installed("withr")
  pdf_dir <- withr::local_tempdir()
  testthat::local_mocked_bindings(.corpus_download = function(url, dest) {
    stop("must not download ", url)
  })
  row <- data.frame(doc_id = "doc_pdf", local_path = "", source_url = "", stringsAsFactors = FALSE)
  row$source_url <- "file:///etc/rapport.pdf"
  expect_null(.resolve_manifest_source(row, pdf_dir))
  man <- .mini_manifest(pdf_dir)
  man$source_url[1] <- "file:///etc/rapport.pdf"
  iss <- validate_knowledge_manifest(man)
  expect_true(any(iss$field == "source_url" & iss$severity == "error"))
})

test_that("build_knowledge_corpus revalidates doc_id (no write outside pdf_dir)", {
  skip_if_not_installed("withr")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    man$doc_id[1] <- "../../evil"
    rep <- build_knowledge_corpus(con = NULL, manifest = man, dry_run = TRUE)
    expect_equal(rep$action[1], "error")
    expect_match(rep$reason[1], "invalid\\s+doc_id")
  })
  row <- data.frame(doc_id = "../evil", local_path = "", source_url = "https://example.org/doc.pdf", stringsAsFactors = FALSE)
  expect_error(.resolve_manifest_source(row, withr::local_tempdir()), "doc_id")
})

test_that("real build reports a refused local_path as an error row", {
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) stop("must not embed"),
    .package = "nemeton")
  outside <- withr::local_tempdir()
  writeLines("alpha secret", file.path(outside, "secret.md"))
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    man$local_path[1] <- file.path(outside, "secret.md")
    rep <- build_knowledge_corpus(con, manifest = man)
    expect_equal(rep$action[rep$doc_id == "doc_full"], "error")
    expect_equal(nrow(list_knowledge_documents(con)), 0L)
  })
})

test_that("a declared local_path missing under the corpus root is named in the report", {
  # Le manifeste empaqueté porte des chemins `data-raw/references/...`,
  # relatifs à la racine du dépôt : depuis le paquet installé, ils ne sont
  # pas résolus. Le rapport doit le dire, pas un « no ingestible source »
  # muet qui ne désigne ni le fichier ni la racine.
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) stop("must not embed"),
    .package = "nemeton")
  root <- withr::local_tempdir()
  withr::local_options(nemeton.corpus_root = root)
  man <- .mini_manifest(root)
  man$local_path[1] <- "data-raw/references/absent.pdf"
  for (dry in c(TRUE, FALSE)) {
    rep <- build_knowledge_corpus(if (dry) NULL else con, manifest = man,
                                  dry_run = dry)
    reason <- rep$reason[rep$doc_id == "doc_full"]
    expect_equal(rep$action[rep$doc_id == "doc_full"], "skipped")
    expect_match(reason, "local_path not found", fixed = TRUE)
    expect_match(reason, "data-raw/references/absent.pdf", fixed = TRUE)
    expect_match(reason, "corpus root", fixed = TRUE)
  }
})


# ---- cache PDF (audit 1.0) -------------------------------------------

.ligne_pdf <- function(doc_id = "doc_pdf") {
  data.frame(doc_id = doc_id, local_path = "",
             source_url = "https://example.org/doc.pdf",
             stringsAsFactors = FALSE)
}

test_that("an HTML page served as the PDF is not cached", {
  pdf_dir <- withr::local_tempdir()
  testthat::local_mocked_bindings(.corpus_download = function(url, dest) {
    writeLines("<html><body>Just a moment...</body></html>", dest)
    0L
  })
  expect_null(.resolve_manifest_source(.ligne_pdf(), pdf_dir))
  expect_length(list.files(pdf_dir, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("a corrupt cached PDF is discarded and downloaded again", {
  pdf_dir <- withr::local_tempdir()
  dest <- file.path(pdf_dir, "doc_pdf.pdf")
  writeLines("<html>403</html>", dest)  # reliquat d'une version antérieure
  n <- 0L
  testthat::local_mocked_bindings(.corpus_download = function(url, dest) {
    n <<- n + 1L
    writeBin(c(charToRaw("%PDF-1.7\n"), as.raw(1:20)), dest)
    0L
  })
  expect_identical(.resolve_manifest_source(.ligne_pdf(), pdf_dir), dest)
  expect_true(.pdf_signature_ok(dest))
  expect_identical(n, 1L)
  # Valide : resservi sans nouveau téléchargement.
  .resolve_manifest_source(.ligne_pdf(), pdf_dir)
  expect_identical(n, 1L)
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

# ---- audit 1.0, constats mineurs ---------------------------------------

test_that("l'idempotence repose sur doc_id, pas sur le titre (audit 1.0)", {
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) .fake_embed_bc(texts),
    .package = "nemeton")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())[1, ]
    build_knowledge_corpus(con, manifest = man)
    expect_equal(nrow(list_knowledge_documents(con)), 1L)

    # Titre corrige dans le manifeste, meme doc_id : pas de doublon.
    man2 <- man; man2$title <- "Full Doc (2e edition du titre)"
    rep <- build_knowledge_corpus(con, manifest = man2)
    expect_equal(rep$reason, "already ingested")
    expect_equal(nrow(list_knowledge_documents(con)), 1L)

    # Autre document portant le meme titre : il est ingere.
    md3 <- file.path(getwd(), "homonyme.md")
    writeLines(c("# Title", "delta epsilon autre texte sur les forets."), md3)
    man3 <- man; man3$doc_id <- "doc_homonyme"; man3$local_path <- md3
    rep <- build_knowledge_corpus(con, manifest = man3)
    expect_equal(rep$action, "ingested")
    expect_equal(nrow(list_knowledge_documents(con)), 2L)
  })
})

test_that("un contenu identique sous un autre doc_id est saute, pas duplique (1.0.0)", {
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) .fake_embed_bc(texts),
    .package = "nemeton")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())[1, ]
    first <- build_knowledge_corpus(con, manifest = man)
    # Meme fichier, autre doc_id et autre titre.
    man2 <- man; man2$doc_id <- "doc_copie"; man2$title <- "Copie"
    rep <- suppressMessages(build_knowledge_corpus(con, manifest = man2))
    expect_equal(rep$action, "skipped")
    expect_equal(rep$document_id, first$document_id)
    expect_equal(rep$reason,
                 sprintf("duplicate content of document %d", first$document_id))
    expect_equal(nrow(list_knowledge_documents(con)), 1L)
  })
})

test_that("un document ingere hors manifeste (sans doc_id) reste reconnu par son titre", {
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) .fake_embed_bc(texts),
    .package = "nemeton")
  withr::with_tempdir({
    ingest_knowledge_document(con, "alpha beta gamma",
      metadata = list(title = "Full Doc", lang = "fr", doc_type = "manual"))
    man <- .mini_manifest(getwd())[1, ]
    rep <- build_knowledge_corpus(con, manifest = man)
    expect_equal(rep$reason, "already ingested")
  })
})

test_that("fresh = TRUE vide le corpus dans une transaction (audit 1.0)", {
  con <- .local_corpus_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) .fake_embed_bc(texts),
    .package = "nemeton")
  withr::with_tempdir({
    man <- .mini_manifest(getwd())
    build_knowledge_corpus(con, manifest = man, include_to_confirm = TRUE)
    expect_equal(nrow(list_knowledge_documents(con)), 2L)

    real_delete <- delete_knowledge_document
    n_calls <- 0L
    testthat::local_mocked_bindings(
      delete_knowledge_document = function(con, document_id) {
        n_calls <<- n_calls + 1L
        if (n_calls == 2L) stop("coupure reseau")
        real_delete(con, document_id)
      })
    expect_error(build_knowledge_corpus(con, manifest = man, fresh = TRUE),
                 "coupure")
    # Rien n'est supprime : la purge est annulee en bloc.
    expect_equal(nrow(list_knowledge_documents(con)), 2L)
  })
})
