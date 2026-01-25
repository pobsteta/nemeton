# E1: Fuelwood Potential Indicator

Calculates mobilizable fuelwood potential (tonnes dry matter/year) from
forest harvest residues and coppice biomass.

## Usage

``` r
indicator_energy_fuelwood(
  units,
  volume_field = "volume",
  species_field = "species",
  harvest_rate = 0.02,
  residue_fraction = 0.3,
  coppice_area_field = NULL,
  column_name = "E1",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- volume_field:

  Character. Column name containing standing volume (m³/ha). Default
  "volume".

- species_field:

  Character. Column name containing species codes. Default "species".

- harvest_rate:

  Numeric. Annual harvest rate (fraction of volume). Default 0.02 (2
  percent/year).

- residue_fraction:

  Numeric. Fraction of harvest available as residues. Default 0.3 (30
  percent).

- coppice_area_field:

  Character. Column name for coppice area fraction. Optional.

- column_name:

  Character. Name for output column. Default "E1".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added columns: E1 (fuelwood potential tonnes DM/yr),
E1_residues, E1_coppice
