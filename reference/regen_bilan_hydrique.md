# Soil water balance per unit — BILJOU engine (spec 027 L2)

Per-unit soil water-balance metrics (relative extractable water, days of
hydric stress, drought intensity / onset) from the **BILJOU** model
(`biljouR`, INRAE lineage), forced by SAFRAN (primary) or ERA5-Land
(fallback) — decision §10.2. Feeds
[`indicateur_r3_secheresse`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md)
(via its `biljou` argument) and
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md).

## Usage

``` r
regen_bilan_hydrique(
  units,
  meteo = NULL,
  sol = NULL,
  lai_max = NULL,
  forest_type = "feuillu",
  years = NULL,
  precomputed = NULL,
  progress_callback = NULL,
  ...
)
```

## Arguments

- units:

  An `sf` of management units (UGF).

- meteo:

  SAFRAN/ERA5 forcing for the engine path: a single `meteo` `data.frame`
  (applied to every unit) or a named list keyed by unit id.

- sol:

  A
  [`biljouR::biljou_soil()`](https://pobsteta.github.io/biljouR/reference/biljou_soil.html)
  object (extractable water `ewm`, root fractions `roots`, …).

- lai_max:

  Per-unit maximum LAI (e.g. derived from
  [`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)):
  a scalar, a length-`nrow(units)` vector, or a named list by id.

- forest_type:

  Phenology: `"feuillu"`/`"broadleaved"` or `"resineux"`/`"coniferous"`
  (mapped to BILJOU's `broadleaved`/`coniferous`).

- years:

  Optional integer years to keep from the BILJOU indices before
  averaging (default: all years in the run).

- precomputed:

  Optional per-unit BILJOU output (`data.frame`/list with any of
  `njstress`, `istress`, `rew_min`, `deb_stress`). Pure fast-path.

- progress_callback:

  Optional function called at each step with a
  `list(current = <key>, …)` payload (monitoring pattern). Keys:
  `"regen_biljou:start"` (`n` points) and `"regen_biljou:complete"`.
  No-op when `NULL`; never fatal. The per-point loop is internal to
  `biljouR`.

- ...:

  Passed to
  [`biljouR::biljou_run()`](https://pobsteta.github.io/biljouR/reference/biljou_run.html)
  (e.g. `budburst`, `leaf_fall`, `rew_c`, `k`).

## Value

`units` with the water-balance columns `njstress`, `istress`, `rew_min`,
`deb_stress` (per-unit mean over the retained years).

## Details

**Two paths.** *Fast-path*: pass `precomputed` (the per-unit output of a
BILJOU run) and the metrics are attached to `units` as the §7 columns,
**without** the GPL engine. *Engine path*: builds unit-centroid points,
runs
[`biljouR::biljou_run_grid()`](https://pobsteta.github.io/biljouR/reference/biljou_run_grid.html)
(per-point BILJOU forced by `meteo`), and aggregates the per-year
drought indices to the mean per unit — mapping
`NJstress`/`Istress`/`DEBstress`/`min_rew` to
`njstress`/`istress`/`deb_stress`/`rew_min`. It needs `meteo`, a soil
(`sol`) and per-unit `lai_max`; with SAFRAN/LiDAR inputs it is **not
runnable in CI** — validated on real data.

## See also

[`indicateur_r3_secheresse`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md),
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)
