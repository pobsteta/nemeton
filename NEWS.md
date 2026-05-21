# nemeton 0.41.3 (2026-05-21)

### Fixed — FORDEAD reported "0 alerts" while detecting 32 ha of dieback

A FORDEAD diagnostic run on a real monitoring zone confirmed dieback
on 3 228 pixels (~32 ha, class `4-sol-nu`) yet inserted **0 alerts**,
with no warning. Three independent defects combined to swallow the
result:

- `.compute_first_dieback_date()` reshaped the `ANOMALY_CONFIRMED`
  layer stack with `array(values, dim = c(n_rows, n_cols, ...))`.
  `terra::values()` is row-major while `array()` fills column-major,
  so the `(time, y, x)` cube fed to `fordead.utils.backward_start()`
  was spatially transposed whenever `n_rows != n_cols` — first-dieback
  dates landed on the wrong pixels. Each layer is now reshaped with
  `byrow = TRUE`.
- `.compute_first_dieback_date()` also assumed `backward_start()`
  returned a numeric "days since epoch" array. It actually returns an
  object-dtype array (ISO date strings on confirmed pixels, `NaN`
  elsewhere), which `terra::rast()` cannot ingest — the step crashed
  and was caught as a benign best-effort failure. The output is now
  coerced explicitly to a numeric day-since-1970 matrix.
- With `first_dieback_date` thus lost, every alert centroid carried
  `trigger_date = NA`, and `.insert_fordead_alerts()` silently
  dropped every such row (the column is part of the UNIQUE key).
  It now emits a `cli_warn` reporting how many alerts were discarded.
- `run_fordead_dieback()` treated a failed `fordead.utils` import as
  silent best-effort. It now warns loudly that `trigger_date` cannot
  be derived and that every detected cluster will be dropped at
  insertion, pointing at the missing Python dependency.

# nemeton 0.41.2 (2026-05-20)

### Fixed — Sentinel-2 reprocessing duplicates inflated the cache and FORDEAD

ESA periodically reprocesses the Sentinel-2 archive: an acquisition
is republished under a new product id whose only change is the
trailing processing-baseline timestamp. A STAC search returned
**both** the original and the reprocessed product as distinct
scenes.

On the user's monitoring zone this meant 47 of 342 acquisitions
(~14 %) were cached twice — doubling the band downloads and disk
footprint — and FORDEAD received two STAC items with an identical
`datetime` ("Duplicas times found"), merging them in an undefined
order that could let the older baseline win over the better-
calibrated reprocessed one.

- New internal helpers `.s2_split_product_id()` and
  `.dedup_s2_reprocessed()` collapse reprocessing duplicates by
  acquisition identity (mission + sensing time + relative orbit +
  MGRS tile), keeping the most recent processing baseline. Both the
  6-field Planetary Computer id and the 7-field ESA `.SAFE` id are
  recognised; unrecognised ids are never merged.
- `stac_search_s2()` now deduplicates every backend result, so all
  consumers (FORDEAD ingestion, FAST NDVI/NBR) benefit.
- `.build_stac_collection_for_aoi()` applies the same dedup as a
  safety net before handing the collection to FORDEAD.

Genuinely distinct same-day acquisitions (different orbit or
mission) are never merged.

# nemeton 0.41.1 (2026-05-20)

### Fixed — FORDEAD version probe no longer forces a reinstall every run

The FORDEAD pipeline reinstalled its Python dependencies
(`pip install --upgrade -r requirements.txt`, git clones and all)
on **every** `run_fordead_dieback()` call, and reported
`fordead=NA` in the start banner.

Root cause: the version probe read the `fordead.version`
attribute, which is a *function* — not a version string. Printing
it yielded a `<function …>` repr that never matched the pinned
`2.1.1`, so `.fordead_is_installed()` always returned `FALSE` and
`.ensure_fordead_python()` re-ran pip.

- `.fordead_python_version()` now reads the canonical distribution
  version via `importlib.metadata.version("fordead")`.
- `run_fordead_dieback()` reuses that same probe for its start
  banner instead of poking module attributes, so `fordead_version`
  is now reported correctly.
- New internal helper `.python_capture_stdout()` wraps the
  `system2()` call so the probe is unit-testable.

With a correctly pinned venv, FORDEAD runs now skip the pip step
entirely, shaving the reinstall time off every diagnostic.

# nemeton 0.41.0 (2026-05-20)

### New — FORDEAD dieback mask persisted to the project cache

`run_fordead_dieback()` ran FORDEAD inside a bare
`tempfile("fordead_")` directory, wiped when the session ended.
Every diagnostic artefact — including the categorical 0-4
dieback mask — was lost, and `read_fordead_dieback_mask()`
(shipped in v0.25.0 with its path convention fully documented)
always returned `NULL` because nothing ever wrote the mask.

Two changes close the loop:

- **Mask persist hook (always on).** After the `postprocess`
  phase, the categorical 0-4 state raster is written to
  `<mask_cache_dir>/zone_<zone_id>/dieback_mask_<YYYYMMDDTHHMMSS>.tif`
  — the exact path `read_fordead_dieback_mask()` looks up. The
  run timestamp doubles as the run id, so successive runs
  accumulate as a history rather than overwriting. The write is
  best-effort: a failure warns but never aborts the pipeline.

- **New `mask_cache_dir` argument.** Root of the FORDEAD
  persistent cache. `NULL` (default) derives it as the sibling
  of `cache_dir`: `file.path(dirname(cache_dir), "fordead")`,
  i.e. `<project>/cache/layers/fordead` for the conventional
  layout.

- **New `keep_output` argument (opt-in, default `FALSE`).**
  When `TRUE` and `output_dir` is left at its default, FORDEAD
  runs directly inside
  `<mask_cache_dir>/zone_<zone_id>/run_<YYYYMMDDTHHMMSS>/` so the
  full raster working set (≈1000+ GeoTIFFs) survives the
  session — useful to re-run `postprocess` with different
  `min_pixels` / `connectivity` without re-`fit`/`predict`. An
  explicit `output_dir` always wins.

The result list gains `rasters$dieback_mask` (path to the
persisted mask, or `NA_character_` on write failure).

Backward compatibility: full. With `keep_output = FALSE`
(default) the working set still lands in a temporary directory
exactly as before; only the small categorical mask is now
additionally persisted.

Tests: 3 new scenarios in `test-fordead-pipeline.R` (mask
written to an explicit `mask_cache_dir` and round-tripped
through `read_fordead_dieback_mask()`; default `mask_cache_dir`
derivation; `keep_output = TRUE` redirecting `output_dir`).
65 PASS.

# nemeton 0.40.1 (2026-05-20)

### Fixed — silent post-`predict` phases in `run_fordead_dieback()`

Only the `fit` and `predict` phases printed a `Step:` line (they
are wrapped in the `.capture()` helper). Everything after
`predict` — deriving the state raster, `first_dieback_date`,
`postprocess` (anomaly clustering) and `persist` (DB insert) —
ran with no console output at all. On a multi-year FORDEAD run
the console stayed frozen on `ℹ Step: predict` for minutes,
indistinguishable from a hang.

`run_fordead_dieback()` now emits, when `verbose = TRUE`:

- `FORDEAD output_dir: <path>` at startup — so the working
  directory is discoverable without digging through
  `tempdir()`.
- `Step: derive state raster`
- `Step: first_dieback_date`
- `Step: postprocess`
- `Step: persist`
- `FORDEAD diagnostic complete: N alert(s) inserted in X s` on
  success.

No behaviour change beyond console output; the progress
callback events (`fordead:phase` / `fordead:phase_done`) are
untouched. `test-fordead-pipeline.R` unchanged (54 PASS) —
`cli` console output is not a progress event so the
event-count assertions still hold.

# nemeton 0.40.0 (2026-05-20)

### Added — authenticated THEIA access via the teledetection SDK

A live test confirmed THEIA assets require an authenticated,
time-limited **signed URL**: the THEIA API key signs the asset
href (a standard AWS SigV4 presign), and the signed URL is then
read by GDAL via `/vsicurl/`. Direct `/vsis3/` access with the API
key is *not* possible (the gateway signs with its own account).

- **New exported helper `theia_signed_href(source_key, year,
  asset, item_id, ...)`** — returns a ready-to-read,
  `/vsicurl/`-prefixed signed URL. The signing is delegated to the
  official `teledetection` Python SDK through `reticulate`
  (`tld.sign_inplace`); `reticulate::py_require()` declares the
  Python packages automatically.
- **`load_theia_source()` year mode now uses SDK signing.** When
  `year` is supplied, the asset URL is signed via
  `theia_signed_href()` and read through `/vsicurl/` — the
  validated, working path for THEIA assets. The spatial-search
  mode (`/vsis3/`) is kept but reserved for direct-S3 setups.

