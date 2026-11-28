# Read and validate the P4 action rules

Reads `inst/extdata/p4_regles_actions.yml` (spec 072, `actions.md`): the
signal-action matrix, the hazard threshold, the qualitative effects of
the options and the bounds of the guard rails. Every value of the
shipped file is provisional (`provisoire: true`) and must be reviewed by
a forester before use.

## Usage

``` r
p4_regles_actions(fichier = NULL, surcharge = NULL)
```

## Arguments

- fichier:

  Path of a project rules file, or `NULL` for the shipped one.

- surcharge:

  Optional named list merged recursively over the file.

## Value

A validated named list of rules.

## Examples

``` r
r <- p4_regles_actions()
r$seuil_alea
#> [1] 0.005
```
