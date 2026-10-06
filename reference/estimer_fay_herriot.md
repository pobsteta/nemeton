# Fay-Herriot area-level estimator (EBLUP and its MSE)

Combines, domain by domain, a design-based direct estimate (unbiased but
noisy where plots are few) with a synthetic regression prediction on
domain-level covariates. The weight given to the direct estimate,
`gamma = A / (A + psi)`, grows with the domain's sampling precision, so
a well-sampled domain keeps its own figure and a poorly sampled one
borrows strength from the others. Every estimate comes with its mean
squared error.

Domains whose direct estimate or sampling variance is missing (no plot,
or a single plot so that `psi` cannot be computed) do not enter the fit;
they receive the synthetic prediction alone and are flagged
`nature = "synthetique"`, never presented as a measurement.

## Usage

``` r
estimer_fay_herriot(direct, psi, X, methode = "REML", max_iter = 100L,
  tol = 1e-06)
```

## Arguments

- direct:

  Numeric vector of direct (design-based) domain estimates. `NA` for
  domains without one.

- psi:

  Numeric vector of sampling variances of `direct` (variance of the
  mean), treated as known. `NA` or non-positive values send the domain
  to the synthetic path.

- X:

  Covariates: a numeric matrix or data.frame with one row per domain,
  without intercept (one is added). No `NA` allowed.

- methode:

  Variance estimation method. Only `"REML"` for now.

- max_iter, tol:

  Fisher-scoring controls for the REML fit.

## Value

A data.frame with one row per domain, in input order: `direct`, `psi`,
`synthetique` (x' beta), `gamma`, `estimation`, `mse`, `rse` (relative
standard error, percent), `nature` (`"fay_herriot"` or `"synthetique"`).
Attributes: `beta` (named coefficients), `sigma2_v` (estimated
random-effect variance `A`), `vcov_beta` (covariance matrix of `beta`,
for the MSE of a synthetic prediction
`x' beta} outside the fit: \code{x' vcov_beta x`), `iterations`,
`converge`.

## Details

When the REML estimate of `A` is not positive, it is truncated to 0 with
a warning: every estimate is then the synthetic prediction, and the
caller must know it.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## References

Fay R.E., Herriot R.A. (1979). Estimates of income for small places: an
application of James-Stein procedures to census data. JASA 74:269-277.

Rao J.N.K., Molina I. (2015). Small Area Estimation, 2nd ed. Wiley.

Onwunji I.C. et al. (2026). Leveraging GEDI and NFI to inform on forest
productivity at the level of the management units. Annals of Forest
Science 83:46. doi:10.1186/s13595-026-01358-2

## Examples

``` r
set.seed(1)
x <- runif(30, 10, 30)
psi <- runif(30, 0.5, 4)
direct <- 2 + 0.3 * x + rnorm(30, 0, 1) + rnorm(30, 0, sqrt(psi))
fh <- estimer_fay_herriot(direct, psi, data.frame(h = x))
head(fh)
#>      direct      psi synthetique     gamma estimation       mse       rse
#> 1 11.503594 2.187280    7.173683 0.4159052   8.974515 1.1297250 11.843372
#> 2  7.066702 2.598480    7.718130 0.3747543   7.474005 1.1861768 14.572074
#> 3  9.854190 2.227395    8.743187 0.4114972   9.200362 1.1111301 11.457175
#> 4 10.425494 1.151762   10.455728 0.5748728  10.438347 0.8357179  8.757862
#> 5  3.463349 3.395807    6.847741 0.3144302   5.783587 1.3442912 20.047002
#> 6 10.293481 2.839634   10.405590 0.3542014  10.365881 1.3045634 11.018599
#>        nature
#> 1 fay_herriot
#> 2 fay_herriot
#> 3 fay_herriot
#> 4 fay_herriot
#> 5 fay_herriot
#> 6 fay_herriot
attr(fh, "sigma2_v")
#> [1] 1.557455
```
