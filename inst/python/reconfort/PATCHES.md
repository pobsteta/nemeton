# Modifications to the vendored RECONFORT code

Upstream: <https://framagit.org/fl.mouret/reconfort>, branch `main`,
commit `25198c9`, licensed Apache-2.0 (attribution in `inst/NOTICE`).
As required by Apache-2.0 §4(b), this file lists every vendored file that
nemeton has **modified**, and why. Inside each file the changes are marked
with `nemeton:` / `NOTE (nemeton):` comments, and the header says
"modified by nemeton".

Baseline: the files as first committed to nemeton (commits `9959fb9ff`,
`62e9cd1a6`, `4ff8abeb5`, June 2026), apart from the provenance header that
nemeton prepends to each file. Re-vendoring from upstream must re-apply the
patches below (or drop the ones upstream has fixed).

| File | Change | Why | nemeton commit |
|------|--------|-----|----------------|
| `run_process_downloaded_images.py` | Archive glob widened from `SENTINEL*D.zip` to `SENTINEL*.zip`. | Current MUSCATE/GEODES archives end in `_C_V4-0.zip`; the legacy glob extracted nothing. | `4e17c43d6` |
| `run_process_downloaded_images.py` | Optional extract-then-delete driven by the `delete_zip_after_extract` cfg key (absent key = upstream behaviour). | A full tile over two years filled the disk (zips + extracted scenes). | `de6dc2368` |
| `utils/generate_cfg_file_classif_part1_sampling_2y_nov_test_1tile.py`, `utils/generate_cfg_file_classif_part2_classif_2y_nov_test_1tile.py` | `builders_class_name` set to `I2Classification`. | The installed iota2 exposes the CamelCase class, not the module name. | `ae8121f48` |
| `iota2/config/iota2_resources.cfg` | Keys `name` / `process_min` / `nb_chunk` removed from the step blocks. | Rejected by the `TaskResources` dataclass of the recent iota2. | `8477b705c` |
| `iota2/external_features/custom_index.py` | Feature labels built as `I2TemporalLabel(...)` instead of strings. Computation and column order unchanged. | The recent iota2 requires `I2Label`/`I2TemporalLabel` labels. | `8477b705c` |
| `run_map_production_reconfort.py` | IOTA² return codes checked (`run_iota2()`), presence of the `final/` rasters checked (`require_final()`), explicit error on stderr. | A failed IOTA² chain went unnoticed and surfaced three steps later as a missing file. | `75bdf9c3a` |
| `utils/utils.py` | `load_config_variable()` no longer `eval()`s cfg values: `split("=", 1)` then `json.loads`, with an `ast.literal_eval` fallback for hand-written upstream cfg files; blank/comment lines skipped. | Code injection: any cfg value was executed as Python. | audit 1.0 (security) |
| `run_geodes_download.py` | Calls `utils.tls.enforce_tls_verification(conf)` before building `Geodes`. | pygeodes disables TLS certificate verification by default. | audit 1.0 (security) |
| `mask_and_compress_rasters.py` | Continuous score computed by a new pure `continuous_score_from_probas()`: bounded to [1, 100] (floor, as the former integer cast) before writing; no-data = every probability band is 0; a 2-band map gets `p3 = 0`. | Very healthy pixels (score < 1) were truncated to 0 = no-data, `sum_proba == 0` blanked valid pixels, and the 2-class `v3_pine` model crashed on band 3. | audit 1.0 (numerical) |
| `utils/generate_cfg_file_classif_part2_classification_2y_nov_test_1tile.py` | Renamed to `generate_cfg_file_classif_part2_classif_2y_nov_test_1tile.py` (import updated in `run_map_production_reconfort.py`). | Path exceeded the 100 bytes allowed in an R package tarball (`R CMD check` NOTE, 1.0 audit). | v0.211.0 |

Files vendored without modification (besides the header):
`utils/__init__.py`, `iota2/colorFile.txt`,
`iota2/nomenclature.txt`, `iota2/vector_db/random_points.*`.

Not RECONFORT code (nemeton-authored, GPL-3): `list_s2_items.py`,
`download_s2_item.py`, `utils/tls.py`, `repair_iota2_env.sh` (patches the
conda environment, not the files of this directory).
