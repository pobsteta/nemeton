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

## Currently vendored (lot L2b.1)

- `custom_index.py` — IOTA² `external_features` hooks computing the two
  RECONFORT continuum-removal indices (CRswir, CRre) on the gap-filled
  Sentinel-2 series. Self-contained (numpy only).

## Deferred to later lots

The orchestration glue (S2 download via `pygeodes`, IOTA² config
generators, the `Iota2.py` subprocess driver, masking + continuous
score) depends on the upstream `utils/` package layout and the IOTA²
runtime. It will be vendored alongside the code that drives it:

- **L2b.2** — `run_geodes_download.py` / `run_process_downloaded_images.py`
  + `utils/` (S2 acquisition into the IOTA² layout).
- **L2b.3** — `run_map_production_reconfort.py`, `utils/generate_cfg_*`,
  `mask_and_compress_rasters.py` (IOTA² ×2 + RF + mask + continuous score).
