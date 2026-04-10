# Compute Fibonacci-weighted general index

Computes the global score as a Fibonacci-weighted mean of family scores.
The NDP determines the weight and confidence level.

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

  Numeric. The weighted general index (0-100).

- ndp:

  Integer. The NDP level used.

- confidence:

  Numeric. The confidence phi ratio.

- weight:

  Integer. The Fibonacci weight.

- n_families:

  Integer. Number of families used.

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
