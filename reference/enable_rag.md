# Enable the RAG knowledge base schema (opt-in migration)

Applies the bundled RAG migration (\`knowledge_document\` +
\`knowledge_chunk\`) on top of the base monitoring schema. This is a
separate, explicit step – \*not\* part of \[db_migrate()\] – because the
PostgreSQL variant requires the \`pgvector\` extension which existing
TimescaleDB deployments may not have installed.

## Usage

``` r
enable_rag(con)
```

## Arguments

- con:

  A \`DBIConnection\` returned by \[db_connect()\].

## Value

Invisible character vector of migration versions applied during this
call (empty if already enabled).

## Details

Idempotent: re-running is a no-op once the migration is recorded in
\`schema_migration\`.

## See also

\[ingest_knowledge_document()\], \[retrieve_knowledge()\].
