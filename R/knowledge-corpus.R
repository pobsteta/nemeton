#' Knowledge-corpus manifest and ingestion orchestration (spec 009.2)
#'
#' @description
#' Public API around the RAG knowledge-corpus manifest
#' (`inst/extdata/knowledge_corpus_v1.csv`, spec 009.1) and the
#' manifest-to-database ingestion pipeline. This promotes the logic that
#' used to live only in `data-raw/build_knowledge_corpus.R` into exported,
#' testable functions, so that a `nemetonshiny` administration tab can
#' edit the manifest and import the corpus **without re-implementing any
#' business logic** (CLAUDE.md rules 1-3).
#'
#' The packaged CSV is the versioned **seed**; an editable **project copy**
#' is resolved by [knowledge_manifest_path()] (`writable = TRUE`) and
#' seeded from the package on first use (spec 009.2 D1).
#'
#' @name knowledge-corpus
NULL


# ---- Controlled vocabularies (single source of truth) ----------------

# Canonical strings for the manifest enum columns. Extending the corpus
# with a genuinely new value means adding it here on purpose. The manifest
# integrity test (test-knowledge-corpus-manifest.R) consumes these via
# knowledge_manifest_vocab() instead of duplicating them.
.KNOWLEDGE_LICENSES <- c(
  "public-domain", "domaine-public", "MIT", "HAL",
  "LO-Etalab", "LO-Etalab-2.0", "OGL-Etalab",
  "CC-BY", "CC-BY-NC", "CC-BY-SA",
  "EUR-Lex-reutilisable", "usage-libre-IPCC",
  "autorisation-explicite", "explicit-auth",
  "acte-reglementaire", "admin",
  "copyright", "to-confirm")

.KNOWLEDGE_STATUSES   <- c("cleared", "to_confirm")
.KNOWLEDGE_STRATEGIES <- c("full", "abstract_only", "link_only")
.KNOWLEDGE_LANGS      <- c("fr", "en")
.KNOWLEDGE_DOC_TYPES  <- c("manual", "note", "paper", "regulation", "report",
                           "guide", "law", "dataset_doc")

# The 15 acteur profiles (short forms, cf. CLAUDE.md) + the wildcard.
.KNOWLEDGE_PROFILES <- c(
  "proprietaire_prive", "proprietaire_public",
  "gestionnaire_onf", "gestionnaire_coop", "gestionnaire_expert",
  "technicien", "naturaliste", "elu_local", "elu_regional",
  "chasseur", "industrie_bois", "bucheron", "chercheur",
  "citoyen", "investisseur", "tous")

# A valid family token is the wildcard "Toutes" or one of the 12 family
# letters optionally followed by a sub-indicator digit (e.g. R, R5, C1).
.KNOWLEDGE_FAMILY_RE <- "^(Toutes|[BCWAFLTRSPEN][0-9]?)$"

# The 16 manifest columns, in canonical order.
.KNOWLEDGE_MANIFEST_COLS <- c(
  "doc_id", "title", "author", "publisher", "pub_date", "lang",
  "doc_type", "source_url", "license", "license_commercial_ok",
  "family_codes", "profile_codes", "ingest_strategy", "local_path",
  "status", "notes")


#' Controlled vocabularies for the knowledge-corpus manifest
#'
#' Returns the canonical value sets used to validate
#' `inst/extdata/knowledge_corpus_v1.csv`. This is the single source of
#' truth: both [validate_knowledge_manifest()] and the manifest integrity
#' tests consume it, and a `nemetonshiny` editor can use it to populate the
#' drop-downs of the enum columns.
#'
#' @return A named list with elements `columns`, `licenses`, `statuses`,
#'   `strategies`, `langs`, `doc_types`, `profiles`, and `family_regex`.
#'
#' @seealso [validate_knowledge_manifest()], [read_knowledge_manifest()].
#' @export
knowledge_manifest_vocab <- function() {
  list(
    columns      = .KNOWLEDGE_MANIFEST_COLS,
    licenses     = .KNOWLEDGE_LICENSES,
    statuses     = .KNOWLEDGE_STATUSES,
    strategies   = .KNOWLEDGE_STRATEGIES,
    langs        = .KNOWLEDGE_LANGS,
    doc_types    = .KNOWLEDGE_DOC_TYPES,
    profiles     = .KNOWLEDGE_PROFILES,
    family_regex = .KNOWLEDGE_FAMILY_RE
  )
}


