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
  precomputed = NULL,
  ...
)
```

## Arguments

- units:

  An `sf` of management units (UGF).

- meteo:

  Optional SAFRAN/ERA5 forcing (for the engine path).

- sol:

  Optional soil description (`biljou_soil()` inputs: extractable water
  `ewm`, root fractions `roots`).

- lai_max:

  Optional per-unit maximum LAI (from
  [`pai_depuis_nuage()`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)).

- forest_type:

  Character, `"feuillu"` / `"resineux"` (phenology).

- precomputed:

  Optional per-unit BILJOU output (`data.frame`/list with any of
  `njstress`, `istress`, `rew_min`, `deb_stress`). Pure fast-path.

- ...:

  Reserved (engine parameters).

## Value

`units` with the water-balance columns present in `precomputed`
(`njstress`, `istress`, `rew_min`, `deb_stress`).

## Details

**Scaffold with a pure fast-path**: pass `precomputed` (the per-unit
output of a BILJOU run) and the metrics are attached to `units` as the
§7 columns, **without** the GPL engine. Without `precomputed`, the full
`biljouR` orchestration is not yet wired; the function fails cleanly.

## See also

[`indicateur_r3_secheresse`](https://pobsteta.github.io/nemeton/reference/indicateur_r3_secheresse.md),
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)
