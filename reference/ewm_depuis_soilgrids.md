# Maximum extractable water (`ewm`) per unit, from SoilGrids

Per-unit **maximum extractable water** (`ewm`, mm) — the plant-available
water reservoir that drives the whole BILJOU water balance, since
`rew = sw / ewm_total` and stress starts below `rew_c = 0.4`.

## Usage

``` r
ewm_depuis_soilgrids(
  units,
  rooting_depth_cm = 100,
  country = "FR",
  depths = NULL,
  progress_callback = NULL
)
```

## Arguments

- units:

  An `sf` of management units.

- rooting_depth_cm:

  Rooting depth in cm (default 100). Depth intervals are truncated at
  this value; an interval starting below it is skipped.

- country:

  ISO country code for the datasource lookup. Default `"FR"`.

- depths:

  Optional character vector of SoilGrids depth intervals to use
  (default: all those within `rooting_depth_cm`, see
  `SOILGRIDS_DEPTHS`).

- progress_callback:

  Optional function called with
  `list(current = "ewm:layer", interval = , i = , n = )` per depth
  interval, and `list(current = "ewm:complete")` at the end (monitoring
  pattern).

## Value

Numeric vector of `ewm` in mm, length `nrow(units)`. `NA` for a unit
whose soil data could not be resolved. `NULL` if **no** depth interval
could be loaded at all (graceful degradation — the caller falls back to
a uniform `ewm`).

## Details

Built from SoilGrids 250 m (ISRIC): for each standard depth interval
within `rooting_depth_cm`, the available water capacity is estimated by
the
[`awc_saxton_rawls`](https://pobsteta.github.io/nemeton/reference/awc_saxton_rawls.md)
pedotransfer function from clay, sand and organic carbon, corrected for
coarse fragments, then integrated over the horizon thickness:

\$\$ewm = \sum\_{layers} AWC_i \times thickness_i \times 10\$\$

(the factor 10 converts cm of horizon x m3/m3 into mm of water).

The topographic wetness index is deliberately **not** used here: it
measures lateral convergence, not storage capacity, and it already feeds
[`indicateur_r3_secheresse`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)
directly (spec 035, decision D1).

## References

Poggio L. et al. (2021). SoilGrids 2.0. *SOIL* 7:217-240.

## See also

[`awc_saxton_rawls`](https://pobsteta.github.io/nemeton/reference/awc_saxton_rawls.md),
[`build_biljou_soil`](https://pobsteta.github.io/nemeton/reference/build_biljou_soil.md)
