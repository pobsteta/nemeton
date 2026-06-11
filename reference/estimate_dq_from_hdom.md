# Estimate a quadratic mean diameter from dominant height

Applies a species-specific power-law allometry \$\$D_g \approx
a\_{species} \cdot H\_{dom}^b\$\$ with \\b = 0.9\\ (gently sub-linear).
The per-species \\a\_{species}\\ is calibrated against the mean \\(H_0,
D_g)\\ pair observed in the French National Forest Inventory — i.e.
Charru et al. 2012 Table 1 (mean \\D_g\\) crossed with Charru et al.
2017 Table 1 (mean \\H_0\\) for the 8 species covered by both, with
extensions using typical IFN H_0 values for PSME, PIPI, PILA, and
broadleaf-genus defaults for CASA and POSP.

## Usage

``` r
estimate_dq_from_hdom(H_dom, species)
```

## Arguments

- H_dom:

  Numeric vector. Dominant height in metres.

- species:

  Character vector of IFN species codes (recycled against `H_dom`).

## Value

Numeric vector of estimated \\D_g\\ in cm, clamped to each species'
observed range. `NA` when `H_dom` is `NA`, non-positive or below 6 m
(stands too young for this allometry).

## Details

The relationship is valid only for pure even-aged stands. Multi-layered
or strongly irregular stands will still be approximated — the estimate
then reflects a biased mean diameter of the dominant social position.
The output is clamped to the observed \\D_g\\ range of each species
(Charru 2012 Table 1) to avoid extrapolation artefacts at very small or
very large \\H\_{dom}\\.

## Examples

``` r
estimate_dq_from_hdom(H_dom = 25, species = "FASY")
#> [1] 27.59599
estimate_dq_from_hdom(
  H_dom   = c(18, 25, 30),
  species = c("QUPE", "FASY", "PIAB")
)
#> [1] 18.21380 27.59599 35.14301
```
