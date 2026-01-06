# N3: Composite Naturalness Index

Calculates a composite wilderness index integrating infrastructure
distance (N1), forest continuity (N2), ancientness (T1), and protection
(B1).

## Usage

``` r
indicator_naturalness_composite(
  units,
  n1_field = "N1",
  n2_field = "N2",
  t1_field = "T1",
  b1_field = "B1",
  aggregation = c("multiplicative", "weighted"),
  weights = c(N1 = 0.25, N2 = 0.25, T1 = 0.25, B1 = 0.25),
  normalization = "quantile",
  quantiles = c(0.1, 0.9),
  column_name = "N3",
  lang = "en"
)
```

## Arguments

- units:

  sf object with N1, N2, T1, B1 indicators

- n1_field:

  Character. Column for infrastructure distance. Default "N1".

- n2_field:

  Character. Column for forest continuity. Default "N2".

- t1_field:

  Character. Column for ancientness. Default "T1".

- b1_field:

  Character. Column for protection status. Default "B1".

- aggregation:

  Character. Method: "multiplicative" or "weighted". Default
  "multiplicative".

- weights:

  Named numeric vector. Component weights (for weighted method). Default
  equal.

- normalization:

  Character. Normalization method: "quantile", "minmax", "zscore".
  Default "quantile".

- quantiles:

  Numeric(2). Quantile bounds for normalization. Default c(0.1, 0.9).

- column_name:

  Character. Name for output column. Default "N3".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added columns: N3 (composite 0-100), N3\_\*\_norm
(normalized components)
