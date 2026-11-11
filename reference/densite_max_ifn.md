# Maximum stand density by dominant species from inventory plots

Estimates the self-thinning ceiling used by
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
(`densite_max`): the upper quantile of the stand density index of the
plots dominated (basal area) by each species. FINN, calibrated on 5-year
intervals, does not stop the basal area of unmanaged stands (spec 068,
section on the density ceiling): the ceiling comes from the inventory
instead, like the self-thinning boundaries fitted on the French national
forest inventory by Charru et al. (2012).

## Usage

``` r
densite_max_ifn(arbres, quantile = 0.99, min_placettes = 100L)
```

## Arguments

- arbres:

  data.frame of trees: `placette`, `essence`, `d1` (cm), `poids`
  (stems/ha). With a `statut` column, only `"vivant"` and `"mort"` rows
  are kept (the state at the first visit, as in
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md)).

- quantile:

  Numeric in `(0, 1]`. Quantile of the plot density index and basal area
  taken as the ceilings. Default 0.99.

- min_placettes:

  Integer. Minimum number of plots dominated by a species for it to get
  its own ceiling; the others use the row `"toutes"` (all plots).
  Default 100.

## Value

data.frame: `essence`, `n_placettes`, `rdi_max`, `g_max` (the same
quantile of the plot basal area, m2/ha), one row per species with at
least `min_placettes` plots (decreasing number of plots), then
`essence = "toutes"`.

## Details

The density index is the additive form of Reineke's (1933) stand density
index, `sum(poids * (d1 / 25)^1.605)`: the number of stems per hectare
the plot would carry at a mean diameter of 25 cm.
[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
computes it the same way, so that the ceiling and the simulated stands
are measured alike. The upper quantile, rather than the maximum, leaves
out plots whose density comes from a few large weights of the IFN
design.

Reineke's line holds the density index constant: along it the basal area
still grows with the mean diameter (as `Dg^0.395`), whereas the maximum
density bends down in large stems for most species (Charru et al. 2012).
With the index ceiling alone, unmanaged stands of BFC simulated over 150
years kept gaining basal area (oaks 65-68 m2/ha, Douglas fir 106,
against 99 % quantiles of 50 and 62 on the plots): `g_max` stands for
that curvature, as a second ceiling. With both, the same stands level
off between 50 (oaks) and 68 m2/ha (spruce) after 150 years.

On 7 632 IFN plots of Bourgogne-Franche-Comte (first visit 2015 and
after), the 99 % quantiles of the index go from about 950 (oaks) to 1
250 (spruce, fir) stems/ha, those of the basal area from about 50 (oaks)
to 75 m2/ha (spruce) (`data-raw/diagnostic_plafond_finn.R`).

## References

Reineke L.H. (1933). Perfecting a stand-density index for even-aged
forests. Journal of Agricultural Research 46: 627-638.

Charru M., Seynave I., Morneau F., Rivoire M., Bontemps J.-D. (2012).
Significant differences and curvilinearity in the self-thinning
relationships of 11 temperate tree species assessed from forest
inventory data. Annals of Forest Science 69: 195-205.

## See also

[`simuler_itineraire()`](https://pobsteta.github.io/nemeton/reference/simuler_itineraire.md)
