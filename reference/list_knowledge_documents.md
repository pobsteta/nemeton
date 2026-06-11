# List the documents in the RAG knowledge base

List the documents in the RAG knowledge base

## Usage

``` r
list_knowledge_documents(con, lang = NULL, doc_type = NULL, family = NULL)
```

## Arguments

- con:

  A \`DBIConnection\`. RAG schema must be enabled.

- lang, doc_type:

  Optional filters (exact match).

- family:

  Optional single family / indicator code; keeps documents tagged with
  it.

## Value

A \`data.frame\` of \`knowledge_document\` rows (without chunks), sorted
by descending ingestion time. \`family_codes\` and \`profile_codes\` are
returned as list-columns of character vectors.
