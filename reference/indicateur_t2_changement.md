# Calculate Canopy Stability (T2)

T2 scores how stable the forest canopy of each unit has been over recent
years. Given a FORMS-T canopy-height time series (`forms_t`, spec 060),
it is **measured**: the share of the unit's canopy that lost at least
`seuil_perte` metres of height for good, whatever the cause (clear-cut,
partial cut, dieback, windthrow). Without that series it falls back on a
**stability proxy** derived from other indicators – a copy of N2 (forest
continuity), otherwise the T1 stand age capped at 100 (tuto 04) – which
carries no information of its own.

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

  An sf object with forest parcels. May contain pre-computed columns: N2
  (forest continuity) or T1 (stand age).

- layers:

  A nemeton_layers object (optional). Not directly used but kept for
  interface consistency.

- t1_values:

  Numeric vector. Pre-computed T1 age values (same length as
  nrow(units)). If NULL and units has no T1 column, T2 is `NA`.

- forms_t:

  FORMS-T canopy height, one layer per year (at least three), layers
  named by year: a
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
  as returned by
  [`charger_forms_t_hauteurs()`](https://pobsteta.github.io/nemeton/reference/charger_forms_t_hauteurs.md),
  or a vector of file paths. `NULL` (default) looks for a raster named
  `"forms_t"` in `layers`, and falls back on the proxy when there is
  none.

- seuil_perte:

  Numeric. Height loss, in metres, that counts as a canopy loss. Default
  `5`.

- unite_hauteur:

  Unit of `forms_t`: `"cm"` (default, FORMS-T as published) or `"m"`.

## Value

The input `units` (same class, rows and order) with an added numeric
column `T2` (0-100, 100 = stable canopy). `NA` where no source is
available – no default value.

When FORMS-T heights are supplied, four more columns are added:

- `t2_status`: `"forms_t"` (measured), `"proxy"` (unit outside the
  series, proxy used) or `"no_source"`;

- `t2_perte_pct`: share of the unit's canopy in lasting loss (%);

- `t2_croissance_m_an`: median Theil-Sen height trend of the canopy
  without loss (m/year);

- `t2_annees`: years read, e.g. `"2019-2024"`.

Without FORMS-T the result is unchanged from earlier releases (`T2`
only).

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

**Proxy (no FORMS-T)**: copy of the N2 (forest continuity/antiquity)
column if present in units, clamped to 0-100, otherwise the T1 stand age
(years) capped at 100 (`t1_values`, then a `T1` column). The fallback
applies **unit by unit**: a unit whose N2 is `NA` takes its T1 age when
known. With FORMS-T, a unit the series does not cover takes the proxy
too.

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

# Compute T1 first, then T2: the T1 column of the result feeds T2
t1 <- indicateur_t1_anciennete(units, layers = massif_demo_layers())
t2 <- indicateur_t2_changement(t1)
t2$T2

# Measured canopy stability from FORMS-T (spec 060)
h <- charger_forms_t_hauteurs(units)
t2 <- indicateur_t2_changement(t1, forms_t = h)
t2[, c("T2", "t2_status", "t2_perte_pct", "t2_croissance_m_an")]
} # }
```
