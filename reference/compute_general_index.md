# Compute the general index (uniform NDP)

Computes the global score as the arithmetic mean of the available family
scores. With a single NDP for the whole dataset, every family carries
the same Fibonacci weight, so the Fibonacci-weighted mean reduces to a
plain mean: the NDP does not change `score`, it only sets the returned
`weight` and `confidence`. Use
[`compute_general_index_mixed`](https://pobsteta.github.io/nemeton/reference/compute_general_index_mixed.md)
when indicators come from different NDP levels: the Fibonacci weights
then differ and are applied.

## Usage

``` r
compute_general_index(family_scores, ndp = 0L)
```

## Arguments

- family_scores:

  Named numeric vector of family scores (0-100). Names should be family
  codes (e.g., "C", "B", "W") or "famille_carbone",
  "famille_biodiversite" format.

- ndp:

  Integer. NDP level (0-4). Default 0.

## Value

A list with:

- score:

  Numeric. Mean of the non-missing family scores (0-100), rounded to one
  decimal.

- ndp:

  Integer. The NDP level used.

- confidence:

  Numeric. The confidence phi ratio.

- weight:

  Integer. The Fibonacci weight.

- n_families:

  Integer. Number of families used.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
scores <- c(C = 72, B = 45, W = 68, A = 55, F = 60,
            L = 40, T = 35, R = 50, S = 65, P = 70,
            E = 48, N = 58)
result <- compute_general_index(scores, ndp = 0)
result$score
#> [1] 55.5
result$confidence
#> [1] 0.08333333
```
