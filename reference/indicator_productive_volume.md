# P1: Standing Timber Volume Indicator

Calculates standing timber volume (m³/ha) using IFN allometric equations
based on species, diameter (DBH), and height data.

## Usage

``` r
indicator_productive_volume(
  units,
  species_field = "species",
  dbh_field = "dbh",
  height_field = "height",
  density_field = "density",
  method = c("ifn_tarif", "allometric"),
  column_name = "P1",
  lang = "en"
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

  Character. Volume calculation method: "ifn_tarif" (IFN tariff) or
  "allometric". Default "ifn_tarif".

- column_name:

  Character. Name for output column. Default "P1".

- lang:

  Character. Message language. Default "en".

## Value

sf object with added column: P1 (standing volume in m³/ha)

## Details

\*\*Calculation\*\* (IFN tarif method):

- Lookup species-specific IFN equation: `V = a × DBH^b × H^c`

- Calculate individual tree volume

- Scale by tree density: `P1 = V_individual × density_stems_ha`

\*\*Species Fallback\*\*: If species code not found in IFN tables, uses
genus-level equations:

- Broadleaf species → BROADLEAF_GENUS equation

- Conifer species → CONIFER_GENUS equation

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

result <- indicator_productive_volume(
  units = units,
  species_field = "species",
  dbh_field = "dbh",
  height_field = "height",
  density_field = "density"
)
} # }
```
