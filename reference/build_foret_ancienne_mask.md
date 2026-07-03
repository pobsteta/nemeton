# Build an ancient-forest polygon layer for N2 continuity

Turns a historical forest source into the `foret_ancienne` polygon layer
consumed by
[`indicateur_n2_continuite`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md)
(its `foret_ancienne` argument). Three source forms are accepted:

- an sf/sfc of already-vectorised ancient-forest polygons (e.g. a
  digitised Cassini / état-major map, or an IGN “forêt ancienne” layer):
  it is validated, reprojected and optionally area-filtered, then
  returned.

- a terra SpatRaster historical forest map: a binary forest mask is
  derived — by class membership (`forest_class`), by threshold
  (`threshold`), or, failing both, as `value > 0` — then polygonised,
  split into contiguous patches, area-filtered and returned as polygons.

- a **named list** of several sources (each a historical epoch, e.g.
  `list(cassini = ..., etatmajor = ...)`): each is normalised to forest
  and dissolved, then consolidated into a **non-overlapping tiered
  layer** with an integer `anciennete` column = the number of epochs
  covering each polygon (higher = older, stronger continuity) and an
  `epoques` label. Feeds the tier-weighted path of
  [`indicateur_n2_continuite`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md).

nemeton ships no French historical forest raster: the source is supplied
by the caller. Note that the Theia `corona-4b` collection is NOT a
usable source over France — it covers only the Middle East (spec 031);
the French sources are Cassini / état-major scans or IGN forêt-ancienne
layers.

## Usage

``` r
build_foret_ancienne_mask(
  source,
  forest_class = NULL,
  threshold = NULL,
  min_area_m2 = 0,
  crs = NULL
)
```

## Arguments

- source:

  An sf/sfc of ancient-forest polygons, a terra SpatRaster historical
  forest map, or a named list of several such sources (multi-epoch
  consolidation).

- forest_class:

  Optional. Raster class value(s) that denote forest (used only when
  `source` is a SpatRaster). Selects the mask by membership.

- threshold:

  Optional numeric. Raster values `>= threshold` are forest (used only
  when `source` is a SpatRaster and `forest_class` is NULL) — e.g. a
  forest-probability or greenness index.

- min_area_m2:

  Numeric. Drop contiguous patches smaller than this area (in the
  working CRS units, m² for a metric CRS). Default 0 = keep all.

- crs:

  Optional target CRS (anything accepted by
  [`st_transform`](https://r-spatial.github.io/sf/reference/st_transform.html)).
  NULL (default) keeps the source CRS.

## Value

An sf polygon layer with `foret_ancienne = TRUE`, ready to pass to
`indicateur_n2_continuite(units, foret_ancienne = ...)`. For a list of
sources it also carries `anciennete` (integer epoch-count tier) and
`epoques` (the contributing epoch labels). May have 0 rows if no forest
is found.
