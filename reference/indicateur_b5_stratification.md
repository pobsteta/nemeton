# B5: Vertical stratification from the LiDAR point cloud

Vertical structure of each unit read in the LiDAR point cloud itself,
not in a canopy height model: Shannon entropy of the distribution of
returns (or of foliage density) between five height strata, on 0-100
(100 = even distribution between the strata). B2 reads the canopy
surface seen from above; B5 reads what lies under it (spec 067, chantier
C, first step, without ForPT). Source-conditional: without a point
cloud, B5 is `NA` with its status and the B family is unchanged.

## Usage

``` r
indicateur_b5_stratification(
  units,
  nuage = NULL,
  layers = NULL,
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

  The point cloud, one of:

  - a `data.frame` (or matrix) with columns `X`, `Y`, `Z`, and
    optionally `Classification`, in the CRS of `units`;

  - a `LAS` object of lidR;

  - a character vector of `.laz` / `.las` files, or a directory holding
    them (e.g. `<project>/cache/layers/lidar_nuage`), read tile by tile
    with lidR (in Suggests) and clipped to the units.

  `NULL`: B5 is `NA` with status `skipped_no_lidar`.

- layers:

  Unused, accepted for
  [`nemeton_compute()`](https://pobsteta.github.io/nemeton/reference/nemeton_compute.md).

- strates:

  Numeric. Lower bounds of the strata in metres, starting at 0. Default
  `c(0, 2, 5, 10, 20)`: strata 0-2, 2-5, 5-10, 10-20 and20 m (spec 067).

- profil:

  `"points"` (default, spec 067 D-3): share of vegetation returns in
  each stratum. `"densite_foliaire"`: share of foliage density in each
  stratum, from the gap fraction (MacArthur & Horn 1969), which corrects
  part of the occlusion of the lower strata by the upper ones.

- normaliser:

  Logical. Are `Z` values altitudes that must first be turned into
  heights above ground? `TRUE` needs lidR and ground returns (class 2):
  heights are taken above a TIN of the ground returns, tile by tile.
  Default `FALSE` (heights already normalised). A cloud whose median `Z`
  exceeds `hauteur_max` is refused rather than read as heights.

- hauteur_sol:

  Numeric. Returns below this height (m) are ground: they count in no
  stratum, but they enter the gap fraction of `"densite_foliaire"`.
  Default 0.5.

- hauteur_max:

  Numeric. Returns above this height (m) are noise and dropped, as are
  returns below -1 m. Default 60.

- classes:

  Integer. Classification codes kept when the cloud has a
  `Classification` column. Default `c(1:5, 9)`: unclassified, ground,
  the three vegetation classes and water of IGN LiDAR HD; buildings (6),
  noise (7, 18), bridges (17) and the IGN classes 64-67 are dropped.

- min_points:

  Integer. Minimum number of returns in a unit (ground included); below
  it, B5 is `NA` with status `skipped_low_density`. Default 100.

- resolution:

  Numeric. Size (m) of the grid used to assign returns to units (a
  return belongs to the unit holding the centre of its cell). Default 1.

## Value

`units` with

- B5:

  score 0-100, 100 = returns (or foliage) evenly spread over the strata;
  0 = a single stratum, or no vegetation above `hauteur_sol`.

- b5_status:

  `calculated`, `skipped_no_lidar`, `skipped_no_coverage` (no return in
  the unit) or `skipped_low_density` (fewer than `min_points`).

- b5_profil:

  `profil` used.

- b5_points:

  number of returns in the unit (ground included).

- b5_densite:

  returns per square metre.

- b5_s1, ..., b5_sK:

  share of each stratum (sums to 1), from the lowest to the highest.

## Details

**Score.** With `p_k` the share of stratum `k` among `K` strata,
`B5 = 100 * (-sum(p_k * log(p_k)) / log(K))`: the Shannon entropy
normalised by its maximum, i.e. the evenness of the vertical profile. It
is the LiDAR form of the foliage height diversity of MacArthur &
MacArthur (1961). It needs no ForPT (spec 067, D-3); ForPT will be used
later to separate wood from foliage.

**`"densite_foliaire"`.** With `P(h)` the share of returns below height
`h` (ground included), the foliage of stratum `[a, b)` is proportional
to `log(P(b) / P(a))` (MacArthur & Horn 1969; the extinction coefficient
cancels out in the shares). A unit without ground return gets a floor of
half a return at `hauteur_sol`.

**Pitfalls** (fiche B5): at about 10 returns per square metre (LiDAR
HD), the lower strata of closed stands are under-sampled, so `"points"`
underestimates the stratification of closed stands (measured by the
dimensioning of spec 067); a leaf-on and a leaf-off flight do not give
the same profile; B5 measures evenness, not height: a 2 m thicket split
between two strata can score as high as a high forest.

## Lifecycle

Experimental (spec 067): may change in any release.

## References

MacArthur, R. H. & MacArthur, J. W. (1961). On bird species diversity.
*Ecology* 42(3), 594-598.

MacArthur, R. H. & Horn, H. S. (1969). Foliage profile by vertical
measurements. *Ecology* 50(5), 802-804.

## See also

[`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md),
[`compute_dtm_chm_from_laz()`](https://pobsteta.github.io/nemeton/reference/compute_dtm_chm_from_laz.md)

## Examples

``` r
units <- sf::st_sf(
  id = 1:2,
  geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(20, 0), c(20, 20), c(0, 20), c(0, 0)))),
    sf::st_polygon(list(rbind(c(20, 0), c(40, 0), c(40, 20), c(20, 20), c(20, 0)))),
    crs = 2154
  )
)
set.seed(1)
n <- 4000
nuage <- data.frame(X = runif(n, 0, 40), Y = runif(n, 0, 20))
# unit 1: one high layer; unit 2: returns spread over the whole height
nuage$Z <- ifelse(nuage$X < 20, runif(n, 22, 28), runif(n, 0, 30))
indicateur_b5_stratification(units, nuage)$B5
#> [1]  0.00 88.76
```
