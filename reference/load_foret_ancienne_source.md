# Acquire the IGN historical-forest (~1850 état-major) layer for an AOI

Fetch the ~1850 forest cover from the IGN *carte de l'état-major*
land-cover layer (BD Carto État-Major,
`BDCARTO_ETAT-MAJOR.NIVEAU3:c_1_1_ocs_ancien`, Licence Ouverte / Etalab
2.0) over `aoi` via WFS (happign), and return it as the `foret_ancienne`
polygon layer consumed by
[`indicateur_n2_continuite`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md).

This is the **historical forest cover** ingredient (forested ~1850): N2
intersects it with the current units, so forest **continuity** ("forest
then *and* now") emerges from the indicator itself. It is **not** the
finished IGN *BD Forêts anciennes* product (état-major × BD Forêt v2,
`Nature` classification), which is download-only (departmental
GeoPackage) and not exposed via WFS.

Degrades gracefully — returns `NULL` on any failure (no network, happign
absent, WFS error, AOI outside metropolitan France) so the caller can
fall back to current-cover N2. A 0-row sf is returned when the AOI
simply has no ~1850 forest.

## Usage

``` r
load_foret_ancienne_source(
  aoi,
  crs = 2154,
  layer = "BDCARTO_ETAT-MAJOR.NIVEAU3:c_1_1_ocs_ancien",
  ...
)
```

## Arguments

- aoi:

  An sf/sfc project extent (must have a defined CRS).

- crs:

  Target EPSG of the returned layer. Default `2154`.

- layer:

  WFS layer id. Defaults to the état-major forest layer.

- ...:

  Passed to
  [`get_wfs`](https://paul-carteron.github.io/happign/reference/get_wfs.html).

## Value

An sf of ancient-forest polygons (`foret_ancienne = TRUE`), clipped to
`aoi`, in `crs`; a 0-row sf if none; `NULL` on failure.

## See also

[`indicateur_n2_continuite`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md),
[`build_foret_ancienne_mask`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)
