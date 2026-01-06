# E2: Carbon Emission Avoidance Indicator

Calculates CO2 emission avoidance (tCO2eq/year) through wood energy and
material substitution using ADEME emission factors.

## Usage

``` r
indicator_energy_avoidance(
  units,
  fuelwood_field = "E1",
  volume_field = NULL,
  energy_scenario = "vs_natural_gas",
  material_scenario = NULL,
  column_name = "E2",
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- fuelwood_field:

  Character. Column name for fuelwood potential (tonnes DM/yr). Default
  "E1".

- volume_field:

  Character. Column name for construction timber volume (m³/ha).
  Optional.

- energy_scenario:

  Character. Energy substitution scenario: "vs_natural_gas",
  "vs_fuel_oil". Default "vs_natural_gas".

- material_scenario:

  Character. Material substitution: "vs_concrete", "vs_steel", NULL.
  Default NULL (no material substitution).

- column_name:

  Character. Name for output column. Default "E2".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added columns: E2 (total CO2 avoided tCO2eq/yr),
E2_energy, E2_material
