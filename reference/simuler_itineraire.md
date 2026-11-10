# Simulate stand trajectories under a silvicultural itinerary

Runs a calibrated FINN model step by step from the initial state of each
plot, and applies the rules of an itinerary **between the steps** by
removing stems from the cohorts (spec 068, D-2): FINN learns the natural
dynamics only, the cuts are imposed from outside.

## Usage

``` r
simuler_itineraire(
  calibration,
  arbres,
  environnement,
  itineraire = NULL,
  horizon = 50,
  n_tirages = 20L,
  elargissement = c("racine", "lineaire"),
  volume = FALSE,
  unites = NULL,
  carbone = FALSE,
  bef = 1.3,
  fraction_carbone = 0.5
)
```

## Arguments

- calibration:

  A `"finn_calibration"` object from
  [`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md),
  with conformal residuals from
  [`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md)
  for an interval.

- arbres:

  data.frame of the initial trees: `placette`, `essence`, `d1` (cm),
  `poids` (stems/ha); with a `statut` column, only `"vivant"` and
  `"mort"` rows are kept, as in
  [`predire_finn()`](https://pobsteta.github.io/nemeton/reference/predire_finn.md).

- environnement:

  data.frame, one row per plot: `placette` and the variables of the
  calibration. Held constant over the horizon.

- itineraire:

  `NULL` (no management) or one entry of
  [`itineraires_catalogue()`](https://pobsteta.github.io/nemeton/reference/itineraires_catalogue.md)
  with `statut_source = "source"`. Rules used (`regles`), all optional
  except the rotation:

  aucune_coupe

  :   `TRUE`: no cut at all (free development, senescence island);
      FINN's dynamics alone, reported under the itinerary's code.
      Excludes every other rule, the rotation included.

  rotation_ans

  :   years between two interventions; a multiple of
      `calibration$pas_annees`.

  diametre_exploitabilite_cm

  :   every stem at or above this diameter is harvested.

  surface_terriere_cible_m2ha

  :   if the basal area is above the target, a share `(G - cible) / G`
      of the stems of every cohort is removed (thinning across all
      sizes).

  intensite_prelevement_pct

  :   maximum share of the stems removed by the thinning; alone (no
      target), the share removed at every intervention.

  norme_g_selon_dg

  :   a thinning norm by quadratic mean diameter: `dg_cm` (increasing)
      and `g_m2ha`, the basal area left after thinning at that mean
      diameter. The target is interpolated on the plot's Dg (all stems);
      below the first `dg_cm` there is no thinning, beyond the last one
      its value holds. Replaces `surface_terriere_cible_m2ha` (not
      both).

  Stems removed are drawn (binomial per cohort): rounding would never
  cut a cohort of a single large stem.

- horizon:

  Numeric. Years simulated, a multiple of `calibration$pas_annees`.
  Default 50.

- n_tirages:

  Integer. Trajectories per plot (FINN is stochastic). Default 20.

- elargissement:

  Character. How the conformal half-width `q` (measured for one step)
  grows with the number of steps `k`: `"racine"` (default,
  `q * sqrt(k)`, independent errors from step to step) or `"lineaire"`
  (`q * k`, errors that add up). Both are **hypotheses**: no plot is
  revisited over 50 years.

- volume:

  Logical. Also compute the merchantable volume (`"volume"` and
  `"volume_preleve"`, m3/ha) with the one-entry Schaeffer tariffs of the
  IFN
  ([`ifn_tarif_schaeffer_reference()`](https://pobsteta.github.io/nemeton/reference/ifn_tarif_schaeffer_reference.md):
  number and advised type of each species, cascade SER -\> GRECO -\>
  France with the SER of the `ser` column of `environnement` when
  present). Stems below 7.5 cm (the IFN threshold) have no volume. The
  `"other"` group takes the tariff of the dominant `"other"` species
  (basal area) of the plot at the start that has a tariff, or of all
  plots. Default `FALSE`.

- unites:

  data.frame or `NULL`. `placette`, `unite`: the plots of each
  management unit (UGF). The output is then one row per unit, the mean
  of its plots (equal weights), with the half-width of a unit of `k`
  plots measured by
  [`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md)
  on groups of `k` held-out plots.

- carbone:

  Logical. Also compute the carbon of the merchantable stem wood
  (`"carbone"` and `"carbone_preleve"`, tC/ha): the volume of the same
  tariffs as `volume` (needed, computed even when `volume = FALSE`)
  times the basic wood density of the species
  ([`infradensite_espar()`](https://pobsteta.github.io/nemeton/reference/infradensite_espar.md),
  that of the tariff species for `"other"`), `bef` and
  `fraction_carbone`. Default `FALSE`.

- bef:

  Numeric. Biomass expansion factor from stem volume to total
  aboveground biomass. Default 1.30, as
  [`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md).

- fraction_carbone:

  Numeric. Carbon fraction of the dry biomass. Default 0.50, the value
  of `inst/extdata/wood_density.csv` used by
  [`indicateur_c1_biomasse()`](https://pobsteta.github.io/nemeton/reference/indicateur_c1_biomasse.md).

## Value

data.frame in long format, one row per plot, year and variable:
`placette`, `itineraire`, `annee` (years from the start, 0 = initial
state), `variable` (`"g"`: basal area before the cut, m2/ha; `"tiges"`:
stems/ha before the cut; `"g_prelevee"`: basal area removed at that
date, m2/ha; with `volume = TRUE`, `"volume"` and `"volume_preleve"`,
m3/ha; with `carbone = TRUE`, `"carbone"` and `"carbone_preleve"`,
tC/ha), `moyenne` (mean of the trajectories), `bas`, `haut` (interval,
for `"g"` only) and `intervalle` (`"conforme"` at one step,
`"conforme_racine"` or `"conforme_lineaire"` beyond, `"aucun"` without
conformal residuals or at year 0). With `unites`: `unite` instead of
`placette`, plus `n_placettes` and `groupes_conformes` (`"voisins"`,
`"hasard"` or `"placette"` for a unit of one plot).

## Details

The climate is the one of `environnement`, held constant: without an
explicit scenario a 50-year trajectory assumes the recent climate. The
response of the stand to a thinning (faster growth) comes only from the
competition FINN learnt on unthinned plots. The conformal interval is
measured on the natural dynamics over one step; after a cut it is kept
as is, which is another hypothesis.

The volume comes from the diameter only (FINN carries no height). On 12
974 trees of 1000 IFN plots of BFC, the tariffs of the exact species
give 1.8 % more than the IFN volumes in total, 9.6 % less between 7.5
and 20 cm and 18.6 % more above 70 cm
(`data-raw/prototype_finn_volume.R`). The carbon inherits this volume
(stems below 7.5 cm carry none) and holds the same `bef` and
`fraction_carbone` as C1, so that year 0 compares with C1.

## See also

[`calibrer_finn()`](https://pobsteta.github.io/nemeton/reference/calibrer_finn.md),
[`conformer_finn()`](https://pobsteta.github.io/nemeton/reference/conformer_finn.md),
[`itineraires_catalogue()`](https://pobsteta.github.io/nemeton/reference/itineraires_catalogue.md)
