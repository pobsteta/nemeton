# Get NDP level configuration

Returns the full configuration list for a given NDP level.

## Usage

``` r
get_ndp_level(ndp)
```

## Arguments

- ndp:

  Integer. NDP level (0-4).

## Value

A list with elements: ndp, key, name, fibonacci, confidence, sources.

## Examples

``` r
get_ndp_level(0)
#> $ndp
#> [1] 0
#> 
#> $key
#> [1] "ndp_decouverte"
#> 
#> $name
#> [1] "Découverte"
#> 
#> $fibonacci
#> [1] 1
#> 
#> $confidence
#> [1] 0.08333333
#> 
#> $sources
#> [1] "sentinel_2" "worldclim"  "bd_topo"    "mnt_25m"   
#> 
get_ndp_level(4)
#> $ndp
#> [1] 4
#> 
#> $key
#> [1] "ndp_jumeau"
#> 
#> $name
#> [1] "Jumeau"
#> 
#> $fibonacci
#> [1] 5
#> 
#> $confidence
#> [1] 1
#> 
#> $sources
#> [1] "scanner_terrestre" "modele_3d"        
#> 
```
