# Normalize a single indicator to 0-100 scale

Converts raw indicator values to a common 0-100 scale using
indicator-specific reference maxima and special handling rules.

## Usage

``` r
normalize_indicator(indicator, values)
```

## Arguments

- indicator:

  Character. Indicator name (NMT convention).

- values:

  Numeric vector. Raw indicator values.

## Value

Numeric vector. Normalized values (0-100).
