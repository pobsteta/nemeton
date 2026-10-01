# IFN production of user-defined domains

Estimates the annual biological production of arbitrary domains (forest
management units, massifs, forests) from the national forest inventory
plots that fall inside them, combined with the Fay-Herriot estimate of
their sylvoecoregion(s) (spec 054 lot 5).

For each domain and campaign, the direct mean of its plots is shrunk
towards the SER estimate with the weight
`gamma = (A + m_s) / (A + m_s + psi)`, where `psi` is the sampling
variance of the direct mean, `m_s` the MSE of the SER estimate and `A`
the between-domain variance of the national model. A domain with many
plots keeps its own figure; a domain with few plots leans on its SER.
Campaigns are then averaged as in
[`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md).

## Usage

``` r
ifn_production_domaines(domaines, attribut = c("pv", "pg"), id_col = NULL,
  n_campagnes = 5L, campagnes = NULL, ser_layer = NULL)
```

## Arguments

- domaines:

  An `sf` of polygons with a defined CRS.

- attribut:

  `"pv"` (default, m3/ha/yr) or `"pg"` (m2/ha/yr).

- id_col:

  Column of `domaines` identifying each domain. `NULL` (default) numbers
  them.

- n_campagnes, campagnes:

  Campaign window, as in
  [`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md).
  Only the campaigns of the national model are available (2019-2024).

- ser_layer:

  Optional SER outlines passed to
  [`localiser_ser`](https://pobsteta.github.io/nemeton/reference/localiser_ser.md),
  used only for a domain without any plot.

## Value

A data.frame with one row per domain: `id`, `attribut`, `valeur`, `mse`,
`rse` (percent), `n_placettes` (live-tree plots over the window),
`poids_direct` (mean `gamma`), `part_bordure` (share of plots within 700
m of the boundary), `ser` (SER weights, e.g. `"C30:0.80,C20:0.20"`),
`surface_ha`, `nature` (`"composite"`, or `"ser"` for a domain without
plots), `campagnes`. The per-campaign detail is in the `detail`
attribute.

## Limits to state alongside the figures

- Below 10 plots in a campaign, the sampling variance of the direct mean
  is taken from the plot-level variance of the domain's SER (generalised
  variance function), the direct variance being unstable.

- `A` was estimated **between sylvoecoregions**. Using it for
  sub-domains of a SER is an approximation; the true between-domain
  variance at that scale may differ.

- The public IFN coordinates are the centre of the 1 km grid cell, the
  real plot lying within 700 m of it. Plots near a domain boundary may
  be assigned to the wrong side; their share is reported in
  `part_bordure`. Below a few thousand hectares, prefer the SER figure.

## See also

[`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md),
[`localiser_ser`](https://pobsteta.github.io/nemeton/reference/localiser_ser.md).

## Examples

``` r
if (FALSE) { # \dontrun{
ut <- sf::st_read("ut_onf.gpkg")
ifn_production_domaines(ut, id_col = "code_ut")
} # }
```
