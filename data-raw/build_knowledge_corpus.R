# build_knowledge_corpus.R
#
# Builds / grows the RAG knowledge base (spec 009 + corpus spec 009.1) from
# the manifest at inst/extdata/knowledge_corpus_v1.csv.
#
# Reproducible and idempotent: re-running skips documents whose title is
# already in the knowledge base (so you can append rows to the manifest and
# re-run without duplicating).
#
# LICENSE GATE (spec 009.1 D5): only rows with status == "cleared" are
# ingested. Everything else stays `to_confirm` until you (Pascal) validate
# its license source-by-source and flip the status. The first cleared batch
# is the project's OWN content (tutorials + specs, MIT) — fully ingestible
# with zero legal arbitration.
#
# Usage:
#   # dry run (no API calls) — validate manifest + print the ingestion plan
#   NEMETON_CORPUS_DRY_RUN=TRUE Rscript data-raw/build_knowledge_corpus.R
#
#   # real build into a local SQLite corpus (needs an embedding API key)
#   export NEMETON_MISTRAL_API_KEY=...
#   export NEMETON_KNOWLEDGE_DB_URL="sqlite:///$(pwd)/data-raw/knowledge_corpus.sqlite"
#   Rscript data-raw/build_knowledge_corpus.R
#
# Env vars:
#   NEMETON_KNOWLEDGE_DB_URL   DB url (default: sqlite in data-raw/)
#   NEMETON_CORPUS_PROVIDER    embed provider: mistral (default) | openai | voyage
#   NEMETON_CORPUS_DRY_RUN     TRUE -> parse + plan only, no DB, no embedding
#   NEMETON_CORPUS_FRESH       TRUE -> delete every existing document first
#   NEMETON_CORPUS_INGEST_TO_CONFIRM  TRUE -> also ingest `to_confirm` rows
#                              that have a local_path/url (use only AFTER you
#                              have personally cleared their licenses)

suppressMessages({
  if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
    pkgload::load_all(quiet = TRUE)
  } else {
    library(nemeton)
  }
})

# ---- config ----------------------------------------------------------

is_true <- function(x) identical(toupper(Sys.getenv(x, "")), "TRUE")

manifest_path <- system.file("extdata", "knowledge_corpus_v1.csv",
                             package = "nemeton")
if (!nzchar(manifest_path)) {
  manifest_path <- "inst/extdata/knowledge_corpus_v1.csv"
}
provider   <- Sys.getenv("NEMETON_CORPUS_PROVIDER", "mistral")
dry_run    <- is_true("NEMETON_CORPUS_DRY_RUN")
fresh      <- is_true("NEMETON_CORPUS_FRESH")
incl_tbc   <- is_true("NEMETON_CORPUS_INGEST_TO_CONFIRM")
db_url     <- Sys.getenv("NEMETON_KNOWLEDGE_DB_URL",
  paste0("sqlite://", normalizePath("data-raw/knowledge_corpus.sqlite",
                                    mustWork = FALSE)))
pdf_dir    <- "data-raw/knowledge_pdfs"

cli::cli_h1("Build knowledge corpus")
cli::cli_inform("Manifest : {.path {manifest_path}}")
cli::cli_inform("Provider : {provider}{if (dry_run) ' (DRY RUN)' else ''}")

# ---- read + validate manifest ---------------------------------------

man <- utils::read.csv(manifest_path, stringsAsFactors = FALSE,
                       colClasses = "character", na.strings = c("NA"))
man[is.na(man)] <- ""
req_cols <- c("doc_id", "title", "lang", "doc_type", "license",
              "family_codes", "profile_codes", "ingest_strategy",
              "local_path", "status", "source_url")
miss <- setdiff(req_cols, names(man))
if (length(miss)) stop("Manifest is missing columns: ", paste(miss, collapse = ", "))

split_codes <- function(x) {
  x <- trimws(strsplit(x, "|", fixed = TRUE)[[1]])
  x[nzchar(x)]
}

# Which rows are eligible to ingest this run?
eligible <- (man$status == "cleared") | (incl_tbc & man$status == "to_confirm")
eligible <- eligible & (man$ingest_strategy == "full")

cli::cli_inform(c(
  "Manifest rows : {nrow(man)}",
  "Cleared       : {sum(man$status == 'cleared')}",
  "To confirm    : {sum(man$status == 'to_confirm')}",
  "Eligible now  : {sum(eligible)}{if (incl_tbc) ' (incl. to_confirm)' else ''}"
))

# ---- text resolution -------------------------------------------------

