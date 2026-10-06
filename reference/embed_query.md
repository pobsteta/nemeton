# Embed a query string into a numeric vector

Thin wrapper over the configured embedding provider. Exported mainly for
debugging and batch indexing; \[retrieve_knowledge()\] calls it
internally.

## Usage

``` r
embed_query(
  text,
  provider = c("mistral", "openai", "voyage"),
  api_key = NULL
)
```

## Arguments

- text:

  Character scalar. The query to embed.

- provider:

  One of \`"mistral"\` (default), \`"openai"\`, \`"voyage"\`.

- api_key:

  Character or \`NULL\`. See \[ingest_knowledge_document()\].

## Value

A numeric vector. Its length is provider-dependent (Mistral 1024, OpenAI
1536/3072, Voyage 1024); it is fitted to 3072 dims only at
storage/compare time.

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).
