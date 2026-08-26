# French population grid (INSEE Filosofi)

Downloads (once per machine) and reads the INSEE *Filosofi* population
grid, clipped to `aoi`. Feeds
[`indicateur_s3_population`](https://pobsteta.github.io/nemeton/reference/indicateur_s3_population.md).

## Usage

``` r
load_insee_population_source(
  aoi,
  buffer_m = 21000,
  maille = c("1km", "200m"),
  millesime = 2021,
  crs = 2154,
  territoire = c("FR", "MTQ", "REU"),
  cache_dir = NULL
)
```

## Arguments

- aoi:

  `sf`/`sfc` extent. Cells are read within its bounding box grown by
  `buffer_m`.

- buffer_m:

  Metres added around `aoi` before clipping. Default `21000`, enough for
  the 20 km ring S3 uses.

- maille:

  `"1km"` (default) or `"200m"`. 200 m is six times heavier and
  pointless for 5-20 km rings.

- millesime:

  Filosofi vintage. Only `2021` is wired.

- crs:

  Output CRS. Default `2154`.

- territoire:

  `"FR"` (metropolitan), `"MTQ"` or `"REU"`.

- cache_dir:

  Override the shared cache directory.

## Value

An `sf` of grid cells with `ind` (individuals) and the imputation flag,
or `NULL` when the source cannot be reached — **never a fabricated
fallback** (spec 050, and the rule of v0.187.0). Carries a
`part_imputee` attribute: share of cells that are imputed.

## Details

**The clip happens at read time, not after.** Measured on the Couchey
massif: 1 024 cells read instead of the 374 511 the metropolitan layer
holds. Reading the whole of France to keep 0.3% of it would cost memory
for nothing.

**Imputed cells are kept.** `i_est_1km == 1` marks a cell holding fewer
than 11 fiscal households, whose count INSEE *models* rather than
observes. Dropping them would remove real people — the imputation exists
precisely so totals stay right — and it would bite hardest where forests
are: 42% of the cells around Couchey are imputed, 53% within 20 km. They
are kept, and the share is reported back so the caller can say so (see
the `part_imputee` attribute).

Licence Ouverte / Open Licence 2.0 (INSEE). Attribution required.
