# Build (or grow) the RAG knowledge base from the manifest

Iterates over the manifest and ingests every eligible document into the
knowledge base, applying the same license gate (D5), eligibility and
idempotency rules as \`data-raw/build_knowledge_corpus.R\` — which is
now a thin wrapper over this function. Unlike the script it is a plain,
blocking R function returning a structured report, so an application can
drive it asynchronously and render progress.

## Usage

``` r
build_knowledge_corpus(
  con = NULL,
  manifest = read_knowledge_manifest(),
  provider = c("mistral", "openai", "voyage"),
  include_to_confirm = FALSE,
  fresh = FALSE,
  dry_run = FALSE,
  pdf_dir = NULL,
  api_key = NULL,
  progress = NULL
)
```

## Arguments

- con:

  A \`DBIConnection\` (\[db_connect()\]). May be \`NULL\` only when
  \`dry_run = TRUE\`. The RAG schema is enabled if needed.

- manifest:

  A data.frame (\[read_knowledge_manifest()\]).

- provider:

  Embedding provider, one of \`"mistral"\` (default), \`"openai"\`,
  \`"voyage"\`.

- include_to_confirm:

  Logical. Also ingest \`to_confirm\` rows. Use only after personally
  clearing their licenses. Default \`FALSE\`.

- fresh:

  Logical. Delete every existing document first, in a single transaction
  (a failure leaves the corpus untouched). Default \`FALSE\`.

- dry_run:

  Logical. Parse and plan only — no DB connection, no embedding API
  calls, no download: a \`full\` row is planned from the existence of
  its \`local_path\` or the shape of its PDF \`source_url\` (reason
  \`"pdf (to download)"\` when not yet cached). Default \`FALSE\`.

- pdf_dir:

  Directory for downloaded PDFs. Default a per-user cache dir under
  \[tools::R_user_dir()\]. A cached file is reused only when it carries
  the PDF file signature; downloads are written to a temporary file and
  moved into place once checked.

- api_key:

  Optional embedding API key (else the provider's environment variable).

- progress:

  Optional callback \`function(i, n, row, report_row)\` invoked after
  each manifest row, for progress reporting.

## Value

A data.frame report, one row per manifest row, with columns \`doc_id\`,
\`action\` (\`"ingested"\`, \`"skipped"\`, \`"error"\`, or \`"planned"\`
in a dry run), \`reason\`, \`mode\`, \`n_chunks\`, \`document_id\`,
\`duration_sec\`. A row skipped because its declared \`local_path\` is
not found under the corpus root names that path and the root in
\`reason\`.

## Details

A row is eligible when its \`ingest_strategy\` is known and its
\`status\` is \`cleared\` (or \`to_confirm\` when \`include_to_confirm =
TRUE\`). \`full\` rows ingest their body via
\[ingest_knowledge_document()\]; \`abstract_only\` / \`link_only\` rows
ingest a reference-only chunk via \[ingest_knowledge_reference()\].
Documents whose manifest \`doc_id\` is already in the base are skipped
(idempotent re-runs); a document ingested outside the manifest (no
\`doc_id\` in its metadata) is matched on its \`title\`.

## Security

The manifest is editable from an application, so its paths are not
trusted. A \`local_path\` must have an allowed extension (\`.pdf\`,
\`.txt\`, \`.md\`, \`.markdown\`, \`.rmd\`, \`.qmd\`) and resolve
(symbolic links and \`..\` included) under the corpus root: option
\`nemeton.corpus_root\`, else the \`NEMETON_CORPUS_ROOT\` environment
variable, else the working directory. Relative paths are resolved
against that root. Only \`http://\` / \`https://\` \`source_url\`s are
downloaded. A row breaking these rules, or whose \`doc_id\` is not a
slug (\`^\[a-z0-9\_\]+\$\`), is reported with \`action = "error"\`.

## See also

\[read_knowledge_manifest()\], \[ingest_knowledge_document()\],
\[ingest_knowledge_reference()\], \[list_knowledge_documents()\].
