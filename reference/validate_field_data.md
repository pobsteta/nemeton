# Validate field data against placette + arbre schemas

Checks referential integrity (tree `plot_id` exists in placettes),
required fields (NOT NULL), physical ranges (DBH in \[0, 300\], height
in \[0, 80\]), species in the controlled domain, and tree-id uniqueness
within a plot.

## Usage

``` r
validate_field_data(
  placettes,
  arbres = NULL,
  region = "BFC",
  lang = "fr",
  dbh_max_cm = 300,
  dbh_alerte_cm = NULL
)
```

## Arguments

- placettes:

  sf POINT data-frame of placettes.

- arbres:

  sf POINT (or NULL) data-frame of tree records.

- region:

  Character. Species region used to populate the `espece` domain.
  Default `"BFC"`.

- lang:

  Character. Language for species labels. Default `"fr"`.

- dbh_max_cm:

  Numeric. Maximal admissible DBH (cm); above is an error. Default 300.
  `Inf` accepts any diameter.

- dbh_alerte_cm:

  Numeric or `NULL`. DBH above which a warning
  (`"DBH above alert threshold"`) is raised. Default `NULL` (no alert).

## Value

A list with:

- `ok`: logical, `TRUE` if no errors were found.

- `errors`: data.frame of error-level issues.

- `warnings`: data.frame of warning-level issues.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).
