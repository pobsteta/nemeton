# Soil Fertility Class (F1)

Extracts soil fertility classification from BD Sol or equivalent
pedological database.

## Usage

``` r
indicator_soil_fertility(
  units,
  layers,
  soil_layer = "soil",
  fertility_col = "fertility"
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing soil data

- soil_layer:

  Character. Name of soil layer in layers object

- fertility_col:

  Character. Column/band name for fertility class

## Value

Numeric vector of fertility scores (0-100 scale, higher = more fertile)

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(vectors = list(soil = "bd_sol.gpkg"))
results <- indicator_soil_fertility(units, layers, soil_layer = "soil")
} # }
```
