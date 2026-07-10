# Per-unit canopy `lai_max` from a LiDAR PAI raster (spec 035 D5)

Aggregate a Plant Area Index raster (typically the cached `pai.tif`
produced by
[`pai_depuis_nuage`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md))
into the per-unit `lai_max` expected by
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md).

## Usage

``` r
lai_max_depuis_pai(units, pai, probs = 0.9, min_pai = 0.1)
```

## Arguments

- units:

  An `sf` of management units.

- pai:

  A `SpatRaster` of Plant Area Index, or a path to one (e.g. the
  `pai.tif` written by `regen_sensibilite(pai_cache = )`).

- probs:

  Percentile of the within-unit PAI distribution used as the plateau.
  Default `0.9`.

- min_pai:

  Pixels strictly below this value are excluded as non-canopy. Default
  `0.1`. Set to `0` to keep every pixel.

## Value

Numeric vector of `lai_max`, length `nrow(units)`. `NA` for a unit with
no canopy pixel. Pass it straight to `regen_bilan_hydrique(lai_max = )`,
which converts it to the id-keyed list `biljou_run_grid()` requires.

## Details

[`biljouR::biljou_lai()`](https://pobsteta.github.io/biljouR/reference/biljou_lai.html)
treats `lai_max` as the **plateau** of the phenology curve (coniferous:
constant all year; broadleaved: the flat top of the trapezoid between
`budburst + ramp` and `leaf_fall - ramp`). A zonal **mean**
under-estimates that plateau — which is what the app's own fallback did.
This function therefore extracts a **high percentile** (default P90),
robust to outlier pixels where a plain `max` would not be.

Pixels below `min_pai` are treated as non-canopy (gaps, roads, water)
and excluded before the percentile, so a unit with a clearing keeps the
PAI of its stocked part.

## See also

[`pai_depuis_nuage`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md),
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
