# Validate a catalogue of silvicultural itineraries

Checks the schema of every entry and the sourcing rule: an entry marked
`statut_source = "source"` must cite at least one reference, and every
expected effect must give its source.

## Usage

``` r
valider_catalogue_itineraires(itineraires)
```

## Arguments

- itineraires:

  A list of itineraries, as read by
  [`itineraires_catalogue()`](https://pobsteta.github.io/nemeton/reference/itineraires_catalogue.md).

## Value

Invisibly `TRUE`; an error naming the first faulty entry otherwise.

## Lifecycle

Experimental (spec 065): may change in any release.
