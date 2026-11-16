# Hydrographic Network Density (W1)

Calculates stream/river network length density within or near forest
parcels. Includes a proximity bonus for parcels near watercourses
(within 500m) that are not directly crossed, reflecting the hydrological
influence of nearby streams on water table and microclimate.

Since 2026.11.34, springs count in the proximity bonus (surface network
**and emergences**): when `layers` holds a point layer `spring_layer`
(BD TOPO `detail_hydrographique`), a unit not crossed by a watercourse
takes its distance to the nearest watercourse **or spring**, and a
spring inside the unit gives the full bonus. Only emergences are kept
(`nature` in `Source`, `Source captée`, `Résurgence`, and
`etat_de_l_objet` "En service" when the column exists): fountains,
wash-houses and sinkholes are works or absorption points. Springs never
add to the density (a point has no length), and an absent spring layer
leaves W1 unchanged. W1 still does not see underground flow (karst).

## Usage

``` r
indicateur_w1_reseau(
  units,
  layers,
  watercourse_layer = "water_network",
  buffer = 0,
  proximity_m = 500,
  proximity_ref = 50,
  spring_layer = "water_points"
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing watercourse vector layer

- watercourse_layer:

  Character. Name of watercourse layer in layers object

- buffer:

  Numeric. Buffer distance (meters) for proximity analysis. Default 0.

- proximity_m:

  Numeric. Maximum distance (m) for proximity bonus. Default 500.

- proximity_ref:

  Numeric. Equivalent density bonus (m/ha) at distance 0. Default 50.

- spring_layer:

  Character. Name of the optional spring point layer in `layers`
  (default `"water_points"`). Absent layer: surface network only.

## Value

The input `units` (same class, rows and order) with an added numeric
column `W1`: network density (m/ha). NA for every unit when the
watercourse layer is missing (no measurement); a supplied but empty
layer gives 0.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(vectors = list(streams = "watercourses.gpkg"))
results <- indicateur_w1_reseau(units, layers, watercourse_layer = "streams")
} # }
```
