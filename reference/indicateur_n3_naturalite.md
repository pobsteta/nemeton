# N3: Composite Naturalness Index

Calculates a composite naturalness index following tuto 04: N3 = 0.35 \*
N1 + 0.35 \* N2 + 0.15 \* (100 - L1) + 0.15 \* B3 NA when any of N1, N2,
L1 or B3 is unavailable.

## Usage

``` r
indicateur_n3_naturalite(units)
```

## Arguments

- units:

  sf object with N1 and N2 columns (optionally L1, B3)

## Value

sf object with added column N3 (score 0-100), or `NA` when any of the
four input columns is missing.

**Higher = more natural = favourable.** N3 is
`0.35*N1 + 0.35*N2 + 0.15*(100 - L1) + 0.15*B3`; all four inputs are
0-100, so the composite is too, and
[`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md)
passes it through.

N3 reads the **raw** `L1` column and applies its own inversion. That is
deliberate and must stay:
[`create_family_index()`](https://pobsteta.github.io/nemeton/reference/create_family_index.md)
works on a copy and does not mutate the source columns, so dropping the
`100 - L1` to "align" N3 on the radar convention would invert L1 twice
(spec 048 sections 9 and 12).

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).
