# Get species configuration for a region

Loads and caches the species classification for a biogeographic region.

## Usage

``` r
get_species_config(region = "BFC")
```

## Arguments

- region:

  Character. Region code (e.g., "BFC", "EU"). Use "EU" for pan-European
  fallback.

## Value

A list with the region's species configuration.

## Examples

``` r
config <- get_species_config("BFC")
config$n_classes  # 10
#> [1] 11
config$classes[[1]]$code  # "essence_chenaie"
#> [1] "essence_chenaie"
```
