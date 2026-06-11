# BD Forêt v2 -\> CV context mapping

BD Forêt v2 -\> CV context mapping

## Usage

``` r
bdforet_v2_mapping(file = NULL)
```

## Arguments

- file:

  Optional path to a user-supplied CSV (same columns as
  `inst/extdata/bdforet_v2_mapping.csv`).

## Value

A data.frame with columns `tfv_code`, `label_fr`, `context_key`,
`confidence` (`"clear"` or `"ambiguous"`), `alt_context_key`,
`notes_fr`.
