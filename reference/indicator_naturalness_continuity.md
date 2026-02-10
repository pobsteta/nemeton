# N2: Forest Continuity Indicator

Calculates forest continuity using BD Foret (current forest cover) and
optionally BD Foret Anciennes (historical forest from ~1850). Follows
tuto 04: - Ancient forest (\>0 - Recent forest (current cover but not
ancient): score = 30 + 30 \* taux_boisement - No forest: score = 15

## Usage

``` r
indicator_naturalness_continuity(
  units,
  bdforet = NULL,
  foret_ancienne = NULL,
  layers = NULL,
  column_name = "N2",
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

  sf object. Historical forest cover (~1850). NULL = only use bdforet.

- layers:

  nemeton_layers object. Used to resolve bdforet if not provided
  directly.

- column_name:

  Character. Name for output column. Default "N2".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added column N2 (score 0-100)
