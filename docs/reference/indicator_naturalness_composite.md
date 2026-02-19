# N3: Composite Naturalness Index

Calculates a composite naturalness index following tuto 04: N3 = 0.35 \*
N1 + 0.35 \* N2 + 0.15 \* (100 - L1) + 0.15 \* B3 Falls back to 50 when
L1 or B3 are unavailable.

## Usage

``` r
indicator_naturalness_composite(units, column_name = "N3", lang = "en")
```

## Arguments

- units:

  sf object with N1 and N2 columns (optionally L1, B3)

- column_name:

  Character. Name for output column. Default "N3".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added column N3 (score 0-100)
