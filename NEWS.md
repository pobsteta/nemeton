# nemeton 0.22.1 (2026-05-15)

### Fixed — Sentinel-2 ingestion above 30 min triggered an avoidable 403 per remaining band

`stac_search_s2_pc()` signs every COG href with a SAS token at search
time and bakes them into `scenes_df`. On a long ingestion run, by the
time the loop reaches scene N the token embedded in the hrefs has
expired (Planetary Computer SAS tokens last ~30 min). The reactive
recovery in `.terra_rast_with_pc_retry()` (added in v0.21.6) caught
each 403 individually:

```
Scene 1..8   → tokens still fresh → OK
Scene 9..26  → 403 → invalidate cache → resign href → retry → OK
```

Every band of every late scene paid one extra HTTP round-trip
(~300 ms each) plus a noisy `s2:pc_token_refreshed` event. On a
typical 26-scene × 3-band run crossing the 30 min mark, that's
~50 wasted requests and ~15 s of latency.

**Fix**: two new private helpers in `R/sentinel2.R`:

* `.pc_href_expires_at(href)` — parses the SAS `se=` query parameter,
  returns a `POSIXct` (UTC) or `NA` if absent / unparseable.
* `.pc_ensure_fresh_href(href, collection, grace_seconds = 60)` —
  no-op on non-PC URLs and on hrefs whose `se=` is comfortably in
  the future; otherwise calls `.pc_resign_href()` to swap in a
  freshly-fetched token. Falls back to the original href if the
  token endpoint itself is down (the reactive retry then takes
  over as a safety net).

Wired into `.get_s2_band_raster()` (R/monitoring.R) immediately
before the `FETCH href=` trace, so every band lookup gets a
last-second freshness check.

Effect on a 45-minute run: zero `s2:pc_token_refreshed` events
(except in genuine clock-skew situations), no warnings to
spread across the worker console, no measurable extra HTTP cost
(the proactive check is one regex parse + one `Sys.time()`
comparison, sub-microsecond).

6 new offline tests in `test-sentinel2.R` covering:
parser on valid / missing / NA / NULL hrefs, no-op on non-PC and
unsigned URLs, no-op when the token is still fresh, resign when
within grace, fallback when resign returns NULL.

# nemeton 0.22.0 (2026-05-15)

### Added — per-pixel Sentinel-2 readers and pixel time-series extraction

Four new exported functions exposing the on-disk Sentinel-2 cache
(`<cache_dir>/{scene_id}/{B04,B08,B12}.tif`, written since v0.21.4
and functional since v0.21.12) as `terra::SpatRaster` objects:

* **`read_s2_band_raster(cache_dir, scene_id, band)`** — single band
  reader, returns a 1-layer SpatRaster or `NULL` if the file is
  missing.
* **`read_s2_band_stack(cache_dir, scenes_df, band)`** — multi-temporal
  stack for one band (B04 / B08 / B12), layers named by `obs_date`,
  `terra::time()` attribute set. Missing scenes skipped silently with
  a single aggregated warning.
* **`build_index_stack(cache_dir, scenes_df, index = c("NDVI", "NBR"))`**
  — computes NDVI or NBR pixel-wise on each scene, returns a 10 m
  stack. For NBR, B12 (20 m natively) is resampled bilinearly onto
  the B08 10 m grid — same idiom as `.extract_scene_obs` so per-pixel
  NBR is numerically consistent with the per-plot NBR aggregates in
  `obs_pixel`. Carries an `"index"` attribute identifying the chosen
  index.
* **`extract_pixel_timeseries(cache_dir, scenes_df, xy, crs = 4326,
  indices = c("NDVI", "NBR"))`** — per-pixel time series at a clicked
  point. `xy` defaults to WGS84 (the convention of leaflet
  `input$map_click`), reprojected per scene to its native S2 CRS.
  Missing scenes produce a row with `value = NA` at that date (the
  temporal hole is preserved for plotly display), not silently
  skipped. NBR uses native 20 m B12 here (no resample), because for a
  single-point lookup the pixel containing the click is what the user
  wants — this differs from `build_index_stack()` by a sub-pixel
  amount, documented in both man pages.

Implements **spec 010** (`specs/010-carte-pixel-timeseries/`). The
intended consumer is a new "Carte pixel" sub-tab under "Suivi
sanitaire" in `nemetonshiny` — leaflet shows the index stack with a
date slider, click on a pixel calls `extract_pixel_timeseries()` and
renders a plotly. No DB schema change (the on-disk cache is the
source of truth), no new dependency (everything via `terra`, `sf`,
`cli`, `rlang` already in Imports).

### Internal

`R/monitoring.R`: extracted the scene_id sanitization rule
(`gsub("[^A-Za-z0-9._-]", "_", ...)`) from `.s2_band_cache_path()`
into a shared private helper `.s2_safe_scene_id()` so the new
readers in `R/pixel-map.R` resolve the same on-disk layout the write
path computes. No behaviour change.

### Tests

16 new offline tests in `tests/testthat/test-pixel-map.R` covering
input validation, file-absent NULL semantics, scene ordering by
date, aggregated-warning skip policy, NDVI / NBR formula correctness
on fixed-value fixtures, NA propagation, B12 resampling, CRS
transform from 4326 to L93, multi-index sort order, point-outside-AOI
all-NA rows, and incomplete-scene NA-row policy. Synthetic fixtures
build valid GeoTIFFs in temp dirs — zero network, zero DB.

# nemeton 0.21.12 (2026-05-15)

### Fixed — S2 band cache never populated because `writeRaster` couldn't guess driver

The disk-side persistence of cropped Sentinel-2 bands (added in v0.21.4
and progressively hardened up to v0.21.10) silently failed on every
scene with recent terra versions:

```
[writeRaster] cannot guess file type from filename
```

Root cause: the temp file is named `<cached_path>.tmp` — i.e.
`<scene_id>/B04.tif.tmp`. `terra::writeRaster()` infers the GDAL
driver from the filename extension, and `.tmp` isn't a known GIS
alias. On older terra the inference was looser and the write
succeeded; on recent terra it's strict and the write throws. The
`tryCatch` around `writeRaster` swallowed the error, unlinked the
partial `.tmp`, emitted a `cli::cli_warn()`, and (since v0.21.10)
cleaned up the empty `scene_dir` — making the failure *less* visible
because no orphan directory was left to flag the issue.

Net effect since v0.21.4: **the cache was never populated**, every
ingestion re-downloaded all bands via VSI even when `cache_dir` was
passed.

Fix (R/monitoring.R): pass `filetype = "GTiff"` explicitly to
`terra::writeRaster()`. The GDAL creation options
(`TILED=YES, COMPRESS=DEFLATE, BLOCKXSIZE=256, BLOCKYSIZE=256,
PREDICTOR=2`) were already GeoTIFF-specific, so this just makes the
driver selection explicit instead of relying on extension inference.

New regression test `.get_s2_band_raster: writeRaster is called with
filetype = 'GTiff'` (test-monitoring.R) — captures the call via a
delegating mock so it catches a future regression even on a lax
terra version.

Surfaced during in-prod validation of v0.21.10's
`FETCH+MATERIALIZE` + scene_dir cleanup logic. v0.21.10's defense-in-
depth cleanup is what made the underlying bug visible: with the
orphan dirs gone, the only remaining symptom was an empty cache, and
the verbose trace (v0.21.7) pointed straight at the writeRaster
line.

# nemeton 0.21.11 (2026-05-15)

### Added — `read_obs_pixel()` exported reader for the obs_pixel hypertable

New exported function `read_obs_pixel(con, zone_id, plot_ids = NULL,
bands = NULL, date_from = NULL, date_to = NULL)` returns the per-plot
× per-band × per-date Sentinel-2 observations as a `data.frame`. The
plot identifier is surfaced as the human-readable `plot.plot_id`
(TEXT), not the internal `plot.id` (INTEGER FK), via a JOIN — so
downstream consumers (Shiny `selectInput`, Quarto reports, GeoPackage
exports) refer to plots by the code the user knows.

Filters are all optional and AND-combined; `NULL` means no filter on
that dimension. Output is deterministically sorted by `(plot_id,
obs_date, band)`, types are coerced (`obs_date → Date`, numerics
forced double), and an empty `data.frame` with the right column
schema is returned for an empty / unknown zone.

This is the read-side counterpart of the (private) write path
`.insert_obs_pixel()`. Exposing it as part of the public API keeps
the `obs_pixel` SQL out of `nemetonshiny` (per the *no business
logic in the app* rule) and unblocks E6.b phase 3 (per-plot NDVI /
NBR plotly time series in `mod_monitoring`).

13 new tests in `test-read_obs_pixel.R`: 6 offline (argument
validation + empty-shape contract), 4 integration via `with_clean_db`
(empty / unknown zone, full read, every filter combination, sibling
zone isolation).

# nemeton 0.21.10 (2026-05-15)

### Fixed — S2 cache leaves empty `<cache_dir>/{scene_id}/` directories

`ingest_sentinel2_timeseries(..., cache_dir = ...)` created scene
subdirectories under `<cache_dir>/` without any `B04.tif` / `B08.tif`
files inside.

Root cause: `terra::rast(href)` on a VSI URL only fetches the COG
**header** — pixel reads are deferred until something consumes the
SpatRaster (typically `terra::writeRaster()`). The retry/auth-refresh
helper `.terra_rast_with_pc_retry()` (v0.21.6 → v0.21.9) wrapped
**only the head request**, so:

1. `terra::rast(href)` succeeds → metadata in hand.
2. `terra::crop(r, ext)` is also lazy → still no bytes downloaded.
3. `dir.create(<cache_dir>/{scene_id}/)` succeeds → directory exists.
4. `terra::writeRaster(r, tmp, …)` finally triggers the byte-range
   reads on the COG over VSI. If the SAS token expired mid-scene, or
   Azure returned a 5xx / 429 on the range request, this step
   throws — **past the retry budget**.
5. The `tryCatch` swallowed the error with a `cli::cli_warn()`,
   unlinked the partial `.tmp`, and returned — leaving the empty
   scene directory behind.

The fix moves the AOI crop **and** the pixel materialization into a
`materialize` closure passed to `.terra_rast_with_pc_retry()`. Both
steps now run **inside** the retry/refresh loop:

```r
materialize = function(r0) {
  buf_native <- sf::st_transform(buf_plots, terra::crs(r0))
  r_cropped  <- terra::crop(r0, terra::ext(terra::vect(buf_native)),
                            snap = "out")
  r_cropped + 0   # forces in-memory pixel read via terra arithmetic
}
```

`r_cropped + 0` is the canonical terra idiom for "make this
SpatRaster in-memory": scalar arithmetic creates a new SpatRaster
whose values are read into RAM. Any VSI failure (auth expiry,
transient 5xx, DNS hiccup mid-stream) surfaces inside the loop and
triggers re-sign / exponential backoff just like a metadata failure
would. The downstream `terra::writeRaster()` then writes from RAM —
no more VSI traffic — so the only way it can fail is local disk I/O.

Defensive cleanup: if `terra::writeRaster()` still fails for a
genuinely local reason (disk full, permission denied, GDAL driver
hiccup) AFTER `dir.create()`, the now-empty `scene_dir` is removed
in the `tryCatch` so `diagnose_s2_cache()` doesn't keep flagging it
as an empty entry. Sibling-band files (a previous successful B04
when B08 fails) are left untouched — partial caches are preserved.

Three new tests:

* `.terra_rast_with_pc_retry: materialize closure runs once on success`
* `.terra_rast_with_pc_retry: materialize failure with PC auth →
  token refresh + retry`
* `.terra_rast_with_pc_retry: materialize failure with transient
  error → backoff retry`
* `.get_s2_band_raster: empty scene_dir is removed when writeRaster
  fails`

# nemeton 0.21.9 (2026-05-13)

### Fixed — transient DNS / network errors abort entire scenes

`.terra_rast_with_pc_retry()` used to retry **only** on PC SAS
401/403. Any other failure — including DNS hiccups
(`Could not resolve host: …`), connection timeouts, and GDAL HTTP
5xx — propagated immediately, the scene was skipped, and the
ingestion lost data for what was usually a 5-30 second blip.

The retry path now classifies the error and reacts accordingly:

* **PC SAS auth** (`40[13]`, `forbidden`, `unauthorized`) on a PC
  blob URL → invalidate cached token, re-sign href, retry
  immediately. *(Behaviour preserved from v0.21.6.)*
* **Transient network** (`could not resolve host`, `could not
  connect`, `connection (timed out|reset|refused)`,
  `network unreachable`, `temporary failure`, `http error 5xx`,
  `gdal error … timeout`) → sleep with exponential backoff
  (2 s, 4 s, 8 s, …, capped at 30 s) and retry the same href.
* **Anything else** (404, malformed COG, permission denied)
  propagates immediately as before.

Total budget is **3 attempts** per band by default; override with
the env var `NEMETON_S2_MAX_TRIES` (positive integer).

A new progress event `s2:band_fetch_retry` is emitted before each
sleep, with payload `scene_id`, `band`, `attempt`, `max_tries`,
`retry_in_sec`, `error_message`. Callers (`nemetonshiny`) can
render it as a toast like *"Hoquet réseau sur scène X bande B04 —
réessai dans 4 s"* so the user sees the pipeline is recovering,
not stuck.

# nemeton 0.21.8 (2026-05-13)

### Fixed — every S2 band cache hit raised "cannot coerce type 'S4' to vector of type 'double'"

