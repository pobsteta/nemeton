# Controlled vocabularies for the knowledge-corpus manifest

Returns the canonical value sets used to validate
\`inst/extdata/knowledge_corpus_v1.csv\`. This is the single source of
truth: both \[validate_knowledge_manifest()\] and the manifest integrity
tests consume it, and a \`nemetonshiny\` editor can use it to populate
the drop-downs of the enum columns.

## Usage

``` r
knowledge_manifest_vocab()
```

## Value

A named list with elements \`columns\`, \`licenses\`, \`statuses\`,
\`strategies\`, \`langs\`, \`doc_types\`, \`profiles\`, and
\`family_regex\`.

## See also

\[validate_knowledge_manifest()\], \[read_knowledge_manifest()\].
