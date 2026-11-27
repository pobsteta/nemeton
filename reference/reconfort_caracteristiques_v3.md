# RECONFORT v3 feature stack (CRswir then CRre over a date grid)

Bands are linearly interpolated in time over `dates_grille` from the
valid observations, then CRswir and CRre are computed from the
interpolated bands. Columns: `CRswir_1..n` then `CRre_1..n` (134 for the
67-date grid of v3).

## Usage

``` r
reconfort_caracteristiques_v3(
  obs,
  dates_obs,
  dates_grille,
  bord = c("constant", "na"),
  min_obs = 2L,
  correction = c("aucune", "biais")
)
```

## Arguments

- obs:

  Named list of six numeric matrices `B4`, `B5`, `B6`, `B8A`, `B11`,
  `B12` (reflectance, 0-1), one row per pixel and one column per
  observation; `NA` marks an invalid value. An observation is valid for
  a pixel only when the six bands are valid.

- dates_obs:

  `Date` vector, one per observation column (any order).

- dates_grille:

  `Date` vector of the target grid.

- bord:

  `"constant"` or `"na"`.

- min_obs:

  Minimum number of valid observations (default 2).

- correction:

  `"aucune"` (default) or `"biais"`: subtract the mean Sen2Cor - MAJA
  biases of study 092 (CRswir 0.0112, CRre 0.0258), fitted on a single
  site (Couchey).

## Value

A numeric matrix, one row per pixel, `2 * length(dates_grille)` columns.

## Details

Edge rule (`bord`): `"constant"` extends the first/last valid
observation; `"na"` gives `NA` outside the observed range. A pixel with
fewer than `min_obs` valid dates gets `NA` everywhere.

## Examples

``` r
d <- as.Date("2024-01-01") + c(0, 40)
o <- lapply(c(B4 = .05, B5 = .08, B6 = .2, B8A = .4, B11 = .25, B12 = .15),
            function(v) matrix(c(v, v), 1))
dim(reconfort_caracteristiques_v3(o, d, as.Date("2024-01-01") + seq(0, 40, 10)))
#> [1]  1 10
```
