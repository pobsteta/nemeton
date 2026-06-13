# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For a narrative, per-feature description of each release, see
[NEWS.md](NEWS.md). This file is the concise, categorised trail.

## [Unreleased]

## [0.75.0] - 2026-06-13

### Changed

- RAG knowledge corpus (E7) curation of `inst/extdata/knowledge_corpus_v1.csv`
  (spec 009/009.1): removed the 12 internal MIT seed docs (tutorials +
  specs 005/008); added 54 references cited by the BILJOU tool (INRAE Nancy,
  forest water-balance model) under the conservative D5 license gate
  (`to_confirm` / `abstract_only` / `copyright`); promoted 8 institutional
  reports to `cleared` (ONF/RENECOFOR `LO-Etalab`, FAO paper 56 `CC-BY-NC`,
  EFI WSCTU n°1 `CC-BY`) with public source URLs. Manifest 39 → 81 docs
  (31 cleared / 50 to_confirm); full-text build plan 7 → 10 PDFs.

### Added

- `data-raw/{add_biljou_refs,clear_biljou_institutional,url_biljou_institutional}.R`
  — reproducible provenance scripts for the corpus curation above.

## [0.74.1] - 2026-06-12

### Fixed

- `build_project_monitoring_zones(..., replace = TRUE)` no longer fails with
  `FOREIGN KEY constraint failed` when re-building a project whose zones
  already own child rows (validation plots, FORDEAD alerts) on the **SQLite**
  backend. Root cause: the SQLite schema (`0001_init.sql`) had dropped the
  `ON DELETE CASCADE` clauses that the PostgreSQL schema carries on
  `plot.zone_id → monitoring_zone(id)` and `alert.plot_id → plot(id)`, so the
  upsert's `DELETE FROM monitoring_zone` was blocked under
  `PRAGMA foreign_keys = ON`. `.delete_project_zones()` now deletes the chain
  explicitly, child-first (`alert` → `plot` → `monitoring_zone`), in a single
  transaction — portable across both backends. No schema migration: adding the
  cascade on SQLite would require a table rebuild, incompatible with
  `db_migrate()`'s single wrapping transaction (`PRAGMA foreign_keys` is a
  no-op inside a transaction, and `defer_foreign_keys` does not clear the
  deferred violation left by the parent `DROP TABLE`).

## [0.74.0] - 2026-06-12

### Added

- RECONFORT end-to-end orchestration (spec 021, lot L2b.3):
  `run_reconfort_dieback(con, zone_id, cache_dir, …)` chains env → model →
  mask → tile → S2 ingest → vendored IOTA² map-production (sampling +
  classification ×2 + OSO masking + continuous score), producing the
  classification / probability / continuous-score rasters (EPSG:2154) and a
  `run_meta.json`. Each run stages a writable copy of the vendored glue
  (scripts + `iota2/` subtree + model + mask + year-partitioned S2 symlinks)
  under `cache_dir`, keeping the installed package read-only. 8 phases with a
  `progress_callback`. A post-condition guard aborts when the IOTA² subprocess
  (whose return code the upstream driver ignores) produces no continuous-score
  raster.
- `ensure_reconfort_oso_mask()` + `RECONFORT_OSO_MASK`: the OSO 2021 deciduous
  mask (~54 MB) is fetched on demand, MD5-verified and cached, with a
  `local_path` fallback (custom mask) — mirroring the RF model fetch (L2a).
  `binary_mask` control: `NULL` → OSO, a path → custom, `FALSE` → unmasked.
- Vendored map-production glue (Apache-2.0): `run_map_production_reconfort.py`,
  `mask_and_compress_rasters.py`, the two IOTA² cfg generators, and the static
  `iota2/` inputs (config, nomenclature, `external_features/custom_index.py`
  moved to its canonical path, `vector_db/random_points.*`).

### Notes

- A real run needs the `nemeton-reconfort` conda env + a GEODES account + tens
  of GB of S2 + OTB/Shark batch execution — opt-in, never in CI; unit tests
  mock every external step. The post-process → `alert` table stays in lot L3.

## [0.73.0] - 2026-06-11

### Added

- RECONFORT IOTA²-native S2 ingestion (spec 021, lot L2b.2):
  `reconfort_aoi_tiles()` resolves the Sentinel-2 MGRS tile(s) covering an
  AOI from a bundled France grid (`inst/extdata/s2_mgrs_tiles_fr.geojson`,
  188 tiles, no network); `reconfort_ingest_s2()` downloads MUSCATE L2A from
  GEODES (`pygeodes`) and unzips into the IOTA² layout, driving the vendored
  upstream scripts via a conda subprocess. GEODES config via
  `options(nemeton.geodes_config)`. Default collection
  `THEIA_REFLECTANCE_SENTINEL2_L2A` (the upstream `MUSCATE_*` example id
  400s on GEODES; confirmed by a real smoke). `reconfort_ingest_s2()` writes
  a per-run pygeodes config whose `download_dir` matches the per-tile
  `zip_path` (in the caller-supplied project cache, like FORDEAD's
  `cache_dir`), so download and unzip agree on the path; that copy carries
  the api_key so it lives in a private mode-600 tempfile, never in the cache,
  wiped after each tile. Post-condition guards abort when the (error-swallowing,
  exit-0) upstream downloader leaves `zip_path` empty or the unzip produces no
  scene folder. Heavy/opt-in, never in CI; end-to-end plumbing validated by a
  real smoke (`data-raw/smoke_reconfort_ingest.R`).

## [0.72.0] - 2026-06-11

### Added

- RECONFORT Python/IOTA² foundations (spec 021, lot L2b.1):
  `.ensure_reconfort_python()` locates and validates the conda IOTA²
  environment (`nemeton-reconfort`, never bootstrapped — cadrage D2);
  `RECONFORT_BANDS` (B04/B05/B06/B8A/B11/B12); vendored
  `inst/python/reconfort/custom_index.py` (CRswir/CRre indices, Apache-2.0,
  attributed in `inst/NOTICE`). No real run yet (pipeline in L2b.2/L2b.3).

## [0.71.0] - 2026-06-11

### Added

- RECONFORT model fetch (spec 021, lot L2a): `ensure_reconfort_model()`
  downloads the calibrated Random-Forest model on demand (5.7–197 MB,
  Apache-2.0), verifies size + MD5, and caches it; `local_path` short-circuits
  to a copy already on disk. `RECONFORT_MODELS` registry (4 versions) +
  `reconfort_model_info()`. No IOTA²/Python in this lot; upstream training
  code is out of scope. Base URL overridable via
  `options(nemeton.reconfort_model_base_url)`.

## [0.70.0] - 2026-06-11

### Added

- RECONFORT validity domain (spec 021, lot L1): `check_reconfort_validity()`,
  `load_reconfort_validity_zones()`, `RECONFORT_VALIDITY_DEPARTMENTS`
  (6 Centre-Val de Loire departments) and `RECONFORT_VALIDITY_SPECIES`
  (oak CHE / chestnut CHT / Scots pine PS). Ships
  `inst/extdata/reconfort_validity_zones.geojson` + the `data-raw/` build
  script. G3 guard-rail is **advisory, not blocking** (`advisory = TRUE`):
  RECONFORT has no upstream geographic lock. No Python in this lot.

