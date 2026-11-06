# Sensitivity of B5 to the density of the LiDAR point cloud

Thins the point cloud down to lower densities and measures how much B5
moves for each unit: if B5 hardly changes when half the returns are
removed, a denser acquisition (drone LiDAR, NDP 2) is unlikely to change
the diagnosis; if it moves a lot, the current density is a limit (spec
067, dimensioning). The cloud is read once; each thinning only redraws
which returns are kept.

## Usage

``` r
simulate_density_sensitivity(
  units,
  nuage,
  densites = c(10, 5, 2),
  indicateurs = "B5",
  repetitions = 5L,
  tolerance = 5,
  graine = 1L,
  strates = c(0, 2, 5, 10, 20),
  profil = c("points", "densite_foliaire"),
  normaliser = FALSE,
  hauteur_sol = 0.5,
  hauteur_max = 60,
  classes = c(1:5, 9),
  min_points = 100L,
  resolution = 1
)
```

## Arguments

- units:

  sf polygon layer (spatial units / UGF).

- nuage:

  Point cloud, as in
  [`indicateur_b5_stratification()`](https://pobsteta.github.io/nemeton/reference/indicateur_b5_stratification.md):
  a table `X, Y, Z` (optionally `Classification`, `gpstime`), a `LAS`
  object, or LAZ files (read with lidR, clipped to the units: keep the
  study area small, the returns are held in memory).

- densites:

  Numeric. Target densities, in returns per square metre over the units.
  Densities at or above the current one are not simulated. Default
  `c(10, 5, 2)` (spec 067).

- indicateurs:

  Character. Indicators to test. Only `"B5"` for now; N4 and the
  structural N5 will join when they exist (spec 067).

- repetitions:

  Integer. Random thinnings per density. Default 5.

- tolerance:

  Numeric. Change of B5 (points on 0-100) below which a unit is called
  stable. Default 5.

- graine:

  Integer. Random seed. Default 1.

- strates, profil, normaliser, hauteur_sol, hauteur_max, classes,
  min_points, resolution:

  Passed to the B5 computation, see
  [`indicateur_b5_stratification()`](https://pobsteta.github.io/nemeton/reference/indicateur_b5_stratification.md).

## Value

A list of class `"sensibilite_densite"`:

- reference:

  data.frame `unite`, `B5`, `b5_status` at the current density.

- detail:

  data.frame `densite`, `repetition`, `unite`, `B5`, `b5_status`,
  `ecart` (absolute change from the reference, `NA` if either value is
  `NA`).

- resume:

  one row per simulated density: `densite`, `proportion` (share of
  returns or pulses kept), `n_unites` (units with a reference value),
  `ecart_median`, `ecart_p90` (over units and repetitions),
  `part_stable` (share of unit-repetitions within `tolerance`),
  `part_perdue` (share that fell below `min_points`), `stable`
  (`ecart_p90 <= tolerance`).

- densite_actuelle:

  returns per square metre over the units.

- eclaircie:

  `"impulsions"` when the cloud carries `gpstime` (all returns of a kept
  pulse are kept, as with a lower pulse density), else `"retours"`
  (returns drawn one by one, which keeps too many lower returns under a
  canopy).

- conclusion:

  `"densite_suffisante"` if B5 is stable at the highest simulated
  density below the current one, `"densite_limite"` if not,
  `"non_simule"` if no density was below the current one.

## Details

The conclusion reads a convergence: thinning cannot show what a denser
cloud would see, only whether the score has stopped moving at the
current density. A stable B5 at half the density supports keeping the
LiDAR HD; an unstable one says a drone campaign would be worth testing,
not that it would change the score.

## Lifecycle

Experimental (spec 067): may change in any release.

## See also

[`indicateur_b5_stratification()`](https://pobsteta.github.io/nemeton/reference/indicateur_b5_stratification.md)

## Examples

``` r
units <- sf::st_sf(id = 1, geometry = sf::st_sfc(
  sf::st_polygon(list(rbind(c(0, 0), c(30, 0), c(30, 30), c(0, 30), c(0, 0)))),
  crs = 2154))
set.seed(1)
nuage <- data.frame(X = runif(9000, 0, 30), Y = runif(9000, 0, 30),
                    Z = c(runif(6000, 15, 25), runif(3000, 0, 8)))
s <- simulate_density_sensitivity(units, nuage, densites = c(5, 2, 0.5))
s$resume
#>   densite proportion n_unites ecart_median ecart_p90 part_stable part_perdue
#> 1     5.0       0.50        1         0.25    22.708         0.8           0
#> 2     2.0       0.20        1         0.61     1.042         1.0           0
#> 3     0.5       0.05        1         0.76     3.080         1.0           0
#>   stable
#> 1  FALSE
#> 2   TRUE
#> 3   TRUE
```
