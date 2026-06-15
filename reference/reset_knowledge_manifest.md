# Reset the writable knowledge manifest to the packaged corpus

Overwrites the writable project copy of the manifest (the one edited
from the application, returned by \`knowledge_manifest_path(writable =
TRUE)\`) with the seed bundled in the installed package.

## Usage

``` r
reset_knowledge_manifest(confirm = TRUE)
```

## Arguments

- confirm:

  Logical. Must be \`TRUE\` (default) to proceed; the parameter exists
  so the caller passes an explicit user confirmation before discarding
  the writable copy.

## Value

The path to the refreshed writable manifest (invisibly).

## Details

The writable copy is created **once** and never auto-refreshed, so that
edits made from the app survive package updates (spec 009.2 D1). The
flip side is that a copy created against an old corpus keeps listing
documents the package no longer ships. Call this to pull the current
packaged corpus explicitly — typically wired to a "reset to packaged
corpus" action in the RAG admin tab.

## See also

\[knowledge_manifest_path()\], \[read_knowledge_manifest()\].
