# IFN biological production by sylvoecoregion and campaign

Returns the bundled table of annual biological production recomputed
from the IGN raw forest-inventory data, per sylvoecoregion (SER) and
campaign, with a Fay-Herriot small-area estimate and its uncertainty
(spec 054).

Two attributes: `"pg"`, basal-area production (m2/ha/yr), exact; and
`"pv"`, volume production (m3/ha/yr), computed under a constant form and
height assumption, which biases it low (about 15-20 percent under the
published IGN figure, see the `methode_pv` column and spec 054 §3.a).

Campaign `t` measures the growth of years `t-5` to `t-1`.

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

  Optional `"pg"` and/or `"pv"`.

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

## See also

[`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md),
[`estimer_fay_herriot`](https://pobsteta.github.io/nemeton/reference/estimer_fay_herriot.md).

## Examples

``` r
if (FALSE) { # \dontrun{
ifn_production_ser(ser = "C30", attribut = "pv", groupe = "tous")
} # }
```
