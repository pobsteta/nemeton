# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For a narrative, per-feature description of each release, see
[NEWS.md](NEWS.md). This file is the concise, categorised trail.

## [Unreleased]

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
