# Estimate a synthetic stand inventory per unit

Given an `sf` of spatial units, a `SpatRaster` CHM and a species vector,
returns `D_g` (cm) and stem density (stems / ha) per unit by chaining:

1.  [`extract_h_dom`](https://pobsteta.github.io/nemeton/reference/extract_h_dom.md)
    to get \\H\_{dom}\\ per unit;

2.  [`estimate_dq_from_hdom`](https://pobsteta.github.io/nemeton/reference/estimate_dq_from_hdom.md)
    for \\D_g\\;

3.  [`n_max_selfthinning`](https://pobsteta.github.io/nemeton/reference/n_max_selfthinning.md)
    (Charru 2012) times a `stocking` fraction for \\N\\.

## Usage

``` r
estimate_synthetic_inventory(
  units,
  chm,
  species,
  h_dom_percentile = 0.9,
  stocking = 0.75
)
```

## Arguments

- units:

  sf polygon layer.

- chm:

  A `SpatRaster` canopy height model.

- species:

  Character vector of IFN species codes, length `nrow(units)`.

- h_dom_percentile:

  Numeric. Percentile of CHM pixels taken as dominant height per unit
  (default 0.9). Ignored when `H_dom` is already present in `units`.

- stocking:

  Numeric in `(0, 1]`. Fraction of self-thinning maximum density used as
  the expected actual density (default 0.75, i.e. 75 French managed
  stands).

## Value

A data.frame with one row per unit containing `H_dom` (m), `dbh` (cm,
the quadratic mean diameter), `density` (stems / ha), and `source`
(always "synthetic_ml") columns.

## Examples

``` r
if (FALSE) { # \dontrun{
inv <- estimate_synthetic_inventory(
  units   = ugf,
  chm     = chm_clean,
  species = ugf$species,
  stocking = 0.75
)
ugf$dbh     <- inv$dbh
ugf$density <- inv$density
} # }
```
