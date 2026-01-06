# N1: Infrastructure Distance Indicator

Calculates minimum distance to infrastructure (roads, buildings, power
lines) as a proxy for remoteness from human influence.

## Usage

``` r
indicator_naturalness_distance(
  units,
  infrastructure = NULL,
  method = c("osm", "local"),
  osm_bbox = NULL,
  infra_types = c("roads", "buildings", "power"),
  osm_road_tags = c("motorway", "trunk", "primary", "secondary", "tertiary"),
  column_name = "N1",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- infrastructure:

  sf object or list. Infrastructure datasets. If NULL and method="osm",
  fetches from OSM.

- method:

  Character. Data source: "osm" or "local". Default "osm".

- osm_bbox:

  Numeric vector for OSM query. Auto-detected if NULL.

- infra_types:

  Character vector. Infrastructure categories: c("roads", "buildings",
  "power"). Default all.

- osm_road_tags:

  Character vector. OSM highway tags for roads. Default c("motorway",
  "trunk", "primary", "secondary", "tertiary").

- column_name:

  Character. Name for output column. Default "N1".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added columns: N1 (min distance m), N1_roads,
N1_buildings, N1_power
