# Carbon Stock via Biomass and Allometric Models (C1)

Calculates aboveground carbon stock (tC/ha) using species-specific
allometric equations from IGN/IFN literature. Requires BD Forêt v2 data
(species, age, density) or equivalent attributes.

## Usage

``` r
indicator_carbon_biomass(
  units,
  layers = NULL,
  species_col = "species",
  age_col = "age",
  density_col = "density"
)
```

## Arguments

- units:

  nemeton_units object with forest parcel geometries

- layers:

  nemeton_layers object (optional for future integration)

- species_col:

  Character. Column name for species (default "species")

- age_col:

  Character. Column name for stand age (default "age")

- density_col:

  Character. Column name for stand density 0-1 (default "density")

## Value

Numeric vector of carbon stock values (tC/ha)

## Examples

``` r
if (FALSE) { # \dontrun{
# With BD Forêt attributes
units$species <- c("Quercus", "Fagus", "Pinus")
units$age <- c(80, 60, 40)
units$density <- c(0.7, 0.8, 0.6)

results <- indicator_carbon_biomass(units)
} # }
```
