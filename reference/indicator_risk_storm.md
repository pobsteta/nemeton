# Calculate Storm Vulnerability Index (R2)

Computes storm vulnerability based on stand height, density, and
topographic exposure.

## Usage

``` r
indicator_risk_storm(
  units,
  dem,
  height_field = "height",
  density_field = "density",
  weights = c(height = 1/3, density = 1/3, exposure = 1/3)
)
```

## Arguments

- units:

  An sf object with forest parcels.

- dem:

  A SpatRaster with digital elevation model (meters).

- height_field:

  Character. Column name with stand height (meters).

- density_field:

  Character. Column name with stand density (0-1 scale).

- weights:

  Named numeric vector. Weights for components: c(height, density,
  exposure). Default c(1/3, 1/3, 1/3).

## Value

The input sf object with added column:

- R2: Storm vulnerability (0-100). Higher = more vulnerable.

## Details

\*\*Formula\*\*: R2 = w1×height_factor + w2×density_factor +
w3×exposure_factor

\*\*Components\*\*:

- height_factor: Taller stands (\>30m) are more vulnerable

- density_factor: Dense stands (\>0.8) have higher wind load

- exposure_factor: Topographic Position Index from DEM (ridges =
  exposed)

## See also

Other risk-indicators:
[`indicator_risk_drought()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_drought.md),
[`indicator_risk_fire()`](https://pobsteta.github.io/nemeton/reference/indicator_risk_fire.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units
units$height <- runif(nrow(units), 10, 35)
units$density <- runif(nrow(units), 0.5, 1.0)

dem <- rast("path/to/dem.tif")

result <- indicator_risk_storm(units, dem = dem, height_field = "height", density_field = "density")
summary(result$R2)
} # }
```
