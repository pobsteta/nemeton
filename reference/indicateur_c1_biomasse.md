# Carbon Stock via Biomass and Allometric Models (C1)

Calculates aboveground carbon stock (tC/ha) using species-specific
allometric equations from IGN/IFN literature. Requires BD Forêt v2 data
(species, age, density) or equivalent attributes.

## Usage

``` r
indicateur_c1_biomasse(
  units,
  layers = NULL,
  species_col = "species",
  age_col = "age",
  density_col = "density",
  chm = NULL,
  dbh_col = "dbh",
  stems_col = "stems_ha",
  h_dom_percentile = 0.9,
  bef = 1.3
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

- chm:

  Optional `SpatRaster` of canopy heights in metres. When supplied
  together with `dbh_col` and `species_col`, activates CHM mode (spec
  005 phase 4): biomass is derived from the IFN tarif \\V = a \cdot D^b
  \cdot H^c\\ combined with wood density, a biomass expansion factor
  (BEF) and the carbon fraction stored in
  `inst/extdata/wood_density.csv`.

- dbh_col:

  Character. Column name for mean stand DBH in cm. Used only in CHM
  mode. Default `"dbh"`.

- stems_col:

  Character. Column name for stand density in stems/ha. Used only in CHM
  mode. Default `"stems_ha"`. If missing, the value of `density_col`
  (treated as a 0-1 fraction) is multiplied by 500 stems/ha to derive a
  rough stems/ha proxy.

- h_dom_percentile:

  Numeric in `[0, 1]`. Percentile of CHM pixels used to derive dominant
  height per unit. Default `0.9`. Ignored when `chm` is `NULL`.

- bef:

  Numeric. Biomass expansion factor converting stem volume to total
  aboveground dry biomass (branches, bark). Default `1.30` (IPCC 2006
  temperate-forest default).

## Value

Numeric vector of carbon stock values (tC/ha)

## Examples

``` r
if (FALSE) { # \dontrun{
# With BD Forêt attributes
units$species <- c("Quercus", "Fagus", "Pinus")
units$age <- c(80, 60, 40)
units$density <- c(0.7, 0.8, 0.6)

results <- indicateur_c1_biomasse(units)
} # }
```
