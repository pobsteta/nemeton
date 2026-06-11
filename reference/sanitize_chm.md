# Sanitize a Canopy Height Model raster

Applies a sequence of masks to filter out pixels where the reported
canopy height is implausible for forest analysis. All masks are
optional: only the ones for which an input is provided are applied.

## Usage

``` r
sanitize_chm(
  chm,
  forest_mask = NULL,
  buildings = NULL,
  water = NULL,
  ndvi = NULL,
  max_height = 50,
  slope = NULL,
  ndvi_threshold = 0.2,
  forest_coverage_threshold = 0.5,
  verbose = TRUE
)
```

## Arguments

- chm:

  A `SpatRaster` of canopy heights in metres.

- forest_mask:

  A `SpatRaster` (logical / 0-1) or an `sf` polygon layer marking forest
  areas. Optional.

- buildings:

  An `sf` polygon layer of buildings. Optional.

- water:

  An `sf` polygon layer of water surfaces. Optional.

- ndvi:

  A `SpatRaster` of NDVI values aligned with `chm`. Optional.

- max_height:

  Numeric. Upper plausibility bound in metres (default `50`).

- slope:

  A `SpatRaster` of slope in degrees aligned with `chm`. Optional.

- ndvi_threshold:

  Numeric. Minimum NDVI to keep a pixel (default `0.2`). Beech/oak in
  summer sit at 0.7-0.9, but conifer plantations, shadowed pixels and
  edges commonly dip under 0.3, so the default was softened from 0.3 to
  0.2 to keep enough pixels on realistic stands.

- forest_coverage_threshold:

  Numeric in `[0, 1]`. When `forest_mask` is an `sf` layer, skip the
  forest-mask step if the mask covers less than this fraction of the CHM
  extent (default `0.5`). Avoids wiping 95 of pixels when BD Forêt
  simply does not map the area. Set to `0` to force the mask regardless
  of coverage.

- verbose:

  Logical. If `TRUE` (default), emit a
  [`cli::cli_alert_info`](https://cli.r-lib.org/reference/cli_alert.html)
  after every step with the cumulative fraction of masked pixels, which
  helps spot a single offending step.

## Value

A list with:

- chm_clean:

  `SpatRaster`. The masked CHM (same extent, resolution, and CRS as the
  input).

- pct_masked:

  Numeric in `[0, 1]`. Fraction of originally non-NA pixels that were
  masked out.

- steps_applied:

  Character vector. Names of the masks actually applied (`"forest"`,
  `"buildings"`, `"water"`, `"ndvi"`, `"range"`, `"slope"`).

## Details

Pipeline steps (in order):

1.  **Forest mask** (if `forest_mask` supplied): keep only pixels marked
    as forest (e.g. from BD Forêt v2 or OSO).

2.  **Buildings + water** (if `buildings` or `water` supplied): mask out
    pixels intersecting either layer.

3.  **NDVI threshold** (if `ndvi` supplied): keep only pixels where
    `ndvi >= ndvi_threshold`.

4.  **Plausible value range**: set to `NA` any pixel with `chm < 0` or
    `chm > max_height`.

5.  **Slope coherence** (if `slope` supplied): mask out pixels where
    `slope > 60` degrees (cliffs).

A warning is emitted if more than 50% of the originally valid pixels are
masked — this usually signals an alignment / resolution / vintage
problem between the CHM and the reference layers.

## Note

`sanitize_chm()` is idempotent and does not mutate the input raster. It
returns a new `SpatRaster`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Minimal: just apply the plausible range step
chm <- terra::rast(system.file("extdata/chm_demo.tif", package = "nemeton"))
out <- sanitize_chm(chm)
out$pct_masked

# Full pipeline with a forest mask and buildings/water vectors
out <- sanitize_chm(
  chm,
  forest_mask = bd_foret,
  buildings   = bd_topo_batiments,
  water       = bd_carthage,
  ndvi        = ndvi_rast,
  max_height  = 50
)
terra::plot(out$chm_clean)
} # }
```
