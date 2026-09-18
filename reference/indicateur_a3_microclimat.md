# A3 — summer under-canopy maximum temperature (regeneration microclimate)

Mean per-UGF summer (JJA) **maximum temperature under the canopy**, the
core heat-stress driver for forest regeneration (spec 027, ADR-014).
Normalised 0-100 **decreasing** (cooler = more favourable = 100).

## Usage

``` r
indicateur_a3_microclimat(units, micro = NULL, chm = NULL,
  bounds = .MICRO_BOUNDS$a3, ...)
```

## Arguments

- units:

  An `sf` of forest management units (UGF).

- micro:

  The summer microclimate rasters (named list / multi-layer
  `SpatRaster`) from
  [`microclimate_run`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md);
  the `tmax_understorey` layer (°C) is used. `NULL` → `A3 = NA`.

- chm:

  Optional canopy-height raster (reserved; structure source for the
  augmentation flag).

- bounds:

  Numeric `c(lo, hi)` normalisation bounds in °C (default `c(15, 40)`).

- ...:

  Unused (signature harmonisation).

## Value

`units` with columns `A3` (0-100), `A3_tmax` (raw °C),
`A3_couverture_pct`, and `attr(., "augmented")` carrying
`"microclimate_model"`.

**Higher = cooler under the canopy = favourable.** The raw quantity
(summer maximum temperature, °C) runs the other way, so
`.micro_norm(decreasing = TRUE)` flips it here, at the source: 15 °C -\>
100, 40 °C -\> 0 (`.MICRO_BOUNDS$a3`).
[`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md)
therefore passes `A3` through unchanged and must **not** invert it a
second time (spec 048 section 12).

## See also

[`indicateur_a4_tamponnement`](https://pobsteta.github.io/nemeton/reference/indicateur_a4_tamponnement.md),
[`indicateur_w4_vpd`](https://pobsteta.github.io/nemeton/reference/indicateur_w4_vpd.md),
[`microclimate_run`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
