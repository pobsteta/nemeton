# RECONFORT layer manifest: describe a run's displayable outputs (L6)

Translates the result of
[`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
into a flat `data.frame` describing the map layers a RECONFORT run
exposes — the continuous dieback **score**, the per-pixel
**classification**, the **probability** map, and the **alert** centroids
— together with the rendering hints a viewer needs (palette, direction,
value domain, default visibility and opacity).

The semantics of a RECONFORT output (what a layer *is*, how its values
are scaled, which way the palette runs) are business knowledge and
therefore live in the `nemeton` core. A presentation layer (e.g.
`nemetonshiny`) consumes this manifest verbatim to build its layer
toggles and opacity control, without hard-coding any RECONFORT semantics
of its own (ADR-009, CLAUDE.md strict rules §1-3).

Only **available** layers are returned: a raster whose path is `NA` (the
masked variants only exist once masking ran) is skipped, and the alert
row appears only when the run produced at least one alert. For the
classification and probability layers the masked variant is preferred
and the raw one is used as a fallback.

Value domains are *nominal* by default (score `1..100`, probability
`0..1000`). Pass `include_range = TRUE` to replace them with the actual
min/max of the displayed band, computed by terra even when the GeoTIFF
stores no statistics (the IOTA² case; best-effort: a read failure or an
all-NA raster keeps the nominal domain).

The IOTA² probability map has **one band per class** in the order of
[`RECONFORT_CLASSES`](https://pobsteta.github.io/nemeton/reference/RECONFORT_CLASSES.md)
(healthy, dieback\[, severe\]), on a `0..1000` scale. Since v0.199.0 the
`probability` row describes **P(atteinte)**, the probability that the
pixel is affected: the sum of bands `2..n` (dieback + severe; dieback
alone for pine), `0..1000`, high = bad. It is derived once into a
single-band `p_atteinte_<source>.tif` next to the source (rebuilt when
the source is newer) and `path` points to it. A probability map clamped
at 255 (runs made before the iota2 \#12 repair, see
`inst/python/reconfort/repair_iota2_env.sh`) is reported once per
session: its continuous score is compressed too, the run must be re-run.

## Usage

``` r
reconfort_layer_manifest(result, include_range = FALSE)
```

## Arguments

- result:

  The list returned by
  [`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md).
  Only `result$rasters` (a named list of output paths, see
  [`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md))
  and, optionally, `result$alerts_sf` / `result$n_alerts` are read.

- include_range:

  If `TRUE`, override the nominal `vmin`/`vmax` of the continuous
  rasters with the actual min/max of their displayed band
  (`terra::minmax(compute = TRUE)`). Default `FALSE` (nominal domains).

## Value

A `data.frame` with one row per available layer and the columns:

- id:

  Stable layer key (`"score"`, `"classification"`, `"probability"`,
  `"alerts"`).

- label_key:

  i18n key (NMT convention) for the display label, resolved by the
  viewer.

- type:

  `"raster"` or `"vector"`.

- role:

  Semantic role, equal to `id` here but kept distinct so future variants
  (e.g. masked vs raw) can share a role.

- path:

  Raster file path, or `NA` for the vector layer.

- categorical:

  `TRUE` for the classification raster, `FALSE` for the continuous
  rasters, `NA` for the vector.

- palette:

  Suggested palette name for continuous rasters (`"RdYlGn"`,
  `"viridis"`), `NA` where the viewer should use the discrete
  [`RECONFORT_CLASSES`](https://pobsteta.github.io/nemeton/reference/RECONFORT_CLASSES.md)
  colours or its own marker style.

- reverse:

  Whether the palette runs high-to-low (the score is reversed so high =
  severe = red).

- vmin, vmax:

  Value domain for the colour scale (`NA` for the categorical and vector
  layers).

- default_visible:

  Whether the viewer should show the layer on first render (score and
  alerts on; the rest off).

- default_opacity:

  Suggested initial opacity in `0..1`.

- n_features:

  Alert feature count for the vector layer, `NA` for rasters.

When the run produced no displayable output the data.frame has zero rows
(the columns and their types are still present).

## See also

[`run_reconfort_dieback`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md),
[`RECONFORT_CLASSES`](https://pobsteta.github.io/nemeton/reference/RECONFORT_CLASSES.md)
