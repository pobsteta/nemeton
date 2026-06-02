# Tests for the RAG knowledge base (spec 009 / E7).
#
# Integration tests run against a throwaway SQLite file under a temp dir
# (never an external/prod DB), so they always run without NEMETON_DB_URL_TEST
# and carry zero risk of wiping a real corpus. The embedding API is mocked
# with a deterministic bag-of-words embedder so retrieval ranking is testable
# offline.

# Fixed forestry vocabulary -> deterministic, offline "embeddings".
.fake_vocab <- c(
  "scolyte", "epicea", "fordead", "crswir", "sapin", "chene",
  "duplat", "carbone", "biomasse", "naturalite", "tempete", "secheresse"
)

.fake_norm <- function(s) {
  s <- tolower(s)
  chartr("éèêàôîùûç",
         "eeeaoiuuc", s)
}

# n x length(vocab) count matrix; cosine over it reflects word overlap.
fake_embed <- function(texts) {
  V <- length(.fake_vocab)
  M <- vapply(as.character(texts), function(t) {
    w <- unlist(strsplit(.fake_norm(t), "[^a-z0-9]+"))
    as.numeric(vapply(.fake_vocab, function(v) sum(w == v), numeric(1)))
  }, numeric(V))
  # vapply returns V x n; transpose to n x V (and keep a matrix for n == 1).
  matrix(t(M), nrow = length(texts), ncol = V)
}

# A temp-file SQLite connection with the base + RAG schema, auto-closed.
local_rag_con <- function(env = parent.frame()) {
  testthat::skip_if_not_installed("DBI")
  testthat::skip_if_not_installed("RSQLite")
  testthat::skip_if_not_installed("withr")
  dir <- withr::local_tempdir(.local_envir = env)
  con <- db_connect(paste0("sqlite://", file.path(dir, "rag.sqlite")))
  withr::defer(db_disconnect(con), envir = env)
  suppressMessages(enable_rag(con))
  con
}

# Ingest a small single-chunk document. Mock the embedder so no network /
# API key is needed.
ingest_fake <- function(con, text, metadata, provider = "mistral") {
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts),
    .package = "nemeton"
  )
  ingest_knowledge_document(con, text, metadata = metadata,
                            embed_provider = provider)
}


# ---- Unit: chunking --------------------------------------------------

test_that(".chunk_text splits long text into several chunks", {
  words <- paste(paste0("mot", seq_len(400)), collapse = " ")
  chunks <- nemeton:::.chunk_text(words, size = 50L, overlap = 5L)
  expect_gt(length(chunks), 1L)
  expect_true(all(nzchar(chunks)))
})

test_that(".chunk_text returns empty for blank input", {
  expect_length(nemeton:::.chunk_text("   \n  ", size = 50L, overlap = 5L), 0L)
  expect_length(nemeton:::.chunk_text("", size = 50L, overlap = 5L), 0L)
})

test_that(".chunk_text consecutive chunks overlap", {
  words <- paste(paste0("w", seq_len(60)), collapse = " ")
  chunks <- nemeton:::.chunk_text(words, size = 12L, overlap = 4L)
  expect_gt(length(chunks), 1L)
  first_words  <- strsplit(chunks[[1]], " ")[[1]]
  second_words <- strsplit(chunks[[2]], " ")[[1]]
  expect_true(length(intersect(first_words, second_words)) > 0L)
})

test_that(".chunk_text rejects invalid overlap", {
  expect_error(nemeton:::.chunk_text("a b c", size = 5L, overlap = 5L),
               "chunk_overlap")
})

test_that(".estimate_tokens approximates nchar/4", {
  expect_equal(nemeton:::.estimate_tokens(strrep("x", 40)), 10L)
  expect_type(nemeton:::.estimate_tokens("hello world"), "integer")
})


# ---- Unit: vector math + encoding ------------------------------------

test_that(".cosine_sim is 1 for identical and 0 for orthogonal vectors", {
  q <- c(1, 0, 1)
  M <- rbind(c(1, 0, 1), c(0, 1, 0))
  sim <- nemeton:::.cosine_sim(q, M)
  expect_equal(sim[1], 1)
  expect_equal(sim[2], 0)
})

test_that(".cosine_sim handles a zero query vector", {
  expect_equal(nemeton:::.cosine_sim(c(0, 0), rbind(c(1, 1))), 0)
})

test_that(".fit_embedding_dim pads and truncates", {
  expect_length(nemeton:::.fit_embedding_dim(c(1, 2), 5L), 5L)
  expect_equal(nemeton:::.fit_embedding_dim(c(1, 2, 3, 4, 5), 3L), c(1, 2, 3))
  expect_equal(tail(nemeton:::.fit_embedding_dim(c(1, 2), 4L), 2), c(0, 0))
})

