# Delete a document and its chunks from the knowledge base

Delete a document and its chunks from the knowledge base

## Usage

``` r
delete_knowledge_document(con, document_id)
```

## Arguments

- con:

  A \`DBIConnection\`. RAG schema must be enabled.

- document_id:

  Integer. \`knowledge_document.id\`.

## Value

Invisibly, the number of chunks deleted (via the \`ON DELETE CASCADE\`
foreign key).
