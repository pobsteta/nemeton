# N2: Forest Continuity Indicator

Calculates continuous forest patch area via buffering and dissolving.

## Usage

``` r
indicator_naturalness_continuity(
  units,
  land_cover = NULL,
  forest_classes = c("forest", "woodland"),
  connectivity_distance = 100,
  method = c("local", "corine", "osm"),
  column_name = "N2",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- land_cover:

  sf or SpatRaster. Land cover layer. If NULL, uses unit boundaries as
  forest.

- forest_classes:

  Character vector. Land cover classes for forest. Default c("forest",
  "woodland").

- connectivity_distance:

  Numeric. Maximum gap (m) to maintain connectivity. Default 100m.

- method:

  Character. Land cover source: "local", "corine", "osm". Default
  "local".

- column_name:

  Character. Name for output column. Default "N2".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added columns: N2 (continuous patch area ha), N2_patch_id
