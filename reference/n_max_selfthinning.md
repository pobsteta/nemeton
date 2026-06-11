# Maximum stand density under self-thinning (Charru 2012)

Returns the upper boundary of the stems-per-hectare / quadratic-
mean-diameter relationship for a given species, i.e. the density a fully
stocked pure even-aged stand would sustain at the given \\D_g\\.
Equation: \$\$\ln(N\_{max}) = a + b \ln(D_g) + c \ln(D_g)^2\$\$ where
\\N\_{max}\\ is in stems / ha and \\D_g\\ in cm.

## Usage

``` r
n_max_selfthinning(dq, species, clamp = TRUE)
```

## Arguments

- dq:

  Numeric vector. Quadratic mean diameter in cm.

- species:

  Character vector of IFN-style species codes (recycled against `dq`).

- clamp:

  Logical. If `TRUE`, clamp `dq` to the observed range of the species.

## Value

Numeric vector of maximum stems/ha. `NA` when the species cannot be
resolved or `dq` is `NA` / non- positive.

## Details

Species not present in the Charru table fall back to a genus-level
proxy:

- conifers (in
  [`is_conifer()`](https://pobsteta.github.io/nemeton/reference/is_conifer.md))
  \\\to\\ `PSME` (Douglas-fir)

- broadleaves \\\to\\ `FASY` (common beech)

Values are clamped to the `[dg_min, dg_max]` range of the species when
`clamp = TRUE` (default) because the self-thinning relationship was
calibrated only over that range and extrapolates poorly.

## Examples

``` r
# Common beech, D_g = 30 cm
n_max_selfthinning(dq = 30, species = "FASY")
#> [1] 581.6271

# Vector input
n_max_selfthinning(
  dq      = c(20, 30, 40),
  species = c("QUPE", "FASY", "PIAB")
)
#> [1] 1049.5908  581.6271  462.9191
```
