# Wetland Coverage (W2)

Calculates percentage of parcel area classified as wetland or riparian
zone. Coverage is summed over several optional sources: BD TOPO water
surfaces, a TWI threshold, OSO land-cover wetland codes, and — when
supplied — the Theia `theia_water` water-occurrence product.

## Usage

``` r
indicateur_w2_zones_humides(
  units,
  layers,
  wetland_layer = "wetlands",
  wetland_values = NULL,
  water_occurrence = NULL,
  occurrence_threshold = 25,
  dem_target_res = .topo_target_res()
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing land cover raster or wetland vector

- wetland_layer:

  Character. Name of wetland layer in layers object

- wetland_values:

  Numeric vector. Land cover codes representing wetlands. Default NULL
  (auto-detect if possible).

- water_occurrence:

  Optional `SpatRaster` of water-occurrence frequency in percent (0-100)
  — the Theia `theia_water` `water_occurrence` product, loaded via
  [`load_raster_source`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md).
  When supplied, pixels whose occurrence reaches `occurrence_threshold`
  contribute to the wetland coverage. Default `NULL`.

- occurrence_threshold:

  Numeric in `[0, 100]`. Minimum water-occurrence frequency (percent of
  observations) for a pixel to count as wetland. Default `25`. Ignored
  when `water_occurrence` is `NULL`.

- dem_target_res:

  Numeric. Working resolution (metres) the DEM is aggregated to before
  TWI is computed. The same value drives the TWI grid, so both coincide
  and the TWI is never resampled up to a finer grid. Keep it identical
  across W2/W3/F2/R3 to share a single cached TWI. Default: the
  package-wide topographic working resolution, 2 m — see
  `options("nemeton.topo_target_res")`; `NULL` keeps the native
  resolution.

## Value

Numeric vector of wetland coverage (0-100%)

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
results <- indicateur_w2_zones_humides(units, layers, wetland_values = c(50, 51, 52))
} # }
```
