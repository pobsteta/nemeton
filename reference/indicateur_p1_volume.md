# P1: Standing Timber Volume Indicator

Calculates standing timber volume (m3/ha) using IFN allometric equations
based on species, diameter (DBH), and height data.

## Usage

``` r
indicateur_p1_volume(
  units,
  species_field = "species",
  dbh_field = "dbh",
  height_field = "height",
  density_field = "density",
  method = c("ifn_tarif", "allometric"),
  column_name = "P1",
  lang = "en",
  chm = NULL,
  h_dom_percentile = 0.9,
  pct_masked = NULL,
  use_climate_drift = FALSE
)
```

## Arguments

- units:

  sf object (POLYGON) of spatial units to assess

- species_field:

  Character. Column name containing species codes (IFN format). Default
  "species".

- dbh_field:

  Character. Column name containing diameter at breast height (cm).
  Default "dbh".

- height_field:

  Character. Column name containing tree height (m). Optional, can be
  estimated.

- density_field:

  Character. Column name containing tree density (stems/ha). Default
  "density".

- method:

  Character. Volume calculation method. Only "ifn_tarif" (the IFN
  combined-variable tariff `V = a x D^2 x H`) is implemented;
  "allometric" is accepted for backward compatibility but has no effect
  and emits a warning. Default "ifn_tarif".

- column_name:

  Character. Name for output column. Default "P1".

- lang:

  Character. Message language. Default "en".

- chm:

  Optional `SpatRaster` of canopy heights in metres. When supplied,
  activates CHM mode (spec 005 phase 3). Heights are taken from the CHM
  (per-unit 90th percentile) instead of `height_field` or the Näslund
  approximation.

- h_dom_percentile:

  Numeric in `[0, 1]`. Percentile of CHM pixels used to derive dominant
  height per unit. Default `0.9`. Ignored when `chm` is `NULL`.

- pct_masked:

  Numeric in `[0, 1]` or `NULL`. Optionally, the fraction of the CHM
  that was masked by
  [`sanitize_chm`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md)
  upstream. When supplied and greater than `0.3`, a warning is emitted:
  a heavily-masked CHM is unreliable for volume estimation.

- use_climate_drift:

  Logical. When `TRUE`, the estimated volume is scaled by the
  per-species climate-driven BAI drift factor (Charru et al. 2017, see
  [`charru_bai_drift`](https://pobsteta.github.io/nemeton/reference/charru_bai_drift.md)).
  Default `FALSE` (raw synthetic-inventory volume).

## Value

sf object with added column: P1 (standing volume in m3/ha)

## Details

In CHM mode (spec 005 phase 3), the height fed to the IFN tarif is the
dominant height extracted from a Canopy Height Model (see
[`extract_h_dom`](https://pobsteta.github.io/nemeton/reference/extract_h_dom.md))
rather than the rough Näslund approximation used by default when
`height` is absent. This typically improves the P1 RMSE by 20 to 40 %.

\*\*Calculation\*\* (IFN tarif method):

- Lookup species-specific IFN equation: `V = a x DBH^b x H^c`

- Calculate individual tree volume

- Scale by tree density: `P1 = V_individual x density_stems_ha`

\*\*Height source priority\*\*:

1.  `chm` (CHM mode), when supplied;

2.  `height_field` column in `units`, if present;

3.  Näslund approximation `H = 1.3 + 0.65 * DBH` as a last-resort
    fallback.

\*\*Species Fallback\*\*: If species code not found in IFN tables, uses
genus-level equations — `BROADLEAF_GENUS` for non-conifers,
`CONIFER_GENUS` for conifers (see internal
[`is_conifer()`](https://pobsteta.github.io/nemeton/reference/is_conifer.md)).

\*\*Data Requirements\*\*:

- species: IFN species code (e.g., "FASY", "QUPE", "PIAB")

- dbh: Diameter at breast height (1.3m) in cm

- height: Tree height in meters (can be estimated from DBH if missing)

- density: Number of stems per hectare

## Examples

``` r
if (FALSE) { # \dontrun{
# With species and biometric data
units$species <- c("FASY", "QUPE", "PIAB")
units$dbh <- c(35, 42, 28)
units$height <- c(25, 30, 22)
units$density <- c(250, 180, 320)

result <- indicateur_p1_volume(
  units = units,
  species_field = "species",
  dbh_field = "dbh",
  height_field = "height",
  density_field = "density"
)
} # }
```
