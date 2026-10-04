# Calculate Temporal Stability Proxy (T2)

Despite its name (`changement`), T2 does **not** measure a rate of
change: no time series is read. It is a temporal **stability proxy**
derived from other indicators – a copy of N2 (forest continuity) when
present, otherwise the T1 stand age capped at 100 – following tuto 04.
It therefore carries no information of its own, and in the T family it
may duplicate T1.

## Usage

``` r
indicateur_t2_changement(units, layers = NULL, t1_values = NULL)
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
  nrow(units)). If NULL and units has no T1 column, T2 is `NA`.

## Value

Numeric vector of stability proxy scores (0-100), 100 = very stable
(ancient forest). `NA` where the source (N2 or T1) is unknown – no
default value.

## Details

**Primary method**: copy of the N2 (forest continuity/antiquity) column
if present in units, clamped to 0-100.

**Fallback**: T1 stand age (years) capped at 100. Older forests are
assumed more stable.

A genuine change-rate indicator (e.g. a Sentinel-2 change detection) is
not implemented in T2.

## See also

Other temporal-indicators:
[`indicateur_t1_anciennete()`](https://pobsteta.github.io/nemeton/reference/indicateur_t1_anciennete.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units[1:10, ]

# Compute T1 first, then T2
t1 <- indicateur_t1_anciennete(units, layers = massif_demo_layers())
t2 <- indicateur_t2_changement(units, t1_values = t1)
} # }
```
