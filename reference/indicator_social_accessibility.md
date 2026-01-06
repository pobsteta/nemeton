# S2: Multimodal Accessibility Indicator

Calculates an accessibility score based on proximity to roads, public
transport, and cycling infrastructure. Higher scores indicate better
public access potential.

## Usage

``` r
indicator_social_accessibility(
  units,
  roads = NULL,
  transit_stops = NULL,
  method = c("osm", "local"),
  osm_bbox = NULL,
  road_types = c("primary", "secondary", "tertiary", "unclassified"),
  weights = c(road = 0.5, transit = 0.3, cycling = 0.2),
  column_name = "S2",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- roads:

  sf object (LINESTRING) of road network. If NULL and method="osm",
  fetches from OSM.

- transit_stops:

  sf object (POINT) of public transport stops. Optional.

- method:

  Character. Data source: "osm" (OpenStreetMap) or "local". Default
  "osm".

- osm_bbox:

  Numeric vector for OSM query. Auto-detected if NULL.

- road_types:

  Character vector. OSM highway tags: c("primary", "secondary",
  "tertiary"). Default all.

- weights:

  Named numeric vector. Weights for components: c(road = 0.5, transit =
  0.3, cycling = 0.2). Default balanced.

- column_name:

  Character. Name for output column. Default "S2".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added column: S2 (accessibility score 0-100)

## Details

\*\*Calculation\*\*:

- Road accessibility: Inverse distance to nearest road (closer = higher)

- Transit accessibility: Count of transit stops within 1km buffer

- Cycling accessibility: Presence of cycling infrastructure

- Weighted composite: `S2 = (w1×road + w2×transit + w3×cycling)`

## Examples

``` r
if (FALSE) { # \dontrun{
result <- indicator_social_accessibility(
  units = massif_demo_units,
  method = "osm",
  weights = c(road = 0.6, transit = 0.2, cycling = 0.2)
)
} # }
```
