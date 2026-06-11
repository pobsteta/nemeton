# Add a dominant-species column from a classification raster

Fills a species column on `units` from a tree-species classification
raster (typically the Theia `theia_species` product) and a user-supplied
class-to-species crosswalk. For each unit the coverage-weighted dominant
raster class is resolved, then mapped to a species code via `class_map`.
This is an upstream helper for indicators that read a species column —
[`indicateur_p1_volume()`](https://pobsteta.github.io/nemeton/reference/indicateur_p1_volume.md),
[`indicateur_p2_station()`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md),
[`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md)
and the biodiversity indicators.

## Usage

``` r
units_add_species_from_raster(
  units,
  species_raster,
  class_map,
  species_col = "species"
)
```

## Arguments

- units:

  sf object. Unit geometries to enrich.

- species_raster:

  A `SpatRaster` of integer tree-species classes.

- class_map:

  Named vector or list mapping raster class values (names, as character)
  to species codes (values). Classes absent from the map yield `NA`.

- species_col:

  Character. Name of the column to add. Default `"species"`.

## Value

The input `units` sf with the species column added (or overwritten).
Units with no raster coverage get `NA`.

## Details

The class-to-species crosswalk is product-specific (it depends on the
legend of the classification raster), so it must be supplied explicitly
rather than guessed.
