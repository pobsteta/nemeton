# Normalize a single indicator to 0-100 scale

Converts raw indicator values to a common 0-100 scale using
indicator-specific reference maxima and special handling rules.

## Usage

``` r
normalize_indicator(indicator, values, statut = NULL)
```

## Arguments

- indicator:

  Character string. Indicator name (NMT convention, long name or short
  code). Anything else than a single non-missing string is an error.

- values:

  Numeric vector. Raw indicator values.

- statut:

  Optional character vector (one value per element of `values`, or one
  for all) telling what a value measures when an indicator has several
  units. Used for P2: `"indice_station_m"` marks a site index in metres
  (CHM mode of
  [`indicateur_p2_station`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md),
  status column `p2_status`), normalised against 40 m instead of the 15
  m3/ha/yr of the production modes. `NULL` (default) keeps the
  production scale.

## Value

Numeric vector. Normalized values (0-100).

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).
