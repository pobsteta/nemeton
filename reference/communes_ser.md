# Communes and their ecoregions

Reads `inst/extdata/communes_ser.csv`: one row per commune x SER, `part`
= share of the commune's total area in the SER (shares under 1 %
dropped, then renormalised: they sum to 1 per commune).

## Usage

``` r
communes_ser(insee = NULL)
```

## Arguments

- insee:

  Optional INSEE commune codes.

## Value

A data.frame `insee`, `nom`, `departement`, `ser`, `part`, `greco`.

## Lifecycle

Experimental (spec 062).

## Examples

``` r
communes_ser("21295")
#>   insee               nom departement ser   part greco
#> 1 21295 Gevrey-Chambertin          21 C20 0.5563     C
#> 2 21295 Gevrey-Chambertin          21 C51 0.4437     C
```
