# Calculate Canopy Stability (T2)

T2 scores how stable the forest canopy of each unit has been over recent
years. Given a FORMS-T canopy-height time series (`forms_t`, spec 060),
it is **measured**: the share of the unit's canopy that lost at least
`seuil_perte` metres of height for good, whatever the cause (clear-cut,
partial cut, dieback, windthrow). Without that series T2 is `NA`: the
stability proxy (a copy of N2, or the T1 age capped at 100) was removed
in 2026.10.5, as it carried no information of its own.

## Usage

``` r
indicateur_t2_changement(
  units,
  layers = NULL,
  t1_values = NULL,
  forms_t = NULL,
  seuil_perte = 5,
  unite_hauteur = c("cm", "m")
)
```

## Arguments

- units:

  An sf object with forest parcels.

- layers:

  A nemeton_layers object (optional). Not directly used but kept for
  interface consistency.

- t1_values:

  Deprecated and ignored since 2026.10.5 (it fed the removed proxy); a
  warning is raised once per session when supplied.

- forms_t:

  FORMS-T canopy height, one layer per year (at least three), layers
  named by year: a
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
  as returned by
  [`charger_forms_t_hauteurs()`](https://pobsteta.github.io/nemeton/reference/charger_forms_t_hauteurs.md),
  or a vector of file paths. `NULL` (default) looks for a raster named
  `"forms_t"` in `layers`; T2 is `NA` when there is none.

- seuil_perte:

  Numeric. Height loss, in metres, that counts as a canopy loss. Default
  `5`.

- unite_hauteur:

  Unit of `forms_t`: `"cm"` (default, FORMS-T as published) or `"m"`.

## Value

The input `units` (same class, rows and order) with an added numeric
column `T2` (0-100, 100 = stable canopy). `NA` where FORMS-T is missing
– no default value.

When FORMS-T heights are supplied, four more columns are added:

- `t2_status`: `"forms_t"` (measured) or `"no_source"` (unit without
  canopy in the series);

- `t2_perte_pct`: share of the unit's canopy in lasting loss (%);

- `t2_croissance_m_an`: median Theil-Sen height trend of the canopy
  without loss (m/year);

- `t2_annees`: years read, e.g. `"2019-2024"`.

Without FORMS-T only the `T2` column (all `NA`) is added.

## Details

**Measured path (FORMS-T)**. Only pixels whose height reached
`seuil_perte` at least once are canopy. A canopy pixel is in lasting
loss when, from some year on, its height stays at least `seuil_perte`
below its maximum over the previous years until the end of the series; a
one-year dip that recovers does not count.
`T2 = 100 * (1 - loss_share)`, where loss_share is the share of the unit
canopy in loss (coverage-weighted with exactextractr). The Theil-Sen
slope of the other canopy pixels gives `t2_croissance_m_an`, a
diagnostic that does not enter the score.

Validation (spec 060, 2026-10-11): on Reconfort, 96 % of the losses
outside SUFOSAT clear-cuts are confirmed by the LiDAR HD canopy (flown
2023-2024), so T2 also sees partial cuts and dieback that T3 does not;
on Fordead (bark-beetle site) the loss covers 98 % of the forest.

Do not compare T2 values computed over different year windows. FORMS-T
is a height **predicted** from Sentinel-1/2 and GEDI, not measured;
light thinnings (less than `seuil_perte`) are not seen.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## See also

Other temporal-indicators:
[`indicateur_t1_anciennete()`](https://pobsteta.github.io/nemeton/reference/indicateur_t1_anciennete.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)

data(massif_demo_units)
units <- massif_demo_units[1:10, ]

# Canopy stability measured on FORMS-T (spec 060)
h <- charger_forms_t_hauteurs(units)
t2 <- indicateur_t2_changement(units, forms_t = h)
t2[, c("T2", "t2_status", "t2_perte_pct", "t2_croissance_m_an")]
} # }
```
