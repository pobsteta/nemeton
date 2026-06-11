# QGIS form schema for the health-validation \`placette\` layer

Adds the dieback-specific columns on top of a sampling-style header
(\`plot_id\`, observer/date) so the GPKG can be opened in QGIS Desktop
(or pushed to QField on a tablet via QFieldSync), edited offline by the
field crew, then re-ingested by \[ingest_health_validation()\]. The
schema reuses the same \`.field()\` descriptor convention as
\[get_placette_schema()\] so the existing \`create_qgis_project()\`
machinery (in \`R/qgis_export.R\`) renders the \`.qgz\` form without
changes.

## Usage

``` r
get_health_validation_schema(region = "BFC", lang = "fr")
```

## Arguments

- region:

  Character. Species region, used to populate the \`essence_dominante\`
  value-map. Default \`"BFC"\`.

- lang:

  Character. Language for species labels. Default \`"fr"\`.

## Value

A list of field descriptors (see \`R/field_schema.R\`).
