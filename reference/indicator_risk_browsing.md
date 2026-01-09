# Calculate Game Browsing Pressure Index (R4)

Computes browsing pressure risk from ungulates (deer, wild boar) based
on species palatability, stand vulnerability, edge exposure, and local
game density.

## Usage

``` r
indicator_risk_browsing(
  units,
  species_field = "species",
  height_field = NULL,
  age_field = NULL,
  game_density = NULL,
  edge_buffer = 50,
  weights = c(palatability = 0.35, vulnerability = 0.3, edge = 0.2, density = 0.15)
)
```

## Arguments

- units:

  An sf object with forest parcels.

- species_field:

  Character. Column name with species names.

- height_field:

  Character. Column name with stand height (meters). Optional.

- age_field:

  Character. Column name with stand age (years). Optional.

- game_density:

  SpatRaster with game density index (0-100), or NULL.

- edge_buffer:

  Numeric. Buffer distance (m) for edge effect calculation. Default 50.

- weights:

  Named numeric vector. Weights for components: c(palatability,
  vulnerability, edge, density). Default c(0.35, 0.30, 0.20, 0.15).

## Value

The input sf object with added columns:

- R4: Browsing pressure risk (0-100). Higher = higher risk.

- R4_palatability: Species palatability score (0-100).

- R4_vulnerability: Stand vulnerability score (0-100).

## Details

\*\*Formula\*\*: R4 = w1\*palatability + w2\*vulnerability +
w3\*edge_exposure + w4\*game_density

\*\*Components\*\*:

- palatability: Species attractiveness to browsers (Quercus=90,
  Abies=85, Fagus=70, Pinus=30)

- vulnerability: Young/short stands more vulnerable (\<2m = 100, \>10m =
  0)

- edge_exposure: Proportion of parcel within buffer of forest edge

- game_density: Local ungulate population index if available

\*\*Data sources for game density\*\*:

- ONF/CNPF: Consumption indices from field surveys

- Hunting federations: Harvest statistics by commune

- ONCFS/OFB: Wildlife monitoring data

## See also

Other risk-indicators:
[`indicator_risk_drought()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_drought.md),
[`indicator_risk_fire()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_fire.md),
[`indicator_risk_storm()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_storm.md)

## Examples
