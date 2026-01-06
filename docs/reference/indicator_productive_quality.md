# P3: Timber Quality Score Indicator

Calculates a timber quality score (0-100) based on tree form
(straightness), commercial diameter thresholds, and defect presence.

## Usage

``` r
indicator_productive_quality(
  units,
  dbh_field = "dbh",
  form_score_field = "form_score",
  defects_field = "defects",
  species_field = "species",
  weights = c(form = 0.4, diameter = 0.4, defects = 0.2),
  column_name = "P3",
  lang = "en"
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

- column_name:

  Character. Name for output column. Default "P3".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added column: P3 (timber quality score 0-100)

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

## Examples

``` r
if (FALSE) { # \dontrun{
units$dbh <- c(45, 28, 35)
units$species <- c("FASY", "PIAB", "QUPE")
units$form_score <- c(85, 70, 60)
units$defects <- c(0, 0, 1)

result <- indicator_productive_quality(
  units = units,
  dbh_field = "dbh",
  form_score_field = "form_score",
  defects_field = "defects"
)
} # }
```
