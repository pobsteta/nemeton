# Calibrate FINN on revisited plots

Fits the mechanistic processes of FINN (Forest Informed Neural Networks,
Kaber et al.; growth, mortality, regeneration, competition) on plots
measured twice, so that the model can then simulate stand trajectories
(spec 068, chantier D, step 3). One FINN site is one plot, one FINN step
is the interval between the two visits.

## Usage

``` r
calibrer_finn(
  arbres,
  environnement,
  processus = "mecaniste",
  surface_placette = 0.7,
  epoques = 600L,
  taux_apprentissage = 0.003,
  part_essences = 0.9,
  min_arbres_essence = 300L,
  pas_annees = 5,
  graine = 42L,
  dossier = NULL
)
```

## Arguments

- arbres:

  data.frame, one row per tree and pair of visits, with columns:

  placette

  :   plot identifier.

  essence

  :   species code (character).

  d1, d2

  :   diameter at breast height (cm) at the first and second visit; `d1`
      is `NA` for recruits, `d2` for dead or cut trees.

  poids

  :   stems per hectare represented by the tree (the IFN `W`): the
      weight of the first visit for a tree followed, the theoretical
      weight of its circle for a recruit.

  statut

  :   `"vivant"` (alive at both visits), `"mort"` (died or left the
      stand), `"coupe"` (cut) or `"recrute"` (new at the second visit).

  Cut trees are removed from the initial state: the cut is assumed to
  happen at the start of the interval, so that FINN learns the natural
  dynamics only (interventions are applied between steps, D-2).

- environnement:

  data.frame, one row per plot: `placette` and the numeric environmental
  variables (e.g. summer maximum temperature, annual rainfall, soil
  depth), in natural units (FINN standardises them). Plots with a
  missing value are dropped.

- processus:

  Character. `"mecaniste"` (default) is the only value for now: neural
  components come only once a cross-validation shows a gain on revisited
  plots (D-3).

- surface_placette:

  Numeric. Area of the FINN patch, in hectares. Default 0.7. FINN rounds
  cohort sizes to integers: with the 15 m circle of the IFN (0.0707 ha)
  a tree of the 6 m circle counts 6.25 stems rounded to 6, which adds
  noise of 1.4 m2/ha (SD) on the initial basal area and a bias on
  recruitment; at 0.7 ha both vanish (spec 068, section 9).

- epoques:

  Integer. Number of training epochs. Default 600.

- taux_apprentissage:

  Numeric. Learning rate. Default 0.003 (better held-out error than 0.01
  on BFC, spec 068).

- part_essences:

  Numeric in `(0, 1]`. Species kept by decreasing initial basal area
  until they cover this share; the others are pooled in `"other"`.
  Default 0.9.

- min_arbres_essence:

  Integer. Minimum number of initial trees (alive or dead at the first
  visit) for a species to get its own parameters; below it the species
  goes to `"other"`, even within `part_essences`. Default 300: on BFC,
  species with 130 to 140 trees gave unstable parameters (predictions of
  several hundred m2/ha on a few plots in two bootstrap calibrations out
  of four, spec 068).

- pas_annees:

  Numeric. Years between the two visits, kept as metadata for the
  simulations. Default 5.

- graine:

  Integer. Random seed (R and torch). Default 42.

- dossier:

  Character or `NULL`. Folder where FINN writes checkpoints every 100
  epochs. Default `NULL` (none).

## Value

A list of class `"finn_calibration"`: `modele` (the fitted FINN model, a
torch object: save it with
[`torch::torch_save()`](https://torch.mlverse.org/docs/reference/torch_save.html),
not [`saveRDS()`](https://rdrr.io/r/base/readRDS.html)), `essences`,
`variables_env`, `surface_placette`, `pas_annees`, `recruits_dbh`,
`n_placettes`, `epoques`, `taux_apprentissage`, `processus`.

## Details

Requires the suggested packages FINN, torch (with libtorch,
[`torch::install_torch()`](https://torch.mlverse.org/docs/reference/install_torch.html))
and data.table; the function stops with a clear message when they are
missing.

On 1000 IFN plots of Bourgogne-Franche-Comte revisited after 5 years,
with summer maximum temperature, annual rainfall (E-OBS) and soil depth,
the error on the basal area at 5 years of 1000 other plots was 3.36
m2/ha (bias +0.37, 40 minutes of CPU), against 3.58 for a linear
regression and 4.24 for persistence
(`data-raw/prototype_finn_calibration.R`).

## References

Kaber Y., Hartig F. et al. FINN: Forest Informed Neural Networks. R
package version 0.1.0, CRAN.

## See also

[`predire_finn()`](https://pobsteta.github.io/nemeton/reference/predire_finn.md)
