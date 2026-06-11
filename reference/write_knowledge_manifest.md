# Write the knowledge-corpus manifest

Validates the manifest (unless \`validate = FALSE\`) and writes it back
as CSV with deterministic, minimal quoting so version-control diffs stay
readable. Refuses to write a manifest carrying \`error\`-severity
issues.

## Usage

``` r
write_knowledge_manifest(
  manifest,
  path = knowledge_manifest_path(writable = TRUE),
  validate = TRUE
)
```

## Arguments

- manifest:

  A data.frame, e.g. from \[read_knowledge_manifest()\].

- path:

  Character. Defaults to the writable project copy
  (\[knowledge_manifest_path()\] with \`writable = TRUE\`).

- validate:

  Logical. When \`TRUE\` (default), abort if
  \[validate_knowledge_manifest()\] reports any \`error\` issue.

## Value

Invisibly, the path written.

## See also

\[read_knowledge_manifest()\], \[validate_knowledge_manifest()\].
