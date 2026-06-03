# build_knowledge_corpus.R
#
# Thin CLI wrapper over nemeton::build_knowledge_corpus() (spec 009.2).
# All the orchestration logic (manifest parsing, license gate D5,
# eligibility, source resolution, idempotent ingestion) now lives in the
# exported package function so the nemetonshiny RAG admin tab can reuse it
# without re-implementing business logic (CLAUDE.md rules 1-3). This script
# only reads environment variables and prints the run report.
#
# LICENSE GATE (spec 009.1 D5): only rows with status == "cleared" are
# ingested. Set NEMETON_CORPUS_INGEST_TO_CONFIRM=TRUE to also ingest
# `to_confirm` rows — use only AFTER you (Pascal) have cleared their
# licenses source-by-source.
#
# Usage:
#   # dry run (no API calls) — validate manifest + print the ingestion plan
#   NEMETON_CORPUS_DRY_RUN=TRUE Rscript data-raw/build_knowledge_corpus.R
#
#   # real build into a local SQLite corpus (needs an embedding API key)
#   export MISTRAL_API_KEY=...
#   export NEMETON_KNOWLEDGE_DB_URL="sqlite:///$(pwd)/data-raw/knowledge_corpus.sqlite"
#   Rscript data-raw/build_knowledge_corpus.R
#
#   # real build into the SHARED prod corpus (same PG as the app)
#   # NOTE: there is NO automatic fallback to NEMETON_DB_URL — you point the
#   # knowledge URL at it ON PURPOSE, so the build can never write the corpus
#   # into prod by accident (cf. the NEMETON_DB_URL_TEST safety rules).
#   export MISTRAL_API_KEY=...
#   export NEMETON_KNOWLEDGE_DB_URL="$NEMETON_DB_URL"
#   Rscript data-raw/build_knowledge_corpus.R
#
# Env vars:
#   NEMETON_KNOWLEDGE_DB_URL   DB url for the corpus. Default: a LOCAL SQLite
#                              in data-raw/ (safe default — never NEMETON_DB_URL).
#   NEMETON_CORPUS_PROVIDER    embed provider: mistral (default) | openai | voyage
#   NEMETON_CORPUS_DRY_RUN     TRUE -> parse + plan only, no DB, no embedding
#   NEMETON_CORPUS_FRESH       TRUE -> delete every existing document first
#   NEMETON_CORPUS_INGEST_TO_CONFIRM  TRUE -> also ingest `to_confirm` rows

suppressMessages({
  if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
    pkgload::load_all(quiet = TRUE)
  } else {
    library(nemeton)
  }
})

is_true <- function(x) identical(toupper(Sys.getenv(x, "")), "TRUE")

provider <- Sys.getenv("NEMETON_CORPUS_PROVIDER", "mistral")
dry_run  <- is_true("NEMETON_CORPUS_DRY_RUN")
fresh    <- is_true("NEMETON_CORPUS_FRESH")
incl_tbc <- is_true("NEMETON_CORPUS_INGEST_TO_CONFIRM")
db_url   <- Sys.getenv("NEMETON_KNOWLEDGE_DB_URL",
  paste0("sqlite://", normalizePath("data-raw/knowledge_corpus.sqlite",
                                    mustWork = FALSE)))

manifest <- read_knowledge_manifest()

cli::cli_h1("Build knowledge corpus")
cli::cli_inform("Provider : {provider}{if (dry_run) ' (DRY RUN)' else ''}")
cli::cli_inform("Manifest rows : {nrow(manifest)}")

# Fail loudly on a malformed manifest before any embedding spend.
issues <- validate_knowledge_manifest(manifest)
errs <- issues[issues$severity == "error", , drop = FALSE]
if (nrow(errs)) {
  cli::cli_alert_danger("Manifest has {nrow(errs)} blocking issue{?s}:")
  for (k in seq_len(nrow(errs))) {
    cli::cli_bullets(c("x" = "{errs$doc_id[k]} / {errs$field[k]}: {errs$message[k]}"))
  }
  quit(save = "no", status = 1)
}

con <- NULL
if (!dry_run) {
  con <- db_connect(db_url)
  on.exit(db_disconnect(con), add = TRUE)
}

report <- build_knowledge_corpus(
  con, manifest = manifest, provider = provider,
  include_to_confirm = incl_tbc, fresh = fresh, dry_run = dry_run,
  pdf_dir = "data-raw/knowledge_pdfs")

if (dry_run) {
  cli::cli_h2("Ingestion plan (dry run)")
  plan <- report[report$action == "planned", , drop = FALSE]
  for (k in seq_len(nrow(plan))) {
    cli::cli_inform("- {plan$doc_id[k]} [{plan$reason[k]}]")
  }
  cli::cli_alert_info("Dry run only: no DB connection, no embedding API calls.")
  quit(save = "no", status = 0)
}

cli::cli_h2("Done")
cli::cli_inform(c(
  "v" = "ingested : {sum(report$action == 'ingested')}",
  "i" = "skipped  : {sum(report$action == 'skipped')}",
  "x" = "errors   : {sum(report$action == 'error')}"
))
