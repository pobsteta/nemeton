# Compute an area-weighted CV from a BD Forêt v2 coverage

For each polygon in `bdforet_sf`, look up the generic forest context
(via
[`bdforet_v2_mapping`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md))
and read the CV at the requested `position`. The final CV is the
arithmetic mean of the per-polygon CVs, weighted by the polygon area
(intersected with `aoi` when provided). Polygons mapped to `NA`
(non-forest, coupe rase, lande) are dropped.

## Usage

``` r
cv_from_bdforet(
  bdforet_sf,
  position = c("mid", "low", "high"),
  aoi = NULL,
  tfv_col = "TFV",
  mapping = NULL,
  typology = NULL
)
```

## Arguments

- bdforet_sf:

  sf. Polygons from BD Forêt v2 with a TFV code column (see `tfv_col`).

- position:

  Character. CV bound to read (`"mid"`, `"low"`, `"high"`).

- aoi:

  Optional sf polygon. When provided, polygons are intersected with it
  before area weighting.

- tfv_col:

  Character. Column name holding the TFV code. Default `"TFV"`.

- mapping:

  Optional override of the BD Forêt mapping (same columns as
  [`bdforet_v2_mapping()`](https://pobsteta.github.io/nemeton/reference/bdforet_v2_mapping.md)).

- typology:

  Optional override of the typology table (same columns as
  [`cv_typology()`](https://pobsteta.github.io/nemeton/reference/cv_typology.md)).

## Value

A list with:

- `cv`: the aggregated CV (numeric fraction).

- `position`: the bound used.

- `coverage`: total mapped area / total input area (sanity check — how
  much of the AOI was classified).

- `summary`: a per-TFV data.frame (`tfv_code`, `area_ha`, `context_key`,
  `cv`, `share`), sorted by descending area.

- `ambiguous`: data.frame of TFV codes where the mapping is flagged
  ambiguous (the user may want to override via the alt_context_key
  column).

- `unmapped`: TFV codes present in the data but absent from the mapping
  table.
