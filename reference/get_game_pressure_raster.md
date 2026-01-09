# Get Game Pressure Raster for R4 Indicator

Creates a SpatRaster of game pressure index by department for use with
the
[`indicator_risk_browsing`](https://pobsteta.github.io/nemeton/reference/indicator_risk_browsing.md)
function.

## Usage

``` r
get_game_pressure_raster(units, pressure_data = NULL, dept_boundaries = NULL)
```

## Arguments

- units:

  sf object. Forest parcels to determine spatial extent and CRS.

- pressure_data:

  Data.frame from
  [`compute_game_pressure_index`](https://pobsteta.github.io/nemeton/reference/compute_game_pressure_index.md),
  or NULL to compute automatically.

- dept_boundaries:

  sf object. Department boundaries with code_dept column, or NULL to
  download from IGN.

## Value

A SpatRaster with game pressure index (0-100) per pixel, matching the
extent and CRS of the input units.

## Details

This function: 1. Downloads/computes game pressure index by department
2. Downloads department boundaries if not provided 3. Rasterizes the
pressure values 4. Returns a raster for use with
indicator_risk_browsing(game_density = ...)

## See also

Other data-acquisition:
[`compute_game_pressure_index()`](https://pobsteta.github.io/nemeton/reference/compute_game_pressure_index.md),
[`download_hunting_data()`](https://pobsteta.github.io/nemeton/reference/download_hunting_data.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(sf)

# Load parcels
parcels <- st_read("parcels.gpkg")

# Get game pressure raster
game_raster <- get_game_pressure_raster(parcels)

# Use with R4 indicator
result <- indicator_risk_browsing(
  parcels,
  species_field = "essence",
  game_density = game_raster
)
} # }
```
