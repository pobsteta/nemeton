# S1: Trail Density Indicator

Calculates the density of recreational trails (pedestrian, cycling,
equestrian) within or near spatial units using OpenStreetMap or local
trail datasets.

## Usage

``` r
indicator_social_trails(
  units,
  trails = NULL,
  method = c("osm", "local"),
  osm_bbox = NULL,
  trail_types = c("path", "footway", "cycleway", "bridleway"),
  buffer_m = 0,
  column_name = "S1",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- trails:

  sf object (LINESTRING) of trail network. If NULL and method="osm",
  fetches from OSM.

- method:

  Character. Data source: "osm" (OpenStreetMap) or "local". Default
  "osm".

- osm_bbox:

  Numeric vector (xmin, ymin, xmax, ymax) for OSM query. Auto-detected
  if NULL.

- trail_types:

  Character vector. OSM highway tags: c("path", "footway", "cycleway",
  "bridleway"). Default all.

- buffer_m:

  Numeric. Buffer distance (m) around units to include nearby trails.
  Default 0 (within units only).

- column_name:

  Character. Name for output column. Default "S1".

- lang:

  Character. Message language ("en" or "fr"). Default "en".

## Value

sf object with added column: S1 (trail density in km/ha)

## Details

\*\*Calculation\*\*:

- Extract or fetch trail network (OSM or local)

- Clip trails to unit boundaries (+ optional buffer)

- Calculate total trail length within each unit

- Normalize by unit area: `S1 = trail_length_km / area_ha`

\*\*Trail Types\*\* (OSM highway tags):

- path: Unpaved footpaths

- footway: Paved pedestrian paths

- cycleway: Dedicated bike paths

- bridleway: Equestrian trails

## Examples

``` r
if (FALSE) { # \dontrun{
# Using OpenStreetMap
result <- indicator_social_trails(
  units = massif_demo_units,
  method = "osm",
  trail_types = c("path", "footway", "cycleway")
)

# Using local trail data with buffer
result <- indicator_social_trails(
  units = parcels,
  trails = local_trails_sf,
  method = "local",
  buffer_m = 100
)
} # }
```
