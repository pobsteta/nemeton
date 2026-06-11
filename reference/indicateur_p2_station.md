# P2: Site Productivity Index Indicator

Calculates a site productivity index in one of two modes:

1.  **CHM mode** (spec 005 phase 2) — when a Canopy Height Model is
    supplied via `chm`, the function extracts a dominant height per unit
    and converts it into a site index \\H_0\\ at `reference_age` using
    [`compute_site_index`](https://pobsteta.github.io/nemeton/reference/compute_site_index.md).
    The output is a dominant height in metres.

2.  **Legacy mode** — when `chm` is `NULL` (default, preserves
    pre-spec-005 behaviour), the function combines soil fertility,
    climate suitability and species-specific growth potential using
    reference productivity tables. The output is an annual increment in
    \\m^3/ha/yr\\.

## Usage

``` r
indicateur_p2_station(
  units,
  species_field = "species",
  fertility_field = "fertility",
  climate_field = "climate",
  productivity_table = NULL,
  column_name = "P2",
  lang = "en",
  chm = NULL,
  age_field = "age",
  reference_age = 50,
  h_dom_percentile = 0.9
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- species_field:

  Character. Column name containing species codes. Default "species".

- fertility_field:

  Character. Column name containing fertility class (1=high, 2=medium,
  3=low). Default "fertility".

- climate_field:

  Character. Column name containing climate zone. Default "climate".

- productivity_table:

  Data.frame. Custom productivity reference table. If NULL, uses bundled
  ONF/IFN tables.

- column_name:

  Character. Name for output column. Default "P2".

- lang:

  Character. Message language. Default "en".

- chm:

  Optional `SpatRaster` of canopy heights in metres. When supplied,
  activates CHM mode (spec 005 phase 2). Typically the `chm_clean`
  component returned by
  [`sanitize_chm`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md).

- age_field:

  Character. Column name containing stand age (years). Used in CHM mode.
  Default `"age"`.

- reference_age:

  Numeric. Reference age at which the site index is returned in CHM
  mode. Default `50`.

- h_dom_percentile:

  Numeric in `[0, 1]`. Percentile of CHM pixels used to derive dominant
  height per unit. Default `0.9`.

## Value

sf object with one added column:

- Legacy mode: `P2` = annual increment (m3/ha/yr).

- CHM mode: `P2` = site index \\H_0\\ (m) at `reference_age`.

## Details

The two modes answer the same forestry question (how productive is this
site?) but in different units. Downstream callers should use
[`compute_general_index_mixed`](https://pobsteta.github.io/nemeton/reference/compute_general_index_mixed.md)
or a mode-aware normalization when mixing units.

\*\*Calculation\*\*:

- Lookup reference productivity from ONF/IFN tables

- Match by species x fertility class x climate zone

- P2 = annual increment (m3/ha/year) for the site

\*\*Fertility Classes\*\*:

- 1: High fertility (rich soils, optimal drainage)

- 2: Medium fertility (average conditions)

- 3: Low fertility (poor soils, constraints)

\*\*Climate Zones\*\*:

- temperate_oceanic: Atlantic climate (Brittany, Normandy)

- temperate_continental: Continental (Lorraine, Burgundy)

- mountainous: Mountain zones (Alps, Pyrenees, Massif Central)

- atlantic: Southwest Atlantic (Landes, Gironde)

- mediterranean: Mediterranean (Provence, Languedoc)

## Examples

``` r
if (FALSE) { # \dontrun{
units$species <- c("FASY", "PIAB", "QUPE")
units$fertility <- c(1, 2, 2)
units$climate <- c("temperate_oceanic", "mountainous", "temperate_oceanic")

result <- indicateur_p2_station(
  units = units,
  species_field = "species",
  fertility_field = "fertility",
  climate_field = "climate"
)
} # }
```
