# Validate the knowledge-corpus manifest

Checks every integrity invariant of the manifest (spec 009.1 §6 / D5):
structure, controlled enums, recognised family / profile codes, and the
license-gate safety rules (a \`cleared\` row never carries an
unconfirmed license; a \`copyright\` document is never full-text
ingested; a declared \`local_path\` has an ingestible extension).

## Usage

``` r
validate_knowledge_manifest(manifest)
```

## Arguments

- manifest:

  A data.frame, e.g. from \[read_knowledge_manifest()\].

## Value

A data.frame with columns \`row\` (1-based row index, \`NA\` for
table-level issues), \`doc_id\`, \`severity\` (\`"error"\` or
\`"warning"\`), \`field\`, and \`message\`. Zero rows means the manifest
is valid.

## Details

Returns the issues as data rather than aborting, so a caller (e.g. a
\`nemetonshiny\` editor) can surface them inline.

## See also

\[knowledge_manifest_vocab()\], \[write_knowledge_manifest()\].