# ---- Manifest path resolution ----------------------------------------

# The packaged seed: system.file when installed, the source tree otherwise.
.knowledge_seed_path <- function() {
  p <- system.file("extdata", "knowledge_corpus_v1.csv", package = "nemeton")
  if (nzchar(p) && file.exists(p)) return(p)
  fallback <- file.path("inst", "extdata", "knowledge_corpus_v1.csv")
  if (file.exists(fallback)) return(fallback)
  cli::cli_abort(c(
    "Packaged manifest {.path knowledge_corpus_v1.csv} not found.",
    "i" = "Reinstall {.pkg nemeton} or run from the package source tree."
  ))
}

#' Resolve the path to the knowledge-corpus manifest
#'
#' The packaged CSV (`inst/extdata/knowledge_corpus_v1.csv`) is the
#' versioned **seed** and is read-only once the package is installed.
#' Editing the manifest from an application therefore works on a writable
#' **project copy** (spec 009.2 D1).
#'
#' @param writable Logical. `FALSE` (default) returns the packaged seed.
#'   `TRUE` returns the writable project copy, resolved from
#'   `NEMETON_KNOWLEDGE_MANIFEST` (or, if unset, a default under
#'   [tools::R_user_dir()]). When the writable copy does not exist yet it
#'   is created by copying the seed (idempotent).
#'
#' @return A character scalar path.
#'
#' @seealso [read_knowledge_manifest()], [write_knowledge_manifest()].
#' @export
knowledge_manifest_path <- function(writable = FALSE) {
  if (!isTRUE(writable)) {
    return(.knowledge_seed_path())
  }
  path <- Sys.getenv("NEMETON_KNOWLEDGE_MANIFEST", "")
  if (!nzchar(path)) {
    path <- file.path(tools::R_user_dir("nemeton", "data"),
                      "knowledge_corpus.csv")
  }
  if (!file.exists(path)) {
    parent <- dirname(path)
    if (!dir.exists(parent)) dir.create(parent, recursive = TRUE, showWarnings = FALSE)
    file.copy(.knowledge_seed_path(), path, overwrite = FALSE)
  }
  path
}


#' Reset the writable knowledge manifest to the packaged corpus
#'
#' Overwrites the writable project copy of the manifest (the one edited
#' from the application, returned by `knowledge_manifest_path(writable =
#' TRUE)`) with the seed bundled in the installed package.
#'
#' The writable copy is created **once** and never auto-refreshed, so
#' that edits made from the app survive package updates (spec 009.2 D1).
#' The flip side is that a copy created against an old corpus keeps
#' listing documents the package no longer ships. Call this to pull the
#' current packaged corpus explicitly — typically wired to a
#' "reset to packaged corpus" action in the RAG admin tab.
#'
#' @param confirm Logical. Must be `TRUE` (default) to proceed; the
#'   parameter exists so the caller passes an explicit user
#'   confirmation before discarding the writable copy.
#'
#' @return The path to the refreshed writable manifest (invisibly).
#'
#' @seealso [knowledge_manifest_path()], [read_knowledge_manifest()].
#' @export
reset_knowledge_manifest <- function(confirm = TRUE) {
  if (!isTRUE(confirm)) {
    cli::cli_abort(c(
      "{.fn reset_knowledge_manifest} overwrites the writable manifest copy.",
      "i" = "Call with {.code confirm = TRUE} to proceed."
    ))
  }
  seed <- .knowledge_seed_path()
  dest <- knowledge_manifest_path(writable = TRUE)
  if (!file.copy(seed, dest, overwrite = TRUE)) {
    cli::cli_abort("Failed to refresh the writable manifest at {.path {dest}}.")
  }
  cli::cli_alert_success(
    "Knowledge manifest reset to the packaged corpus at {.path {dest}}.")
  invisible(dest)
}


# ---- Read / write ----------------------------------------------------

