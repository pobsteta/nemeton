# Dominant-height increment expected by FINN

Simulates one FINN step (5 years) from the first-visit state of each
plot and returns the increment of its dominant height, the mean height
of the 100 largest trees per hectare. Heights come from the
height-diameter curves fitted on the total heights measured by the
French national forest inventory (IFN, Bourgogne-Franche-Comte), by
species and, where enough trees were measured, by sylvo-ecoregion (SER).
This is the expected growth that the dynamic vitality indicator T4
compares with the FORMS-T canopy-height series (spec 068).

## Usage

``` r
accroissement_hdom_finn(
  calibration,
  arbres,
  environnement,
  ser = NULL,
  n_tirages = 20L,
  correction = TRUE
)
```

## Arguments

- calibration:

  A `finn_calibration` from
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md).

- arbres:

  Data frame of trees, as in
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md):
  `placette`, `essence`, `d1` (cm), `poids` (stems/ha); `d2` and
  `statut` are optional and ignored (every tree with a diameter is alive
  at the start).

- environnement:

  Data frame with `placette` and the environmental variables of the
  calibration, for the simulated period.

- ser:

  Optional named character vector giving the SER code of each plot
  (names = plot identifiers), or a data frame with columns `placette`
  and `ser`. Without it, the all-SER curve of each species is used.

- n_tirages:

  Integer, number of FINN draws per plot. Default 20.

- correction:

  Logical, apply the growth and recruitment correction of
  [`corriger_finn()`](https://pobsteta.github.io/nemeton/reference/corriger_finn.md)
  when the calibration carries one. Default `TRUE`.

## Value

A data frame with one row per plot and draw: `placette`, `ser`,
`essence` (species with the largest basal area at the start), `g0`
(m2/ha), `h_dom` (dominant height at the start, m), `tirage` and
`accroissement` (dominant-height increment over the step, m).

## Details

The curves are static: one height per diameter and species. They mix
stands of different fertility, so the increment they give for the
dominant trees can be lower than the true one on good sites; T4 must be
checked for centring on a stand with no known disturbance before use
(spec 068, T4-3). Species pooled as `"other"` by the calibration use the
`"other"` curve.

## See also

[`indicateur_t4_vitalite()`](https://pobsteta.github.io/nemeton/reference/indicateur_t4_vitalite.md),
[`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md),
[`corriger_finn()`](https://pobsteta.github.io/nemeton/reference/corriger_finn.md)
