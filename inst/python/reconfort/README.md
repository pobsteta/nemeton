# Vendored RECONFORT Python glue

These files are **vendored verbatim** from the upstream RECONFORT
repository (https://framagit.org/fl.mouret/reconfort, branch `main`,
commit `25198c9`), which is licensed **Apache-2.0** (see
`inst/NOTICE` for attribution). Apache-2.0 is permissive and allows
redistribution with attribution, so the chain is bundled here rather
than fetched at runtime.

Do **not** edit these files by hand — re-vendor from upstream if it
changes, so the computation stays bit-for-bit identical to the
calibrated model's expectations.

## Currently vendored

Lot **L2b.1** (indices):
- `custom_index.py` — IOTA² `external_features` hooks computing the two
  RECONFORT continuum-removal indices (CRswir, CRre) on the gap-filled
  Sentinel-2 series. Self-contained (numpy only).

Lot **L2b.2** (S2 acquisition), driven by `R/reconfort_ingest.R`:
- `run_geodes_download.py` — downloads MUSCATE L2A archives from GEODES
  (`pygeodes`) for a tile + date range, per a `.cfg` file.
- `run_process_downloaded_images.py` — unzips the archives into the IOTA²
  `<s2_root>/extracted/<tile>/` layout.
- `utils/utils.py` (+ `utils/__init__.py`) — `load_config_variable()`, the
  `.cfg` reader both scripts use.

## Deferred to L2b.3

The map-production glue (`run_map_production_reconfort.py`,
`utils/generate_cfg_*`, `mask_and_compress_rasters.py`: IOTA² ×2 + RF +
mask + continuous score) will be vendored alongside the code that drives
it (`R/reconfort_pipeline.R`).
