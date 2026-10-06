# Landscape Fragmentation (L2)

Calculates landscape fragmentation using landscapemetrics (COHESION +
AI) when available, or shape index fallback. Returns a score 0-100.

## Usage

``` r
indicateur_l2_morcellement(
  units,
  layers = NULL,
  landcover_layer = "landcover",
  forest_values = c(16, 17),
  buffer = 1000
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object (optional, for raster-based metrics)

- landcover_layer:

  Character. Name of landcover layer in layers.

- forest_values:

  Numeric vector. Values representing forest in landcover. Default
  `c(16, 17)`: OSO broadleaf and coniferous forest (23-class
  Theia/CESBIO nomenclature, the `forest_cover` layer). Pass the codes
  of your own raster when it uses another nomenclature.

- buffer:

  Numeric. Buffer distance in meters around union of parcels.

## Value

The input `units` (same class, rows and order) with an added numeric
column `L2`: fragmentation scores (0-100). **Higher = less fragmented =
favourable** (COHESION + AI, or the inverse shape index in the
fallback): already oriented the right way, so normalize_indicator()
passes it through and does NOT invert it – unlike L1.

## Renamed in 0.176.0

This indicator used to be called `indicateur_l1_sylvosphere()` – a name
that announced the L1 sylvosphere while computing the L2 fragmentation
metric. The old name, kept as a deprecated alias since then, was removed
in 1.0.0 (spec 057). Persisted columns are renamed by
[`migrer_colonnes_l`](https://pobsteta.github.io/nemeton/reference/migrer_colonnes_l.md).
See spec 045.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
if (FALSE) { # \dontrun{
results <- indicateur_l2_morcellement(units, layers, buffer = 1000)
} # }
```
