# NDVI Mean and Trend Analysis (C2)

Extracts mean NDVI from Sentinel-2 or equivalent satellite imagery.
Optionally calculates NDVI trend over multiple dates (requires temporal
rasters).

## Usage

``` r
indicateur_c2_ndvi(
  units,
  layers,
  ndvi_layer = "ndvi",
  trend = FALSE,
  fapar = NULL
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing NDVI raster(s)

- ndvi_layer:

  Character. Name of NDVI layer in layers object

- trend:

  Logical. Calculate temporal trend if multiple dates available? Default
  FALSE.

- fapar:

  Optional `SpatRaster` of FAPAR values in `[0, 1]` (typically the Theia
  `s2_biophysical` FAPAR product, loaded via
  [`load_raster_source`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)).
  When supplied, activates FAPAR mode: the function returns the per-unit
  mean FAPAR and ignores `ndvi_layer`. The raster is expected in the CRS
  of `units`.

## Value

Numeric vector of NDVI mean values (0-1 scale), or list with mean and
trend if trend = TRUE

## Details

In FAPAR mode (Theia `s2_biophysical`, phase 3a), when a FAPAR raster is
supplied via `fapar`, the per-unit mean Fraction of Absorbed
Photosynthetically Active Radiation is returned instead of NDVI. FAPAR
is a physically grounded vitality measure on the same `[0, 1]` scale as
NDVI, so downstream normalization is unchanged. When `fapar` is `NULL`
the pre-existing NDVI behaviour is preserved.

## Examples

``` r
if (FALSE) { # \dontrun{
# Single-date NDVI
layers <- nemeton_layers(rasters = list(ndvi = "sentinel2_ndvi.tif"))
results <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi")

# Multi-date NDVI with trend
results <- indicateur_c2_ndvi(units, layers, ndvi_layer = "ndvi", trend = TRUE)

# FAPAR mode (Theia s2_biophysical)
fapar <- load_raster_source("s2_biophysical", "FR", path = "fapar_2023.tif")
results <- indicateur_c2_ndvi(units, layers, fapar = fapar)
} # }
```
