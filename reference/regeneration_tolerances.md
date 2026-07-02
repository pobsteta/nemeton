# Regeneration tolerance table (per species)

Per-species heat / dryness tolerance thresholds used by the **optional**
species tuning of
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md)
(spec 027 §10.1). Read from `inst/extdata/regeneration_tolerances.csv`.
Values are **indicative** (they order species sensitivity), keyed on
[`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md);
documented, not field-calibrated (spec 027 §9.2).

## Usage

``` r
regeneration_tolerances()
```

## Value

A `data.frame` with columns `code`, `label`, `tmax_tol_c` (max tolerated
under-canopy summer T°max, °C) and `vpd_tol_kpa` (max tolerated summer
VPD, kPa).

## See also

[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md),
[`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
