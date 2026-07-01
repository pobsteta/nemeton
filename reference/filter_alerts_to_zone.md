# Restrict an alert layer to the UGF zone, at read time (spec 021 L7)

Vector counterpart of the read-time raster masking
([`read_reconfort_layer`](https://pobsteta.github.io/nemeton/reference/read_reconfort_layer.md),
[`read_fast_alert_raster`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md),
[`read_fordead_dieback_mask`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md),
spec 016). Keeps only the alert centroids that fall **inside the UGF
zone polygon**, so a viewer no longer shows alerts outside the user's
managed perimeter.

Shared by the three health pipelines (RECONFORT, FORDEAD, FAST): the
filtering operation is identical for any `sf` POINT alert layer, so a
single core helper provides true parity and keeps the spatial predicate
out of the presentation layer (ADR-009, CLAUDE.md strict rules §1-3).
The persisted `alert` table is **not** modified — the filter is applied
at read/display time only (spec 016 principle "mask at read, not
write"); the per-zone `zone_id` provenance is kept.

## Usage

``` r
filter_alerts_to_zone(
  alerts,
  con = NULL,
  zone_id = NULL,
  apply_zone_mask = TRUE,
  mask_polygon = NULL
)
```

## Arguments

- alerts:

  An `sf` POINT layer (e.g. `result$alerts_sf` from
  [`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  /
  [`run_fordead_dieback`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md),
  or rows read from the `alert` table). Returned unchanged if not a
  non-empty `sf`.

- con:

  A `DBIConnection`, used only to resolve the zone polygon via
  [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md)
  when `mask_polygon` is `NULL`.

- zone_id:

  Integer scalar identifying the row in `monitoring_zone`.

- apply_zone_mask:

  If `TRUE` (default), keep only in-zone alerts. `FALSE` returns the
  layer unchanged.

- mask_polygon:

  An explicit `sf`/`sfc` polygon overriding the DB lookup (e.g. a single
  stratum). When `NULL`, the polygon is resolved from `con` + `zone_id`.

## Value

An `sf` (filtered to the UGF zone unless `apply_zone_mask = FALSE` or no
polygon could be resolved).

## See also

[`read_reconfort_layer`](https://pobsteta.github.io/nemeton/reference/read_reconfort_layer.md),
[`read_fast_alert_raster`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md),
[`read_fordead_dieback_mask`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)
