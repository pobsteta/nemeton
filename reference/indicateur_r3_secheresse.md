# Calculate Drought Stress Index (R3)

Computes drought stress combining a climate component (SPEI-3 index) and
a topographic modulation (aspect, slope, TWI). Falls back to
topographic-only assessment when SPEI is unavailable.

## Usage

``` r
indicateur_r3_secheresse(
  units,
  layers = NULL,
  dem = NULL,
  climate_data = NULL,
  snow = NULL,
  snow_relief_strength = 0.3,
  soil_moisture = NULL,
  sm_relief_strength = 0.3
)
```

## Arguments

- units:

  An sf object with forest parcels.

- layers:

  A nemeton_layers object. Used to extract DEM.

- dem:

  A SpatRaster with digital elevation model (meters).

- climate_data:

  Optional list with `precip` (monthly precipitation vector in mm) and
  `temp` (list with `tmin` and `tmax` monthly vectors in degrees C). If
  NULL, uses simulated data.

- snow:

  Optional `SpatRaster` of snow-cover duration in days per year (the
  Theia `theia_snow` `snow_cover_duration` product, loaded via
  [`load_raster_source`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)).
  When supplied, the snowpack acts as a seasonal water reserve that
  attenuates drought stress — see Details. Units with no snow coverage
  are left unchanged. Default `NULL`.

- snow_relief_strength:

  Numeric in `[0, 1]`. Maximum fractional reduction of R3 applied when
  the snow-cover duration reaches the 180-day (6-month) reference.
  Default `0.3`. Ignored when `snow` is `NULL`.

- soil_moisture:

  Optional `SpatRaster` of surface soil moisture in \\m^3/m^3\\ (the
  Theia `theia_soil_moisture` product, loaded via
  [`load_raster_source`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)).
  When supplied, moist soil attenuates drought stress — see Details.
  Default `NULL`.

- sm_relief_strength:

  Numeric in `[0, 1]`. Maximum fractional reduction of R3 applied when
  the soil moisture reaches the \\0.3\\m^3/m^3\\ field-capacity
  reference. Default `0.3`. Ignored when `soil_moisture` is `NULL`.

## Value

The input sf object with added column:

- R3: Drought stress (0-100). Higher = higher stress.

## Details

\*\*Climate component\*\* (weight 0.6): Uses SPEI-3 (Standardised
Precipitation-Evapotranspiration Index at 3-month scale) via SPEI. PET
is computed with the Hargreaves method. R3_climat = (-SPEI_recent + 2) /
4, clamped to 0-1. Falls back to 0.5 without SPEI.

\*\*Topographic component\*\* (weight 0.4):

- aspect_risk: south-facing = max risk

- slope_risk: steep slopes = runoff = dry

- twi_risk: low TWI = dry

topo_risk = 0.4\*aspect_risk + 0.3\*slope_risk + 0.3\*twi_risk

R3 = (0.6 \* climate + 0.4 \* topo) \* 100

\*\*Snow attenuation\*\* (Theia `theia_snow`, optional): when `snow` is
supplied, the per-unit mean snow-cover duration is rescaled to a 0-1
relief factor against a 180-day reference, and R3 is multiplied by
`1 - snow_relief_strength * relief`. A forest with a long-lasting
snowpack carries a meltwater reserve into the growing season and is
therefore less drought-stressed.

\*\*Soil-moisture attenuation\*\* (Theia `theia_soil_moisture`,
optional): when `soil_moisture` is supplied, the per-unit mean surface
soil moisture is rescaled to a 0-1 relief factor against the
\\0.3\\m^3/m^3\\ field-capacity reference, and R3 is multiplied by
`1 - sm_relief_strength * relief`. Moist soil buffers drought stress.

## See also

Other risk-indicators:
[`indicateur_r1_feu()`](https://pobsteta.github.io/nemeton/reference/indicateur_r1_feu.md),
[`indicateur_r2_tempete()`](https://pobsteta.github.io/nemeton/reference/indicateur_r2_tempete.md),
[`indicateur_r4_abroutissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r4_abroutissement.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units
dem <- rast("path/to/dem.tif")

result <- indicateur_r3_secheresse(units, dem = dem)
summary(result$R3)
} # }
```
