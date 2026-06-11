# Persist the FORDEAD diagnostic bundle (spec 008 §14.3, L1)

Writes the curated model bundle a later \`read_fordead_pixel_series()\`
(L2, spec 008 §14.4) will consume: the 5-band harmonic coefficient
raster, the masked observed-CRSWIR stack, the first-anomaly date raster
and a \`run_meta.json\`. Best-effort by contract — the caller wraps this
in a \`tryCatch\` so a write failure warns but never aborts the FORDEAD
run.

## Usage

``` r
.write_fordead_model_bundle(
  output_dir,
  model_dir,
  first_anomaly = NULL,
  run_meta = list(),
  verbose = TRUE
)
```

## Arguments

- output_dir:

  Character(1). Root FordeadProcess output dir — the working set, source
  of \`fit/model.tif\` and the \`CRSWIR\` layers.

- model_dir:

  Character(1). Destination bundle directory, conventionally
  \`\<mask_cache_dir\>/zone\_\<id\>/model\_\<run_id\>/\`. Created (with
  parents) if absent.

- first_anomaly:

  A \`terra::SpatRaster\` of first-anomaly dates (days since epoch),
  typically the raster returned by \[.compute_first_dieback_date()\].
  May be \`NULL\` (then \`first_anomaly.tif\` is skipped).

- run_meta:

  A named list serialised verbatim to \`run_meta.json\`.

- verbose:

  Logical. Emit a \`cli\` line when the bundle is written.

## Value

\`model_dir\` (invisibly) on success; throws on failure.
