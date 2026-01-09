# Calculate Drought Stress Index (R3)

Computes drought stress based on topographic wetness (inverse TWI),
precipitation deficit, and species sensitivity.

## Usage

``` r
indicator_risk_drought(
  units,
  twi_field = "W3",
  climate = NULL,
  species_field = "species",
  weights = c(twi = 0.4, precip = 0.4, species = 0.2)
)
```

## Arguments

- units:

  An sf object with forest parcels.

- twi_field:

  Character. Column name with Topographic Wetness Index (TWI). Can reuse
  W3 from v0.2.0.

- climate:

  List with 'precipitation' SpatRaster, or NULL.

- species_field:

  Character. Column name with species names.

- weights:

  Named numeric vector. Weights for components: c(twi, precip, species).
  Default c(0.4, 0.4, 0.2).

## Value

The input sf object with added column:

- R3: Drought stress (0-100). Higher = higher stress.

## Details

\*\*Formula\*\*: R3 = w1×(100-TWI_norm) + w2×precip_deficit +
w3×species_sensitivity

\*\*Components\*\*:

- Inverse TWI: Low TWI (dry sites) = high drought stress

- Precipitation deficit: Low annual precip = high stress

- Species sensitivity: Fagus (80), Quercus (50), Pinus (50), others (50)

## See also

Other risk-indicators:
[`indicator_risk_browsing()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_browsing.md),
[`indicator_risk_fire()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_fire.md),
[`indicator_risk_storm()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_storm.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units

# Reuse W3 (TWI) from v0.2.0
units$W3 <- runif(nrow(units), 5, 15)
units$species <- sample(c("Fagus", "Quercus", "Pinus"), nrow(units), replace = TRUE)

climate <- list(precipitation = rast("path/to/precip.tif"))

result <- indicator_risk_drought(units, twi_field = "W3", climate = climate, species_field = "species")
summary(result$R3)
} # }
```
