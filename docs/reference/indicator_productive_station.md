# P2: Site Productivity Index Indicator

Calculates a site productivity index combining soil fertility, climate
suitability, and species-specific growth potential using reference
productivity tables.

## Usage

``` r
indicator_productive_station(
  units,
  species_field = "species",
  fertility_field = "fertility",
  climate_field = "climate",
  productivity_table = NULL,
  column_name = "P2",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- species_field:

  Character. Column name containing species codes. Default "species".

- fertility_field:

  Character. Column name containing fertility class (1=high, 2=medium,
  3=low). Default "fertility".

- climate_field:

  Character. Column name containing climate zone. Default "climate".

- productivity_table:

  Data.frame. Custom productivity reference table. If NULL, uses bundled
  ONF/IFN tables.

- column_name:

  Character. Name for output column. Default "P2".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added column: P2 (annual increment in m³/ha/yr)

## Details

\*\*Calculation\*\*:

- Lookup reference productivity from ONF/IFN tables

- Match by species × fertility class × climate zone

- P2 = annual increment (m³/ha/year) for the site

\*\*Fertility Classes\*\*:

- 1: High fertility (rich soils, optimal drainage)

- 2: Medium fertility (average conditions)

- 3: Low fertility (poor soils, constraints)

\*\*Climate Zones\*\*:

- temperate_oceanic: Atlantic climate (Brittany, Normandy)

- temperate_continental: Continental (Lorraine, Burgundy)

- mountainous: Mountain zones (Alps, Pyrenees, Massif Central)

- atlantic: Southwest Atlantic (Landes, Gironde)

- mediterranean: Mediterranean (Provence, Languedoc)

## Examples

``` r
if (FALSE) { # \dontrun{
units$species <- c("FASY", "PIAB", "QUPE")
units$fertility <- c(1, 2, 2)
units$climate <- c("temperate_oceanic", "mountainous", "temperate_oceanic")

result <- indicator_productive_station(
  units = units,
  species_field = "species",
  fertility_field = "fertility",
  climate_field = "climate"
)
} # }
```
