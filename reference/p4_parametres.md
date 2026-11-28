# Read and validate the P4 parameter file

Reads `inst/extdata/p4_parametres.yml` (spec 072, section 5), optionally
replaced by a project file and/or patched by a list, then validates it.
Every value of the shipped file is provisional (`provisoire: true`).

## Usage

``` r
p4_parametres(fichier = NULL, surcharge = NULL)
```

## Arguments

- fichier:

  Path of a project parameter file, or `NULL` for the shipped one.

- surcharge:

  Optional named list merged recursively over the file (project
  override).

## Value

A validated named list of parameters.

## Examples

``` r
p <- p4_parametres()
p$vocations$production$taux_exige
#> [1] 0.03
```
