# A4 — canopy thermal buffering (regeneration microclimate)

Mean per-UGF **buffering** = summer T°max in the open minus under the
canopy. A larger buffer means the canopy shields the regeneration
microsite from heat (spec 027, ADR-014). Normalised 0-100 **increasing**
(more buffering = 100).

## Usage

``` r
indicateur_a4_tamponnement(units, micro = NULL, chm = NULL,
  bounds = .MICRO_BOUNDS$a4, ...)
```

## Arguments

- units:

  An `sf` of UGF.

- micro:

  Summer microclimate rasters; both `tmax_open` and `tmax_understorey`
  (°C) are used. `NULL`/missing layer → `A4 = NA`.

- chm:

  Optional canopy-height raster (reserved).

- bounds:

  Numeric `c(lo, hi)` buffering bounds in °C (default `c(0, 10)`).

- ...:

  Unused.

## Value

`units` with `A4` (0-100), `A4_buffer` (raw °C), `A4_couverture_pct`,
and the `"microclimate_model"` augmentation flag.

**Higher = more thermal buffering = favourable**, and the raw quantity
(the open-air minus under-canopy temperature gap, °C) already runs that
way: 0 °C -\> 0, 10 °C -\> 100 (`.MICRO_BOUNDS$a4`,
`decreasing = FALSE`). Unlike `A3` and `W4`, nothing is flipped.
[`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md)
passes it through (spec 048 section 12).

## See also

[`indicateur_a3_microclimat`](https://pobsteta.github.io/nemeton/reference/indicateur_a3_microclimat.md),
[`microclimate_run`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
