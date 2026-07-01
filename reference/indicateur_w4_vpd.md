# W4 — summer under-canopy vapour-pressure deficit (regeneration)

Mean per-UGF summer (JJA) **VPD under the canopy** (kPa), the
atmospheric-dryness driver of seedling water stress (spec 027, ADR-014).
Normalised 0-100 **decreasing** (moister air = more favourable = 100).

## Usage

``` r
indicateur_w4_vpd(units, micro = NULL, chm = NULL,
  bounds = .MICRO_BOUNDS$w4, ...)
```

## Arguments

- units:

  An `sf` of UGF.

- micro:

  Summer microclimate rasters; the `vpd` layer (kPa) is used. `NULL` →
  `W4 = NA`.

- chm:

  Optional canopy-height raster (reserved).

- bounds:

  Numeric `c(lo, hi)` VPD bounds in kPa (default `c(0.5, 4.0)`).

- ...:

  Unused.

## Value

`units` with `W4` (0-100), `W4_vpd` (raw kPa), `W4_couverture_pct`, and
the `"microclimate_model"` augmentation flag.

## See also

[`indicateur_a3_microclimat`](https://pobsteta.github.io/nemeton/reference/indicateur_a3_microclimat.md),
[`microclimate_run`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
