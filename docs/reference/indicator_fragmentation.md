# Calculate forest fragmentation indicator

Quantifies forest fragmentation from land cover data.

## Usage

``` r
indicator_fragmentation(
  units,
  layers,
  landcover_layer = "landcover",
  forest_values = NULL,
  metric = c("forest_pct", "edge_density", "patch_count"),
  ...
)
```

## Arguments

- units:

  A `nemeton_units` or `sf` object representing analysis units

- layers:

  A `nemeton_layers` object containing spatial data

- landcover_layer:

  Character. Name of land cover raster layer. Default "landcover".

- forest_values:

  Numeric vector. Raster values representing forest classes. Default
  NULL (auto-detect if possible).

- metric:

  Character. Fragmentation metric to calculate. Options: "forest_pct",
  "edge_density", "patch_count". Default "forest_pct".

- ...:

  Additional arguments (not used)

## Value

Numeric vector of fragmentation indicator values

## Details

Fragmentation metrics:

- **forest_pct**: Percentage of forest cover in each unit (simple
  metric)

- **edge_density**: Ratio of forest edge to total forest area (higher =
  more fragmented)

- **patch_count**: Number of distinct forest patches (higher = more
  fragmented)

For MVP (v0.1.0), only forest_pct is implemented. Future versions will
add advanced landscape metrics using landscapemetrics package.

## See also

[`nemeton_compute`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Forest percentage
forest_pct <- indicator_fragmentation(
  units, layers,
  forest_values = c(1, 2, 3)
)
} # }
```
