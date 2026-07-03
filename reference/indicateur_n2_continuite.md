# N2: Forest Continuity Indicator

Calculates forest continuity using BD Foret (current forest cover) and
optionally BD Foret Anciennes (historical forest from ~1850). Follows
tuto 04: - Ancient forest (\>0 - Recent forest (current cover but not
ancient): score = 30 + 30 \* taux_boisement - No forest: score = 15

## Usage

``` r
indicateur_n2_continuite(
  units,
  bdforet = NULL,
  foret_ancienne = NULL,
  layers = NULL,
  column_name = "N2",
  weight_anciennete = TRUE,
  lang = "en"
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- bdforet:

  sf object. Current forest cover (BD Foret V2). NULL = default score
  50.

- foret_ancienne:

  sf object. Historical forest cover. A single-epoch layer (e.g.
  état-major ~1850) or a **tiered** layer from
  [`build_foret_ancienne_mask`](https://pobsteta.github.io/nemeton/reference/build_foret_ancienne_mask.md)
  with an `anciennete` column (multi-epoch consolidation, e.g. Cassini +
  état-major). NULL = only use bdforet.

- layers:

  nemeton_layers object. Used to resolve bdforet if not provided
  directly.

- column_name:

  Character. Name for output column. Default "N2".

- weight_anciennete:

  Logical. When `foret_ancienne` carries an `anciennete` tier column,
  weight the ancient-forest coverage by tier depth (forest present at
  more epochs counts more). Ignored for single-epoch layers. Default
  `TRUE`.

- lang:

  Character. Message language. Default "en".

## Value

sf object with added column N2 (score 0-100)
