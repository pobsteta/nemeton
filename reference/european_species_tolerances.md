# European tree-species regeneration tolerances

Reference table of restocking tolerances for ~193 European tree species,
calibrated per species (spec 027). Complements the broad 11-class
[`regeneration_tolerances`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md)
(kept for the UGF-class mapping) with the same
`tmax_tol_c`/`vpd_tol_kpa` axes plus richer autecology: Niinemets &
Valladares (2006) drought / shade / waterlogging tolerances (1–5),
winter cold and frost, air-humidity affinity and thermophily (1–9).

## Usage

``` r
european_species_tolerances(statut = NULL, confiance = NULL, type = NULL,
  include_invasif = TRUE)
```

## Arguments

- statut:

  Optional character vector filter on `statut`. The convenience value
  `"frm"` expands to both `"frm_1999"` and `"frm_2025"` (the regulatory
  FRM species).

- confiance:

  Optional filter on `confidence` (`"eleve"`/`"moyen"`/`"faible"`).

- type:

  Optional filter on `type` (`"conifere"`/`"feuillu"`).

- include_invasif:

  Logical; keep INTRO/INVASIVE taxa. Default `TRUE`.

## Value

A data.frame with `code`, `species_sci`, `species_fr`, `type`, `statut`,
`tmax_tol_c`, `vpd_tol_kpa`, `drought_tol`, `shade_tol`, `waterlog_tol`,
`frost_winter_min_c`, `frost_late`, `frost_early`, `air_humidity`,
`thermophily`, `confidence`, `invasif`, `notes`.

## Details

Three stacked scopes in `statut`: `"frm_1999"` (Directive 1999/105/EC
Annex I in force, 47), `"frm_2025"` (additions of the forthcoming FRM
regulation, political agreement 2025-12-08, 17) and `"atlas_jrc"`
(European Atlas of Forest Tree Species dendroflora outside the FRM list,
~130, **rule-derived draft** — validate before operational use). The
`confidence` column (`"eleve"`/`"moyen"`/`"faible"`) grades reliability;
`invasif` flags INTRO/INVASIVE taxa (listed for completeness —
**presence is not a recommendation**).

## References

European Atlas of Forest Tree Species (San-Miguel-Ayanz et al. 2016);
Caudullo, Welk & San-Miguel-Ayanz (2017); Niinemets & Valladares (2006);
Directive 1999/105/EC. See `inst/REFERENCES.md`.

## See also

[`regeneration_tolerances`](https://pobsteta.github.io/nemeton/reference/regeneration_tolerances.md),
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md),
[`regen_species_choices`](https://pobsteta.github.io/nemeton/reference/regen_species_choices.md)
