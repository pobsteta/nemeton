# Read the knowledge-corpus manifest

Reads the manifest CSV into a typed (all-character) data.frame with
\`NA\` normalised to \`""\`, matching the contract of the ingestion
pipeline. Performs no semantic validation beyond requiring the 16
expected columns — use \[validate_knowledge_manifest()\] for that.

## Usage

``` r
read_knowledge_manifest(path = knowledge_manifest_path())
```

## Arguments

- path:

  Character. Defaults to the packaged seed
  (\[knowledge_manifest_path()\]).

## Value

A data.frame with the manifest columns.

## See also

\[validate_knowledge_manifest()\], \[write_knowledge_manifest()\],
\[build_knowledge_corpus()\].
