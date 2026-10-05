# Calculate Protected Area Coverage (B1)

Computes the percentage of each forest parcel covered by designated
protected areas (ZNIEFF, Natura2000, National/Regional Parks).

## Usage

``` r
indicateur_b1_protection(
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

  An sf object with protected area polygons (for instance the
  `protected_areas` layer of the data catalog). `NULL` gives NA.

- source:

  Kept for backward compatibility; has no effect. `"wfs"` does not fetch
  anything: this function never queries the INPN WFS, and the protected
  areas must be supplied through `protected_areas`.

- protection_types:

  Kept for backward compatibility; has no effect (all the features of
  `protected_areas` are used).

- preprocess:

  Logical. If TRUE, harmonize CRS automatically. Default TRUE.

## Value

The input sf object with added columns:

- B1: protection score (0-100)

- B1_pct: weighted protected coverage of the parcel (0-100)

- B1_nb: number of distinct protection statuses intersecting the parcel

## Details

\*\*Calculation\*\*: with a protection-type column (`type_protection`,
`zone_type`, `type` or `statut`), B1 = 0.7 \* B1_pct + 0.3 \* min(B1_nb,
4) / 4 \* 100, where B1_pct is the coverage of each status averaged with
weights by protection strength (strong 1.0, medium 0.6, weak 0.3,
unknown 0.5). The number of statuses is scaled by a fixed bound of 4
stacked statuses (ZNIEFF 1 + ZNIEFF 2 + Natura 2000 + park/reserve), so
the score of a parcel does not depend on the other parcels of the batch.
Without a type column, B1 = B1_pct (plain coverage; the number of
statuses is unknown).

A NULL `protected_areas` gives NA (no measurement; the `"wfs"` source is
not fetched by this function); an empty `protected_areas` gives 0.

\*\*Interpretation\*\*: Higher values indicate better protection status.

## See also

Other biodiversity-indicators:
[`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md),
[`indicateur_b3_connectivite()`](https://pobsteta.github.io/nemeton/reference/indicateur_b3_connectivite.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(nemeton)
library(sf)

# Load demo data
data(massif_demo_units)

# Protected areas supplied by the caller (e.g. the catalog layer)
protected_zones <- st_read("path/to/protected_areas.shp")
result <- indicateur_b1_protection(
  massif_demo_units,
  protected_areas = protected_zones
)

# View results
summary(result$B1)
} # }
```
