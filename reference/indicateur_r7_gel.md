# Late-frost risk indicator (R7)

Per-unit **late-frost risk** — the frequency of spring frost **after
budburst**, the dominant cause of regeneration failure for
frost-sensitive species (oak, beech, Douglas fir). Fed by a daily
**minimum temperature** series (`tmin`), typically the meteoland/SAFRAN
downscaling of the microclimat chantier (P4); it also accepts a direct
daily Tmin raster.

## Usage

``` r
indicateur_r7_gel(
  units,
  tmin = NULL,
  budburst_doy = 100,
  window_end_doy = 180,
  frost_threshold_c = 0,
  max_frost_days = 8,
  ...
)
```

## Arguments

- units:

  An `sf` of management units.

- tmin:

  A daily minimum-temperature `SpatRaster` (one layer per day, dates via
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html)),
  or `NULL` (→ skip). Multi-year series are supported.

- budburst_doy:

  Day-of-year of budburst; frosts before it don't count (default 100 ≈
  10 April).

- window_end_doy:

  Last day-of-year of the sensitivity window (default 180 ≈ end June).

- frost_threshold_c:

  Tmin threshold (°C) below which a day is a frost (default 0).

- max_frost_days:

  Late-frost days per year mapping to score 0 (default 8).

- ...:

  Ignored (forward-compat).

## Value

`units` with `R7` (0–100, high = low frost risk, `NA` when skipped),
`r7_gel_days` (mean late-frost days/year), and `r7_status`
(`"calculated"` / `"skipped_no_tmin"`).

## Details

Conditional like R5 (FORDEAD) and R6 (microclimf): without `tmin`, `R7`
is `NA` and `r7_status = "skipped_no_tmin"`. Sense follows R1–R4/R6 —
**high score = low risk** (few late frosts); it is **not** inverted
(unlike R5).

A unit's mean number of late-frost days per year (Tmin below
`frost_threshold_c`, on days after `budburst_doy` up to
`window_end_doy`) is mapped to 0–100: `0` days → `100`, `max_frost_days`
or more → `0`.

## See also

[`indicateur_r6_sensibilite`](https://pobsteta.github.io/nemeton/reference/indicateur_r6_sensibilite.md),
[`eobs_downscale`](https://pobsteta.github.io/nemeton/reference/eobs_downscale.md)
