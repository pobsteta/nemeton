# Calculate accessibility indicator

Measures accessibility based on proximity to roads and trails.

## Usage

``` r
indicator_accessibility(
  units,
  layers,
  roads_layer = "roads",
  trails_layer = NULL,
  max_distance = 5000,
  road_weight = 0.7,
  trail_weight = 0.3,
  invert = FALSE,
  ...
)
```

## Arguments

- units:

  A `nemeton_units` or `sf` object representing analysis units

- layers:

  A `nemeton_layers` object containing spatial data

- roads_layer:

  Character. Name of roads vector layer. Default "roads".

- trails_layer:

  Character. Name of trails vector layer. Default NULL (optional).

- max_distance:

  Numeric. Maximum distance to consider (meters). Default 5000.

- road_weight:

  Numeric. Weight for road proximity (0-1). Default 0.7.

- trail_weight:

  Numeric. Weight for trail proximity (0-1). Default 0.3.

- invert:

  Logical. If TRUE, higher values = less accessible (more remote).
  Default FALSE.

- ...:

  Additional arguments (not used)

## Value

Numeric vector of accessibility indicator values

## Details

The accessibility indicator is based on proximity to transportation
infrastructure:

- **Roads**: Primary accessibility factor (default weight: 0.7)

- **Trails**: Secondary accessibility factor (default weight: 0.3)

If `invert = TRUE`, the indicator represents remoteness (useful for
wilderness/conservation contexts where low accessibility is desirable).

## See also

[`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Accessibility (higher = more accessible)
accessibility <- indicator_accessibility(units, layers)

# Remoteness (higher = more remote)
remoteness <- indicator_accessibility(
  units, layers,
  invert = TRUE
)
} # }
```
