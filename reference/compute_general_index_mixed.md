# Compute general index with mixed NDP per indicator

When different indicators come from different data sources, each may
have a different NDP level. This function uses per-indicator Fibonacci
weights.

## Usage

``` r
compute_general_index_mixed(family_scores, ndp_per_indicator)
```

## Arguments

- family_scores:

  Named numeric vector of family scores (0-100).

- ndp_per_indicator:

  Named integer vector mapping family codes to NDP levels (0-4). Names
  must match `family_scores` names.

## Value

A list with:

- score:

  Numeric. The weighted general index.

- confidence:

  Numeric. Average confidence across indicators.

- n_families:

  Integer. Number of families used.

- weights_used:

  Named integer vector of Fibonacci weights per family.

## Examples

``` r
scores <- c(C = 72, B = 45, W = 68)
ndps <- c(C = 2, B = 0, W = 1)
compute_general_index_mixed(scores, ndps)
#> $score
#> [1] 64.2
#> 
#> $confidence
#> [1] 0.1944444
#> 
#> $n_families
#> [1] 3
#> 
#> $weights_used
#> C B W 
#> 2 1 1 
#> 
```
