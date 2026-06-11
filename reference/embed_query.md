# Embed a query string into a numeric vector

Thin wrapper over the configured embedding provider. Exported mainly for
debugging and batch indexing; \[retrieve_knowledge()\] calls it
internally.

## Usage

``` r
embed_query(
  text,
  provider = c("mistral", "openai", "voyage"),
  api_key = NULL,
  lang = NULL
)
```

## Arguments

- text:

  Character scalar. The query to embed.

- provider:

  One of \`"mistral"\` (default), \`"openai"\`, \`"voyage"\`.

- api_key:

  Character or \`NULL\`. See \[ingest_knowledge_document()\].

- lang:

  Optional ISO 639-1 language hint (reserved for provider-specific model
  selection; currently unused).

## Value

A numeric vector. Its length is provider-dependent (Mistral 1024, OpenAI
1536/3072, Voyage 1024); it is fitted to 3072 dims only at
storage/compare time.
