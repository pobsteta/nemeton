# Fill in missing inventory fields from a CHM

Convenience wrapper around
[`estimate_synthetic_inventory`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md)
that mutates an `sf` in place: fills the `dbh_field` / `density_field`
columns only when they are absent or fully `NA`, leaves any partial
user-provided values intact, and tags the result with the attribute
`inventory_source = "synthetic_ml"` when substitution actually occurred.
Designed to be called at the top of any indicator function that depends
on \\D_g\\ and \\N\\.

## Usage

``` r
ensure_inventory_fields(
  units,
  species_field = "species",
  dbh_field = "dbh",
  density_field = "density",
  chm = NULL,
  stocking = 0.75,
  h_dom_percentile = 0.9
)
```

## Arguments

- units:

  sf object.

- species_field:

  Character. Column holding species codes (default "species").

- dbh_field:

  Character. Column expected to hold \\D_g\\ (default "dbh").

- density_field:

  Character. Column expected to hold stems / ha (default "density").

- chm:

  Optional `SpatRaster` CHM. When `NULL`, the function is a no-op.

- stocking:

  Stocking fraction (see
  [`estimate_synthetic_inventory`](https://pobsteta.github.io/nemeton/reference/estimate_synthetic_inventory.md)).

- h_dom_percentile:

  Percentile for \\H\_{dom}\\ extraction.

## Value

The input `sf` with `dbh_field` and `density_field` filled (when
possible). The `inventory_source` attribute is set to "synthetic_ml" iff
at least one field was filled from the CHM.
