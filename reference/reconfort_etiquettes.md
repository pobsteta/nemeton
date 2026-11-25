# RECONFORT field labels, checked and propagated from Y-2 to Y+2

Validates survey plots in the format of the upstream
\`train_new_model/\` labels, recomputes the class from \`DEPERIS_pe\`,
then propagates the labels in time: a \*\*healthy\*\* plot in year Y is
healthy in Y-1 and Y-2; a \*\*declining\*\* plot (class 2 or 3) in year
Y is declining in Y+1 and Y+2 with its observed class (a very declining
plot, class 3, stays class 3). A propagation never overwrites a real
observation, and a disagreement is listed, never settled silently.

## Usage

``` r
reconfort_etiquettes(placettes, propager = TRUE, avant = 2L, apres = 2L)
```

## Arguments

- placettes:

  A \`data.frame\` with columns \`id_unique\`, \`date\` (survey year,
  integer or \`Date\`), \`dep_cor\` (1, 2 or 3; 0 is refused) and
  \`DEPERIS_pe\` in \\0, 1\\. Other columns (e.g. \`x\`, \`y\`) are
  carried along.

- propager:

  Logical; \`FALSE\` keeps the observations only.

- avant, apres:

  Years propagated before (healthy) and after (declining) an
  observation; 2 by default.

## Value

A \`data.frame\` with \`id_unique\`, \`annee\`, \`dep_cor\` (class from
\`DEPERIS_pe\`), \`DEPERIS_pe\` (\`NA\` on propagated rows), \`source\`
(\`"observation"\` or \`"propagation"\`) and the carried columns.
Attributes: \`conflits\` (disagreements; a row whose two propagations
disagree is dropped and listed with \`classe_retenue = NA\`) and
\`ecarts_classe\` (observations whose given \`dep_cor\` differs from the
class recomputed from \`DEPERIS_pe\`).

## Examples

``` r
p <- data.frame(id_unique = "a", date = 2022L, dep_cor = 1L, DEPERIS_pe = 0.05)
reconfort_etiquettes(p)
#>   id_unique annee dep_cor DEPERIS_pe      source
#> 1         a  2020       1         NA propagation
#> 2         a  2021       1         NA propagation
#> 3         a  2022       1       0.05 observation
```
