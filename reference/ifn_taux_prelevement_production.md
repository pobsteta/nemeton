# Harvest to production ratio by sylvoecoregion

Divides the harvested volume by the biological volume production of a
sylvoecoregion, over the same campaigns: both flows cover the same
growing seasons (spec 054 section 7.2). A ratio above 1 means the domain
harvests more than it grows (decapitalisation), below 1 that it
capitalises.

**Known bias.** Nationally the ratio is 0.67 against 0.61 published by
the IGN for 2014-2022 (about +10 percent, spec 054 section 3.c). A ratio
slightly above 1 is therefore not proof of decapitalisation.

## Usage

``` r
ifn_taux_prelevement_production(ser = NULL,
  groupe = c("tous", "feuillus", "resineux"),
  definition = c("ign", "vidange"), n_campagnes = 5L, campagnes = NULL,
  min_plac = 30)
```

## Arguments

- ser:

  SER code, a single string, or `NULL` for the national figure.

- groupe:

  `"tous"` (default), `"feuillus"` or `"resineux"`.

- definition:

  `"ign"` (default): every felled tree, as the IGN counts harvest;
  `"vidange"`: felled **and extracted** trees only, the definition used
  for forest roads (spec 040).

- n_campagnes, campagnes, min_plac:

  Campaign window and minimum number of revisited plots, as in
  [`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md).
  The harvest estimate sets the level; the production is taken at the
  same level and campaigns.

## Value

A one-row data.frame: `ser`, `groupe`, `definition`, `prelevement` and
`production` (m3/ha/yr), `ratio`, `rse` (percent, delta method under
independence of the two estimates), `niveau_utilise`, `campagnes`.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

[`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md),
[`ifn_taux_prelevement`](https://pobsteta.github.io/nemeton/reference/ifn_taux_prelevement.md).

## Examples

``` r
if (FALSE) { # \dontrun{
ifn_taux_prelevement_production("C30")
ifn_taux_prelevement_production(NULL)   # national, about 0.67
} # }
```
