# N1: Infrastructure Distance Indicator

Calculates distance to infrastructure (roads, buildings, urban zones) as
a measure of remoteness from human influence. Follows tuto 04
methodology: distances from parcel centroids to roads (BD TOPO) and
buildings, normalized to 0-100 and combined with weights (40

## Usage

``` r
indicateur_n1_distance(
  units,
  roads = NULL,
  buildings = NULL,
  layers = NULL,
  column_name = "N1",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- roads:

  sf object (LINESTRING/MULTILINESTRING). Road network (BD TOPO). NULL =
  default 1000m.

- buildings:

  sf object (POLYGON/MULTIPOLYGON). Buildings. NULL = default 500m.

- layers:

  nemeton_layers object. Used to resolve roads/buildings if not provided
  directly.

- column_name:

  Character. Name for output column. Default "N1".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added column N1 (score 0-100, 100 = very remote)
