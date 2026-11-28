# Choose the axes to cross with P4 (spec 072, section 8)

PCA of the family scores with `P4` as supplementary variable
(FactoMineR, in Suggests): on each of the first `n_axes` dimensions, the
family with the highest contribution is kept, preferring the one opposed
to P4 on ties (contributions within 5 percent of the best). An imposed
axis replaces the least contributing one. Below `effectif_min` units, or
when FactoMineR is missing, no factorial analysis is run: the axes of
the vocation are returned with a warning.

## Usage

``` r
p4_selectionner_axes(
  units,
  familles = NULL,
  n_axes = 3L,
  axe_impose = NULL,
  vocation = NULL,
  effectif_min = 30L
)
```

## Arguments

- units:

  Data frame with `P4` and `famille_*` columns.

- familles:

  Family columns; default all `famille_*` columns.

- n_axes:

  Number of axes (at most 3).

- axe_impose:

  Optional family column imposed by the vocation.

- vocation:

  Vocation used for the fallback axes (default: the most frequent one in
  `units`).

- effectif_min:

  Minimum number of complete units (default 30).

## Value

A list: `axes` (character), `methode` (`"acp"` or `"repli_vocation"`),
`contributions` (matrix or `NULL`).

## Examples

``` r
u <- data.frame(P4 = c(.04, .03, .01), famille_production = c(1, 2, 3))
suppressWarnings(p4_selectionner_axes(u))$methode
#> [1] "repli_vocation"
```
