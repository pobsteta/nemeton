# Predict RECONFORT classes with a trained spike model

Predict RECONFORT classes with a trained spike model

## Usage

``` r
reconfort_predire(modele, serie, cibles)
```

## Arguments

- modele:

  A \`reconfort_modele\` from \[reconfort_entrainer()\].

- serie:

  Time series, as for \[reconfort_entrainer()\].

- cibles:

  A \`data.frame\` with \`id_unique\` and \`annee\` (rows to predict).

## Value

\`cibles\` with a \`classe\` column (1, 2 or 3; \`NA\` without a usable
series).
