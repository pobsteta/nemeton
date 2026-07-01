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

## See also

[`indicateur_a3_microclimat`](https://pobsteta.github.io/nemeton/reference/indicateur_a3_microclimat.md),
[`microclimate_run`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md)
