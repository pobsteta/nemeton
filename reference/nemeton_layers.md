# Create nemeton_layers object

Creates a catalog of spatial layers (rasters and vectors) with lazy
loading.

## Usage

``` r
nemeton_layers(rasters = NULL, vectors = NULL, validate = TRUE)
```

## Arguments

- rasters:

  Named list of paths to raster files (GeoTIFF, etc.)

- vectors:

  Named list of paths to vector files (GeoPackage, shapefile, etc.)

- validate:

  Logical. Validate file existence? Default TRUE.

## Value

An object of class `nemeton_layers`

## Details

Layers are not loaded into memory until first use (lazy loading). This
allows creating a catalog of large rasters without memory overhead.

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(
  rasters = list(
    ndvi = "data/sentinel2_ndvi.tif",
    dem = "data/ign_mnt_25m.tif"
  ),
  vectors = list(
    rivers = "data/bdtopo_hydro.gpkg",
    roads = "data/routes.shp"
  )
)

summary(layers)
} # }
```
