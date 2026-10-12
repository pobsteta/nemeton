# Number the trees of a circular plot (Groma rule)

Applies the Groma numbering rule, shared with the Python and Kotlin
implementations (common cases: `tests/testthat/fixtures/numerotation`).
Trees are retained within `rayon_m` and from `seuil_diam_cm` (bounds
included). Number 1 is the closest of the visible trees whose azimuth is
within `tolerance_deg` of the smallest visible azimuth (a trunk is
hidden when a closer trunk crosses the line of sight). The others follow
clockwise; trees whose relative azimuth is within the tolerance form a
group, numbered from the closest.

## Usage

``` r
numeroter_arbres(
  x,
  y,
  dbh_cm,
  id,
  rayon_m = 20,
  seuil_diam_cm = 7.5,
  unite_azimut = c("deg", "gr"),
  tolerance_deg = 1
)
```

## Arguments

- x, y:

  Numeric. Horizontal offsets from the plot centre (m), `x` towards
  east, `y` towards \*\*geographic\*\* north (rotate Lambert-93 offsets
  by the meridian convergence first).

- dbh_cm:

  Numeric. Diameter at 1.30 m (cm).

- id:

  Character. Stable tree identifiers (uuid), compared byte-wise.

- rayon_m:

  Plot radius (m). Default 20.

- seuil_diam_cm:

  Minimal diameter (cm). Default 7.5.

- unite_azimut:

  `"deg"` or `"gr"`: unit of the returned azimuth.

- tolerance_deg:

  Azimuth tie tolerance, always in degrees. Default 1.

## Value

A data.frame with `id`, `tree_id` (character, `NA` when excluded),
`exclusion` (`NA`, `"hors_rayon"`, `"sous_seuil"`), `visible`, `azimut`
(plot unit) and `distance_m`, in the input order.

## Lifecycle

Experimental (spec 061).

## Examples

``` r
numeroter_arbres(x = c(1, 0, -3), y = c(5, 8, 2), dbh_cm = c(30, 25, 40),
                 id = c("a", "b", "c"))
#>   id tree_id exclusion visible    azimut distance_m
#> 1  a       2      <NA>    TRUE  11.30993   5.099020
#> 2  b       1      <NA>    TRUE   0.00000   8.000000
#> 3  c       3      <NA>    TRUE 303.69007   3.605551
```
