# Calculate Protected Area Coverage (B1)

Computes the percentage of each forest parcel covered by designated
protected areas (ZNIEFF, Natura2000, National/Regional Parks).

## Usage

``` r
indicator_biodiversity_protection(
  units,
  protected_areas = NULL,
  source = c("local", "wfs"),
  protection_types = c("ZNIEFF1", "ZNIEFF2", "N2000_SCI"),
  preprocess = TRUE
)
```

## Arguments

- units:

  An sf object with forest parcels (POLYGON or MULTIPOLYGON).

- protected_areas:

  An sf object with protected area polygons. If NULL and source="wfs",
  will attempt to fetch from INPN WFS service.

- source:

  Character. Data source: "local" (use protected_areas parameter) or
  "wfs" (fetch from INPN). Default "local".

- protection_types:

  Character vector. Types of protected areas to include when using WFS.
  Default c("ZNIEFF1", "ZNIEFF2", "N2000_SCI").

- preprocess:

  Logical. If TRUE, harmonize CRS automatically. Default TRUE.

## Value

The input sf object with added column:

- B1: Percentage of parcel area in protected zones (0-100)

## Details

\*\*Calculation\*\*: B1 = (area_protected / area_total) × 100

\*\*Interpretation\*\*: Higher values indicate better protection status.
Parcels with B1 \> 75\\

## See also

Other biodiversity-indicators:
[`indicator_biodiversity_connectivity()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_connectivity.md),
[`indicator_biodiversity_structure()`](https://pobsteta.github.io/nemeton/reference/indicator_biodiversity_structure.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(sf)

# Load demo data
data(massif_demo_units)

# Option A: Use local protected area data
protected_zones <- st_read("path/to/protected_areas.shp")
result <- indicator_biodiversity_protection(
  massif_demo_units,
  protected_areas = protected_zones,
  source = "local"
)

# Option B: Fetch from INPN WFS (requires internet)
result <- indicator_biodiversity_protection(
  massif_demo_units,
  source = "wfs",
  protection_types = c("ZNIEFF1", "ZNIEFF2", "N2000_SCI")
)

# View results
summary(result$B1)
} # }
```
