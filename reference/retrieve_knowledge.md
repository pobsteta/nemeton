# Retrieve the most relevant knowledge chunks for a query

Embeds \`query\` and returns the top-k chunks by cosine similarity,
optionally filtered by indicator family, actor profile, and language. On
PostgreSQL the ranking uses pgvector's \`\<=\>\` operator; on SQLite it
is computed in R.

## Usage

``` r
retrieve_knowledge(
  con,
  query,
  top_k = 8L,
  family_codes = NULL,
  profile_codes = NULL,
  min_similarity = 0.7,
  lang = NULL,
  embed_provider = c("mistral", "openai", "voyage")
)
```

## Arguments

- con:

  A \`DBIConnection\`. RAG schema must be enabled.

- query:

  Character scalar. Natural-language query.

- top_k:

  Integer. Maximum number of chunks to return. Default 8.

- family_codes:

  Optional character vector. Keep only documents tagged with at least
  one of these family / indicator codes.

- profile_codes:

  Optional character vector. Keep only documents tagged with at least
  one of these actor-profile codes.

- min_similarity:

  Numeric in \`\[0, 1\]\`. Drop chunks below this cosine similarity.
  Default 0.7.

- lang:

  Optional ISO 639-1 code. Keep only documents in this language.

- embed_provider:

  One of \`"mistral"\` (default), \`"openai"\`, \`"voyage"\`. Must match
  the provider used at ingestion.

## Value

A \`data.frame\` sorted by descending \`similarity\` with columns
\`chunk_id\`, \`document_id\`, \`title\`, \`author\`, \`pub_date\`,
\`source_url\`, \`lang\`, \`chunk_index\`, \`page_number\`, \`text\`,
\`similarity\`. Zero rows (canonical empty frame) when nothing clears
\`min_similarity\`.

## See also

\[format_citations()\] to render the result as a citation block.
