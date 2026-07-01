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
  stocking = 0.75,
  min_stand_height = 1.3,
  min_merchantable_height = 6,
  suspect_frac = 0.95
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

- min_stand_height:

  Numeric (m). Dominant height below which a unit is a felled / cleared
  / non-forest stand (breast height, default `1.3`). Used to distinguish
  the felled case from a young stand in documentation; the actual
  zero-out is governed by `min_merchantable_height` (which must be
  \\\ge\\ this).

- min_merchantable_height:

  Numeric (m). Dominant height below which a unit carries **no
  merchantable stock**: its `dbh` and `density` are set to `0` rather
  than `NA`, so volume/quality indicators (P1, P3, E1) return `0`
  instead of a cryptic `NA`. Default `6` (the lower calibration bound of
  the mature-stand allometry). Covers both felled stands (\\H\_{dom}
  \<\\ `min_stand_height`) and young / pre-merchantable stands. The test
  is on *height*: a tall stand whose \\D_g\\ is `NA` because its
  *species* is missing stays `NA`; an `NA` \\H\_{dom}\\ (no CHM
  coverage) also stays `NA`.

- suspect_frac:

  Numeric in `(0, 1]`. If at least this fraction of observed units fall
  below `min_merchantable_height` *and* the CHM's global maximum is
  itself below it, the CHM is flagged as likely degenerate (all-zero /
  failed prediction): a warning is emitted and the returned data.frame
  carries `attr(x, "chm_suspect") = TRUE`. Default `0.95`.

## Value

A data.frame with one row per unit containing `H_dom` (m), `dbh` (cm,
the quadratic mean diameter), `density` (stems / ha), and `source`
(always "synthetic_ml") columns. Units below `min_merchantable_height`
get `dbh = 0` and `density = 0`. The attribute `chm_suspect` (logical)
flags a likely degenerate CHM (see `suspect_frac`).

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
