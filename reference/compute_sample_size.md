# Sample size for a target relative error and a given CV

Sample size for a target relative error and a given CV

## Usage

``` r
compute_sample_size(
  cv,
  target_error,
  alpha = 0.05,
  N = NULL,
  max_iter = 20L,
  tol = 0.5
)
```

## Arguments

- cv:

  Numeric. Coefficient of variation as a fraction (e.g., 0.35 for 35 %).
  Non-negative.

- target_error:

  Numeric. Target relative error on the mean, as a fraction (e.g., 0.10
  for \\\pm\\10 %). Strictly positive.

- alpha:

  Numeric. Significance level. Default 0.05 (95 % confidence).

- N:

  Optional. Population size (number of plots the AOI can host at the
  target plot density). When provided, a finite- population correction
  is applied.

- max_iter:

  Integer. Maximum number of Student-iteration steps. Default 20
  (convergence is typically reached in 2-4).

- tol:

  Numeric. Convergence tolerance on \\n\\ between two iterations.
  Default 0.5 (half a plot).

## Value

A list with:

- `n`: the minimum sample size (rounded up).

- `t_used`: the Student quantile at convergence.

- `df`: degrees of freedom at convergence (\\n - 1\\).

- `converged`: logical.

- `iterations`: number of iterations.

- `fpc_applied`: logical, TRUE when `N` was used.

- `inputs`: echo of `cv`, `target_error`, `alpha`, `N`.

## Examples

``` r
# Conifer plantation, ±10 % on G/ha, 95 % confidence:
compute_sample_size(cv = 0.30, target_error = 0.10)
#> $n
#> [1] 38
#> 
#> $t_used
#> [1] 2.027695
#> 
#> $df
#> [1] 37
#> 
#> $converged
#> [1] TRUE
#> 
#> $iterations
#> [1] 2
#> 
#> $fpc_applied
#> [1] FALSE
#> 
#> $inputs
#> $inputs$cv
#> [1] 0.3
#> 
#> $inputs$target_error
#> [1] 0.1
#> 
#> $inputs$alpha
#> [1] 0.05
#> 
#> $inputs$N
#> NULL
#> 
#> 

# Same, with an AOI that hosts at most 200 plots:
compute_sample_size(cv = 0.30, target_error = 0.10, N = 200)
#> $n
#> [1] 32
#> 
#> $t_used
#> [1] 2.027695
#> 
#> $df
#> [1] 31
#> 
#> $converged
#> [1] TRUE
#> 
#> $iterations
#> [1] 2
#> 
#> $fpc_applied
#> [1] TRUE
#> 
#> $inputs
#> $inputs$cv
#> [1] 0.3
#> 
#> $inputs$target_error
#> [1] 0.1
#> 
#> $inputs$alpha
#> [1] 0.05
#> 
#> $inputs$N
#> [1] 200
#> 
#> 
```
