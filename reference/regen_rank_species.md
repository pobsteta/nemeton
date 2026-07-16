# Rank the top-N regeneration species per management unit

Deterministic ecological suitability ranking of tree species for
regeneration, per management unit (UGF). For each `(unit × species)` it
aggregates up to three 0-100 sub-scores (high = well suited) and returns
the `top_n` species per unit (spec 039). This is the **deterministic
core**; an LLM narrative layer lives in the app (phase 2).

Axes:

- **Heat & dryness** — summer T°max (`tmax_moyenne + d_tmax`) and VPD
  (`vpd_canicule`) against the species tolerances (`tmax_tol_c`,
  `vpd_tol_kpa`), plus edaphic dryness (`rew_min`) against
  `drought_tol`. Liebig's law of the minimum caps the axis at the worst
  stress (reuses
  [`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)'s
  thresholds `.REGEN_TOL_SPAN`).

- **Late frost** — station frost pressure (`R7`, else `r7_gel_days`)
  crossed with the species `frost_late` sensitivity, so the axis
  **differentiates** species (an early-flushing beech is penalised on a
  frost-prone site, a late-flushing oak is not).

- **Shade** *(optional)* — per-unit canopy density (`cover_col`, or
  `lai_col` converted with a Beer-Lambert `1 - exp(-k·LAI)`) crossed
  with `shade_tol`. When no density input is supplied the axis is
  omitted (the score renormalises over the present axes) and `shade_tol`
  breaks ranking ties instead.

## Usage

``` r
regen_rank_species(
  units,
  species_pool = NULL,
  top_n = 3,
  weights = NULL,
  exclude_invasive = TRUE,
  region = "BFC",
  cover_col = NULL,
  lai_col = NULL,
  extinction_k = .REGEN_RANK_K,
  id_col = "ug_id",
  include_atlas = FALSE,
  ...
)
```

## Arguments

- units:

  An `sf` carrying the station columns produced by the regeneration
  engines (`tmax_moyenne`, `d_tmax`, `vpd_canicule`, `rew_min`, and `R7`
  or `r7_gel_days` for the frost axis).

- species_pool:

  `NULL` (default →
  [`regen_species_choices`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md)
  for `units`), a character vector of species codes, or a `data.frame`
  of candidate traits. Missing trait columns (e.g. `frost_late`) are
  joined from
  [`european_species_tolerances`](https://pobsteta.github.io/nemeton/reference/european_species_tolerances.md)
  by `code`.

- top_n:

  Number of species to keep per unit (default 3).

- weights:

  Optional named numeric overriding the axis weights
  `c(chaleur_secheresse=, gel=, ombre=)` (default `c(0.5, 0.3, 0.2)`,
  renormalised over the axes actually present).

- exclude_invasive:

  Drop species flagged `invasif` (default `TRUE`).

- region:

  Region passed to
  [`regen_species_choices`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md)
  when building the default pool.

- cover_col, lai_col:

  Optional column of `units` giving the per-unit residual canopy density
  — a cover fraction (`cover_col`, 0-1, or 0-100 auto-rescaled) or a
  leaf/plant area index (`lai_col`, converted with Beer-Lambert).
  `lai_col` takes precedence. Both `NULL` → shade axis omitted.

- extinction_k:

  Beer-Lambert extinction coefficient for `lai_col` (default 0.5).

- id_col:

  Unit id column (default `"ug_id"`; falls back to the row index).

- include_atlas:

  Also list the JRC-Atlas species in the default pool (default `FALSE`).

- ...:

  Reserved.

## Value

A long `data.frame`, one row per `(unit × rank)`: `ug_id`, `rank`,
`species_code`, `label`, `type`, `suitability` (0-100),
`limiting_factor` (`"chaleur"`/`"secheresse"`/`"gel"`/`"ombre"`, or `NA`
when unconstrained), `confidence`, `invasif`. Units with no station data
yield a single `rank = NA` row (no fabricated recommendation). An empty
pool yields a 0-row frame. The chosen axis weights are attached as
`attr(, "weights")`.

## See also

[`regen_rank_to_wide`](https://pobsteta.github.io/nemeton/reference/regen_rank_to_wide.md),
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md),
[`regen_species_choices`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md),
[`european_species_tolerances`](https://pobsteta.github.io/nemeton/reference/european_species_tolerances.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  units <- indice_priorite_regen(units)          # station columns present
  ranked <- regen_rank_species(units, top_n = 3, lai_col = "lai_max")
  regen_rank_to_wide(ranked, top_n = 3)
} # }
```