#' Read the knowledge-corpus manifest
#'
#' Reads the manifest CSV into a typed (all-character) data.frame with
#' `NA` normalised to `""`, matching the contract of the ingestion
#' pipeline. Performs no semantic validation beyond requiring the 16
#' expected columns — use [validate_knowledge_manifest()] for that.
#'
#' @param path Character. Defaults to the packaged seed
#'   ([knowledge_manifest_path()]).
#'
#' @return A data.frame with the manifest columns.
#'
#' @seealso [validate_knowledge_manifest()], [write_knowledge_manifest()],
#'   [build_knowledge_corpus()].
#' @export
read_knowledge_manifest <- function(path = knowledge_manifest_path()) {
  if (!is.character(path) || length(path) != 1L || !file.exists(path)) {
    cli::cli_abort("{.arg path} must point to an existing manifest CSV file.")
  }
  man <- utils::read.csv(path, stringsAsFactors = FALSE,
                         colClasses = "character", na.strings = "NA")
  man[is.na(man)] <- ""
  miss <- setdiff(.KNOWLEDGE_MANIFEST_COLS, names(man))
  if (length(miss)) {
    cli::cli_abort("Manifest is missing column{?s}: {.val {miss}}.")
  }
  man
}


# Quote a single CSV field only when it contains a comma, double quote or
# newline (escaping embedded quotes by doubling). Reproduces the minimal
# quoting of the packaged manifest so git diffs stay clean.
.csv_quote <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  needs <- grepl('[",\n\r]', x)
  x[needs] <- paste0('"', gsub('"', '""', x[needs]), '"')
  x
}

#' Write the knowledge-corpus manifest
#'
#' Validates the manifest (unless `validate = FALSE`) and writes it back as
#' CSV with deterministic, minimal quoting so version-control diffs stay
#' readable. Refuses to write a manifest carrying `error`-severity issues.
#'
#' @param manifest A data.frame, e.g. from [read_knowledge_manifest()].
#' @param path Character. Defaults to the writable project copy
#'   ([knowledge_manifest_path()] with `writable = TRUE`).
#' @param validate Logical. When `TRUE` (default), abort if
#'   [validate_knowledge_manifest()] reports any `error` issue.
#'
#' @return Invisibly, the path written.
#'
#' @seealso [read_knowledge_manifest()], [validate_knowledge_manifest()].
#' @export
write_knowledge_manifest <- function(manifest,
                                     path = knowledge_manifest_path(writable = TRUE),
                                     validate = TRUE) {
  if (!is.data.frame(manifest)) {
    cli::cli_abort("{.arg manifest} must be a data.frame.")
  }
  if (isTRUE(validate)) {
    issues <- validate_knowledge_manifest(manifest)
    errs <- issues[issues$severity == "error", , drop = FALSE]
    if (nrow(errs)) {
      bullets <- sprintf("[%s] %s: %s", errs$doc_id, errs$field, errs$message)
      names(bullets) <- rep("x", length(bullets))
      cli::cli_abort(c(
        "Refusing to write: manifest has {nrow(errs)} blocking issue{?s}.",
        bullets,
        "i" = "Fix them, or call with {.code validate = FALSE} to force."
      ))
    }
  }
  # Canonical column order; keep any extra columns (e.g. abstract) after.
  cols <- c(intersect(.KNOWLEDGE_MANIFEST_COLS, names(manifest)),
            setdiff(names(manifest), .KNOWLEDGE_MANIFEST_COLS))
  man <- manifest[, cols, drop = FALSE]
  parent <- dirname(path)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  body <- vapply(seq_len(nrow(man)), function(i) {
    paste(.csv_quote(unlist(man[i, ], use.names = FALSE)), collapse = ",")
  }, character(1))
  lines <- c(paste(cols, collapse = ","), body)
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}


# ---- Validation ------------------------------------------------------

.split_manifest_codes <- function(x) {
  x <- trimws(unlist(strsplit(as.character(x), "|", fixed = TRUE)))
  x[nzchar(x)]
}

.is_reference_strategy <- function(strategy) {
  strategy %in% c("abstract_only", "link_only")
}

