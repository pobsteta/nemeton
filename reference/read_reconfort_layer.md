# Read a RECONFORT output raster, masked to the UGF zone by default (L7)

Reader for the raster layers of a RECONFORT run, the analogue of
[`read_fast_alert_raster`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
and
[`read_fordead_dieback_mask`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)
(spec 016). By default it restricts the raster to the **UGF zone
polygon** (pixels outside the user's managed perimeter become `NA`), so
RECONFORT reaches parity with the two other health pipelines and the
spatial mask lives in the `nemeton` core rather than in the presentation
layer (spec 021 L7, ADR-013 amendment A6).

The on-disk IOTA² rasters are not modified: the mask is applied at
**read time** (spec 016 principle "mask at read, not write"). Reuses the
spec 016 helpers
[`.apply_zone_mask()`](https://pobsteta.github.io/nemeton/reference/dot-apply_zone_mask.md)
/
[`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md).

## Usage

``` r
read_reconfort_layer(
  layer,
  con = NULL,
  zone_id = NULL,
  apply_zone_mask = TRUE,
  mask_polygon = NULL
)
```

## Arguments

- layer:

  Either a length-1 raster path, or a single row of a
  [`reconfort_layer_manifest`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md)
  data.frame (its `type` must be `"raster"`; a `"vector"` row — the
  alert centroids — is rejected, the vector is not masked here, see spec
  021 L7 §D3).

- con:

  A `DBIConnection`, used only to resolve the zone polygon via
  [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md)
  when `mask_polygon` is `NULL`. `NULL` skips DB resolution.

- zone_id:

  Integer scalar identifying the row in `monitoring_zone` (used with
  `con`).

- apply_zone_mask:

  If `TRUE` (default), mask the raster to the UGF polygon. `FALSE`
  returns the raw raster (bbox + OSO broadleaf extent), the pre-L7
  behaviour.

- mask_polygon:

  An explicit `sf`/`sfc` polygon overriding the DB lookup. When `NULL`,
  the polygon is resolved from `con` + `zone_id`.

## Value

A
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
(masked to the UGF zone unless `apply_zone_mask = FALSE` or no polygon
could be resolved).

## See also

[`reconfort_layer_manifest`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md),
[`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md),
[`read_fast_alert_raster`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md),
[`read_fordead_dieback_mask`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)
