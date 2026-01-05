# Calculate biodiversity indicator

Computes biodiversity indices from species occurrence or richness data.

## Usage

``` r
indicator_biodiversity(
  units,
  layers,
  richness_layer = "species_richness",
  index = c("richness", "shannon", "simpson"),
  fun = "mean",
  ...
)
```

## Arguments

- units:

  A `nemeton_units` or `sf` object representing analysis units

- layers:

  A `nemeton_layers` object containing spatial data

- richness_layer:

  Character. Name of species richness raster layer. Default
  "species_richness".

- index:

  Character. Biodiversity index to calculate. Options: "richness",
  "shannon", "simpson". Default "richness".

- fun:

  Character. Summary function for zonal extraction. Default "mean".

- ...:

  Additional arguments (not used)

## Value

Numeric vector of biodiversity index values

## Details

Biodiversity indices:

- **richness**: Mean species count per unit (raw values from raster)

- **shannon**: Shannon diversity index (if provided in raster)

- **simpson**: Simpson diversity index (if provided in raster)

For MVP (v0.1.0), this function expects pre-calculated biodiversity
rasters. Future versions will support raw species occurrence data and
in-situ calculation.

## See also

[`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Species richness
richness <- indicator_biodiversity(units, layers, index = "richness")

# Shannon index
shannon <- indicator_biodiversity(
  units, layers,
  richness_layer = "shannon_index",
  index = "shannon"
)
} # }
```
