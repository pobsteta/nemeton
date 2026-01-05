# Calculate Air Quality Index (A2)

Computes air quality score using direct ATMO station data (if available)
or proxy method based on distance to pollution sources (roads, urban
areas).

## Usage

``` r
indicator_air_quality(
  units,
  atmo_data = NULL,
  roads = NULL,
  urban_areas = NULL,
  method = "auto"
)
```

## Arguments

- units:

  An sf object with forest parcels.

- atmo_data:

  An sf object with ATMO air quality stations (points). Must contain
  columns: NO2 (µg/m³), PM10 (µg/m³). Can be NULL.

- roads:

  An sf object with road network (lines). Used for proxy method.

- urban_areas:

  An sf object with urban zones (polygons). Used for proxy method.

- method:

  Character. Method to use:

  - "auto" (default): Use direct if atmo_data available, else proxy

  - "direct": Require ATMO data (error if NULL)

  - "proxy": Use distance-based proxy

## Value

The input sf object with added columns:

- A2: Air quality index (0-100). Higher = better air quality.

- A2_method: Method used ("direct" or "proxy")

## Details

\*\*Direct Method\*\* (ATMO data): - Interpolate NO2 and PM10 from
nearest stations - Convert to quality score: low pollution = high score

\*\*Proxy Method\*\* (distance-based): - Calculate distance to nearest
road and urban area - Far from pollution sources = high score

## See also

Other air-indicators:
[`indicator_air_coverage()`](https://pobsteta.github.io/nemeton/reference/indicator_air_coverage.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units[1:10, ]

# Direct method with ATMO data
atmo_data <- st_read("path/to/atmo_stations.gpkg")
result <- indicator_air_quality(units, atmo_data = atmo_data, method = "direct")

# Proxy method
roads <- st_read("path/to/roads.gpkg")
urban <- st_read("path/to/urban_areas.gpkg")
result <- indicator_air_quality(units, roads = roads, urban_areas = urban, method = "proxy")
} # }
```
