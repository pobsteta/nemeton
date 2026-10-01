# Attach each unit to its sylvoecoregion (SER)

Adds the SER code of each unit, as needed by the IFN references keyed by
sylvoecoregion
([`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md),
[`indicateur_p2_station`](https://pobsteta.github.io/nemeton/reference/indicateur_p2_station.md)
with `source = "ifn_fh"`,
[`ifn_taux_prelevement_production`](https://pobsteta.github.io/nemeton/reference/ifn_taux_prelevement_production.md),
[`completer_volume_ifn`](https://pobsteta.github.io/nemeton/reference/completer_volume_ifn.md)).
A unit that straddles two SER gets the one covering the largest part of
it.

The SER outlines come from the INRAE WFS (layer `inrae:ser_l93`, IGN
sylvoecoregions, Lambert 93), restricted to the extent of `units`; pass
`ser_layer` to work offline or with a cached copy.

## Usage

``` r
localiser_ser(units, ser_layer = NULL, colonne = "ser", timeout = 60L)
```

## Arguments

- units:

  An `sf` object with a defined CRS.

- ser_layer:

  Optional `sf` of SER outlines with a `codeser` column. `NULL`
  (default) downloads the outlines intersecting `units`.

- colonne:

  Name of the added column. Default `"ser"`.

- timeout:

  Network timeout in seconds. Default `60`.

## Value

`units` with `colonne` added (or overwritten): the SER code, or `NA` for
a unit outside every SER or when the outlines could not be obtained
(with a warning).

## See also

[`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md).

## Examples

``` r
if (FALSE) { # \dontrun{
ugf <- localiser_ser(ugf)
table(ugf$ser)
} # }
```
