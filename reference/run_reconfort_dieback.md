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
  aoi_crop = TRUE,
  oso_national = NULL,
  number_of_chunks = 200L,
  scheduler_type = "localCluster",
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

  Integer, the **last** year of the two-year Sentinel-2 series – the
  single temporal control of a run (the app exposes only this, as a year
  picker). Default the current year. The download window, the analysis
  window and the output names all derive from it; see *Temporal window*
  below.

- date_from, date_to:

  Sentinel-2 **download** window (\`"YYYY-MM-DD"\`). \`NULL\` (default)
  derives a two-calendar-year window from \`s2_year\`: \`date_from =
  (s2_year-1)-01-01\`, \`date_to = s2_year-12-31\`. This only bounds
  what is fetched from Theia; IOTA2 then re-clips to the model's
  seasonal *analysis* window (\`S2_start\`/\`S2_end\`), so a custom
  download window cannot widen the analysis beyond what the pre-trained
  model expects. See *Temporal window*.

- v_model:

  RF model version (see
  [`RECONFORT_MODELS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_MODELS.md)).
  Default \`"v3"\` (oak, 2-year series).

- binary_mask:

  Broadleaf mask control. \`NULL\` (default) fetches and uses the OSO
  2021 deciduous mask; a path uses a custom mask; \`FALSE\` disables
  masking (continuous score from the raw probability map only). When
  \`aoi_crop = TRUE\` and \`binary_mask = NULL\`, the mask is cut from
  the national OSO (\`oso_national\`) for the AOI instead.

- aoi_crop:

  Logical. When \`TRUE\` (default) the Sentinel-2 scenes are streamed
  and clipped + reprojected to the zone AOI (+ buffer) in the output
  projection during ingestion (spec 021) — each archive is downloaded,
  extracted, cropped and deleted in turn: a multi-hour full-tile run
  becomes minutes, IOTA2's reference-grid handling is fixed, the
  broadleaf mask + ground truth are AOI-local, and peak disk stays near
  a single archive. All operations are per-pixel, so clipping does not
  change the result for the kept pixels.

- oso_national:

  Character or \`NULL\`. National OSO land-cover raster used to cut the
  AOI broadleaf mask (default \`\<global cache\>/oso/oso.tif\`,
  overridable via \`options(nemeton.reconfort_oso_national)\`).

- number_of_chunks:

  IOTA2 RAM-saving chunk count. Default \`200\`; when \`aoi_crop =
  TRUE\` it is derived from the cropped raster height (~240 rows per
  chunk, so 4 chunks for a 930x952 AOI). This is what caps peak memory:
  a single chunk materialises the whole multi-date feature stack at once
  and goes past 20 GB even on a small AOI (the R session was killed by
  systemd-oomd on 2026-07-13; 13.4 GB once chunked). Chunking requires
  an iota2 patched for defect \#11 (\`repair_iota2_env.sh\`) — without
  it, chunk 0 keeps an uncut region mask and OTB aborts; the run then
  falls back to a single chunk with a warning. An explicit value is
  respected.

- scheduler_type:

  IOTA2 scheduler. Default \`"localCluster"\`. IOTA2's \`Iota2.py\` only
  accepts \`debug\`, \`cluster\`, \`PBS\`, \`Slurm\`, \`localCluster\`
  (note the lower-case \`l\`) — \`"LocalCluster"\` 400s. When \`aoi_crop
  = TRUE\` the default is overridden to \`"debug"\`. Note this does NOT
  make the run sequential: IOTA2 spawns Dask \`distributed.worker\`s
  regardless (observed in the OTB classification logs on 2026-07-13,
  with the cfg reading \`debug\`). Memory is capped by
  \`number_of_chunks\`, not by this. An explicit non-default value is
  respected. PENDING : à revoir après alignement de la version d'iota2.

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

## Temporal window (`s2_year` -\> analysis dates)

RECONFORT does not diff two dates: it classifies a pixel's ~2-year index
trajectory with a pre-trained model. One run is driven entirely by
\`s2_year\` (the last year of the series). The dates flow as:

1.  **Download window** (this function): from \`s2_year\`, \`date_from =
    (s2_year-1)-01-01\` and \`date_to = s2_year-12-31\` unless
    overridden – two calendar years fetched from Theia.

2.  **Analysis window** (IOTA2 cfg, derived from \`s2_year\` +
    \`v_model\`, *not* from \`date_from\`/\`date_to\`): \`S2_start =
    (s2_year-1)\<sdate\>\`, \`S2_end = s2_year\<edate\>\` with
    \`sdate\`/\`edate\` fixed by the model –
    `v3`/`v3_chestnut`/`v3_pine`: \`0101\` -\> \`1029\` (Jan of
    \`s2_year-1\` to 29 Oct of \`s2_year\`, ~22 months, the "2y_nov"
    calibration); `v3_early_may`: \`0101\` -\> \`0531\` (~1.5 year).

3.  **Features**: IOTA2 gap-fills the cloud-masked S2 acquisitions of
    the analysis window onto a regular date grid, then computes CRswir +
    CRre per date. The per-pixel feature vector is the full two-year
    trajectory of both indices.

4.  **Classification**: the SharkRF \`v_model\` labels each pixel \`1
    healthy, 2 declining, 3 severely declining\` (2 classes for pine)
    plus a continuous score.

Because the analysis window is model-bound, a custom
\`date_from\`/\`date_to\` only changes *what is downloaded*, never the
window the model sees. To cover several years, call once per \`s2_year\`
(each run = a 2-year window ending end-October of its \`s2_year\`); the
app stacks the resulting yearly maps.
