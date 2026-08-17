# Can R5 dieback be computed here, and by which method?

Answers, **before** any FORDEAD or RECONFORT run, whether the dieback
indicator applies to a set of forest units — and if not, which of the
two independent conditions fails. Mirrors the routing that
[`indicateur_r5_deperissement`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md)
performs at compute time, so a caller can tell the user up front instead
of showing an empty indicator after a long run.

## Usage

``` r
r5_applicabilite(
  units,
  bdforet = NULL,
  layers = NULL,
  resineux_col = NULL,
  feuillus_col = NULL,
  min_resineux = 0.3,
  min_feuillus = 0.3,
  threshold_geo = 0.5
)
```

## Arguments

- units:

  An sf object with the forest units.

- bdforet:

  An sf of BD Foret V2 polygons, used to derive the dominant species
  when `units` carries no species column. Optional.

- layers:

  A nemeton_layers object. Used to resolve `bdforet` when it is not
  passed directly. Optional.

- resineux_col, feuillus_col:

  Character. Columns holding a 0-1 conifer / broadleaf share, bypassing
  species derivation. Optional.

- min_resineux, min_feuillus:

  Numeric in `[0, 1]`. Minimum share for a unit to route to FORDEAD /
  RECONFORT. Defaults 0.3, as in
  [`indicateur_r5_deperissement`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md).

- threshold_geo:

  Numeric in `[0, 1]`. Share of the units' extent that must fall inside
  the calibration zone. Default 0.5.

## Value

A list with:

- `status`: one of `"eligible_fordead"`,
  `"eligible_fordead_out_of_calibration"`, `"eligible_reconfort"`,
  `"no_species"`, `"not_applicable"`. A **stable key**, meant to be
  translated downstream.

- `method`: `"fordead"`, `"reconfort"` or `NA`.

- `in_calibration`: logical, `NA` on the RECONFORT route.

- `geo_pct`, `dept_codes`: extent share inside the calibration zone, and
  the departments met.

- `resineux_pct`, `feuillus_pct`: share of units routed to each method.

- `n_units`, `n_fordead`, `n_reconfort`.

- `per_unit`: data.frame (`share_resineux`, `share_feuillus`, `method`)
  — the routing is per unit, a mixed massif is not an all-or-nothing
  verdict.

## Details

Two conditions, deliberately reported apart:

- **species** — Norway spruce / silver fir route to FORDEAD, oak /
  chestnut / Scots pine route to RECONFORT (same helpers the indicator
  uses). Without a species column, BD Foret V2 is used as a fallback.

- **calibration** — the FORDEAD route was validated on five departments
  only (see
  [`FORDEAD_VALIDITY_DEPARTMENTS`](https://pobsteta.github.io/nemeton/reference/FORDEAD_VALIDITY_DEPARTMENTS.md),
  ONF/DSF 2024). Outside them the computation still runs, but its
  confidence classes are extrapolated.

The distinction matters: a silver fir stand in the Ardennes is still a
silver fir stand. Reporting "out of calibration" is not the same as
reporting "wrong species", and conflating the two either hides a real
limit or discards a usable signal. RECONFORT has no published validity
zone, so `in_calibration` is `NA` on that route.

## See also

[`check_fordead_validity`](https://pobsteta.github.io/nemeton/reference/check_fordead_validity.md),
[`indicateur_r5_deperissement`](https://pobsteta.github.io/nemeton/reference/indicateur_r5_deperissement.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ap <- r5_applicabilite(units, bdforet = bdforet)
if (ap$status == "eligible_fordead_out_of_calibration") {
  message("Espece correcte, hors des 5 departements de calibration ONF/DSF")
}
} # }
```