### Deferred

- The `health_reconfort` NDP flag and `reconfort_anomalies` datasource
  (spec 021 §5) are postponed: they assumed a FORDEAD parity
  (`health_fordead` / `fordead_anomalies`) that never existed and does not
  fit the current `augmented` semantics of `detect_ndp()`.

## [0.69.2] - 2026-06-11

### Fixed

- `.fast_raster_trend()` (FAST `mode = "trend"`, spec 023): a year with a
  single in-season scene yields a one-layer SpatRaster, on which
  `terra::app(sub, fun)` errors ("number of values returned by 'fun' is not
  appropriate"). Replaced by layer-count-robust cell-wise primitives
  (`nlyr - countNA`, `terra::median`). Covered by `test-fast-trend.R`.

### Added

- spec 021 (RECONFORT, 3rd health-monitoring method for broadleaves):
  design docs only — `plan.md` (6 open questions resolved against the
  verified upstream repo) + `spec.md`. ADR-013 amendment A4 (multi-method
  health monitoring) lives in `nemetonplateform`.

### Changed

- CI back to green (R-CMD-check, tests, coverage, pkgdown). The `tests` job
  now runs the real suite via `devtools::test()`; `R-CMD-check` uses
  `--no-tests`/`--no-build-vignettes`; `pkgdown` gains `rsconnect` and a
  complete reference index (111 missing topics added). A capability guard
  (`skip_if_terra_write_broken()`) skips raster tests on a GitHub runner
  exhibiting a terra "no valid constructor" anomaly (not reproducible
  locally; the whole suite passes locally), running them fully everywhere
  else.

## [0.67.0] - 2026-06-04

### Added

- `prune_orphan_zone_caches()`: removes `zone_<id>/` cache directories
  whose zone no longer exists in `monitoring_zone` (orphaned by the
  spec-020 zone upsert, which assigns new ids). Covers the FAST / FORDEAD
  / sampling per-zone caches; `dry_run = TRUE` previews; shared caches
  (`sentinel2/`, `lidar_*`) are never touched.

## [0.66.0] - 2026-06-04

### Added

- Monitoring zones from UGF × BD Forêt v2 strata (spec 020): a project can
  own up to 4 zones `<project>_tot/_feu/_res/_mix` (UGF union, and its
  intersection with broadleaf / conifer / mixed strata classified via
  `tfv_g11`). New exports `build_project_monitoring_zones()`,
  `create_monitoring_zone()` (zone-only, no placettes — spec 017),
  `find_zones_by_project()`. Empty strata are skipped with a warning;
  `replace = TRUE` performs an idempotent upsert.
- Migration 0005 (pg + sqlite): `monitoring_zone` uniqueness relaxed from
  `project_uuid` to `(project_uuid, name)` — N zones per project.

### Fixed

- `register_monitoring_zone(project_uuid = …)` fetched the inserted zone
  id by `project_uuid` alone, which could return the wrong id under the
  spec-020 multi-zone model. Now keyed by `(project_uuid, name)`.

## [0.65.3] - 2026-06-03

### Added

- LRU GC for the FAST 0-4 mask cache: `compute_fast_alert_mask()` writes a
  timestamped `fast_alert_<ts>.tif` per call, so the mask directory grew
  unbounded. `.fast_alert_mask_gc()` now keeps at most
  `getOption("nemeton.fast_mask_keep", 20)` masks per zone (LRU by mtime),
  mirroring `.fast_raster_gc()` for the continuous COGs.

### Fixed

- The continuous-cache GC no longer deletes 0-4 masks. `.fast_raster_gc()`
  matched `^fast_.*\.tif$`, which caught `fast_alert_*` masks when
  `result_cache_dir == mask_cache_dir` (validation sampling on
  `fast_sampling/`). Tightened to `^fast_[A-Z].*\.tif$` (continuous
  `fast_NDVI_`/`fast_NBR_`/`fast_NDMI_` only), so the two caches are GC'd
  independently.

## [0.65.2] - 2026-06-03

### Changed

- FAST D6 cache COGs now use a verbose, deterministic filename
  `fast_<INDEX>_<MODE>_thr<threshold>_<from>_<to>_w<window>_<hash8>.tif`
  (was `fast_<index>_<mode>_<hash>.tif`). Key parameters are legible
  straight from the name; an 8-char slice of the unchanged D6 hash still
  discriminates the scene-id list and mask polygon. Same parameters yield
  the same name, so cache idempotence is preserved. Pre-0.65.2 files are
  no longer matched as hits — they recompute on first demand and are
  reclaimed by the LRU GC; remove them manually to free disk at once
  (see NEWS).

## [0.65.1] - 2026-06-03

### Fixed

- `.prewarm_fast_alerts()` now pre-warms the 6 FAST combinations
  (NDVI/NBR/NDMI × count/rolling) instead of 4, matching the public
  `read_fast_alert_rasters()` orchestrator. NDMI was added in 0.65.0 but
  the prewarm loop still skipped it, so the first NDMI selection in the
  app paid a cold compute instead of a D6 cache hit. A scene without B11
  (NDMI) takes the existing best-effort skip path (warn + `_failed`
  event), like NBR without B12. No API change.

## [0.65.0] - 2026-06-03

### Added

- `read_fast_alert_rasters()`: convenience orchestrator that builds the
  full FAST diagnostic in one call — the three indices (NDVI, NBR, NDMI)
  in both modes (count, rolling), i.e. up to six rasters. Returns a named
  list keyed `"<index>_<mode>"`; each map shares the COG cache, the
  content-addressed result cache (spec 017 D6) and the zone mask. Missing
  index → `NULL` slot (stable shape). `indices`/`modes` restrict the set.

### Fixed

- NDMI FAST alert maps were never produced: `.enumerate_cache_scenes()`
  had no `NDMI` branch in its `index` switch, so an NDMI request matched
  zero cached scenes and `read_fast_alert_raster(index = "NDMI")` /
  `compute_fast_alert_mask()` always returned `NULL` despite B08 + B11
  being cached. The switch now maps `NDMI -> B08 + B11` and aborts on an
  unknown index instead of failing silently (spec 019 regression).

## [0.64.0] - 2026-06-03

### Added

- NDMI index in the FAST health-monitoring subsystem (spec 019):
  `NDMI = (B08 - B11) / (B08 + B11)` (NIR − SWIR1), a vegetation-moisture
  proxy. `build_index_stack()`, `extract_pixel_timeseries()`,
  `read_fast_alert_raster()` and `compute_fast_alert_mask()` accept
  `index/indices = "NDMI"`; `read_s2_band_raster()` /
  `read_s2_band_stack()` accept band `"B11"`. The FAST default stays NDVI
  (back-compatible); the D6 cache key includes the index, so NDMI COGs
  (`fast_NDMI_*`) never collide with existing NDVI/NBR caches.

### Changed

- `ingest_sentinel2_timeseries()` accepts `bands = "NDMI"` and now caches
  B11 systematically (best-effort, spec 019 D3): a scene lacking the B11
  asset is skipped without failing NDVI/NBR ingestion. `.s2_required_bands()`
  maps `NDMI -> B08, B11`; `.cache_scene_bands()` gains an
  `optional_bands` argument.

## [0.63.0] - 2026-06-03

### Added

- `R/knowledge-corpus.R` — public API for RAG corpus administration
  (spec 009.2), so a `nemetonshiny` admin tab can edit the manifest and
  import the corpus without re-implementing business logic:
  `knowledge_manifest_vocab()` (single source of truth for the
  controlled vocabularies), `knowledge_manifest_path(writable)` (packaged
  seed vs writable project copy, D1), `read_knowledge_manifest()`,
  `validate_knowledge_manifest()` (structured issues incl. license-gate
  D5 invariants), `write_knowledge_manifest()` (deterministic minimal
  quoting), and `build_knowledge_corpus(con, …, dry_run, progress)`
  (ingestion orchestrator returning a structured per-document report).

### Changed

- `data-raw/build_knowledge_corpus.R` reduced to a thin CLI wrapper over
  `build_knowledge_corpus()`; environment-variable semantics (including
  the "no fallback to `NEMETON_DB_URL`" safety rule) preserved.
- `tests/testthat/test-knowledge-corpus-manifest.R` now consumes
  `knowledge_manifest_vocab()` instead of duplicating the controlled
  vocabularies.

## [0.62.0] - 2026-06-02

### Added

- `ingest_knowledge_reference()` — exported reference-only ingestion for
  the RAG corpus (spec 009.1 §5). Stores a single citation chunk (title,
  author, year, URL + optional abstract) without the protected full
  text; records `link_only` / `abstract_only` under the JSON
  `metadata.ingestion_mode` (no schema change). Delegates chunk/embed/
  insert to `ingest_knowledge_document()` (DRY).
- `data-raw/build_knowledge_corpus.R` now routes `abstract_only` /
  `link_only` manifest rows (previously skipped) through
  `ingest_knowledge_reference()`, under the same D5 license gate.

## [0.61.2] - 2026-06-02

### Changed

- RAG corpus manifest: license arbitration (spec 009.1 D5, decided by
  Pascal). `bernard_doridant_2024_fordead` (ONF/DSF, basis of the R5
  guardrails) cleared as Licence Ouverte; `set_revue_foret_croissance_climat`
  cleared as open/CC-BY (the only `to_confirm` row with a local PDF, now
  ingestible). The four copyright papers (Mouret 2022, Fassnacht 2016,
  McCool 1987, Beven & Kirkby 1979) stay `to_confirm`. Manifest is now
  35 cleared / 4 to_confirm.

## [0.61.1] - 2026-06-02

### Fixed

- RAG corpus manifest (`inst/extdata/knowledge_corpus_v1.csv`): the
  `set_revue_foret_croissance_climat` row was `status = cleared` while
  its `license` was the literal `to-confirm` placeholder, which would
  have let `build_knowledge_corpus.R` ingest it despite an unconfirmed
  license (contrary to spec 009.1 D5). Status reset to `to_confirm`.

### Added

- `tests/testthat/test-knowledge-corpus-manifest.R` — integrity guards
  for the packaged corpus manifest: column set, unique slug `doc_id`,
  controlled enums (`license` / `status` / `ingest_strategy` / `lang` /
  `doc_type` / `license_commercial_ok`), valid family/profile codes, and
  the D5/§5 safety invariants (a `cleared` row needs a confirmed license;
  a `copyright` document is never `full`-ingested).
- `inst/NOTICE`: a "RAG knowledge corpus" section attributing the corpus
  sources by license class.

## [0.61.0] - 2026-06-02

### Added

- `ingest_sentinel2_timeseries()` gains opt-in `prewarm_alerts = FALSE` +
  `prewarm_mask_cache_dir = NULL` (spec 018). When `prewarm_alerts = TRUE`,
  a successful ingestion chains on four `read_fast_alert_raster()` calls
  (`NDVI`/`NBR` × `count`/`rolling`, default threshold, `window_days = 30`)
  so the four usual FAST alert maps land in the D6 result cache and the
  app's FAST tab is instant on first visit. Per-combination failures warn
  and are skipped (the others still complete); the pre-warm polls
  `cancel_path` between combinations and never starts on a cancelled
  ingestion. New internal helper `.prewarm_fast_alerts()`. Progress
  heartbeat events `fast_prewarm:<index>_<mode>` / `_done` / `_failed`.

## [0.60.0] - 2026-06-02

### Removed

- `read_obs_pixel()`, `list_fast_alerts_for_zone()` and `detect_alerts()`
  (deprecated in v0.58.0) are removed. Use `build_index_stack()` /
  `extract_pixel_timeseries()` and `read_fast_alert_raster()` /
  `compute_fast_alert_mask()` instead. Files `R/read_obs_pixel.R`,
  `R/fast_alerts.R`, `R/alerts.R` and their `man/` pages deleted; exports
  removed from `NAMESPACE`.
- `CREATE TABLE obs_pixel` (and the PG `create_hypertable` call) removed
  from `0001_init.sql` (PG + SQLite): fresh databases never create the
  table. Migration `0004_drop_obs_pixel.sql` is kept for existing
  databases (idempotent DROP, no-op on a fresh DB).

## [0.58.0] - 2026-06-02

### Removed

- `ingest_sentinel2_timeseries()` no longer extracts per-plot means nor
  inserts into `obs_pixel`; it only primes the COG band cache
  (B04/B08/B12). STAC resolution, the on-disk band cache and the `s2:*`
  heartbeats are unchanged. The `n_obs_inserted` summary field is gone;
  `skip_cached` now operates on the COG cache (a scene is skipped when
  all its required band COGs already exist on disk).
- Internal helpers `.insert_obs_pixel()` and `.find_cached_obs_dates()`
  removed; `.extract_scene_obs()` replaced by `.cache_scene_bands()`.

### Changed

- Migration `0004_drop_obs_pixel.sql` (PG + SQLite) drops the `obs_pixel`
  table (idempotent). The pure per-pixel FAST diagnostic
  (`read_fast_alert_raster()`, spec 017) has been its only path since
  v0.55.0.

### Deprecated

- `read_obs_pixel()`, `list_fast_alerts_for_zone()` and `detect_alerts()`
  (all legacy `obs_pixel` consumers) are deprecated and emit a
  `cli::cli_warn`; scheduled for removal in v0.60.0. Use the per-pixel
  COG cache (`build_index_stack()` / `extract_pixel_timeseries()`) and
  `read_fast_alert_raster()` / `compute_fast_alert_mask()` instead.

## [0.57.0] - 2026-06-02

### Added

- Opt-in multi-core scene processing (spec 017 D4). `build_index_stack()`
  and `read_fast_alert_raster()` / `compute_fast_alert_mask()` gain a
  `parallel = FALSE` argument; when `TRUE` and `furrr` is installed the
  per-scene index compute runs in `furrr::future_map()` (caller sets the
  `future::plan()`). Workers return `terra::wrap()`-ed rasters that the
  main process unwraps; results are identical to sequential. Falls back
  to sequential when `furrr` is absent. Closes spec 017.

## [0.56.0] - 2026-06-01

### Added

- Content-addressed persistence of the FAST alert raster (spec 017 D6).
  `read_fast_alert_raster()` gains `cache_result = TRUE` and
  `result_cache_dir = NULL`: the continuous raster is written as a COG
  keyed by a hash of its inputs (scenes + index + threshold + mode +
  window_days + dates + mask WKT), so a same-input revisit is served
  instantly from disk and the cache self-invalidates on any change. At
  most `getOption("nemeton.fast_raster_keep", 20)` COGs kept per zone.
- `compute_fast_alert_mask()` passes `cache_result` / `result_cache_dir`
  through; quartiles are recomputed from the persisted COG without a
  raster recompute. Hash via `rlang::hash` (no `digest` dependency).

## [0.55.2] - 2026-06-01

### Fixed

- `db_migrate()` : `INSERT INTO schema_migration … ON CONFLICT DO NOTHING`
  (sans colonne cible) n'est valide que sur SQLite ≥ 3.35.0 ; routage par
  backend vers `INSERT OR IGNORE` sur SQLite (no-op sous PostgreSQL).
- `.insert_fordead_alerts()` et `detect_alerts()` : ajout de `WHERE 1=1`
  sur le `SELECT` des `INSERT … SELECT … ON CONFLICT` pour lever
  l'ambiguïté d'analyse UPSERT/jointure de SQLite (`near "DO": syntax
  error`). Complète le correctif `.insert_obs_pixel()` de la v0.55.1.
- Tests de non-régression SQLite ajoutés (`test-fordead-alert-insert-sqlite.R`,
  `helper-sqlite.R`).

## [0.55.1] - 2026-06-01

### Fixed

- `.insert_obs_pixel()` : correction d'une erreur fatale `near "DO":
  syntax error` sur le backend SQLite local. L'`INSERT … SELECT … ON
  CONFLICT … DO NOTHING` souffrait de l'ambiguïté d'analyse UPSERT/jointure
  de SQLite ; ajout d'une clause `WHERE 1=1` sur le `SELECT` pour lever
  l'ambiguïté (no-op sous PostgreSQL). Test de non-régression SQLite ajouté.
## [0.55.0] - 2026-05-31

### Changed

- FAST alert map (`read_fast_alert_raster`) is now **mono-index**: new
  `index = c("NDVI","NBR")` (default NDVI) and a single `threshold`
  replace `threshold_ndvi`/`threshold_nbr`; the NDVI-OR-NBR combination
  is dropped (spec 017 D1).
- `compute_fast_alert_mask` discretises into **quartiles of the
  strictly-positive pixels** (class 0 = no alert; classes 1-4 =
  `c(0, q25, q50, q75, Inf)`) for both `count` and `rolling`, replacing
  the fixed breaks (spec 017 D2). `breaks` stays overridable.
- `read_fast_alert_raster` enumerates scenes **from the COG cache**, not
  from `obs_pixel` — the raster diagnostic is now independent of
  placettes (spec 017 D3). `con`/`zone_id` are used only for the UGF mask.

### Added

- Internal helpers `.enumerate_cache_scenes()`, `.s2_scene_date()`,
  `.fast_alert_quartile_breaks()`.
- `specs/017-fast-alert-raster-perf/spec.md` (D1-D6; perf phases D6/D4
  follow in v0.56.0 / v0.57.0).

## [0.54.0] - 2026-05-31

### Changed

- Test-DB isolation guard. Integration DB access now goes through
  `.guard_test_db()` + `.test_db_connect()` in `helper-monitoring.R`,
  which require `NEMETON_DB_URL_TEST` to be set, distinct from
  `NEMETON_DB_URL`, and free of application tables
  (`projects`/`users`/`parcels`). This prevents the destructive
  `DROP TABLE … CASCADE` integration helper from wiping a production DB
  (villards incidents 2026-05-25 & 2026-05-31). Without
  `NEMETON_DB_URL_TEST`, integration tests skip (suite stays green).
  Override with `NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE`.

### Added

- `tests/testthat/test-helper-guards.R` — offline tests for the guard.
- `.Renviron.example` documenting `NEMETON_DB_URL` / `NEMETON_DB_URL_TEST`.

## [0.53.0] - 2026-05-31

### Added

- `ingest_sentinel2_timeseries(..., cancel_path = NULL)` — cooperative
  file-based cancellation. The worker polls `file.exists(cancel_path)`
  between tiles; when the flag appears it exits cleanly after the
  current tile, keeping already-committed tiles. The summary gains a
  `status` column (`"success"` / `"cancelled"`) and an `s2:cancelled`
  progress event.
- `run_fordead_dieback(..., cancel_path = NULL)` — same, polled at phase
  boundaries (after ingest / fit / predict). Returns `status =
  "cancelled"` with a `phase` field; emits `fordead:cancelled`. The
  Python subprocess is not force-killed.
- A cancel flag already present at entry is ignored as a stale leftover
  (with a warning); `cancel_path = NULL` performs zero filesystem polls.

### Changed

- The `ingest_sentinel2_timeseries()` summary `data.frame` now carries a
  trailing `status` column (additive; by-name access unaffected).

## [0.52.1] - 2026-05-30

### Fixed

- `build_index_stack()` now aligns per-scene layers onto the **union** of
  their extents (NA-padding via `terra::extend()`) instead of cropping to
  the intersection. Fixes multi-tile MGRS AOIs (e.g. villards on
  T31TFM ⊂ T31TGM) where the pixel NDVI/NBR map was silently trimmed to
  the narrowest tile's strip.
- Multi-CRS guard in `build_index_stack()`: layers in a different CRS are
  reprojected onto the first layer's CRS before the union; non-coinciding
  grids fall back to a single `terra::resample()` onto the widest layer.
- The FAST alert path (`read_fast_alert_raster()` /
  `compute_fast_alert_mask()`) is unchanged — its per-MGRS-tile grouping
  + `mosaic(fun = "max")` already covers multi-tile AOIs and avoids
  double-counting the S2 overlap strip; rationale comment updated.

### Changed

- `build_index_stack()` "Skipped N/total scenes (incomplete cache)"
  message downgraded from a per-call `cli_warn` to
  `rlang::inform(.frequency = "once")` (was spamming ~12 identical lines
  per Shiny load).

## [0.52.0] - 2026-05-29

### Added

- RAG knowledge base for AI perspectives (E7, spec 009) — seven exported
  functions in `R/rag.R`: `enable_rag()`, `ingest_knowledge_document()`,
  `embed_query()`, `retrieve_knowledge()`, `list_knowledge_documents()`,
  `delete_knowledge_document()`, `format_citations()`.
- Opt-in RAG migration `inst/db/migrations/{pg,sqlite}/rag/0004_rag.sql`
  (`knowledge_document` + `knowledge_chunk`), applied by `enable_rag()`
  rather than the default `db_migrate()` sequence (PostgreSQL needs
  pgvector; ADR-012).
- Dual-backend retrieval: pgvector `<=>` on PostgreSQL, R-side cosine on
  SQLite (JSON-encoded embeddings). Embedding providers: Mistral
  (default), OpenAI, Voyage AI.
- `pdftools` added to Suggests (offline PDF ingestion).

### Changed

- `vector(3072)` embedding column carries **no** ivfflat index (pgvector
  caps ivfflat/hnsw at 2000 dims); PostgreSQL retrieval is exact KNN.
  halfvec(3072)+hnsw deferred to ADR-012 when the corpus grows.

## [0.49.1] - 2026-05-27

### Added

- `create_validation_sampling_plan(..., control_classes = c(0L))` —
  new argument to relax the strict "class 0 = healthy" filter for
  control plots. Useful on heavily disturbed zones where no
  class-0 cell exists (villards FAST: all 8471 UGF pixels were
  class 4).
- Enriched warning when no control candidates : the message now
  reports the alert raster's class distribution to help the user
  pick a relaxed `control_classes` value.
- `alert_class` column of control plots now reflects the actual
  cell value (was hard-coded to `0L`).

## [0.49.0] - 2026-05-27

### Changed

- All raster readers in the FAST / FORDEAD pipeline mask their
  outputs to the UGF polygon by default (`apply_zone_mask = TRUE`).
  Pixels outside the UGFs become `NA`. The on-disk COG cache is
  unchanged (still a rectangle aligned to the pixel grid) ; the
  mask is applied after read, before return. Spec 016.
- `read_fast_alert_raster()`, `compute_fast_alert_mask()`,
  `read_fast_alert_mask()`, `read_fordead_dieback_mask()` gain
  `apply_zone_mask = TRUE` / `mask_polygon = NULL` arguments. Pass
  `apply_zone_mask = FALSE` for the pre-v0.49.0 rectangle output.
- `build_index_stack()` gains `mask_polygon = NULL`. Lower-level
  helper without `con` / `zone_id`, the polygon must be passed
  explicitly.
- `extract_pixel_timeseries()` gains `zone_polygon = NULL` /
  `warn_outside_zone = TRUE`. No raster mask (single-point query),
  only a warning when the click sits outside the UGFs.

### Added

- Internal helper `.apply_zone_mask(raster, zone_polygon)` in
  `R/zone_aoi.R`. Wraps `terra::mask()` with CRS reprojection and
  a defensive `tryCatch` (failure → unmask with `cli_warn`).

### Notes

- `read_obs_pixel()` is unchanged. The existing
  `plot.zone_id = $zone_id` filter IS the UGF membership filter
  de facto (plots are registered inside the UGFs by
  `register_monitoring_zone()`). No spatial `ST_Within` post-filter
  added.

## [0.48.3] - 2026-05-27

### Fixed

- Cache S2 : memoize the COG tile native extent per MGRS code in a
  session-scoped environment. The tile-aware second chance
  introduced in v0.48.2 was paying ~10-25 s per band per scene for
  the GET range that reads the COG header, even though all bands of
  all dates of the same MGRS tile share the same native extent.
  Villards full re-validation drops from ~1 h to ~50 s.

### Added

- Internal helpers `.s2_tile_ext_cache` (environment),
  `.s2_tile_ext_memoize(tile_code, href)`, and
  `.s2_tile_ext_cache_clear()` (test helper).

## [0.48.2] - 2026-05-27

### Fixed

- Cache S2 predicate gains a tile-aware second chance : when the
  snap-to-grid check (v0.48.1) says STALE, the COG header is read
  lazily (`terra::rast(href)`, ~1 s, no pixel decode) to obtain the
  tile's native extent, `needed_ext` is clipped to that extent, and
  the predicate is retried. Fires CACHE-HIT when the cached file is
  the legitimate clip of the AOI to the MGRS tile boundary (the
  common case on multi-tile AOIs like villards spanning T31TFM +
  T31TGM). Eliminates the residual "fake STALE" after v0.48.1's
  snap-to-grid.

## [0.48.1] - 2026-05-27

### Fixed

- Cache S2 validation predicate switches from raw-float
  `.ext_contains(tol = 40m)` to pixel-grid-aware
  `.ext_contains_at_grid(res, tol_pixels = 1)`. Snaps both extents to
  the COG's pixel grid before comparison → sub-pixel jitter from
  `sf::st_transform(zone_polygon, raster_crs)` is eliminated at the
  source. Resolves villards CACHE-STALE storm (~6 h ingest → ~30 s
  on a warm cache).
- New ENV bypass `NEMETON_S2_CACHE_SKIP_VALIDATION` (`"TRUE"` or
  `"1"`) — emergency escape hatch to trust every cached file
  blindly.
- Diagnostic log on CACHE-STALE now shows snapped extents +
  signed per-side margin (`delta_m`) for quick triage.

### Added

- Internal helpers `.snap_ext_to_grid(ext, res)` and
  `.ext_contains_at_grid(outer, inner, res, tol_pixels)`.
- Internal helper `.cache_skip_validation()` (env var check).

## [0.48.0] - 2026-05-26

### Added

- `lasR` fallback to derive MNT/MNH from cached `.laz` tiles when
  IGN pre-rasterized downloads fail. See `compute_dtm_chm_from_laz()`,
  `resolve_project_dem/chm(try_compute_from_laz = TRUE)`. Diagnostic
  helpers `probe_ign_lidar_tile()` / `probe_ign_lidar_tiles()`
  classify IGN failures. `lasR (>= 0.10.0)` in Suggests.

## [0.47.5] - 2026-05-26

### Fixed

- `build_index_stack()` (spec 010) now computes the intersection of
  per-scene extents and crops each layer to that common extent
  before `terra::rast(layers)`. Fixes `[rast] extents do not match`
  triggered by mixed-vintage cache files (different AOI snapping
  across app sessions). Returns `NULL` with a warn if no overlap.
  Unblocks Carte FAST, Alertes FAST, FAST validation sampling.

## [0.47.4] - 2026-05-25

### Fixed

- Bump cache-hit tolerance from `1 * max(res)` (10/20 m) to
  `4 * max(res)` (40/80 m). 1-pixel tolerance still triggered
  CACHE-STALE on villards because previous-session cache files were
  written for a slightly different `sf::st_union(parcels)` polygon.

## [0.47.3] - 2026-05-25

### Fixed

- `.ext_contains(outer, inner, tolerance = 0)` gains a `tolerance`
  argument (CRS units). The cache-hit lookup in
  `.get_s2_band_raster()` now passes `tolerance =
  max(terra::res(r_cached))` so a sub-pixel mismatch between the
  cached extent and the AOI doesn't trigger a CACHE-STALE. Closes
  the villards CACHE-STALE storm — projected refetch from ~4 h to
  ~10-30 min. Strict (`tolerance = 0`) default for back-compat.
- `[s2_cache]` verbose log now reports the tolerance value when
  CACHE-STALE fires anyway: `… (tol=10m), refetching`.

## [0.47.2] - 2026-05-25

### Fixed

- `tests/testthat/helper-monitoring.R::with_clean_db()` now refuses to
  run when `NEMETON_DB_URL_TEST` is unset or equal to `NEMETON_DB_URL`
  (the helper's `reset_schema()` would otherwise wipe the user's
  production monitoring data). Override via
  `NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE` for CI on an empty DB.
  Closes the gap that destroyed villards on 2026-05-25.

## [0.47.1] - 2026-05-25

### Fixed

- `.fordead_is_installed()` and `.ensure_fordead_python()` swap
  `cli::cli_alert_warning()` / `cli::cli_alert_info()` for
  `cli::cli_warn()` / `cli::cli_inform()` so the emitted warning /
  message condition is catchable by `expect_warning()` /
  `expect_message()` (the `_alert_*` family is cosmetic only). No
  user-visible change.
- `test-fordead-python.R` — `.assert_fordead_system` test captures
  `base::requireNamespace` before mocking so the mock's else-branch
  doesn't recurse into itself.

Suite `test-fordead-python.R` 57 ✓ (was 3 fails). Closes the « ~9
échecs préexistants » documented in v0.43.2.

## [0.47.0] - 2026-05-25

### Added

- `fordead_alert_mask(alert_raster, classes, buffer_m)` — exported.
  Extracts alert cells from a categorical 0-4 SpatRaster (FORDEAD
  `dieback_mask` or FAST mask), preserves their class value (NA
  elsewhere), with optional metric buffer dilation. Output is suitable
  both as mask AND as priority raster.
- `compute_fast_alert_mask(con, zone_id, ..., cache_dir, mask_cache_dir,
  breaks)` — exported. Discretises [read_fast_alert_raster()] (v0.46.0)
  to the 0-4 scale aligned with FORDEAD, persists under
  `<mask_cache_dir>/zone_<id>/fast_alert_<ts>.tif`.
- `read_fast_alert_mask(con, zone_id, run_id, cache_dir)` — exported.
  Strict mirror of [read_fordead_dieback_mask()] reading the persisted
  0-4 mask, NULL when no file matches.
- `create_validation_sampling_plan(zone, alert_raster, n_validation,
  n_control, classes, buffer_m, source, seed)` — exported. Single
  entry point returning an `sf` POINT (EPSG:2154) combining
  validation plots (unequal-probability GRTS on the alert mask) +
  control plots (equiprobable GRTS on healthy class 0), with TSP
  visit order. Spec 014 phase A.

### Internal

- Helpers `.draw_grts_weighted()`, `.draw_grts_equiprobable()`,
  `.compute_visit_order()` in `R/validation_sampling.R`.

## [0.46.0] - 2026-05-24

### Added

- `read_fast_alert_raster(con, zone_id, threshold_ndvi, threshold_nbr,
  date_from, date_to, mode, window_days, cache_dir)` — exported.
  Produces a single-band `SpatRaster` (EPSG:2154) of FAST alerts at
  native S2 pixel resolution. Two modes: `"count"` (integer per-pixel
  alert-day count) and `"rolling"` (continuous deficit magnitude on
  the trailing window). Multi-tile MGRS AOIs handled via per-tile
  compute + mosaic. Spec 013.
- Internal helpers `.compute_alert_count()`, `.compute_alert_rolling()`,
  `.s2_mgrs_tile()` in `R/fast_alert_raster.R`.

## [0.45.0] - 2026-05-23

### Changed

- FAST (`ingest_sentinel2_timeseries()`) and FORDEAD-ingest
  (`ingest_s2_raw_bands_to_cache()`) now resolve their Sentinel-2
  AOI through `monitoring_zone.zone_wkt` via the new shared helper
  `.get_zone_aoi()` (moved to `R/zone_aoi.R`). Both pipelines crop
  the COG to the same extent → the on-disk cache is reusable across
  them. Spec 012.
- `.extract_scene_obs()` gains an optional `crop_aoi` argument.
- Defensive fallback to per-plot bbox + warn when `zone_wkt` is
  empty or unparseable.

### Added

- `R/zone_aoi.R` — shared resolver `.get_zone_aoi(con, zone_id)`.

## [0.44.0] - 2026-05-23

### Added

- Migration `0003_project_uuid` (PG + DuckDB) adding
  `monitoring_zone.project_uuid TEXT` and a partial UNIQUE index on
  non-NULL values. Spec 011.
- `register_monitoring_zone(..., project_uuid = NULL)` — optional new
  argument, persisted on the zone row when non-NULL.
- `find_zone_by_project(con, project_uuid)` — new exported function
  returning the bound zone id or `integer(0)`. Does **not** fall back
  to a `name`-based lookup.

## [0.43.2] - 2026-05-23

### Fixed

- `.same_path()` (`R/fordead_python.R`) collapses `/./`, duplicate
  slashes and a trailing slash before comparing — `normalizePath(mustWork
  = FALSE)` leaves non-existent paths untouched, so the identity test
  produced false negatives whenever one input had a redundant segment.
- `.validate_date_range()` (`R/fordead_stac.R`) wraps `as.Date()` in
  `tryCatch`: recent R errors on an unparseable string instead of
  returning `NA` with a warning, which was swallowing the actionable
  "must parse as a date (ISO yyyy-mm-dd)" message.
- `diagnose_s2_cache()` (`R/monitoring.R`) orphan cleanup uses `unlink(
  recursive = TRUE)` — `recursive = FALSE` never removes a directory,
  even an empty one, so the cleanup branch was a silent no-op.
- `test-monitoring.R` progress-callback assertion expects the
  `s2:cache_lookup` event introduced earlier and indexes events by
  `current` key rather than by position.

## [0.41.2] - 2026-05-20

### Fixed

- Sentinel-2 STAC searches returned ESA reprocessing duplicates (the
  same acquisition republished under a new processing baseline) as
  distinct scenes — doubling the cache footprint (~14 % of scenes on
  a real zone) and feeding FORDEAD two items with the same
  `datetime`. `stac_search_s2()` and `.build_stac_collection_for_aoi()`
  now collapse such duplicates by acquisition identity (mission +
  sensing time + orbit + MGRS tile), keeping the latest baseline.

### Added

- Internal helpers `.s2_split_product_id()` and
  `.dedup_s2_reprocessed()` — Sentinel-2 reprocessing-duplicate
  detection and removal.

## [0.41.1] - 2026-05-20

### Fixed

- FORDEAD version probe read the `fordead.version` *attribute* (a
  function, not a string), so the installed version never matched
  the pin and `pip install --upgrade` ran on every
  `run_fordead_dieback()` call. `.fordead_python_version()` now
  reads `importlib.metadata.version("fordead")`; the pipeline start
  banner reuses the same probe, so `fordead_version` is reported
  correctly instead of `NA`.

### Added

- Internal helper `.python_capture_stdout()` — mockable `system2()`
  wrapper used by the FORDEAD version probe.

## [0.40.0] - 2026-05-20

### Added

- `theia_signed_href()` — resolves a `/vsicurl/`-prefixed signed
  THEIA asset URL via the `teledetection` Python SDK (reticulate).
- `load_theia_source()` year mode now signs the asset URL through
  the SDK and reads it via `/vsicurl/` — the validated
  authenticated path for THEIA assets.

## [0.39.1] - 2026-05-20

### Fixed

- `theia_configure_s3()` reads `TLD_ACCESS_KEY` / `TLD_SECRET_KEY`
  (the THEIA API-key pair) instead of `THEIA_S3_*`, and the S3
  region is `sm1` (not `us-east-1`). GDAL `/vsis3/` reads the
  THEIA assets directly — no Python SDK needed.

## [0.39.0] - 2026-05-20

### Added

- `stac_get_item()` — fetch a single STAC item by id.
- `resolve_theia_assets()` / `load_theia_source()` gain a `year`
  argument to target one year of an annual THEIA collection
  (FORMSpoT). `formspot` in `FR.json` gains `item_id_template`,
  `asset_template` and `years`.

## [0.38.0] - 2026-05-20

### Added

- `theia_configure_s3()` — configures GDAL `/vsis3/` for
  authenticated reads of the THEIA S3 object store; credentials
  from `THEIA_S3_ACCESS_KEY` / `THEIA_S3_SECRET_KEY` env vars.
- `services.theia_s3` entry in `FR.json` (endpoint, bucket).

### Changed

- `resolve_theia_assets()` returns `/vsis3/` paths (gateway /
  `s3://` / `https://` hrefs are normalised).
- `load_raster_source()` `path` argument accepts remote
  (`s3://`, `http(s)://`, `/vsi*`) paths, not only local files.

## [0.37.0] - 2026-05-20

### Changed

- THEIA STAC API endpoint corrected to
  `https://api.stac.teledetection.fr` (verified against the
  FORMSpoT data-access notebook). `services.theia_stac` documents
  the required teledetection API-key authentication.
- FORMSpoT metadata verified: collection `FORMSpoT`, yearly items
  `FORMSpoT-{year}` (2014-2024), `height_{year}` assets, height in
  decimetres.

### Added

- New datasource `formspot_delta` — FORMSpoT-∆ forest-disturbance
  polygons (`consumed_by`: R5, T2).

## [0.36.1] - 2026-05-20

### Fixed

- `services.theia_stac.url` set to the verified THEIA MTD STAC API
  root; `forms_t` gains `stac_collection: "forms-t"`.
- Theia STAC resolver `"to confirm"` guard now uses a substring
  match, correctly rejecting the `"to confirm at the Theia
  catalogue"` placeholders.

## [0.36.0] - 2026-05-20

### Added

- THEIA STAC resolver (`R/theia_stac.R`): `stac_search_items()`,
  `resolve_theia_assets()` and `load_theia_source()` materialise
  the Theia datasources from the THEIA STAC API. New
  `services.theia_stac` entry in `FR.json` (STAC API URL still to
  confirm). Closes the deferred Phase 2 STAC-resolution item.

## [0.35.2] - 2026-05-20

### Changed

- `formspot` datasource entry: FORMSpoT is wired into the
  C1/P1/P2/B2 indicators through the existing `chm` argument (the
  shared CHM interface used by FORMS-T and chm_opencanopy). The
  `consumed_by` block now names the precise indicator functions,
  `products` splits into `height` / `biomass`, and an
  `integration_note` documents the integration path.

## [0.35.1] - 2026-05-20

### Fixed

- `formspot` datasource entry: FORMSpoT is confirmed published as
  the THEIA STAC collection `FORMSpoT`; the entry now carries the
  verified `stac_catalog` / `stac_collection` fields instead of
  the provisional preprint-stage note.

## [0.35.0] - 2026-05-20

### Added

- Theia data sources, phase 3d: `indicateur_w2_zones_humides()`
  gains a `water_occurrence` argument (Theia `theia_water`);
  `indicateur_r3_secheresse()` gains `soil_moisture` /
  `sm_relief_strength` arguments (Theia `theia_soil_moisture`);
  new exported helper `units_add_species_from_raster()` fills a
  species column from the Theia `theia_species` product. Closes
  Phase 3 of the Theia chantier. Backward-compatible.

## [0.34.0] - 2026-05-20

### Added

- Theia data sources, phase 3c: `indicateur_r3_secheresse()`
  gains `snow` and `snow_relief_strength` arguments — a Theia
  `theia_snow` snow-cover-duration raster attenuates the drought
  stress (snowpack as a seasonal water reserve). Backward-compatible.

## [0.33.0] - 2026-05-20

### Added

- Theia data sources, phase 3b: exported helpers
  `texture_to_fertility_score()` and
  `texture_to_erosion_resistance()`; `indicateur_f1_fertilite()`
  gains a `"theia_soil"` source + `texture` argument;
  `indicateur_f2_erosion()` gains a `texture` argument. Wires the
  Theia `theia_soil` product into the F1/F2 indicators.

## [0.32.0] - 2026-05-20

### Added

- Theia data sources, phase 3a: `indicateur_c2_ndvi()` gains a
  `fapar` argument (FAPAR-based vitality) and
  `indicateur_a1_couverture()` gains an `fvc` argument
  (FVC-based tree coverage), wiring the Theia `s2_biophysical`
  product into the C2 and A1 indicators. Both arguments are
  optional and backward-compatible.

### Changed

- `indicateur_a1_couverture()`: `land_cover` now defaults to
  `NULL` (required only in legacy mode, ignored in FVC mode).

## [0.31.0] - 2026-05-20

### Added

- `load_raster_source()` gains a `path` argument so path-less
  `raster_local` datasources (the Theia products) can be loaded
  from a locally downloaded file.
- New exported helper `get_datasource_product()` returning the
  metadata of one sub-product of a multi-product datasource
  (e.g. `forms_t` height/volume/biomass).

## [0.30.0] - 2026-05-20

### Added

- Theia data sources, phase 1b: `theia_water`,
  `theia_soil_moisture`, `s2_l2a_muscate`, `theia_species`,
  `theia_lst` and `formspot` declared in
  `inst/datasources/FR.json`, completing Phase 1 (catalogue) of
  the Theia chantier. Declarative only — no core indicator code
  changed.

## [0.29.0] - 2026-05-20

### Added

- Theia data sources, phase 1a: `s2_biophysical` (LAI/FAPAR/FVC),
  `theia_soil` (texture fractions) and `theia_snow` (Let-it-snow
  collection) declared in `inst/datasources/FR.json`, with
  `consumed_by` wiring to the C2/A1/B2, F1/F2 and R3/W indicators
  respectively. Declarative only — no core indicator code changed.

## [0.28.0] - 2026-05-20

### Added

- `forms_t` dataset declared in `inst/datasources/FR.json`: the
  FORMS-T Theia time-series of canopy height (10 m), growing
  stock volume (30 m) and aboveground biomass (30 m) maps over
  metropolitan France (Schwartz et al. 2023, ESSD). Documents the
  `consumed_by` wiring of the height product into the CHM path of
  the C1, P1, P2 and B2 indicators.

## [0.21.1] - 2026-05-12

### Fixed

- DuckDB migration `0001_init.sql` rejected by the parser on
  `GENERATED ALWAYS AS IDENTITY` and `ON DELETE CASCADE`. Replaced
  with explicit `CREATE SEQUENCE` + `DEFAULT nextval(...)` and
  dropped the cascade actions from FK clauses. Fixes the
  "Base de suivi non configurée" error on first launch of
  `nemetonshiny` with a local DuckDB backend.

## [0.19.11] - 2026-04-24

### Changed

- `create_sampling_plan()` now clamps `n_base + n_over` to the
  candidate-frame capacity upfront, preserving the Base/Over ratio
  and emitting a `cli_warn()`. Prevents the silent LPM2 fallback
  that could drop all Over plots on small AOIs with strict
  forest-cover / slope filters.

### Added

- Two new unit tests covering the clamp logic: ratio preservation,
  minimum-1-Over guarantee, and warning signature.

## [0.19.10] - 2026-04-24

### Changed

- `create_sampling_plan()` now auto-simplifies the stratification
  (drops TPI, then type) when the full 3D combination would contain
  thin strata, instead of skipping GRTS entirely. A `cli_inform()`
  reports which dimensions were dropped. Extends GRTS coverage to
  small AOIs where the 3D stratification produces too many singletons.

### Added

- Internal helper `.fit_stratum()` plus four unit tests covering
  degradation, fully-thin edge cases, and constant-dimension handling.

## [0.19.9] - 2026-04-24

### Changed

- `create_sampling_plan()` now prints an informative `cli::cli_inform()`
  message on the two previously silent GRTS-skip paths (no usable
  stratification, `spsurvey` not installed), listing the concrete
  reasons. Users no longer have to guess why the draw fell back to
  LPM2 or random.

## [0.19.7] - 2026-04-24

### Fixed

- `.compute_forest_cover()` now aligns its vectorised output using
  a carried `.fc_id` column instead of `row.names()`, which some
  sf versions rewrite on intersection. Fixes silent "all-zero"
  forest cover leading to empty candidate sets in
  `create_sampling_plan()`.

## [0.19.6] - 2026-04-24

### Performance

- `.compute_forest_cover()` vectorised: ~40-80× faster on typical
  GRTS loads (3000 candidates × 50 mask polygons now in ~0.7 s
  instead of 30-60 s), removing the UI freeze on create_sampling_plan()
  calls.

## [0.19.5] - 2026-04-24

### Changed

- `detect_ndp()` emits `"height_lidar"` in the augmented vector
  when `chm_source == "lidar_hd"`, distinct from the existing
  `"height_ml"` flag used for Open-Canopy.

## [0.19.4] - 2026-04-24

### Fixed

- `create_sampling_plan()` no longer floods the console with sf's
  "attribute variables are assumed to be spatially constant"
  warning (one per candidate × polygon). `.compute_forest_cover()`
  now sets `sf::st_agr()` to `"constant"` and wraps
  `st_intersection()` in `suppressWarnings()`.

## [0.19.3] - 2026-04-24

### Changed

- Flip every BD Forêt v2 TFV row in `inst/extdata/bdforet_v2_mapping.csv`
  from `confidence = "ambiguous"` to `"clear"` (9 rows touched).
  The secondary candidate stays in `alt_context_key` for reference.

### Fixed

- `cv_from_bdforet()` no longer reports non-forest codes (FF0, FO0,
  LA4, LA6) as `$unmapped` — these are explicitly mapped to `NA`
  and are silently excluded from the CV. Only codes truly absent
  from the mapping are surfaced as unmapped.

## [0.19.2] - 2026-04-24

### Changed

- Tour optimisation now uses `TSP::solve_TSP()` (nearest_insertion +
  2-opt) — same recipe as tutorial 09-sampling. Hand-rolled fallback
  kept when the `TSP` package is not installed. `TSP (>= 1.2.0)`
  added to `Suggests`.

## [0.19.1] - 2026-04-24

### Fixed

- `create_sampling_plan()` now assigns `visit_order` from a real
  nearest-neighbor + 2-opt walking tour (start = south-easternmost
  Base plot) instead of from the draw order. The polyline drawn by
  the Shiny map is no longer a zig-zag across the AOI.

## [0.19.0] - 2026-04-24

### Added

- `compute_sample_size(cv, target_error, alpha, N)` — Cochran formula
  with iterative Student-t refinement and optional finite-population
  correction. (`R/sample_size.R`)
- `cv_typology()` / `cv_lookup(context_key, position)` — lookup over
  the 8 generic forest contexts with low / mid / high CV bounds on
  basal area G/ha. Reference CSV at
  `inst/extdata/cv_typology.csv` (editable by the caller via
  the `file =` argument).
- `bdforet_v2_mapping()` — 32 BD Forêt v2 TFV codes mapped to the
  generic contexts, with a confidence flag (`clear` / `ambiguous`)
  and a secondary candidate for the ambiguous ones. Reference CSV
  at `inst/extdata/bdforet_v2_mapping.csv`.
- `cv_from_bdforet(bdforet_sf, position, aoi, tfv_col)` — area-
  weighted CV for an AOI, plus a diagnostic summary (per-TFV share,
  ambiguous codes, unmapped codes).
- `create_sampling_plan()` now accepts `target_error`, `cv`,
  `alpha` and `over_ratio`: `n_base` is computed via
  `compute_sample_size()` when these are provided, with the result
  attached to the plan as `attr(plan, "sample_size")`.
- Library-level sampling pipeline `create_sampling_plan()` —
  GRTS stratified when CHM/DEM/BD Forêt layers are available,
  with LPM2 (spatially-balanced) and random fallbacks.
- QField re-ingestion layer (`R/qgis_import.R`):
  `import_qfield_gpkg()`, `validate_field_data()`,
  `aggregate_plot_metrics()`, `attach_field_data_to_units()`,
  `tag_field_data_sources()`.
- QField project export `create_qfield_project()` producing a
  ready-to-use `.qgz` (ZIP of `.qgs` XML + GPKG) with zero new
  hard dependency.
- Placette / arbre schema module (`R/field_schema.R`) used on both
  export and re-ingestion sides.
- `detect_ndp()` alternative path: placettes → NDP 2, full tree
  inventory (≥ 10 trees/plot on average) → NDP 3.
- New data source `field_qfield` in `inst/datasources/FR.json`.
- `inst/extdata/cv_typology.csv` and
  `inst/extdata/bdforet_v2_mapping.csv` — editable reference tables.

### Changed

- `bdforet_v2_mapping.csv` now carries a `label_key` column (the
  normalized French libellé per TFV code). `cv_from_bdforet()` does
  a two-pass join — TFV code first, label fallback — so projects
  where the IGN WFS delivers libellés (instead of codes) in the
  `tfv` field no longer return NA / 0 % coverage.
- File renames: `R/qfield_export.R` → `R/qgis_export.R`,
  `R/qfield_import.R` → `R/qgis_import.R`, tests renamed
  accordingly. The exported function names (`create_qfield_project`,
  `import_qfield_gpkg`) are unchanged.

### Fixed

- `cv_from_bdforet()` normalizes incoming TFV values (trim, dashify
  separators, uppercase) before the lookup, so inputs like
  `FF2_64_64` or `" ff2-64-64 "` resolve to `FF2-64-64` as expected.

## Prior versions

See [NEWS.md](NEWS.md) for the complete narrative history
(0.1.0 onwards).

[Unreleased]: https://github.com/pobsteta/nemeton/compare/v0.19.7...HEAD
[0.19.7]: https://github.com/pobsteta/nemeton/compare/v0.19.6...v0.19.7
[0.19.6]: https://github.com/pobsteta/nemeton/compare/v0.19.5...v0.19.6
[0.19.5]: https://github.com/pobsteta/nemeton/compare/v0.19.4...v0.19.5
[0.19.4]: https://github.com/pobsteta/nemeton/compare/v0.19.3...v0.19.4
[0.19.3]: https://github.com/pobsteta/nemeton/compare/v0.19.2...v0.19.3
[0.19.2]: https://github.com/pobsteta/nemeton/compare/v0.19.1...v0.19.2
[0.19.1]: https://github.com/pobsteta/nemeton/compare/v0.19.0...v0.19.1
[0.19.0]: https://github.com/pobsteta/nemeton/compare/v0.18.0...v0.19.0
