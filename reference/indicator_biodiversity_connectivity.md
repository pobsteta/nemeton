# Calculate Ecological Connectivity (B3)

Computes distance from each forest parcel to the nearest ecological
corridor (Trame Verte et Bleue).

## Usage

``` r
indicator_biodiversity_connectivity(
  units,
  corridors = NULL,
  distance_method = c("edge", "centroid"),
  max_distance = 5000
)
```

## Arguments

- units:

  An sf object with forest parcels.

- corridors:

  An sf object with ecological corridors (lines or polygons). If NULL,
  uses fallback scoring (default medium score of 50). Default NULL.

- distance_method:

  Character. Method for distance calculation: "edge" (edge-to-edge),
  "centroid" (centroid-to-centroid). Default "edge".

- max_distance:

  Numeric. Maximum distance threshold (meters). Distances beyond this
  are capped. Default 5000.

## Value

The input sf object with added columns:

- B3: Distance to nearest corridor (meters). Lower = better
  connectivity.

- B3_norm: Normalized connectivity score (0-100). Higher = better
  (inverse distance).

## Details

\*\*Calculation\*\*: B3 = min distance to any corridor

\*\*Normalization\*\*: B3_norm = 100 × (1 - min(B3, max_distance) /
max_distance)

\*\*Interpretation\*\*:

- 0-500m: Excellent connectivity (B3_norm \> 90)

- 500-1500m: Good connectivity (B3_norm 70-90)

- 1500-3000m: Fair connectivity (B3_norm 40-70)

- \>3000m: Poor connectivity (B3_norm \< 40)

## See also

Other biodiversity-indicators:
[`indicator_biodiversity_protection()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_protection.md),
[`indicator_biodiversity_structure()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_structure.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(sf)

data(massif_demo_units)

# Load ecological corridors (Trame Verte et Bleue)
corridors <- st_read("trame_verte.gpkg")

result <- indicator_biodiversity_connectivity(
  massif_demo_units,
  corridors = corridors,
  distance_method = "edge",
  max_distance = 3000
)

# Highly connected parcels
well_connected <- result[result$B3 < 500, ]
} # }
```
