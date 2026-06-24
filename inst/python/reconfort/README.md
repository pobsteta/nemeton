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
- `iota2/external_features/custom_index.py` — IOTA² `external_features`
  hooks computing the two RECONFORT continuum-removal indices (CRswir,
  CRre) on the gap-filled Sentinel-2 series. Self-contained (numpy only).
  Lives at the path the IOTA² cfg references.

Lot **L2b.2** (S2 acquisition), driven by `R/reconfort_ingest.R`:
- `run_geodes_download.py` — downloads MUSCATE L2A archives from GEODES
  (`pygeodes`) for a tile + date range, per a `.cfg` file.
- `run_process_downloaded_images.py` — unzips the archives into the IOTA²
  `<s2_root>/extracted/<tile>/` layout.
- `utils/utils.py` (+ `utils/__init__.py`) — `load_config_variable()`, the
  `.cfg` reader both scripts use.

Lot **L2b.3** (map production), driven by `R/reconfort_pipeline.R`:
- `run_map_production_reconfort.py` — generates the two IOTA² cfg files,
  runs `Iota2.py` twice (sampling, then classification), copies the RF
  model in, then masks + computes the continuous score.
- `mask_and_compress_rasters.py` — `mask_rasters()` (OSO broadleaf mask)
  and `compute_continuous_score()` (`(1001 + (-P1 + P2 + 2*P3))/30`).
- `utils/generate_cfg_file_classif_part1_sampling_2y_nov_test_1tile.py`
  and `..._part2_classification_...py` — the IOTA² cfg templates.
- `iota2/` — static IOTA² inputs: `colorFile.txt`, `nomenclature.txt`,
  `config/iota2_resources.cfg`, `external_features/custom_index.py`,
  `vector_db/random_points.*` (1 dummy ground-truth point per class).

`R/reconfort_pipeline.R` stages a writable working copy of this tree per
run (the upstream scripts chdir to their own dir and write `results/`
there). The ~54 MB OSO mask and the RF models are fetched on demand
(`ensure_reconfort_oso_mask()`, `ensure_reconfort_model()`), not bundled.

## Réparation de l'environnement conda (`repair_iota2_env.sh`)

Le paquet `iota2` (canaux `iota2` + `iota2-deps`) a deux défauts qui cassent la
chaîne RECONFORT sur un install récent. Après avoir créé l'env conda, lancer
**une fois** :

```bash
bash repair_iota2_env.sh nemeton-reconfort
```

Idempotent. Il applique : (#9) `pandas < 3` — iota2 utilise
`to_datetime(infer_datetime_format=)`, supprimé en pandas 3 ; (#10) un wrapper
exécutable `task_launcher.py` dans `$ENV/bin/` — iota2 l'invoque en commande nue
mais ne l'expose pas comme console-script (les workers dask échouent sinon avec
`task_launcher.py: not found`).
