# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For a narrative, per-feature description of each release, see
[NEWS.md](NEWS.md). This file is the concise, categorised trail.

## [Unreleased]

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