test_that(".pg_text_array quotes members", {
  expect_equal(nemeton:::.pg_text_array(c("R", "B")), '{"R","B"}')
})

test_that(".decode_any_array reads JSON, pg-literal, and NA", {
  expect_equal(nemeton:::.decode_any_array('["R","B"]'), c("R", "B"))
  expect_equal(nemeton:::.decode_any_array('{"R","B"}'), c("R", "B"))
  expect_length(nemeton:::.decode_any_array(NA_character_), 0L)
  expect_equal(nemeton:::.decode_any_array(c("R", "B")), c("R", "B"))
})

test_that("embedding round-trips through JSON encoding", {
  v <- c(0.123456789, -0.5, 1e-8, 2.5)
  back <- nemeton:::.decode_embedding(nemeton:::.embedding_json(v))
  expect_equal(back, v, tolerance = 1e-12)
})


# ---- Unit: metadata validation ---------------------------------------

test_that(".validate_doc_metadata requires title/lang/doc_type", {
  expect_error(nemeton:::.validate_doc_metadata(list(lang = "fr", doc_type = "report")),
               "title")
})

test_that(".validate_doc_metadata rejects an invalid doc_type", {
  expect_error(
    nemeton:::.validate_doc_metadata(list(title = "T", lang = "fr", doc_type = "blog")),
    "doc_type"
  )
})

test_that(".validate_doc_metadata defaults license to unknown", {
  m <- nemeton:::.validate_doc_metadata(list(title = "T", lang = "fr", doc_type = "note"))
  expect_equal(m$license, "unknown")
})


# ---- Unit: citation formatting ---------------------------------------

test_that("format_citations returns empty string for no chunks", {
  expect_identical(format_citations(nemeton:::.empty_retrieval()), "")
})

test_that("format_citations builds numbered Markdown footnotes", {
  df <- data.frame(
    chunk_id = 1:2, document_id = 1:2,
    title = c("Methode FORDEAD", "Courbes Duplat"),
    author = c("Bernard & Doridant", "Duplat & Tran-Ha"),
    pub_date = as.Date(c("2024-01-01", "1997-01-01")),
    source_url = c("https://example.org/a", NA_character_),
    lang = c("fr", "fr"), chunk_index = c(0L, 0L),
    page_number = c(23L, NA_integer_),
    text = c("x", "y"), similarity = c(0.9, 0.8),
    stringsAsFactors = FALSE
  )
  md <- format_citations(df, format = "markdown")
  expect_match(md, "## Sources documentaires")
  expect_match(md, "\\[\\^1\\]")
  expect_match(md, "\\[\\^2\\]")
  expect_match(md, "Bernard & Doridant, 2024")
  expect_match(md, "p\\. 23")
  expect_match(md, "https://example.org/a")
})

test_that("format_citations can emit HTML", {
  df <- nemeton:::.empty_retrieval()
  df[1, ] <- list(1L, 1L, "T", "A", as.Date("2020-01-01"), NA_character_,
                  "fr", 0L, NA_integer_, "body", 0.9)
  html <- format_citations(df, format = "html")
  expect_match(html, "<ol>")
  expect_match(html, 'id="cite-1"')
})


# ---- Integration: schema + ingest ------------------------------------

test_that("enable_rag creates the knowledge tables (idempotent)", {
  con <- local_rag_con()
  expect_true(DBI::dbExistsTable(con, "knowledge_document"))
  expect_true(DBI::dbExistsTable(con, "knowledge_chunk"))
  expect_length(suppressMessages(enable_rag(con)), 0L)  # already applied
})

test_that("retrieve_knowledge errors when RAG schema is absent", {
  testthat::skip_if_not_installed("DBI")
  testthat::skip_if_not_installed("RSQLite")
  testthat::skip_if_not_installed("withr")
  dir <- withr::local_tempdir()
  con <- db_connect(paste0("sqlite://", file.path(dir, "bare.sqlite")))
  withr::defer(db_disconnect(con))
  suppressMessages(db_migrate(con))           # base schema only, no RAG
  expect_error(retrieve_knowledge(con, "x"), "RAG knowledge base schema")
})

test_that("ingest_knowledge_document stores a document and its chunk", {
  con <- local_rag_con()
  res <- ingest_fake(con, "le scolyte attaque l'epicea, methode fordead crswir",
    metadata = list(title = "Doc R", lang = "fr", doc_type = "report",
                    license = "OGL", family_codes = c("R"), author = "ONF",
                    pub_date = "2024-03-01"))
  expect_type(res, "list")
  expect_gte(res$n_chunks, 1L)
  ndoc <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM knowledge_document")$n
  nchk <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM knowledge_chunk")$n
  expect_equal(ndoc, 1L)
  expect_equal(nchk, res$n_chunks)
})

