# Discover the persisted RECONFORT display layers from the cache (L6)

Cache-side counterpart of
[`reconfort_layer_manifest`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md):
rebuilds the layer manifest of a RECONFORT run from the rasters
persisted under the project cache, **without** the in-memory `result`.
This lets a viewer redraw the RECONFORT rasters after a project reload
(parity with
[`read_fordead_layer`](https://pobsteta.github.io/nemeton/reference/read_fordead_layer.md)
/
[`read_fordead_dieback_mask`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md),
which read their layers from the cache).

Primary source is the IOTA² `final/` output dir
(`output_zone_<id>/results/iota2_results_classif_labels-z<id>-S2_*/final/`),
where the display rasters persist across reloads:
`Final_continuous_score_masked*.tif` (score),
`Final_Classif_masked_*.tif` (classification, fallback
`Classif_Seed_0.tif`) and `Final_Proba_map_masked*.tif` (probability,
fallback `ProbabilityMap_seed_0.tif`). When that dir is absent (workdir
cleaned) or an older run is requested, it falls back to the run-scoped
copies under `zone_<id>/` (`reconfort_mask_<run_id>.tif` /
`reconfort_score_<run_id>.tif` / `reconfort_proba_<run_id>.tif`). The
CRswir / CRre multi-band stacks (a time series consumed by
[`read_reconfort_pixel_series`](https://pobsteta.github.io/nemeton/reference/read_reconfort_pixel_series.md))
are **not** display layers and are excluded.

The output is byte-for-byte interchangeable with
[`reconfort_layer_manifest`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md)
(same columns, types and rendering hints), so the caller reuses the same
machinery
([`read_reconfort_layer`](https://pobsteta.github.io/nemeton/reference/read_reconfort_layer.md),
raster cache, toggles, opacity). Alerts are not included (they are read
from the `alert` table independently).

## Usage

``` r
reconfort_cache_manifest(cache_dir, zone_id, run_id = NULL, include_range = FALSE)
```

## Arguments

- cache_dir:

  Project RECONFORT cache directory. The zone layers are resolved at
  `<cache_dir>/zone_<zone_id>/` or, as a fallback,
  `<cache_dir>/reconfort/zone_<zone_id>/`.

- zone_id:

  Scalar monitoring-zone id.

- run_id:

  Run timestamp, or `NULL` (default) to pick the most recent run in the
  zone cache.

- include_range:

  If `TRUE`, fill `vmin`/`vmax` of the continuous rasters with their
  actual
  [`terra::minmax()`](https://rspatial.github.io/terra/reference/minmax.html).
  Default `FALSE`.

## Value

A `data.frame` with the same columns as
[`reconfort_layer_manifest`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md)
(one row per available display raster). Best-effort: a missing cache /
zone / run yields a zero-row frame.

## See also

[`reconfort_layer_manifest`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md),
[`read_reconfort_layer`](https://pobsteta.github.io/nemeton/reference/read_reconfort_layer.md),
[`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
