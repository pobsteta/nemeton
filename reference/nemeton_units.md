# Create nemeton_units object

Creates a nemeton_units object from spatial data, representing spatial
analysis units (forest parcels, plots, grids).

## Usage

``` r
nemeton_units(x, id_col = NULL, metadata = list(), validate = TRUE)
```

## Arguments

- x:

  An `sf` object or path to spatial file (GeoPackage, shapefile)

- id_col:

  Character. Name of column to use as unique identifier. If NULL,
  generates automatically as "unit_001", "unit_002", etc.

- metadata:

  Named list of metadata (site_name, year, source, description, etc.)

- validate:

  Logical. Validate geometries? Default TRUE.

## Value

An object of class `nemeton_units` (inherits from `sf`)

## Details

The function validates that:

- Geometries are POLYGON or MULTIPOLYGON

- CRS is defined

- Geometries are valid (if validate = TRUE)

- No empty geometries

Metadata are stored as an attribute and can include:

- site_name: Name of the site/forest

- year: Reference year

- source: Data source

- description: Optional description

## Examples

``` r
if (FALSE) { # \dontrun{
library(sf)

# From sf object
polygons <- st_read("parcels.gpkg")
units <- nemeton_units(
  polygons,
  metadata = list(
    site_name = "Forêt de Fontainebleau",
    year = 2024,
    source = "IGN BD Forêt v2"
  )
)

# From file path
units <- nemeton_units(
  "parcels.gpkg",
  id_col = "parcel_id",
  metadata = list(site_name = "Test Forest")
)
} # }
```
