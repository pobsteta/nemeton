# IFN biological production by sylvoecoregion and campaign

Returns the bundled table of annual biological production recomputed
from the IGN raw forest-inventory data, per sylvoecoregion (SER) and
campaign, with a Fay-Herriot small-area estimate and its uncertainty
(spec 054).

Four attributes, all per hectare and per year:

- `"pg"`: basal-area production (m2/ha/yr), exact from the increment
  cores;

- `"pv"`: volume production (m3/ha/yr). Height growth follows diameter
  growth through the height-diameter allometry estimated in the
  inventory (`methode_pv = "allometrie_hauteur_diametre"`), and the
  growth of trees felled between two visits is included, as in the IGN
  definition. National check: 97 percent of the published IGN figure
  (spec 054 section 3.c);

- `"prel"`: harvested volume (m3/ha/yr), all felled trees (IGN
  definition);

- `"prel_vidange"`: harvested volume of trees felled **and extracted**
  (`VEGET5 == "6"`), the definition used for forest roads (spec 040).

Campaign `t` measures the growth of years `t-5` to `t-1`, and the
harvest between the first visit of a plot (`t-5`) and its revisit (`t`).

**Groups are contributions, not stand figures.** The `"feuillus"` and
`"resineux"` rows are per hectare of the **whole** forest of the domain
(plots without the group count as zero), so that the groups add up to
`"tous"`. They are not the production of a hectare of broadleaf or
conifer stand. Ratios between two attributes of the same group (e.g.
harvest / production) remain meaningful.

## Usage

``` r
ifn_production_ser(ser = NULL, greco = NULL, campagne = NULL,
  attribut = NULL, groupe = NULL, niveau = NULL)
```

## Arguments

- ser, greco:

  Optional SER / GRECO codes to filter on.

- campagne:

  Optional campaign year(s).

- attribut:

  Optional `"pg"`, `"pv"`, `"prel"` and/or `"prel_vidange"`.

- groupe:

  Optional `"tous"`, `"feuillus"` and/or `"resineux"`.

- niveau:

  Optional `"ser"`, `"greco"` and/or `"national"`.

## Value

A data.frame with columns `niveau`, `ser`, `greco`, `campagne`,
`attribut`, `groupe`, `n_plac`, `direct`, `psi`, `estimation`, `mse`,
`rse`, `gamma`, `nature` (`"fay_herriot"`, `"synthetique"` or
`"direct"`), `methode_pv`, `covariables`, `part_g_imputee`, `millesime`,
`source`. Read `nature` before using `estimation`: a synthetic value is
a model prediction, not a measurement.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

[`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md),
[`estimer_fay_herriot`](https://pobsteta.github.io/nemeton/reference/estimer_fay_herriot.md).

## Examples

``` r
if (FALSE) { # \dontrun{
ifn_production_ser(ser = "C30", attribut = "pv", groupe = "tous")
} # }
```
