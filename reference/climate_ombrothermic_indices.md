# Gaussen-Bagnouls dry months and De Martonne aridity index

Computes two forest-climatology indices from monthly climatologies of
precipitation and temperature:

\* \*\*Gaussen-Bagnouls dry months\*\*: a month is dry when \`P \< 2 T\`
(precipitation in mm, temperature in °C); \* \*\*De Martonne index\*\*:
\`sum(P) / (mean(T) + 10)\` over the year.

Months are matched by \`month\`. A month with no finite P or T is never
counted dry; with no matching month, the result is empty / \`NA\`.

## Usage

``` r
climate_ombrothermic_indices(clim_rr, clim_t)
```

## Arguments

- clim_rr:

  \`data.frame\` with columns \`month\` and \`value\`: monthly
  precipitation (mm/month), e.g. from \[eobs_monthly_climatology()\].

- clim_t:

  \`data.frame\` with columns \`month\` and \`value\`: monthly mean
  temperature (°C).

## Value

A list with \`dry_idx\` (integer, the dry months), \`dry_months\`
(integer, their count; \`NA\` when no month matches) and \`demartonne\`
(numeric; \`NA\` when not computable).

## Examples

``` r
rr <- data.frame(month = 1:12,
                 value = c(70, 60, 55, 50, 40, 20, 8, 15, 45, 80, 90, 80))
tt <- data.frame(month = 1:12,
                 value = c(8, 9, 11, 13, 17, 21, 24, 24, 21, 16, 12, 9))
climate_ombrothermic_indices(rr, tt)
#> $dry_idx
#> [1] 6 7 8
#> 
#> $dry_months
#> [1] 3
#> 
#> $demartonne
#> [1] 24.11803
#> 
```
