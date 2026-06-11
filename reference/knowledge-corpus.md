# Knowledge-corpus manifest and ingestion orchestration (spec 009.2)

Public API around the RAG knowledge-corpus manifest
(\`inst/extdata/knowledge_corpus_v1.csv\`, spec 009.1) and the
manifest-to-database ingestion pipeline. This promotes the logic that
used to live only in \`data-raw/build_knowledge_corpus.R\` into
exported, testable functions, so that a \`nemetonshiny\` administration
tab can edit the manifest and import the corpus \*\*without
re-implementing any business logic\*\* (CLAUDE.md rules 1-3).

The packaged CSV is the versioned \*\*seed\*\*; an editable \*\*project
copy\*\* is resolved by \[knowledge_manifest_path()\] (\`writable =
TRUE\`) and seeded from the package on first use (spec 009.2 D1).
