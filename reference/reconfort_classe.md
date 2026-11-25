# Class of a DEPERIS dieback share

Maps the share of D+ trees (\`DEPERIS_pe\`, in \\0, 1\\) to the
RECONFORT class: 1 healthy (\< 0.20), 2 declining (0.20 to 0.50
inclusive), 3 severely declining (\> 0.50).

## Usage

``` r
reconfort_classe(deperis_pe)
```

## Arguments

- deperis_pe:

  Numeric vector in \\0, 1\\.

## Value

An integer vector of classes 1, 2 or 3 (\`NA\` where the input is
\`NA\`).

## Examples

``` r
reconfort_classe(c(0, 0.19, 0.2, 0.5, 0.51, 1))
#> [1] 1 1 2 2 3 3
```
