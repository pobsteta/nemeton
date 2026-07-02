# Regeneration priority index (spec 027 L3)

Cross the **microclimate exposure** (microclimf engine) and the **soil
water stress** (biljouR engine) of each management unit into a single
0-100 **regeneration priority** — high = the most vulnerable parcels, to
prioritise for adaptation / regeneration (ADR-014, spec 027 v2.1). This
is a head-of-tab score, **not** a radar axis.

## Usage

``` r
indice_priorite_regen(
  units,
  species = NULL,
  weights = NULL,
  tolerances = NULL,
  flag_breaks = .REGEN_FLAG_BREAKS,
  ...
)
```

## Arguments

- units:

  An `sf` carrying the exposure and/or water-stress columns.

- species:

  Optional target-species code
  ([`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)).
  `NULL` (default) → generic index, no species tuning.

- weights:

  Optional named numeric `c(exposition=, hydrique=)` to override the
  equal weighting of the two volets.

- tolerances:

  Optional override of the tolerance thresholds (a `data.frame` like
  [`regeneration_tolerances`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md),
  or a single-species list `list(tmax_tol_c=, vpd_tol_kpa=)`).

- flag_breaks:

  Numeric `c(sensible=, priorite=)` thresholds for the boolean flags
  (default `c(50, 50)`).

- ...:

  Unused.

## Value

`units` with `indice_priorite_regen` (0-100), `regen_exposition` and
`regen_hydrique` (the two 0-100 sub-scores), `parcelle_sensible` and
`priorite` (logical flags, §7), and `regen_essence` (species used or
`"generique"`). `couverture_pct`, if present, is preserved.

## Details

The function **consumes** the engine output columns already on `units`
(the §7 contract): exposure from `sensibilite` (0-100) — or derived from
`d_tmax`/`d_vpd` — and water stress from `njstress` / `istress` /
`rew_min`. Each volet is a renormalised mean over the columns present,
so a partially populated `units` still yields a score.

By default the index is **generic** (no species). Passing `species`
enables the **optional** per-species tuning (decision §10.1): where the
raw summer heat / dryness exceeds the species tolerance
([`regeneration_tolerances`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)),
the priority is pushed up (an intolerant species on a hot, dry microsite
is more urgent).

## See also

[`regeneration_tolerances`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md),
[`indicateur_r6_sensibilite`](https://pobsteta.github.io/nemeton/reference/indicateur_r6_sensibilite.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  units <- regen_sensibilite(units, ...)      # microclimf -> sensibilite
  units <- regen_bilan_hydrique(units, ...)   # biljouR   -> njstress, rew_min
  units <- indice_priorite_regen(units)
} # }
```
