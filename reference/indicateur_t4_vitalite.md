# Calculate dynamic vitality (T4)

Compares the dominant-height growth of each unit, observed on the
FORMS-T annual canopy-height series, with the growth expected by the
FINN forest model for comparable stands (spec 068). 50 means the unit
grows as expected; low values flag a growth deficit, high values a
growth above expectation. Source-conditional: without FORMS-T, T4 is
`NA`.

## Usage

``` r
indicateur_t4_vitalite(
  units,
  forms_t = NULL,
  essence = NULL,
  ser = NULL,
  coupes = NULL,
  attendu = NULL,
  tolerance_h = 2,
  min_analogues = 30L,
  min_pixels = 50L,
  unite_hauteur = c("cm", "m")
)
```

## Arguments

- units:

  An sf object with forest units.

- forms_t:

  A `SpatRaster` of yearly canopy heights, one layer per year named by
  year (as returned by
  [`charger_forms_t_hauteurs()`](https://pobsteta.github.io/nemeton/reference/charger_forms_t_hauteurs.md)),
  or file paths. `NULL` (default): T4 is not computed (`NA`).

- essence:

  Dominant species of each unit, as IFN `ESPAR` codes (for example
  `"03"` sessile oak, `"09"` beech, `"62"` Norway spruce): a character
  vector of length `nrow(units)`, a single code for every unit, or the
  name of a column of `units`. `NULL` (default): the column `essence` of
  `units` when present.

- ser:

  Optional sylvo-ecoregion (SER) code of each unit, vector or column
  name. `NULL` (default): the column `ser` of `units` when present;
  otherwise analogues are taken in every SER.

- coupes:

  Optional logical vector, `TRUE` for units with a cut detected over the
  series (for instance `T3 > 0`). `NULL` (default): the `T3` column of
  `units` is used when present.

- attendu:

  Optional data frame of expected increments simulated on the unit's own
  inventory with
  [`accroissement_hdom_finn()`](https://pobsteta.github.io/nemeton/reference/accroissement_hdom_finn.md),
  with columns `unite` (row number in `units`) and `accroissement` (m
  over 5 years). For those units it replaces the IFN analogues.

- tolerance_h:

  Numeric, half-width (m) of the initial dominant-height window for the
  analogues. Default 2.

- min_analogues:

  Integer, minimum number of analogue plots. Default 30.

- min_pixels:

  Integer, minimum number of canopy pixels (\>= 5 m) per unit and year.
  Default 50 (0.5 ha at 10 m).

- unite_hauteur:

  Unit of the FORMS-T heights, `"cm"` (default, as distributed) or
  `"m"`.

## Value

`units` with the numeric column `T4` (0-100) and:

- `t4_status`: `"calculated"`, `"skipped_no_forms_t"`,
  `"skipped_no_coverage"`, `"skipped_cut"`, `"skipped_drop"` (dominant
  height fell by more than 3 m from one year to the next),
  `"skipped_no_essence"` or `"skipped_no_analogues"`;

- `t4_accroissement_obs`: observed dominant-height increment (m per 5
  years);

- `t4_accroissement_att`: median of the reference distribution (m per 5
  years);

- `t4_h_dom`: dominant height of the first year (m);

- `t4_n_analogues`: number of analogue plots (`NA` with `attendu`).

## Details

**Observed.** Each year, the dominant height of the unit is the 90th
percentile of its FORMS-T pixels at least 5 m high. The increment is the
Theil-Sen slope of that series, times 5.

**Expected.** IFN plots of Bourgogne-Franche-Comte measured in 2017-2021
(3 398 plots) were run through one FINN step (5 years) under the E-OBS
2019-2023 climate, 20 draws each (`data-raw/t4_analogues_bfc.R`). The
analogues of a unit share its dominant species and SER and have an
initial dominant height within `tolerance_h` of the unit's first-year
value; when fewer than `min_analogues` are found, the SER is dropped,
then the window is doubled.

**Score.** FORMS-T varies far more than FINN draws (standard deviation
1.35 m against 0.1 m per 5 years around IFN plots): the reference adds
to the simulated increments the residuals observed minus simulated
measured around the IFN plots of the same species and initial dominant
height (within `tolerance_h`, then twice that, then all species), mean
bias included (`data-raw/t4_residus_forms_bfc.R`): beyond 28 m FORMS-T
keeps growing while the height-diameter curves level off, so the bias
depends on height. `T4 = 100 * P(simulated + residual < observed)`.

**Not computed** after a cut (`coupes`) or a fall of the dominant height
of more than 3 m between two years: a cut is not a vitality defect;
excess mortality
([`surmortalite_finn()`](https://pobsteta.github.io/nemeton/reference/surmortalite_finn.md))
and R5 cover those cases.

**Limits.** The residuals are measured on discs of about 20 ha around
blurred IFN coordinates: they include stand-to-stand variability, which
makes T4 cautious; a smaller unit is noisier than the reference assumes.
FORMS-T is a height predicted from Sentinel-1/2 and GEDI, not measured.
The analogues cover Bourgogne-Franche-Comte (FINN calibration domain).

**Centring check** (spec 068, 2026-11-15): on 1 072 fir and spruce cells
of 4 ha at Dabo (Vosges, no known disturbance), median 57, 5 % and 95 %
quantiles 13 and 98; stands over about 33 m find no analogue.

## See also

[`accroissement_hdom_finn()`](https://pobsteta.github.io/nemeton/reference/accroissement_hdom_finn.md),
[`charger_forms_t_hauteurs()`](https://pobsteta.github.io/nemeton/reference/charger_forms_t_hauteurs.md)

Other temporal-indicators:
[`indicateur_t1_anciennete()`](https://pobsteta.github.io/nemeton/reference/indicateur_t1_anciennete.md),
[`indicateur_t2_changement()`](https://pobsteta.github.io/nemeton/reference/indicateur_t2_changement.md)