test_that("two ingests create two distinct documents", {
  con <- local_rag_con()
  r1 <- ingest_fake(con, "scolyte epicea",
    metadata = list(title = "A", lang = "fr", doc_type = "note"))
  r2 <- ingest_fake(con, "chene duplat",
    metadata = list(title = "B", lang = "fr", doc_type = "note"))
  expect_false(identical(r1$document_id, r2$document_id))
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM knowledge_document")$n, 2L)
})

test_that("embed_query returns a numeric vector", {
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  v <- embed_query("scolyte epicea")
  expect_type(v, "double")
  expect_length(v, length(.fake_vocab))
  expect_false(anyNA(v))
})


# ---- Integration: retrieval ------------------------------------------

# Seed a 3-document corpus shared by the retrieval tests.
seed_corpus <- function(con) {
  ingest_fake(con, "le scolyte de l'epicea, detection fordead crswir",
    metadata = list(title = "FORDEAD R5", lang = "fr", doc_type = "report",
                    family_codes = c("R"), profile_codes = c("gestionnaire_onf"),
                    author = "Bernard", pub_date = "2024-01-01"))
  ingest_fake(con, "courbes de site index, chene, duplat",
    metadata = list(title = "Site index", lang = "fr", doc_type = "paper",
                    family_codes = c("P"), profile_codes = c("chercheur"),
                    author = "Duplat", pub_date = "1997-01-01"))
  ingest_fake(con, "carbon biomass allometry forest",
    metadata = list(title = "Biomass", lang = "en", doc_type = "paper",
                    family_codes = c("C"), author = "Forrester"))
}

test_that("retrieve_knowledge ranks the relevant chunk first (A4)", {
  con <- local_rag_con()
  seed_corpus(con)
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  res <- retrieve_knowledge(con, "scolyte epicea", min_similarity = 0.5)
  expect_gt(nrow(res), 0L)
  expect_equal(res$title[1], "FORDEAD R5")
  expect_gte(res$similarity[1], 0.7)
})

test_that("retrieve_knowledge filters by family_codes (A5)", {
  con <- local_rag_con()
  seed_corpus(con)
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  res <- retrieve_knowledge(con, "chene duplat carbone", family_codes = c("P"),
                            min_similarity = 0.1)
  expect_true(all(res$title == "Site index"))
})

test_that("retrieve_knowledge filters by profile_codes", {
  con <- local_rag_con()
  seed_corpus(con)
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  res <- retrieve_knowledge(con, "scolyte epicea",
                            profile_codes = c("gestionnaire_onf"), min_similarity = 0.1)
  expect_true(all(res$document_id %in%
    DBI::dbGetQuery(con,
      "SELECT id FROM knowledge_document WHERE profile_codes LIKE '%gestionnaire_onf%'")$id))
})

test_that("retrieve_knowledge filters by language", {
  con <- local_rag_con()
  seed_corpus(con)
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  res <- retrieve_knowledge(con, "carbon biomass", lang = "en", min_similarity = 0.1)
  expect_true(all(res$lang == "en"))
})

test_that("retrieve_knowledge honours top_k", {
  con <- local_rag_con()
  seed_corpus(con)
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  res <- retrieve_knowledge(con, "scolyte epicea chene carbone", top_k = 1L,
                            min_similarity = 0)
  expect_lte(nrow(res), 1L)
})

test_that("retrieve_knowledge returns the canonical empty frame below threshold", {
  con <- local_rag_con()
  seed_corpus(con)
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  res <- retrieve_knowledge(con, "tempete secheresse", min_similarity = 0.99)
  expect_equal(nrow(res), 0L)
  expect_named(res, c("chunk_id", "document_id", "title", "author", "pub_date",
                      "source_url", "lang", "chunk_index", "page_number",
                      "text", "similarity"))
})

test_that("retrieve_knowledge warns on a mixed-provider corpus", {
  con <- local_rag_con()
  ingest_fake(con, "scolyte epicea",
    metadata = list(title = "M", lang = "fr", doc_type = "note"), provider = "mistral")
  ingest_fake(con, "scolyte epicea",
    metadata = list(title = "O", lang = "fr", doc_type = "note"), provider = "openai")
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  expect_warning(retrieve_knowledge(con, "scolyte", min_similarity = 0.1),
                 "mixes")
})


# ---- Integration: listing + deletion ---------------------------------

test_that("list_knowledge_documents sorts by ingestion and filters by family", {
  con <- local_rag_con()
  seed_corpus(con)
  docs <- list_knowledge_documents(con)
  expect_equal(nrow(docs), 3L)
  expect_true(is.list(docs$family_codes))
  only_p <- list_knowledge_documents(con, family = "P")
  expect_equal(nrow(only_p), 1L)
  expect_equal(only_p$title, "Site index")
})

