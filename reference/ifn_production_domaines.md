# IFN production of user-defined domains

Estimates the annual biological production of arbitrary domains (forest
management units, massifs, forests) from the national forest inventory
plots that fall inside them, combined with a prediction drawn from their
sylvoecoregion(s) (spec 054 lots 5 and 5-bis).

For each domain and campaign, the direct mean of its plots is shrunk
towards the prediction with the weight `gamma = A(S) / (A(S) + psi)`,
where `psi` is the sampling variance of the direct mean and `A(S)` the
error of the prediction for a domain of area `S`, calibrated on grid
cells of 15 to 100 km. A domain with many plots keeps its own figure; a
domain with few plots leans on the prediction. Campaigns are then
averaged as in
[`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md).

Two predictions:

- `"ser"`: the Fay-Herriot estimates of the domain's sylvoecoregions,
  weighted by the share of its plots in each.

- `"hybride"` (volume production only, when `covariables` is supplied):
  the same, corrected by the national model coefficients for the gap
  between the domain's covariates and those of its sylvoecoregions.
  Validated against the inventory on grid cells: 19 to 35 percent lower
  error than `"ser"` for `"pv"`, but no gain for `"pg"`, which therefore
  keeps `"ser"`.

## Usage

``` r
ifn_production_domaines(domaines, attribut = c("pv", "pg"), id_col = NULL,
  n_campagnes = 5L, campagnes = NULL, ser_layer = NULL, covariables = NULL)
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

- covariables:

  Optional output of
  [`ifn_covariables_domaines`](https://pobsteta.github.io/nemeton/reference/ifn_covariables_domaines.md)
  (same `id`s). Enables the `"hybride"` prediction for `"pv"`.

## Value

A data.frame with one row per domain: `id`, `attribut`, `valeur`, `mse`,
`rse` (percent), `n_placettes` (live-tree plots over the window),
`poids_direct` (mean `gamma`), `part_bordure` (share of plots within 700
m of the boundary), `ser` (SER weights, e.g. `"C30:0.80,C20:0.20"`),
`surface_ha`, `predicteur` (`"ser"` or `"hybride"`), `variance_domaine`
(`A(S)`), `hors_calibrage`, `nature` (`"composite"`, or `"prediction"`
for a domain without plots), `campagnes`. The per-campaign detail is in
the `detail` attribute.

## Limits to state alongside the figures

- `A(S)` is calibrated between 22 500 ha (15 km cells) and 1 million ha;
  outside that range it is extrapolated (`hors_calibrage = TRUE`).

- Below 10 plots in a campaign, the sampling variance of the direct mean
  is taken from the plot-level variance of the domain's SER (generalised
  variance function), the direct variance being unstable.

- The public IFN coordinates are the centre of the 1 km grid cell, the
  real plot lying within 700 m of it. Plots near a domain boundary may
  be assigned to the wrong side; their share is reported in
  `part_bordure`.

## See also

[`ifn_covariables_domaines`](https://pobsteta.github.io/nemeton/reference/ifn_covariables_domaines.md),
[`ifn_production_reference`](https://pobsteta.github.io/nemeton/reference/ifn_production_reference.md),
[`localiser_ser`](https://pobsteta.github.io/nemeton/reference/localiser_ser.md).

## Examples

``` r
if (FALSE) { # \dontrun{
ut <- sf::st_read("ut_onf.gpkg")
ifn_production_domaines(ut, id_col = "code_ut")
} # }
```
