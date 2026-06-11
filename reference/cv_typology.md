# CV typology reference table

Loads the generic forest-context / CV lookup table. The returned frame
has columns:

- `context_key`: NMT snake_case key.

- `context_fr` / `context_en`: human labels.

- `variable`: target variable (`"G"` for basal area).

- `level`: `"peuplement"` (stand-level), `"essence"` (single species
  within a mixed stand), or `"classe_diametre"` (per diameter class).

- `cv_low`, `cv_mid`, `cv_high`: CV as a fraction (e.g., 0.25 for 25 %).

- `notes_fr`: one-line rationale.

## Usage

``` r
cv_typology(file = NULL)
```

## Arguments

- file:

  Optional path to a user-supplied CSV (same columns). Default reads
  `inst/extdata/cv_typology.csv`.

## Value

A data.frame, 8 rows.