#' Validate the knowledge-corpus manifest
#'
#' Checks every integrity invariant of the manifest (spec 009.1 §6 / D5):
#' structure, controlled enums, recognised family / profile codes, and the
#' license-gate safety rules (a `cleared` row never carries an unconfirmed
#' license; a `copyright` document is never full-text ingested; a declared
#' `local_path` has an ingestible extension).
#'
#' Returns the issues as data rather than aborting, so a caller (e.g. a
#' `nemetonshiny` editor) can surface them inline.
#'
#' @param manifest A data.frame, e.g. from [read_knowledge_manifest()].
#'
#' @return A data.frame with columns `row` (1-based row index, `NA` for
#'   table-level issues), `doc_id`, `severity` (`"error"` or `"warning"`),
#'   `field`, and `message`. Zero rows means the manifest is valid.
#'
#' @seealso [knowledge_manifest_vocab()], [write_knowledge_manifest()].
#' @export
validate_knowledge_manifest <- function(manifest) {
  if (!is.data.frame(manifest)) {
    cli::cli_abort("{.arg manifest} must be a data.frame.")
  }
  issues <- list()
  add <- function(row, doc_id, severity, field, message) {
    issues[[length(issues) + 1L]] <<- data.frame(
      row = row, doc_id = doc_id, severity = severity,
      field = field, message = message, stringsAsFactors = FALSE)
  }

  # ---- structure
  miss <- setdiff(.KNOWLEDGE_MANIFEST_COLS, names(manifest))
  for (m in miss) {
    add(NA_integer_, NA_character_, "error", m, "missing required column")
  }
  if (length(miss)) return(.bind_issues(issues))   # cannot check rows reliably

  m <- manifest
  m[is.na(m)] <- ""
  n <- nrow(m)
  if (!n) return(.bind_issues(issues))

  dup <- duplicated(m$doc_id) | duplicated(m$doc_id, fromLast = TRUE)
  for (i in seq_len(n)) {
    id <- m$doc_id[i]

    # ---- doc_id / title
    if (!nzchar(id)) {
      add(i, id, "error", "doc_id", "doc_id is empty")
    } else if (!grepl("^[a-z0-9_]+$", id)) {
      add(i, id, "error", "doc_id", "doc_id is not a slug (^[a-z0-9_]+$)")
    }
    if (dup[i]) add(i, id, "error", "doc_id", "duplicate doc_id")
    if (!nzchar(m$title[i])) add(i, id, "error", "title", "title is empty")

    # ---- enums
    if (!m$lang[i] %in% .KNOWLEDGE_LANGS) {
      add(i, id, "error", "lang", sprintf("unknown lang '%s'", m$lang[i]))
    }
    if (!m$status[i] %in% .KNOWLEDGE_STATUSES) {
      add(i, id, "error", "status", sprintf("unknown status '%s'", m$status[i]))
    }
    if (!m$ingest_strategy[i] %in% .KNOWLEDGE_STRATEGIES) {
      add(i, id, "error", "ingest_strategy",
          sprintf("unknown ingest_strategy '%s'", m$ingest_strategy[i]))
    }
    if (!m$doc_type[i] %in% .KNOWLEDGE_DOC_TYPES) {
      add(i, id, "error", "doc_type", sprintf("unknown doc_type '%s'", m$doc_type[i]))
    }
    if (!toupper(m$license_commercial_ok[i]) %in% c("TRUE", "FALSE")) {
      add(i, id, "error", "license_commercial_ok",
          sprintf("must be TRUE/FALSE, got '%s'", m$license_commercial_ok[i]))
    }
    if (!m$license[i] %in% .KNOWLEDGE_LICENSES) {
      add(i, id, "error", "license", sprintf("unknown license '%s'", m$license[i]))
    }

    # ---- family / profile codes (recognised + non-empty)
    if (!nzchar(m$family_codes[i])) {
      add(i, id, "error", "family_codes", "no family code (row unreachable by retrieval)")
    } else {
      bad <- Filter(function(f) !grepl(.KNOWLEDGE_FAMILY_RE, f),
                    .split_manifest_codes(m$family_codes[i]))
      if (length(bad)) {
        add(i, id, "error", "family_codes",
            sprintf("unknown family code(s): %s", paste(bad, collapse = ", ")))
      }
    }
    if (!nzchar(m$profile_codes[i])) {
      add(i, id, "error", "profile_codes", "no profile code (row unreachable by retrieval)")
    } else {
      bad <- setdiff(.split_manifest_codes(m$profile_codes[i]), .KNOWLEDGE_PROFILES)
      if (length(bad)) {
        add(i, id, "error", "profile_codes",
            sprintf("unknown profile code(s): %s", paste(bad, collapse = ", ")))
      }
    }

    # ---- license gate (D5): a cleared row WILL be ingested
    if (identical(m$status[i], "cleared")) {
      if (!nzchar(m$license[i])) {
        add(i, id, "error", "license", "cleared row with empty license (D5)")
      } else if (identical(m$license[i], "to-confirm")) {
        add(i, id, "error", "license", "cleared row with `to-confirm` license (D5)")
      }
    }
    # ---- copyright is never full-text ingested (009.1 §5)
    if (identical(m$license[i], "copyright") && identical(m$ingest_strategy[i], "full")) {
      add(i, id, "error", "ingest_strategy",
          "copyright document marked `full` (must be abstract_only/link_only)")
    }
    # ---- a declared local_path has an ingestible extension
    if (nzchar(m$local_path[i]) &&
        !grepl("\\.(pdf|rmd|md|markdown|qmd)$", m$local_path[i], ignore.case = TRUE)) {
      add(i, id, "warning", "local_path",
          sprintf("non-ingestible local_path extension: %s", m$local_path[i]))
    }
  }

  .bind_issues(issues)
}

