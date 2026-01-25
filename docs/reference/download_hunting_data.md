# Download Hunting Statistics from data.gouv.fr

Downloads departmental hunting harvest statistics (tableaux de chasse)
for major game species from the French open data portal.

## Usage

``` r
download_hunting_data(
  species = "all",
  cache_dir = NULL,
  force_download = FALSE
)
```

## Arguments

- species:

  Character vector. Species to download: "chevreuil" (roe deer), "cerf"
  (red deer), "sanglier" (wild boar), or "all" (default).

- cache_dir:

  Character. Directory to cache downloaded files. Default uses
  rappdirs::user_cache_dir("nemeton").

- force_download:

  Logical. Force re-download even if cached. Default FALSE.

## Value

A data.frame with columns:

- code_dept: Department code (01-95, 2A, 2B, 971-976)

- nom_dept: Department name

- espece: Species name

- saison: Hunting season (e.g., "2022-2023")

- tableau: Number of animals harvested

## Details

Data source: Office Francais de la Biodiversite (OFB), formerly ONCFS.
URL:
https://www.data.gouv.fr/datasets/evolution-des-tableaux-de-chasse-departementaux-du-grand-gibier-en-france-donnees-depuis-1973

The hunting statistics provide a proxy for local game population
density. Higher harvest numbers generally indicate higher population
pressure.

## See also

Other data-acquisition:
[`compute_game_pressure_index()`](https://pobsteta.github.io/nemeton/reference/compute_game_pressure_index.md),
[`get_game_pressure_raster()`](https://pobsteta.github.io/nemeton/reference/get_game_pressure_raster.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Download roe deer statistics
chevreuil_data <- download_hunting_data(species = "chevreuil")

# Download all species
all_data <- download_hunting_data(species = "all")

# Get latest season for department 33 (Gironde)
gironde <- subset(all_data, code_dept == "33")
} # }
```
