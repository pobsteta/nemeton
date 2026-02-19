# Calculate Stability / Change Rate Index (T2)

Measures forest stability using N2 (forest continuity/antiquity) as
proxy, following tuto 04 methodology. Falls back to T1 age capped at
100.

## Usage

``` r
indicator_temporal_change(units, layers = NULL, t1_values = NULL)
```

## Arguments

- units:

  An sf object with forest parcels. May contain pre-computed columns: N2
  (forest continuity) or T1 (stand age).

- layers:

  A nemeton_layers object (optional). Not directly used but kept for
  interface consistency.

- t1_values:

  Numeric vector. Pre-computed T1 age values (same length as
  nrow(units)). If NULL and units has no T1 column, T2 defaults to 50.

## Value

Numeric vector of stability scores (0-100). 100 = very stable (ancient
forest), 0 = recent change.

## Details

\*\*Primary method\*\*: Use N2 (forest continuity/antiquity) column if
present in units. N2 measures continuous forest cover duration, serving
as a direct proxy for temporal stability.

\*\*Fallback\*\*: Use T1 stand age capped at 100. Older forests are
assumed more stable.

## See also

Other temporal-indicators:
[`indicator_temporal_age()`](https://pobsteta.github.io/nemeton/reference/indicator_temporal_age.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units[1:10, ]

# Compute T1 first, then T2
t1 <- indicator_temporal_age(units, layers = massif_demo_layers())
t2 <- indicator_temporal_change(units, t1_values = t1)
} # }
```
