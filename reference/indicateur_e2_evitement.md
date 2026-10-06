# E2: Carbon Emission Avoidance Indicator

Calculates CO2 emission avoidance (tCO2eq/year) through wood energy and
material substitution using ADEME emission factors.

## Usage

``` r
indicateur_e2_evitement(
  units,
  fuelwood_field = "E1",
  volume_field = NULL,
  energy_scenario = "vs_natural_gas",
  material_scenario = NULL,
  taux_recolte_materiau = NULL
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- fuelwood_field:

  Character. Column name for fuelwood potential (tonnes DM/yr). Default
  "E1".

- volume_field:

  Character. Column name for the standing construction timber volume
  (m³/ha, a stock). Optional; used only with `material_scenario`, and
  then annualised by `taux_recolte_materiau`.

- energy_scenario:

  Character. Energy substitution scenario: "vs_natural_gas",
  "vs_fuel_oil". Default "vs_natural_gas".

- material_scenario:

  Character. Material substitution: "vs_concrete", "vs_steel", NULL.
  Default NULL (no material substitution).

- taux_recolte_materiau:

  Numeric in `[0, 1]`, one value or one per unit: share of
  `volume_field` harvested as construction timber each year. Required
  with `material_scenario` + `volume_field`, no default on purpose: E2
  is an annual flux, and adding the standing stock (m³/ha) to the yearly
  energy substitution, as versions up to 0.211.0 did, mixed a stock and
  a flux.

## Value

sf object with added columns: E2 (total CO2 avoided tCO2eq/ha/yr),
E2_energy, E2_material. **Higher = more emissions avoided =
favourable**, not inverted. Same ref_max as E1 (2.64) because it is, to
within 0.1 quantity: E2 = E1 x 4500 kWh x 0.222 kgCO2/kWh / 1000 = E1 x
0.999. See spec 048 section 11.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).
