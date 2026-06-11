# Check whether an AOI lies within the RECONFORT calibration domain

Implements guard-rail G3 (spec 021). An AOI is "valid" for RECONFORT if
(i) it intersects the six Centre-Val de Loire departments by more than
\`threshold_geo\` of its area and (ii) the user-provided forest units
are dominated by the three calibrated species (oak + chestnut + Scots
pine) at more than \`threshold_species\` of their cumulated area.

Unlike \[check_fordead_validity()\], the check is \*\*advisory, not
blocking\*\* (\`advisory = TRUE\` in the result): RECONFORT carries no
hard geographic lock upstream, so the app warns but never prevents the
diagnosis.

## Usage

``` r
check_reconfort_validity(
  aoi,
  units = NULL,
  bdforet = NULL,
  layers = NULL,
  threshold_geo = 0.5,
  threshold_species = 0.7,
  min_target = 0.3
)
```

## Arguments

- aoi:

  An \`sf\` polygon (any CRS); the project area of interest.

- units:

  Optional \`sf\` of forest management units. Must carry a species label
  column (one of \`essence_dominante\`, \`essence\`, \`species_label\`,
  \`species\`, \`essence_principale\`). When \`NULL\`, the species check
  is skipped (\`species_valid = NA\`). When \`units\` has no species
  column, the function falls back to deriving it from BD Forêt V2 if
  either \`bdforet\` or \`layers\` is provided.

- bdforet:

  Optional \`sf\` of BD Forêt V2 polygons (formation végétale layer,
  IGN). Used as a species fallback when \`units\` carries no
  recognisable species column. Each unit's dominant essence is derived
  by area-weighted intersection via \[enrich_parcels_bdforet()\].
  Ignored when \`units\` already carries a species column.

- layers:

  Optional \`nemeton_layers\` object. When \`bdforet\` is \`NULL\`, the
  function attempts to resolve a \`"bdforet"\` vector layer from
  \`layers\` (\`resolve_vector_layer(layers, "bdforet")\`) and uses it
  as the fallback species source.

- threshold_geo:

  Minimum fraction of \`aoi\` area that must fall inside the validity
  zones. Default \`0.5\`.

- threshold_species:

  Minimum fraction of \`units\` area that must be oak + chestnut + Scots
  pine. Default \`0.7\`.

- min_target:

  Minimum per-unit RECONFORT-species share to use the RECONFORT output
  for that unit when routing R5 (\`R/indicators-deperissement.R\`, lot
  L4). Reserved here for API parity — \`check_reconfort_validity()\`
  itself does not filter by it and only echoes it back in the result.

## Value

A list with elements: \* \`geo_valid\` (logical),
\`geo_intersection_pct\` (numeric, fraction of AOI area inside the
validity zones), \`geo_dept_codes\` (character vector of department
codes intersected, possibly empty); \* \`species_valid\` (logical or
\`NA\`), \`species_target_pct\` (combined oak+chestnut+pine share),
\`species_chene_pct\`, \`species_chataignier_pct\`, \`species_pin_pct\`
(numeric or \`NA\`); \* \`overall_valid\` (logical) — \`geo_valid &&
(species_valid \* \`advisory\` (always \`TRUE\`) — the check warns, it
does not block; \* \`thresholds\` (list).