.bind_issues <- function(issues) {
  if (!length(issues)) {
    return(data.frame(
      row = integer(0), doc_id = character(0), severity = character(0),
      field = character(0), message = character(0), stringsAsFactors = FALSE))
  }
  do.call(rbind, issues)
}


# ---- Source resolution -----------------------------------------------

# Strip YAML front matter and ```{r}``` / ``` code fences from .Rmd/.md so
# we embed prose, not code.
.clean_markdown <- function(txt) {
  txt <- sub("^---\\n.*?\\n---\\n", "", txt)         # YAML front matter
  txt <- gsub("```\\{[^}]*\\}.*?```", " ", txt)      # ```{r ...} blocks
  txt <- gsub("```.*?```", " ", txt)                 # plain fenced blocks
  txt <- gsub("`r [^`]*`", " ", txt)                 # inline r-code
  txt
}

# Return either a text string (embed directly), a file path (PDF, handed to
# ingest_knowledge_document for extraction), or NULL when nothing ingestible
# (e.g. a landing-page URL with no downloadable document).
.resolve_manifest_source <- function(row, pdf_dir) {
  lp <- row$local_path
  if (nzchar(lp) && file.exists(lp)) {
    if (grepl("\\.pdf$", lp, ignore.case = TRUE)) return(lp)
    txt <- paste(readLines(lp, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    if (grepl("\\.(rmd|md|markdown|qmd)$", lp, ignore.case = TRUE)) {
      txt <- .clean_markdown(txt)
    }
    return(txt)
  }
  url <- row$source_url
  if (nzchar(url) && grepl("\\.pdf$", url, ignore.case = TRUE)) {
    if (!dir.exists(pdf_dir)) dir.create(pdf_dir, recursive = TRUE, showWarnings = FALSE)
    dest <- file.path(pdf_dir, paste0(row$doc_id, ".pdf"))
    if (!file.exists(dest)) {
      ok <- tryCatch({
        utils::download.file(url, dest, mode = "wb", quiet = TRUE); TRUE
      }, error = function(e) FALSE)
      if (!ok) return(NULL)
    }
    return(dest)
  }
  NULL
}

.manifest_abstract <- function(row) {
  if ("abstract" %in% names(row) && nzchar(row$abstract)) row$abstract else NULL
}

# Build the per-document metadata list consumed by the ingestion functions.
.manifest_row_metadata <- function(row) {
  list(
    title         = row$title,
    lang          = row$lang,
    doc_type      = row$doc_type,
    license       = row$license,
    author        = if (nzchar(row$author)) row$author else NULL,
    publisher     = if (nzchar(row$publisher)) row$publisher else NULL,
    pub_date      = if (nzchar(row$pub_date)) row$pub_date else NULL,
    source_url    = if (nzchar(row$source_url)) row$source_url else NULL,
    family_codes  = .split_manifest_codes(row$family_codes),
    profile_codes = .split_manifest_codes(row$profile_codes),
    ingested_by   = "build_knowledge_corpus",
    extra         = list(
      doc_id = row$doc_id,
      license_commercial_ok = identical(toupper(row$license_commercial_ok), "TRUE"))
  )
}

.empty_corpus_report <- function() {
  data.frame(
    doc_id = character(0), action = character(0), reason = character(0),
    mode = character(0), n_chunks = integer(0), document_id = integer(0),
    duration_sec = numeric(0), stringsAsFactors = FALSE)
}

.corpus_report_row <- function(doc_id, action, reason = NA_character_,
                               mode = NA_character_, n_chunks = NA_integer_,
                               document_id = NA_integer_, duration_sec = NA_real_) {
  data.frame(
    doc_id = doc_id, action = action, reason = reason, mode = mode,
    n_chunks = as.integer(n_chunks), document_id = as.integer(document_id),
    duration_sec = as.numeric(duration_sec), stringsAsFactors = FALSE)
}


#' Build (or grow) the RAG knowledge base from the manifest
#'
#' Iterates over the manifest and ingests every eligible document into the
#' knowledge base, applying the same license gate (D5), eligibility and
#' idempotency rules as `data-raw/build_knowledge_corpus.R` — which is now
#' a thin wrapper over this function. Unlike the script it is a plain,
#' blocking R function returning a structured report, so an application can
#' drive it asynchronously and render progress.
#'
#' A row is eligible when its `ingest_strategy` is known and its `status`
#' is `cleared` (or `to_confirm` when `include_to_confirm = TRUE`). `full`
#' rows ingest their body via [ingest_knowledge_document()]; `abstract_only`
#' / `link_only` rows ingest a reference-only chunk via
#' [ingest_knowledge_reference()]. Documents whose `title` is already in the
#' base are skipped (idempotent re-runs).
#'
#' @param con A `DBIConnection` ([db_connect()]). May be `NULL` only when
#'   `dry_run = TRUE`. The RAG schema is enabled if needed.
#' @param manifest A data.frame ([read_knowledge_manifest()]).
#' @param provider Embedding provider, one of `"mistral"` (default),
#'   `"openai"`, `"voyage"`.
#' @param include_to_confirm Logical. Also ingest `to_confirm` rows. Use
#'   only after personally clearing their licenses. Default `FALSE`.
#' @param fresh Logical. Delete every existing document first. Default
#'   `FALSE`.
#' @param dry_run Logical. Parse and plan only — no DB connection, no
#'   embedding API calls. Default `FALSE`.
#' @param pdf_dir Directory for downloaded PDFs. Default a per-user cache
#'   dir under [tools::R_user_dir()].
#' @param api_key Optional embedding API key (else the provider's
#'   environment variable).
#' @param progress Optional callback `function(i, n, row, report_row)`
#'   invoked after each manifest row, for progress reporting.
#'
#' @return A data.frame report, one row per manifest row, with columns
#'   `doc_id`, `action` (`"ingested"`, `"skipped"`, `"error"`, or
#'   `"planned"` in a dry run), `reason`, `mode`, `n_chunks`,
#'   `document_id`, `duration_sec`.
#'
#' @seealso [read_knowledge_manifest()], [ingest_knowledge_document()],
#'   [ingest_knowledge_reference()], [list_knowledge_documents()].
#' @export
build_knowledge_corpus <- function(con = NULL,
                                   manifest = read_knowledge_manifest(),
                                   provider = c("mistral", "openai", "voyage"),
                                   include_to_confirm = FALSE,
                                   fresh = FALSE,
                                   dry_run = FALSE,
                                   pdf_dir = NULL,
                                   api_key = NULL,
                                   progress = NULL) {
  provider <- match.arg(provider)
  if (!is.data.frame(manifest)) {
    cli::cli_abort("{.arg manifest} must be a data.frame.")
  }
  miss <- setdiff(.KNOWLEDGE_MANIFEST_COLS, names(manifest))
  if (length(miss)) {
    cli::cli_abort("Manifest is missing column{?s}: {.val {miss}}.")
  }
  if (!is.null(progress) && !is.function(progress)) {
    cli::cli_abort("{.arg progress} must be a function or NULL.")
  }
  if (is.null(pdf_dir)) {
    pdf_dir <- file.path(tools::R_user_dir("nemeton", "cache"), "knowledge_pdfs")
  }
  man <- manifest
  man[is.na(man)] <- ""
  n <- nrow(man)

  known_strategy <- man$ingest_strategy %in% .KNOWLEDGE_STRATEGIES
  eligible <- (man$status == "cleared") |
              (isTRUE(include_to_confirm) & man$status == "to_confirm")
  eligible <- eligible & known_strategy

  emit <- function(i, rep_row) {
    if (!is.null(progress)) progress(i, n, man[i, , drop = FALSE], rep_row)
    rep_row
  }

  # ---- dry run: plan only, no DB / embeddings
  if (isTRUE(dry_run)) {
    rows <- lapply(seq_len(n), function(i) {
      r <- man[i, , drop = FALSE]
      if (!eligible[i]) {
        rr <- .corpus_report_row(r$doc_id, "skipped",
          reason = sprintf("not eligible (status=%s)", r$status))
        return(emit(i, rr))
      }
      if (.is_reference_strategy(r$ingest_strategy)) {
        mode <- if (!is.null(.manifest_abstract(r))) "abstract_only" else "link_only"
        return(emit(i, .corpus_report_row(r$doc_id, "planned", reason = mode, mode = mode)))
      }
      src <- .resolve_manifest_source(r, pdf_dir)
      if (is.null(src)) {
        return(emit(i, .corpus_report_row(r$doc_id, "skipped", reason = "no ingestible source")))
      }
      kind <- if (file.exists(src) && grepl("\\.pdf$", src, ignore.case = TRUE)) "pdf" else "text"
      emit(i, .corpus_report_row(r$doc_id, "planned", reason = kind, mode = "full"))
    })
    return(do.call(rbind, c(list(.empty_corpus_report()), rows)))
  }

  # ---- real build
  if (is.null(con) || !inherits(con, "DBIConnection")) {
    cli::cli_abort("{.arg con} must be a {.cls DBIConnection} unless {.code dry_run = TRUE}.")
  }
  suppressMessages(enable_rag(con))
  if (isTRUE(fresh)) {
    existing <- list_knowledge_documents(con)
    for (id in existing$id) delete_knowledge_document(con, id)
  }
  already <- tryCatch(list_knowledge_documents(con)$title, error = function(e) character(0))

  rows <- lapply(seq_len(n), function(i) {
    r <- man[i, , drop = FALSE]
    if (!eligible[i]) {
      return(emit(i, .corpus_report_row(r$doc_id, "skipped",
        reason = sprintf("not eligible (status=%s)", r$status))))
    }
    if (r$title %in% already) {
      return(emit(i, .corpus_report_row(r$doc_id, "skipped", reason = "already ingested")))
    }
    reference <- .is_reference_strategy(r$ingest_strategy)
    src <- if (reference) NULL else .resolve_manifest_source(r, pdf_dir)
    if (!reference && is.null(src)) {
      return(emit(i, .corpus_report_row(r$doc_id, "skipped", reason = "no ingestible source")))
    }
    meta <- .manifest_row_metadata(r)
    res <- tryCatch(
      if (reference) {
        ingest_knowledge_reference(con, metadata = meta,
                                   abstract = .manifest_abstract(r),
                                   embed_provider = provider, api_key = api_key)
      } else {
        ingest_knowledge_document(con, src, metadata = meta,
                                  embed_provider = provider, api_key = api_key)
      },
      error = function(e) structure(conditionMessage(e), class = "corpus_error")
    )
    if (inherits(res, "corpus_error")) {
      return(emit(i, .corpus_report_row(r$doc_id, "error", reason = as.character(res))))
    }
    mode <- if (reference) res$ingestion_mode else "full"
    emit(i, .corpus_report_row(r$doc_id, "ingested", reason = NA_character_,
                               mode = mode, n_chunks = res$n_chunks,
                               document_id = res$document_id,
                               duration_sec = res$duration_sec))
  })
  do.call(rbind, c(list(.empty_corpus_report()), rows))
}