test_that("delete_knowledge_document cascades to chunks (A7)", {
  con <- local_rag_con()
  r <- ingest_fake(con, "scolyte epicea fordead",
    metadata = list(title = "Del", lang = "fr", doc_type = "report"))
  n <- delete_knowledge_document(con, r$document_id)
  expect_equal(n, r$n_chunks)
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM knowledge_document")$n, 0L)
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM knowledge_chunk")$n, 0L)
})

test_that("ingest + retrieve + format_citations compose end to end", {
  con <- local_rag_con()
  seed_corpus(con)
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  res <- retrieve_knowledge(con, "scolyte epicea", min_similarity = 0.5)
  cit <- format_citations(res, format = "markdown")
  expect_match(cit, "## Sources documentaires")
  expect_match(cit, "FORDEAD R5")
})


# ---- reference-only ingestion (spec 009.1 §5, link_only/abstract_only) ----

test_that(".build_reference_text cites metadata and flags reference-only", {
  txt <- nemeton:::.build_reference_text(list(
    title = "TWI model", author = "Beven & Kirkby", pub_date = "1979-01-01",
    publisher = "Hydrological Sciences Bulletin",
    source_url = "https://doi.org/x", license = "copyright"))
  expect_match(txt, "TWI model")
  expect_match(txt, "Beven & Kirkby, 1979")
  expect_match(txt, "Source: https://doi.org/x")
  expect_match(txt, "Reference only")
  expect_match(txt, "copyright")
})

test_that(".build_reference_text uses the abstract when provided", {
  txt <- nemeton:::.build_reference_text(
    list(title = "T", author = "A", pub_date = "2020-01-01"),
    abstract = "A short abstract about bark beetles.")
  expect_match(txt, "Abstract: A short abstract about bark beetles\\.")
  expect_false(grepl("Reference only", txt))
})

test_that("ingest_knowledge_reference stores one link_only chunk + records the mode", {
  con <- local_rag_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  res <- ingest_knowledge_reference(con, metadata = list(
    title = "Fassnacht 2016 review", author = "Fassnacht et al.",
    pub_date = "2016-01-01", lang = "en", doc_type = "paper",
    license = "copyright", source_url = "https://doi.org/10.1016/j.rse.2016.08.013",
    family_codes = c("B", "P"), profile_codes = "chercheur"))
  expect_equal(res$n_chunks, 1L)
  expect_identical(res$ingestion_mode, "link_only")

  # The chunk holds the citation, never a full body.
  chunk <- DBI::dbGetQuery(con, "SELECT text FROM knowledge_chunk")$text
  expect_length(chunk, 1L)
  expect_match(chunk, "Fassnacht 2016 review")
  expect_match(chunk, "Reference only")

  # ingestion_mode is recorded in the JSON metadata column (no schema change).
  meta <- DBI::dbGetQuery(con, "SELECT metadata FROM knowledge_document")$metadata
  expect_match(meta, "link_only")
})

test_that("ingest_knowledge_reference with an abstract is abstract_only", {
  con <- local_rag_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  res <- ingest_knowledge_reference(con,
    metadata = list(title = "Mouret 2022", lang = "en", doc_type = "paper",
                    license = "copyright", family_codes = "R5"),
    abstract = "FORDEAD detects dieback from CRSWIR anomalies on Sentinel-2.")
  expect_identical(res$ingestion_mode, "abstract_only")
  chunk <- DBI::dbGetQuery(con, "SELECT text FROM knowledge_chunk")$text
  expect_match(chunk, "FORDEAD detects dieback")
})

test_that("ingest_knowledge_reference requires a title", {
  con <- local_rag_con()
  expect_error(
    ingest_knowledge_reference(con, metadata = list(lang = "en", doc_type = "paper")),
    "title")
})

test_that("a reference-only document is retrievable and cites cleanly", {
  con <- local_rag_con()
  testthat::local_mocked_bindings(
    .embed_texts = function(texts, ...) fake_embed(texts), .package = "nemeton")
  ingest_knowledge_reference(con, metadata = list(
    title = "Beven Kirkby TWI 1979", author = "Beven & Kirkby",
    pub_date = "1979-01-01", lang = "en", doc_type = "paper",
    license = "copyright", source_url = "https://doi.org/twi",
    family_codes = "W", profile_codes = "chercheur"))
  res <- retrieve_knowledge(con, "topographic wetness index hydrology",
                            min_similarity = 0)
  expect_gt(nrow(res), 0L)
  cit <- format_citations(res, format = "markdown")
  expect_match(cit, "Beven & Kirkby")
  expect_match(cit, "https://doi.org/twi", fixed = TRUE)
})
