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

  sf object (LINESTRING/MULTILINESTRING). Road network (BD TOPO). NULL
  (and none in `layers`) gives N1 = NA.

- buildings:

  sf object (POLYGON/MULTIPOLYGON). Buildings. NULL (and none in
  `layers`) gives N1 = NA.

- layers:

  nemeton_layers object. Used to resolve roads/buildings if not provided
  directly.

- column_name:

  Character. Name for output column. Default "N1".

- lang:

  Character. Currently unused (messages are in English); kept for
  backward compatibility. Default "en".

## Value

sf object with added column N1 (score 0-100, 100 = very remote). Each
distance is scored `min(100, d / 20)` (2 km or more = 100). The urban
term has no data layer: its distance is a constant 2000 m, so it always
adds 25 points and N1 ranges over 25-100.
