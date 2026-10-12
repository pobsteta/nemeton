# Assign tree heights from segmented crowns

Point-in-polygon on the trunk position: a tree takes the apex height
(`h_max`) of the crown that contains it, the highest one when crowns
overlap. A trunk on a crown boundary is inside. Nothing is assigned
outside any crown (no fallback on the nearest crown), crowns whose
height is outside `[h_min, h_max]` are ignored, and a measured height
(`h_source = "mesuree"`) is never overwritten. A CHM-derived height
(`"mnh"`) is recomputed: a tree that no longer falls in a valid crown
gets `h_m = NA`, `h_source = "aucune"`.

## Usage

``` r
affecter_hauteur_houppier(arbres, houppiers, h_min = 1, h_max = 70)
```

## Arguments

- arbres:

  sf POINT of trees, optionally with `h_m`, `h_source` and
  `houppier_id`.

- houppiers:

  sf POLYGON of crowns with `houppier_id` and `h_max`, as returned by
  [`segment_houppiers`](https://pobsteta.github.io/nemeton/reference/segment_houppiers.md).

- h_min, h_max:

  Admissible crown heights (m). Defaults 1 and 70.

## Value

`arbres` with `h_m`, `h_source` and `houppier_id` filled in.

## Lifecycle

Experimental (spec 061).

## Examples

``` r
library(sf)
#> Linking to GEOS 3.12.1, GDAL 3.8.4, PROJ 9.4.0; sf_use_s2() is TRUE
crowns <- st_sf(houppier_id = 1:2, h_max = c(24.5, 31),
                geometry = st_sfc(st_buffer(st_point(c(0, 0)), 3),
                                  st_buffer(st_point(c(4, 0)), 3)))
trees <- st_sf(tree_id = c("1", "2"),
               geometry = st_sfc(st_point(c(2, 0)), st_point(c(10, 0))))
affecter_hauteur_houppier(trees, crowns)
#> Simple feature collection with 2 features and 4 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 2 ymin: 0 xmax: 10 ymax: 0
#> CRS:           NA
#>   tree_id     geometry h_m h_source houppier_id
#> 1       1  POINT (2 0)  31      mnh           2
#> 2       2 POINT (10 0)  NA   aucune          NA
```
