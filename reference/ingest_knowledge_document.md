# Ingest a document into the RAG knowledge base

Extracts text from a PDF / \`.txt\` / \`.md\` file (or a raw string),
splits it into overlapping chunks, embeds each chunk via the chosen
provider, and writes the document and its chunks to the knowledge base.
Runs in a single transaction so a failed embedding rolls back cleanly.

\*\*No duplicates.\*\* Before any embedding call, the chunk fingerprints
(\`knowledge_chunk.text_hash\`, in \`chunk_index\` order) are compared
with the documents already in the base. When an existing document has
exactly the same sequence (same content, chunked with the same
\`chunk_size\` / \`chunk_overlap\`), nothing is embedded or inserted: a
message names the existing document and its \`document_id\` is returned
with \`duplicate = TRUE\`.

## Usage

``` r
ingest_knowledge_document(
  con,
  source,
  metadata = list(),
  chunk_size = 512L,
  chunk_overlap = 50L,
  embed_provider = c("mistral", "openai", "voyage"),
  api_key = NULL
)
```

## Arguments

- con:

  A \`DBIConnection\`. RAG schema must be enabled (\[enable_rag()\]).

- source:

  Character. A path to a \`.pdf\` / \`.txt\` / \`.md\` file, or a raw
  text string. PDFs are split one segment per page so chunks carry a
  \`page_number\`. A single-line string that looks like a file path
  (ends with a supported extension, starts with \`/\`, \`./\`, \`~/\`,
  ..., or is a space-free path with an extension) must name an existing
  supported file, otherwise an error is raised instead of embedding the
  path itself as text.

- metadata:

  Named list. Required: \`title\`, \`lang\` (ISO 639-1), \`doc_type\`
  (one of \`knowledge_manifest_vocab()\$doc_types\`: \`manual\`,
  \`note\`, \`paper\`, \`regulation\`, \`report\`, \`guide\`, \`law\`,
  \`dataset_doc\`, \`web\`). Optional: \`author\`, \`publisher\`,
  \`pub_date\`, \`source_url\`, \`license\` (default \`"unknown"\`),
  \`family_codes\`, \`profile_codes\`, \`ingested_by\`, and \`extra\` (a
  list stored as JSON \`metadata\`).

- chunk_size, chunk_overlap:

  Integer. Target chunk size and overlap, in estimated tokens. Defaults
  512 / 50.

- embed_provider:

  One of \`"mistral"\` (default), \`"openai"\`, \`"voyage"\`.

- api_key:

  Character or \`NULL\`. Defaults to the provider's
  \`NEMETON\_\<PROVIDER\>\_API_KEY\` (or \`\<PROVIDER\>\_API_KEY\`)
  environment variable.

## Value

Invisibly, a list with \`document_id\`, \`n_chunks\`, \`n_tokens_est\`,
\`duration_sec\` and \`duplicate\` (\`TRUE\` when the content was
already ingested: \`document_id\` is then the existing document's id).

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).

## See also

\[retrieve_knowledge()\], \[delete_knowledge_document()\].
