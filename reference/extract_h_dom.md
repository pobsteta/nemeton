# Extract dominant height from a CHM for a set of spatial units

For each polygon unit, computes the dominant height \\H\_{dom}\\ as a
high percentile (default 90%) of the canopy-height pixels falling inside
that unit. Pixels with `NA` (typically masked by
[`sanitize_chm`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md))
are ignored.

## Usage

``` r
extract_h_dom(chm, units, percentile = 0.9, min_pixels = 10L)
```

## Arguments

- chm:

  A `SpatRaster` of canopy heights in metres. Typically the `chm_clean`
  component returned by
  [`sanitize_chm`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md).

- units:

  An `sf` polygon layer. One row per spatial unit.

- percentile:

  Numeric in `[0, 1]`. The percentile of canopy heights to take as
  dominant height. Default `0.9`.

- min_pixels:

  Integer. Minimum number of non-`NA` pixels required to compute
  \\H\_{dom}\\. Units with fewer pixels get `NA`. Default `10`.

## Value

A numeric vector of length `nrow(units)` containing the dominant height
(in metres) for each unit. `NA` when the unit holds fewer than
`min_pixels` valid pixels.

## Details

The convention \\H\_{dom} = P\_{90}(\mathrm{CHM})\\ is a practical proxy
for the classical definition (mean height of the 100 largest trees per
hectare) when only a CHM raster is available. Choosing `percentile = 1`
yields the maximum height, `percentile = 0.5` the median.

## Examples

``` r
if (FALSE) { # \dontrun{
chm_clean <- sanitize_chm(chm, forest_mask = bd_foret)$chm_clean
units$H_dom <- extract_h_dom(chm_clean, units)
} # }
```
