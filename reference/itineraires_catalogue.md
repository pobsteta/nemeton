# Catalogue of silvicultural itineraries

Reads the catalogue of silvicultural itineraries shipped with the
package (`inst/extdata/itineraires_sylvicoles.json`, spec 065) or a
catalogue file of your own with the same schema. Each itinerary is
described by parameterised **rules** and by its **expected effects** on
the indicator families, all sourced.

## Usage

``` r
itineraires_catalogue(chemin = NULL)
```

## Arguments

- chemin:

  Path to a catalogue JSON file. `NULL`: the shipped one.

## Value

A list of itineraries (each a list: `code`, `famille_itineraire`,
`libelle`, `domaine`, `regles`, `effets_attendus`, `sources`,
`statut_source`), validated by
[`valider_catalogue_itineraires()`](https://pobsteta.github.io/nemeton/reference/valider_catalogue_itineraires.md).

## Details

**Sourcing rule.** A numeric parameter without a reference does not
enter the catalogue: an entry whose rules are not yet sourced carries
`statut_source = "a_sourcer"` and is never admissible. The shipped
catalogue holds the skeleton of the first itineraries (spec 065, D-4),
all `"a_sourcer"`: their parameters are filled from silvicultural guides
by the forester, not invented.

## Lifecycle

Experimental (spec 065): may change in any release.

## See also

[`itineraires_admissibles()`](https://pobsteta.github.io/nemeton/reference/itineraires_admissibles.md),
[`comparer_itineraires()`](https://pobsteta.github.io/nemeton/reference/comparer_itineraires.md)
