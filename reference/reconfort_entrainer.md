# Train the RECONFORT-style dieback classifier (spike)

Fits a \`ranger\` Random Forest on the CRswir/CRre time series (36
ten-day steps of the observation year per index) of labelled plots, and
scores it by \*\*spatial block cross-validation\*\*: plots are grouped
into square blocks of \`taille_bloc\` metres, whole blocks are assigned
to folds, and a fold is predicted by a model that never saw a plot of
the same block.

## Usage

``` r
reconfort_entrainer(
  serie,
  etiquettes,
  k = 5L,
  taille_bloc = 1000,
  seed = 42L,
  num_arbres = 300L
)
```

## Arguments

- serie:

  A \`data.frame\` time series with \`id_unique\`, \`date\` (\`Date\`)
  and either \`CRswir\` and \`CRre\`, or the Sentinel-2 bands accepted
  by \[reconfort_indices()\].

- etiquettes:

  Labels from \[reconfort_etiquettes()\], with plot coordinates \`x\`
  and \`y\` (metres) used to build the blocks.

- k:

  Number of cross-validation folds.

- taille_bloc:

  Block size in the unit of \`x\`/\`y\` (metres).

- seed:

  Integer seed (blocks, folds and forest); fixed for reproducibility.

- num_arbres:

  Number of trees.

## Value

An object of class \`reconfort_modele\`: \`modele\` (the final
\`ranger\` fit on all rows), \`confusion\` (out-of-fold confusion
matrix, rows observed, columns predicted, classes 1 to 3), \`precision\`
(overall accuracy out-of-fold), \`precision_observations\` (same, on
real observations only), \`plis\` (per row: \`id_unique\`, \`annee\`,
\`source\`, \`bloc\`, \`pli\`, \`observe\`, \`predit\`), \`variables\`,
\`seed\`, \`k\`, \`taille_bloc\`.

## Examples

``` r
# \donttest{
# voir tests/testthat/test-reconfort-apprentissage.R pour un jeu `synth_`
# }
```