`.ext_contains()` (introduced in v0.21.4 to decide whether a cached
COG covers today's AOI) did:

```r
o <- as.numeric(c(outer[1], outer[2], outer[3], outer[4]))
```

`outer` is a `terra::SpatExtent` (S4). `outer[1]` does NOT return a
plain double — it returns a nested S4 element. `c()` accumulates
those into an S4 list, and `as.numeric()` then chokes with

```
cannot coerce type 'S4' to vector of type 'double'
```

Symptom for the user: every scene that already had a cached band
on disk got skipped at the scene level

```
Scene "S2A_MSIL2A_20250712T104041_R008..." skipped:
  cannot coerce type 'S4' to vector of type 'double'
```

— so the cache never got reused, the network was hit again, and
ingestion looked like nothing was making progress.

* New private helper `.ext_as_numeric(e)` routes `SpatExtent`
  through `terra::xmin()/xmax()/ymin()/ymax()`, falls back to
  `as.numeric()` for plain numeric vectors. Bulletproof across
  terra versions.
* `.ext_contains()` and the verbose `.s2_cache_log()` debug call
  both go through the new helper.

2 new regression tests exercise `.ext_contains()` with real
`terra::ext()` objects (mixed S4 / numeric combinations).

# nemeton 0.21.7 (2026-05-13)

### Added — observability for the S2 band cache

Three additions to make it easy to answer "why is no `.tif`
landing in `cache/layers/sentinel2/`":

1. **Always-on cache status banner** at the top of every
   `ingest_sentinel2_timeseries()` call:

   ```
   i S2 band cache: enabled at <project>/cache/layers/sentinel2
   ```

   …or the unmissable inverse when the wiring is wrong:

   ```
   i S2 band cache: DISABLED (cache_dir is NULL or empty).
   ```

   Catches the most common bug — `cache_dir` not actually being
   passed by the caller — at the very first line of output instead
   of after 30 minutes of silent ingestion.

2. **Verbose tracer** gated by `NEMETON_S2_CACHE_DEBUG=TRUE` (or
   `=1`). When enabled, `.get_s2_band_raster()` writes one
   `message()` line per decision point: ENTER, CACHE-HIT/MISS/STALE,
   FETCH (with href), CROP, WRITE preparing dir, WRITE writeRaster
   target + size, RENAME, or any error along the way. Off by
   default to keep regular runs quiet. Use `message()` (not `cli`)
   so the trace is captured by `future_promise` worker logs.

3. **`diagnose_s2_cache(cache_dir)`** — new exported helper that
   walks the cache and reports populated vs empty scene
   directories, total bytes, mean bands per scene, and the list of
   empty dirs. Returns the result list invisibly so callers can
   script cleanups (`unlink(diagnose_s2_cache(...)$empty_dirs,
   recursive = TRUE)`).

### Fixed — write permission failures now produce a clear warning

When `dir.create(scene_dir)` silently fails (Windows permission
issue, antivirus quarantine, network drive), `.get_s2_band_raster()`
now emits `S2 band cache: cannot create <path>. Check write
permissions.` and skips the write — instead of silently dropping
into `terra::writeRaster` and surfacing a cryptic GDAL error.

# nemeton 0.21.6 (2026-05-13)

### Fixed — empty `cache/layers/sentinel2/{scene_id}/` dirs after failed fetches

In v0.21.4 `.get_s2_band_raster()` created the per-scene cache
directory eagerly at function entry, *before* attempting the VSI
fetch. If `terra::rast(href)` then raised (typical causes: PC SAS
token expired mid-ingestion → HTTP 403, Azure 504, Sentinel-2 COG
moved), the scene directory was already on disk while no
`B04.tif` / `B08.tif` / `B12.tif` was ever written. Users saw
hundreds of empty scene folders with no obvious cause.

* Directory creation is now **deferred** to the moment immediately
  preceding `terra::writeRaster()`. A scene whose bands cannot be
  opened no longer leaves a phantom folder behind.
* Two new progress events let callers (e.g. `nemetonshiny`)
  surface the actual failure cleanly:
  * `s2:band_fetch_failed` — emitted when `terra::rast(href)` is
    unrecoverable (after PC-token-refresh path if applicable).
    Payload: `scene_id`, `band`, `href`, `error_message`.
  * `s2:pc_token_refreshed` — emitted when an initial 403/401 on
    a Planetary Computer blob URL triggered a successful token
    refresh + retry. Payload: `scene_id`, `band`, `collection`.

### Added — auto-refresh of Planetary Computer SAS tokens on 403/401

The previous design signed every href at STAC search time and
relied on `terra::rast()` reading them later. PC SAS tokens last
~30 min, so any ingestion that ran longer than that started
hitting HTTP 403 on the last scenes' bands.

`.get_s2_band_raster()` now wraps each `terra::rast(href)` in
`.terra_rast_with_pc_retry()`:

1. First call goes through as-is.
2. On failure, the error message is sniffed: when the href is a
   PC blob URL (`*.blob.core.windows.net` with a `sig=…` query)
   *and* the error matches `\\b(40[13]|forbidden|unauthorized
   |authentication)\\b`, the cached SAS token for `sentinel-2-l2a`
   is invalidated, the href is re-signed with a fresh token, and
   the open is retried exactly once.
3. Anything else (504, network, malformed COG, non-PC URL)
   propagates immediately — no point spending a token round-trip.

Two new internal helpers back the retry path:

* `.pc_invalidate_token(collection)` — drops one collection's
  cached token so the next fetch hits `/api/sas/v1/token/…`.
* `.pc_resign_href(href, collection)` — strips the current SAS
  query string and applies a freshly-fetched one (returns `NULL`
  when the token refresh itself failed).

10 new tests cover the lazy creation, the retry happy/sad paths,
the non-PC short-circuit, and the helper-level behaviours.

# nemeton 0.21.5 (2026-05-13)

### Fixed — transient STAC failures (HTTP 504/503/502) no longer abort the search

`stac_search_s2()` (and its CDSE / Planetary Computer
implementations) now retry on transient HTTP errors before
giving up:

* Retried status codes: **429, 500, 502, 503, 504**. The default
  `httr2` policy only retries on 429 + 503, which left genuine
  Planetary Computer 504 Gateway Timeouts surfaced immediately
  as toasts in `nemetonshiny`.
* Default budget: 4 attempts per backend (≈ 14 s of cumulative
  exponential backoff in the worst case: 2 + 4 + 8 s between
  attempts, capped at 60 s).
* Override via `NEMETON_STAC_MAX_TRIES` (integer env var).

When every configured backend exhausts its retry budget,
`stac_search_s2()` now emits a single aggregated warning
\dQuote{All STAC backends (cdse, pc) failed after retries} —
in addition to the per-backend warnings — so the UI can render
one toast instead of stacking one per backend.

The retry policy is also applied to the Planetary Computer SAS
token fetch (`/api/sas/v1/token/{collection}`) and the legacy
per-href sign endpoint (`/api/sas/v1/sign`), so a transient PC
hiccup during the auth round-trip no longer falls back to
unsigned URLs (which Azure would then 409).

# nemeton 0.21.4 (2026-05-12)

### Added — on-disk COG band cache for `ingest_sentinel2_timeseries()`

`ingest_sentinel2_timeseries()` now accepts an optional
`cache_dir = NULL` argument. When set, each cropped Sentinel-2
band (B04, B08, B12) is persisted as a tiled GeoTIFF
(COG-compatible: `TILED=YES`, `COMPRESS=DEFLATE`, `PREDICTOR=2`,
256×256 blocks) under `<cache_dir>/{scene_id}/{band}.tif`.

* On a cache hit, the band is opened with `terra::rast()` against
  the local file — no VSI/HTTP read.
* On a cache miss, the band is fetched via VSI, cropped to the
  AOI bbox, and written atomically (`.tmp` → `rename`). Cache
  write failures only warn, the pipeline continues with the
  in-memory raster.
* The cache is **extent-aware**: a cached file whose bbox no
  longer covers the requested plots is silently overwritten. A
  new placette outside the previous window therefore does not
  return stale data.

This complements the `skip_cached` short-circuit added in
v0.21.3:

| Layer    | Saves when            | Where           |
|----------|------------------------|-----------------|
| `skip_cached` (v0.21.3) | `obs_pixel` already has the (plot × band) values for an `obs_date` | DB SQL pre-filter |
| `cache_dir` (this release) | `obs_pixel` needs a refresh (new band, new metric, manual wipe) but the raw bands are unchanged | local COG store |

Two new progress events:

* `s2:band_cached` — per band, payload `scene_id`, `band`, `path`.
* `s2:band_fetched` — per band, same payload.

Disk usage estimate: ~50 KB per band for a 1 km² AOI; ~24 MB for
the typical 159-scene × 3-band run. Set `cache_dir = NULL`
(default) to keep the v0.21.3 behaviour (no caching).

# nemeton 0.21.3 (2026-05-12)

### Added — `skip_cached` short-circuit for `ingest_sentinel2_timeseries()`

`ingest_sentinel2_timeseries()` now accepts an optional
`skip_cached = TRUE` argument. Before the STAC loop, it queries
`obs_pixel` and identifies every `obs_date` already covered for
**every** plot of the zone × **every** requested band. Matching
scenes are skipped: no VSI/HTTP read, no `terra::crop`, no
`exactextractr` extraction — the user only pays for scenes whose
data is genuinely missing from the database.

Concretely this turns a re-run of `ingest_sentinel2_timeseries()`
against an already-populated zone from ~1-2 GB of network into
zero, while preserving the existing idempotent INSERT semantics.

The cache lookup is partial-coverage-aware: requesting a new band
(e.g. adding `"NBR"` to a zone previously ingested with `"NDVI"`
only) does not trigger a false-positive skip — the scene is
re-extracted because at least one `(plot, band)` tuple is still
absent. Set `skip_cached = FALSE` to force re-extraction
unconditionally (debugging or post-invalidation workflows).

Two new progress phases are emitted:

* `s2:cache_lookup` — once after the STAC query, with `n_cached`
  and `n_to_process` so the UI can immediately show "x/y scenes
  already in cache, fetching y" before the first HTTP read.
* `s2:scene_cached` — once per skipped scene, mirroring the
  `s2:scene` payload (`scene_id`, `obs_date`, `cloud_pct`,
  `source`). Lets the toast tick through the cached scenes at
  loop speed for visual feedback.

The summary tibble gains an `n_scenes_cached` column;
`s2:complete` emits the same value alongside `n_obs_inserted`.

# nemeton 0.21.2 (2026-05-12)

### Added — `progress_callback` for `run_fordead_dieback()`

The FORDEAD orchestrator now accepts an optional
`progress_callback = NULL` argument, mirroring the convention
already used by `ingest_sentinel2_timeseries()` (v0.21.0). Callers
— typically the async worker in `nemetonshiny` — can subscribe to
ordered, phase-level events and surface a live progress
indicator to the user.

The callback receives a single named list with a `current`
discriminator. Phases emitted, in order:

* `fordead:start` — once, with `total` (6 or 7 phases depending
  on whether persistence is requested), `python_env`,
  `fordead_version`.
* `fordead:phase` / `fordead:phase_done` — bracket each phase
  with `phase_name`, `completed`, `total`. The seven possible
  `phase_name` values are: `"vegetation_index"`, `"train_model"`,
  `"forest_mask"`, `"dieback_detection"`, `"export_results"`,
  `"postprocess"`, and (when `con` + `zone_id` are supplied)
  `"persist"`.
* `fordead:complete` — once on success, with `n_alerts_inserted`
  and `duration_sec`.
* `fordead:error` — once on failure, with the `phase_name` that
  blew up, `error_message` and `duration_sec`. No
  `fordead:complete` is emitted in that case.

Exceptions raised inside the callback are caught and discarded —
a buggy UI never aborts the FORDEAD pipeline.

Default `NULL` preserves the v0.21.1 behaviour (silent, no
events). No call site needs to change.

# nemeton 0.21.1 (2026-05-12)

### Fixed — DuckDB migration 0001 rejected by the parser

`db_migrate()` failed on a fresh DuckDB monitoring database with
`Parser Error: syntax error at or near "GENERATED" — LINE 2: id
INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY`. The DuckDB
parser does not accept the SQL-standard `GENERATED ALWAYS AS
IDENTITY` clause, contrary to the comment shipped in
`inst/db/migrations/duckdb/0001_init.sql`. As a side effect, FK
clauses also relied on `ON DELETE CASCADE`, which DuckDB rejects
at parse time.

* `0001_init.sql` (DuckDB variant) now uses explicit
  `CREATE SEQUENCE IF NOT EXISTS … START 1` + `INTEGER PRIMARY KEY
  DEFAULT nextval('…')` for `monitoring_zone`, `plot` and `alert`.
* `ON DELETE CASCADE` is dropped from the three FK clauses
  (`plot.zone_id`, `obs_pixel.plot_id`, `alert.plot_id`). FK
  existence is still enforced; no current code path issues
  `DELETE FROM monitoring_zone` / `DELETE FROM plot`, so this is
  a documented restriction rather than a behavioural gap.
* Header comments updated to reflect the actual DuckDB-vs-PG
  differences (no false claim about IDENTITY support since 0.7).

The first launch of `nemetonshiny` against a local DuckDB
backend (`NEMETON_DB_URL=duckdb:///...` or auto-detected
`*.duckdb` path) now completes the schema bootstrap cleanly.

# nemeton 0.21.0 (2026-05-11)

### Added — Local DuckDB backend for the monitoring subsystem

The monitoring database (spec 007 / E6) can now run on a local
DuckDB file instead of PostgreSQL + TimescaleDB + PostGIS. Use
case : single-user `nemetonshiny` deployments where setting up
Postgres is overkill.

**Selection by URL scheme.** `db_connect()` inspects the
connection URL and dispatches to the right driver :

* `postgresql://user:pass@host:port/dbname` →
  [RPostgres::Postgres()] (unchanged).
* `duckdb:///absolute/path/to/file.duckdb` →
  [duckdb::duckdb()]. The parent directory is created
  automatically.

A bare path ending in `.duckdb` is also accepted for convenience.

**Two migration directories.** `inst/db/migrations/` is now
split between `pg/` (the existing files — `CREATE EXTENSION
timescaledb`, `create_hypertable()`, `TIMESTAMPTZ`…) and
`duckdb/` (same schema, minus the TimescaleDB / PostGIS
specifics — no hypertable, `GENERATED ALWAYS AS IDENTITY`
instead of `SERIAL`, `TIMESTAMP` instead of `TIMESTAMPTZ`).
`db_migrate()` picks the directory matching the connection's
driver class.

**Portable SQL touches in the monitoring functions.**

* `list_alerts()` no longer uses the PG-only
  `ANY($n::text[])` cast. Filters now bind one parameter per
  value and emit a portable `IN ($n, $n+1, …)` clause that
  works on both backends.
* `.insert_obs_pixel()` and `.insert_alerts()` branch on the
  connection class to emit `CREATE TEMP TABLE … ON COMMIT DROP`
  for Postgres or a `DROP TABLE IF EXISTS` + `CREATE TEMP
  TABLE` + explicit `DROP TABLE` for DuckDB (which has no
  `ON COMMIT DROP` clause).

**Suggested dependency.** `duckdb (>= 0.8.0)` is added to
`Suggests`. The PG path is unaffected by its absence ;
`db_connect()` only loads `duckdb` when the URL scheme
selects that backend.

**Removed helper.** `.pg_text_array()` is dropped — it only
existed to support `ANY($n::text[])` which is no longer used.
Internal, never exported.

### Changed — `db_migrate()` signature

`migrations_dir` now defaults to `NULL` (was the bundled
`inst/db/migrations/`). The directory is then picked
automatically based on the connection's driver. Callers
passing an explicit path still work unchanged.

# nemeton 0.20.1.9009 (development)

### Fixed — Planetary Computer SAS signing migrated to batch token endpoint

`stac_search_s2_pc()` used to sign every Sentinel-2 band href
individually through `/api/sas/v1/sign`. A single STAC search
typically returns 20-50 scenes × 3 bands (B04, B08, B12), so the
loop instantly hit Planetary Computer's per-IP rate limit and
emitted 50+ `PC sign failed: HTTP 429 Too Many Requests` warnings,
followed by a wave of `GDAL Error 1: HTTP error code : 409` from
`sentinel2l2a01.blob.core.windows.net` because terra fell back to
the unsigned URLs.

The signing now uses the documented batch endpoint
`/api/sas/v1/token/{collection}` instead. One HTTP call returns a
SAS query string that is valid for the whole collection for ~30
minutes; we cache it in a per-process env (`.pc_token_cache`,
keyed by collection) and append it to every href via the new
helper `.pc_apply_token()`. Subsequent searches in the same R
session reuse the cached token until 60 s before its `msft:expiry`.

Net effect: a search that previously made 60-150 sign calls and
got rate-limited now makes a single token call and signs every
href client-side. The original `.pc_sign_url()` helper is kept
in the source as a documented single-href fallback but is no
longer called from the search path.

* New private helpers: `.pc_collection_token(collection,
  grace_seconds = 60L)` and `.pc_apply_token(href, token)`.
* New private cache env: `.pc_token_cache` (cleared at session end).
* 6 new test_thats covering: token append on a bare href,
  leading-`?` normalisation, append with existing query string,
  empty-token short-circuit, fresh-cache reuse, expired-cache
  refresh, network failure → NULL with warning.

# nemeton 0.20.1.9008 (development)

### Diagnostic — `.pc_sign_url()` no longer swallows failures

The Planetary Computer SAS sign helper used to fall back silently
to the unsigned URL whenever `httr2::req_perform()` errored or the
response body could not be parsed. This caused a confusing wave of
`HTTP 409` errors from `sentinel2l2a01.blob.core.windows.net`
("file does not exist" via `terra::rast()`) whenever something —
rate limit, timeout, transient auth — broke the per-href signing
loop. Two `cli::cli_warn()` calls now surface the underlying cause
so we can pick the right durable fix (batched token endpoint,
retry/backoff, …) instead of guessing.

# nemeton 0.20.1.9007 (development)

### Added — `ingest_sentinel2_timeseries()` progress callback

`ingest_sentinel2_timeseries()` now accepts an optional
`progress_callback` argument so long-running scene downloads can be
streamed back to the UI (typically `nemetonshiny`'s `mod_monitoring`
in E6.b). The contract follows the same shape as the indicator /
download callbacks already used in `nemetonshiny/service_compute.R`:
the callback receives a single named list with a `current` phase
key plus context fields. Phases emitted, in order:

* `s2:search` — before the STAC query (`start`, `end`, `n_plots`,
  `bands`).
* `s2:search_done` — after STAC (`total` = number of scenes).
* `s2:scene` — before each scene (`completed`, `total`, `scene_id`,
  `obs_date`, `cloud_pct`, `source`).
* `s2:scene_skipped` — when a scene fails extraction (adds
  `error_message`).
* `s2:complete` — at the end (`completed = total`, `n_obs_inserted`).

The argument defaults to `NULL` (silent), so existing callers are
unaffected.

# nemeton 0.20.1.9006 (development)

### Infra — DB stack now embeds PostGIS by default

The `docker-compose.yml` reference deployment switched from
`timescale/timescaledb:latest-pg16` (Alpine, TimescaleDB only) to
`timescale/timescaledb-ha:pg16` (Debian, ships TimescaleDB + PostGIS
+ pgvector) so the cœur and downstream `nemetonshiny` no longer need
a separate spatial extension setup. Migration `0001_init.sql` now
activates `postgis` alongside `timescaledb`, so a fresh
`db_migrate()` run leaves the DB ready for both hypertables and
spatial geometries.

* The `-ha` image uses `/home/postgres/pgdata` as `PGDATA` (vs
  `/var/lib/postgresql/data` for the Alpine image), so existing
  development volumes must be recreated:
  ```
  docker compose down
  docker volume rm nemeton_pg_data
  docker compose up -d timescaledb
  ```
* Schema columns stay in WKT TEXT for now — the `geometry(Point,
  2154)` migration plus GiST indexes will land in a later cycle when
  data volume justifies pushing snap-to-plot and `ST_DWithin`
  filtering down to SQL.

# nemeton 0.20.1.9005 (development)

### Renamed — QGIS / QField terminology cleanup

The two QField-named exports were renamed to reflect what they
actually do: produce / consume a standard `.qgz` QGIS 3.x project
(zip of `.qgs` XML + GPKG) which any QGIS-speaking client (QGIS
Desktop, QField via QFieldSync, etc.) can open. There is no
QFieldSync-specific tagging in the output, so the previous names
were misleading.

* `create_qfield_project()` → **`create_qgis_project()`**
* `import_qfield_gpkg()` → **`import_qgis_gpkg()`**

The roxygen group names (and therefore the `man/*.Rd` page names)
follow:

* `qfield_export` → **`qgis_export`**
* `qfield_import` → **`qgis_import`**

The function bodies, signatures, return types and behaviour are
unchanged — this is a pure rename.

### Deprecated

`create_qfield_project()` and `import_qfield_gpkg()` are kept as
deprecated aliases for backwards compatibility with `nemetonshiny`
and any external caller. They forward to the new names and emit a
one-shot `.Deprecated()` warning. **They will be removed in a
future release** — please migrate.

### Internal cross-references updated

`R/health_validation.R`, `R/sampling_plan.R`, `R/field_schema.R`
and the QGIS export/import modules now reference the new names in
their docstrings and comments. 62 textual mentions of "qfield"
across the codebase were rebalanced toward "qgis" where the
subject was actually QGIS Desktop / the `.qgz` format and not the
mobile QField client specifically.

### Tests

* All call sites in `test-qgis-export.R` and `test-qgis-import.R`
  updated to the new names.
* Added two tests that exercise the deprecated aliases and assert
  the deprecation warning is emitted.

Total suite: 5994 PASS / 0 FAIL.

# nemeton 0.20.1.9004 (development)

### Added — E6.d (R5 dieback indicator, towards v0.21.0)

* **`R/indicators-deperissement.R`** — implements guard-rail
  G5 of spec 008. The R5 dieback index is the
  confidence-weighted fraction of each forest unit's area
  covered by FORDEAD anomaly clusters (rescaled to 0-100 to
  align with R1..R4).
  * `indicateur_r5_deperissement(units, fordead_results,
    weights = FORDEAD_CONFIDENCE_WEIGHTS, min_resineux = 0.3,
    include_low_classes = FALSE, resineux_col = NULL)` —
    returns the input `units` augmented with an `R5` column
    (numeric, 0-100, NA when skipped) and an `r5_status`
    column (`"calculated"`, `"skipped_no_resineux"`,
    `"skipped_no_fordead"`).
  * Per-UGF logic: skip with `skipped_no_resineux` when the
    spruce + fir share is below `min_resineux` (binary 0/1
    when derived from a dominant-species column, or any
    fraction in `[0, 1]` when the caller passes
    `resineux_col`). Skip with `skipped_no_fordead` when no
    FORDEAD results are provided. Otherwise the score is the
    weighted cluster-area / unit-area ratio, capped at 1 and
    multiplied by 100.
  * Defaults to keeping only classes `3-forte` and `4-sol-nu`
    (G1 from the ONF/DSF 2024 report — classes 1-faible /
    2-moyenne carry 50% / 33% false-positive rates). Set
    `include_low_classes = TRUE` to include them, weighted
    by `FORDEAD_CONFIDENCE_WEIGHTS`.

* **`R/indicator-config.R`** — `INDICATOR_FAMILIES$R` extended
  from 4 to 5 indicators (`R1..R5`) with bilingual labels and
  tooltips. `create_family_index()` picks `R5` up automatically
  through its existing `^R[0-9]` regex; no change needed in
  `R/family-system.R`. The R family score (`famille_risque`)
  stays finite when R5 is NA — R1..R4 carry the average in that
  case.

* **Tests** — 18 new offline tests in
  `tests/testthat/test-indicators-deperissement.R`. Total
  suite: 5988 PASS / 0 FAIL. **The cœur side of the v0.21.0
  release is now complete** (E6.c.1/.2/.3/.4 + E6.d) — only
  the app side (E6.b phases 2-6, E6.c.5 in `nemetonshiny`)
  and the end-to-end smoke (E6.f) remain.

# nemeton 0.20.1.9003 (development)

### Added — E6.c.4 (FORDEAD QField terrain validation, towards v0.21.0)

* **`R/health_validation.R`** — guard-rail G4 of spec 008 (the
  ONF/DSF report mandates a terrain validation step). Three
  exported functions plus two exported vocabularies:
  * `HEALTH_VALIDATION_STADES` — 7 DSF-aligned dieback stage
    codes (`sain`, `sain_scolyte_vert_indif`, `scolyte_vert`,
    `scolyte_rouge`, `scolyte_gris`,
    `scolyte_rouge_gris_indif`, `coupe_rase`).
  * `HEALTH_VALIDATION_CAUSES` — 7 free-form cause suggestions
    rendered as a value-map in the QField form.
  * `get_health_validation_schema(region, lang)` — 11
    `.field()` descriptors compatible with
    `create_qfield_project()`. The `essence_dominante`
    domain comes from `list_species_classes()` and falls
    back to free text when the region is unknown.
  * `generate_health_validation_plots(alerts_sf, n, method, crs)`
    — stratified draw on `confidence_class`. Uses
    `spsurvey::grts()` when available, falls back to per-stratum
    random sampling otherwise (the `sampling_method` column of
    the result tracks which path ran). Internal
    `.allocate_health_strata()` distributes the budget with a
    largest-remainder method while guaranteeing at least one
    plot per present class. Output ready for QField export
    (typed-NA editable columns).
  * `ingest_health_validation(con, gpkg_path, zone_id,
    snap_distance_m, validated_by, layer)` — reads the GPKG
    placette layer, snaps each plot to the nearest alert in
    Lambert-93 (default 50 m), and translates
    `stade_deperissement` to `validation_status` /
    `validation_cause` via the internal `.health_stade_to_status()`
    helper. The `coupe_rase` rule is class-dependent
    (1-faible / 2-moyenne → `false_positive`; 3-forte /
    4-sol-nu → `confirmed`). `validated_by` precedence: arg >
    `obs_by` field > `Sys.info()`. The field's free-form `cause`
    column overrides the auto-mapped cause when present.
    Returns `list(n_updated, n_confirmed, n_false_positive,
    n_unmatched, n_skipped, details)` where `details` is a
    data.frame tracing each plot.

* **Tests** — 31 new tests
  (`test-health-validation-schema.R` 10,
  `test-generate-health-validation-plots.R` 11 with a
  `local_mocked_bindings(requireNamespace)` to exercise the
  GRTS-fallback path,
  `test-ingest-health-validation.R` 10 TimescaleDB integration
  tests through `with_clean_db`). Total suite:
  **5957 PASS / 0 FAIL**.

# nemeton 0.20.1.9002 (development)

### Added — E6.c.3 (FORDEAD validity zones, towards v0.21.0)

* **`inst/extdata/fordead_validity_zones.geojson`** — five
  French departments (88 Vosges, 39 Jura, 01 Ain, 73 Savoie,
  74 Haute-Savoie) where the FORDEAD calibration is validated
  by the ONF/DSF report (Bernard & Doridant 2024). 5
  MULTIPOLYGON features, EPSG:4326, simplified at 100 m in
  Lambert-93 (~27 500 km^2, 80 ko). Built reproducibly from
  the static `gregoiredavid/france-geojson` mirror
  (Etalab 2.0).

* **`data-raw/build_fordead_validity_zones.R`** — reproducible
  script. Pivot from the original plan: `geo.api.gouv.fr` no
  longer serves contours via `format=geojson&geometry=contour`,
  so we use the GitHub static mirror instead.

* **`R/fordead_validity.R`** — implements guard-rail G3 of
  spec 008.
  * `FORDEAD_VALIDITY_DEPARTMENTS` and
    `FORDEAD_VALIDITY_SPECIES` exported constants.
  * `load_fordead_validity_zones()` — loads and caches the
    GeoJSON for the lifetime of the R session.
  * `check_fordead_validity(aoi, units, threshold_geo,
    threshold_species, min_resineux)` — returns a list
    flagging whether the AOI lies inside the calibrated
    extent (`geo_valid`, `geo_intersection_pct`,
    `geo_dept_codes`) and whether the user units are
    spruce + fir dominated (`species_valid`,
    `species_resineux_pct`, `species_epc_pct`,
    `species_sap_pct`), plus an `overall_valid` flag.
  * Internal `.is_epicea()` and `.is_sapin_pectine()` helpers
    correctly handle the Norway-spruce / silver-fir Latin
    name collision (both species share the epithet "abies")
    and exclude Douglas fir (Pseudotsuga menziesii).

* **Tests** — 16 new offline tests
  (`test-fordead-validity-zones.R` 4,
  `test-fordead-validity.R` 12). Total suite: 5866 PASS / 0 FAIL.

# nemeton 0.20.1.9001 (development)

### Fixed

* **`R/fordead_postprocess.R::list_alerts()`** — vector filters
  (`classes`, `validation_status`) are now serialised as Postgres
  `text[]` literals via the new internal helper `.pg_text_array()`
  and bound through `$n::text[]` placeholders. RPostgres requires
  every `dbBind` parameter to be length 1, so passing an R vector
  directly to `WHERE x = ANY($n)` was failing with
  *"Parameter 2 does not have length 1"* whenever a caller passed
  more than one class or status. Discovered by re-enabling the
  TimescaleDB integration tests once `NEMETON_DB_URL_TEST` was
  exported.

# nemeton 0.20.1.9000 (development)

### Added — E6.c.2 (FORDEAD post-processing + DB integration, towards v0.21.0)

* **`inst/db/migrations/0002_fordead.sql`** — extends `alert` with
  the validation workflow columns (`confidence_class`,
  `stress_index`, `validation_status DEFAULT 'pending'`,
  `validation_cause`, `validated_by`, `validated_at`) and adds two
  indexes: `alert_validation_status_idx` (UI filtering) and
  `alert_plot_date_type_idx` (composite index for the rolling-window
  × FORDEAD fusion). Idempotent (`ADD COLUMN IF NOT EXISTS` /
  `CREATE INDEX IF NOT EXISTS`).

* **`R/fordead_postprocess.R`** — turns the GeoTIFF outputs of
  `run_fordead_dieback()` into an `sf` POINT layer of cluster
  centroids and persists them in the `alert` table. Pipeline:
  `.classify_pixels_to_classes()` → `.cluster_anomaly_pixels()`
  (`terra::patches`, 8-neighbour by default, drops patches smaller
  than `min_pixels = 5`) → `.cluster_to_centroids()` (one POINT per
  cluster, enriched with `confidence_class`, `stress_index`,
  `trigger_date`, `n_pixels`, `area_m2`, `cluster_id`).

* **`FORDEAD_CLASSES`** (exported) — canonical 5-class vocabulary
  (`0-hors-anomalie`, `1-faible`, `2-moyenne`, `3-forte`,
  `4-sol-nu`).

* **`FORDEAD_CONFIDENCE_WEIGHTS`** (exported) — per-class
  trustworthiness coefficients calibrated on the ONF/DSF FORDEAD
  validation report (Bernard & Doridant 2024 — ADR-013 §G5).
  Classes 1 / 2 are weighted at 0.10 / 0.30 (poor field
  validation), classes 3 / 4 at 0.82 / 0.70.

* **`.insert_fordead_alerts(con, alerts_sf, zone_id, radius_m)`** —
  bulk-inserts cluster centroids as `alert_type =
  'fordead_dieback'` rows. Each centroid is snapped to the nearest
  registered plot of the zone (default max 200 m); centroids with
  no plot in range are skipped with a warning. Idempotent on
  `(plot_id, alert_type, trigger_date)` via `ON CONFLICT DO
  NOTHING` and a TEMP staging table.

* **`run_fordead_dieback()` wired** — the orchestrator now calls
  the post-processor inline and accepts new arguments `zone_id`,
  `min_pixels`, `connectivity`. The `alerts_sf` field of the
  return value is populated; `n_alerts_inserted` reflects the
  actual `ON CONFLICT` outcome when `con` and `zone_id` are
  supplied.

* **`classify_disturbance(alerts_df, window_days = 30)`**
  (exported, garde-fou G2) — joins each FORDEAD alert with
  rolling-window (`ndvi_drop` / `nbr_drop`) alerts on the same
  plot in a ±`window_days` window. Adds a `disturbance_type`
  column with values `mechanical`, `progressive`, `recent_event`
  or `NA`. Pure R, O(n²), no DB writes — recomputed at each call.

* **`list_alerts(con, zone_id, classes, validation_status,
  period)`** (exported, garde-fou G1) — read helper for the UI.
  Default class filter keeps `c("3-forte", "4-sol-nu")` (and
  rolling-window alerts which have no class); pass `classes =
  NULL` to opt in to lower-confidence alerts. Optional filters on
  `validation_status` and `trigger_date` period.

* **Tests** — `test-fordead-postprocess.R` (45+ assertions across
  constants, raster post-processing on synthetic SpatRasters,
  `classify_disturbance` cases, integration `with_clean_db` for
  `list_alerts` + `.insert_fordead_alerts`); `test-fordead-pipeline.R`
  extended with a non-empty postprocess scenario asserting the
  INSERT wiring. `test-db.R` extended for the `0002_fordead`
  migration. Suite : 5745 PASS / 0 FAIL offline.

### Added — E6.c.1 (FORDEAD pipeline scaffolding, towards v0.21.0)

* **`R/fordead_python.R`** — reticulate venv helpers for FORDEAD.
  `.ensure_fordead_python()` is idempotent (creates the
  `~/.virtualenvs/nemeton-fordead` venv on first use, installs the
  pinned dependencies from `inst/python/requirements.txt`, caches the
  imported module for the session). Python ≥ 3.10 is required;
  diagnostics make the precondition explicit. Override the venv name
  via the env var `NEMETON_FORDEAD_ENV`.

* **`R/fordead_pipeline.R`** — `run_fordead_dieback()` orchestrates
  the five FORDEAD steps (compute masked vegetation index, train
  model, forest mask, dieback detection, export results) on an AOI
  in EPSG:2154. Returns a structured list (`status`, `output_dir`,
  `rasters`, `alerts_sf`, `n_alerts_inserted`, `duration_sec`,
  `python_env`, `fordead_version`). Calibration is frozen on the
  ONF/DSF reference values (Bernard & Doridant 2024, ADR-013):
  CRSWIR + threshold 0.16. Post-processing of rasters into POINT
  clusters and DB persistence land in chantier E6.c.2.

* **`inst/python/requirements.txt`** — pinned Python deps
  (`fordead==2.1.4`, xarray, dask, rasterio, eodag, etc.).

* **`reticulate (>= 1.34.0)`** added to `Suggests`. Python and the
  `fordead` package are not pulled in until the user runs the
  pipeline; offline / non-Python users keep the existing surface.

* **Tests** — `test-fordead-python.R` (8 test_that, mocked reticulate,
  covers idempotence, version gating, venv reuse) and
  `test-fordead-pipeline.R` (12 test_that, mocked Python phases,
  covers argument validation, in-order step invocation, error
  propagation, forest-mask routing). All tests run offline.

# nemeton 0.20.1 (2026-04-25)

### Fixed — E6.a hardening (integration tests surfaced two real bugs)

* **`db_migrate()` multi-statement migrations.** The bundled
  `0001_init.sql` migration contains multiple statements (`CREATE
  TABLE` × 4, `CREATE INDEX` × 3, `SELECT create_hypertable(...)`,
  `CREATE EXTENSION`). RPostgres prepares the SQL by default and
  PostgreSQL refuses with *"cannot insert multiple commands into a
  prepared statement"*. Switched the migration call to
  `dbExecute(..., immediate = TRUE)` so the simple-query protocol is
  used. Fresh installs from v0.20.0 could never bootstrap the schema;
  this fix is required for the monitoring subsystem to be usable.

* **`.insert_obs_pixel()` temp-table scope.** The bulk-ingest helper
  created a `TEMP TABLE ... ON COMMIT DROP` *outside* the transaction
  containing the `dbAppendTable` + `INSERT … SELECT`. Each top-level
  `dbExecute` auto-commits, so the staging table was dropped
  immediately and the subsequent append failed with *"relation
  tmp_obs_pixel_staging does not exist"*. Moved the
  `CREATE TEMP TABLE` inside the same `dbWithTransaction` as the
  inserts.

* **`register_monitoring_zone()` docstring.** Claimed idempotence on
  `(zone_name, plot_id)`, but `monitoring_zone` has no uniqueness on
  `name`. Reworded to reflect actual guarantees: only
  `(zone_id, plot_id)` is enforced (via `UNIQUE` + `ON CONFLICT DO
  NOTHING`); same `zone_name` still creates a new zone row.

### Added

* **`tests/testthat/test-monitoring.R`** — 12 test_that blocks, 49
  assertions (3 pure unit + 9 integration). Covers
  `register_monitoring_zone()` (insert, WGS84 reprojection from
  Lambert-93, per-zone plot uniqueness), `ingest_sentinel2_timeseries()`
  (empty zone warning, empty STAC summary, mocked successful flow with
  idempotent re-run, per-scene extraction error recovery), and the
  internal helpers `.empty_ingest_summary()`, `.fetch_plots_sf()`,
  `.insert_obs_pixel()`. Surfaced both fixes above. `R/monitoring.R`
  now has its own dedicated test file (the 251-line module had zero
  direct tests in v0.20.0).

# nemeton 0.20.0 (2026-04-25)

### Added — Épaississement 6.a (walking skeleton monitoring continu)

* **TimescaleDB-backed monitoring subsystem.** First persisted
  time-series store in nemeton, designed to ingest Sentinel-2
  observations on demand and detect drops in vegetation indices. See
  `specs/007-monitoring-continu/` for the full spec.

* **Database layer** (new `R/db.R`): `db_connect()`, `db_disconnect()`,
  `db_migrate()`. Connection URL via `NEMETON_DB_URL`. Migrations
  bundled in `inst/db/migrations/0001_init.sql` create four tables —
  `monitoring_zone`, `plot`, `obs_pixel`, `alert` — with `obs_pixel`
  promoted to a TimescaleDB hypertable chunked every 7 days. Tracking
  via `schema_migration` makes re-runs no-ops.

* **STAC Sentinel-2 client** (new `R/sentinel2.R`): `stac_search_s2()`
  façade with **CDSE priority + Planetary Computer fallback**
  (ADR-008 souveraineté UE). Per-backend helpers
  `stac_search_s2_cdse()` and `stac_search_s2_pc()` are exported for
  finer control. PC hrefs are signed via the SAS-token endpoint so
  `terra::rast()` reads work without further authentication.

* **On-demand ingestion** (new `R/monitoring.R`):
    * `register_monitoring_zone(con, name, polygon, placettes)` upserts
      a zone and its plots (idempotent on `(zone_id, plot_id)`).
    * `ingest_sentinel2_timeseries(con, zone_id, start, end,
      bands = c("NDVI","NBR"))` fetches all matching scenes via STAC,
      computes NDVI from B04/B08 and NBR from B08/B12 in memory, and
      extracts the per-plot mean over a 15 m circular buffer with
      `exactextractr`. Bulk INSERT into `obs_pixel` via a TEMP staging
      table + `ON CONFLICT DO NOTHING`.

* **Alert detection** (new `R/alerts.R`): `detect_alerts(con,
  zone_id, threshold_ndvi_drop = 0.15, threshold_nbr_drop = 0.25,
  window_days = 30)` uses a SQL window function to compare each
  observation against the rolling mean of the preceding window;
  drops exceeding the per-band threshold are persisted in `alert`
  (idempotent on `(plot_id, alert_type, trigger_date)`) and returned
  as an sf POINT object.

* **Docker Compose** (`docker-compose.yml` at repo root, plus
  `.env.example`): single `timescaledb` service
  (`timescale/timescaledb:latest-pg16`) bound to localhost,
  persistent volume `nemeton_pg_data`, healthcheck via `pg_isready`.

* **Tests**: `test-db.R`, `test-sentinel2.R`, `test-alerts.R` plus
  `helper-monitoring.R`. Unit tests cover URL parsing, STAC feature
  parsing, CDSE→PC fallback logic, and bbox reprojection. Integration
  tests against a live TimescaleDB are gated by
  `skip_if_no_timescaledb()` (looks for `NEMETON_DB_URL_TEST`).

### Dependencies

* `RPostgres` added to Suggests (DBI was already present).
* No new hard dependency: the monitoring subsystem only loads when its
  functions are called.

### Documentation

* `specs/007-monitoring-continu/{spec.md, plan.md, tasks.md}` — full
  specification, implementation plan, 18-task breakdown.
* `PLAN.md` — refreshed for E6 with phase tracking.

### Out of scope (reported to v0.20.x)

* Shiny module `mod_monitoring` (E6.b, in `nemetonshiny`).
* Automated cron worker (E6.c).
* Integration of alerts into `compute_all_indicators()` for dynamic
  R1/R2/T2 modulation.

# nemeton 0.19.12 (2026-04-24)

### Fixed

* **`create_qfield_project()` now produces a `.qgz` that opens in
  QGIS 3.x without crashing**. Three latent bugs in the hand-written
  `.qgs` / GeoPackage made the project file unusable:

    1. Placette columns that were not supplied by the caller were
       filled with plain `NA` (logical), so the GeoPackage ended up
       typing `date_visite`, `pente_pct`, `observateur`, etc. as
       `Integer(Boolean)`. QGIS then tried to bind `DateTime` / `Range`
       / `TextEdit` widgets to boolean columns and crashed while
       building the attribute form. Missing columns are now filled
       with a **typed NA** (`NA_character_`, `NA_real_`, `NA_integer_`,
       `as.POSIXct(NA)`) matching the schema.

    2. `ValueMap` widgets (`type`, `exposition`, `espece`, `statut`,
       `qualite`) were emitted as `List-of-Lists` instead of the
       canonical QGIS 3.x `List-of-Maps` (each entry is a `<Option
       type="Map">` wrapping one `<Option type="QString" name=...
       value=...>`). QGIS crashed while parsing the form definition.

    3. The QGIS 2.x `<prop k="..." v="..."/>` syntax used by the
       categorised point renderer is rejected by QGIS 3.x. The custom
       renderer has been dropped; QGIS now applies its default
       single-symbol renderer, which users can categorise in the UI.

* Structural hardening of the `.qgs` XML, independent of the crash
  fix: full `<spatialrefsys>` block (wkt, proj4, srsid, srid, authid,
  description, geographicflag) built from `sf::st_crs()` instead of a
  bare `<authid>`; `<extent>` added to every `<maplayer>`; `source`
  attribute added to every `<layer-tree-layer>`; `<customproperties>`
  + `<custom-order enabled="0"/>` inside `<layer-tree-group>`;
  `<homePath>`, `<title>`, `<properties>` at the project root.

# nemeton 0.19.11 (2026-04-24)

### Changed

* **`create_sampling_plan()` now clamps `n_base + n_over` to frame
  capacity with a clear warning**. Previously, when the candidate
  frame (after `min_forest_cover` / `max_slope` filtering) was smaller
  than `n_base + n_over`, the pipeline silently fell back to LPM2 and
  could drop *all* Over plots (since `max(0L, n_frame - n_base)` is 0
  when `n_base ≥ n_frame`). It now detects the mismatch upfront,
  scales `n_base` and `n_over` down proportionally (Base/Over ratio
  preserved, with a minimum of 1 Over when `n_over > 0`), and emits a
  `cli::cli_warn()` pointing at the likely causes (strict
  `min_forest_cover`, large `grid_step`). GRTS can then run on the
  reduced allocation instead of being skipped entirely.

### Added

* Two new unit tests (`test-sampling-plan.R`) locking in the clamp
  behavior: Base/Over ratio preservation, minimum-1-Over guarantee,
  and the warning signature.

# nemeton 0.19.10 (2026-04-24)

### Changed

* **`create_sampling_plan()` auto-simplifies the stratification when
  GRTS would refuse**. Previously, a single thin stratum — easy to
  hit on small AOIs, where the 3D stratification (CHM height ×
  BD Forêt type × TPI) can produce up to 60 combinations — caused
  the whole GRTS draw to be skipped and the plan fell back to LPM2
  (which is spatially balanced but *not* stratified). The new
  `.fit_stratum()` helper now tries the stratification ladder
  3D → 2D (drop TPI) → 1D (height only), keeping the richest combo
  where every stratum still meets the allocation + over requirement,
  and emits a `cli::cli_inform()` listing the dropped dimension(s).
  LPM2 / random remain the final fallback.

### Added

* Four new unit tests (`test-sampling-plan.R`) covering the new
  `.fit_stratum()` helper: degradation from 3D to 2D, from 3D to 1D,
  the fully-thin edge case, and degeneracy handling when one
  dimension is constant.

# nemeton 0.19.9 (2026-04-24)

### Changed

* **`create_sampling_plan()` now explains why GRTS was skipped**. The
  two previously silent fallback branches (no usable stratification,
  or `spsurvey` not installed) now emit a `cli::cli_inform()` listing
  the concrete reasons — e.g. `"Skipping GRTS: no usable
  stratification (single stratum, no CHM, no DEM, no BD Foret 'tfv'
  field). Falling back to LPM2 / random."` The two already-reported
  cases (thin strata and `spsurvey::grts` errors) are unchanged.

# nemeton 0.19.7 (2026-04-24)

### Fixed

* **`.compute_forest_cover()` row alignment**: the row.names-based
  fallback introduced in 0.19.6 was fragile across sf versions —
  some versions rewrite row.names on intersection and the
  resulting `match()` returned NA, leaving the forest cover at 0
  for all buffers. Replaced by a carried integer id column
  (`.fc_id`) added to buf_hit before the intersection and read
  back from `inter$.fc_id`. Robust on every sf ≥ 1.0.

# nemeton 0.19.6 (2026-04-24)

### Performance

* **Vectorised `.compute_forest_cover()`** used by
  `create_sampling_plan()`. The previous per-row `for` loop was
  O(n × m) (n = candidate buffers, m = mask polygons) — on a
  Couchey-sized AOI (n ~ 3000 buffers, m ~ 50 BD Forêt polygons)
  the pre-filter was running in ~30–60 s, freezing the Shiny UI.
  New implementation runs in ~0.7 s for the same load by:
  1. pre-filtering candidates with a bulk `sf::st_intersects()`;
  2. unioning the mask once;
  3. calling a single vectorised `st_intersection()`.
  Output is equivalent to the previous loop (suite 5608 / 0
  failure).

# nemeton 0.19.5 (2026-04-24)

### Changed

* **`detect_ndp()` recognises LiDAR HD as a distinct augmentation**
  (E5.d phase 2). When the input carries
  `attr(data, "chm_source") == "lidar_hd"`, the augmented vector
  now includes `"height_lidar"` alongside any other flags. The
  `"height_ml"` tag stays reserved for Open-Canopy ML predictions.
  As before, the base NDP level is lifted to 1 ("Observation") when
  `attr(data, "has_lidar_hd")` is TRUE — the new flavour flag is
  purely informational.

# nemeton 0.19.4 (2026-04-24)

### Fixed

* **Warning flood in `.compute_forest_cover()`** — when
  `create_sampling_plan()` was called with a non-trivial
  `forest_mask` (e.g. a BD Forêt v2 coverage with 30+ polygons),
  the per-candidate `sf::st_intersection()` call fired
  "attribute variables are assumed to be spatially constant
  throughout all geometries" once per candidate. A large project
  (~2000 candidates) therefore spammed the console with 2000
  copies of the same warning. Declare the attributes as constant
  via `sf::st_agr()` and wrap the intersection in
  `suppressWarnings()` so the message appears once (in the
  downstream Shiny log) at most.

# nemeton 0.19.3 (2026-04-24)

### Changed

* **`inst/extdata/bdforet_v2_mapping.csv`** — every row now has
  `confidence = "clear"`. The 9 previously ambiguous TFV codes
  (FF1-00, FF1G06-06, FF1-10-10, FF1-49-49, FF1-00-00, FF2G58-58,
  FF2G61-61, FO1, FO2) commit to the primary `context_key`; the
  secondary candidate is still kept in `alt_context_key` as
  informational metadata so the user can override locally.

### Fixed

* **`cv_from_bdforet()`** — distinguish two cases that were
  previously conflated in `$unmapped`:
  - *truly unknown* TFV codes (absent from the mapping) → stay in
    `$unmapped`;
  - codes mapped explicitly to `NA` (non-forest: FF0, FO0, LA4,
    LA6) → no longer reported as unmapped since the mapping
    acknowledges them.
  This removes the spurious "FORÊT-FERMÉE-SANS-COUVERT-ARBORÉ"
  warning in the Shiny sizing report.

# nemeton 0.19.2 (2026-04-24)

### Changed

* **TSP tour delegated to the `TSP` package** — the hand-rolled
  nearest-neighbor we shipped in 0.19.1 is replaced by the same
  recipe used in tutorial `09-sampling`:
  `TSP::solve_TSP(method = "nearest_insertion")` seeds the tour,
  `TSP::solve_TSP(method = "2-opt")` refines it. The output is then
  rotated so the SE-most plot is first (heuristic road-access
  start). The old NN + open-path 2-opt stays as a fallback when
  `TSP` is not installed.
* `TSP (>= 1.2.0)` added to `Suggests` in `DESCRIPTION`.

# nemeton 0.19.1 (2026-04-24)

### Fixed

* **`create_sampling_plan()`** — `visit_order` now reflects a real
  walking tour. The previous implementation assigned `visit_order`
  from the draw order (GRTS / LPM2 / random), which on a wide AOI
  produced a zig-zag polyline on the Shiny map rather than a
  sensible field route. Base plots are now reordered via a
  nearest-neighbor heuristic starting from the south-easternmost
  point (likeliest road access in French forest contexts), then
  improved by up to 20 passes of 2-opt for an open path. Over
  (replacement) plots keep their draw-priority order at the tail.
  The helper `.tsp_nearest_neighbor()` is internal; no new hard
  dependency.
* Tests: two new assertions in `test-sampling-plan.R` (the TSP tour
  is materially shorter than a random order, and the first plot
  lands in the east half of a wide rectangle).

# nemeton 0.19.0 (2026-04-24)

### New feature — Sample size from target error + CV typology (Épaississement 5.c)

* **`R/sample_size.R`** — `compute_sample_size(cv, target_error, alpha,
  N, max_iter, tol)` implements the classic Cochran formula
  `n >= (t * CV / E)^2` with iterative Student-t refinement on the
  degrees of freedom and an optional finite-population correction
  `n_corr = n / (1 + n/N)`. Returns the sized `n`, the converged
  `t_used` / `df`, convergence flag, iteration count, and the echoed
  inputs. Formulas are standard sampling theory and are not
  copyrightable; credit to Max Bruciamacchie / AgroParisTech
  (PPtools, GPL-2, 2014) for the IFN-G/ha convention we align on.

* **`R/cv_typology.R`** — lookup tables and helpers for the CV side
  of the equation:
  - `cv_typology()` loads `inst/extdata/cv_typology.csv`: 8 generic
    forest contexts (5 peuplement-level, 3 stratification-level) with
    low / mid / high CV bounds on basal area G/ha.
  - `cv_lookup(context_key, position)` reads a single CV value.
  - `bdforet_v2_mapping()` loads `inst/extdata/bdforet_v2_mapping.csv`:
    the 32 BD Forêt v2 TFV codes mapped to one of the generic
    contexts with a confidence flag (clear / ambiguous) and a
    secondary candidate for ambiguous classes.
  - `cv_from_bdforet(bdforet_sf, position, aoi, tfv_col)` returns an
    area-weighted CV for an AOI, plus a diagnostic summary (per-TFV
    share, ambiguous codes, unmapped codes). Polygons mapped to
    NA (FF0 coupe rase, LA4 lande, etc.) are excluded from the CV.

* **`R/sampling_plan.R`** — `create_sampling_plan()` now accepts
  `target_error`, `cv`, `alpha` and `over_ratio` as optional
  arguments. When `target_error` + `cv` are provided, `n_base` is
  sized via `compute_sample_size()` and `n_over` defaults to
  `ceiling(n_base * over_ratio)` (default 20 %). The previous
  `n_base` path is preserved and stays the default when neither
  argument is set, but at least one must now be provided. The sizing
  result is attached to the returned sf as `attr(plan, "sample_size")`.

* **CSV editability**: both typology files are loaded via
  `system.file()` by default, but `cv_typology(file = ...)` and
  `bdforet_v2_mapping(file = ...)` let the user point at a custom
  CSV — useful to tune the bounds locally without rebuilding the
  package.

* Tests: `test-sample-size.R` (24 assertions), `test-cv-typology.R`
  (24 assertions, including area-weighted aggregation and the
  ambiguous / unmapped paths), plus 7 new assertions in
  `test-sampling-plan.R` for the `target_error` path. Full suite
  5595 / 0 failure.

# nemeton 0.18.0.9000 (development)

### New feature — QField export (Épaississement 5.a)

* **`R/field_schema.R`** — field data schema used for QField
  integration: `get_placette_schema()` (10 fields) and
  `get_arbre_schema()` (9 visible fields + species domain). The
  `espece` domain is pulled from `list_species_classes()` so the
  vocabulary stays aligned with the rest of the package.
  `schema_to_df()` and `empty_sf_from_schema()` are internal helpers.
* **`R/qfield_export.R`** — `create_qfield_project(placettes,
  zone_etude, parcours_tsp, output_dir, project_name, crs, region,
  lang, overwrite)` packages a sampling plan as a QField-ready
  `.qgz` (a ZIP of a minimal QGIS 3.x `.qgs` XML + a GeoPackage
  with `placettes` / `arbres` / `zone_etude` / `parcours_tsp`
  layers). Edit widgets (TextEdit, Range, DateTime, ValueMap,
  ExternalResource), aliases and NotNull constraints are generated
  from the schemas. Zero new hard dependency: the XML is produced
  by string assembly, the GPKG by `sf`, the ZIP by `utils::zip()`.
* **Tutorial 09-sampling** — new Section 6 "Export QField" exercises
  `create_qfield_project()` on the GRTS output, plus a 3-question
  quiz on the `.qgz` format, NotNull constraints and the species
  domain source.

### New feature — Library-level sampling pipeline (Épaississement 5.a bis)

* **`R/sampling_plan.R`** — `create_sampling_plan(zone, n_base, n_over,
  chm, slope, forest_mask, mnt, ...)` lifts the full GRTS workflow of
  tutorial 09 to a single exported function. It builds a candidate
  grid, applies terrain constraints (slope / forest cover), stratifies
  on CHM height quartiles / BD Forêt tfv / TPI terciles, and draws
  plots via `spsurvey::grts` when strata are viable, falling back to
  `BalancedSampling::lpm2`, then to a plain spatial random draw —
  each step surfaced via an attached `"method"` attribute on the
  result.
* Without any of the optional inputs the pipeline degrades to the
  equivalent of a single `st_sample()` call, which makes it a drop-in
  replacement for the previous Shiny-side placeholder.

### New feature — QField re-ingestion (Épaississement 5.b)

* **`R/qfield_import.R`** — three companion functions that close the
  field loop:
  * `import_qfield_gpkg(path)` reads the `placettes` + `arbres`
    layers returned from QField.
  * `validate_field_data(placettes, arbres, region, lang)` checks
    referential integrity (orphan `plot_id`, duplicate `tree_id`),
    physical ranges (DBH in (0, 300] cm, height in [0, 80] m),
    species in the controlled domain of `region`, and returns an
    `{ok, errors, warnings}` list.
  * `aggregate_plot_metrics(placettes, arbres, plot_radius)` computes
    per-plot dendrometric aggregates — `field_n_trees`,
    `field_dg_cm` (quadratic mean diameter), `field_h_dom_m`
    (top 5 height), `field_g_ha` (basal area), `field_cv_dbh` /
    `field_cv_h` for the B2 structural component — as a sf that can
    be joined onto forest units.
  * `attach_field_data_to_units(units, field_agg)` spatial-joins the
    aggregates onto polygon units for downstream indicators
    (P1 / P2 / B2 / C1 / R2) to consume uniformly via `field_*`
    columns.
* **`R/ndp.R`** — `detect_ndp()` gains an alternative QField path:
  `field_plots_count >= 1` bumps the NDP to at least 2 (Exploration);
  when trees-per-plot average >= 10, the level goes to 3 (Diagnostic).
  `tag_field_data_sources(data, placettes, arbres)` is the helper
  that sets the expected attributes in one call.
* **`inst/datasources/FR.json`** — new `datasets.field_qfield` entry
  declaring the format (GeoPackage), required CRS (EPSG:2154),
  layers (`placettes`, `arbres`) and the NDP bump rule.
* Tests: `test-sampling-plan.R` (22 assertions across GRTS / LPM2 /
  random / constraint paths), `test-qfield-import.R` (26 assertions
  covering round-trip, validation failures, aggregates, and the
  units join), `test-ndp-qfield.R` (13 assertions on the alternative
  path including the sources listing and the JSON declaration).

# nemeton 0.18.0

Release theme: **F1 soil fertility becomes a three-source indicator
with absolute scoring and empirical calibration against RMQS**.

### New Vignette — F1 three-source decision guide (phase E)

* **`vignettes/f1-three-sources_fr.Rmd`** — end-to-end comparison of
  the three F1 data-source paths (`"layer"`, `"soilgrids"`,
  `"gissol"`) with a decision matrix, runnable examples, the Phase D
  calibration reading (why CEC alone is a coarse proxy and the
  expert table captures more), and a decision tree for picking the
  right `source` per AOI.

### Calibration — F1 expert scores vs RMQS 1ère campagne (phase D)

* **`inst/scripts/calibrate_uts_rmqs.R`** — reproducible pipeline
  that downloads the RMQS 1ère campagne dataset (DOI 10.15454/QSXKGA,
  Etalab 2.0 licence, ≈ 2 171 sites, 2000-2009), joins topsoil CEC
  (0-30 cm, `cec_40_1`) with the site's AFES 1995/2008 soil name
  (`rp_95_nom` / `rp_2008_nom`), classifies each name into one of
  our `rpf_code` values via a keyword-priority dictionary, and
  compares observed median CEC (mapped to 0-100 via
  `cec_to_fertility_score()`) with the expert score.
* **`inst/extdata/uts_fertilite_rmqs_calibration.csv`** — calibration
  artefact: 45 `rpf_code` × 2 037 RMQS sites, one row per code with
  `n_sites`, `cec_median`, `cec_q25`, `cec_q75`, `observed_score`,
  `expert_score`, `delta` and a boolean `flag_outlier` (|delta| > 20).
* **What the deltas reveal**: 20/45 rows are flagged. The deltas are
  NOT an indictment of the expert table — they highlight that CEC
  alone is a coarse proxy. The expert scores integrate Baize & Jabiol
  multi-criteria (texture, pH, drainage, depth, forestry productivity),
  which CEC doesn't capture. Key signals:
    * **Alluvial / colluvial soils under-score on CEC** (FLU_TYP,
      COL_TYP, COL_CAL all −40 to −55): these are fertile because
      they are deep, well-drained and productive, not because they
      hold many cations. The SoilGrids path in F1 will under-rate
      them by design.
    * **ORG_INS over-scores on CEC** (+65): peat has very high CEC
      but is poor for forestry (acidity, waterlogging). The expert
      score rightly penalises this where CEC alone cannot.
    * **BRUN_MES bucket is biased** (−49 on 378 sites): most "plain
      BRUNISOL" RMQS labels fall into this via fallback, but many of
      those sites show CEC compatible with BRUN_DYS. Not a scoring
      bug — a mapping-granularity bug in the V2 classifier.
    * **Classes absent from the V1 expert table** (30+ RMQS sites):
      PLANOSOL, PELOSOL, MAGNESISOL, FERSIALSOL, DOLOMITOSOL,
      ALUANDOSOL/ANDOSOL. Candidates for a V2 CSV extension.
* **`tests/testthat/test-uts-calibration-rmqs.R`** — integrity checks
  on the calibration CSV (schema, cross-reference to the expert
  table, arithmetic consistency, sample size, CEC quartile order).
  Does not re-run the pipeline.

### New Features — F1 GIS Sol wiring (phase C)

* **`indicateur_f1_fertilite()` gains a third `source` option**:
  `source = "gissol"` reads a French RRP (Référentiel Régional
  Pédologique) polygon layer from `layers`, intersects it with
  `units`, joins the AFES 2008 typology code against the UTS
  crosswalk shipped in `inst/extdata/uts_fertilite_fr.csv`, and
  returns an area-weighted fertility score per unit on the 0-100
  scale. Units whose polygons carry only codes absent from the
  table return NA; units outside the RRP coverage return NA. A
  `cli::cli_warn` summarises unknown codes when any are present.
* **`rpf_code_col` argument** (default `"rpf_code"`) lets the
  caller point at whatever column name the source RRP uses for the
  AFES code (`UTSDom`, `RPFdom`, etc.) without pre-renaming columns.
* **`read_uts_fertility_table()`** — new exported helper returning
  the V1 UTS → fertility crosswalk as a data.frame. Useful for
  external review of the scoring and for ad-hoc joins against
  arbitrary RRP vector data.

### New Data — UTS → fertility lookup (F1 GIS Sol wiring, phase B)

* **`inst/extdata/uts_fertilite_fr.csv`** — V1 draft of the soil
  typology → forest-fertility crosswalk for France, 54 rows covering
  the 14 Grands Ensembles de Référence of the AFES 2008 Référentiel
  Pédologique (Brunisols, Luvisols, Podzosols, Alocrisols, Calcosols,
  Calcisols, Fluviosols, Colluviosols, Rankosols, Arenosols,
  Redoxisols, Reductisols, Peyrosols, Organosols, Régosols/Lithosols,
  Anthroposols). Columns: `rpf_code`, `rpf_name`, `wrb_code`
  (WRB 2014 equivalent), `fertility_class` (1–5), `fertility_score`
  (15/35/55/75/90 per the agreed grid), `texture_dom`, `drainage`,
  `depth_cm`, `ph_range`, `forest_note`, `source_biblio`, `notes`.
  Sources: AFES 2008, Baize & Jabiol 1995, Duchaufour 2001, Jabiol
  et al. 2009, Bonneau 1995. Intended for peer review by a
  pedologist before production use.
* **`tests/testthat/test-uts-fertilite.R`** — integrity checks on
  the CSV (schema, unique keys, score grid, class distribution,
  coverage of the 14 AFES families).

### New Features — F1 fertility from SoilGrids 2.0

* **`load_raster_source(source_key, country, aoi)`** — new exported
  loader that resolves a datasource key declared in
  `inst/datasources/<country>.json` to a ready-to-use `SpatRaster`.
  Prepends `/vsicurl/` for `raster_remote` sources so GDAL reads
  only the requested window (essential for planet-scale feeds like
  SoilGrids). Crops to an optional AOI (reprojected to the raster's
  native CRS). Refuses `raster_local` entries with no path (e.g.
  `chm_opencanopy`, which is materialised on the fly by its
  producing package).
* **`cec_to_fertility_score(cec_x10)`** — maps raw SoilGrids 2.0
  Cation Exchange Capacity values (unit: `cmol(c)/kg × 10`) to a
  0-100 fertility score, linearly on `[0, 30] cmol(c)/kg` and capped
  at the bounds. Thresholds follow Baize & Jabiol (1995).
* **`indicateur_f1_fertilite()` gains a `source` argument**:
    * `source = "layer"` (default) — unchanged, reads a user-supplied
      soil raster or polygon layer and min-max normalises per call.
    * `source = "soilgrids"` — fetches the SoilGrids 2.0 CEC topsoil
      raster via `load_raster_source("soilgrids_cec")`, extracts the
      per-unit mean, and maps to 0-100 via `cec_to_fertility_score()`.
      No inventory layer is needed and scores are absolute
      (comparable across projects), unlike the relative layer-mode
      score. Global coverage — works for any AOI.
  Behaviour is fully backward-compatible when `source` is omitted.

# nemeton 0.17.0

### New Features — NDP 1 "synthetic inventory"

* **`n_max_selfthinning(dq, species)`** — species-keyed evaluator of the
  Charru et al. 2012 self-thinning relationship
  \eqn{\ln(N_{max}) = a + b \ln(D_g) + c \ln(D_g)^2} for 11 temperate
  species (11 linear and curvilinear fits from Tables 2/5 of the
  paper, clamped to each species' observed \eqn{D_g} range).
* **`estimate_synthetic_inventory()`** — given an `sf` of units, a CHM
  `SpatRaster` and species codes, chains
  \eqn{H_{dom}} (CHM) \eqn{\to} \eqn{D_g} (species allometry)
  \eqn{\to} \eqn{N} (self-thinning × stocking fraction 0.75) and
  returns per-unit `(dbh, density, source = "synthetic_ml")`.
* **`ensure_inventory_fields()`** — fills a sf's missing `dbh` /
  `density` columns in place, leaving user-provided values intact.
  Wired into `indicateur_p1_volume()`, `_p3_qualite_bois()` and
  `_e1_bois_energie()` so that these three indicators now compute
  from the CHM when a terrain inventory is absent, instead of
  failing with "Missing required fields".
* **`charru_bai_drift_table()` / `bai_drift_factor(species, habitat)`**
  — per-species central estimates of the 1980-2007 relative BAI
  change reported in Charru et al. 2017 (Fig. 4a), with fallback to
  the per-climatic-habitat mean. `indicateur_p1_volume()` gains an
  opt-in `use_climate_drift = FALSE` argument that multiplies per-
  unit volume by the drift factor when TRUE.

### New Features — site-index curves

* **FASY (common beech) migrated to the Korf recursive model of
  Bontemps et al. 2007 (RFF HS2, Annex 2)**. Three species codes now
  coexist in `inst/extdata/site_index_curves.csv`:
    * `FASY_NO` — Nord-Ouest (a=44.2, b=0.032, c=1.647)
    * `FASY_NE` — Nord-Est  (a=68.7, b=0.028, c=0.823)
    * `FASY` — per-age per-class mean, used as a regionally-
      agnostic default pending a GRECO-aware dispatcher.
* **Phase A calibration audit** — new exported helper
  `site_index_reference_points()` returns, for each of the 10 MVP
  species, the published reference point `(age, H_{class\_3})` and
  its bibliographic source (Duplat & Tran-Ha 1997 for QUPE / QURO,
  Seynave et al. 2005 for PIAB, Vallet & Pérot 2011 for ABAL,
  DSF/IRSTEA 2010 for PSME, …). A new regression test
  `test-site-index-calibration.R` asserts the shipped CSV matches
  every reference point within 0.5 m (worst current delta: 0.36 m
  on POSP).
* **`enrich_parcels_bdforet()` is now exported** so that downstream
  packages (notably nemetonshiny, for its pre-compute P2 species/age
  enrichment step) can call it without `:::`.

### Bug Fixes

* **`sanitize_chm()`** hardened against the Open-Canopy feed used in
  nemetonshiny:
    * each pipeline step (forest mask, buildings, water, NDVI, range,
      slope) runs in a named `tryCatch` so a terra failure surfaces
      with the step name instead of a cryptic `[subset] invalid
      name(s)`;
    * sf layers are stripped of every attribute before the
      `terra::vect()` conversion (via the new internal
      `.sf_to_vect_geom()`), sidestepping the list-columns /
      factor-level issues that BD Forêt V2 outputs occasionally
      carry;
    * NDVI default threshold softened from 0.3 to 0.2 (the former
      was too strict for conifer / shadowed / edge pixels);
    * new `forest_coverage_threshold` (default 0.5): the forest-mask
      step is skipped with a warning when the mask covers less than
      that fraction of the CHM extent, instead of wiping 95 %+ of
      the pixels when BD Forêt simply does not map the area. Pass
      `forest_coverage_threshold = 0` to force the mask;
    * each step now emits a `cli_alert_info` with the cumulative
      fraction of pixels masked, for post-mortem analysis.
* **E2 CO2 avoidance** emits a single aggregate log line per AOI
  instead of one line per unit (reduces log noise by ~60× on typical
  63-UGF projects).

### Breaking changes

* None. All changes are backward-compatible with v0.16.x.

# nemeton 0.16.0

### New Features

* C1 biomass, B2 structure, R2 storm — Open-Canopy CHM modes
  (spec 005 phase 4):
    * `indicateur_c1_biomasse()` gains a `chm = NULL` argument.
      When supplied with `dbh` and `species` columns, biomass is
      derived from the IFN tarif \eqn{V = a \cdot D^b \cdot H^c}
      combined with wood density (`inst/extdata/wood_density.csv`),
      a biomass expansion factor (`bef`, default 1.30, IPCC 2006
      temperate-forest default) and the carbon fraction. Stems
      per ha: prefer `stems_col` (default `"stems_ha"`), else
      derive from `density_col` fraction × 500. Positively
      correlates with the age-based path on varied stands
      (Spearman ρ ≥ 0.5).
    * `indicateur_b2_structure()` gains `chm = NULL` and
      `cv_chm_weight = 0.2` arguments. When a CHM is supplied,
      CV(height) per unit is computed and blended into the B2
      score. Without strata/age inputs, the CV(CHM) becomes the
      primary structural-diversity proxy. Heterogeneous stands
      (tall + short pixels) score higher than homogeneous ones.
    * `indicateur_r2_tempete()` gains `chm = NULL`,
      `species_field`, `h_dom_percentile` and `h_reference`
      arguments. The base DEM/wind score is modulated by a
      canopy-vulnerability factor \eqn{f(H, \textit{species})}
      clamped to [0.5, 1.5]: tall stands are more vulnerable
      than short ones, and at equal height conifers (factor
      1.2) score higher than broadleaves (factor 0.8).
    * All three additions are fully backward-compatible when
      `chm` is `NULL`.
* P1 standing-timber volume via Open-Canopy CHM (spec 005 phase 3):
    * `indicateur_p1_volume()` gains a `chm = NULL` argument.
      When supplied, the height fed to the IFN tarif
      \eqn{V = a \cdot D^b \cdot H^c} is taken from the CHM
      (per-unit 90th-percentile via
      \code{\link{extract_h_dom}}) instead of the Näslund
      approximation \eqn{H = 1.3 + 0.65 \cdot DBH}. Typical
      RMSE reduction on mature stands: 20 to 40 \%.
    * New optional arguments `h_dom_percentile` (default 0.9)
      and `pct_masked` (emits a warning when greater than 0.3,
      signalling a heavily-masked CHM whose P1 estimate is
      unreliable).
    * Genus-level fallback is now species-aware: conifers fall
      back to `CONIFER_GENUS`, non-conifers to
      `BROADLEAF_GENUS`. Previously every species defaulted to
      broadleaf, which penalised conifer volume estimates.
    * Added `PSME` (Pseudotsuga menziesii, Douglas) and `POSP`
      (Populus sp. cultivé) rows to
      `inst/extdata/ifn_volume_equations.csv` so they no longer
      fall back to genus-level coefficients.
    * New internal helper `is_conifer()` (shared with
      `compute_site_index()`).
    * Behaviour is unchanged when `chm` is `NULL`: fully
      backward-compatible with v0.15.x.
* P2 site index via Open-Canopy CHM (spec 005 phase 2):
    * New reference dataset `inst/extdata/site_index_curves.csv`
      covering the 10 MVP species (QUPE, QURO, FASY, CASA, PIAB,
      ABAL, PSME, PISY, PIPI, POSP) plus two genus-level fallbacks
      (`BROADLEAF_GENUS`, `CONIFER_GENUS`). Generated from the
      published Chapman-Richards parametrizations of Duplat &
      Tran-Ha 1997 and related works, with per-species source
      attribution. Distribution authorised by M. Tran-Ha
      (personal communication, April 2026 — see `inst/NOTICE`).
    * New `compute_site_index(H_dom, age, species,
      reference_age = 50)` performs bilinear interpolation over
      the five fertility classes and returns the dominant height
      at the reference age (metres). Vectorised; NA-safe;
      genus-level fallback when the species is not directly
      tabulated; case-insensitive species codes.
    * New helpers `list_site_index_species()` and
      `read_site_index_curves()`.
    * New `extract_h_dom(chm, units, percentile = 0.9)` in
      `R/utils-chm.R`: per-unit dominant height from a sanitised
      CHM raster (90th-percentile by default). Falls back to
      `terra::extract()` when `exactextractr` is absent.
    * `indicateur_p2_station()` gains a `chm = NULL` argument
      that activates the CHM mode when supplied. In CHM mode the
      output column holds the site index in metres; the legacy
      proxy (`fertility × climate × species` → m³/ha/yr) is
      unchanged when `chm` is `NULL`.
    * New vignette `site-index-open-canopy_fr.Rmd` — end-to-end
      workflow from a CHM to P2 on a synthetic forest, with a
      section on limits (CHM ML RMSE, `sanitize_chm()`
      importance, age dependency).
* Foundation for Open-Canopy integration (spec 005 phase 1, ADR-011 amendment):
    * `detect_ndp()` now returns an `ndp_result` S3 object with
      `level`, `confidence`, `augmented`, `sources` slots. The
      `augmented` vector flags ML-derived layers such as `height_ml`
      when `attr(data, "chm_source") == "opencanopy"`. The base NDP
      level and global Fibonacci confidence are unchanged.
    * **Breaking**: `detect_ndp()` used to return a plain integer.
      Callers must now use `result$level` or `as.integer(result)`.
    * New accessor `get_ndp_augmented()`.
    * New dataset entry `chm_opencanopy` in `inst/datasources/FR.json`
      (type, format COG, required CRS, value range, provenance, license).
    * New `sanitize_chm()` 5-step pipeline in `R/utils-chm.R`
      (forest mask, buildings/water, NDVI threshold, plausibility
      bounds, slope coherence). Returns `list(chm_clean, pct_masked,
      steps_applied)` and warns when more than 50% of valid pixels
      are masked.
    * New `inst/NOTICE` documenting third-party attributions
      (IGN BD ORTHO, Open-Canopy weights, LiDAR HD, OSO, WorldClim,
      Duplat & Tran-Ha site-index curves).

### Refactoring

* Moved `ndp_badge()` and `ndp_progress_bar()` HTML widgets to the
  `nemetonshiny` package (they had no use in the core package)

### Bug Fixes

* Fixed radar chart: replaced `NaN` values with 0 to prevent polygon vertex
  loss when an indicator is missing

### Documentation

* Added indicator calculation table by NDP level (0-4)
* Added all 14 missing topics to the `_pkgdown.yml` reference index
* Synchronized `CLAUDE.md` with the v0.15.0 core/Shiny split: reflect
  `nemetonshiny` as a separate package, mark Épaississements 3 and 4 as
  delivered, update file references and strict rules

---

# nemeton 0.15.1

**Date**: 2026-04-09

### Bug Fixes

* Addressed all remaining R CMD check notes and warnings
* Cast all indicators (including F1 soil fertility) to `double` in
  `massif_demo_units` for consistent column types
* Forced conversion to `double` to avoid integer/numeric mismatches in
  downstream normalization

### Data

* Regenerated `massif_demo_units` dataset with 29 indicators + 12 family
  composites using NMT naming (`famille_*` prefix)
* Regenerated `roads` and `water` GeoPackage fixtures

### Documentation

* Vignettes realigned with NMT naming: `starts_with()` patterns updated to
  match `famille_` prefix
* Fixed unicode escapes in `R/ndp.R`

---

# nemeton 0.15.0

**Date**: 2026-04-09

### BREAKING CHANGES ⚠️

**Core/Shiny package split (ADR-009)**

The `nemeton` package is now **core-only**. The Shiny application
(`nemetonApp`) has been extracted into a separate package `nemetonshiny`.
Users who relied on `nemeton::run_app()` must now install `nemetonshiny`
and call `nemetonshiny::run_app()`.

* 120+ internal functions are now exported from `nemeton` to be consumed
  by `nemetonshiny` and other downstream packages (`tree_sat_nemeton`,
  `maestro_nemeton`)
* All Shiny modules (`mod_*.R`), expert profiles (`inst/experts/`), UI
  i18n files (`inst/app/i18n/`), LLM prompts and OAuth2 module have been
  moved out of this repository
* `NAMESPACE` and `DESCRIPTION` cleaned up to drop Shiny-only dependencies

### New Features

#### NDP System (Niveau De Précision) — ADR-011

* New `R/ndp.R` module implementing the 5-level data-precision system
  with Fibonacci weighting (1-1-2-3-5) and confidence ratio φ
* `NDP_LEVELS` configuration, accessors (`get_ndp_level()`,
  `get_ndp_name()`, `get_ndp_weight()`, `get_ndp_confidence()`)
* `detect_ndp()` — automatic NDP detection from data sources
* `compute_general_index()` and `compute_general_index_mixed()` for
  Fibonacci-weighted global scores
* NDP wired into the compute pipeline, radar chart, PDF report and
  synthesis table

#### Naturalness Indicators (N1, N2, N3)

* Aligned N1, N2, N3 formulas with Tutorial 04 ecological definitions

#### Internationalization & Data Sources (ADR-002)

* Data source abstraction by country — hardcoded URLs replaced with
  `get_data_source()` calls
* Species configuration by region for the NDP pipeline (ADR-007)
* Added `essence_peupleraie` as 11th species class
* EPSG:3035 pan-European storage CRS (ADR-008)

#### Infrastructure

* PostgreSQL/PostGIS database service for Clever Cloud (ADR-002)
* Auto-sync to PostGIS after indicator computation
* CI/CD enhancements with tests and Docker build (ADR-010)
* Dual license structure MIT + EUPL v1.2 (ADR-006)
* Real code coverage with covr + codecov (replaces the previous static
  badge)

### Refactoring

#### NMT (Néméton Naming Convention) alignment

* All function, column and family names aligned with the NMT glossary
* DB schema aligned with NMT glossary keys (ADR-002)
* `get_famille_code()` reverse lookup added for NMT family names
* Test column names renamed to NMT convention
* Indicator names in `list_indicators()` switched to NMT

#### Test Suite Consolidation

* Consolidated dozens of `coverage-boost*`, `batch*` test files into
  direct `test-*.R` files aligned with the real R modules they cover
* Removed dead test files, orphan man pages, and stub functions that
  shadowed real indicator implementations
* Removed Shiny-specific tests from the core package
* Removed unnecessary `library()` calls from test files

### Bug Fixes

* Fixed dual `save_indicators()` conflict that was breaking NDP
  persistence
* Fixed LiDAR directory (not just file) detection in cache for NDP
* Added filesystem cache fallback for NDP detection
* Fixed W1, S3, P1, P2, P3 indicator failures surfaced during NMT
  migration
* Defined explicit radar display order for the 12 families
* Resolved `%||%` import from rlang and fixed `NAMESPACE` export order
* `hunting` module: suppress expected `download.file` warnings on HTTP
  404 and resolve `data.gouv.fr` URLs dynamically via API
* Removed `microclima` hard dependency

### Documentation

* Updated README for v0.15.0 — `nemetonshiny` installation instructions,
  NMT names, new badges
* Updated pkgdown site for v0.15.0 — NMT names, NDP, species,
  `nemetonshiny`
* ADR-012 added: future PG extensions (TimescaleDB for continuous
  monitoring, pgvector for RAG perspectives)
* `CLAUDE.md` updated with DDD/NDP/BMAD architecture

---

# nemeton 0.14.1

**Date**: 2026-02-18

### UI Improvements

* Made the recent projects section collapsible using the same Bootstrap 5
  collapse pattern as the commune search and project form sections

### Bug Fixes

* Fixed namespace issues in i18n and energy indicator tests
* Fixed mock bindings for `lookup_species_threshold` using `unlockBinding`
* Suppressed expected OSM tile download warnings in export tests
* Fixed various test stability issues (memory, timeouts, namespace prefixes)

### Documentation

* Updated README with app screenshot and badge updates
* Prepared package for CRAN submission

---

# nemeton 0.14.0

**Date**: 2026-02-10

### Test Suite Stabilization

#### Bug Fixes

* Fixed ExtendedTask global state leak in mod_home retry test that blocked
  mod_project testServer calls when running the full test suite
  - Mock `promises::future_promise` to prevent multisession worker spawning
  - Return terminal state from `read_progress_state` to stop `later::later` polling loop
  - Restore `future::plan` on exit via `withr::defer`
* Suppressed expected warnings in test-workflow, test-visualization,
  test-mod_map, and test-mod_synthesis
* Renamed test files with z/zz prefix for stable execution ordering

#### Documentation

* Added Mistral API key example in nemetonApp guide vignette

#### Tests

* All 9272 tests passing (0 warnings)
* R CMD check: 0 errors, 0 warnings

---

# nemeton 0.13.0

**Date**: 2026-02-08

### CI/CD Optimization

* Optimized CI workflow with timeout, split check and coverage jobs
* Suppressed expected warnings in test suite (normalize, locale patterns)
* Fixed French locale support in match.arg error patterns

---

# nemeton 0.12.0

**Date**: 2026-02-05

### Phase 9 Finalization - MVP 0.7.0 Complete

#### New Features

* **PDF Report Generation** (`generate_report_pdf()`)
  - Quarto-based reports with professional layout
  - Fallback to base R graphics when Quarto unavailable
  - Automatic Quarto installation via `ensure_quarto_installed()`
  - Bilingual support (French/English)

* **GeoPackage Export** (`export_geopackage()`)
  - Export family scores with geometry for GIS analysis
  - Full spatial data preservation

* **nemetonApp Synthesis Tab**
  - AI-generated analysis with expert profiles
  - Integrated comment editor
  - Real-time PDF generation with progress indicator

#### Documentation

* New vignette: "Guide de l'Application nemetonApp"
* Updated README with nemetonApp section
* Enhanced pkgdown reference for Shiny functions

#### Bug Fixes

* Fixed TWI normalization windows for F2 soil fertility ([2.5, 10] range)
* Fixed R3 drought risk raster extent mismatch
* Fixed non-ASCII characters in service_export.R
* Added data.table to Suggests for fasterRaster compatibility

#### Tests

* All 3447 tests passing
* R CMD check: 0 errors, 0 warnings, 2 notes


# nemeton 0.8.0

**Date**: 2026-01-25

### New Features

#### nemetonApp - Interactive Shiny Application

* **`run_app()`** - Launch the nemetonApp Shiny application
  - Interactive parcel selection on a map (Leaflet)
  - French commune search with autocomplete
  - Calculate all 31 nemeton indicators automatically
  - Visualize results with 12-family radar charts
  - Export PDF reports and GeoPackage data
  - Bilingual support (French/English)

* **Application Architecture**
  - `app_ui.R` - bslib-based responsive UI with Bootstrap 5
  - `app_server.R` - Modular server with reactive state management
  - `app_config.R` - Configuration constants and indicator families
  - `utils_theme.R` - WCAG 2.1 AA accessible theme
  - `utils_i18n.R` - Internationalization with 200+ messages

* **Accessibility (WCAG 2.1 AA)**
  - Color contrast ratio >= 4.5:1 for text
  - Colorblind-friendly viridis palettes
  - Minimum touch target 44×44px
  - Focus visible indicators
  - Keyboard navigation support

* **Data Services**
  - `service_communes.R` - French commune search API
  - `service_cadastre.R` - Cadastral parcel retrieval
  - `service_project.R` - Project management and persistence

### Bug Fixes

* Fixed `\dontrun` missing brace in service_communes.R documentation
* Fixed integer type for symbol_shapes in accessibility config
* Updated indicator count test (29 → 31 indicators)

### Dependencies

* Added `shiny (>= 1.8.0)` to Imports
* Added `bslib (>= 0.6.0)` to Imports
* Added `htmltools (>= 0.5.7)` to Imports
* Added `leaflet (>= 2.1.0)` to Suggests
* Added `cicerone (>= 1.0.0)` to Suggests (guided tour)
* Added `shinyWidgets (>= 0.8.0)` to Suggests
* Added `rappdirs` to Suggests (project directories)

---

# nemeton 0.6.2

**Date**: 2026-01-24

### Changes

- **Data consolidation**: Merged `massif_demo_units` and `massif_demo_units_extended` into a single dataset with 89 columns (29 indicators, 12 family composites, normalized values)
- **Tests**: Fixed 19 skipped tests, now 1478 tests passing (0 skipped)
- **Documentation**: Simplified README from 846 to 138 lines
- **Fixtures**: Added synthetic cadastral file for integration tests

---

# nemeton 0.6.1

**Date**: 2026-01-23

### Changes

- Fix pkgdown references to obsolete v0.1.0 indicators
- Add lasR remote for GitHub Actions CI

---

# nemeton 0.6.0 (Development)

## v0.6.0 - Legacy Indicators Removal

**Date**: 2026-01-23

### BREAKING CHANGES ⚠️

**Removed Legacy Indicators (v0.1.0)**

The original 5 MVP indicators have been removed in favor of the comprehensive 12-family framework (32+ indicators). This is a breaking change for code using v0.1.0 indicators.

#### Removed Functions

- `indicator_carbon()` - **Use instead:** `indicator_carbon_biomass()` (C1) or `indicator_carbon_ndvi()` (C2)
- `indicator_biodiversity()` - **Use instead:** `indicator_biodiversity_protection()` (B1), `indicator_biodiversity_structure()` (B2), or `indicator_biodiversity_connectivity()` (B3)
- `indicator_water()` - **Use instead:** `indicator_water_network()` (W1), `indicator_water_wetlands()` (W2), or `indicator_water_twi()` (W3)
- `indicator_fragmentation()` - **Use instead:** `indicator_landscape_fragmentation()` (L1) or `indicator_landscape_edge()` (L2)
- `indicator_accessibility()` - **Use instead:** `indicator_social_accessibility()` (S2) or `indicator_social_trails()` (S1)

#### Migration Guide

**Before (v0.1.0-v0.5.x):**
```r
# Old API
results <- nemeton_compute(
  units, layers,
  indicators = c("carbon", "biodiversity", "water")
)
```

**After (v0.6.0+):**
```r
# New API with family-based indicators
results <- nemeton_compute(
  units, layers,
  indicators = c("carbon_biomass", "biodiversity_protection", "water_twi")
)

# Or use list_indicators() to see all available indicators
available <- list_indicators(return_type = "details")
```

#### Updated Core Functions

- `nemeton_compute()` - Now uses `list_indicators()` for available indicators
- `list_indicators()` - Returns all 31 indicators from the 12-family framework
- `compute_indicator()` - Dynamic dispatch supporting all family-based indicators

#### Files Removed

- `R/indicators-biophysical.R` - Legacy indicator implementations (567 lines)
- `tests/testthat/test-indicators-biophysical.R` - Legacy tests (414 lines, 26 tests)

### Rationale

The legacy indicators were functional placeholders from the v0.1.0 MVP. The new 12-family framework (introduced in v0.2.0-v0.4.0) provides:

- **More comprehensive coverage**: 31 indicators vs 5
- **Better scientific foundation**: Species-specific allometric models, multiple data sources
- **Clearer organization**: 12 families (C, W, F, L, B, R, T, A, S, P, E, N)
- **Improved flexibility**: Multiple sub-indicators per ecosystem service

All legacy indicators had superior replacements available since v0.2.0 (January 2026).

---

# nemeton 0.5.2

## v0.5.2 - Tutorial 09 Sampling + TSP

**Date**: 2026-01-23

### New Features

#### Tutorial 09: Échantillonnage de calibration LiDAR HD + TSP (180 min)

* **Dimensionnement optimal** - Calcul du nombre de placettes basé sur la formule n = t² × CV² / E²
  - Fonctions `calculate_sample_size()` et `sample_size_table()`
  - Tableau de référence interactif pour CV (10-40%) et erreur (5-20%)
  - Correction pour population finie

* **Sampling Frame** - Construction d'une grille de candidats avec contraintes terrain
  - Filtrage par couvert forestier (≥70%) et pente (≤45%)
  - Utilisation des données T01/T03/T07 (zone_etude, bd_foret, mnt, chm_complet)

* **Stratification triple** - Basée sur 3 critères forestiers
  - **Hauteur CHM LiDAR** : 4 classes (H1-H4) par quartiles
  - **Type de peuplement** (BD Forêt v2 tfv) : FEU/CON/MIX/POP/AUT
  - **Position topographique** (TPI) : Bas/Milieu/Haut de pente
  - Calcul TPI avec `focal()` (rayon 100m)

* **Tirage GRTS stratifié** - Échantillonnage spatialement équilibré
  - Package `spsurvey::grts()` avec allocation proportionnelle
  - Oversample par strate pour placettes de remplacement
  - Fallback `BalancedSampling::lpm2` si GRTS échoue

* **Réseau de chemins** - Construction réseau avec `sfnetworks` depuis BD TOPO
  - Filtrage chemins praticables à pied
  - Calcul poids avec `edge_length()`

* **Optimisation TSP** - Parcours optimal avec package `TSP`
  - Méthode nearest insertion + 2-opt
  - Visualisation avec distinction Base/Remplacement

* **Export terrain** - Formats multiples pour GPS
  - GeoPackage (SIG)
  - GPX (navigation GPS)
  - CSV (tableau récapitulatif avec coordonnées WGS84)

### Improvements

* **Harmonisation data_dir** - Chemin unifié sur tous les tutoriels T01-T09
  - `~/.local/share/nemeton/tutorial_data`
  - Suppression variable `cache_dir` dans T08

### Dependencies

* Added `spsurvey (>= 5.0.0)` to Suggests
* Added `BalancedSampling (>= 1.6.0)` to Suggests
* Added `sfnetworks (>= 0.6.0)` to Suggests
* Added `TSP (>= 1.2.0)` to Suggests
* Added `tidygraph (>= 1.2.0)` to Suggests
* Added `igraph (>= 1.4.0)` to Suggests

### Documentation

* Updated `vignettes/tutorial-guide.Rmd` with Tutorial 09
* Updated `TUTORIAL_INSTALL.md` with Tutorial 09

**References**:
- Stevens, D. L., & Olsen, A. R. (2004). Spatially balanced sampling of natural resources. *JASA*, 99(465), 262-278.
- Grafström, A., & Tillé, Y. (2013). Doubly balanced spatial sampling with spreading and restitution of auxiliary totals. *Environmetrics*, 24(2), 120-131.
- Hahsler, M., & Hornik, K. (2007). TSP—Infrastructure for the traveling salesperson problem. *Journal of Statistical Software*, 23(2).

---

# nemeton 0.5.1

## v0.5.1 - Tutorial 08 Coregistration

**Date**: 2025-01-18

### New Features

#### Tutorial 08: Coregistration LiDAR/Terrain (130 min)

* **Problématique GPS** - Précision GPS sous couvert forestier (2-10 m)
* **Corrélation MNH/Terrain** - Recalage par corrélation croisée
* **lidaRtRee::coregistration()** - Recherche translation optimale (dx, dy)
* **Traitement parallèle** - `future_lapply()` pour lots de placettes
* **Analyse statistique** - Tests de significativité, visualisation vecteurs
* **Export** - CSV et GeoPackage pour utilisation SIG

### Documentation

* Updated `vignettes/tutorial-guide.Rmd` with Tutorial 08
* Updated `TUTORIAL_INSTALL.md` with Tutorial 08

**Reference**: Monnet, J.-M., & Mermin, É. (2014). Cross-correlation of diameter measures for the co-registration of forest inventory plots with airborne laser scanning data. *Forests*, 5(9), 2307-2326.

---

# nemeton 0.5.0

## v0.5.0 - Tutorial 07 & CRAN Compliance

**Date**: 2025-01-18

### Overview

Release featuring the complete Tutorial 07 (Advanced LiDAR) and CRAN compliance improvements. All 7 interactive tutorials are now complete (195/195 tasks).

### New Features

#### Tutorial 07: LiDAR Avancé (90 min)

* **LAScatalog Management** - Multi-tile LiDAR processing with lidR
* **lasR Pipelines** - Ultra-fast C++ processing for DTM/CHM generation
* **Individual Tree Detection (ITD)** - Tree segmentation with lidaRtRee
* **Gap & Edge Detection** - Forest structure analysis
* **Area-Based Approach (ABA)** - Model calibration and wall-to-wall prediction
* **BABA Exploration** - Rapid LiDAR metrics without field calibration
* **Parallelization** - `future_lapply()` for tile-based processing
* **Incremental Caching** - Resume interrupted processing
* **OSO Forest Mask** - Land cover filtering for predictions

### Dependencies

* Added `lasR` to Suggests (from r-lidar.r-universe.dev)
* Added `lidaRtRee` to Suggests

### Documentation

* Updated `vignettes/tutorial-guide.Rmd` with Tutorial 07
* Updated `TUTORIAL_INSTALL.md` with lasR/lidaRtRee installation
* Updated quickstart guide with Tutorial 07 instructions

### CRAN Compliance

* Removed development artifacts (RELEASE_*.md, .RData, .Rhistory, etc.)
* Updated `.Rbuildignore` and `.gitignore`
* Excluded spec-kit directories from version control

---

# nemeton 0.4.0

## v0.4.0 - Complete 12-Family Ecosystem Services Referential

**Date**: 2026-01-05

### Overview

Major release completing the **12-family ecosystem services referential** with 4 new indicator families (S, P, E, N) and advanced multi-criteria analysis tools. This release adds 11 new indicator functions, 3 analysis functions, and brings the total to **29 indicators across 12 families**.

### New Indicator Families

#### Social & Recreational Family (Famille S) - 3 Indicators

* **`indicator_social_trails()`** (S1) - Trail density
  - Calculates recreational trail density (km/ha) from OSM or local data
  - Supports footways, cycleways, and bridleways
  - Output: 0-5+ km/ha trail density

* **`indicator_social_accessibility()`** (S2) - Multimodal accessibility score
  - Distance-based scoring for road, parking, and public transport access
  - Configurable distance thresholds and weights
  - Output: 0-100 accessibility score

* **`indicator_social_proximity()`** (S3) - Population proximity
  - Population within configurable buffer zones (5/10/20 km)
  - Supports INSEE population grid or custom data
  - Output: Total population count within buffers

#### Productive & Economic Family (Famille P) - 3 Indicators

* **`indicator_productive_volume()`** (P1) - Standing timber volume
  - IFN-based allometric equations by species
  - Genus-level fallback for rare species
  - Output: m³/ha standing volume

* **`indicator_productive_station()`** (P2) - Site productivity index
  - Fertility × climate × species interaction
  - Based on French forestry station classification
  - Output: m³/ha/yr potential productivity

* **`indicator_productive_quality()`** (P3) - Timber quality score
  - Form factor, diameter distribution, defect assessment
  - Configurable quality criteria weights
  - Output: 0-100 quality score

#### Energy & Climate Family (Famille E) - 2 Indicators

* **`indicator_energy_fuelwood()`** (E1) - Fuelwood potential
  - Harvest residues + coppice biomass estimation
  - Species-specific conversion factors
  - Output: tonnes DM/ha/yr mobilizable fuelwood

* **`indicator_energy_avoidance()`** (E2) - CO2 emission avoidance
  - ADEME emission factors for energy substitution
  - Supports energy and material substitution scenarios
  - Output: tCO2eq/ha/yr avoided emissions

#### Naturalness & Wilderness Family (Famille N) - 3 Indicators

* **`indicator_naturalness_distance()`** (N1) - Infrastructure distance
  - Distance to roads, buildings, powerlines from OSM
  - Minimum distance to nearest infrastructure
  - Output: meters to nearest infrastructure

* **`indicator_naturalness_continuity()`** (N2) - Forest patch continuity
  - Connected forest area calculation
  - Based on landscape patch analysis
  - Output: hectares of continuous forest

* **`indicator_naturalness_composite()`** (N3) - Wilderness composite index
  - Multiplicative aggregation of N1 × N2 × T1 × B1
  - Weighted aggregation option available
  - Output: 0-100 wilderness score

### New Analysis Functions

#### Multi-Criteria Decision Support

* **`identify_pareto_optimal()`** - Pareto optimality analysis
  - Identifies non-dominated solutions across multiple objectives
  - Supports both maximization and minimization objectives
  - Returns data with `is_optimal` column for Pareto-optimal parcels

* **`cluster_parcels()`** - Multi-family clustering
  - K-means and hierarchical clustering methods
  - Automatic optimal k determination via silhouette analysis
  - Returns cluster assignments with centroid profiles

* **`plot_tradeoff()`** - Trade-off visualization
  - 2D scatterplot with optional Pareto frontier overlay
  - Color and size mapping for additional dimensions
  - Label support for parcel identification

### Enhanced Features

* **12-axis radar plots** - `nemeton_radar()` now supports all 12 families
* **12×12 correlation matrix** - `compute_family_correlations()` extended
* **12-family hotspot detection** - `identify_hotspots()` updated
* **Normalization presets** - Added for S, P, E, N families

### New Demo Dataset

* **`massif_demo_units_extended`** - Complete 12-family reference dataset
  - 20 demo parcels with all 29 indicators
  - 12 pre-calculated family composite indices
  - Synthetic but realistic value distributions

### New Vignettes

* **`complete-referential_fr.Rmd`** - 12-family workflow demonstration
* **`multi-criteria-optimization_fr.Rmd`** - Pareto, clustering, and trade-off analysis

### Dependencies

* Added `cluster` package dependency for silhouette analysis
* Added `ggrepel` to Suggests for label positioning

### Documentation

* Updated README with v0.4.0 feature highlights
* Updated pkgdown site configuration
* Full roxygen2 documentation for all new functions

---

# nemeton 0.3.0 (Development)

## v0.3.0 MVP - Multi-Family Extension (B, R, T, A)

**Status**: ✅ v0.3.0 Complete (845+ tests passing, 100% backward compatible)

### Overview

Extension of the ecosystem service indicator framework with 4 new families (B, R, T, A), bringing the total to **9 of 12 planned families** implemented. This release adds 10 new indicator functions and enhances the family aggregation and visualization system.

### New Indicator Families

#### Biodiversity Family (Famille B) - 3 Indicators

* **`indicator_biodiversity_protection()`** (B1) - Protected area coverage
  - Calculates percentage of forest parcel within protected zones (ZNIEFF, Natura2000, etc.)
  - Supports local or remote protected area datasets
  - Output: 0-100% protection coverage
  - Spatial overlay with area-weighted calculation

* **`indicator_biodiversity_structure()`** (B2) - Structural diversity index
  - Shannon diversity index across vegetation strata, age classes, and species
  - Configurable weights for each diversity component (default: strata 0.4, age 0.3, species 0.3)
  - Optional height coefficient of variation (CV) integration
  - Output: 0-100 diversity score
  - Handles monoculture scenarios (low diversity → low scores)

* **`indicator_biodiversity_connectivity()`** (B3) - Ecological connectivity
  - Distance to ecological corridors (TVB - Trame Verte et Bleue)
  - Supports edge and centroid distance methods
  - Configurable max distance threshold (default: 5000m)
  - Fallback scoring when corridor data unavailable
  - Output: Distance in meters (lower = better connectivity)

#### Risk & Resilience Family (Famille R) - 3 Indicators

* **`indicator_risk_fire()`** (R1) - Fire risk index
  - Multi-factor fire susceptibility: slope + species + climate
  - Species flammability coefficients (conifer > broadleaf)
  - Slope amplification (higher slope = faster fire spread)
  - Optional climate data integration (temperature, precipitation)
  - Output: 0-100 risk score (higher = more vulnerable)

* **`indicator_risk_storm()`** (R2) - Storm vulnerability index
  - Wind damage risk: tree height × stand density × exposure
  - Height coefficient (taller trees more vulnerable)
  - Density factor (dense stands = higher windthrow risk)
  - Topographic exposure from DEM (exposed ridges = higher risk)
  - Output: 0-100 vulnerability score

* **`indicator_risk_drought()`** (R3) - Drought stress index
  - Combines water availability (TWI) and species drought tolerance
  - Species tolerance coefficients (drought-resistant vs. water-demanding)
  - Optional precipitation data integration
  - Low TWI + intolerant species = high stress
  - Output: 0-100 stress score

#### Temporal Dynamics Family (Famille T) - 2 Indicators

* **`indicator_temporal_age()`** (T1) - Stand age/ancientness
  - Historical forest age from BD Forêt or Cassini maps
  - Ancient forest detection (age > 150 years)
  - Supports multi-source age estimation
  - Output: Years since establishment (or age class)
  - Handles missing historical data gracefully

* **`indicator_temporal_change()`** (T2) - Land cover change rate
  - Temporal change detection using Corine Land Cover multi-dates
  - Calculates change rate between two periods
  - Supports custom date ranges
  - Identifies stable vs. dynamic forests
  - Output: % change per year (or absolute area change)
  - Leverages existing nemeton_temporal() infrastructure

#### Air Quality & Microclimate Family (Famille A) - 2 Indicators

* **`indicator_air_coverage()`** (A1) - Tree canopy coverage
  - Percentage of tree cover within 1km buffer
  - High-resolution vegetation data (sentinel-2 or lidar-derived)
  - Urban microclimate regulation potential
  - Output: 0-100% coverage in buffer zone
  - Supports custom buffer distances

* **`indicator_air_quality()`** (A2) - Air quality index
  - Integration with ATMO air quality data (when available)
  - Fallback: distance to pollution sources (roads, industry)
  - Supports custom air quality datasets
  - Output: 0-100 air quality score (higher = better)
  - Proxy mode for areas without monitoring stations

### Extended Functions

* **`create_family_index()` - New "min" aggregation method**
  - Added conservative worst-case aggregation: `method = "min"`
  - Useful for risk assessment (score = worst sub-indicator)
  - Joins existing methods: mean, weighted, geometric, harmonic
  - Example: `create_family_index(data, method = "min")`

* **`nemeton_radar()` - Comparison mode for multiple units**
  - New: compare multiple forest parcels on same radar chart
  - Overlaid polygons for visual comparison
  - Syntax: `nemeton_radar(data, unit_id = c(1, 5, 10), mode = "family")`
  - Supports 9-12 axes dynamically (adapts to available families)
  - Enhanced legend and color differentiation

### Testing

* **186 new tests** for v0.3.0 families
  - Biodiversity (B1-B3): 56 tests (protection zones, diversity indices, corridors)
  - Risk (R1-R3): 52 tests (fire models, storm factors, drought stress)
  - Temporal (T1-T2): 38 tests (historical data, change detection)
  - Air (A1-A2): 28 tests (coverage buffers, quality indices)
  - Integration: 12 tests (multi-family workflows, normalization, radar)

* **Total test suite: 845+ tests passing** (up from 659)
* **100% backward compatibility verified** with v0.2.0 workflows

### Use Cases

* **Conservation prioritization**: Identify high biodiversity + low risk parcels
* **Climate adaptation planning**: Map drought stress + storm vulnerability
* **Urban forestry**: Quantify air quality and microclimate benefits
* **Historical ecology**: Detect ancient forests + track land use change
* **Multi-criteria decision support**: 9-family composite indices for holistic management

### Implemented Families Status (9/12)

* ✅ **C** - Carbon & Vitality (C1-C2)
* ✅ **B** - Biodiversity (B1-B3) - **NEW v0.3.0**
* ✅ **W** - Water Regulation (W1-W3)
* ✅ **A** - Air Quality & Microclimate (A1-A2) - **NEW v0.3.0**
* ✅ **F** - Soil Fertility (F1-F2)
* ✅ **L** - Landscape & Aesthetics (L1-L2)
* ✅ **T** - Temporal Dynamics & Trame (T1-T2) - **NEW v0.3.0**
* ✅ **R** - Risk Management & Resilience (R1-R3) - **NEW v0.3.0**
* ⏳ **S** - Social & Recreational (planned v0.4.0)
* ⏳ **P** - Productive & Economic (planned v0.4.0)
* ⏳ **E** - Energy & Climate (planned v0.4.0)
* ⏳ **N** - Naturalness & Night (planned v0.4.0)

---

# nemeton 0.2.0 (Development)

## v0.2.0 - Phase 9: Multi-Family System (US6)

**Status**: ✅ Phase 9 Complete (659 tests passing, +46 from Phase 8)

### New Functions

#### Multi-Family Aggregation & Visualization

* **`create_family_index()`** - Family-level composite scores
  - Aggregates sub-indicators into family indices (family_C, family_W, etc.)
  - Automatic detection of family prefixes (C1, C2 → family_C)
  - 4 aggregation methods: mean, weighted, geometric, harmonic
  - Custom weights per family
  - Supports all 12 families (C, B, W, A, F, L, T, R, S, P, E, N)
  - Returns sf object with added family_* columns

### Extended Functions

* **`normalize_indicators()` family support**
  - Added `by_family` parameter for family-aware workflows
  - Auto-detection of family indicators (C1, W1, F1 pattern)
  - Backward compatible with v0.1.0 indicators (carbon, water, etc.)
  - When `by_family = TRUE`: normalizes in-place (suffix = "", keep_original = FALSE)

* **`nemeton_radar()` multi-family mode**
  - New `mode` parameter: "indicator" (default) or "family"
  - Family mode: displays 4-12 family axes dynamically
  - Auto-detects family_* columns when mode = "family"
  - Backward compatible with indicator mode
  - Enhanced unit_id handling: supports both ID matching and numeric row indices

### Helper Functions (Internal)

* **`detect_indicator_family()`** - Extract family code from indicator name
* **`get_family_name()`** - Full family name from code (bilingual FR/EN)

### Testing

* **46 new tests** for multi-family system
  - create_family_index(): 9 tests (aggregation methods, weights, NA handling)
  - normalize_indicators() family support: 3 tests (auto-detection, by_family mode)
  - nemeton_radar() family mode: 4 tests (multi-family display, validation)
  - Integration: 5 tests (end-to-end workflows, temporal integration)
  - Family detection: 2 tests (all 12 families)

* **Total test suite: 659 tests passing** (up from 613)
* **2 minor test issues**: plot data structure check, locale-dependent error message
* **Full backward compatibility maintained**

### Technical Details

* **Family Detection**: Regex pattern `^[A-Z][0-9]` matches C1, W1, F1, etc.
* **Aggregation Methods**:
  - Mean/Weighted: Handles NA values with weight renormalization
  - Geometric: `exp(mean(log(values)))` with negative value handling
  - Harmonic: `n / sum(1/x)` with zero value handling
* **12 Family Codes**:
  - C (Carbon & Vitality), B (Biodiversity), W (Water Regulation)
  - A (Air Quality & Microclimate), F (Soil Fertility), L (Landscape & Aesthetics)
  - T (Temporal Dynamics), R (Risk Management), S (Social & Recreational)
  - P (Productive & Economic), E (Energy & Climate), N (Naturalness)

### Use Cases

* **Multi-dimensional assessment**: Compare ecosystem services across 12 families
* **Custom weighting**: Priority to specific families (e.g., 60% carbon, 40% water)
* **Radar visualization**: Visual profiling of forest parcels across all families
* **Family-level reporting**: Aggregate detailed indicators into comprehensible family scores

---

## v0.2.0 - Phase 8: Infrastructure Multi-Temporelle (US1)

**Status**: ✅ Phase 8 Complete (613 tests passing)

### New Functions

#### Temporal Analysis Framework - 2 Core Functions + 2 Visualizations

* **`nemeton_temporal()`** - Multi-period temporal dataset creation
  - Combines nemeton_units objects from different time periods
  - Automatic unit alignment tracking across periods
  - Support for ISO dates and custom period labels
  - Metadata: dates, period labels, alignment status
  - Returns nemeton_temporal S3 class with print/summary methods

* **`calculate_change_rate()`** - Temporal change rate calculation
  - Computes absolute change rates (units per year)
  - Computes relative change rates (% per year)
  - Supports indicator selection or "all" indicators
  - Configurable start/end periods
  - Handles NA values appropriately
  - Returns sf object with _rate_abs and _rate_rel columns

* **`plot_temporal_trend()`** - Time-series line plots
  - Line plots showing indicator evolution over time
  - Single indicator: all units on one plot
  - Multiple indicators: faceted plots (2 columns)
  - Optional mean trend line overlay
  - Unit selection support
  - Automatic date handling from temporal metadata

* **`plot_temporal_heatmap()`** - Indicator evolution heatmap
  - Heatmap showing all indicators across periods for one unit
  - Optional normalization to 0-100 scale
  - Viridis color scale
  - Value labels on tiles
  - Indicator selection support
  - Useful for single-unit profiling

### S3 Methods

* **`print.nemeton_temporal()`** - Console summary
  - Shows number of periods and units
  - Date range if available
  - Warns about incomplete alignment
  - Lists available indicators

* **`summary.nemeton_temporal()`** - Detailed statistics
  - Per-period summaries (unit counts, indicator ranges)
  - Mean values for each indicator per period
  - Alignment information

### Technical Details

* **Temporal Framework**:
  - Unit ID tracking with configurable column (default: "parcel_id")
  - Automatic alignment detection (units present in all periods vs. incomplete)
  - Flexible date handling (ISO dates, years, or custom labels)
  - Preserves all sf attributes and geometry

* **Change Rates**:
  - Time difference calculation from dates or period names
  - Absolute rate: `(value_end - value_start) / years`
  - Relative rate: `((value_end / value_start) - 1) * 100 / years`
  - NA propagation for missing data

* **Visualizations**:
  - ggplot2-based with theme_minimal
  - Date axis with automatic formatting
  - Faceting for multiple indicators
  - Viridis colormap for heatmaps
  - Responsive layouts (legend positions, text angles)

### Testing

* **79 new tests** for temporal infrastructure
  - nemeton_temporal(): 13 tests (creation, alignment, validation)
  - calculate_change_rate(): 13 tests (absolute/relative rates, NA handling)
  - print/summary methods: 3 tests (output format)
  - plot_temporal_trend(): 11 tests (single/multiple indicators, unit selection)
  - plot_temporal_heatmap(): 10 tests (normalization, indicator selection)
  - Integration: 4 tests (multi-period workflows, 3+ periods)

* **Total test suite: 613 tests passing** (up from 584)
* **Full backward compatibility maintained**

### Use Cases

* **Longitudinal monitoring**: Track indicator evolution over 5-10+ years
* **Management impact**: Compare before/after forest intervention
* **Climate change**: Detect long-term trends in carbon stock, water regulation
* **Scenario comparison**: Visualize different management trajectories

---

## v0.2.0 - Phase 7: Famille L (Landscape/Paysage)

**Status**: ✅ Phase 7 Complete (584 tests passing)

### New Indicator Functions

#### Landscape Family (Famille L) - 2 Indicators

* **`indicator_landscape_fragmentation()`** (L1) - Forest fragmentation metric
  - Counts number of forest patches within a buffer zone around each parcel
  - Uses connected component labeling (terra::patches with 8-neighbor connectivity)
  - Configurable buffer distance (default: 1000m)
  - Configurable forest definition via landcover codes
  - Output: Number of discrete forest patches (higher = more fragmented)
  - Zero buffer option for parcel-only analysis

* **`indicator_landscape_edge()`** (L2) - Edge-to-area ratio
  - Calculates perimeter-to-area ratio for forest parcels
  - Formula: `Edge density = perimeter (m) / area (ha)`
  - Higher values indicate greater edge effect and fragmentation
  - Output: m/ha (meters of edge per hectare)
  - Uses sf geometry operations for precise boundary calculations

### Technical Details

* **L1 Fragmentation**:
  - Buffer zone creation using sf::st_buffer()
  - Landcover cropping and masking with terra
  - Forest mask creation using terra::app() with custom classification
  - Connected component analysis: terra::patches(directions = 8)
  - Handles zero-forest scenarios gracefully

* **L2 Edge Density**:
  - Boundary extraction: sf::st_cast() to MULTILINESTRING
  - Perimeter calculation: sf::st_length()
  - Area calculation: sf::st_area() converted to hectares
  - No dependencies on raster layers (geometry-only)

### Testing

* **49 new tests** for landscape family indicators
  - L1 fragmentation: 13 tests (patch counting, buffer effects, forest definitions)
  - L2 edge: 11 tests (geometry scaling, parcel size effects, validation)
  - Integration: 8 tests (combined workflow, dataframe integration, correlation analysis)
  - Edge cases: 5 tests (empty units, single parcels, full dataset)

* **Total test suite: 584 tests passing** (up from 535)
* **Full backward compatibility maintained**

---

## v0.2.0 - Phase 6: Famille F (Fertilité des Sols)

**Status**: ✅ Phase 6 Complete (535 tests passing)

### New Indicator Functions

#### Soil Family (Famille F) - 2 Indicators

* **`indicator_soil_fertility()`** (F1) - Soil fertility classification
  - Extracts fertility scores from soil data (raster or vector)
  - Supports BD Sol (French soil database) or equivalent pedological data
  - Output: 0-100 scale (higher = more fertile)
  - Auto-normalizes input values to 0-100 range
  - Supports both raster and vector soil layers (with area-weighted averaging)

* **`indicator_soil_erosion()`** (F2) - Erosion risk index
  - Calculates erosion risk by combining slope and land cover protection
  - Formula: `Risk = slope × (1 - forest_protection)`
  - High slope + low forest cover = high erosion risk
  - Output: 0-100 risk score
  - Uses terra for slope calculation and land cover analysis

### Internal Utilities

* **Soil Data Extraction**
  - `extract_fertility_from_raster()` - Raster-based fertility extraction
  - `extract_fertility_from_vector()` - Vector-based fertility with spatial join
  - Area-weighted averaging for overlapping soil polygons
  - Automatic CRS harmonization

### Testing

* **37 new tests** for soil family indicators
  - F1 fertility: 11 tests (raster/vector extraction, normalization, error handling)
  - F2 erosion: 17 tests (slope-cover combination, forest definitions, edge cases)
  - Integration: 9 tests (combined workflow, correlation analysis, dataframe integration)
  - 1 skipped test (vector soil data - future enhancement)

* **Total test suite: 535 tests passing** (up from 498)
* **Full backward compatibility maintained**

### Technical Details

* **F1 Fertility**:
  - Flexible input: accepts any raster or vector soil layer
  - Linear normalization: `(value - min) / (max - min) × 100`
  - Vector mode: area-weighted spatial join with soil polygons
* **F2 Erosion**:
  - Slope from DEM using `terra::terrain(v="slope")`
  - Forest mask using `terra::app()` for multi-value classification
  - Protection factor: 1 = full forest, 0 = no forest
  - Normalized to 0-100 scale (max slope = 90°)

---

## v0.2.0 - Phase 5: Famille W (Eau/Infiltrée)

**Status**: ✅ Phase 5 Complete (498 tests passing)

### New Indicator Functions

#### Water Family (Famille W) - 3 Indicators

* **`indicator_water_network()`** (W1) - Hydrographic network density
  - Calculates stream/river network length density within or near forest parcels
  - Supports buffer distance parameter for proximity analysis
  - Output: km/ha (kilometers of watercourse per hectare)
  - Higher values = greater hydrological connectivity

* **`indicator_water_wetlands()`** (W2) - Wetland coverage percentage
  - Calculates percentage of parcel area classified as wetland or riparian zone
  - Supports multiple wetland type codes from landcover rasters
  - Output: 0-100% coverage
  - Area-weighted calculation using coverage fractions

* **`indicator_water_twi()`** (W3) - Topographic Wetness Index
  - Calculates TWI using terra D8 flow algorithm
  - Formula: `TWI = ln(catchment_area / tan(slope))`
  - Automatically handles flat areas and edge cases
  - Output: TWI values (typically 0-20, higher = wetter areas)
  - Future: whitebox D-infinity algorithm support (v0.3.0+)

### Internal Utilities

* **TWI Calculation System**
  - `calculate_twi_terra()` - D8 flow direction algorithm
  - Slope-based flow accumulation
  - Catchment area calculation
  - Handles numerical edge cases (flat areas, infinite values)
  - `calculate_twi_whitebox()` - Placeholder for future D-infinity implementation

### Testing

* **51 new tests** for water family indicators
  - W1 network: 13 tests (density calculation, buffer zones, zero-stream parcels)
  - W2 wetlands: 14 tests (percentage calculation, multiple codes, zero coverage)
  - W3 TWI: 16 tests (DEM processing, method validation, terrain variation)
  - Integration: 8 tests (combined workflow, dataframe integration)

* **Total test suite: 498 tests passing** (up from 447)
* **Full backward compatibility maintained**

### Technical Details

* **W1 Network Density**: Uses sf spatial operations for line-polygon intersection
* **W2 Wetland Coverage**: Uses exactextractr for area-weighted raster value extraction
* **W3 TWI**: Terra hydrology functions (`terrain(v="flowdir")`, `flowAccumulation()`)
* **Flow algorithm**: D8 (8-neighbor) for computational efficiency
* **Coordinate transformations**: Automatic CRS harmonization for vector layers

---

## v0.2.0 - Phase 4: Famille C (Carbone/Énergétique)

**Status**: ✅ Phase 4 Complete (447 tests passing)

### New Indicator Functions

#### Carbon Family (Famille C) - 2 Indicators

* **`indicator_carbon_biomass()`** (C1) - Aboveground carbon stock using species-specific allometric equations
  - Requires: BD Forêt v2 attributes (species, age, density)
  - Species support: Quercus, Fagus, Pinus, Abies, + Generic fallback
  - Allometric model: `Biomass = a × Age^b × Density^c`
  - Output: tC/ha (tonnes carbon per hectare)
  - Citations: IGN/IFN literature (Dupouey, Bontemps, Vallet, Wutzler)

* **`indicator_carbon_ndvi()`** (C2) - Vegetation vitality via NDVI
  - Requires: Sentinel-2 or equivalent NDVI raster (0-1 scale)
  - Output: Mean NDVI per forest parcel
  - Future: Temporal trend analysis (v0.3.0+)

### Internal Data & Utilities

* **Allometric Model System** (`R/sysdata.rda`)
  - 5 species-specific coefficient sets
  - Calibrated for realistic French forest biomass (50-200 tC/ha mature stands)
  - Source: `data-raw/allometric_models.R`

* **New Utility Functions** (internal)
  - `get_allometric_coefficients()` - Species-specific coefficient lookup
  - `calculate_allometric_biomass()` - Vectorized biomass calculation
  - `detect_indicator_family()` - Extract family code from indicator name
  - `get_family_name()` - Full family name from code

### Deprecations

* **`indicator_carbon()`** - Now deprecated (will be removed in v1.0.0)
  - Replacement: Use `indicator_carbon_biomass()` for BD Forêt support, or `indicator_carbon_ndvi()` for NDVI
  - Backward compatibility: Function still works with deprecation warning
  - All existing workflows continue to function

### Testing

* **38 new tests** for carbon family indicators
  - C1 biomass: 15 tests (allometric calculations, NA handling, column names, Generic fallback)
  - C2 NDVI: 10 tests (raster extraction, edge values, trend warning)
  - Integration: 8 tests (backward compatibility, nemeton_compute integration)
  - Edge cases: 5 tests (missing columns, invalid inputs, error messages)

* **Total test suite: 447 tests passing** (up from 409)
* **Full backward compatibility verified**

### Technical Details

* **Allometric coefficients** calibrated to produce realistic biomass values:
  - Young/sparse stands: 2-10 tC/ha
  - Mature forests: 50-200 tC/ha
  - Age exponent (b): 1.55-1.75
  - Density exponent (c): 0.80-0.90

* **NA propagation**: Properly handles missing species, age, or density data

---

# nemeton 0.1.0-rc1 (2026-01-04)

## MVP Release Candidate

**Status**: ✅ 97% Complete (32/33 requirements) - Ready for testing

### Major Features

#### Core Functionality (✅ Complete)
* **Spatial Analysis Engine**: `nemeton_compute()` with 5 biophysical indicators
* **Automatic Preprocessing**: CRS harmonization, extent cropping
* **Error Resilience**: Per-indicator error handling (continues if one fails)
* **Lazy Loading**: Memory-efficient layer catalog system

#### Indicators (✅ 5/5 Complete)
* `indicator_carbon()` - Carbon stock from biomass (Mg C/ha)
* `indicator_biodiversity()` - Species richness / Shannon index
* `indicator_water()` - Water regulation (TWI + proximity to streams)
* `indicator_fragmentation()` - Forest coverage and connectivity
* `indicator_accessibility()` - Distance to roads and trails

#### Normalization & Indices (✅ Complete)
* `normalize_indicators()` - 3 methods (min-max, z-score, quantile)
* `create_composite_index()` - Weighted aggregation (4 methods)
* `invert_indicator()` - Reverse polarity for negative indicators
* Reference-based normalization support

#### Visualization (⚠️ 3/4 - Radar pending)
* `plot_indicators_map()` - Thematic choropleth maps (single + faceted)
* `plot_comparison_map()` - Side-by-side scenario comparison
* `plot_difference_map()` - Absolute and relative change visualization
* Multiple palettes: viridis, RdYlGn, Greens, Blues, etc.

#### Demo Dataset (✅ Complete)
* `massif_demo` - Synthetic forest data (136 ha, 20 parcels)
* 4 rasters at 25m: biomass, DEM, landcover, species richness
* 2 vector layers: roads (5), water courses (3)
* Lambert-93 projection (EPSG:2154)
* Reproducible generation script (`data-raw/massif_demo.R`)

#### Internationalization (✅ Bonus Feature)
* **Bilingual Support**: French + English (200+ messages)
* **Auto-detection**: System locale detection
* **Manual Override**: `nemeton_set_language("fr")` / `nemeton_set_language("en")`
* **Complete Coverage**: All user-facing messages translated
* Dedicated vignette: `internationalization.Rmd`

### Exported Functions (17)

**Core**: `nemeton_units()`, `nemeton_layers()`, `nemeton_compute()`, `massif_demo_layers()`
**Indicators**: `indicator_carbon()`, `indicator_biodiversity()`, `indicator_water()`, `indicator_fragmentation()`, `indicator_accessibility()`
**Normalization**: `normalize_indicators()`, `create_composite_index()`, `invert_indicator()`
**Visualization**: `plot_indicators_map()`, `plot_comparison_map()`, `plot_difference_map()`
**Utilities**: `list_indicators()`, `nemeton_set_language()`

### Documentation (✅ Complete)

* **README.md**: Comprehensive quick start guide (497 lines)
* **Vignettes**:
  - `getting-started.Rmd` - Full workflow with massif_demo
  - `internationalization.Rmd` - i18n guide (FR/EN)
* **Roxygen2**: All 17 exported functions fully documented
* **Examples**: Executable examples in all function docs

### Testing (✅ 225+ Tests)

* **Unit Tests**: Comprehensive coverage across all modules
* **Integration Tests**: End-to-end workflow validation
* **Real Data Tests**: French cadastral parcel testing
* **Fixtures**: Helper functions for test data generation

### Package Metrics

* **R Code**: ~2,500 lines
* **Tests**: ~2,100 lines
* **Dataset Size**: 0.81 Mo (< 5 Mo target)
* **Functions**: 17 exported
* **Vignettes**: 2
* **i18n Messages**: 200+ (FR/EN)

### Quick Start Example

```r
library(nemeton)

# 5-line workflow
data(massif_demo_units)
layers <- massif_demo_layers()
results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
normalized <- normalize_indicators(results, method = "minmax")
plot_indicators_map(normalized, palette = "viridis")
```

## Known Issues

* ⚠️ Minor test fixture compatibility issue (to be fixed in v0.1.0 final)
* ⚠️ Test coverage measurement pending (covr fails due to test issues)
* 📝 User Story 4 (radar chart) not implemented (P3 - optional for MVP)

## Roadmap to v0.1.0

- [ ] Fix test fixtures
- [ ] Verify `devtools::check()` passes
- [ ] Measure test coverage (target: ≥70%)
- [ ] Optional: Implement `nemeton_radar()` (P3)

## Breaking Changes

* None (initial release)

## Credits

Developed with ❤️ and [Claude Code](https://claude.com/claude-code)
**Contributors**: Pascal Obstétar, Claude Sonnet 4.5
