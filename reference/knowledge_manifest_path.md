# Resolve the path to the knowledge-corpus manifest

The packaged CSV (\`inst/extdata/knowledge_corpus_v1.csv\`) is the
versioned \*\*seed\*\* and is read-only once the package is installed.
Editing the manifest from an application therefore works on a writable
\*\*project copy\*\* (spec 009.2 D1).

## Usage

``` r
knowledge_manifest_path(writable = FALSE)
```

## Arguments

- writable:

  Logical. \`FALSE\` (default) returns the packaged seed. \`TRUE\`
  returns the writable project copy, resolved from
  \`NEMETON_KNOWLEDGE_MANIFEST\` (or, if unset, a default under
  \[tools::R_user_dir()\]). When the writable copy does not exist yet it
  is created by copying the seed (idempotent).

## Value

A character scalar path.

## See also

\[read_knowledge_manifest()\], \[write_knowledge_manifest()\].
