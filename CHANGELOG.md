# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a
Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For a narrative, per-feature description of each release, see
[NEWS.md](https://pobsteta.github.io/nemeton/NEWS.md). This file is the
concise, categorised trail.

## [Unreleased](https://github.com/pobsteta/nemeton/compare/v0.19.7...HEAD)

## \[0.129.0\] - 2026-07-04

### Added

- [`lai_sentinel2()`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md)
  increment 2 (spec 033): automatic MUSCATE reflectance assembly (D4)
  when `refl` is `NULL` — MUSCATE STAC search + stateless per-scene band
  fetch (`.get_s2_band_raster`), reusing the S2 pipeline; and a shipped
  pre-trained PROSAIL model
  `inst/extdata/prosail_lai_Sentinel_2A_B4-B5-B8.rds` (D3) loaded
  without retraining (serialization verified, prediction CI-tested;
  regenerate via `data-raw/prosail_lai_model.R`).

### Changed

- [`lai_sentinel2()`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md)
  default `selected_bands` is now `c("B4","B5","B8")` (red, red-edge,
  NIR — the S2 pipeline does not expose B03/green).

## \[0.128.0\] - 2026-07-04

### Added

- [`lai_sentinel2()`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md)
  (spec 033, increment 1): NDP-0 canopy fallback retrieving a LAI raster
  from Sentinel-2 L2A via PROSAIL hybrid inversion (`prosail`), for
  `lai_max` (biljouR, direct) and `pai` (microclimf, degraded proxy)
  when LiDAR HD is absent. `precomputed` + temporal reducer (p90
  default) CI-tested; PROSAIL training verified, application validated
  on real data. `prosail` in Suggests + Remotes, guarded.
- `regen_sensibilite(pai = ...)`: inject a canopy raster (S2/PROSAIL LAI
  fallback) to bypass the LiDAR PAI; `las` no longer required in that
  case.
- [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md):
  `augmented = "lai_ml"` when `attr(data, "lai_source") == "prosail_s2"`
  (base NDP unchanged, ADR-011).

## \[0.127.1\] - 2026-07-03

### Fixed

- [`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
  engine path now aggregates rasters per unit via `exactextractr` (the
  `.micro_extract()` helper) instead of
  [`terra::extract`](https://rspatial.github.io/terra/reference/extract.html):
  coverage-weighted means and an exact non-NA `couverture_pct` at parcel
  boundaries, consistent with the A3/A4/W4 microclimate indicators.
  `precomputed` path unchanged.

## \[0.127.0\] - 2026-07-03

### Added

- Multi-epoch consolidation of ancient forest for N2 (spec 031).
  `build_foret_ ancienne_mask()` now accepts a named list of historical
  sources (e.g. Cassini + état-major) and returns a non-overlapping
  tiered layer with an integer `anciennete` column (number of epochs
  covering each polygon) and an `epoques` label, via
  [`sf::st_intersection`](https://r-spatial.github.io/sf/reference/geos_binary_ops.html)
  self-overlay. Single-source forms unchanged.

### Changed

- [`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md)
  gains `weight_anciennete = TRUE`: when the `foret_ancienne` layer
  carries an `anciennete` tier column, the ancient-forest coverage is
  weighted by tier depth (forest present at more epochs counts more).
  Backward compatible — single-epoch layers keep the binary behaviour;
  `weight_anciennete = FALSE` forces it. Ready to fold in a vectorised
  Cassini (~1750) layer once available (Cassini ships raster-only from
  IGN).

## \[0.126.0\] - 2026-07-03

### Added

- Real
  [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
  BILJOU engine (spec 027 L2, increment C/3): the engine path is now
  wired via the `biljouR` API — unit centroids → `biljou_run_grid()`
  (per-point BILJOU forced by `meteo`) → per-unit mean over years,
  mapping `NJstress`/`Istress`/`DEBstress`/`min_rew` to the §7 columns
  `njstress`/`istress`/`deb_stress`/`rew_min`. `forest_type`
  feuillu/resineux mapped to broadleaved/coniferous; phenology forwarded
  via `...`; new `years` arg; failed points degrade to NA. `biljouR` in
  Suggests + Remotes, guarded by `requireNamespace`; `precomputed`
  pass-through preserved. Unlike PAI/microclimf, this engine path is
  CI-tested (biljouR ships the `meteo_hesse` example, so the full
  orchestration runs offline). Completes the reGénération engine
  porting: all three engines (lasR / microclimf / biljouR) are now real.

## \[0.125.0\] - 2026-07-03

### Added

- Real
  [`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
  microclimf engine (spec 027 L1, increment B/3): the engine path is now
  wired — static LiDAR-HD grid (DTM, canopy height, PAI via
  [`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)),
  per-year microclimf runs forced by ERA5-Land (`mcera5`) with disk
  caching (`cache_dir`), average-vs-heatwave summer means (fixed
  canopy), ΔT°max/ΔVPD, signal/noise robustness, and per-unit
  aggregation into the §7 exposure columns (+
  `parcelle_sensible`/`priorite`). Ported faithfully from the
  reGénération prototype `microclimat_parcelles_robuste.R`. New args
  `res`, `tampon`, `reqhgt`, `k`, `cache_dir`; heavy deps (`microclimf`,
  `mcera5`, `lasR`) in Suggests, guarded by `requireNamespace`;
  `precomputed` pass-through preserved. Engine path validated on real
  data (not runnable in CI).

## \[0.124.0\] - 2026-07-03

### Changed

- [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md)
  (spec 027 L2, core item 2) now accepts a per-year summer `SpatRaster`
  E-OBS input (one layer per year, JJA-aggregated) in addition to the
  precomputed named-numeric series: each layer is cropped + masked to
  the AOI (units’ union) and averaged
  ([`terra::global`](https://rspatial.github.io/terra/reference/global.html))
  into the yearly summer-heat index feeding the average/heatwave year
  selection for
  [`indicateur_r6_sensibilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_r6_sensibilite.md).
  Years come from layer names or a new `years` argument. This wires the
  previously deferred E-OBS raster path. Backward compatible; testable
  offline (20 tests, incl. AOI crop/mask).

## \[0.123.0\] - 2026-07-03

### Added

- `load_foret_ancienne_source(aoi, crs = 2154)` (spec 031, core item 1):
  acquires the ~1850 historical forest cover from the IGN *carte de
  l’état-major* WFS layer
  (`BDCARTO_ETAT-MAJOR.NIVEAU3:c_1_1_ocs_ancien`, Etalab 2.0) via
  `happign`, clipped to the AOI, standardised through
  [`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)
  as the `foret_ancienne` layer for
  [`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md)
  (no N2 signature change). The official *BD Forêts anciennes* product
  (Nature classification) is download-only (departmental GeoPackage, no
  WFS) — the état-major ingredient is used instead, and N2’s
  intersection with current units recovers continuity. Degrades to
  `NULL` (no network, `happign` absent, WFS error, outside metropolitan
  France); 0-row `sf` when no ~1850 forest. `happign` in Suggests,
  guarded by `requireNamespace`. Real WFS path validated on real data
  (not runnable in CI).

## \[0.122.0\] - 2026-07-03

### Added

- Real
  [`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)
  engine (spec 027 L1, increment A/3): the LiDAR-HD point-cloud path is
  now wired to the `lasR` pipeline (single read, two class-filtered
  `count` rasterizations → gap fraction → Beer-Lambert PAI, resampled
  onto the working grid, optional parcel mask). Ported faithfully from
  the reGénération prototype `pai_lidarhd_lasR.R`. Heavy dep `lasR` in
  Suggests, guarded by `requireNamespace`; `precomputed` pass-through
  and clean input validation preserved. New args: `parcelle`, `fenetre`,
  `cl_sol`, `cl_veg`, `epsg`, `pai_max`. Engine path is validated on
  real LiDAR data by the user (not runnable in CI).

## \[0.121.1\] - 2026-07-03

### Changed

- Declared `biljouR` in `Suggests` + `Remotes` (`pobsteta/biljouR`): the
  BILJOU water-balance engine used by
  [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
  is now an official optional dependency (still loaded via
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) with clean
  degradation). The engine-path error message points to the repository.

## \[0.121.0\] - 2026-07-03

### Added

- [`map_tfv_to_species_class()`](https://pobsteta.github.io/nemeton/reference/map_tfv_to_species_class.md)
  (spec 027): BD Forêt v2 TFV code -\> NMT species class, via a new
  `species_class` column of
  [`bdforet_v2_mapping()`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md).
  Closes the core PLAN item “TFV -\> regeneration species mapping” (app
  pre-fills the target species from the essences present on the
  coverage).
- [`regen_species_choices()`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md)
  gains a `level` argument: `"species"` (default) now lists the FRM
  European species (`european_species_tolerances(statut="frm")`, Atlas
  foldable via `include_atlas`), `"class"` keeps the 11 broad classes.
  UGF presence flagged from a TFV column (`tfv_col`) or a species-class
  column.
- [`european_species_tolerances()`](https://pobsteta.github.io/nemeton/reference/european_species_tolerances.md)
  gains a `species_class` column (genus-rule link to the 11 classes).

### Changed

- `indice_priorite_regen(species=)` resolves both tolerance tables: a
  class code (`essence_hetraie`) or a European species code
  (`fagus_sylvatica`).

## \[0.120.0\] - 2026-07-03

### Added

- [`european_species_tolerances()`](https://pobsteta.github.io/nemeton/reference/european_species_tolerances.md)
  (spec 027): per-species restocking-tolerance reference table for ~193
  European tree species (file provided by Pascal). Complements the
  11-class
  [`regeneration_tolerances()`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)
  with the same `tmax_tol_c`/`vpd_tol_kpa` axes (now sourced) plus
  Niinemets & Valladares
  2006. drought/shade/waterlogging tolerances, frost, air humidity and
        thermophily. `statut` scopes (frm_1999 / frm_2025 / atlas_jrc),
        `confidence` grading and an `invasif` flag; `statut = "frm"`
        convenience filter. Sources added in `inst/REFERENCES.md`; data
        in `inst/extdata/european_species_tolerances.csv` (built by
        `data-raw/european_species_tolerances.R`). Increment 1/3.

## \[0.119.0\] - 2026-07-03

### Added

- [`regen_species_choices()`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md)
  (spec 027 §10.1): ready-to-use option list for the reGénération
  “target species” dropdown, built core-side. Options are exactly the
  scorable classes (intersection of
  [`regeneration_tolerances()`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)
  and
  [`list_species_classes()`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)),
  so the selector never offers a species the index ignores. Returns
  `code`/`label`/`tmax_tol_c`/`vpd_tol_kpa`/`present`/`groupe`,
  UGF-present classes first (`groupe = "present"`) then adaptation
  alternatives sorted by increasing heat tolerance. Onglet brief §4.1
  updated.

## \[0.118.0\] - 2026-07-03

### Added

- [`tendances_estivales_eobs()`](https://pobsteta.github.io/nemeton/reference/tendances_estivales_eobs.md)
  (spec 027 §6, branch A): summer E-OBS climate trend map (warming ×
  drying) cropped to the union of the units plus a buffer (default 25
  km, decision §10.4; metric buffer via EPSG:3035), not national. Per
  E-OBS cell: least-squares trend of summer tmax and precipitation, plus
  a bivariate classification (`classe_tmax`/`classe_precip` 1-3,
  `classe_bivariee` 1-9). Engine path from per-year `tx`/`rr` rasters
  (testable terra logic), `precomputed` fast-path, clean degradation.
  Returns an sf of cell-centre points for the app to render.

## \[0.117.0\] - 2026-07-02

### Added

- reGénération engine scaffolds L1/L2 (spec 027 v2.1):
  [`regen_bilan_hydrique()`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
  (biljouR — soil water balance),
  [`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
  (microclimf — summer under-canopy exposure) and
  [`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)
  (lasR/lidR — PAI). Heavy GPL deps stay in `Suggests` (guarded via
  `requireNamespace`, clean degradation). Each offers a pure, testable
  `precomputed` fast-path that attaches a pre-computed engine output to
  `units` as the §7 columns without the engine — so the `regen_* -> r3`
  / `indice_priorite_regen` pipeline already runs on pre-computed model
  outputs.
  [`regen_sensibilite()`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
  derives `d_tmax`/`d_vpd` and `rang_sensibilite`. `biljouR` is not yet
  declared in Suggests/Remotes (repo to confirm); guarded via
  `requireNamespace` only.

## \[0.116.0\] - 2026-07-02

### Added

- [`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)
  enriched with the BILJOU soil water-balance metrics (spec 027 §5.1):
  new `biljou` (data.frame/list with `njstress`, `istress`,
  `deb_stress`) and `biljou_weight` arguments. Exposes the raw metrics
  (`r3_njstress`, `r3_istress`, `r3_deb_stress`) alongside the score,
  blends the mechanistic water-balance stress into the SPEI/topographic
  risk, computes R3 from BILJOU alone when no DEM is available, and
  auto-reads the metrics from `units` columns. Strictly backward
  compatible (no `biljou` → v0.115.x behaviour, including NA without a
  DEM).

## \[0.115.0\] - 2026-07-02

### Added

- **[`indice_priorite_regen()`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)** +
  **[`regeneration_tolerances()`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)**
  (spec 027 v2.1 L3): regeneration priority index crossing microclimate
  exposure (`sensibilite` / `d_tmax` / `d_vpd`) and soil water stress
  (`njstress` / `istress` / `rew_min`) into a 0-100 priority. Generic by
  default; optional per-species tuning (off by default, arbitration
  §10.1). Output columns follow the §7 contract
  (`indice_priorite_regen`, `regen_exposition`, `regen_hydrique`,
  `parcelle_sensible`, `priorite`, `regen_essence`). Pure R logic, no
  GPL dependency; consumes the engine output columns. Reworks the parked
  `regeneration_index` into the brief’s exposure × water-stress cross.

## \[0.114.1\] - 2026-07-02

### Fixed

- [`indicateur_l3_het_spectrale()`](https://pobsteta.github.io/nemeton/reference/indicateur_l3_het_spectrale.md)
  crashed (“list cannot be coerced to double”) on the real biodivMapR
  beta-diversity output, a multi-band raster (3 PCoA Bray-Curtis axes):
  `exact_extract(..., "mean")` returns a data.frame that
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html) cannot coerce.
  `.aggregate_diversity()` now collapses a multi-band extraction to one
  scalar per unit (mean across bands), leaving single-band alpha (B4)
  unchanged; off-coverage units yield `NA`. Added a multi-band
  regression test.

## \[0.114.0\] - 2026-07-02

### Added

- Indicator **A5 “Rafraîchissement urbain”**
  ([`indicateur_a5_rafraichissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_a5_rafraichissement.md),
  spec 032 reoriented): relative surface-temperature freshness of a tree
  unit vs its local surroundings, from an LST raster (Theia Thermocity).
  High = cooler than surroundings. Source-conditional (NULL LST -\> NA);
  joins the A family (A1-A5) but not
  [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md).
  `theia_lst` (`thermocity-lst`) wired as `consumed_by: A5`.

### Changed

- Spec 032 reoriented from “A3 régulation thermique (albedo + LST)” to
  “A5 urban cooling (LST only)”. Albedo is dropped — it is not a valid
  cooling proxy for a tree (shade + evapotranspiration dominate; canopy
  albedo is low and radiatively warming). LST covers only metropolises,
  matching the urban-tree scope. `cesbio-s2albedo` is not wired. The A3
  slot is already taken by spec 027’s under-canopy microclimate
  indicator.

## \[0.113.0\] - 2026-07-02

### Added

- [`build_foret_ancienne_mask()`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)
  (spec 031): source-agnostic helper that builds the `foret_ancienne`
  polygon layer consumed by
  [`indicateur_n2_continuite()`](https://pobsteta.github.io/nemeton/reference/indicateur_n2_continuite.md),
  from a user-supplied historical forest source — an sf/sfc of
  ancient-forest polygons, or a terra SpatRaster classified/threshold
  map (polygonised, patch-split, area-filtered).

### Changed

- Spec 031 reoriented: the planned N4 “Forêt ancienne” indicator fed by
  Corona 4B is dropped — the Theia `corona-4b` collection has zero
  France coverage (3 Middle-East items only) and N2 already handles
  ancient-forest continuity via its `foret_ancienne` argument (N4 would
  be redundant). `corona-4b` is not declared as a datasource.

## \[0.112.1\] - 2026-07-02

### Fixed

- [`enrich_parcels_bdforet()`](https://pobsteta.github.io/nemeton/reference/enrich_parcels_bdforet.md):
  recover from invalid BD Forêt V2 geometries (“Edge N is degenerate
  (duplicate vertex)”) that aborted the whole `st_intersection` and
  zeroed species/age enrichment (silently degrading the
  species-dependent P/C/B indicators to their synthetic-inventory
  fallback). Now repairs both layers with
  [`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html)
  and retries once before giving up; the repair cost is paid only on
  failure.

## \[0.112.0\] - 2026-07-02

### Added

- Indicator **T3 “Clear-cuts”**
  ([`indicateur_t3_coupes_rases()`](https://pobsteta.github.io/nemeton/reference/indicateur_t3_coupes_rases.md),
  spec 030): recency-weighted clear-cut pressure per forest unit from
  the SUFOSAT national product (CNES/CESBIO, Sentinel-1 radar change
  detection). `dates` encoded YYDDD, `proba` in percent;
  `window_years`/`min_proba` parameters. Oriented “high = bad” like R5 —
  inverted in
  [`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md).
  Source-conditional (NULL raster -\> NA); joins the T family config and
  normalization but not
  [`list_indicators()`](https://pobsteta.github.io/nemeton/reference/list_indicators.md)
  (the 31 base indicators).
- `inst/datasources/FR.json`: `sufosat` source (collection confirmed on
  the live Theia MTD STAC 2026-07-02, assets `dates`/`proba`).

## \[0.111.0\] - 2026-07-02

### Added

- MUSCATE Sentinel-2 L2A as a third, French-sovereign STAC backend of
  [`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
  (spec 029). New exported
  [`stac_search_s2_theia_muscate()`](https://pobsteta.github.io/nemeton/reference/sentinel2_stac.md)
  queries the Theia MTD STAC collection `sentinel2-l2a-theia`, remaps
  the MUSCATE band dialect to the nemeton `B02/B04/…` keys, reduces S3
  hrefs to `/vsis3/` paths and returns the shared normalised scene
  tibble. Added to the default `source` vector as a last-resort
  fallback: only queried when both `cdse` and `pc` fail — nominal
  behaviour is unchanged.
- `inst/datasources/FR.json`: `s2_l2a_muscate.access` confirmed
  collection id + FRE reflectance product (spec 029 K4 real-data smoke,
  2026-07-02).

## \[0.103.0\] - 2026-06-30

### Added

- `run_reticulate_isolated(fun, args, python|virtualenv|condaenv, show)`
  : exécute une tâche Python/reticulate dans un sous-processus `callr` à
  env épinglé (`RETICULATE_PYTHON` + `R_ENVIRON_USER=""`), pour faire
  cohabiter plusieurs envs reticulate (Open-Canopy, FORDEAD, Theia) dans
  une même session R sans le conflit de binding unique. Repli
  in-process. `callr` en `Suggests`. 8 tests
  (`test-reticulate-isolated.R`).

## \[0.102.0\] - 2026-06-30

### Added

- reGénération L2 (spec 027 / ADR-014) : `indicateur_r6_sensibilite`
  (R6, famille R) — sensibilité du microsite à une année chaude (Δ
  stress canicule − moyenne, ΔT°max + ΔVPD standardisés, décroissant =
  résilient). Sens haut=bon (pas d’inversion).
  [`microclimate_detect_years()`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md) +
  `R/microclimate_years.R` : détection auto des années moyenne/canicule
  depuis E-OBS, override utilisateur (§6bis). Famille R → R1…R6. 33
  tests.

## \[0.101.0\] - 2026-06-30

### Added

- reGénération L1 (spec 027 / ADR-014) : indicateurs microclimatiques
  sous couvert `indicateur_a3_microclimat` (A3),
  `indicateur_a4_tamponnement` (A4), `indicateur_w4_vpd` (W4) — insérés
  dans les familles A/W existantes (radar 12 axes préservé). Flag NDP
  `microclimate_model` (`detect_ndp`, amende ADR-011). Scaffold
  [`microclimate_run()`](https://pobsteta.github.io/nemeton/reference/microclimate_run.md) +
  contrat `micro`. Sources `FR.json` (era5_land, eobs,
  lidarhd_mnt/mnh/nuage). Dépendances lourdes en `Suggests` (microclimf,
  mcera5, ecmwfr, lidR). 16 tests (`test-indicators-microclimate.R`).

## \[0.100.1\] - 2026-06-30

### Fixed

- [`reconfort_cache_manifest()`](https://pobsteta.github.io/nemeton/reference/reconfort_cache_manifest.md)
  découvre désormais les couches d’affichage depuis le dossier IOTA²
  `final/` (`output_zone_<id>/results/.../final/Final_*.tif`), où elles
  persistent — la v0.100.0 ne regardait que les copies run-scopées
  `zone_<id>/` (absentes pour les runs existants → seule la
  classification remontait). Repli `zone_<id>/` conservé. Validé sur le
  cache réel zone 5. 9 tests ajoutés.

## \[0.100.0\] - 2026-06-30

### Added

- `reconfort_cache_manifest(cache_dir, zone_id, run_id = NULL, include_range)`
  : découverte cache des couches d’affichage RECONFORT (parité
  `read_fordead_layer`), pour réafficher les rasters après un
  rechargement de projet sans le `result` en mémoire. Schéma
  byte-identique à
  [`reconfort_layer_manifest()`](https://pobsteta.github.io/nemeton/reference/reconfort_layer_manifest.md).
  18 tests (`test-reconfort-cache-manifest.R`).

### Changed

- [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  (phase `persist`) cache aussi le score continu et la probabilité
  run-scopés (`reconfort_score_<run_id>.tif`,
  `reconfort_proba_<run_id>.tif`) à côté du masque, pour que ces couches
  réapparaissent après rechargement.

## \[0.99.1\] - 2026-06-29

### Fixed

- Sens de **R5 dépérissement** :
  [`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md)
  inverse désormais R5 (`100 - score`, colonnes
  `indicateur_r5_deperissement` / `R5`) pour que sa contribution au
  radar / `famille_risque` reste « haut = bon » comme R1-R4 (R5 brut est
  « haut = mauvais »). Sans ça, une UGF très dépérie remontait le score
  de la famille R.
  [`indicateur_r5_deperissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md)
  inchangé (API brute). Tooltip R5 reformulé (+ mention RECONFORT). Bug
  latent (R5 pas encore agrégé côté app). 3 tests
  (`test-normalization.R`).

## \[0.99.0\] - 2026-06-29

### Added

- `filter_alerts_to_zone(alerts, con, zone_id, apply_zone_mask = TRUE, mask_polygon = NULL)`
  : ne garde que les centroïdes d’alertes dans le polygone UGF, au
  read-time (contrepartie vectorielle de `read_reconfort_layer` / spec
  016). Helper **unique partagé** par les 3 pipelines
  (RECONFORT/FORDEAD/FAST) ; interne `.filter_alerts_to_zone()`.
  Révision de L7 §D3 (les centroïdes RECONFORT débordaient des UGFs car
  extraits du raster masqué OSO-feuillus, pas UGF). 8 tests
  (`test-filter-alerts-to-zone.R`).

## \[0.98.0\] - 2026-06-28

### Added

- `read_reconfort_layer(layer, con, zone_id, apply_zone_mask = TRUE, mask_polygon = NULL)`
  : lit une couche raster RECONFORT et la masque au polygone des UGFs
  par défaut, au read-time (parité `read_fast_alert_raster` /
  `read_fordead_dieback_mask`, spec 016). Accepte un chemin ou une ligne
  raster du manifeste ; rejette la ligne vecteur (alertes). Réutilise
  [`.apply_zone_mask()`](https://pobsteta.github.io/nemeton/reference/dot-apply_zone_mask.md)
  /
  [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md).
  Spec 021 L7, ADR-013 A6. 11 tests (`test-reconfort-reader.R`).

## \[0.97.0\] - 2026-06-28

### Added

- `reconfort_layer_manifest(result, include_range = FALSE)` : décrit les
  couches affichables d’un run RECONFORT (score, classification,
  probabilité, alertes) en un `data.frame` plat avec indications de
  rendu (`palette`, `reverse`, `vmin`/`vmax`, `categorical`,
  `default_visible`, `default_opacity`, `n_features`). Sémantique des
  couches gardée dans le cœur (ADR-009) ; consommé tel quel par
  `nemetonshiny` pour les toggles de calques et le curseur d’opacité. 29
  tests (`test-reconfort-manifest.R`).

## \[0.94.1\] - 2026-06-23

### Fixed

- FORDEAD first-use install now surfaces pip’s real diagnostic instead
  of reticulate’s empty `Error installing package(s):`. New internal
  helper
  [`.fordead_pip_install()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_pip_install.md)
  runs pip in the venv interpreter, captures the combined stdout+stderr,
  and on failure aborts with the tail of pip’s own output plus the
  common offline/Windows causes (missing `git` for the `git+https` pins,
  no network to gitlab.com / forge.inrae.fr, a wheel that fails to
  build, or — observed on Windows — `Filename too long` when git checks
  out the transitive `stac_static` clone, pointing at
  `git config --system core.longpaths true`).
  [`.ensure_fordead_python()`](https://pobsteta.github.io/nemeton/reference/dot-ensure_fordead_python.md)
  calls it in place of
  [`reticulate::virtualenv_install()`](https://rstudio.github.io/reticulate/reference/virtualenv-tools.html).

## \[0.91.2\] - 2026-06-17

### Changed

- [`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
  (FORDEAD ingest) no longer reads the `plot` table at all: it dropped
  the `.fetch_plots_sf()` call and the legacy per-plot bbox fallback (a
  pre-spec-012/017 leftover). FORDEAD is a per-pixel diagnostic whose
  AOI is the zone geometry (`zone_wkt`); a zone without a usable
  `zone_wkt` now warns + returns empty (pointing to
  [`register_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/register_monitoring_zone.md))
  instead of reconstructing an AOI from the placettes. The `s2:search`
  progress payload reports `n_plots = 0`.

## \[0.91.1\] - 2026-06-17

### Fixed

- [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  no longer aborts with
  `Not compatible with requested type: [type=NULL; target=double]` on a
  geometry-only monitoring zone (no placettes, the default since spec
  017).
  [`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
  computed a dead per-plot buffer
  `sf::st_buffer(plots_proj, dist = plots_proj$radius_m)`; on a
  placette-less zone `radius_m` is `NULL`, so the buffer crashed. The
  buffer was never used downstream (the zone AOI is the crop since spec
  012/017) — removed.

## \[0.91.0\] - 2026-06-17

### Added

- `smooth_pixel_series(method = "harmonic")` — a 3rd smoother for the
  per-pixel series: robust harmonic regression (`n_harmonics` annual
  Fourier pairs + linear trend, IRLS / Tukey biweight) that models the
  seasonal cycle and so stays **continuous across the winter/summer data
  gaps** the local `rolling_median` / `loess` cannot bridge. Base R
  only. New `n_harmonics` parameter. The fit is a model (winter
  interpolated from the seasonal shape), not raw data. Since the helper
  predicts at every row, the app gets a fully continuous curve by
  appending a regular `value = NA` date grid. Spec 026.

## \[0.90.0\] - 2026-06-17

### Added

- [`smooth_pixel_series()`](https://pobsteta.github.io/nemeton/reference/smooth_pixel_series.md)
  — robustly denoises the per-pixel spectral series from
  [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md),
  adding a `smoothed` column per index so the app can draw faded raw
  points + a clean line instead of a sawtooth. Default `rolling_median`
  over a temporal window (`window_days = 45`, robust to cloud spikes),
  optional `loess` (`family = "symmetric"`). NA-aware, no new
  dependency. Spec 026.

## \[0.89.0\] - 2026-06-17

### Added

- `min_slope` parameter on the whole `trend` pipeline
  (`read_fast_alert_raster`, `read_fast_alert_rasters`,
  `extract_pixel_trend`, `extract_trend_series`,
  `create_trend_sanitary_plan`): minimum decline magnitude (index
  units/yr) for a pixel to be flagged, on top of the negative-slope +
  Mann-Kendall test. Fixes the over-sensitivity where a
  tiny-but-monotonic drift (e.g. 0.0001 NDRE/yr) was “significant” yet
  ecologically negligible. Default `0.005` (provisional, to be
  calibrated against ONF/DSF ground truth); `0` restores the pure
  significance test. Folded into the D6 cache hash. Count/rolling
  unaffected.

## \[0.88.1\] - 2026-06-16

### Fixed

- [`create_trend_sanitary_plan()`](https://pobsteta.github.io/nemeton/reference/create_trend_sanitary_plan.md)
  no longer scatters plots across the whole S2 tile when the UGF mask
  can’t be resolved.
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  returns an unmasked full-tile raster on a NULL zone polygon (a no-op
  mask), so the GRTS draw ran tile-wide instead of inside the zone. The
  function now resolves the polygon up front (from `mask_polygon`, else
  `con`/`zone_id`) and aborts with a typed
  `nemeton_zone_mask_unresolved` error if it cannot — never a silent
  tile-wide draw. Pass `mask_polygon` explicitly to skip the DB lookup
  and guarantee containment.

## \[0.88.0\] - 2026-06-16

### Added

- [`create_trend_sanitary_plan()`](https://pobsteta.github.io/nemeton/reference/create_trend_sanitary_plan.md)
  — a standalone **sanitary** plot plan drawn on the FAST `trend` raster
  (default NDRE) with a continuous-probability GRTS weighted by the
  decline magnitude (`|slope|`, via `spsurvey aux_var`). Optional
  control plots on stable cells. Distinct from the terrain/inventory
  plots: it never reads the `plot` table and computes **no TSP tour** —
  plots are ordered by descending severity (`S01` = steepest). Returns
  an `sf` POINT (`plot_id`, `type` Sanitaire/Temoin, `alert_value`,
  `index`, `source = "FAST_TREND"`, `seed`; no `visit_order`). Typed
  `nemeton_empty_alert_mask` error when no significant decline. New
  internal `.draw_grts_continuous()`. Spec 025.

## \[0.87.0\] - 2026-06-16

### Added

- [`extract_pixel_trend()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_trend.md)
  — the per-pixel counterpart of the FAST trend raster. For a point `xy`
  it returns the yearly seasonal composite series plus the Theil-Sen /
  Mann-Kendall result, strictly consistent with
  `read_fast_alert_raster(mode = "trend")` at the same pixel
  (cross-checked in tests). Reads the raw per-scene series via
  [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
  (scene-by-scene, no zone-wide mosaic — immune to the multi-tile
  resolution bug). Returns `composites`, `n_years`,
  `theil_sen_slope/intercept`, `mann_kendall_p/tau`,
  `significant_decline`, `alert_value` (`abs(slope)` if significant, `0`
  if not, `NA` below `min_years`) and `enough_years`. Drives the “why
  this pixel has this colour” graph in `nemetonshiny`.

### Changed

- Factored the scalar Theil-Sen / Mann-Kendall fit into the shared
  internal `.trend_fit_one()`, now used by
  [`extract_pixel_trend()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_trend.md)
  and
  [`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md)
  (consistent with the vectorised `.trend_fit_cells()` the raster uses)
  so pixel, zone and raster never diverge.

## \[0.86.0\] - 2026-06-16

### Added

- [`extract_trend_series()`](https://pobsteta.github.io/nemeton/reference/extract_trend_series.md)
  — zone-level yearly seasonal composite series plus the Theil-Sen /
  Mann-Kendall fit for an index in `trend` mode (default NDRE). The
  trend map reduces each pixel to a single slope and carries no onset
  information; this returns the intermediate `(year, value)` trajectory
  (with `n_scenes`, the Theil-Sen `fitted` line and a `fit` summary:
  `slope`, `intercept`, `p_value`, `tau`, `significant`, `alert`) so
  callers can plot *when* a decline sets in. Reuses the same per-year
  composite as the map via the new internal `.trend_yearly_composite()`;
  multi-tile AOIs are combined as a valid-pixel-count-weighted mean per
  year.

## \[0.85.1\] - 2026-06-16

### Fixed

- [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  /
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  no longer abort with `[mosaic] resolution does not match` for 20 m
  indices (NDRE) when the zone straddles several MGRS tiles (T31TFM +
  T31TGM). Per-tile alert rasters were projected to EPSG:2154
  independently, so terra picked a per-tile output resolution and two 20
  m tiles drifted apart; the new internal helper `.mosaic_per_tile()`
  resamples every tile onto one common EPSG:2154 grid (first tile’s
  resolution, snapped union extent) before mosaicking. Single- tile
  zones and 10 m indices are unaffected.
- Hardened the opportunistic villards smoke test in
  `test-fast-alert-raster.R` to skip (instead of error) when a reachable
  DB lacks the nemeton schema.

## \[0.85.0\] - 2026-06-15

### Added

- [`read_fast_alert_rasters()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_rasters.md)
  now covers the `trend` mode (spec 023). The wrapper’s defaults become
  `c("NDVI","NBR","NDMI","NDRE")` × `c("count","rolling","trend")` and
  it builds only the meaningful combinations (8 by default): `trend` on
  `NDMI`/`NDRE`, `count`/`rolling` on `NDVI`/`NBR`/`NDMI` — a
  nonsensical pair such as `NDVI_trend` or `NDRE_count` is silently
  skipped. Trend parameters (`months`, `min_years`, `min_obs_per_year`,
  `alpha`) are exposed and forwarded. (The end-of-ingest pre-warm gained
  the same trend combos in 0.84.0.)
- [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  now caches the red-edge bands B05 + B8A best-effort on every ingest
  (like B11 for NDMI), even with the default `bands = c("NDVI", "NBR")`,
  so all four FAST indices — NDVI/NBR/NDMI/NDRE, including the trend
  maps — are always renderable without re-ingesting or passing
  `bands = "NDRE"`. This removes the `NDRE_trend` pre-warm soft-skip on
  fresh ingests at the source.

### Changed

- New shared internal predicate `.fast_alert_combo_ok()` /
  `.fast_alert_combos()` enumerates the valid `(index, mode)` pairs once
  for the wrapper. Count / rolling cache hashes are byte-identical (no
  recompute of existing COGs).

## \[0.84.0\] - 2026-06-15

### Added

- `ingest_sentinel2_timeseries(prewarm_alerts = TRUE)` now pre-warms
  **8** FAST alert maps instead of 6: the historical
  `{NDVI, NBR, NDMI} × {count, rolling}` (spec 019) plus two **trend**
  combos `{NDMI, NDRE} × {trend}` (spec 023). Trend targets chronic
  broadleaf decline, whose relevant signals are moisture (NDMI, B11) and
  red-edge (NDRE, B05/B8A); NDVI/NBR stay count/rolling only. The trend
  warm uses the core defaults `months = 6:9`, `min_obs_per_year = 2`,
  `min_years = 4`, `alpha = 0.05` (`threshold`/`window_days` unused in
  trend). It is best-effort: a zone whose cache lacks the red-edge
  (B05/B8A) or B11 bands is skipped without failing the ingestion. New
  progress events `fast_prewarm:{NDMI,NDRE}_trend{,_done,_failed}`
  mirror the existing format; `fast_prewarm:complete` / `:cancelled`
  unchanged. Unblocks the 3-mode selector wiring in `nemetonshiny`.

## \[0.83.3\] - 2026-06-14

### Fixed

- [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  and
  [`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md)
  no longer require registered plots (spec 017). The S2 ingest is a
  placette-independent cache-priming step driven by the zone’s
  `zone_wkt` AOI, yet both paths still aborted with “No plots
  registered” — which broke cache priming for every zone created by
  [`create_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/create_monitoring_zone.md)
  /
  [`build_project_monitoring_zones()`](https://pobsteta.github.io/nemeton/reference/build_project_monitoring_zones.md)
  (geometry-only, no placettes, the app’s default since spec 017). They
  now resolve the zone AOI first and only fall back to the per-plot bbox
  when `zone_wkt` is absent; a zone with neither is still rejected.
  Regression covered by `test-aoi-alignment.R`.

## \[0.83.2\] - 2026-06-14

### Fixed

- `.assert_cache_has_bands()` (NDRE guard, spec 022): pinned the cli
  pluralisation quantity with `{cli::qty(missing)}` so the abort no
  longer fails with “Multiple quantities for pluralization” when both
  red-edge bands (B05 + B8A) are missing. Covered by `test-ndre.R`.

### Documentation

- FAST `trend` (spec 023): documented the `mosaic(fun = "max")`
  tile-overlap behaviour — per-tile slopes combined by max keep the
  larger decline magnitude on MGRS seams (a bounded, conservative high
  bias; single-tile AOIs unaffected).

## \[0.83.1\] - 2026-06-14

### Changed

- FAST `trend` mode (spec 023): `.fast_raster_trend()` now fits
  Theil-Sen / Mann-Kendall with a vectorised pre-filter + matrix-wide
  computation instead of a per-pixel
  [`terra::app`](https://rspatial.github.io/terra/reference/app.html)
  callback (~9× faster, byte-identical output). Rare tied-value pixels
  fall back to the exact tie-corrected `.mann_kendall()`.
  `terra::app(cores=)` and a furrr/PSOCK split were both measured slower
  than serial here, so the lever is vectorisation, not parallelism. A
  [`cli::cli_alert_info`](https://cli.r-lib.org/reference/cli_alert.html)
  reports the candidate-pixel count.

### Documentation

- Clarified the `alpha` parameter for trend mode: the Mann-Kendall
  p-value is two-sided, but the negative-slope gate makes the effective
  false-positive rate for a declared decline `alpha / 2` (default `0.05`
  = 2.5% one-sided).

## \[0.83.0\] - 2026-06-14

### Added

- `read_reconfort_alert_mask(con, zone_id, run_id, cache_dir, ...)`: the
  RECONFORT mirror of
  [`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md),
  returning the categorical class raster (1 sain / 2 dépérissant / 3
  très-dépérissant) of the latest run.
  [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)’s
  `persist` phase now writes that flat mask
  (`<cache_dir>/zone_<id>/reconfort_mask_<run_id>.tif`, best-effort).
  Lets nemetonshiny reuse its raster validation-sampling module 1:1 with
  `create_validation_sampling_plan(source = "RECONFORT")` (full FORDEAD
  parity, control plots included). Closes the core side of G4 (Option
  A).

## \[0.82.0\] - 2026-06-14

### Changed

- Broadleaf terrain-validation vocabulary
  `HEALTH_VALIDATION_STADES_FEUILLUS` finalised against the real DSF
  DEPERIS protocol (MB + MR criteria, A–F notation, \> 50 % crown-damage
  threshold): sain / deperissement_faible / deperissement_marque /
  deperissement_grave / mort / coupe_rase. “PROVISIONAL” note removed.

### Added

- `create_validation_sampling_plan(source = ...)` accepts `"RECONFORT"`
  (the function samples any single-layer categorical raster; the caller
  passes the RECONFORT class raster with `classes = c(2, 3)`,
  `control_classes = c(1)`). Unblocks the nemetonshiny “RECONFORT
  validation plan” sub-tab (L6 / G4).

## \[0.81.0\] - 2026-06-13

### Added

- Broadleaf QField terrain-validation schema (spec 021 G4, support for
  L6):
  `get_health_validation_schema(method = c("fordead", "reconfort"))`
  serves a broadleaf dieback vocabulary in `reconfort` mode
  (`HEALTH_VALIDATION_STADES_FEUILLUS` /
  `HEALTH_VALIDATION_CAUSES_FEUILLUS`). The stage→status mapping routes
  by method (a clearcut on a `reconfort_dieback` alert is a
  `false_positive`);
  [`ingest_health_validation()`](https://pobsteta.github.io/nemeton/reference/ingest_health_validation.md)
  detects the method from `alert.alert_type`. `fordead` mode unchanged.
  DEPERIS stage vocabulary provisional.

## \[0.80.0\] - 2026-06-13

### Added

- RECONFORT pixel diagnostic (spec 021, lot L5): `R/reconfort_outputs.R`
  recomputes CRswir/CRre per date from the ingested S2 (option B) and
  persists dated stacks;
  [`read_reconfort_pixel_series()`](https://pobsteta.github.io/nemeton/reference/read_reconfort_pixel_series.md)
  returns the observed CRswir/CRre series at a clicked pixel (no
  reticulate — no harmonic model). A best-effort `persist` phase + a
  `run_id` are wired into
  [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md).
  The S2 scene enumeration (THEIA/MUSCATE naming) is best-effort,
  pending validation against a real IOTA² run.

## \[0.79.0\] - 2026-06-13

### Added

- `reset_knowledge_manifest(confirm = TRUE)`: overwrites the writable
  project manifest copy with the packaged seed. The writable copy is
  created once and never auto-refreshed, so a stale copy kept listing
  documents the package no longer ships (e.g. the tutorials removed in
  0.75.0). Meant to back a “reset to packaged corpus” action in the
  nemetonshiny RAG admin tab.

## \[0.78.0\] - 2026-06-13

### Added

- Unified R5 dieback indicator with per-species routing (spec 021, lot
  L4):
  [`indicateur_r5_deperissement()`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md)
  gains `reconfort_results` (+ `weights_reconfort`, `min_feuillus`,
  `feuillus_col`) and routes each unit to the method calibrated for its
  dominant species — RECONFORT (oak/chestnut/Scots pine) vs FORDEAD
  (spruce/fir), else `skipped_no_method`. New statuses
  `calculated_reconfort`, `skipped_no_reconfort`, `skipped_no_method`
  (replacing `skipped_no_resineux`). R5 stays a 0-100 column. Default
  RECONFORT weights are provisional.

## \[0.77.0\] - 2026-06-13

### Added

- RECONFORT post-process (spec 021, lot L3): `R/reconfort_postprocess.R`
  turns
  [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md)
  rasters into `reconfort_dieback` alerts (reclassify → 8-connectivity
  patches → centroids, continuous score as `stress_index`).
  [`classify_disturbance()`](https://pobsteta.github.io/nemeton/reference/classify_disturbance.md)
  extended to 3 methods (FAST + FORDEAD + RECONFORT) with a
  `method_overlap` flag. Migration `0006` (index on `alert(alert_type)`,
  PG + SQLite). A best-effort `postprocess` phase is wired into
  [`run_reconfort_dieback()`](https://pobsteta.github.io/nemeton/reference/run_reconfort_dieback.md).
  New exports `RECONFORT_CLASSES`, `RECONFORT_CONFIDENCE_WEIGHTS`,
  `RECONFORT_ALERT_CLASSES` (confidence weights are provisional, pending
  the upstream confusion matrix).

## \[0.76.2\] - 2026-06-13

### Changed

- RAG corpus: the 4 scanned BILJOU papers (Bréda 1993/2002/2008, Granier
  1996), demoted to `link_only` in 0.76.1, are now OCR’d (`tesseract`
  fra+eng, 300 dpi) and re-ingested as full-text. Prod corpus: 60
  full-text / 81 (6120 chunks). OCR text
  (`data-raw/references/biljou/ocr/*.md`) is gitignored (copyright).

### Added

- `data-raw/ocr_biljou_scans.sh`: reproduces the OCR of the scanned
  PDFs.

## \[0.76.1\] - 2026-06-13

### Fixed

- RAG corpus: 4 BILJOU PDFs are scanned images with no text layer
  (`pdf_text` → 0 chars) and failed full-text ingestion. Set to
  `link_only` (citable references) → prod corpus 81/81, 0 errors (56
  full-text + 25 references, 6033 chunks). OCR would be required for
  full-text.

### Added

- `data-raw/fill_corpus_prod.sh`: incremental (non-FRESH) prod corpus
  build to complete a partial run without re-ingesting everything.

## \[0.76.0\] - 2026-06-13

### Added

- `db_connect(url, read_only, connect_timeout = 10L)`: bounds the
  connection attempt. Passed to libpq (`connect_timeout`, seconds) on
  the PostgreSQL backend to cap the hang on an unreachable host; ignored
  for SQLite.

### Internal

- Tooling parity with `nemetonshiny`: dynamic version badge
  (`github/v/release`), `version-consistency` CI guard (DESCRIPTION =
  NEWS = CITATION), and a `release.yml` workflow (auto tag + GitHub
  release from `DESCRIPTION` on push to `main`).

## \[0.75.4\] - 2026-06-13

### Changed

- RAG corpus: 44 BILJOU reference papers (+ user-deposited Monnet &
  Peiffer) wired to full-text from the PDFs hosted by INRAE on the
  BILJOU portal (`appgeodb.nancy.inrae.fr/biljou/pdf/`). Ex-`copyright`
  rows retagged `license=HAL` (open archive, non-commercial), consistent
  with Bontemps/Charru. Also fills 2 institutional gaps (Bréthes 1997
  soils, Badeau RENECOFOR feasibility “Livre Jaune”). Manifest: 60
  full-text + 21 references (81/81, 0 skipped). Remaining references: 4
  non-BILJOU copyright papers, unhosted books (Quae/Biotope/AFORCE), EFI
  (dead links), portal-only docs.

### Added

- `data-raw/wire_biljou_pdfs.R` (filename → doc_id mapping).
  `.gitignore` extended to `data-raw/references/**/*.pdf` for the
  `biljou/` subfolder.

## \[0.75.3\] - 2026-06-13

### Changed

- RAG corpus: retrieved open-access PDFs (non-Cloudflare hosts) for 3
  docs, flipped from `link_only` to full-text `full`: Duplat & Tran-Ha
  1997 (EDP afs-journal), Larrieu IBP guide (CNPF v3.2), EU Forest
  Strategy COM(2021) 572 (EUR-Lex). Manifest: 14 full-text + 67
  references (81/81). Non-retrievable PDFs (Monnet via MDPI/HAL
  Cloudflare, OFB/ONF/CNPF portals, paywalls) stay `link_only`; direct
  links recorded in the references README.

## \[0.75.2\] - 2026-06-13

### Changed

- RAG corpus: the 21 `cleared`/`full` rows without an attached PDF
  (previously skipped at build) now all ingest. IPCC 2019 (Vol.4 Ch.4
  Forest Land) PDF retrieved → `full`; the other 20 → `link_only`
  citable references. Manifest: 81/81 ingestible, 0 skipped (11
  full-text + 70 references).
- Fixed `monnet_mermin_2014` metadata (it is *Forests* 5(9):2307-2326,
  DOI 10.3390/f5092307, open on HAL — was wrongly *Remote Sensing
  6(8)*); added open HAL `source_url` for `duplat_tranha_1997` and
  `larrieu_2018_ibp`.

### Added

- `data-raw/link_only_skipped.R` (reproducible) and a manual-download
  section in `data-raw/references/README.md` for the OA PDFs behind
  anti-bot walls.

## \[0.75.1\] - 2026-06-13

### Changed

- RAG corpus: lifted the D5 license gate across the whole manifest — the
  50 `to_confirm` rows (BILJOU + 4 copyright papers) are now `cleared`
  (explicit override). All being `abstract_only`, they ingest as citable
  references (`link_only`), not full text. Manifest: 81 cleared / 0
  to_confirm. Prod pgvector re-synced (FRESH): 60 docs (10 full-text +
  50 references), 2354 chunks, 0 missing embeddings; 21 skipped (cleared
  `full` without an attached PDF — kept `full` for later full-text
  ingestion).

### Added

- `data-raw/clear_all_to_confirm.R` (reproducible status flip) and
  `data-raw/build_corpus_prod.sh` (FRESH prod-corpus rebuild wrapper).

## \[0.75.0\] - 2026-06-13

### Changed

- RAG knowledge corpus (E7) curation of
  `inst/extdata/knowledge_corpus_v1.csv` (spec 009/009.1): removed the
  12 internal MIT seed docs (tutorials + specs 005/008); added 54
  references cited by the BILJOU tool (INRAE Nancy, forest water-balance
  model) under the conservative D5 license gate (`to_confirm` /
  `abstract_only` / `copyright`); promoted 8 institutional reports to
  `cleared` (ONF/RENECOFOR `LO-Etalab`, FAO paper 56 `CC-BY-NC`, EFI
  WSCTU n°1 `CC-BY`) with public source URLs. Manifest 39 → 81 docs (31
  cleared / 50 to_confirm); full-text build plan 7 → 10 PDFs.

### Added

- `data-raw/{add_biljou_refs,clear_biljou_institutional,url_biljou_institutional}.R`
  — reproducible provenance scripts for the corpus curation above.

## \[0.74.1\] - 2026-06-12

### Fixed

- `build_project_monitoring_zones(..., replace = TRUE)` no longer fails
  with `FOREIGN KEY constraint failed` when re-building a project whose
  zones already own child rows (validation plots, FORDEAD alerts) on the
  **SQLite** backend. Root cause: the SQLite schema (`0001_init.sql`)
  had dropped the `ON DELETE CASCADE` clauses that the PostgreSQL schema
  carries on `plot.zone_id → monitoring_zone(id)` and
  `alert.plot_id → plot(id)`, so the upsert’s
  `DELETE FROM monitoring_zone` was blocked under
  `PRAGMA foreign_keys = ON`. `.delete_project_zones()` now deletes the
  chain explicitly, child-first (`alert` → `plot` → `monitoring_zone`),
  in a single transaction — portable across both backends. No schema
  migration: adding the cascade on SQLite would require a table rebuild,
  incompatible with
  [`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)’s
  single wrapping transaction (`PRAGMA foreign_keys` is a no-op inside a
  transaction, and `defer_foreign_keys` does not clear the deferred
  violation left by the parent `DROP TABLE`).

## \[0.74.0\] - 2026-06-12

### Added

- RECONFORT end-to-end orchestration (spec 021, lot L2b.3):
  `run_reconfort_dieback(con, zone_id, cache_dir, …)` chains env → model
  → mask → tile → S2 ingest → vendored IOTA² map-production (sampling +
  classification ×2 + OSO masking + continuous score), producing the
  classification / probability / continuous-score rasters (EPSG:2154)
  and a `run_meta.json`. Each run stages a writable copy of the vendored
  glue (scripts + `iota2/` subtree + model + mask + year-partitioned S2
  symlinks) under `cache_dir`, keeping the installed package read-only.
  8 phases with a `progress_callback`. A post-condition guard aborts
  when the IOTA² subprocess (whose return code the upstream driver
  ignores) produces no continuous-score raster.
- [`ensure_reconfort_oso_mask()`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_oso_mask.md) +
  `RECONFORT_OSO_MASK`: the OSO 2021 deciduous mask (~54 MB) is fetched
  on demand, MD5-verified and cached, with a `local_path` fallback
  (custom mask) — mirroring the RF model fetch (L2a). `binary_mask`
  control: `NULL` → OSO, a path → custom, `FALSE` → unmasked.
- Vendored map-production glue (Apache-2.0):
  `run_map_production_reconfort.py`, `mask_and_compress_rasters.py`, the
  two IOTA² cfg generators, and the static `iota2/` inputs (config,
  nomenclature, `external_features/custom_index.py` moved to its
  canonical path, `vector_db/random_points.*`).

### Notes

- A real run needs the `nemeton-reconfort` conda env + a GEODES
  account + tens of GB of S2 + OTB/Shark batch execution — opt-in, never
  in CI; unit tests mock every external step. The post-process → `alert`
  table stays in lot L3.

## \[0.73.0\] - 2026-06-11

### Added

- RECONFORT IOTA²-native S2 ingestion (spec 021, lot L2b.2):
  [`reconfort_aoi_tiles()`](https://pobsteta.github.io/nemeton/reference/reconfort_aoi_tiles.md)
  resolves the Sentinel-2 MGRS tile(s) covering an AOI from a bundled
  France grid (`inst/extdata/s2_mgrs_tiles_fr.geojson`, 188 tiles, no
  network);
  [`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
  downloads MUSCATE L2A from GEODES (`pygeodes`) and unzips into the
  IOTA² layout, driving the vendored upstream scripts via a conda
  subprocess. GEODES config via `options(nemeton.geodes_config)`.
  Default collection `THEIA_REFLECTANCE_SENTINEL2_L2A` (the upstream
  `MUSCATE_*` example id 400s on GEODES; confirmed by a real smoke).
  [`reconfort_ingest_s2()`](https://pobsteta.github.io/nemeton/reference/reconfort_ingest_s2.md)
  writes a per-run pygeodes config whose `download_dir` matches the
  per-tile `zip_path` (in the caller-supplied project cache, like
  FORDEAD’s `cache_dir`), so download and unzip agree on the path; that
  copy carries the api_key so it lives in a private mode-600 tempfile,
  never in the cache, wiped after each tile. Post-condition guards abort
  when the (error-swallowing, exit-0) upstream downloader leaves
  `zip_path` empty or the unzip produces no scene folder. Heavy/opt-in,
  never in CI; end-to-end plumbing validated by a real smoke
  (`data-raw/smoke_reconfort_ingest.R`).

## \[0.72.0\] - 2026-06-11

### Added

- RECONFORT Python/IOTA² foundations (spec 021, lot L2b.1):
  `.ensure_reconfort_python()` locates and validates the conda IOTA²
  environment (`nemeton-reconfort`, never bootstrapped — cadrage D2);
  `RECONFORT_BANDS` (B04/B05/B06/B8A/B11/B12); vendored
  `inst/python/reconfort/custom_index.py` (CRswir/CRre indices,
  Apache-2.0, attributed in `inst/NOTICE`). No real run yet (pipeline in
  L2b.2/L2b.3).

## \[0.71.0\] - 2026-06-11

### Added

- RECONFORT model fetch (spec 021, lot L2a):
  [`ensure_reconfort_model()`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_model.md)
  downloads the calibrated Random-Forest model on demand (5.7–197 MB,
  Apache-2.0), verifies size + MD5, and caches it; `local_path`
  short-circuits to a copy already on disk. `RECONFORT_MODELS` registry
  (4 versions) +
  [`reconfort_model_info()`](https://pobsteta.github.io/nemeton/reference/reconfort_model_info.md).
  No IOTA²/Python in this lot; upstream training code is out of scope.
  Base URL overridable via `options(nemeton.reconfort_model_base_url)`.

## \[0.70.0\] - 2026-06-11

### Added

- RECONFORT validity domain (spec 021, lot L1):
  [`check_reconfort_validity()`](https://pobsteta.github.io/nemeton/reference/check_reconfort_validity.md),
  [`load_reconfort_validity_zones()`](https://pobsteta.github.io/nemeton/reference/load_reconfort_validity_zones.md),
  `RECONFORT_VALIDITY_DEPARTMENTS` (6 Centre-Val de Loire departments)
  and `RECONFORT_VALIDITY_SPECIES` (oak CHE / chestnut CHT / Scots pine
  PS). Ships `inst/extdata/reconfort_validity_zones.geojson` + the
  `data-raw/` build script. G3 guard-rail is **advisory, not blocking**
  (`advisory = TRUE`): RECONFORT has no upstream geographic lock. No
  Python in this lot.

### Deferred

- The `health_reconfort` NDP flag and `reconfort_anomalies` datasource
  (spec 021 §5) are postponed: they assumed a FORDEAD parity
  (`health_fordead` / `fordead_anomalies`) that never existed and does
  not fit the current `augmented` semantics of
  [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md).

## \[0.69.2\] - 2026-06-11

### Fixed

- `.fast_raster_trend()` (FAST `mode = "trend"`, spec 023): a year with
  a single in-season scene yields a one-layer SpatRaster, on which
  `terra::app(sub, fun)` errors (“number of values returned by ‘fun’ is
  not appropriate”). Replaced by layer-count-robust cell-wise primitives
  (`nlyr - countNA`,
  [`terra::median`](https://rspatial.github.io/terra/reference/summarize-generics.html)).
  Covered by `test-fast-trend.R`.

### Added

- spec 021 (RECONFORT, 3rd health-monitoring method for broadleaves):
  design docs only — `plan.md` (6 open questions resolved against the
  verified upstream repo) + `spec.md`. ADR-013 amendment A4
  (multi-method health monitoring) lives in `nemetonplateform`.

### Changed

- CI back to green (R-CMD-check, tests, coverage, pkgdown). The `tests`
  job now runs the real suite via
  [`devtools::test()`](https://devtools.r-lib.org/reference/test.html);
  `R-CMD-check` uses `--no-tests`/`--no-build-vignettes`; `pkgdown`
  gains `rsconnect` and a complete reference index (111 missing topics
  added). A capability guard (`skip_if_terra_write_broken()`) skips
  raster tests on a GitHub runner exhibiting a terra “no valid
  constructor” anomaly (not reproducible locally; the whole suite passes
  locally), running them fully everywhere else.

## \[0.67.0\] - 2026-06-04

### Added

- [`prune_orphan_zone_caches()`](https://pobsteta.github.io/nemeton/reference/prune_orphan_zone_caches.md):
  removes `zone_<id>/` cache directories whose zone no longer exists in
  `monitoring_zone` (orphaned by the spec-020 zone upsert, which assigns
  new ids). Covers the FAST / FORDEAD / sampling per-zone caches;
  `dry_run = TRUE` previews; shared caches (`sentinel2/`, `lidar_*`) are
  never touched.

## \[0.66.0\] - 2026-06-04

### Added

- Monitoring zones from UGF × BD Forêt v2 strata (spec 020): a project
  can own up to 4 zones `<project>_tot/_feu/_res/_mix` (UGF union, and
  its intersection with broadleaf / conifer / mixed strata classified
  via `tfv_g11`). New exports
  [`build_project_monitoring_zones()`](https://pobsteta.github.io/nemeton/reference/build_project_monitoring_zones.md),
  [`create_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/create_monitoring_zone.md)
  (zone-only, no placettes — spec 017),
  [`find_zones_by_project()`](https://pobsteta.github.io/nemeton/reference/find_zones_by_project.md).
  Empty strata are skipped with a warning; `replace = TRUE` performs an
  idempotent upsert.
- Migration 0005 (pg + sqlite): `monitoring_zone` uniqueness relaxed
  from `project_uuid` to `(project_uuid, name)` — N zones per project.

### Fixed

- `register_monitoring_zone(project_uuid = …)` fetched the inserted zone
  id by `project_uuid` alone, which could return the wrong id under the
  spec-020 multi-zone model. Now keyed by `(project_uuid, name)`.

## \[0.65.3\] - 2026-06-03

### Added

- LRU GC for the FAST 0-4 mask cache:
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  writes a timestamped `fast_alert_<ts>.tif` per call, so the mask
  directory grew unbounded. `.fast_alert_mask_gc()` now keeps at most
  `getOption("nemeton.fast_mask_keep", 20)` masks per zone (LRU by
  mtime), mirroring `.fast_raster_gc()` for the continuous COGs.

### Fixed

- The continuous-cache GC no longer deletes 0-4 masks.
  `.fast_raster_gc()` matched `^fast_.*\.tif$`, which caught
  `fast_alert_*` masks when `result_cache_dir == mask_cache_dir`
  (validation sampling on `fast_sampling/`). Tightened to
  `^fast_[A-Z].*\.tif$` (continuous
  `fast_NDVI_`/`fast_NBR_`/`fast_NDMI_` only), so the two caches are
  GC’d independently.

## \[0.65.2\] - 2026-06-03

### Changed

- FAST D6 cache COGs now use a verbose, deterministic filename
  `fast_<INDEX>_<MODE>_thr<threshold>_<from>_<to>_w<window>_<hash8>.tif`
  (was `fast_<index>_<mode>_<hash>.tif`). Key parameters are legible
  straight from the name; an 8-char slice of the unchanged D6 hash still
  discriminates the scene-id list and mask polygon. Same parameters
  yield the same name, so cache idempotence is preserved. Pre-0.65.2
  files are no longer matched as hits — they recompute on first demand
  and are reclaimed by the LRU GC; remove them manually to free disk at
  once (see NEWS).

## \[0.65.1\] - 2026-06-03

### Fixed

- `.prewarm_fast_alerts()` now pre-warms the 6 FAST combinations
  (NDVI/NBR/NDMI × count/rolling) instead of 4, matching the public
  [`read_fast_alert_rasters()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_rasters.md)
  orchestrator. NDMI was added in 0.65.0 but the prewarm loop still
  skipped it, so the first NDMI selection in the app paid a cold compute
  instead of a D6 cache hit. A scene without B11 (NDMI) takes the
  existing best-effort skip path (warn + `_failed` event), like NBR
  without B12. No API change.

## \[0.65.0\] - 2026-06-03

### Added

- [`read_fast_alert_rasters()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_rasters.md):
  convenience orchestrator that builds the full FAST diagnostic in one
  call — the three indices (NDVI, NBR, NDMI) in both modes (count,
  rolling), i.e. up to six rasters. Returns a named list keyed
  `"<index>_<mode>"`; each map shares the COG cache, the
  content-addressed result cache (spec 017 D6) and the zone mask.
  Missing index → `NULL` slot (stable shape). `indices`/`modes` restrict
  the set.

### Fixed

- NDMI FAST alert maps were never produced: `.enumerate_cache_scenes()`
  had no `NDMI` branch in its `index` switch, so an NDMI request matched
  zero cached scenes and `read_fast_alert_raster(index = "NDMI")` /
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  always returned `NULL` despite B08 + B11 being cached. The switch now
  maps `NDMI -> B08 + B11` and aborts on an unknown index instead of
  failing silently (spec 019 regression).

## \[0.64.0\] - 2026-06-03

### Added

- NDMI index in the FAST health-monitoring subsystem (spec 019):
  `NDMI = (B08 - B11) / (B08 + B11)` (NIR − SWIR1), a
  vegetation-moisture proxy.
  [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md),
  [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md),
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  and
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  accept `index/indices = "NDMI"`;
  [`read_s2_band_raster()`](https://pobsteta.github.io/nemeton/reference/read_s2_band_raster.md)
  /
  [`read_s2_band_stack()`](https://pobsteta.github.io/nemeton/reference/read_s2_band_stack.md)
  accept band `"B11"`. The FAST default stays NDVI (back-compatible);
  the D6 cache key includes the index, so NDMI COGs (`fast_NDMI_*`)
  never collide with existing NDVI/NBR caches.

### Changed

- [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  accepts `bands = "NDMI"` and now caches B11 systematically
  (best-effort, spec 019 D3): a scene lacking the B11 asset is skipped
  without failing NDVI/NBR ingestion. `.s2_required_bands()` maps
  `NDMI -> B08, B11`; `.cache_scene_bands()` gains an `optional_bands`
  argument.

## \[0.63.0\] - 2026-06-03

### Added

- `R/knowledge-corpus.R` — public API for RAG corpus administration
  (spec 009.2), so a `nemetonshiny` admin tab can edit the manifest and
  import the corpus without re-implementing business logic:
  [`knowledge_manifest_vocab()`](https://pobsteta.github.io/nemeton/reference/knowledge_manifest_vocab.md)
  (single source of truth for the controlled vocabularies),
  `knowledge_manifest_path(writable)` (packaged seed vs writable project
  copy, D1),
  [`read_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/read_knowledge_manifest.md),
  [`validate_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/validate_knowledge_manifest.md)
  (structured issues incl. license-gate D5 invariants),
  [`write_knowledge_manifest()`](https://pobsteta.github.io/nemeton/reference/write_knowledge_manifest.md)
  (deterministic minimal quoting), and
  `build_knowledge_corpus(con, …, dry_run, progress)` (ingestion
  orchestrator returning a structured per-document report).

### Changed

- `data-raw/build_knowledge_corpus.R` reduced to a thin CLI wrapper over
  [`build_knowledge_corpus()`](https://pobsteta.github.io/nemeton/reference/build_knowledge_corpus.md);
  environment-variable semantics (including the “no fallback to
  `NEMETON_DB_URL`” safety rule) preserved.
- `tests/testthat/test-knowledge-corpus-manifest.R` now consumes
  [`knowledge_manifest_vocab()`](https://pobsteta.github.io/nemeton/reference/knowledge_manifest_vocab.md)
  instead of duplicating the controlled vocabularies.

## \[0.62.0\] - 2026-06-02

### Added

- [`ingest_knowledge_reference()`](https://pobsteta.github.io/nemeton/reference/ingest_knowledge_reference.md)
  — exported reference-only ingestion for the RAG corpus (spec 009.1
  §5). Stores a single citation chunk (title, author, year, URL +
  optional abstract) without the protected full text; records
  `link_only` / `abstract_only` under the JSON `metadata.ingestion_mode`
  (no schema change). Delegates chunk/embed/ insert to
  [`ingest_knowledge_document()`](https://pobsteta.github.io/nemeton/reference/ingest_knowledge_document.md)
  (DRY).
- `data-raw/build_knowledge_corpus.R` now routes `abstract_only` /
  `link_only` manifest rows (previously skipped) through
  [`ingest_knowledge_reference()`](https://pobsteta.github.io/nemeton/reference/ingest_knowledge_reference.md),
  under the same D5 license gate.

## \[0.61.2\] - 2026-06-02

### Changed

- RAG corpus manifest: license arbitration (spec 009.1 D5, decided by
  Pascal). `bernard_doridant_2024_fordead` (ONF/DSF, basis of the R5
  guardrails) cleared as Licence Ouverte;
  `set_revue_foret_croissance_climat` cleared as open/CC-BY (the only
  `to_confirm` row with a local PDF, now ingestible). The four copyright
  papers (Mouret 2022, Fassnacht 2016, McCool 1987, Beven & Kirkby 1979)
  stay `to_confirm`. Manifest is now 35 cleared / 4 to_confirm.

## \[0.61.1\] - 2026-06-02

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
  the D5/§5 safety invariants (a `cleared` row needs a confirmed
  license; a `copyright` document is never `full`-ingested).
- `inst/NOTICE`: a “RAG knowledge corpus” section attributing the corpus
  sources by license class.

## \[0.61.0\] - 2026-06-02

### Added

- [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  gains opt-in `prewarm_alerts = FALSE` +
  `prewarm_mask_cache_dir = NULL` (spec 018). When
  `prewarm_alerts = TRUE`, a successful ingestion chains on four
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  calls (`NDVI`/`NBR` × `count`/`rolling`, default threshold,
  `window_days = 30`) so the four usual FAST alert maps land in the D6
  result cache and the app’s FAST tab is instant on first visit.
  Per-combination failures warn and are skipped (the others still
  complete); the pre-warm polls `cancel_path` between combinations and
  never starts on a cancelled ingestion. New internal helper
  `.prewarm_fast_alerts()`. Progress heartbeat events
  `fast_prewarm:<index>_<mode>` / `_done` / `_failed`.

## \[0.60.0\] - 2026-06-02

### Removed

- `read_obs_pixel()`, `list_fast_alerts_for_zone()` and
  `detect_alerts()` (deprecated in v0.58.0) are removed. Use
  [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  /
  [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
  and
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  /
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  instead. Files `R/read_obs_pixel.R`, `R/fast_alerts.R`, `R/alerts.R`
  and their `man/` pages deleted; exports removed from `NAMESPACE`.
- `CREATE TABLE obs_pixel` (and the PG `create_hypertable` call) removed
  from `0001_init.sql` (PG + SQLite): fresh databases never create the
  table. Migration `0004_drop_obs_pixel.sql` is kept for existing
  databases (idempotent DROP, no-op on a fresh DB).

## \[0.58.0\] - 2026-06-02

### Removed

- [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  no longer extracts per-plot means nor inserts into `obs_pixel`; it
  only primes the COG band cache (B04/B08/B12). STAC resolution, the
  on-disk band cache and the `s2:*` heartbeats are unchanged. The
  `n_obs_inserted` summary field is gone; `skip_cached` now operates on
  the COG cache (a scene is skipped when all its required band COGs
  already exist on disk).
- Internal helpers `.insert_obs_pixel()` and `.find_cached_obs_dates()`
  removed; `.extract_scene_obs()` replaced by `.cache_scene_bands()`.

### Changed

- Migration `0004_drop_obs_pixel.sql` (PG + SQLite) drops the
  `obs_pixel` table (idempotent). The pure per-pixel FAST diagnostic
  ([`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md),
  spec 017) has been its only path since v0.55.0.

### Deprecated

- `read_obs_pixel()`, `list_fast_alerts_for_zone()` and
  `detect_alerts()` (all legacy `obs_pixel` consumers) are deprecated
  and emit a
  [`cli::cli_warn`](https://cli.r-lib.org/reference/cli_abort.html);
  scheduled for removal in v0.60.0. Use the per-pixel COG cache
  ([`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  /
  [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md))
  and
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  /
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  instead.

## \[0.57.0\] - 2026-06-02

### Added

- Opt-in multi-core scene processing (spec 017 D4).
  [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  and
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  /
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  gain a `parallel = FALSE` argument; when `TRUE` and `furrr` is
  installed the per-scene index compute runs in
  [`furrr::future_map()`](https://furrr.futureverse.org/reference/future_map.html)
  (caller sets the
  [`future::plan()`](https://future.futureverse.org/reference/plan.html)).
  Workers return
  [`terra::wrap()`](https://rspatial.github.io/terra/reference/wrap.html)-ed
  rasters that the main process unwraps; results are identical to
  sequential. Falls back to sequential when `furrr` is absent. Closes
  spec 017.

## \[0.56.0\] - 2026-06-01

### Added

- Content-addressed persistence of the FAST alert raster (spec 017 D6).
  [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  gains `cache_result = TRUE` and `result_cache_dir = NULL`: the
  continuous raster is written as a COG keyed by a hash of its inputs
  (scenes + index + threshold + mode + window_days + dates + mask WKT),
  so a same-input revisit is served instantly from disk and the cache
  self-invalidates on any change. At most
  `getOption("nemeton.fast_raster_keep", 20)` COGs kept per zone.
- [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md)
  passes `cache_result` / `result_cache_dir` through; quartiles are
  recomputed from the persisted COG without a raster recompute. Hash via
  [`rlang::hash`](https://rlang.r-lib.org/reference/hash.html) (no
  `digest` dependency).

## \[0.55.2\] - 2026-06-01

### Fixed

- [`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
  : `INSERT INTO schema_migration … ON CONFLICT DO NOTHING` (sans
  colonne cible) n’est valide que sur SQLite ≥ 3.35.0 ; routage par
  backend vers `INSERT OR IGNORE` sur SQLite (no-op sous PostgreSQL).
- [`.insert_fordead_alerts()`](https://pobsteta.github.io/nemeton/reference/dot-insert_fordead_alerts.md)
  et `detect_alerts()` : ajout de `WHERE 1=1` sur le `SELECT` des
  `INSERT … SELECT … ON CONFLICT` pour lever l’ambiguïté d’analyse
  UPSERT/jointure de SQLite (`near "DO": syntax error`). Complète le
  correctif `.insert_obs_pixel()` de la v0.55.1.
- Tests de non-régression SQLite ajoutés
  (`test-fordead-alert-insert-sqlite.R`, `helper-sqlite.R`).

## \[0.55.1\] - 2026-06-01

### Fixed

- `.insert_obs_pixel()` : correction d’une erreur fatale
  `near "DO": syntax error` sur le backend SQLite local.
  L’`INSERT … SELECT … ON CONFLICT … DO NOTHING` souffrait de
  l’ambiguïté d’analyse UPSERT/jointure de SQLite ; ajout d’une clause
  `WHERE 1=1` sur le `SELECT` pour lever l’ambiguïté (no-op sous
  PostgreSQL). Test de non-régression SQLite ajouté. \## \[0.55.0\] -
  2026-05-31

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
  placettes (spec 017 D3). `con`/`zone_id` are used only for the UGF
  mask.

### Added

- Internal helpers `.enumerate_cache_scenes()`, `.s2_scene_date()`,
  `.fast_alert_quartile_breaks()`.
- `specs/017-fast-alert-raster-perf/spec.md` (D1-D6; perf phases D6/D4
  follow in v0.56.0 / v0.57.0).

## \[0.54.0\] - 2026-05-31

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
- `.Renviron.example` documenting `NEMETON_DB_URL` /
  `NEMETON_DB_URL_TEST`.

## \[0.53.0\] - 2026-05-31

### Added

- `ingest_sentinel2_timeseries(..., cancel_path = NULL)` — cooperative
  file-based cancellation. The worker polls `file.exists(cancel_path)`
  between tiles; when the flag appears it exits cleanly after the
  current tile, keeping already-committed tiles. The summary gains a
  `status` column (`"success"` / `"cancelled"`) and an `s2:cancelled`
  progress event.
- `run_fordead_dieback(..., cancel_path = NULL)` — same, polled at phase
  boundaries (after ingest / fit / predict). Returns
  `status = "cancelled"` with a `phase` field; emits
  `fordead:cancelled`. The Python subprocess is not force-killed.
- A cancel flag already present at entry is ignored as a stale leftover
  (with a warning); `cancel_path = NULL` performs zero filesystem polls.

### Changed

- The
  [`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md)
  summary `data.frame` now carries a trailing `status` column (additive;
  by-name access unaffected).

## \[0.52.1\] - 2026-05-30

### Fixed

- [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  now aligns per-scene layers onto the **union** of their extents
  (NA-padding via
  [`terra::extend()`](https://rspatial.github.io/terra/reference/extend.html))
  instead of cropping to the intersection. Fixes multi-tile MGRS AOIs
  (e.g. villards on T31TFM ⊂ T31TGM) where the pixel NDVI/NBR map was
  silently trimmed to the narrowest tile’s strip.
- Multi-CRS guard in
  [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md):
  layers in a different CRS are reprojected onto the first layer’s CRS
  before the union; non-coinciding grids fall back to a single
  [`terra::resample()`](https://rspatial.github.io/terra/reference/resample.html)
  onto the widest layer.
- The FAST alert path
  ([`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md)
  /
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md))
  is unchanged — its per-MGRS-tile grouping
  - `mosaic(fun = "max")` already covers multi-tile AOIs and avoids
    double-counting the S2 overlap strip; rationale comment updated.

### Changed

- [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  “Skipped N/total scenes (incomplete cache)” message downgraded from a
  per-call `cli_warn` to `rlang::inform(.frequency = "once")` (was
  spamming ~12 identical lines per Shiny load).

## \[0.52.0\] - 2026-05-29

### Added

- RAG knowledge base for AI perspectives (E7, spec 009) — seven exported
  functions in `R/rag.R`:
  [`enable_rag()`](https://pobsteta.github.io/nemeton/reference/enable_rag.md),
  [`ingest_knowledge_document()`](https://pobsteta.github.io/nemeton/reference/ingest_knowledge_document.md),
  [`embed_query()`](https://pobsteta.github.io/nemeton/reference/embed_query.md),
  [`retrieve_knowledge()`](https://pobsteta.github.io/nemeton/reference/retrieve_knowledge.md),
  [`list_knowledge_documents()`](https://pobsteta.github.io/nemeton/reference/list_knowledge_documents.md),
  [`delete_knowledge_document()`](https://pobsteta.github.io/nemeton/reference/delete_knowledge_document.md),
  [`format_citations()`](https://pobsteta.github.io/nemeton/reference/format_citations.md).
- Opt-in RAG migration `inst/db/migrations/{pg,sqlite}/rag/0004_rag.sql`
  (`knowledge_document` + `knowledge_chunk`), applied by
  [`enable_rag()`](https://pobsteta.github.io/nemeton/reference/enable_rag.md)
  rather than the default
  [`db_migrate()`](https://pobsteta.github.io/nemeton/reference/db_migrate.md)
  sequence (PostgreSQL needs pgvector; ADR-012).
- Dual-backend retrieval: pgvector `<=>` on PostgreSQL, R-side cosine on
  SQLite (JSON-encoded embeddings). Embedding providers: Mistral
  (default), OpenAI, Voyage AI.
- `pdftools` added to Suggests (offline PDF ingestion).

### Changed

- `vector(3072)` embedding column carries **no** ivfflat index (pgvector
  caps ivfflat/hnsw at 2000 dims); PostgreSQL retrieval is exact KNN.
  halfvec(3072)+hnsw deferred to ADR-012 when the corpus grows.

## \[0.49.1\] - 2026-05-27

### Added

- `create_validation_sampling_plan(..., control_classes = c(0L))` — new
  argument to relax the strict “class 0 = healthy” filter for control
  plots. Useful on heavily disturbed zones where no class-0 cell exists
  (villards FAST: all 8471 UGF pixels were class 4).
- Enriched warning when no control candidates : the message now reports
  the alert raster’s class distribution to help the user pick a relaxed
  `control_classes` value.
- `alert_class` column of control plots now reflects the actual cell
  value (was hard-coded to `0L`).

## \[0.49.0\] - 2026-05-27

### Changed

- All raster readers in the FAST / FORDEAD pipeline mask their outputs
  to the UGF polygon by default (`apply_zone_mask = TRUE`). Pixels
  outside the UGFs become `NA`. The on-disk COG cache is unchanged
  (still a rectangle aligned to the pixel grid) ; the mask is applied
  after read, before return. Spec 016.
- [`read_fast_alert_raster()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_raster.md),
  [`compute_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/compute_fast_alert_mask.md),
  [`read_fast_alert_mask()`](https://pobsteta.github.io/nemeton/reference/read_fast_alert_mask.md),
  [`read_fordead_dieback_mask()`](https://pobsteta.github.io/nemeton/reference/read_fordead_dieback_mask.md)
  gain `apply_zone_mask = TRUE` / `mask_polygon = NULL` arguments. Pass
  `apply_zone_mask = FALSE` for the pre-v0.49.0 rectangle output.
- [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  gains `mask_polygon = NULL`. Lower-level helper without `con` /
  `zone_id`, the polygon must be passed explicitly.
- [`extract_pixel_timeseries()`](https://pobsteta.github.io/nemeton/reference/extract_pixel_timeseries.md)
  gains `zone_polygon = NULL` / `warn_outside_zone = TRUE`. No raster
  mask (single-point query), only a warning when the click sits outside
  the UGFs.

### Added

- Internal helper `.apply_zone_mask(raster, zone_polygon)` in
  `R/zone_aoi.R`. Wraps
  [`terra::mask()`](https://rspatial.github.io/terra/reference/mask.html)
  with CRS reprojection and a defensive `tryCatch` (failure → unmask
  with `cli_warn`).

### Notes

- `read_obs_pixel()` is unchanged. The existing
  `plot.zone_id = $zone_id` filter IS the UGF membership filter de facto
  (plots are registered inside the UGFs by
  [`register_monitoring_zone()`](https://pobsteta.github.io/nemeton/reference/register_monitoring_zone.md)).
  No spatial `ST_Within` post-filter added.

## \[0.48.3\] - 2026-05-27

### Fixed

- Cache S2 : memoize the COG tile native extent per MGRS code in a
  session-scoped environment. The tile-aware second chance introduced in
  v0.48.2 was paying ~10-25 s per band per scene for the GET range that
  reads the COG header, even though all bands of all dates of the same
  MGRS tile share the same native extent. Villards full re-validation
  drops from ~1 h to ~50 s.

### Added

- Internal helpers `.s2_tile_ext_cache` (environment),
  `.s2_tile_ext_memoize(tile_code, href)`, and
  `.s2_tile_ext_cache_clear()` (test helper).

## \[0.48.2\] - 2026-05-27

### Fixed

- Cache S2 predicate gains a tile-aware second chance : when the
  snap-to-grid check (v0.48.1) says STALE, the COG header is read lazily
  (`terra::rast(href)`, ~1 s, no pixel decode) to obtain the tile’s
  native extent, `needed_ext` is clipped to that extent, and the
  predicate is retried. Fires CACHE-HIT when the cached file is the
  legitimate clip of the AOI to the MGRS tile boundary (the common case
  on multi-tile AOIs like villards spanning T31TFM + T31TGM). Eliminates
  the residual “fake STALE” after v0.48.1’s snap-to-grid.

## \[0.48.1\] - 2026-05-27

### Fixed

- Cache S2 validation predicate switches from raw-float
  `.ext_contains(tol = 40m)` to pixel-grid-aware
  `.ext_contains_at_grid(res, tol_pixels = 1)`. Snaps both extents to
  the COG’s pixel grid before comparison → sub-pixel jitter from
  `sf::st_transform(zone_polygon, raster_crs)` is eliminated at the
  source. Resolves villards CACHE-STALE storm (~6 h ingest → ~30 s on a
  warm cache).
- New ENV bypass `NEMETON_S2_CACHE_SKIP_VALIDATION` (`"TRUE"` or `"1"`)
  — emergency escape hatch to trust every cached file blindly.
- Diagnostic log on CACHE-STALE now shows snapped extents + signed
  per-side margin (`delta_m`) for quick triage.

### Added

- Internal helpers `.snap_ext_to_grid(ext, res)` and
  `.ext_contains_at_grid(outer, inner, res, tol_pixels)`.
- Internal helper `.cache_skip_validation()` (env var check).

## \[0.48.0\] - 2026-05-26

### Added

- `lasR` fallback to derive MNT/MNH from cached `.laz` tiles when IGN
  pre-rasterized downloads fail. See
  [`compute_dtm_chm_from_laz()`](https://pobsteta.github.io/nemeton/reference/compute_dtm_chm_from_laz.md),
  `resolve_project_dem/chm(try_compute_from_laz = TRUE)`. Diagnostic
  helpers
  [`probe_ign_lidar_tile()`](https://pobsteta.github.io/nemeton/reference/probe_ign_lidar_tile.md)
  /
  [`probe_ign_lidar_tiles()`](https://pobsteta.github.io/nemeton/reference/probe_ign_lidar_tiles.md)
  classify IGN failures. `lasR (>= 0.10.0)` in Suggests.

## \[0.47.5\] - 2026-05-26

### Fixed

- [`build_index_stack()`](https://pobsteta.github.io/nemeton/reference/build_index_stack.md)
  (spec 010) now computes the intersection of per-scene extents and
  crops each layer to that common extent before `terra::rast(layers)`.
  Fixes `[rast] extents do not match` triggered by mixed-vintage cache
  files (different AOI snapping across app sessions). Returns `NULL`
  with a warn if no overlap. Unblocks Carte FAST, Alertes FAST, FAST
  validation sampling.

## \[0.47.4\] - 2026-05-25

### Fixed

- Bump cache-hit tolerance from `1 * max(res)` (10/20 m) to
  `4 * max(res)` (40/80 m). 1-pixel tolerance still triggered
  CACHE-STALE on villards because previous-session cache files were
  written for a slightly different `sf::st_union(parcels)` polygon.

## \[0.47.3\] - 2026-05-25

### Fixed

- `.ext_contains(outer, inner, tolerance = 0)` gains a `tolerance`
  argument (CRS units). The cache-hit lookup in `.get_s2_band_raster()`
  now passes `tolerance = max(terra::res(r_cached))` so a sub-pixel
  mismatch between the cached extent and the AOI doesn’t trigger a
  CACHE-STALE. Closes the villards CACHE-STALE storm — projected refetch
  from ~4 h to ~10-30 min. Strict (`tolerance = 0`) default for
  back-compat.
- `[s2_cache]` verbose log now reports the tolerance value when
  CACHE-STALE fires anyway: `… (tol=10m), refetching`.

## \[0.47.2\] - 2026-05-25

### Fixed

- `tests/testthat/helper-monitoring.R::with_clean_db()` now refuses to
  run when `NEMETON_DB_URL_TEST` is unset or equal to `NEMETON_DB_URL`
  (the helper’s `reset_schema()` would otherwise wipe the user’s
  production monitoring data). Override via
  `NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE` for CI on an empty DB.
  Closes the gap that destroyed villards on 2026-05-25.

## \[0.47.1\] - 2026-05-25

### Fixed

- [`.fordead_is_installed()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_is_installed.md)
  and
  [`.ensure_fordead_python()`](https://pobsteta.github.io/nemeton/reference/dot-ensure_fordead_python.md)
  swap
  [`cli::cli_alert_warning()`](https://cli.r-lib.org/reference/cli_alert.html)
  /
  [`cli::cli_alert_info()`](https://cli.r-lib.org/reference/cli_alert.html)
  for
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html) /
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)
  so the emitted warning / message condition is catchable by
  `expect_warning()` / `expect_message()` (the `_alert_*` family is
  cosmetic only). No user-visible change.
- `test-fordead-python.R` — `.assert_fordead_system` test captures
  [`base::requireNamespace`](https://rdrr.io/r/base/ns-load.html) before
  mocking so the mock’s else-branch doesn’t recurse into itself.

Suite `test-fordead-python.R` 57 ✓ (was 3 fails). Closes the « ~9 échecs
préexistants » documented in v0.43.2.

## \[0.47.0\] - 2026-05-25

### Added

- `fordead_alert_mask(alert_raster, classes, buffer_m)` — exported.
  Extracts alert cells from a categorical 0-4 SpatRaster (FORDEAD
  `dieback_mask` or FAST mask), preserves their class value (NA
  elsewhere), with optional metric buffer dilation. Output is suitable
  both as mask AND as priority raster.
- `compute_fast_alert_mask(con, zone_id, ..., cache_dir, mask_cache_dir, breaks)`
  — exported. Discretises \[read_fast_alert_raster()\] (v0.46.0) to the
  0-4 scale aligned with FORDEAD, persists under
  `<mask_cache_dir>/zone_<id>/fast_alert_<ts>.tif`.
- `read_fast_alert_mask(con, zone_id, run_id, cache_dir)` — exported.
  Strict mirror of \[read_fordead_dieback_mask()\] reading the persisted
  0-4 mask, NULL when no file matches.
- `create_validation_sampling_plan(zone, alert_raster, n_validation, n_control, classes, buffer_m, source, seed)`
  — exported. Single entry point returning an `sf` POINT (EPSG:2154)
  combining validation plots (unequal-probability GRTS on the alert
  mask) + control plots (equiprobable GRTS on healthy class 0), with TSP
  visit order. Spec 014 phase A.

### Internal

- Helpers `.draw_grts_weighted()`, `.draw_grts_equiprobable()`,
  `.compute_visit_order()` in `R/validation_sampling.R`.

## \[0.46.0\] - 2026-05-24

### Added

- `read_fast_alert_raster(con, zone_id, threshold_ndvi, threshold_nbr, date_from, date_to, mode, window_days, cache_dir)`
  — exported. Produces a single-band `SpatRaster` (EPSG:2154) of FAST
  alerts at native S2 pixel resolution. Two modes: `"count"` (integer
  per-pixel alert-day count) and `"rolling"` (continuous deficit
  magnitude on the trailing window). Multi-tile MGRS AOIs handled via
  per-tile compute + mosaic. Spec 013.
- Internal helpers `.compute_alert_count()`, `.compute_alert_rolling()`,
  `.s2_mgrs_tile()` in `R/fast_alert_raster.R`.

## \[0.45.0\] - 2026-05-23

### Changed

- FAST
  ([`ingest_sentinel2_timeseries()`](https://pobsteta.github.io/nemeton/reference/ingest_sentinel2_timeseries.md))
  and FORDEAD-ingest
  ([`ingest_s2_raw_bands_to_cache()`](https://pobsteta.github.io/nemeton/reference/ingest_s2_raw_bands_to_cache.md))
  now resolve their Sentinel-2 AOI through `monitoring_zone.zone_wkt`
  via the new shared helper
  [`.get_zone_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-get_zone_aoi.md)
  (moved to `R/zone_aoi.R`). Both pipelines crop the COG to the same
  extent → the on-disk cache is reusable across them. Spec 012.
- `.extract_scene_obs()` gains an optional `crop_aoi` argument.
- Defensive fallback to per-plot bbox + warn when `zone_wkt` is empty or
  unparseable.

### Added

- `R/zone_aoi.R` — shared resolver `.get_zone_aoi(con, zone_id)`.

## \[0.44.0\] - 2026-05-23

### Added

- Migration `0003_project_uuid` (PG + DuckDB) adding
  `monitoring_zone.project_uuid TEXT` and a partial UNIQUE index on
  non-NULL values. Spec 011.
- `register_monitoring_zone(..., project_uuid = NULL)` — optional new
  argument, persisted on the zone row when non-NULL.
- `find_zone_by_project(con, project_uuid)` — new exported function
  returning the bound zone id or `integer(0)`. Does **not** fall back to
  a `name`-based lookup.

## \[0.43.2\] - 2026-05-23

### Fixed

- [`.same_path()`](https://pobsteta.github.io/nemeton/reference/dot-same_path.md)
  (`R/fordead_python.R`) collapses `/./`, duplicate slashes and a
  trailing slash before comparing — `normalizePath(mustWork = FALSE)`
  leaves non-existent paths untouched, so the identity test produced
  false negatives whenever one input had a redundant segment.
- `.validate_date_range()` (`R/fordead_stac.R`) wraps
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) in `tryCatch`:
  recent R errors on an unparseable string instead of returning `NA`
  with a warning, which was swallowing the actionable “must parse as a
  date (ISO yyyy-mm-dd)” message.
- [`diagnose_s2_cache()`](https://pobsteta.github.io/nemeton/reference/diagnose_s2_cache.md)
  (`R/monitoring.R`) orphan cleanup uses `unlink( recursive = TRUE)` —
  `recursive = FALSE` never removes a directory, even an empty one, so
  the cleanup branch was a silent no-op.
- `test-monitoring.R` progress-callback assertion expects the
  `s2:cache_lookup` event introduced earlier and indexes events by
  `current` key rather than by position.

## \[0.41.2\] - 2026-05-20

### Fixed

- Sentinel-2 STAC searches returned ESA reprocessing duplicates (the
  same acquisition republished under a new processing baseline) as
  distinct scenes — doubling the cache footprint (~14 % of scenes on a
  real zone) and feeding FORDEAD two items with the same `datetime`.
  [`stac_search_s2()`](https://pobsteta.github.io/nemeton/reference/stac_search_s2.md)
  and
  [`.build_stac_collection_for_aoi()`](https://pobsteta.github.io/nemeton/reference/dot-build_stac_collection_for_aoi.md)
  now collapse such duplicates by acquisition identity (mission +
  sensing time + orbit + MGRS tile), keeping the latest baseline.

### Added

- Internal helpers `.s2_split_product_id()` and
  `.dedup_s2_reprocessed()` — Sentinel-2 reprocessing-duplicate
  detection and removal.

## \[0.41.1\] - 2026-05-20

### Fixed

- FORDEAD version probe read the `fordead.version` *attribute* (a
  function, not a string), so the installed version never matched the
  pin and `pip install --upgrade` ran on every
  [`run_fordead_dieback()`](https://pobsteta.github.io/nemeton/reference/run_fordead_dieback.md)
  call.
  [`.fordead_python_version()`](https://pobsteta.github.io/nemeton/reference/dot-fordead_python_version.md)
  now reads `importlib.metadata.version("fordead")`; the pipeline start
  banner reuses the same probe, so `fordead_version` is reported
  correctly instead of `NA`.

### Added

- Internal helper
  [`.python_capture_stdout()`](https://pobsteta.github.io/nemeton/reference/dot-python_capture_stdout.md)
  — mockable [`system2()`](https://rdrr.io/r/base/system2.html) wrapper
  used by the FORDEAD version probe.

## \[0.40.0\] - 2026-05-20

### Added

- [`theia_signed_href()`](https://pobsteta.github.io/nemeton/reference/theia_signed_href.md)
  — resolves a `/vsicurl/`-prefixed signed THEIA asset URL via the
  `teledetection` Python SDK (reticulate).
- [`load_theia_source()`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md)
  year mode now signs the asset URL through the SDK and reads it via
  `/vsicurl/` — the validated authenticated path for THEIA assets.

## \[0.39.1\] - 2026-05-20

### Fixed

- [`theia_configure_s3()`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
  reads `TLD_ACCESS_KEY` / `TLD_SECRET_KEY` (the THEIA API-key pair)
  instead of `THEIA_S3_*`, and the S3 region is `sm1` (not `us-east-1`).
  GDAL `/vsis3/` reads the THEIA assets directly — no Python SDK needed.

## \[0.39.0\] - 2026-05-20

### Added

- [`stac_get_item()`](https://pobsteta.github.io/nemeton/reference/stac_get_item.md)
  — fetch a single STAC item by id.
- [`resolve_theia_assets()`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md)
  /
  [`load_theia_source()`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md)
  gain a `year` argument to target one year of an annual THEIA
  collection (FORMSpoT). `formspot` in `FR.json` gains
  `item_id_template`, `asset_template` and `years`.

## \[0.38.0\] - 2026-05-20

### Added

- [`theia_configure_s3()`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
  — configures GDAL `/vsis3/` for authenticated reads of the THEIA S3
  object store; credentials from `THEIA_S3_ACCESS_KEY` /
  `THEIA_S3_SECRET_KEY` env vars.
- `services.theia_s3` entry in `FR.json` (endpoint, bucket).

### Changed

- [`resolve_theia_assets()`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md)
  returns `/vsis3/` paths (gateway / `s3://` / `https://` hrefs are
  normalised).
- [`load_raster_source()`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)
  `path` argument accepts remote (`s3://`, `http(s)://`, `/vsi*`) paths,
  not only local files.

## \[0.37.0\] - 2026-05-20

### Changed

- THEIA STAC API endpoint corrected to
  `https://api.stac.teledetection.fr` (verified against the FORMSpoT
  data-access notebook). `services.theia_stac` documents the required
  teledetection API-key authentication.
- FORMSpoT metadata verified: collection `FORMSpoT`, yearly items
  `FORMSpoT-{year}` (2014-2024), `height_{year}` assets, height in
  decimetres.

### Added

- New datasource `formspot_delta` — FORMSpoT-∆ forest-disturbance
  polygons (`consumed_by`: R5, T2).

## \[0.36.1\] - 2026-05-20

### Fixed

- `services.theia_stac.url` set to the verified THEIA MTD STAC API root;
  `forms_t` gains `stac_collection: "forms-t"`.
- Theia STAC resolver `"to confirm"` guard now uses a substring match,
  correctly rejecting the `"to confirm at the Theia catalogue"`
  placeholders.

## \[0.36.0\] - 2026-05-20

### Added

- THEIA STAC resolver (`R/theia_stac.R`):
  [`stac_search_items()`](https://pobsteta.github.io/nemeton/reference/stac_search_items.md),
  [`resolve_theia_assets()`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md)
  and
  [`load_theia_source()`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md)
  materialise the Theia datasources from the THEIA STAC API. New
  `services.theia_stac` entry in `FR.json` (STAC API URL still to
  confirm). Closes the deferred Phase 2 STAC-resolution item.

## \[0.35.2\] - 2026-05-20

### Changed

- `formspot` datasource entry: FORMSpoT is wired into the C1/P1/P2/B2
  indicators through the existing `chm` argument (the shared CHM
  interface used by FORMS-T and chm_opencanopy). The `consumed_by` block
  now names the precise indicator functions, `products` splits into
  `height` / `biomass`, and an `integration_note` documents the
  integration path.

## \[0.35.1\] - 2026-05-20

### Fixed

- `formspot` datasource entry: FORMSpoT is confirmed published as the
  THEIA STAC collection `FORMSpoT`; the entry now carries the verified
  `stac_catalog` / `stac_collection` fields instead of the provisional
  preprint-stage note.

## \[0.35.0\] - 2026-05-20

### Added

- Theia data sources, phase 3d:
  [`indicateur_w2_zones_humides()`](https://pobsteta.github.io/nemeton/reference/indicateur_w2_zones_humides.md)
  gains a `water_occurrence` argument (Theia `theia_water`);
  [`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)
  gains `soil_moisture` / `sm_relief_strength` arguments (Theia
  `theia_soil_moisture`); new exported helper
  [`units_add_species_from_raster()`](https://pobsteta.github.io/nemeton/reference/units_add_species_from_raster.md)
  fills a species column from the Theia `theia_species` product. Closes
  Phase 3 of the Theia chantier. Backward-compatible.

## \[0.34.0\] - 2026-05-20

### Added

- Theia data sources, phase 3c:
  [`indicateur_r3_secheresse()`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)
  gains `snow` and `snow_relief_strength` arguments — a Theia
  `theia_snow` snow-cover-duration raster attenuates the drought stress
  (snowpack as a seasonal water reserve). Backward-compatible.

## \[0.33.0\] - 2026-05-20

### Added

- Theia data sources, phase 3b: exported helpers
  [`texture_to_fertility_score()`](https://pobsteta.github.io/nemeton/reference/texture_to_fertility_score.md)
  and
  [`texture_to_erosion_resistance()`](https://pobsteta.github.io/nemeton/reference/texture_to_erosion_resistance.md);
  [`indicateur_f1_fertilite()`](https://pobsteta.github.io/nemeton/reference/indicateur_f1_fertilite.md)
  gains a `"theia_soil"` source + `texture` argument;
  [`indicateur_f2_erosion()`](https://pobsteta.github.io/nemeton/reference/indicateur_f2_erosion.md)
  gains a `texture` argument. Wires the Theia `theia_soil` product into
  the F1/F2 indicators.

## \[0.32.0\] - 2026-05-20

### Added

- Theia data sources, phase 3a:
  [`indicateur_c2_ndvi()`](https://pobsteta.github.io/nemeton/reference/indicateur_c2_ndvi.md)
  gains a `fapar` argument (FAPAR-based vitality) and
  [`indicateur_a1_couverture()`](https://pobsteta.github.io/nemeton/reference/indicateur_a1_couverture.md)
  gains an `fvc` argument (FVC-based tree coverage), wiring the Theia
  `s2_biophysical` product into the C2 and A1 indicators. Both arguments
  are optional and backward-compatible.

### Changed

- [`indicateur_a1_couverture()`](https://pobsteta.github.io/nemeton/reference/indicateur_a1_couverture.md):
  `land_cover` now defaults to `NULL` (required only in legacy mode,
  ignored in FVC mode).

## \[0.31.0\] - 2026-05-20

### Added

- [`load_raster_source()`](https://pobsteta.github.io/nemeton/reference/load_raster_source.md)
  gains a `path` argument so path-less `raster_local` datasources (the
  Theia products) can be loaded from a locally downloaded file.
- New exported helper
  [`get_datasource_product()`](https://pobsteta.github.io/nemeton/reference/get_datasource_product.md)
  returning the metadata of one sub-product of a multi-product
  datasource (e.g. `forms_t` height/volume/biomass).

## \[0.30.0\] - 2026-05-20

### Added

- Theia data sources, phase 1b: `theia_water`, `theia_soil_moisture`,
  `s2_l2a_muscate`, `theia_species`, `theia_lst` and `formspot` declared
  in `inst/datasources/FR.json`, completing Phase 1 (catalogue) of the
  Theia chantier. Declarative only — no core indicator code changed.

## \[0.29.0\] - 2026-05-20

### Added

- Theia data sources, phase 1a: `s2_biophysical` (LAI/FAPAR/FVC),
  `theia_soil` (texture fractions) and `theia_snow` (Let-it-snow
  collection) declared in `inst/datasources/FR.json`, with `consumed_by`
  wiring to the C2/A1/B2, F1/F2 and R3/W indicators respectively.
  Declarative only — no core indicator code changed.

## \[0.28.0\] - 2026-05-20

### Added

- `forms_t` dataset declared in `inst/datasources/FR.json`: the FORMS-T
  Theia time-series of canopy height (10 m), growing stock volume (30 m)
  and aboveground biomass (30 m) maps over metropolitan France (Schwartz
  et al. 2023, ESSD). Documents the `consumed_by` wiring of the height
  product into the CHM path of the C1, P1, P2 and B2 indicators.

## \[0.21.1\] - 2026-05-12

### Fixed

- DuckDB migration `0001_init.sql` rejected by the parser on
  `GENERATED ALWAYS AS IDENTITY` and `ON DELETE CASCADE`. Replaced with
  explicit `CREATE SEQUENCE` + `DEFAULT nextval(...)` and dropped the
  cascade actions from FK clauses. Fixes the “Base de suivi non
  configurée” error on first launch of `nemetonshiny` with a local
  DuckDB backend.

## \[0.19.11\] - 2026-04-24

### Changed

- [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  now clamps `n_base + n_over` to the candidate-frame capacity upfront,
  preserving the Base/Over ratio and emitting a `cli_warn()`. Prevents
  the silent LPM2 fallback that could drop all Over plots on small AOIs
  with strict forest-cover / slope filters.

### Added

- Two new unit tests covering the clamp logic: ratio preservation,
  minimum-1-Over guarantee, and warning signature.

## \[0.19.10\] - 2026-04-24

### Changed

- [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  now auto-simplifies the stratification (drops TPI, then type) when the
  full 3D combination would contain thin strata, instead of skipping
  GRTS entirely. A `cli_inform()` reports which dimensions were dropped.
  Extends GRTS coverage to small AOIs where the 3D stratification
  produces too many singletons.

### Added

- Internal helper `.fit_stratum()` plus four unit tests covering
  degradation, fully-thin edge cases, and constant-dimension handling.

## \[0.19.9\] - 2026-04-24

### Changed

- [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  now prints an informative
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)
  message on the two previously silent GRTS-skip paths (no usable
  stratification, `spsurvey` not installed), listing the concrete
  reasons. Users no longer have to guess why the draw fell back to LPM2
  or random.

## [0.19.7](https://github.com/pobsteta/nemeton/compare/v0.19.6...v0.19.7) - 2026-04-24

### Fixed

- `.compute_forest_cover()` now aligns its vectorised output using a
  carried `.fc_id` column instead of
  [`row.names()`](https://rdrr.io/r/base/row.names.html), which some sf
  versions rewrite on intersection. Fixes silent “all-zero” forest cover
  leading to empty candidate sets in
  [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md).

## [0.19.6](https://github.com/pobsteta/nemeton/compare/v0.19.5...v0.19.6) - 2026-04-24

### Performance

- `.compute_forest_cover()` vectorised: ~40-80× faster on typical GRTS
  loads (3000 candidates × 50 mask polygons now in ~0.7 s instead of
  30-60 s), removing the UI freeze on create_sampling_plan() calls.

## [0.19.5](https://github.com/pobsteta/nemeton/compare/v0.19.4...v0.19.5) - 2026-04-24

### Changed

- [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
  emits `"height_lidar"` in the augmented vector when
  `chm_source == "lidar_hd"`, distinct from the existing `"height_ml"`
  flag used for Open-Canopy.

## [0.19.4](https://github.com/pobsteta/nemeton/compare/v0.19.3...v0.19.4) - 2026-04-24

### Fixed

- [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  no longer floods the console with sf’s “attribute variables are
  assumed to be spatially constant” warning (one per candidate ×
  polygon). `.compute_forest_cover()` now sets
  [`sf::st_agr()`](https://r-spatial.github.io/sf/reference/st_agr.html)
  to `"constant"` and wraps `st_intersection()` in
  [`suppressWarnings()`](https://rdrr.io/r/base/warning.html).

## [0.19.3](https://github.com/pobsteta/nemeton/compare/v0.19.2...v0.19.3) - 2026-04-24

### Changed

- Flip every BD Forêt v2 TFV row in
  `inst/extdata/bdforet_v2_mapping.csv` from `confidence = "ambiguous"`
  to `"clear"` (9 rows touched). The secondary candidate stays in
  `alt_context_key` for reference.

### Fixed

- [`cv_from_bdforet()`](https://pobsteta.github.io/nemeton/reference/cv_from_bdforet.md)
  no longer reports non-forest codes (FF0, FO0, LA4, LA6) as `$unmapped`
  — these are explicitly mapped to `NA` and are silently excluded from
  the CV. Only codes truly absent from the mapping are surfaced as
  unmapped.

## [0.19.2](https://github.com/pobsteta/nemeton/compare/v0.19.1...v0.19.2) - 2026-04-24

### Changed

- Tour optimisation now uses
  [`TSP::solve_TSP()`](https://rdrr.io/pkg/TSP/man/solve_TSP.html)
  (nearest_insertion + 2-opt) — same recipe as tutorial 09-sampling.
  Hand-rolled fallback kept when the `TSP` package is not installed.
  `TSP (>= 1.2.0)` added to `Suggests`.

## [0.19.1](https://github.com/pobsteta/nemeton/compare/v0.19.0...v0.19.1) - 2026-04-24

### Fixed

- [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  now assigns `visit_order` from a real nearest-neighbor + 2-opt walking
  tour (start = south-easternmost Base plot) instead of from the draw
  order. The polyline drawn by the Shiny map is no longer a zig-zag
  across the AOI.

## [0.19.0](https://github.com/pobsteta/nemeton/compare/v0.18.0...v0.19.0) - 2026-04-24

### Added

- `compute_sample_size(cv, target_error, alpha, N)` — Cochran formula
  with iterative Student-t refinement and optional finite-population
  correction. (`R/sample_size.R`)
- [`cv_typology()`](https://pobsteta.github.io/nemeton/reference/cv_typology.md)
  / `cv_lookup(context_key, position)` — lookup over the 8 generic
  forest contexts with low / mid / high CV bounds on basal area G/ha.
  Reference CSV at `inst/extdata/cv_typology.csv` (editable by the
  caller via the `file =` argument).
- [`bdforet_v2_mapping()`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md)
  — 32 BD Forêt v2 TFV codes mapped to the generic contexts, with a
  confidence flag (`clear` / `ambiguous`) and a secondary candidate for
  the ambiguous ones. Reference CSV at
  `inst/extdata/bdforet_v2_mapping.csv`.
- `cv_from_bdforet(bdforet_sf, position, aoi, tfv_col)` — area- weighted
  CV for an AOI, plus a diagnostic summary (per-TFV share, ambiguous
  codes, unmapped codes).
- [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  now accepts `target_error`, `cv`, `alpha` and `over_ratio`: `n_base`
  is computed via
  [`compute_sample_size()`](https://pobsteta.github.io/nemeton/reference/compute_sample_size.md)
  when these are provided, with the result attached to the plan as
  `attr(plan, "sample_size")`.
- Library-level sampling pipeline
  [`create_sampling_plan()`](https://pobsteta.github.io/nemeton/reference/create_sampling_plan.md)
  — GRTS stratified when CHM/DEM/BD Forêt layers are available, with
  LPM2 (spatially-balanced) and random fallbacks.
- QField re-ingestion layer (`R/qgis_import.R`):
  [`import_qfield_gpkg()`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md),
  [`validate_field_data()`](https://pobsteta.github.io/nemeton/reference/validate_field_data.md),
  [`aggregate_plot_metrics()`](https://pobsteta.github.io/nemeton/reference/aggregate_plot_metrics.md),
  [`attach_field_data_to_units()`](https://pobsteta.github.io/nemeton/reference/attach_field_data_to_units.md),
  [`tag_field_data_sources()`](https://pobsteta.github.io/nemeton/reference/tag_field_data_sources.md).
- QField project export
  [`create_qfield_project()`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
  producing a ready-to-use `.qgz` (ZIP of `.qgs` XML + GPKG) with zero
  new hard dependency.
- Placette / arbre schema module (`R/field_schema.R`) used on both
  export and re-ingestion sides.
- [`detect_ndp()`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
  alternative path: placettes → NDP 2, full tree inventory (≥ 10
  trees/plot on average) → NDP 3.
- New data source `field_qfield` in `inst/datasources/FR.json`.
- `inst/extdata/cv_typology.csv` and
  `inst/extdata/bdforet_v2_mapping.csv` — editable reference tables.

### Changed

- `bdforet_v2_mapping.csv` now carries a `label_key` column (the
  normalized French libellé per TFV code).
  [`cv_from_bdforet()`](https://pobsteta.github.io/nemeton/reference/cv_from_bdforet.md)
  does a two-pass join — TFV code first, label fallback — so projects
  where the IGN WFS delivers libellés (instead of codes) in the `tfv`
  field no longer return NA / 0 % coverage.
- File renames: `R/qfield_export.R` → `R/qgis_export.R`,
  `R/qfield_import.R` → `R/qgis_import.R`, tests renamed accordingly.
  The exported function names (`create_qfield_project`,
  `import_qfield_gpkg`) are unchanged.

### Fixed

- [`cv_from_bdforet()`](https://pobsteta.github.io/nemeton/reference/cv_from_bdforet.md)
  normalizes incoming TFV values (trim, dashify separators, uppercase)
  before the lookup, so inputs like `FF2_64_64` or `" ff2-64-64 "`
  resolve to `FF2-64-64` as expected.

## Prior versions

See [NEWS.md](https://pobsteta.github.io/nemeton/NEWS.md) for the
complete narrative history (0.1.0 onwards).
