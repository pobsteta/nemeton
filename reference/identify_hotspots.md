# Identify Multi-Criteria Hotspots

Identifies parcels ranking in the top percentile across multiple
ecosystem service families, revealing areas with exceptional
multi-functional value.

## Usage

``` r
identify_hotspots(units, families = NULL, threshold = 80, min_families = 3)
```

## Arguments

- units:

  sf object with computed family indices (family\_\*)

- families:

  Character vector of family column names to analyze. If NULL (default),
  uses all columns starting with "family\_"

- threshold:

  Numeric percentile threshold (0-100) for defining "high" values.
  Default: 80 (top 20 percent)

- min_families:

  Minimum number of families in which a parcel must rank above threshold
  to be classified as a hotspot. Default: 3

## Value

sf object with original data plus three new columns: hotspot_count
(number of families where parcel ranks above threshold),
hotspot_families (comma-separated list of family names above threshold),
is_hotspot (logical indicating if parcel meets min_families criterion)

## Details

The function identifies multi-criteria hotspots by: 1. Computing
percentile thresholds for each family index 2. Counting how many
families each parcel ranks above threshold 3. Flagging parcels exceeding
\`min_families\` as hotspots

\*\*Use cases\*\*: - Conservation prioritization (high biodiversity +
age + connectivity) - Risk mitigation (high vulnerability across fire +
storm + drought) - Multi-objective optimization (balancing competing
services)

## Bilingual Support

This function supports bilingual messages via
\`nemeton_set_language()\`.

## See also

\[compute_family_correlations()\], \[plot_correlation_matrix()\]

Other analysis:
[`compute_family_correlations()`](https://pobsteta.github.io/nemeton/reference/compute_family_correlations.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Load demo data with family indices
data(massif_demo_units)
units <- massif_demo_units
units$family_B <- runif(nrow(units), 30, 90)
units$family_T <- runif(nrow(units), 40, 85)
units$family_C <- runif(nrow(units), 45, 80)
units$family_W <- runif(nrow(units), 35, 75)

# Identify hotspots: top 20\% in at least 3 families
hotspots <- identify_hotspots(
  units,
  threshold = 80,
  min_families = 3
)

# View hotspot parcels
hotspot_parcels <- hotspots[hotspots$is_hotspot, ]
print(hotspot_parcels[, c("parcel_id", "hotspot_count", "hotspot_families")])

# Conservative threshold: top 10\% in 4+ families
elite_hotspots <- identify_hotspots(
  units,
  threshold = 90,
  min_families = 4
)

# Analyze specific families only
biodiversity_hotspots <- identify_hotspots(
  units,
  families = c("family_B", "family_T"),
  threshold = 75,
  min_families = 2
)
} # }
```
