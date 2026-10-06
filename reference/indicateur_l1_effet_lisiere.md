# Sylvosphere - Edge Effect (L1)

Composite indicator (0-100) with 3 components: - Geometry (30 - Matrix
contrast (40 - Exposure (30

## Usage

``` r
indicateur_l1_effet_lisiere(
  units,
  layers = NULL,
  landcover_layer = "landcover",
  forest_values = c(16, 17),
  buffer = 50
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing land cover (optional)

- landcover_layer:

  Character. Name of land cover layer

- forest_values:

  Numeric vector. Land cover codes for forest; their matrix contrast
  is 0. Default `c(16, 17)`: OSO broadleaf and coniferous forest
  (23-class Theia/CESBIO nomenclature). Other codes are read with the
  OSO contrast table (built-up 90, roads 75, crops 50,
  orchards/vineyards 45, water 30, grassland 20, moorland 15; 50 for
  codes outside the nomenclature).

- buffer:

  Numeric. Buffer distance (meters) for contrast analysis. Default 50m.

## Value

The input `units` (same class, rows and order) with an added numeric
column `L1`: sylvosphere scores (0-100). **Higher = more edge effect
borne by the unit = less favourable**: all three components grow with it
(boundary irregularity, hostile surrounding matrix, wind and sun
exposure). The value is therefore INVERTED by normalize_indicator() so
the radar convention holds (0-100, higher = better), like R1-R5 and T3.
See spec 048 section 9.

## Renamed in 0.176.0

This indicator used to be called `indicateur_l2_fragmentation()` – a
name that announced the L2 fragmentation metric while computing the L1
edge effect. The old name, kept as a deprecated alias since then, was
removed in 1.0.0 (spec 057). Persisted columns are renamed by
[`migrer_colonnes_l`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md).
See spec 045.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
if (FALSE) { # \dontrun{
layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
results <- indicateur_l1_effet_lisiere(
  units, layers,
  forest_values = c(1, 2, 3), buffer = 50
)
} # }
```
