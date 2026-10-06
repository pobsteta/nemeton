# Format retrieved chunks as a citation block

Renders the result of \[retrieve_knowledge()\] as a numbered Markdown
(or HTML) "Sources" block, ready to concatenate to an AI perspective.
The footnote markers (\`\[^1\]\`, \`\[^2\]\`, ...) match the order of
the rows.

## Usage

``` r
format_citations(retrieved_chunks, format = c("markdown", "html"), lang = "fr")
```

## Arguments

- retrieved_chunks:

  A \`data.frame\` returned by \[retrieve_knowledge()\].

- format:

  One of \`"markdown"\` (default) or \`"html"\`. In HTML, every field is
  HTML-escaped and a link is emitted only for an \`http://\` /
  \`https://\` \`source_url\`.

- lang:

  Language for the section heading. \`"fr"\` (default) -\> "Sources
  documentaires"; anything else -\> "Sources".

## Value

A character scalar. Empty string \`""\` when there are no chunks.

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).
