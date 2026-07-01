# R6 — microsite climate sensitivity (heatwave vs average year)

Per-UGF **sensitivity** of the under-canopy microsite to a hot year
(spec 027 L2, ADR-014): the change in summer heat stress between a
**heatwave** year and an **average** year, with the canopy held fixed
(isolates the climatic effect). Combines the standardised ΔT°max and
ΔVPD; normalised 0-100 **decreasing** (less sensitive = more resilient =
100).

The two years are chosen by the caller — typically auto-detected from
the E-OBS summer series via
[`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md),
or set manually. This function consumes the **two precomputed `micro`
sets** (one per year), each carrying `tmax_understorey` and `vpd`.

## Usage

``` r
indicateur_r6_sensibilite(units, micro_moyenne = NULL, micro_canicule = NULL,
  bounds = .MICRO_BOUNDS$r6, ...)
```

## Arguments

- units:

  An `sf` of UGF.

- micro_moyenne:

  Summer microclimate rasters for the **average** year (needs
  `tmax_understorey`, `vpd`).

- micro_canicule:

  Summer microclimate rasters for the **heatwave** year (same layers).
  `NULL`/missing layers → `R6 = NA`.

- bounds:

  Numeric `c(scale_t, scale_v)` standardisation scales (default
  `c(8, 2)` — ΔT in °C, ΔVPD in kPa).

- ...:

  Unused.

## Value

`units` with `R6` (0-100, higher = less sensitive), `R6_dtmax` (raw
ΔT°max, °C), `R6_dvpd` (raw ΔVPD, kPa), `R6_couverture_pct`, and the
`"microclimate_model"` augmentation flag.

## See also

[`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md),
[`indicateur_a3_microclimat`](https://pobsteta.github.io/nemeton/reference/indicateur_a3_microclimat.md)