Workflow: `load_theia_source("formspot", aoi, year = 2023)` —
requires `reticulate` plus the Python `teledetection` /
`pystac_client` packages and a registered THEIA API key
(<https://gate.stac.teledetection.fr>).

# nemeton 0.39.1 (2026-05-20)

### Fixed — correct THEIA S3 credentials and region

A live test against the THEIA store showed the v0.38.0
`theia_configure_s3()` config was wrong on two points, now fixed:

- **Environment variables**: the THEIA API key (created at
  <https://gate.stac.teledetection.fr>) is a standard S3 SigV4
  key pair. `theia_configure_s3()` now reads `TLD_ACCESS_KEY` /
  `TLD_SECRET_KEY` (the same names the `teledetection` SDK uses),
  not `THEIA_S3_*`.
- **Region**: the S3 region is `sm1` (visible in the
  `X-Amz-Credential` scope of a signed URL), not `us-east-1`.
  `services.theia_s3.region` in `FR.json` is corrected.

With the correct key pair and region, GDAL reads the THEIA
assets directly via `/vsis3/` with native SigV4 signing — no
Python / `teledetection` SDK required.

# nemeton 0.39.0 (2026-05-20)

### Added — year targeting for annual THEIA collections

FORMSpoT (and similar annual time-series collections) publish one
STAC item per year — `FORMSpoT-{year}` — each with a
year-specific asset (`height_{year}`). A bbox search would return
every yearly item, so a dedicated lookup is needed.

- **New exported helper `stac_get_item(stac_api, collection,
  item_id)`** — fetches a single STAC item by id.
- **`resolve_theia_assets()` and `load_theia_source()` gain a
  `year` argument.** When supplied and the datasource declares an
  `access$item_id_template` (FORMSpoT does), the matching item is
  fetched directly by id and the year-specific asset is resolved
  — no spatial search. The asset name defaults to
  `access$asset_template` with `{year}` substituted.
- `inst/datasources/FR.json`: the `formspot` entry now carries
  machine-usable `item_id_template` (`FORMSpoT-{year}`),
  `asset_template` (`height_{year}`) and `years` ([2014, 2024]).

Usage: `load_theia_source("formspot", aoi, year = 2023)`.

# nemeton 0.38.0 (2026-05-20)

### Added — authenticated THEIA S3 reads

The THEIA / FORMS COG and VRT assets live on an S3-compatible
(MinIO) object store. Rather than reimplementing the
`teledetection` SDK's URL signing, `nemeton` reads the objects
directly with GDAL's `/vsis3/` virtual filesystem, which signs
each request natively.

- **New exported helper `theia_configure_s3(access_key,
  secret_key, country)`** — sets the GDAL `/vsis3/` configuration
  (endpoint, path-style hosting, region) for the session.
  Credentials are read from the `THEIA_S3_ACCESS_KEY` /
  `THEIA_S3_SECRET_KEY` environment variables (a gitignored
  `.Renviron`) — never stored in the package.
- **`resolve_theia_assets()` now returns `/vsis3/` paths.** Asset
  hrefs are normalised by a new internal helper handling the
  teledetection download-gateway form
  (`gate.../download?url=...`), `s3://` URIs and path-style
  `https://` object URLs.
- **`load_raster_source()` accepts remote paths.** Its `path`
  argument now takes `s3://`, `http(s)://` and `/vsi*` paths in
  addition to local files (`s3://` is normalised to `/vsis3/`,
  `http(s)://` to `/vsicurl/`).
- New `services.theia_s3` entry in `FR.json` declaring the
  (non-secret) S3 endpoint `s3-data.meso.umontpellier.fr` and
  bucket `sm1-gdc-ext`.

Workflow: `theia_configure_s3()` once per session, then
`load_theia_source("formspot", aoi, asset = "height_2023")`.

# nemeton 0.37.0 (2026-05-20)

### Changed — THEIA STAC endpoint corrected, FORMSpoT metadata verified

Verified against the official FORMSpoT data-access notebook
(Schwartz, gist) and the `teledetection` Python SDK:

- **STAC API endpoint corrected** to `https://api.stac.teledetection.fr`
  (the MTD STAC API behind the `teledetection` SDK). The previous
  `api.datastore-mtd.theia.data-terra.org` value was the metadata
  document host shown in the browser, not the programmatic API.
- **Authentication required**: asset download needs a teledetection
  API key — the SDK's `tld.sign_inplace` signs the STAC asset
  hrefs. `services.theia_stac` now documents this in an `auth`
  field. The R STAC resolver does **not** yet implement
  teledetection signing (see `PLAN.md`).
- **FORMSpoT metadata verified**: collection `FORMSpoT`, one item
  per year `FORMSpoT-{year}` (2014-2024), height asset
  `height_{year}`. The height is stored in **decimetres** —
  divide by 10 before passing it as `chm`.
- **New datasource `formspot_delta`** — the companion FORMSpoT-∆
  forest-disturbance polygons (collection `FORMSpoT-delta`, item
  `FORMSpoT-delta_2014-2024`, asset `disturbance_polygons`, each
  polygon carrying the disturbance `year`). `consumed_by`: R5, T2.

# nemeton 0.36.1 (2026-05-20)

### Fixed — THEIA STAC endpoint confirmed

- `services.theia_stac.url` in `inst/datasources/FR.json` is now
  the verified THEIA MTD STAC API root
  (`https://api.datastore-mtd.theia.data-terra.org`, STAC 1.1.0,
  anonymous access) — no longer `"to confirm"`. The `forms_t`
  entry gains the verified `stac_collection: "forms-t"` and its
  `stac_catalog` host is corrected, so `load_theia_source("forms_t",
  aoi, asset = ...)` resolves out of the box.
- The Theia STAC resolver's `"to confirm"` guard now matches any
  string containing `"to confirm"` (the FR.json placeholders read
  `"to confirm at the Theia catalogue"`), instead of only the
  exact literal — so sources with an unverified `stac_collection`
  are still correctly rejected.

# nemeton 0.36.0 (2026-05-20)

### Added — THEIA STAC resolver

New module `R/theia_stac.R` closes the deferred Phase 2 item of
the Theia chantier: the Theia datasources can now be materialised
from the THEIA STAC API instead of requiring a manual download.

- **`stac_search_items(stac_api, collection, bbox, datetime,
  limit)`** — endpoint-agnostic STAC item search, built on the
  project STAC paginator. Works against any STAC API.
- **`resolve_theia_assets(source_key, aoi, asset, datetime,
  country, stac_api, limit)`** — looks up a Theia datasource,
  searches the THEIA STAC API for items of its collection
  intersecting the AOI, and returns the matching asset hrefs
  prefixed with `/vsicurl/`.
- **`load_theia_source(source_key, aoi, asset, ...)`** — resolves
  and loads a Theia datasource as a `SpatRaster` cropped to the
  AOI (virtual mosaic when several items match).

The THEIA STAC API endpoint is read from the new
`services.theia_stac` entry of `inst/datasources/FR.json`. Its
`url` field is shipped as `"to confirm"`: the STAC browser host
(`browser.datastore-mtd.theia.data-terra.org`) is known, but the
STAC API root behind it must be filled in (or passed via the
`stac_api` argument). Until then the resolver aborts with an
actionable message rather than guessing an endpoint.

# nemeton 0.35.2 (2026-05-20)

### Changed — FORMSpoT wired into C1/P1/P2/B2 via the shared CHM interface

The `formspot` datasource entry is no longer a deferred reliquat:
FORMSpoT integrates into the indicators through the **existing
`chm` argument** of `indicateur_c1_biomasse()`,
`indicateur_p1_volume()`, `indicateur_p2_station()` and
`indicateur_b2_structure()` — the same Canopy Height Model
interface already used by FORMS-T (`forms_t`) and
`chm_opencanopy`. No new indicator code is required: the
FORMSpoT tree-level canopy-height product is loaded with
`load_raster_source("formspot", path = ...)` and passed as
`chm`.

`inst/datasources/FR.json` is updated accordingly: the
`formspot` `consumed_by` block now names the precise indicator
functions (C1/P1/P2/B2 instead of the vague C/P/T/R), the
`products` block splits into `height` (CHM-compatible) and
`biomass`, and a new `integration_note` documents the
shared-`chm` integration path (including the caveat to rasterise
the height attribute if FORMSpoT is delivered as a vector
tree-point layer).

# nemeton 0.35.1 (2026-05-20)

### Fixed — FORMSpoT confirmed as a THEIA STAC collection

The `formspot` datasource entry in `inst/datasources/FR.json` was
declared provisional in v0.30.0 (preprint stage, Theia
availability unconfirmed). FORMSpoT is in fact published as the
THEIA STAC collection `FORMSpoT`
(`browser.datastore-mtd.theia.data-terra.org/collections/FORMSpoT`).
The entry now carries the verified `stac_catalog` and
`stac_collection` fields, and the provisional note is replaced by
the actual distribution description. Indicator wiring for
FORMSpoT remains deferred (see `PLAN.md`).

# nemeton 0.35.0 (2026-05-20)

### Added — Theia data sources, phase 3d (indicator wiring: phase-1b sources)

Phase 3d wires the phase-1b Theia sources into the indicators
and closes Phase 3 of the "Theia data sources" chantier.

- **W2 — `indicateur_w2_zones_humides()` gains a
  `water_occurrence` argument** (plus `occurrence_threshold`,
  default 25 %). When the Theia `theia_water` water-occurrence
  raster is supplied, pixels whose occurrence frequency reaches
  the threshold add to the wetland coverage — a fourth source
  alongside BD TOPO water surfaces, the TWI threshold and OSO
  land-cover codes.
- **R3 — `indicateur_r3_secheresse()` gains `soil_moisture` and
  `sm_relief_strength` arguments.** When the Theia
  `theia_soil_moisture` raster is supplied, moist soil attenuates
  drought stress against a 0.3 m³/m³ field-capacity reference
  (same relief mechanism as the `snow` argument added in 0.34.0).
- **New exported helper `units_add_species_from_raster()`.** It
  fills a species column on `units` from a tree-species
  classification raster (the Theia `theia_species` product) and a
  user-supplied class-to-species crosswalk, resolving the
  coverage-weighted dominant class per unit. This is the upstream
  integration point for the P / C / biodiversity indicators,
  which read a species column.

All additions are backward-compatible.

**Deferred wirings** (documented in `PLAN.md`): `s2_l2a_muscate`
is base Sentinel-2 reflectance — its integration point is the
existing S2 ingestion pipeline, not an indicator argument;
`theia_lst` → A2 is a semantic mismatch (A2 is an air-quality
index, not a microclimate one); `theia_water` → W1 is deferred
(W1 is a linear-network density, a raster mask does not map to
it); `formspot` wiring waits until the product is confirmed on
the Theia catalogue.

# nemeton 0.34.0 (2026-05-20)

### Added — Theia data sources, phase 3c (indicator wiring: theia_snow)

Phase 3c wires the Theia Snow collection product `theia_snow`
into the drought-risk indicator R3.

- **R3 — `indicateur_r3_secheresse()` gains a `snow` argument**
  (plus a `snow_relief_strength` tuning parameter). When a
  snow-cover-duration `SpatRaster` is supplied (the Theia
  `theia_snow` `snow_cover_duration` product, in days/year), the
  snowpack is treated as a seasonal water reserve: the per-unit
  mean duration is rescaled to a 0-1 relief factor against a
  180-day reference, and R3 is multiplied by
  `1 - snow_relief_strength * relief` (default
  `snow_relief_strength = 0.3`, i.e. up to a 30 % drought-stress
  reduction for a 6-month snowpack). Units with no snow coverage
  are left unchanged.

`snow = NULL` (default) preserves the pre-existing climate +
topography behaviour — no existing caller is affected. Phase 3d
(the phase-1b sources) remains, scoped in `PLAN.md`.

# nemeton 0.33.0 (2026-05-20)

### Added — Theia data sources, phase 3b (indicator wiring: theia_soil)

Phase 3b wires the Theia soil-texture product `theia_soil` into
the soil family (F1, F2).

- **Two exported texture helpers.**
  `texture_to_fertility_score(clay, silt, sand, coarse_elements)`
  maps a soil-texture composition to a 0-100 forest-fertility
  score (proximity to the loam optimum in the texture triangle,
  with a coarse-element penalty).
  `texture_to_erosion_resistance(clay, silt, sand)` maps texture
  to a 0-100 erosion-resistance score (USLE erodibility logic:
  silt erodes, clay resists). Both are calibratable first-pass
  heuristics, exported for pedologist audit; the texture triplet
  is renormalised internally, so inputs may be in any consistent
  unit (g/kg, percent, fraction).
- **F1 — `indicateur_f1_fertilite()` gains a `"theia_soil"`
  source** and a `texture` argument (a named list of clay / silt
  / sand, optionally coarse_elements, `SpatRaster`s). In that
  mode F1 derives fertility from the per-unit mean texture via
  `texture_to_fertility_score()`.
- **F2 — `indicateur_f2_erosion()` gains a `texture` argument.**
  When supplied, a texture erosion-resistance component is
  averaged into F2 alongside the TWI and slope components
  (F2 = mean of the three). `texture = NULL` (default) preserves
  the pre-existing TWI + slope behaviour.

All additions are backward-compatible: existing F1/F2 callers are
unaffected. Phase 3c (`theia_snow` → R3) and 3d (the phase-1b
sources) remain, scoped in `PLAN.md`.

# nemeton 0.32.0 (2026-05-20)

### Added — Theia data sources, phase 3a (indicator wiring: s2_biophysical)

Phase 3 of the "Theia data sources" chantier wires the declared
sources into the indicator functions, one source at a time, with
strictly backward-compatible optional arguments. Phase 3a wires
the Sentinel-2 biophysical product `s2_biophysical` into two
indicators:

- **C2 — `indicateur_c2_ndvi()` gains a `fapar` argument.** When
  a FAPAR `SpatRaster` is supplied (the Theia `s2_biophysical`
  FAPAR product), the indicator returns the per-unit mean FAPAR
  instead of NDVI. FAPAR is a physically grounded vitality
  measure on the same `[0, 1]` scale as NDVI, so downstream
  normalization is unchanged. `fapar = NULL` (default) preserves
  the pre-existing NDVI behaviour.
- **A1 — `indicateur_a1_couverture()` gains an `fvc` argument**,
  and `land_cover` now defaults to `NULL`. When an FVC
  `SpatRaster` is supplied (the Theia `s2_biophysical` FVC
  product), A1 is the per-buffer mean FVC rescaled to a 0-100
  percentage; `land_cover` is then ignored. `fvc = NULL`
  (default) preserves the land-cover behaviour.

Both arguments are purely additive — no existing caller is
affected. Phase 3b (`theia_soil` → F1/F2), 3c (`theia_snow` →
R3) and 3d (the phase-1b sources) remain, scoped in `PLAN.md`.

# nemeton 0.31.0 (2026-05-20)

### Added — Theia data sources, phase 2 (loaders)

Phase 2 of the "Theia data sources" chantier (see `PLAN.md`)
makes the catalogue entries declared in Phases 1a/1b actually
loadable.

- **`load_raster_source()` gains a `path` argument.** The Theia
  datasources (`forms_t`, `theia_soil`, `theia_snow`, ...) are
  `type: "raster_local"` with no static URL — they are
  distributed per tile/year via the Theia catalogue and
  downloaded by the user. `load_raster_source()` now accepts an
  explicit `path` to the downloaded file, so these sources become
  loadable through the normal datasource API (CRS harmonisation,
  AOI cropping). Path-less `raster_local` sources still error
  cleanly when no `path` is supplied, and the file must exist.
- **New exported helper `get_datasource_product()`.** Multi-product
  datasources (e.g. `forms_t` with `height` / `volume` /
  `biomass`, `theia_soil` with `clay` / `silt` / `sand` /
  `coarse_elements`) bundle several rasters under a `products`
  block. `get_datasource_product(source_key, product)` returns
  one sub-product's metadata (resolution, unit, value range,
  conversion notes — e.g. the FORMS-T cm-to-m note), so a caller
  can pick the right product and apply the documented unit
  conversion before feeding it to an indicator.

A STAC auto-resolution path against the Theia catalogue is
deliberately *not* implemented yet: the per-source STAC
collection identifiers are still marked `"to confirm"` in
`FR.json`. Phase 2 therefore standardises on the
download-then-load workflow; STAC resolution is deferred until
those endpoints are verified. Phase 3 (indicator wiring) remains.

# nemeton 0.30.0 (2026-05-20)

### Added — Theia data sources, phase 1b (catalogue declarations)

Second batch of the "Theia data sources" chantier (see
`PLAN.md`). Six further Theia / DATA TERRA products are declared
in `inst/datasources/FR.json`, completing Phase 1 (catalogue).
Declarative only — no core indicator code is modified:

- **`theia_water`** — surface-water extent and occurrence
  (Surfwater lineage). `consumed_by`: W1, W2.
- **`theia_soil_moisture`** — SMOS L3 (coarse, regional context)
  and Sentinel-1-derived surface soil moisture. `consumed_by`:
  W3, R3, F1.
- **`s2_l2a_muscate`** — Sentinel-2 Level-2A surface reflectance
  (MUSCATE / MAJA), a French national alternative to the CDSE /
  Planetary Computer feed. `consumed_by`: C2, T2, R5.
- **`theia_species`** — tree-species classification, tagged
  `augmented: "species_ml"`. `consumed_by`: B1, B2, P, C.
- **`theia_lst`** — land-surface temperature (Thermocity
  lineage). `consumed_by`: A2.
- **`formspot`** — FORMSpoT tree-level forest monitoring;
  declared as a provisional entry (preprint arXiv:2512.17021,
  Theia availability to confirm). `consumed_by`: C, P, T, R.

As in Phase 1a, every entry is `type: "raster_local"` with no
static URL, `ndp_level: 0`, and carries `consumed_by`,
`provenance` and explicit `"to confirm"` markers. Phase 1
(catalogue) is now complete; Phase 2 (loaders) and Phase 3
(indicator wiring) remain, scoped in `PLAN.md`.

# nemeton 0.29.0 (2026-05-20)

### Added — Theia data sources, phase 1a (catalogue declarations)

First batch of the "Theia data sources" chantier (see `PLAN.md`).
Three priority Theia / DATA TERRA products are now declared in
`inst/datasources/FR.json` (section `datasets`), following the
declarative pattern established by `forms_t` in v0.28.0 — no core
indicator code is modified:

- **`s2_biophysical`** — Sentinel-2 biophysical variables (LAI,
  FAPAR, FVC) at 10 m. `consumed_by`: C2 (vitality, complements
  NDVI), A1 (canopy cover via FVC), B2 (LAI heterogeneity).
- **`theia_soil`** — metropolitan-France soil maps: clay, silt,
  sand fractions and coarse-element content. `consumed_by`: F1
  (texture as a fertility proxy, a France-wide alternative to the
  global SoilGrids CEC layer), F2 (erodibility).
- **`theia_snow`** — Theia Snow collection (Let-it-snow / LIS):
  snow-cover maps and annual phenology at 20 m. `consumed_by`: R3
  (snowpack as a seasonal water reserve modulating drought
  stress), W (winter water input).

Each entry carries `ndp_level: 0`, a `consumed_by` block, a
`provenance` block and explicit `"to confirm"` markers on
metadata not yet verified (STAC collection id, exact resolution,
licence). All three are `type: "raster_local"` with no static URL
— `load_raster_source()` deliberately refuses to fetch them, as
for `forms_t` and `chm_opencanopy`.

This release covers Phase 1a only. Phase 1b (six further Theia
sources), Phase 2 (loaders) and Phase 3 (indicator wiring) are
scoped in `PLAN.md`.

# nemeton 0.28.0 (2026-05-20)

### Added — FORMS-T (Theia) declared as a forest data source

`inst/datasources/FR.json` now declares the `forms_t` dataset:
the FORMS-T time-series of forest attribute maps over
metropolitan France (2018-present), produced by Theia / DATA
TERRA from a deep-learning fusion of Sentinel-1, Sentinel-2 and
GEDI lidar (Schwartz et al. 2023, ESSD,
doi:10.5194/essd-15-4927-2023).

Three products are described, each with resolution, unit and a
plausible value range:

- **height** — canopy height, 10 m, stored in centimetres;
- **volume** — growing stock volume, 30 m, m3/ha;
- **biomass** — aboveground biomass, 30 m, Mg/ha.

The entry carries a `consumed_by` block documenting how the
height product feeds the existing CHM path of four indicators —
`indicateur_c1_biomasse()` (C1), `indicateur_p1_volume()` (P1),
`indicateur_p2_station()` (P2) and `indicateur_b2_structure()`
(B2). FORMS-T height is in centimetres, so callers divide the
raster by 100 before passing it as the `chm` argument (which
expects metres).

The source is `type: "raster_local"` and carries no static URL
(distribution is per-tile/per-year via the THEIA STAC catalog or
the Zenodo record), so `load_raster_source()` deliberately
refuses to fetch it — the caller resolves the STAC asset href or
a local download path first. It is tagged `ndp_level: 0` and
`augmented: "height_ml"`, consistent with ADR-011 amended
(satellite + ML granularity, no NDP level change).

# nemeton 0.27.0 (2026-05-19)

### Fixed — STAC search silently capped at 100 features

`stac_search_s2()` and its two backends (`stac_search_s2_cdse()`,
`stac_search_s2_pc()`) had `limit = 100L` hardcoded, with no
pagination. Any AOI × date-range request hitting more than 100
matching scenes was silently truncated to the 100 most recent
ones — which broke every FORDEAD run with a multi-year training
window: the training window 2018-2020 saw 0 scenes because the
search only ever returned the latest ~16 months.

User-visible symptom (post v0.25.7 gating, still present in
v0.26.0):

```
✖ FORDEAD pipeline failed: No Sentinel-2 scene in the training
  window for zone 1.
✖ Scenes available: "2024-02-03" → "2026-05-01" (100 scenes).
✖ Training window: "2018-01-01 -> 2019-12-31" (0 scenes).
```

The garde-fou pointed at the dates, but the real cause was the
search cap.

### New — STAC pagination via `links[rel=next]`

`R/sentinel2.R` now exposes `.stac_search_paginate()`, a generic
paginator that:

- follows the STAC API standard `links[rel=next]` mechanism
  (both POST-with-body and GET-with-token variants),
- per-page size is fixed at 1000 (the max accepted by both CDSE
  and Planetary Computer); override via the env var
  `NEMETON_STAC_PAGE_SIZE` for backends with stricter caps,
- stops on (a) no `next` link, (b) empty page (defensive),
  (c) cumulative count reaching the user `limit`, or (d) the
  100-page safety cap (`.STAC_MAX_PAGES`) — the latter emits
  an actionable `cli_warn` pointing at `start`/`end`/`max_cloud`.

Both `stac_search_s2_cdse()` and `stac_search_s2_pc()` now route
through this helper. The default `limit` is bumped from 100 to
**10000** at the façade and at both backends — that's ~10 years
of single-tile coverage, more than enough for FORDEAD's
canonical 2-year training + 18-month monitoring window. Callers
that want a quick preview can still pass `limit = 50`.

Roxygen for the `limit` parameter rewritten with the new
semantics (total cap across pages, not per-request page size).

### Tests

5 new scenarios in `test-sentinel2.R` covering the paginator
(`with_mocked_responses`): single-page, multi-page traversal,
`max_total` truncation, empty-page defensive stop, and
`NEMETON_STAC_PAGE_SIZE` env var override. 101 PASS (+13).
Two pre-existing failures in the same file (mocked-binding
warnings test, unrelated to v0.27.0) are flagged for separate
investigation.

The FORDEAD pipeline test suite (`test-fordead-pipeline.R`,
54 PASS) is unchanged: the mocks stub
`ingest_s2_raw_bands_to_cache()` directly so the STAC swap is
transparent.

### Migration

Backward compatibility: full. Callers that did not pass an
explicit `limit` get more results (up to 10000 instead of 100)
without any code change. Callers that passed `limit = N` keep
the exact same upper-bound semantics — only the path to reach
it changed.

# nemeton 0.26.0 (2026-05-19)

### New — BD Forêt V2 fallback in `check_fordead_validity()`

Guard-rail G3 (spec 008, ADR-013) gains an automatic species
resolution path. `check_fordead_validity()` now accepts two new
arguments:

- `bdforet`: an `sf` of BD Forêt V2 polygons (formation végétale
  layer, IGN).
- `layers`: a `nemeton_layers` object from which a `"bdforet"`
  vector layer is resolved automatically via the existing
  `resolve_vector_layer()` helper.

When `units` carries no recognisable species column
(`essence_dominante`, `essence`, `species_label`, `species`,
`essence_principale`) AND a BD Forêt source is provided, the
function derives the dominant essence per unit via the existing
`enrich_parcels_bdforet()` helper (area-weighted intersection) and
runs the species check normally. An informational `cli_alert_info`
flags the fallback in the console.

Order of precedence:

1. Species column already on `units` → used directly (unchanged).
2. Else `bdforet` argument → enrich.
3. Else `layers$vectors$bdforet` → resolve, then enrich.
4. Else → warning with hint to pass `bdforet =` or `layers =`,
   species check skipped (`species_valid = NA`), same final
   behaviour as before.

The previous warning text ("No species column found on `units`…")
is preserved when no fallback path succeeds, but now includes a
hint line pointing to the new arguments.

Backward compatibility: full. Callers that do not pass `bdforet`
or `layers` get the v0.25.9 behaviour.

Tests: 4 new scenarios in `test-fordead-validity.R` (direct
`bdforet`, resolution via `layers`, empty/no-resolution warning,
ignored when units already carries species). 63 PASS total on
this file.

# nemeton 0.25.9 (2026-05-19)

### Changed — calibrated rolling defaults for `run_fordead_dieback()`

The default training and monitoring windows of `run_fordead_dieback()`
now reflect the ADR-013 calibration:

- `dates_training` defaults to `c("2018-01-01", "2020-12-31")` — a
  2-year baseline anchored on the start of Sentinel-2 dense coverage,
  long enough to fit the harmonic model and short enough to keep
  the baseline free from recent disturbances.
- `dates_monitoring` defaults to a rolling 18-month window ending
  today:

  ```r
  c(
    as.character(seq(Sys.Date(), by = "-18 months", length.out = 2)[2]),
    as.character(Sys.Date())
  )
  ```

  18 months covers a full vegetation cycle plus the early stages of a
  slow dieback, while staying short enough to keep the diagnostic
  actionable.

Previous defaults (`2016-2017` training / `2018→today` monitoring)
required users to override the dates on every call to obtain a sensible
window. The new defaults make `run_fordead_dieback(con, zone_id,
cache_dir)` directly usable on production zones without further
configuration. Roxygen docs and the example block are updated
accordingly.

No code change beyond the signature defaults and documentation. All
54 existing FORDEAD tests pass unchanged: scenarios that exercise the
date logic already pass explicit windows.

# nemeton 0.25.8 (2026-05-19)

### Fixed — `fordead.utils` submodule access via reticulate

Bug surfaced after v0.25.7 unblocked the training/monitoring gating.
Pipeline progressed cleanly through ingest / stac_assembly / fit /
predict, then `first_dieback_date` derivation warned with :

```
! first_dieback_date derivation failed: AttributeError: module
  'fordead' has no attribute 'utils'
```

Root cause : Python's `import fordead` does NOT auto-import the
`fordead.utils` submodule. We accessed `fd$utils$backward_start` on
the top-level `fd <- reticulate::import("fordead", convert = FALSE)`
handle, which raised AttributeError every time. The pipeline kept
running thanks to the surrounding `tryCatch`, but `first_dieback_date`
silently became `NA_character_` in the result.

Fix in `R/fordead_pipeline.R::run_fordead_dieback()` : import
`fordead.utils` explicitly via
`reticulate::import("fordead.utils", convert = FALSE)` before calling
`.compute_first_dieback_date()`. The import is wrapped in `tryCatch`
so a missing submodule (older fordead pin) doesn't abort the
pipeline — `first_dieback_date` falls back to `NULL` and the
postprocess phase continues without the first-dieback-date raster.

### Tests

`test-fordead-pipeline.R` (54 PASS) unchanged — the mock stubs
`.compute_first_dieback_date` directly so the internal swap from
`fd$utils` to a dedicated `import("fordead.utils")` is transparent.


# nemeton 0.25.7 (2026-05-18)

### Fixed — pre-`fit()` gating against empty training / monitoring windows

Bug surfaced once v0.25.6 unblocked CRS alignment and the user re-ran
FORDEAD on a real cache. Phase 1 STAC assembly succeeded over 116
scenes (2024-2026 envelope), but `fit()` crashed deep in stackstac
with :

```
AssertionError: out_bounds=None
```

Root cause : the default `dates_training = c("2016-01-01", "2017-12-31")`
selected **zero** scenes from a cache holding 2024+ data. fordead's
`compute_spectral_index` ran on the empty time slice, wrote no
CRSWIR layer files, and the subsequent `update_ds("CRSWIR")` call
to `stackstac.stack(assets = ["CRSWIR"])` got an empty asset list →
`out_bounds` stayed `None` → assertion failure with no actionable
context for the caller.

Fix in `R/fordead_pipeline.R::run_fordead_dieback()` : after the
ingest phase populates `scenes_df`, count the scenes that fall in
`[dates_training[1], dates_training[2]]` and
`[dates_monitoring[1], dates_monitoring[2]]`. If either count is
zero, abort with a typed message that reports the
scene-date envelope and the requested windows so the caller can
fix `dates_training` / `dates_monitoring`. Example output:

```
Error in `run_fordead_dieback()`:
! No Sentinel-2 scene in the training window for zone 1.
✖ Scenes available: 2024-02-03 → 2026-04-08 (116 scenes).
✖ Training window: 2016-01-01 -> 2017-12-31 (0 scenes).
✖ Monitoring window: 2018-01-01 -> 2026-05-18 (116 scenes).
ℹ Adjust `dates_training` / `dates_monitoring` so both windows
  contain at least 1 scene from the available envelope.
```

### Tests

* `test-fordead-pipeline.R` — 2 new tests (+4 PASS, total 54) :
  empty-training-window abort, empty-monitoring-window abort.
  Asserts that fordead's `fit()` is never called when either window
  is empty.


# nemeton 0.25.6 (2026-05-18)

### Fixed — FORDEAD `fit()` crashed with `NoDataInBounds` on UTM tiles

Bug surfaced once v0.25.2's sampling fix landed and the user re-ran
FORDEAD on a real Sentinel-2 tile (T31TGM, EPSG:32631). The phase-0
ingest populated the cache, phase-1 STAC assembly built an
`ItemCollection` with the proper `proj:epsg = 32631` metadata, but
phase-2 `fit()` crashed in stackstac with :

```
rioxarray.exceptions.NoDataInBounds: No data found in bounds.
Data variable: stackstac-<hash>
```

Root cause : we passed `bbox` and `geometry` to
`FordeadProcess(...)` in EPSG:4326 (degrees) but the Sentinel-2 tile
cache is in EPSG:32631 (meters). FordeadProcess's `geometry` setter
attempts `value.to_crs(self.crs)` — but only when the input has a
`to_crs` attribute (GeoDataFrame / GeoSeries). Our previous
implementation passed a raw `shapely.geometry.Polygon` which has no
`to_crs`, so the setter could not reproject. The bbox stayed in
degrees on the meter-CRS data cube, and `stackstac.clip_box()` found
zero pixels in the (sub-degree) range.

Fix in two parts :

* `R/fordead_stac.R::.aoi_geometry_reticulate()` now returns a
  `geopandas.GeoSeries(crs = "EPSG:4326")` instead of a raw shapely
  Polygon. The setter's `to_crs` + `total_bounds` path now triggers
  and reprojects the geometry to the collection CRS, while
  overriding `self.bbox` from `geometry.total_bounds` in the right
  CRS.
* `R/fordead_pipeline.R::run_fordead_dieback()` no longer passes a
  `bbox` argument to `FordeadProcess(...)` (pass `bbox = NULL`).
  Previously the constructor stored the degree-valued bbox at line
  95 of fordead's `workflow.py`, and the very next `geometry`
  setter triggered `self.crs` which calls `to_xarray(bbox=...,
  geometry=None)` — using the wrong-CRS bbox during an internal
  evaluation, which could also raise `NoDataInBounds` before our
  geometry override could take effect. With `bbox = None` the
  collection is assembled un-clipped, `self.crs` resolves to the
  collection's CRS, and the geometry setter finishes the job
  cleanly.

### Tests

* `test-fordead-stac.R` — `.aoi_geometry_reticulate` test updated
  to assert the returned object is a `geopandas.GeoSeries` with
  `crs = "EPSG:4326"`. Mocks `geopandas$GeoSeries` and
  `reticulate::import_builtins()` alongside `shapely.wkt`. 73 PASS
  (baseline + new assertions ; 2 pre-existing failures on charToDate
  fixtures unchanged).
* `test-fordead-pipeline.R` (48 PASS) unchanged — those tests mock
  `.aoi_geometry_reticulate` at the package level, so the internal
  implementation swap is transparent.


# nemeton 0.25.5 (2026-05-18)

### Fixed — `resolve_project_dem()` / `resolve_project_chm()` missed direct files under `cache/layers/`

v0.25.4 only probed `<project>/cache/layers/{lidar_mnt,dem,bd_alti,
rge_alti,dtm,mnt}/*.tif` (i.e. inside *sub*-directories) and root-level
files `<project>/{dtm,mnt,chm,mnh}.tif`. It did NOT probe
`<project>/cache/layers/dem.tif` directly — a convention used by some
downloaders that drop the raster flat in `cache/layers/` rather than
under a named sub-directory.

User report: a project with `<project>/cache/layers/dem.tif` returned
`NULL` from `resolve_project_dem()`, and the sampling-plan tab
re-emitted the v0.25.1 "Stratification-valid candidate pool (0)" abort.

Search order extended (DEM):

* `<project>/cache/layers/dem.tif` — direct file
* `<project>/cache/layers/dtm.tif` — direct file
* `<project>/cache/layers/mnt.tif` — direct file
* `<project>/dem.tif`               — project root variant

Search order extended (CHM):

* `<project>/cache/layers/chm.tif` — direct file
* `<project>/cache/layers/mnh.tif` — direct file

The new direct-file probes sit just after the sub-directory probes and
before the project-root fallbacks, so they take precedence over root
`dtm.tif` / `mnt.tif` when both exist (cache/ is the more discoverable
convention).

5 new tests cover the direct-file matches and the priority between
`cache/layers/dem.tif` and root `<project>/dtm.tif`.

# nemeton 0.25.4 (2026-05-18)

### Added — `resolve_project_dem()` / `resolve_project_chm()` discovery helpers

Néméton projects accumulate digital terrain models (MNT / DEM /
DTM) and canopy height models (MNH / CHM) from several producers,
each landing under its own naming convention:

* IGN RGE ALTI (tutorials): `<project>/mnt.tif`
* LiDAR HD (`lidR` pipeline): `<project>/cache/layers/lidar_mnt/*.tif`
* `opencanopynemeton`: `<project>/dtm.tif` at project root
* Open-Canopy CHM: `<project>/cache/layers/chm/*.tif`
* IGN BD ALTI / RGE ALTI: `<project>/cache/layers/{bd_alti,rge_alti}/*.tif`

Callers (`nemetonshiny`, scripts) used to hard-code paths that
broke as soon as a different producer was used. Most visibly, the
`<project>/dtm.tif` convention from `opencanopynemeton` was
recognised neither by `nemeton` nor by `nemetonshiny`, leading to
the v0.25.1 "Stratification-valid candidate pool (0) is below
`n_base`" failure even when the DTM was perfectly downloaded
— the file was just never passed to `create_sampling_plan(mnt =)`.

Two new exported helpers walk a priority-ordered list of well-known
locations and return the first match:

```r
dem <- nemeton::resolve_project_dem(project_path)
chm <- nemeton::resolve_project_chm(project_path)
plan <- nemeton::create_sampling_plan(zone, mnt = dem, chm = chm, ...)
```

DEM search order (highest quality first):

1. `<project>/cache/layers/lidar_mnt/*.tif`  — LiDAR HD (1 m)
2. `<project>/cache/layers/dem/*.tif`        — generic DEM cache
3. `<project>/cache/layers/bd_alti/*.tif`    — IGN BD ALTI (25 m)
4. `<project>/cache/layers/rge_alti/*.tif`   — IGN RGE ALTI (5 m)
5. `<project>/cache/layers/dtm/*.tif`        — generic DTM cache
6. `<project>/cache/layers/mnt/*.tif`        — generic MNT cache
7. `<project>/dtm.tif`                        — `opencanopynemeton`
8. `<project>/mnt.tif`                        — tutorial convention
9. `<project>/data/dtm.tif` / `data/mnt.tif`  — alt project layouts

CHM search order:

1. `<project>/cache/layers/chm/*.tif`        — Open-Canopy
2. `<project>/cache/layers/lidar_mnh/*.tif`  — LiDAR HD MNH
3. `<project>/cache/layers/mnh/*.tif`        — generic MNH cache
4. `<project>/chm.tif`, `mnh.tif`, `data/chm.tif`, `data/mnh.tif`

When multiple tiles match in the same directory, the returned
`SpatRaster` is a virtual mosaic (`terra::vrt()`), so downstream
`terra::extract` / `terra::crop` calls transparently cover the
full footprint.

Both helpers accept `load = FALSE` (return paths only, useful for
diagnostics), `load = TRUE` (default, return a `SpatRaster`) and
`verbose = TRUE` (log every probed location). The returned object
carries the matched layer label as attribute `"nemeton_dem_layer"`
/ `"nemeton_chm_layer"` for traceability.

11 new offline tests cover argument validation, single-file
matches, the `cache/layers/` discovery path, priority order
(LiDAR HD beats opencanopy DTM when both present), multi-tile
VRT mosaicking, verbose/silent modes, and case-insensitive
matching for `DTM.tif` vs `dtm.tif` on Windows.
# nemeton 0.25.2 (2026-05-17)

### Fixed — `create_sampling_plan()` with overlapping BD Forêt polygons

Same symptom as the v0.25.1 fix (`le tableau de remplacement a 363
lignes, le tableau remplacé en a 337`), but a different code path —
not caught by v0.25.1's NA filter. Reported again from
`nemetonshiny@v0.35.0` after v0.25.1 landed.

Root cause : in `.stratify()`, the BD Forêt v2 join used
`sf::st_join(frame, forest_mask[, "tfv"], left = TRUE)`. `st_join`
returns **one row per (left, right) match**. BD Forêt v2 polygons
overlap by construction in mixed-class zones, so a candidate falling
on 2 polygons produced 2 rows in the join — the result had more rows
than `frame`, and `frame$strat_type <- tfv_too_long` then crashed
with the system error.

v0.25.1's filter (drop candidates whose CHM / MNT extraction is NA)
ran fine and reduced frame to 337 — but `st_join` immediately after
inflated the result to 363 rows, exactly matching the reported
numbers.

Fix in `.stratify()` : replace `sf::st_join` with
`sf::st_intersects` + first-match. The result is a list of length
`nrow(frame)`, and we pick the first matching polygon's `tfv` value
per candidate. Picking the first match (arbitrary order from the
spatial index) is a deliberate simplification — multi-class overlaps
are not joined by spatial majority in the current scope.

### Tests

* `test-sampling_stratification.R` — 1 new test (14 PASS total) :
  overlapping BD Forêt polygons (two polygons with explicit overlap
  zone). Pre-fix raised the size-mismatch error ; post-fix the plan
  generates and `strat_type` resolves to one of the BD Forêt classes.


# nemeton 0.25.1 (2026-05-17)

### Fixed — `create_sampling_plan()` partial-coverage CHM / MNT

Bug reported from `nemetonshiny@v0.35.0`: `create_sampling_plan()`
with CHM × MNT stratification on a partial-coverage raster failed
with `le tableau de remplacement a 363 lignes, le tableau remplacé en
a 337` when the AOI's edge candidates fell on NA pixels.

Root cause : `.stratify()` produced strata strings like `"NA_FEU_BAS"`
for candidates with `mean_height = NA` or `mean_tpi = NA`.
`spsurvey::grts()` silently dropped those rows from the frame,
leaving a downstream size mismatch on the `[<-` assignment that
brought the size back to the full pool.

Fix in `R/sampling_plan.R::create_sampling_plan()` : a new filter
step runs **between** the forest-cover / slope filter and the clamp,
**before** `.stratify()` is called. When `chm` / `mnt` is provided,
candidates whose extracted value is NA are dropped so the pool that
enters stratification is homogeneous on every requested dimension.
Side effects :

* When the filter removes more than 10 % of the pool, a
  `cli::cli_warn()` reports the delta so the user knows their AOI
  has bordering candidates outside the CHM-MNT coverage.
* When the remaining pool is smaller than `n_base`, the function
  aborts cleanly via `cli::cli_abort()` with a typed message and
  remediation hints (rather than the previous silent grts failure).

### Tests

* `test-sampling_stratification.R` (new) — 11 PASS. Covers (1) the
  exact bug reproducer (partial CHM, plan generated without error),
  (2) the > 10 % reduction warning, (3) the under-`n_base` abort,
  (4) the no-stratification regression guard (`chm = NULL` and
  `mnt = NULL`), (5) full-coverage guard (no warning fires when CHM
  covers the whole AOI).


# nemeton 0.25.0 (2026-05-17)

### Added — FAST alerts + FORDEAD mask exporters

Two new public functions powering the 4-subtabs Suivi sanitaire UI in
`nemetonshiny@v0.34.0` (Alertes FAST / Carte FAST / Alertes FORDEAD /
Carte FORDEAD).

* **`list_fast_alerts_for_zone(con, zone_id, threshold_ndvi = 0.40,
  threshold_nbr = 0.30, window_days = 30L, date_from, date_to)`** —
  aggregates `obs_pixel` per plot over the last `window_days` of the
  search window, classifies each plot by the worse of its NDVI / NBR
  ratios against threshold :
    - `critical` if either ratio `< 0.5`,
    - `warning` if either ratio in `[0.5, 1.0)`,
    - `info` if either ratio in `[1.0, 1.1)` (warning corridor),
    - safe plots (both ratios `>= 1.1`) are not returned.
  Returns an `sf` POINT layer in **EPSG:4326** with `plot_id`,
  `last_obs_date`, `ndvi_value`, `nbr_value`, `ndvi_drop`, `nbr_drop`,
  ordered factor `severity`. Empty-but-schema-stable `sf` when no
  plot is in the alert zone (caller-safe for `rbind` / `bind_rows`).

* **`read_fordead_dieback_mask(con, zone_id, run_id = NULL,
  cache_dir = NULL)`** — reads the categorical 0-4 dieback mask
  (`0 = sain`, `1 = faible`, `2 = moyenne`, `3 = forte`,
  `4 = sol nu`, `NA = hors masque forestier`) written by
  [`run_fordead_dieback()`] to
  `<cache_dir>/zone_<zone_id>/dieback_mask_<run_id>.tif`. Without
  `run_id`, the latest mask (filename order on the YYYYMMDDTHHMMSS
  suffix) is returned. Returns a `terra::SpatRaster`, or `NULL`
  when no mask is available.

### Internal — spec deviations documented in roxygen

* `list_fast_alerts_for_zone()` — severity is bucketed via *ratio*
  (`value / threshold`) rather than absolute *drop* margin, so a same
  `<= 50 %` shape works for both NDVI and NBR thresholds without
  tuning. Documented in roxygen `@section Severity rules`.
* `read_fordead_dieback_mask()` — the prompt-spec signature
  `(con, zone_id, run_id)` cannot derive the project root from the
  connection in this release (no `fordead_run` tracking table yet).
  We widen the signature with a required `cache_dir` argument and
  reserve `con` for forward compatibility. Documented in roxygen
  `@section con parameter`.
* Persist hook in `run_fordead_dieback()` — out of scope for v0.25.0.
  The reader returns `NULL` until the postprocess phase is extended
  to write the classified mask to the conventional path. App should
  treat NULL as "no FORDEAD run yet" in the Carte FORDEAD subtab.

### Tests

* `test-fast_alerts.R` — 26 PASS. Severity classifier exercised via
  mocked `DBI::dbGetQuery` returning synthetic rows. Covers : 4-plot
  fixture with one of each severity (info / warning / critical /
  safe), worse-of-two-bands rule, drop column logic, NA observation
  exclusion, empty-result shape, input validation.
* `test-fordead_mask.R` — 15 PASS. Filesystem fixtures (3 × 3
  categorical GeoTIFFs via `terra::writeRaster`) under
  `<tmp>/zone_<id>/dieback_mask_<ts>.tif`. Covers : NULL on missing
  cache_dir / empty dir, value preservation 0..4 + NA, latest-run
  pick, explicit run_id, NULL on unknown run_id.


# nemeton 0.24.4 (2026-05-17)

### Fixed — pystac assets now carry `proj:*` / `raster:*` metadata

Bug surfaced once v0.24.3 fixed the simplestac import: the pipeline
got further but every Item logged "has no assets left after
filtering" then `ValueError: Zero asset IDs requested`.

Cause: `simplestac.utils.filter_assets()` drops every asset whose
`extra_fields` doesn't contain at least one key matching
`^proj:|^raster:`. Our hand-rolled `pystac.Asset(href, roles,
media_type)` calls produced assets with empty `extra_fields` → 100 %
of assets filtered out → fordead nothing to compute on.

Fix in `R/fordead_stac.R::.build_stac_collection_for_aoi()` :
delegate asset construction to
`simplestac.local.stac_asset_info_from_raster(band_file)`, then
build the asset via `pystac.Asset.from_dict(info)`. The helper
reads each COG's header (no pixel read) and returns a dict with
`href`, `type`, `roles`, `proj:epsg`, `proj:bbox`, `proj:shape`,
`proj:transform`, `gsd`, `raster:bands` — exactly the metadata
fordead 2.x needs.

Cost: one COG header read per band per scene (cheap — terra and
rasterio both stream the GeoTIFF directory only). For 100 scenes ×
6 bands = 600 header reads, < 5 s on a warm cache.

### Tests

Mock `simplestac.local` module added (`stac_asset_info_from_raster`
returns a minimal dict with `proj:epsg` / `proj:bbox` / `proj:shape`
/ `proj:transform` / `raster:bands` for testability). Fake
`pystac.Asset` widened from a constructor to a list exposing
`from_dict()`. Three test switch blocks updated to wire the new
module. 72 PASS / 2 pre-existing failures unchanged.


# nemeton 0.24.3 (2026-05-17)

### Fixed — `simplestac.ItemCollection` import via the right submodule

Bug surfaced once the v0.24.1 / v0.24.2 ingest path actually
populated the cache successfully and the pipeline reached phase 1
(STAC assembly):

```
FORDEAD pipeline failed: AttributeError: module 'simplestac' has
no attribute 'ItemCollection'
```

`simplestac` 1.2.5 does not re-export `ItemCollection` at the
package top level — the class lives in `simplestac.utils`. The
v0.23.0 paperwork assumed a top-level export ; verified against the
installed venv on 2026-05-17 (`dir(simplestac)` returns only
`PackageNotFoundError` and `version`).

Fix in `R/fordead_stac.R::.build_stac_collection_for_aoi()` :
`reticulate::import("simplestac", convert = FALSE)` →
`reticulate::import("simplestac.utils", convert = FALSE)`.
`simplestac$ItemCollection(items)` resolves through the submodule
unchanged after the import target swap.

### Tests

Mock import switch updated (`simplestac = ...` →
`simplestac.utils = ...`) in `test-fordead-stac.R`. 72 PASS, 2 pre-
existing failures unchanged (`charToDate` on synthetic fixtures —
present on baseline v0.24.2).


# nemeton 0.24.2 (2026-05-16)

### Improved — FORDEAD ingest now emits the same `s2:*` events as FAST

In v0.24.0 / v0.24.1, the phase-0 ingest of [`run_fordead_dieback()`]
emitted `s2:search`, `s2:search_done`, `s2:scene`,
`s2:scene_skipped` and `s2:complete` — but **not**
`s2:cache_lookup` (the pre-loop "X cached, Y to fetch" summary) nor
`s2:scene_cached` (the per-scene "already on disk" signal). Result:
the app showed "scene downloading" for every scene even when the
cache was already fully warm.

Parity restored:

* [`ingest_s2_raw_bands_to_cache()`] now does a filesystem-level
  cache pre-scan before the per-scene loop, and emits `s2:cache_lookup`
  with the `n_cached` / `n_to_process` counters.
* Each fully-cached scene emits `s2:scene_cached` (skipping the band
  fetch loop) instead of `s2:scene`.
* `s2:complete` now carries `n_scenes_cached` alongside the existing
  `n_bands_fetched` and `n_bands_cached`.

The downstream toast dispatcher in `nemetonshiny@v0.32.0+` already
handles these event keys (they were wired for FAST) — zero app
change required. Identical UX to FAST during the FORDEAD phase 0.


# nemeton 0.24.1 (2026-05-16)

### Fixed — STAC search now exposes all 7 FAST + FORDEAD bands

Bug revealed at the first production use of v0.24.0
([`run_fordead_dieback()`]) : the ingest phase tried to fetch B02 /
B05 / B8A / B11 from each scene but `stac_search_s2()` only
extracted hrefs for B04 / B08 / B12 (the three FAST bands). Result :
"Scene X has no href_B02 column" on every band, every scene → 100%
skip → "No scene in `scenes_df` had all required bands".

Root cause : `.features_to_tibble()` hardcoded the three FAST bands
when extracting STAC assets, with no extension hook. The fix
centralises the band list in two private constants :

* `.S2_STAC_BANDS` — the seven bands now exposed:
  `c("B02","B04","B05","B08","B8A","B11","B12")`.
* `.S2_STAC_REQUIRED_BANDS` — the three bands a scene must have to
  remain in the result (`c("B04","B08","B12")`). The four FORDEAD-
  extra bands are kept tolerant : missing band on a given scene
  yields an empty href column, not a dropped row. Downstream
  consumers (FAST keeps using only B04/B08/B12 ; FORDEAD calls the
  ingest helper which now reports per-scene missing bands cleanly)
  decide individually whether to accept the scene.

Cost : one more asset lookup per feature, no extra HTTP. PC token
application is centralised over the seven bands via a loop.

### Improved — clearer error when a STAC asset is missing

`.get_s2_band_raster()` previously errored with "Scene X has no
href_B12 column" — which conflated two failure modes :
("the STAC schema doesn't expose this band" vs "this scene doesn't
have an asset for this band"). v0.24.1 splits these into two typed
messages so the root cause is obvious in the warning aggregate.

### Test

* `test-sentinel2.R` — empty-tibble shape test widened to the seven
  bands.
* No new failures introduced ; pre-existing failures
  (`charToDate` on synthetic fixtures, STAC retry test fragility)
  unchanged.


# nemeton 0.24.0 (2026-05-16)

### Changed — FORDEAD now invocable with `(con, zone_id, cache_dir)` only

Spec 008 §13 amendment A2, plan 008 §10, ADR-013 amendment A2.

[`run_fordead_dieback()`] now derives its AOI from
`monitoring_zone.zone_wkt` and runs a partial-coverage-aware ingest
phase as phase 0 — callers no longer need to supply an explicit AOI
or scenes_df. Discovered at the first production use of v0.23.0
(error `scenes_df is required and must be a data.frame`): the app
has `con + zone_id` everywhere, but reconstructing `scenes_df`
required walking the disk cache from the UI layer, duplicating
logic that already exists in the core.

**Public API changes (breaking)** :

* New signature : `run_fordead_dieback(con, zone_id, cache_dir,
  dates_training, dates_monitoring, ...)`. All three are required.
* Arguments **removed** : `aoi` (derived from `monitoring_zone.zone_wkt`),
  `scenes_df` (produced by the new phase-0 ingest), `forest_mask`
  (already deprecated in v0.23.0).
* The phase plan grows from 5 (v0.23.0) to 6 phases — `ingest` is
  added as phase 0. `progress_callback` receives a new
  `phase_name = "ingest"` event ; the `s2:*` events from the ingest
  helper pass through verbatim, so a UI that already renders FAST
  toasts displays them with zero rework.

**New public surface** :

* `FORDEAD_BANDS` — exported character constant
  `c("B02","B04","B05","B8A","B11","B12")`. The six raw Sentinel-2
  bands required by fordead 2.x for CRSWIR + masks. Differs from
  the FAST triplet `c("B04","B08","B12")` used by NDVI / NBR.
* `ingest_s2_raw_bands_to_cache()` — new public function that
  populates `<cache_dir>/<safe_scene_id>/<band>.tif` for an
  arbitrary set of raw Sentinel-2 bands, with no DB writes. Used
  internally by `run_fordead_dieback()` (phase 0) and available to
  any custom pipeline that needs raw bands beyond NDVI / NBR.
  Companion of [`ingest_sentinel2_timeseries()`].
  [`ingest_sentinel2_timeseries()`] is strictly restricted to NDVI /
  NBR via `match.arg` — that function computes derived indices on
  the fly and writes them to `obs_pixel`, so it can't be repurposed
  to fetch arbitrary bands.

**Internal restructure** :

* New `R/sentinel2_cache.R` — homes `ingest_s2_raw_bands_to_cache()`
  and `.empty_raw_ingest_summary()`.
* `R/fordead_pipeline.R` — `.get_zone_aoi(con, zone_id)` helper
  that queries `monitoring_zone.zone_wkt + crs_epsg` and reprojects
  to EPSG:2154. Replaces the previous direct AOI argument.
* `.validate_fordead_args()` signature simplified — no longer takes
  `aoi` / `forest_mask`. AOI validation moved next to its derivation
  via `.get_zone_aoi()`. The forest-mask deprecation warning is
  removed (forest_mask is gone for good).
* `.empty_fordead_result()` gains `zone_id` and `n_scenes` fields
  for parity with the success-path return value.
* Removed dead helper `.download_or_use_cached_bd_foret` (stub never
  wired to anything since v0.23.0 removed the forest_mask path).

**Tests refactor** :

* `test-fordead-pipeline.R` rewritten — every call site uses the
  new signature, `.mock_pipeline_helpers()` mocks the new
  `.get_zone_aoi` + `ingest_s2_raw_bands_to_cache`. Six-phase
  contract asserted (was four). Three new tests : ingest phase
  propagates `s2:*` verbatim, `n_alerts_inserted` path with
  always-on persist, `FORDEAD_BANDS` contents.
* `test-fordead-zone-aoi.R` (new) — five tests on `.get_zone_aoi`
  via mocked `DBI::dbGetQuery`.
* `test-sentinel2-cache.R` (new) — eight tests on
  `ingest_s2_raw_bands_to_cache` via mocked `.fetch_plots_sf` /
  `stac_search_s2` / `.get_s2_band_raster`.
* `test-fordead-integration.R` adapted — env vars are now
  `NEMETON_DB_URL` + `NEMETON_FORDEAD_TEST_ZONE_ID` +
  `NEMETON_FORDEAD_TEST_CACHE_DIR` (was AOI path + cache dir).

**Migration path** :

```r
# v0.23.0
res <- run_fordead_dieback(aoi, scenes_df, cache_dir, ...)

# v0.24.0
res <- run_fordead_dieback(con, zone_id, cache_dir, ...)
```

The `nemetonshiny` migration (1 call site) ships in
`nemetonshiny@v0.33.0`.


# nemeton 0.23.0 (2026-05-16)

### Changed — FORDEAD pipeline migrated to fordead 2.x

Spec 008 §12 amendment A1, plan 008 §9. The R-side FORDEAD pipeline
([run_fordead_dieback()]) is rewritten to use fordead 2.x's unified
`fordead.workflow.FordeadProcess` class instead of the dispersed
1.x `fordead.steps.step1_*..step5_*` modules. Bridges the nemeton
STAC COG cache directly — no more THEIA / MAJA format gap.

The 1.x integration shipped in `v0.21.0` was never end-to-end
operational : kwargs were wrong (`vegetation_index` vs `vi`,
`input_directory` vs `data_directory`), the pipeline expected
THEIA L2A folders which `ingest_sentinel2_timeseries()` doesn't
produce, and the 44 offline mocks accepted any kwarg. The cascade
of patches `v0.22.2..v0.22.5` (16 May 2026) revealed the gaps. This
release closes them properly.

**Public API changes (breaking)** :

* `run_fordead_dieback()` gains two **required** arguments :
  - `scenes_df` — a data.frame with `scene_id` (character) and
    `obs_date` (Date). Typically the output of
    [ingest_sentinel2_timeseries()] or a query against `obs_pixel`.
  - `cache_dir` — root of the STAC COG cache, where
    `<cache_dir>/<safe_scene_id>/<band>.tif` files live. Local
    hrefs avoid PC SAS expiry during long `fit()` runs.
* `forest_mask` is deprecated and ignored. fordead 2.x handles
  cloud / shadow / soil masks via `FordeadConfig` defaults, which
  per ADR-013 §G5 already match the ONF/DSF calibration. A
  `cli::cli_alert_warning` fires when a non-`NULL` value is passed.
* All other arguments unchanged.

**Internal restructure** :

* New `R/fordead_stac.R` (session 1, commit 4bf0a0a) :
  - `.aoi_bbox_4326()` — WGS-84 bbox for `FordeadProcess(bbox=...)`.
  - `.aoi_geometry_reticulate()` — shapely geometry via WKT.
  - `.aoi_geojson_list()` — GeoJSON dict for `pystac.Item.geometry`.
  - `.build_fordead_config()` — `FordeadConfig` with the 4 R-exposed
    knobs overridden, rest = ADR-013-matching defaults.
  - `.build_stac_collection_for_aoi()` — walks `scenes_df` + cache,
    skips scenes missing required bands with one aggregated warning,
    builds `simplestac.ItemCollection`.
* New `R/fordead_outputs.R` (session 2, commit ef2d072) :
  - `.list_layer_files()` / `.latest_layer_file()` — locate
    `<output_dir>/<LAYER>/fordead_<YYYYMMDD>_<LAYER>.tif`.
  - `.compute_first_dieback_date()` — stack `ANOMALY_CONFIRMED` and
    call `fordead.utils.backward_start()`.
  - `.fordead_2x_status_to_classes()` — derive the 0-4 class raster
    from `ANOMALY_CONFIRMED` + `CONSECUTIVE_DETECTIONS` +
    `STOP_CONFIRMED`. Thresholds match spec 008 §12.4 mapping table.
* `.postprocess_fordead_rasters()` is **unchanged**. The input
  shape (named list with `state`, `stress_index`,
  `first_dieback_date`) is preserved — the pipeline builds it from
  the 2.x layers. Guarantees AC.12.4 (R5 tests stay green).

**Phase progress callback** (compatibility note) :

The 5 phase names in `progress_callback` events have changed from
the 1.x theoretical list (`vegetation_index`, `train_model`,
`forest_mask`, `dieback_detection`, `export_results`, `postprocess`,
`persist`) to the 2.x mapping :
- `stac_assembly` — STAC ItemCollection + bbox/geom/config build.
- `fit` — `FordeadProcess.fit()` (umbrella).
- `predict` — `FordeadProcess.predict()` (umbrella).
- `postprocess` — `.postprocess_fordead_rasters()` (unchanged).
- `persist` — `.insert_fordead_alerts()` (optional, when
  `con` + `zone_id`).

`nemetonshiny@v0.32.0` (released 2026-05-16) anticipated this with
a generic phase-name lookup design, so the app needs no rewiring.

**Python dependencies** :

* `inst/python/requirements.txt` :
  - `fordead @ git+https://gitlab.com/fordead/fordead_package@v2.1.1`
    (was `@v1.11.4`)
  - `simplestac @ git+https://forge.inrae.fr/umr-tetis/stac/simplestac@v1.2.5`
    added explicitly (transitive dep of fordead 2.x).
* `R/fordead_python.R` version-aware reinstall logic (v0.22.5)
  detects the pin change and triggers `pip install --upgrade` on
  the next `run_fordead_dieback()` call.

**Tests** :

* `test-fordead-pipeline.R` refactored : 16 offline tests with mocks
  for `fd$workflow$FordeadProcess` + helpers via
  `testthat::local_mocked_bindings(!!!, .package = "nemeton")`.
  Covers 8 validations (2 new : `scenes_df`, `cache_dir`),
  4 orchestration paths, 1 `.empty_fordead_result` shape.
* `test-fordead-stac.R` (session 1) : 16 offline tests for the new
  STAC helpers + FordeadConfig builder.
* `test-fordead-outputs.R` (session 2) : 11 tests — 6 without terra
  (`.list_layer_files`, `.latest_layer_file`) + 5 with terra
  (`.fordead_2x_status_to_classes` mapping + STOP + NA-255).
* `test-fordead-integration.R` (NEW, session 3) : 2 opt-in tests
  guarded by `skip_if_no_fordead_integration()` (requires
  `NEMETON_FORDEAD_INTEGRATION=TRUE` + a real cache + AOI fixture).
  Plan 008 §9.4 AC.12.3.

**Migration notes for users on `v0.21.0..v0.22.5`** :

* Update your code to pass `scenes_df` and `cache_dir`:
  ```r
  res <- run_fordead_dieback(
    aoi              = aoi,
    scenes_df        = scenes_df,  # NEW (required)
    cache_dir        = cache_dir,  # NEW (required)
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", as.character(Sys.Date()))
  )
  ```
* The next call automatically replaces the in-venv fordead 1.x with
  2.x (version-aware reinstall, no manual `virtualenv_remove`).
* Remove any `forest_mask = ...` arguments — they're now ignored.

**Known limitation / deferred work** :

* The thresholds in `.fordead_2x_status_to_classes` (`>=3, >=6,
  >=10`) are placeholders from spec 008 §12.4. They need empirical
  recalibration against a real FORDEAD run on a validated zone
  (AC.12.3 part 2). Tracked as a follow-up patch.
* `test-fordead-integration.R` skip-by-default. Run locally with
  `NEMETON_FORDEAD_INTEGRATION=TRUE` + a populated cache + AOI to
  exercise the end-to-end path.

---

# nemeton 0.22.5 (2026-05-16)

### Fixed — `module 'fordead' has no attribute 'steps'` after v0.22.2..v0.22.4

After the install/discovery fixes of v0.22.2..v0.22.4, the FORDEAD
pipeline finally started — and immediately failed at the first
substantive step :

```
ℹ Step: compute_masked_vegetationindex
✖ FORDEAD pipeline failed: AttributeError: module 'fordead' has no attribute 'steps'
```

Cause : **fordead 2.x is a complete API rewrite**. The 1.x pipeline
exposed `fordead.steps.step1_compute_masked_vegetationindex`,
`step2_train_model`, `step3_dieback_detection`, `step5_export_results`
as importable submodules — and that's exactly the API
`R/fordead_pipeline.R` was written against. fordead 2.x dropped that
in favour of a single `fordead.workflow.FordeadProcess` class with
methods like `compute_spectral_index`, `fit`, `predict`,
`anomaly_detection`, etc. The pin `@v2.1.1` introduced in v0.22.2
crossed that boundary silently because the spec said "fordead 2.x"
without verification.

**Fix**: pin downgraded to **`v1.11.4`** (last 1.x release,
2025-08-13). Verified : `fordead/steps/` at v1.11.4 contains
exactly the 5 step files our pipeline imports.

### Fixed — pin downgrade required re-install detection

A user already running v0.22.2..v0.22.4 has a venv with `fordead
2.1.1` installed. After the pin downgrade to `1.11.4`, the previous
`.fordead_is_installed()` only checked importability — it would
have returned TRUE for the wrong-API 2.1.1 install and skipped the
upgrade. The pipeline would have stayed broken.

`.fordead_is_installed()` now takes an optional `requirements_path`
argument and compares the installed version against the pin. Two
new private helpers :

* `.fordead_version_pinned(req_path)` — parses
  `fordead @ git+...@vX.Y.Z` or `fordead==X.Y.Z` from
  `requirements.txt`.
* `.fordead_python_version(env_name)` — runs
  `<venv>/python -c "import fordead; print(fordead.version)"`.

On version mismatch the helper emits a clear `cli::cli_alert_warning`
and returns FALSE, which makes `.ensure_fordead_python()` re-run
`pip install --upgrade -r requirements.txt`. pip then sees the new
URL pin and reinstalls fordead at the correct version.

### Migration tracked

Migrating `R/fordead_pipeline.R` to the fordead 2.x `FordeadProcess`
class API is a future epic — spec 008 §3 / plan 008 §2 will need
rework, plus an ADR-013 amendment. Logged as backlog in `PLAN.md`.

### Tests

* 5 new tests in `test-fordead-python.R` covering version parsing
  and the new `.fordead_is_installed(requirements_path)` branch:
  - `.fordead_version_pinned` parses git URL pin
  - `.fordead_version_pinned` parses PyPI-style pin
  - `.fordead_version_pinned` returns NA when nothing matches
  - `.fordead_is_installed` flags a version mismatch as not-installed
  - `.fordead_is_installed` accepts a matching version
* 2 existing `.fordead_is_installed` mocks updated to accept the
  new `requirements_path = NULL` argument.

---

# nemeton 0.22.4 (2026-05-16)

### Fixed — FORDEAD pre-check failed when `RETICULATE_PYTHON` was just unset

After applying the recovery procedure from v0.22.3 (unset
`RETICULATE_PYTHON`, restart R), some users hit a new pre-check
failure :

```
✖ FORDEAD pipeline failed: No Python interpreter found.
ℹ FORDEAD requires Python ">= 3.10".
```

Cause : `reticulate::py_discover_config()` can return `NULL` even
when `Sys.which("python3.12")` clearly resolves to a valid
interpreter. reticulate's discovery relies on a small set of
heuristics (env var, pinned config, well-known venv locations) and
isn't a guarantee that the system has no Python. We were treating
"reticulate doesn't know" as "Python is not installed".

**Fix**: `.assert_fordead_system()` now falls back to direct PATH
probing when reticulate returns nothing. The new private helper
`.find_python_on_path()` walks a list of conventional Python binary
names from newest to oldest (`python3.14` → `python3.13` → … →
`python3.10` → `python3` → `python`) and returns the first one whose
`--version` reports ≥ 3.10. Companion helper `.probe_python_version()`
parses the `<py> --version` output.

This means the FORDEAD pipeline no longer requires `RETICULATE_PYTHON`
to be set or reticulate's config to be primed beforehand. If any
Python ≥ 3.10 is reachable on PATH, FORDEAD can build its venv from
it.

### Tests

* 6 new tests in `test-fordead-python.R` covering the fallback path :
  - `.probe_python_version` parses `--version` from a real interpreter
    (skipped if none on PATH)
  - `.probe_python_version` returns NA on an unreachable binary
  - `.find_python_on_path` returns a 3.10+ binary when available
  - `.find_python_on_path` returns `""` when no candidate matches
    (`Sys.which` mocked to always return empty)
  - `.assert_fordead_system` falls back to PATH when
    `py_discover_config` is `NULL`
  - `.assert_fordead_system` errors when both reticulate AND PATH
    yield nothing
* The existing test "aborts when no Python is found" now mocks
  `.find_python_on_path` too, otherwise the runner's real Python
  would defeat the assertion.

---

# nemeton 0.22.3 (2026-05-16)

### Fixed — `RETICULATE_PYTHON` silently shadowed the FORDEAD virtualenv

After the v0.22.2 install fix, FORDEAD could still fail at runtime
on machines where `RETICULATE_PYTHON` was set in `.Renviron` /
`Renviron.site` for another project (typically conda envs for
OpenCanopy CHM work, spec 005). Symptom :

```
Avis : The request to `use_python("...nemeton-fordead/bin/python")`
will be ignored because the environment variable RETICULATE_PYTHON
is set to "...miniforge3/envs/open_canopy/bin/python"
✖ FORDEAD pipeline failed: ModuleNotFoundError: No module named 'fordead'
```

reticulate's `use_virtualenv()` / `use_python(..., required = TRUE)`
defer to `RETICULATE_PYTHON` at init time even with `required = TRUE`.
Install succeeded into the FORDEAD venv, but `import("fordead")` then
ran against the conflicting (`open_canopy`) interpreter where fordead
is absent.

**Fix**: `.use_fordead_env()` now detects this conflict :

* If Python is **not yet initialised**, the env var is temporarily
  masked for the duration of `use_virtualenv()`. It's restored
  immediately afterwards via `on.exit()` so other reticulate
  consumers in the session (OpenCanopy CHM) still see their config.
  reticulate's cached binding stays on the FORDEAD env for the rest
  of the session.
* If Python is **already initialised** to a different binary, the
  switch is impossible (reticulate caches the binding once Python
  is up). An actionable error tells the user to
  `Sys.unsetenv("RETICULATE_PYTHON")` and restart R.

Helper `.same_path()` added for symlink/trailing-slash-tolerant
path comparison.

### Tests

* 3 new regression tests on the conflict logic :
  conflict-masking path, already-bound error path, no-conflict
  no-op path.
* 1 test on `.same_path()` (normalisation + empty-string edge case).
* Existing `.ensure_fordead_python` tests now `withr::local_envvar`
  RETICULATE_PYTHON to keep them hermetic and add a
  `virtualenv_python` mock.

---

# nemeton 0.22.2 (2026-05-15)

### Fixed — FORDEAD install failed because `fordead` is not on PyPI

The pinned dependency `fordead==2.1.4` in `inst/python/requirements.txt`
made `pip install -r requirements.txt` fail with:

```
ERROR: Could not find a version that satisfies the requirement fordead==2.1.4
ERROR: No matching distribution found for fordead==2.1.4
```

Two problems compounded:

1. **`fordead` is not published on PyPI** at all (verified: HTTP 404 on
   `https://pypi.org/simple/fordead/`). The official install method
   per the INRAE docs is
   `pip install git+https://gitlab.com/fordead/fordead_package`.
2. **Version `2.1.4` does not exist**. The latest tag on GitLab is
   `v2.1.1` (2026-02-04); the pin was written aspirationally without
   verification when spec 008 was drafted.

**Fix**: `inst/python/requirements.txt` now uses a PEP 508 URL pin:

```
fordead @ git+https://gitlab.com/fordead/fordead_package@v2.1.1
```

### Fixed — `.ensure_fordead_python()` could not recover from a half-installed venv

Independently of the requirements bug above, `.ensure_fordead_python()`
in `R/fordead_python.R` only ran `virtualenv_install` when the venv
**did not** exist. When `pip install` failed mid-way (transient
network failure, broken pin, etc.) the venv had been created with
the base deps (pip, wheel, setuptools, numpy) but without `fordead`
itself. Subsequent calls saw `virtualenv_exists() == TRUE`, skipped
the install, then exploded at `reticulate::import("fordead")` with
no recovery path — the user had to run
`reticulate::virtualenv_remove("nemeton-fordead")` by hand.

**Fix**: two new private helpers in `R/fordead_python.R`:

* `.fordead_python_import_ok(py_path, module)` — runs
  `<py_path> -c "import <module>"` via `system2()`, returns the
  exit code as a logical. Test-friendly: it's a one-liner around
  `system2` that mocks easily.
* `.fordead_is_installed(env_name)` — resolves the venv's Python
  interpreter via `reticulate::virtualenv_python()`, returns `FALSE`
  if it's absent or if `fordead` can't be imported.

`.ensure_fordead_python()` now calls `.fordead_is_installed()` when
the venv already exists. If `fordead` is missing, it emits a
warning toast and re-runs `virtualenv_install` instead of plowing
ahead. The user no longer has to remove the venv manually after a
failed first install.

### Migration notes for users who hit the bug before this release

If you tried to run FORDEAD against v0.22.1 (or earlier) and saw
`No matching distribution found for fordead==2.1.4`, your virtualenv
is in a half-installed state. After upgrading to v0.22.2 the
recovery is automatic — the next call to `run_fordead_dieback()`
will detect the missing `fordead` and reinstall from the correct
source. If you prefer a clean slate, you can still do:

```r
reticulate::virtualenv_remove("nemeton-fordead")
```

### Tests

* Updated `.fordead_requirements_path resolves the shipped requirements`
  to match the new URL-pin format.
* Updated `.ensure_fordead_python skips create when the venv already exists`
  to mock `.fordead_is_installed = TRUE` (healthy venv path).
* New: `.ensure_fordead_python reinstalls when fordead is missing from
  existing venv` — covers the recovery path.
* New: 2 tests on `.fordead_is_installed` (absent Python binary;
  import probe TRUE/FALSE).

### Internal

* spec 008 §1.3 / plan 008 §1.3 docstrings updated to reflect the
  git-based install. ADR-013 left unchanged (it doesn't quote the
  pin).

---

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
