# Run the RECONFORT broadleaf-dieback map production end-to-end

Orchestrates a full RECONFORT run for one monitoring zone: validate the
conda/IOTA2 environment, fetch the Random-Forest model
([`ensure_reconfort_model`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_model.md))
and the broadleaf mask
([`ensure_reconfort_oso_mask`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_oso_mask.md)),
resolve the AOI to Sentinel-2 MGRS tile(s)
([`reconfort_aoi_tiles`](https://pobsteta.github.io/nemeton/reference/reconfort_aoi_tiles.md)),
ingest the S2 archives
([`reconfort_ingest_s2`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)),
then drive the vendored IOTA2 map-production (sampling +
classification + OSO masking + continuous score). Produces the
classification, probability and continuous-score rasters (EPSG:2154)
plus a \`run_meta.json\`.

## Usage

``` r
run_reconfort_dieback(
  con,
  zone_id,
  cache_dir,
  s2_year = as.integer(format(Sys.Date(), "%Y")),
  date_from = NULL,
  date_to = NULL,
  v_model = "v3",
  binary_mask = NULL,
  number_of_chunks = 200L,
  scheduler_type = "LocalCluster",
  nb_parallel_tasks = 1L,
  output_dir = NULL,
  geodes_config = NULL,
  model_cache_dir = NULL,
  mask_cache_dir = NULL,
  tiles = NULL,
  skip_ingest = FALSE,
  keep_workdir = TRUE,
  quiet = FALSE,
  progress_callback = NULL
)
```

## Arguments

- con:

  A \`DBIConnection\` to the monitoring database.

- zone_id:

  Scalar monitoring-zone id (resolved to an AOI via the
  \`monitoring_zone\` table).

- cache_dir:

  Project cache root. The per-run working directory is created under
  \`\<cache_dir\>/reconfort/\` (same caller-supplied convention as
  FORDEAD's \`cache_dir\`).

- s2_year:

  Integer last year of the two-year S2 series. Default the current year.

- date_from, date_to:

  Download window (\`"YYYY-MM-DD"\`). Default a two-year window ending
  with \`s2_year\` (the IOTA2 cfg further clips to the model's seasonal
  dates).

- v_model:

  RF model version (see
  [`RECONFORT_MODELS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_MODELS.md)).
  Default \`"v3"\` (oak, 2-year series).

- binary_mask:

  Broadleaf mask control. \`NULL\` (default) fetches and uses the OSO
  2021 deciduous mask; a path uses a custom mask; \`FALSE\` disables
  masking (continuous score from the raw probability map only).

- number_of_chunks:

  IOTA2 RAM-saving chunk count. Default \`200\`.

- scheduler_type:

  IOTA2 scheduler (\`"LocalCluster"\` or \`"Slurm"\` on HPC). Default
  \`"LocalCluster"\`.

- nb_parallel_tasks:

  IOTA2 parallel-task count. Default \`1\`.

- output_dir:

  Explicit per-run working directory. Default
  \`\<cache_dir\>/reconfort/run_z\<zone_id\>\_S2\<s2_year\>\`.

- geodes_config:

  Path to \`pygeodes-config.json\` (see
  [`reconfort_ingest_s2`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)).
  Default resolves the option / user dir.

- model_cache_dir, mask_cache_dir:

  Override caches for the model / mask fetches. Default per-user nemeton
  caches.

- tiles:

  Explicit MGRS tile code(s); resolved from the zone AOI when \`NULL\`.

- skip_ingest:

  Reuse an already-ingested S2 layout under the working dir instead of
  downloading. Default \`FALSE\`.

- keep_workdir:

  Keep the staged working directory after the run. Default \`TRUE\` (the
  rasters live there).

- quiet:

  Suppress progress + subprocess output. Default \`FALSE\`.

- progress_callback:

  Optional function called with a named list at each phase (\`current =
  "reconfort:phase"\` / \`"reconfort:..."\`), for wiring into an app
  progress bar.

## Value

Invisibly, a list: \`status\`, \`zone_id\`, \`tiles\`, \`s2_year\`,
\`v_model\`, \`species\`, \`workdir\`, \`rasters\` (the collected output
paths), \`meta\` (path to \`run_meta.json\`) and \`elapsed_sec\`.

## Details

The downstream conversion of these rasters into \`alert\` rows (patch
centroids, \`confidence_class\`, \`stress_index\`) is lot L3 and is
**not** performed here.

**Heavy and opt-in.** A real run needs the \`nemeton-reconfort\` conda
environment, a GEODES account, tens of GB of Sentinel-2 and an OTB/Shark
batch execution. It is never exercised in CI; unit tests mock every
external step.
