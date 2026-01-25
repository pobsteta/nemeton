# Compute Game Browsing Pressure Index by Department

Calculates a browsing pressure index (0-100) for each department based
on hunting harvest statistics. Higher values indicate higher game
populations and thus higher browsing pressure on forests.

## Usage

``` r
compute_game_pressure_index(
  hunting_data = NULL,
  season = "latest",
  weights = c(chevreuil = 0.3, cerf = 0.25, sanglier = 0.15, chamois = 0.08, mouflon =
    0.07, daim = 0.06, isard = 0.05, cerf_sika = 0.04),
  normalize_by = "rank",
  dept_forest_area = NULL
)
```

## Arguments

- hunting_data:

  Data.frame from
  [`download_hunting_data`](https://pobsteta.github.io/nemeton/reference/download_hunting_data.md),
  or NULL to download automatically.

- season:

  Character. Hunting season to use (e.g., "2022-2023"). Default "latest"
  uses most recent available.

- weights:

  Named numeric vector. Weights for species contribution to browsing
  pressure. Default weights reflect relative forest impact: chevreuil
  (0.30), cerf (0.25), sanglier (0.15), chamois (0.08), mouflon (0.07),
  daim (0.06), isard (0.05), cerf_sika (0.04).

- normalize_by:

  Character. How to normalize harvest numbers: "area" (per km2 of
  forest, requires dept_forest_area), "rank" (percentile rank), or
  "minmax" (min-max scaling). Default "rank".

- dept_forest_area:

  Named numeric vector. Forest area (km2) by department code. Only
  needed if normalize_by = "area". If NULL, uses built-in estimates.

## Value

A data.frame with columns:

- code_dept: Department code

- nom_dept: Department name

- pressure_index: Browsing pressure index (0-100)

- \<species\>\_harvest: Harvest count for each species present

## Details

The pressure index combines harvest statistics for 8 large game species
affecting forest regeneration:

- Chevreuil (roe deer): Main browser, high impact on regeneration

- Cerf (red deer): Significant browser, bark stripping

- Sanglier (wild boar): Root damage, seed predation

- Chamois: Alpine browser, localized impact

- Isard (Pyrenean chamois): Pyrenees only

- Mouflon: Mediterranean zones

- Daim (fallow deer): Browser, localized populations

- Cerf sika (sika deer): Bark stripping, limited range

Weights reflect relative impact on forest browsing (not total damage).
Mountain ungulates (chamois, isard, mouflon) have lower weights as they
primarily affect alpine/subalpine forests.

## See also

Other data-acquisition:
[`download_hunting_data()`](https://pobsteta.github.io/nemeton/reference/download_hunting_data.md),
[`get_game_pressure_raster()`](https://pobsteta.github.io/nemeton/reference/get_game_pressure_raster.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Compute pressure index for latest season
pressure <- compute_game_pressure_index()

# Get departments with highest pressure
high_pressure <- pressure[pressure$pressure_index > 75, ]

# Use with R4 indicator
# (Convert to spatial and join with parcels)
} # }
```
