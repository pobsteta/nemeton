# IFN harvest by species and sylvoecoregion

Reference table of **harvested** timber per hectare and per year, by IFN
species code and sylvoecoregion, derived from the five-year revisit of
the raw IFN data (campaigns 2005-2024).

Same key schema and same three nested levels as
[`ifn_volume_essence_ser`](https://pobsteta.github.io/nemeton/reference/ifn_volume_essence_ser.md):
`"ser"`, `"greco"`, `"national"`.

## Usage

``` r
ifn_prelevement_essence_ser(espar = NULL, ser = NULL, greco = NULL,
  niveau = NULL)
```

## Arguments

- espar:

  Optional IFN species code filter (character, e.g. `"09"`).

- ser:

  Optional SER code filter (e.g. `"C20"`).

- greco:

  Optional GRECO code filter (single letter).

- niveau:

  Optional level filter: `"ser"`, `"greco"` or `"national"`.

## Value

A data.frame with `niveau`, `ser`, `greco`, `espar`, `n_plac_presence`,
`n_plac_maille`, `prelev_ha_an_present`, `prelev_ha_an_maille`,
`taux_presence`, `libelle_essence`, `millesime`, `source`.

## What counts as harvested

Only `VEGET5 == "6"` — *arbre coupé vidangé*, felled **and extracted**.
Code `7` (*coupé non vidangé*) is deliberately excluded: that wood stays
in the forest and never travels the road network, which is what this
table is meant to size.

## Two approximations, stated

1.  The revisit row carries only the tree's fate — neither its volume
    nor its species. Both are taken from the tree's **first-visit** row
    (key `IDP`, `A`), so the harvested volume is the volume at first
    measurement: the tree grew somewhat before being felled. 92% of
    felled trees carry such a measurement.

2.  Harvest observed over the five-year interval is divided by five to
    give a yearly flux. It is an average, not a schedule.

As a sanity check, summing `prelev_ha_an_maille` over all species at the
national level gives **2.84 m3/ha/year**, consistent with the published
order of magnitude for French forest harvest.

## Harvest is not prescription

These figures describe what **has been** removed, not what **should**
be. Sizing a road network on them assumes management carries on
unchanged.

## See also

[`ifn_taux_prelevement`](https://pobsteta.github.io/nemeton/reference/ifn_taux_prelevement.md)
for the fallback ladder,
[`ifn_volume_essence_ser`](https://pobsteta.github.io/nemeton/reference/ifn_volume_essence_ser.md)
for standing volume.

## Examples

``` r
if (FALSE) { # \dontrun{
ifn_prelevement_essence_ser(espar = "62", niveau = "national")
} # }
```
