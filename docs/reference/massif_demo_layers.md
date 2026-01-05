# Load Massif Demo Spatial Layers

Convenience function to load all spatial layers associated with the
[`massif_demo_units`](https://pobsteta.github.io/nemeton/reference/massif_demo_units.md)
dataset.

## Usage

``` r
massif_demo_layers()
```

## Value

A `nemeton_layers` object containing:

- rasters:

  - `biomass`: Aboveground biomass (Mg/ha)

  - `dem`: Digital Elevation Model (m)

  - `landcover`: Land cover classification (6 classes)

  - `species_richness`: Number of species per pixel

- vectors:

  - `roads`: Road network (Départementale, Forestière, Chemin)

  - `water`: Water courses (Ruisseau, Rivière, Torrent)

## Details

All layers are in Lambert-93 projection (EPSG:2154) and cover the same
extent as `massif_demo_units`.

The returned object can be used directly with
[`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)
to calculate biophysical indicators.

## File Locations

The function loads files from the package installation directory: -
Rasters: `inst/extdata/massif_demo_*.tif` - Vectors:
`inst/extdata/massif_demo_*.gpkg`

## See also

[`massif_demo_units`](https://pobsteta.github.io/nemeton/reference/massif_demo_units.md),
[`nemeton_layers`](https://pobsteta.github.io/nemeton/reference/nemeton_layers.md),
[`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)

## Examples

``` r
# Load demo parcels and layers
data(massif_demo_units)
layers <- massif_demo_layers()
#> ℹ Chargement des couches spatiales Massif Demo...
#> ℹ Created layer catalog: 4 rasters, 2 vectors
#> ✔ 4 couches raster et 2 couches vecteur chargées

# Inspect layers
print(layers)
#> 
#> ── nemeton_layers object ───────
#> 
#> ── Rasters (4) ──
#> 
#> • biomass : massif_demo_biomass.tif [not loaded] 
#> • dem : massif_demo_dem.tif [not loaded] 
#> • landcover : massif_demo_landcover.tif [not loaded] 
#> • species_richness : massif_demo_species_richness.tif [not loaded] 
#> 
#> ── Vectors (2) ──
#> 
#> • roads : massif_demo_roads.gpkg [not loaded] 
#> • water : massif_demo_water.gpkg [not loaded] 
#> 

if (FALSE) { # \dontrun{
# Compute all indicators
results <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "all",
  preprocess = TRUE
)

# Carbon indicator only
carbon <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "carbon",
  preprocess = TRUE
)

# Water regulation (using DEM and water courses)
water <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "water",
  preprocess = TRUE
)

# Fragmentation (using land cover)
fragmentation <- nemeton_compute(
  massif_demo_units,
  layers,
  indicators = "fragmentation",
  forest_values = c(1, 2, 3),  # Forest classes
  preprocess = TRUE
)
} # }
```
