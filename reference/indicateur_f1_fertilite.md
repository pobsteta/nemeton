# Soil Fertility Class (F1)

Extracts soil fertility from a user-supplied pedological layer, from the
SoilGrids 2.0 global CEC topsoil raster, or from a French RRP polygon
layer joined to the UTS → fertility crosswalk shipped in
`inst/extdata/uts_fertilite_fr.csv`.

## Usage

``` r
indicateur_f1_fertilite(
  units,
  layers = NULL,
  soil_layer = "soil",
  fertility_col = "fertility",
  source = c("layer", "soilgrids", "gissol", "theia_soil"),
  country = "FR",
  rpf_code_col = "rpf_code",
  texture = NULL
)
```

## Arguments

- units:

  nemeton_units object

- layers:

  nemeton_layers object containing soil data. Unused when
  `source = "soilgrids"`.

- soil_layer:

  Character. Name of soil layer in layers object. Unused when
  `source = "soilgrids"`.

- fertility_col:

  Character. Column/band name for fertility class in `"layer"` mode.
  Unused when `source` is `"soilgrids"` or `"gissol"`.

- source:

  Character. One of `"layer"` (default), `"soilgrids"`, `"gissol"`, or
  `"theia_soil"`.

- country:

  Character. Country code used to resolve the SoilGrids datasource
  entry. Default `"FR"`.

- rpf_code_col:

  Character. Column in the RRP layer that carries the AFES 2008 code
  (matching the `rpf_code` primary key of
  [`read_uts_fertility_table`](https://pobsteta.github.io/nemeton/reference/read_uts_fertility_table.md)).
  Default `"rpf_code"`. Only used when `source = "gissol"`.

- texture:

  Optional named list of `SpatRaster`s with elements `clay`, `silt`,
  `sand` and optionally `coarse_elements` (the Theia `theia_soil`
  products, loaded via
  [`load_raster_source`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)).
  Required when `source = "theia_soil"`, ignored otherwise.

## Value

Numeric vector of fertility scores (0-100 scale, higher = more fertile)

## Details

Three data sources are supported via `source`:

- `"layer"` (default) — read a raster or polygon layer from `layers`,
  min-max normalised per call (relative score).

- `"soilgrids"` — fetch the 250 m SoilGrids 2.0 Cation Exchange Capacity
  raster (0-5 cm topsoil, mean) declared as `soilgrids_cec` in
  `inst/datasources/FR.json`, extract the per-unit mean and map it to
  0-100 via
  [`cec_to_fertility_score`](https://pobsteta.github.io/nemeton/reference/cec_to_fertility_score.md)
  (absolute score, comparable across projects). No inventory layer is
  needed.

- `"gissol"` — read a French RRP (Référentiel Régional Pédologique)
  polygon layer from `layers` that carries a pedological typology code
  (AFES 2008 Référentiel Pédologique), intersect it with `units`, join
  the AFES code against
  [`read_uts_fertility_table`](https://pobsteta.github.io/nemeton/reference/read_uts_fertility_table.md),
  and return an area-weighted fertility score per unit on the 0-100
  scale. France metropolitan only. Unknown codes are silently dropped;
  units whose polygons carry only unknown codes return NA.

- `"theia_soil"` — derive fertility from a Theia `theia_soil` texture
  raster set passed via `texture` (a named list of clay / silt / sand,
  optionally `coarse_elements`, `SpatRaster`s). The per-unit mean
  texture is mapped to a 0-100 score via
  [`texture_to_fertility_score`](https://pobsteta.github.io/nemeton/reference/texture_to_fertility_score.md).
  No inventory layer is needed.

SoilGrids is global — the `"soilgrids"` mode works for any AOI,
`country` only controls where the datasource entry is looked up.

## Examples

``` r
if (FALSE) { # \dontrun{
# Traditional path: user-supplied soil layer
layers <- nemeton_layers(vectors = list(soil = "bd_sol.gpkg"))
results <- indicateur_f1_fertilite(units, layers, soil_layer = "soil")

# SoilGrids path: no soil layer needed
results <- indicateur_f1_fertilite(units, source = "soilgrids")

# GIS Sol path: RRP polygons + AFES typology join
layers <- nemeton_layers(vectors = list(soil = "rrp_departement.gpkg"))
results <- indicateur_f1_fertilite(units, layers,
                                   source = "gissol",
                                   rpf_code_col = "UTSDom")
} # }
```
