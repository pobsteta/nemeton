# Microclimate exposure per unit — microclimf engine (spec 027 L1)

Per-unit summer under-canopy exposure (T°max, VPD, canopy buffering,
heatwave-vs-average sensitivity, robustness) from the mechanistic
**microclimf** model driven by LiDAR-HD structure and ERA5-Land forcing.
Produces the §7 exposure columns consumed by
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md).

## Usage

``` r
regen_sensibilite(
  units,
  mnt = NULL,
  mnh = NULL,
  las = NULL,
  annees_moy = NULL,
  annees_canic = NULL,
  mois_ete = 6:8,
  precomputed = NULL,
  ...
)
```

## Arguments

- units:

  An `sf` of UGF.

- mnt, mnh, las:

  Optional LiDAR-HD inputs (DTM raster, canopy-height raster, classified
  point cloud) for the engine path.

- annees_moy, annees_canic:

  Integer years for the average / heatwave summers (engine path). See
  [`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md).

- mois_ete:

  Integer months of the summer window (default `6:8`).

- precomputed:

  Optional per-unit microclimf output (`data.frame`/list).

- ...:

  Reserved (engine parameters).

## Value

`units` with the exposure columns (subset of §7), plus derived
`d_tmax`/`d_vpd`/`rang_sensibilite` where computable.

## Details

**Scaffold with a pure fast-path**: pass `precomputed` (a microclimf run
output) and the metrics are attached as §7 columns without the GPL
engine. Missing `d_tmax`/`d_vpd` are derived from the canicule − moyenne
difference, and `rang_sensibilite` from `sensibilite` (1 = most
sensitive). Without `precomputed`, the orchestration is not yet wired.

## See also

[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md),
[`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md)
