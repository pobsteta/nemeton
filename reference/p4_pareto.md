# Pareto status of units on P4 and chosen axes (spec 072, section 8)

Calls
[`identify_pareto_optimal()`](https://pobsteta.github.io/nemeton/reference/identify_pareto_optimal.md)
with the **raw** `P4` (never `P4_norm` nor the decision) and at most
three axes, all maximised. With `perte_sinistre`, builds the yield-risk
front instead: `P4` is maximised and the disaster loss minimised.

## Usage

``` r
p4_pareto(units, axes = NULL, perte_sinistre = NULL)
```

## Arguments

- units:

  Output of
  [`indicateur_p4_rendement_net()`](https://pobsteta.github.io/nemeton/reference/indicateur_p4_rendement_net.md)
  with the axis columns.

- axes:

  Character vector of up to three columns to cross with `P4` (e.g. from
  [`p4_selectionner_axes()`](https://pobsteta.github.io/nemeton/reference/p4_selectionner_axes.md)).

- perte_sinistre:

  Optional numeric vector (one per unit) of the disaster loss to
  minimise, e.g. of the dominant hazard.

## Value

`units` with `p4_pareto_statut` (`domine` / `non_domine`; `NA` when P4
or an axis is missing) and the attribute `prix_implicite`: P4 points
given up per score point between neighbouring units of the front, on the
first axis.

## Examples

``` r
u <- data.frame(P4 = c(.04, .03, .01), B = c(35, 65, 30))
p4_pareto(u, "B")$p4_pareto_statut
#> [1] "non_domine" "non_domine" "domine"    
```
