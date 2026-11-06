# Admissible silvicultural itineraries per unit

For every unit and every itinerary of the catalogue, says whether the
itinerary is admissible and, if not, **why** (closed set of codes, spec
065 § 4). A criterion whose data is missing never admits nor excludes
silently: the row carries `donnee_manquante`.

## Usage

``` r
itineraires_admissibles(
  units,
  catalogue = itineraires_catalogue(),
  protected_areas = NULL,
  colonnes = list(id = NULL, p2 = "P2", ser = "ser", essence = "essence", pente =
    "pente_pct", desserte = "desserte_m")
)
```

## Arguments

- units:

  sf (or data frame) of units.

- catalogue:

  Itineraries, from
  [`itineraires_catalogue()`](https://pobsteta.github.io/nemeton/reference/itineraires_catalogue.md).

- protected_areas:

  Optional sf of protected areas with a type column (`type_protection`,
  `zone_type`, `type` or `statut`), whose codes are those of B1 (`rnn`,
  `rb`, `coeur`, `apb`, `natura`, ...). Needed only by itineraries that
  exclude protections.

- colonnes:

  Named list of the unit columns read by the filter: `id`, `p2`
  (station, P2), `ser` (sylvoecoregion code), `essence`, `pente` (slope,
  %), `desserte` (skidding distance, m; spec 065 D-3).

## Value

A long data frame: `unit_id`, `itineraire`, `admissible` (logical, `NA`
when data is missing), `raison` (`NA` if admissible; else
`source_manquante`, `statut_protection`, `hors_ser`, `essence_absente`,
`station_insuffisante`, `pente`, `desserte` or `donnee_manquante`) and
`detail` (observed value against threshold). Criteria are checked in
that order and the first failing one is reported.

## Details

Admissible does not mean recommended: it means that nothing in the
catalogue's rules and the data rules the itinerary out.

## Lifecycle

Experimental (spec 065): may change in any release.

## See also

[`comparer_itineraires()`](https://pobsteta.github.io/nemeton/reference/comparer_itineraires.md)
