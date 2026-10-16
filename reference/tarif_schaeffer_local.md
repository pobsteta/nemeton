# Schaeffer tariff numbers of a forest

Tariff numbers computed on the IFN plots around the forest: `units` plus
a buffer bringing the area to about 2,000 ha (at least 450 m), as
`PPtools::ExtractPlac()`. A species keeps its forest number when it has
at least `min_arbres` trees on at least `min_placettes` plots; otherwise
the number falls back on
[`ifn_tarif_schaeffer_reference`](https://pobsteta.github.io/nemeton/reference/ifn_tarif_schaeffer_reference.md)
for the majority SER.

## Usage

``` r
tarif_schaeffer_local(
  units,
  especes = NULL,
  ifn = NULL,
  campagnes = 15,
  min_arbres = 30,
  min_placettes = 5,
  ser = NULL,
  cible_ha = 2000
)
```

## Arguments

- units:

  sf polygons of the forest.

- especes:

  Optional species (any form accepted by
  [`resoudre_espar`](https://pobsteta.github.io/nemeton/reference/resoudre_espar.md));
  default: the species found around the forest.

- ifn:

  Optional result of
  [`ifn_charger`](https://pobsteta.github.io/nemeton/reference/ifn_charger.md)
  with `ARBRE` and `PLACETTE`; loaded when `NULL`.

- campagnes:

  Number of most recent campaigns kept. Default 15.

- min_arbres, min_placettes:

  Forest-level thresholds. Defaults 30 and 5.

- ser:

  Optional SER code; default: the majority SER of `units`
  ([`localiser_ser`](https://pobsteta.github.io/nemeton/reference/localiser_ser.md)),
  else the majority SER of the plots found.

- cible_ha:

  Target area of the extraction zone. Default 2000.

## Value

A data.frame as
[`ifn_tarif_schaeffer_reference`](https://pobsteta.github.io/nemeton/reference/ifn_tarif_schaeffer_reference.md),
with `niveau_utilise` `"foret"`, `"SER"`, `"GRECO"` or `"FRANCE"` and
`n_placettes` (forest level only); attributes `ser` (the SER used for
the fallback), `tampon_m` and `n_placettes_zone`.

## Details

Public IFN plots are placed at the centre of their kilometre cell (700 m
off at most): there are about ten plots per 2,000 ha of forest, hence
the tree threshold at the forest level (spec 062, D2).

## Lifecycle

Experimental (spec 062).
