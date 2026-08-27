# Compute spectral diversity rasters (alpha & beta) via biodivMapR

Runs the biodivMapR spectral-diversity pipeline on an optical
reflectance raster (typically a Sentinel-2 scene at NDP 0) and returns
the alpha (Shannon of spectral species) and beta (Bray-Curtis turnover)
diversity rasters. This is the shared primitive behind indicators **B4**
(alpha) and **L3** (beta); compute it once and pass the result to both
indicator functions to avoid running biodivMapR twice.

## Usage

``` r
compute_spectral_diversity(
  reflectance,
  mask = NULL,
  window_size = 10L,
  nb_cpu = 1L,
  output_dir = tempfile("biodivmapr_"),
  options = NULL,
  reuse_existing = TRUE
)
```

## Arguments

- reflectance:

  A `terra` `SpatRaster` of surface reflectance (one layer per spectral
  band) *or* a file path to such a raster. When a `SpatRaster` is given
  it is written to a temporary GeoTIFF, as biodivMapR operates on files.

- mask:

  Optional binary `SpatRaster` / file path masking the pixels to process
  (e.g. a forest / UGF mask). `NULL` (default) processes the full extent
  — crop `reflectance` to the AOI beforehand.

- window_size:

  Integer. Side (in pixels) of the square spatial unit over which
  diversity is computed (default `10L`, i.e. ~100 m at 10 m Sentinel-2).
  See spec 028 D2.

- nb_cpu:

  Integer. Number of CPU workers passed to biodivMapR (default `1L`).

- output_dir:

  Directory for biodivMapR outputs (default a fresh temporary
  directory).

- options:

  Optional named list forwarded to
  `biodivMapR::biodivMapR_full(options = )` (e.g. `nbclusters`,
  `alpha_metrics`). `NULL` (default) uses biodivMapR defaults — notably
  `nbclusters = 50` spectral species (spec 028 D2).

- reuse_existing:

  Logical. When `TRUE` (default) and `output_dir` already contains the
  diversity rasters from a prior run, reuse them instead of re-running
  the (expensive) biodivMapR pipeline. Pass a persistent `output_dir`
  (e.g. a project cache) to benefit; the default
  [`tempfile()`](https://rdrr.io/r/base/tempfile.html) directory never
  hits.

## Value

A list with:

- alpha:

  a `SpatRaster` of Shannon alpha diversity (or `NULL` if not produced),

- beta:

  a 3-layer `SpatRaster` holding the first three PCoA axes of the
  Bray-Curtis dissimilarity between windows — an ordination, not a
  scalar dissimilarity; see
  [`indicateur_l3_het_spectrale`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md)
  for how a per-unit value is derived from it (or `NULL`),

- output_dir:

  the directory holding the raw biodivMapR outputs.

- reused:

  `TRUE` if the rasters were loaded from a cached `output_dir` rather
  than recomputed.

## See also

[`indicateur_b4_div_spectrale`](https://pobsteta.github.io/nemeton/reference/indicateur_b4_div_spectrale.md),
[`indicateur_l3_het_spectrale`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md)
