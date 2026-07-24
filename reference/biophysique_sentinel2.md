# Biophysical variable from Sentinel-2 via PROSAIL inversion (spec 042)

Generalises
[`lai_sentinel2`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md)
to any of the directly-invertible PROSAIL biophysical variables —
**LAI**, **fAPAR** or **FVC** (fCover) — over `aoi` from Sentinel-2 L2A,
by the same hybrid inversion machinery.
[`lai_sentinel2`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md)
is a thin alias (`variable = "lai"`), kept for backward compatibility.

Same two paths as
[`lai_sentinel2`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md):
*fast-path* (`precomputed`, temporal reduction only) and *engine path*
(train/apply a hybrid model, needs `prosail` + real S2 scenes — not
runnable in CI).

## Usage

``` r
biophysique_sentinel2(variable = c("lai", "fapar", "fvc", "ccc"), aoi = NULL,
  refl = NULL, start = NULL, end = NULL, reducer = "p90",
  source = "muscate", sensor = "Sentinel_2A", selected_bands = NULL,
  geom_acq = NULL, mask = NULL, cache_dir = NULL, precomputed = NULL, ...)
```

## Arguments

- variable:

  One of `"lai"` (default), `"fapar"`, `"fvc"`. `"ccc"` is a compound
  (Cab x LAI), not a direct inversion target: it errors and is deferred
  (spec 042 lot 4).

- selected_bands:

  S2 bands for the inversion. `NULL` picks a per-variable default
  (currently `c("B4","B5","B8")` for all three — provisional, spec 042
  D3).

- aoi, refl, start, end, reducer, source, sensor, geom_acq, mask,
  cache_dir, precomputed, ...:

  See
  [`lai_sentinel2`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md).

## Value

A single-layer `SpatRaster` named after `variable`, or `NULL` on
degradation (no `prosail`, no scene, engine failure).

## Scope (spec 042 lot 1)

Only the three **direct** inversion targets are supported. **CCC**
(canopy chlorophyll content) is a compound (Cab x LAI), not a direct
target — it errors and is deferred (lot 4). Per-variable band selection
is **provisional**: the LAI default `c("B4","B5","B8")` is validated
(spec 033); for fAPAR/FVC the red-edge-optimal set is still open (spec
042 D3), and their inversion is unvalidated pending the GEODES
cross-check (lot 3).

## See also

[`lai_sentinel2`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md);
consumers of the biophysical layers:
[`indicateur_a1_couverture`](https://pobsteta.github.io/nemeton/reference/indicateur_a1_couverture.md)
(`fvc=`) and
[`indicateur_c2_ndvi`](https://pobsteta.github.io/nemeton/reference/indicateur_c2_ndvi.md)
(`fapar=`).