# Strip YAML front matter and ```{r}``` / ``` code fences from .Rmd/.md so we
# embed prose, not code.
clean_markdown <- function(txt) {
  txt <- sub("^---\\n.*?\\n---\\n", "", txt)              # YAML front matter
  txt <- gsub("```\\{[^}]*\\}.*?```", " ", txt)           # ```{r ...} blocks
  txt <- gsub("```.*?```", " ", txt)                      # plain fenced blocks
  txt <- gsub("`r [^`]*`", " ", txt)                      # inline r-code
  txt
}

# Return either a text string (to embed directly) or a file path (PDF, handed
# to ingest_knowledge_document which extracts it), or NULL when nothing is
# ingestible (e.g. a landing-page URL with no downloadable document).
resolve_source <- function(row) {
  lp <- row$local_path
  if (nzchar(lp) && file.exists(lp)) {
    if (grepl("\\.pdf$", lp, ignore.case = TRUE)) return(lp)         # PDF path
    txt <- paste(readLines(lp, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    if (grepl("\\.(rmd|md|markdown|qmd)$", lp, ignore.case = TRUE)) {
      txt <- clean_markdown(txt)
    }
    return(txt)
  }
  url <- row$source_url
  if (nzchar(url) && grepl("\\.pdf$", url, ignore.case = TRUE)) {
    dir.create(pdf_dir, recursive = TRUE, showWarnings = FALSE)
    dest <- file.path(pdf_dir, paste0(row$doc_id, ".pdf"))
    if (!file.exists(dest)) {
      ok <- tryCatch({
        utils::download.file(url, dest, mode = "wb", quiet = TRUE); TRUE
      }, error = function(e) FALSE)
      if (!ok) return(NULL)
    }
    return(dest)
  }
  NULL  # only a landing page / DOI without a direct PDF -> not ingestible here
}

# ---- dry run ---------------------------------------------------------

if (dry_run) {
  cli::cli_h2("Ingestion plan (dry run)")
  plan <- man[eligible, , drop = FALSE]
  for (i in seq_len(nrow(plan))) {
    r <- plan[i, ]
    src <- resolve_source(r)
    kind <- if (is.null(src)) "NO SOURCE" else if (file.exists(src) &&
      grepl("\\.pdf$", src, TRUE)) "pdf" else "text"
    cli::cli_inform("- {r$doc_id} [{kind}] {r$title}")
  }
  cli::cli_alert_info("Dry run only: no DB connection, no embedding API calls.")
  quit(save = "no", status = 0)
}

# ---- real build ------------------------------------------------------

con <- db_connect(db_url)
on.exit(db_disconnect(con), add = TRUE)
suppressMessages(enable_rag(con))

if (fresh) {
  existing <- list_knowledge_documents(con)
  for (id in existing$id) delete_knowledge_document(con, id)
  cli::cli_alert_warning("Fresh build: deleted {nrow(existing)} existing document{?s}.")
}

already <- tryCatch(list_knowledge_documents(con)$title, error = function(e) character(0))

n_ok <- 0L; n_skip <- 0L; n_err <- 0L
for (i in seq_len(nrow(man))) {
  r <- man[i, ]
  if (!eligible[i]) { n_skip <- n_skip + 1L; next }
  if (r$title %in% already) {
    cli::cli_alert_info("skip (already ingested): {r$doc_id}")
    n_skip <- n_skip + 1L; next
  }
  src <- resolve_source(r)
  if (is.null(src)) {
    cli::cli_alert_warning("skip (no ingestible source): {r$doc_id}")
    n_skip <- n_skip + 1L; next
  }
  meta <- list(
    title         = r$title,
    lang          = r$lang,
    doc_type      = r$doc_type,
    license       = r$license,
    author        = if (nzchar(r$author)) r$author else NULL,
    publisher     = if (nzchar(r$publisher)) r$publisher else NULL,
    pub_date      = if (nzchar(r$pub_date)) r$pub_date else NULL,
    source_url    = if (nzchar(r$source_url)) r$source_url else NULL,
    family_codes  = split_codes(r$family_codes),
    profile_codes = split_codes(r$profile_codes),
    ingested_by   = "build_knowledge_corpus.R",
    extra         = list(doc_id = r$doc_id,
                         license_commercial_ok = identical(toupper(r$license_commercial_ok), "TRUE"))
  )
  res <- tryCatch(
    ingest_knowledge_document(con, src, metadata = meta, embed_provider = provider),
    error = function(e) { cli::cli_alert_danger("error {r$doc_id}: {conditionMessage(e)}"); NULL }
  )
  if (is.null(res)) { n_err <- n_err + 1L; next }
  cli::cli_alert_success("ingested {r$doc_id}: {res$n_chunks} chunk{?s}")
  n_ok <- n_ok + 1L
}

cli::cli_h2("Done")
cli::cli_inform(c(
  "v" = "ingested : {n_ok}",
  "i" = "skipped  : {n_skip}",
  "x" = "errors   : {n_err}"
))
