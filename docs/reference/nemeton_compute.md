# Calculate Nemeton indicators for spatial units

Main function to compute biophysical indicators for forest units from
spatial layers. Orchestrates indicator calculation with automatic
preprocessing and error handling.

## Usage

``` r
nemeton_compute(
  units,
  layers,
  indicators = "all",
  preprocess = TRUE,
  parallel = FALSE,
  progress = TRUE,
  ...
)
```

## Arguments

- units:

  A `nemeton_units` or `sf` object representing analysis units

- layers:

  A `nemeton_layers` object containing spatial data layers

- indicators:

  Character vector of indicator names to calculate, or "all" for all
  available. Available indicators: "carbon", "biodiversity", "water",
  "fragmentation", "accessibility"

- preprocess:

  Logical. Automatically harmonize CRS and crop layers? Default TRUE.

- parallel:

  Logical. Use parallel computation? (Not implemented in MVP, will error
  if TRUE)

- progress:

  Logical. Show progress bar? Default TRUE.

- ...:

  Additional arguments passed to indicator functions

## Value

An `sf` object with original columns plus one column per calculated
indicator

## Details

The function performs the following steps:

1.  Validates inputs (units and layers)

2.  If `preprocess = TRUE`:

    - Reprojects layers to units CRS

    - Crops layers to units extent

3.  For each indicator:

    - Calls corresponding `indicator_*()` function

    - Handles errors gracefully (warning + NA column)

    - Updates metadata

4.  Returns enriched sf object

If an indicator calculation fails, a warning is issued and the indicator
column is filled with NA, but computation continues for other
indicators.

## See also

[`indicator_carbon`](https://pobsteta.github.io/nemeton/reference/indicator_carbon.md),
[`indicator_biodiversity`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity.md),
[`indicator_water`](https://pobsteta.github.io/nemeton/reference/indicator_water.md),
[`indicator_fragmentation`](https://pobsteta.github.io/nemeton/reference/indicator_fragmentation.md),
[`indicator_accessibility`](https://pobsteta.github.io/nemeton/reference/indicator_accessibility.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

# Create units
units <- nemeton_units(sf::st_read("parcels.gpkg"))

# Create layer catalog
layers <- nemeton_layers(
  rasters = list(
    biomass = "biomass.tif",
    dem = "dem.tif"
  ),
  vectors = list(
    roads = "roads.gpkg"
  )
)

# Calculate all indicators
results <- nemeton_compute(units, layers)

# Calculate specific indicators
results <- nemeton_compute(
  units, layers,
  indicators = c("carbon", "biodiversity")
)
} # }
```
