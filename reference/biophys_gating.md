# Gate the Sentinel-2 biophysical augmentation flag, per unit

Returns, for each unit, whether the Sentinel-2 biophysical variables are
reliable enough to carry the `"biophysical_s2"` NDP augmentation flag
(spec 043 D6, ADR-015). All four quality conditions must hold; any
missing metric fails the gate (**fail-closed**).

This is a **decision**, not a computation: the biophysical rasters and
their quality metrics are produced upstream (`biophysnemeton`, ADR-009).
This function only decides eligibility, so the confidence phi never
counts a variable retrieved on an insufficient basis (ADR-011).

## Usage

``` r
biophys_gating(n_obs, pct_masked, oob_frac, area_px,
  thresholds = biophys_gating_thresholds())
```

## Arguments

- n_obs:

  Integer vector: valid observations in the June-August window, per
  unit.

- pct_masked:

  Numeric vector in `[0, 1]`: cloud/shadow masking rate per unit.

- oob_frac:

  Numeric vector in `[0, 1]`: fraction of pixels flagged out-of-domain
  by SL2P (input or output) per unit.

- area_px:

  Integer vector: unit size in 20 m pixels.

- thresholds:

  A list as returned by
  [`biophys_gating_thresholds`](https://pobsteta.github.io/nemeton/reference/biophys_gating_thresholds.md).

## Value

A logical vector, one per unit: `TRUE` where **all** conditions hold,
`FALSE` otherwise (including where any input is `NA`).

## See also

[`biophys_gating_thresholds`](https://pobsteta.github.io/nemeton/reference/biophys_gating_thresholds.md)

## Examples

``` r
biophys_gating(n_obs = c(5, 2, 8), pct_masked = c(0.2, 0.1, 0.6),
               oob_frac = c(0.02, 0.01, 0.03), area_px = c(40, 30, 100))
#> [1]  TRUE FALSE FALSE
# -> TRUE, FALSE (n_obs<3), FALSE (pct_masked>0.4)
```
