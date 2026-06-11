# Species BAI drift factor (Charru 2017)

Returns the relative change in BAI over 1980-2007 for a given species,
i.e. a multiplicative factor that converts a historical baseline
productivity to its 2007 value (e.g. 1.25 for `"PIAB"` = +25 panel fall
back to the per-habitat mean when the habitat is supplied, or to 1.0 (no
drift) otherwise.

## Usage

``` r
bai_drift_factor(species, habitat = NULL)
```

## Arguments

- species:

  Character vector of IFN species codes.

- habitat:

  Optional character vector of climatic habitats (`"mountain"`,
  `"generalist"`, `"lowland"`, `"mediterranean"`) to control the
  fallback. Recycled against `species`.

## Value

Numeric vector of the same length as `species` with the relative BAI
change (1.0 = no change).

## Details

Only 8 species are tabulated:
`PIAB, ABAL, PISY, FASY, QURO, QUPE, QUPU, PIHA`. For broader or
finer-grained coverage, see
[`charru_bai_drift_table`](https://pobsteta.github.io/nemeton/reference/charru_bai_drift_table.md).

## Examples

``` r
bai_drift_factor(c("PIAB", "FASY", "QUPE", "PIHA"))
#> [1] 1.25 1.05 0.97 0.72
bai_drift_factor("ACPS", habitat = "lowland")  # fallback by habitat
#> [1] 0.985
```
