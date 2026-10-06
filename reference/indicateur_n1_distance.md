# N1: Infrastructure Distance Indicator

Calculates distance to infrastructure (roads, buildings) as a measure of
remoteness from human influence. Follows tuto 04 methodology: distances
from parcel centroids to roads (BD TOPO) and buildings, normalized to
0-100 and combined with weights 0.40 (roads) and 0.35 (buildings),
rescaled to sum to 1: `N1 = (0.40 * roads + 0.35 * buildings) / 0.75`.

## Usage

``` r
indicateur_n1_distance(
  units,
  roads = NULL,
  buildings = NULL,
  layers = NULL
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

## Value

sf object with added column N1 (score 0-100, 100 = very remote). Each
distance is scored `min(100, d / 20)` (2 km or more = 100). Until 1.0.0
a third "urban" term (weight 0.25) had no data layer: its distance was a
constant 2000 m, adding 25 points to every unit. It was removed (spec
056), so N1 now spans the full 0-100 range. N1 is NA when the roads or
the buildings layer is missing.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).
