# Estimate the site index from a dominant height and a stand age

Given an observed dominant height `H_dom` (typically derived from a
Canopy Height Model) and the stand age, returns the dominant height that
the same fertility level would reach at `reference_age`. This is the
classical definition of the site index in French forestry.

## Usage

``` r
compute_site_index(H_dom, age, species, reference_age = 50)
```

## Arguments

- H_dom:

  Numeric vector. Observed dominant height in metres.

- age:

  Numeric vector. Stand age in years.

- species:

  Character vector. Species codes (IFN style, 4 letters). Recycled
  against `H_dom` / `age`.

- reference_age:

  Numeric scalar. Reference age at which the site index is returned
  (default 50).

## Value

A numeric vector of the same length as the recycled inputs, giving the
site index (dominant height at `reference_age`) in metres. `NA` is
returned when `H_dom` or `age` is missing, when `age` is outside the
tabulated range, or when the species cannot be resolved.

## Details

The computation is a bilinear interpolation over the five fertility
classes tabulated in `inst/extdata/site_index_curves.csv`:

1.  At the observed `age`, find which pair of fertility classes brackets
    `H_dom`, and compute the fractional class `c` in `[1, 5]`.

2.  At `reference_age`, interpolate between the same pair of classes
    using `c`.

When `species` is not directly tabulated, a genus-level fallback is
applied (`BROADLEAF_GENUS` for non-conifers, `CONIFER_GENUS` otherwise).

## Examples

``` r
# Sessile oak: 20 m at 80 years -> site index at 50 years
compute_site_index(H_dom = 20, age = 80, species = "QUPE")
#> [1] 14.46525

# Norway spruce: 25 m at 40 years
compute_site_index(H_dom = 25, age = 40, species = "PIAB")
#> [1] 28.91933

# Vectorised input
compute_site_index(
  H_dom   = c(20, 25, 18),
  age     = c(80, 40, 60),
  species = c("QUPE", "PIAB", "FASY")
)
#> [1] 14.46525 28.91933 15.16204
```
