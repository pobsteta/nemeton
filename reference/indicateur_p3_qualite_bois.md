# P3: Timber Quality Score Indicator

Calculates a timber quality score (0-100) based on tree form
(straightness), commercial diameter thresholds, and defect presence.

## Usage

``` r
indicateur_p3_qualite_bois(
  units,
  dbh_field = "dbh",
  form_score_field = "form_score",
  defects_field = "defects",
  species_field = "species",
  weights = c(form = 0.4, diameter = 0.4, defects = 0.2),
  chm = NULL
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- dbh_field:

  Character. Column name containing diameter at breast height (cm).
  Default "dbh".

- form_score_field:

  Character. Column name containing form quality score (0-100).
  Optional.

- defects_field:

  Character. Column name containing defect indicator (0=none,
  1=present). Optional.

- species_field:

  Character. Column name containing species codes (for diameter
  thresholds). Default "species".

- weights:

  Named numeric vector. Component weights: c(form = 0.4, diameter = 0.4,
  defects = 0.2). Default balanced.

- chm:

  Optional \`terra::SpatRaster\` canopy height model (spec 005). Passed
  to \`ensure_inventory_fields()\` to auto-fill \`dbh\` from the CHM
  when the diameter field is missing. Default \`NULL\`.

## Value

sf object with added columns: P3 (timber quality score 0-100) and
`p3_status`, which tells which components were measured:
`"diametre_seul"`, `"diametre_forme"`, `"diametre_defauts"` or
`"complet"` (NA when P3 is NA).

**Higher = better timber = favourable.** P3 is a weighted mean of the
components that are each already 0-100 and each already oriented that
way (diameter against commercial thresholds, stem form, a defects
penalty), so the composite is 0-100 by construction and
[`normalize_indicator()`](https://pobsteta.github.io/nemeton/reference/normalize_indicator.md)
passes it through (spec 048 section 12).

Only MEASURED components enter the mean, their weights rescaled to sum
to 1. Form and defects are used when the unit carries a non-missing
value in `form_score_field` / `defects_field` (field data, e.g. QField);
there is no default score any more. Before 1.0.0 a missing form counted
70 and missing defects 85, i.e. 45 constant points out of 100 on every
unit without field data (spec 056): P3 is now the diameter score alone
there (`p3_status = "diametre_seul"`).

## Details

\*\*Calculation\*\*:

- Form score (0-100): Straightness and branching quality

- Diameter score (0-100): Proximity to commercial thresholds -
  Broadleaf: 40cm (sawlog), 20cm (pulpwood) - Conifer: 30cm (sawlog),
  15cm (pulpwood)

- Defect penalty: 100 = no defects, 0 = severe defects

- P3 = weighted average of components

\*\*Quality Classes\*\*:

- 80-100: Premium quality (sawlog, veneer)

- 60-80: Good quality (construction timber)

- 40-60: Average quality (general use)

- 20-40: Low quality (pulpwood, biomass)

- 0-20: Very low quality (firewood only)

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
if (FALSE) { # \dontrun{
units$dbh <- c(45, 28, 35)
units$species <- c("FASY", "PIAB", "QUPE")
units$form_score <- c(85, 70, 60)
units$defects <- c(0, 0, 1)

result <- indicateur_p3_qualite_bois(
  units = units,
  dbh_field = "dbh",
  form_score_field = "form_score",
  defects_field = "defects"
)
} # }
```
