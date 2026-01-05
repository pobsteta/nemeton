# Identify Multi-Criteria Hotspots

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
  Default: 80 (top 20

  min_familiesMinimum number of families in which a parcel must rank
  above threshold to be classified as a hotspot. Default: 3

sf object with original data plus three new columns: -
\`hotspot_count\`: Number of families where parcel ranks above
threshold - \`hotspot_families\`: Comma-separated list of family names
above threshold - \`is_hotspot\`: Logical indicating if parcel meets
min_families criterion Identifies parcels ranking in the top percentile
across multiple ecosystem service families, revealing areas with
exceptional multi-functional value. The function identifies
multi-criteria hotspots by: 1. Computing percentile thresholds for each
family index 2. Counting how many families each parcel ranks above
threshold 3. Flagging parcels exceeding \`min_families\` as
hotspots\*\*Use cases\*\*: - Conservation prioritization (high
biodiversity + age + connectivity) - Risk mitigation (high vulnerability
across fire + storm + drought) - Multi-objective optimization (balancing
competing services) Bilingual SupportThis function supports bilingual
messages via \`nemeton_set_language()\`.

\[compute_family_correlations()\], \[plot_correlation_matrix()\]Other
analysis:
[`compute_family_correlations()`](https://pobsteta.github.io/nemeton/reference/compute_family_correlations.md)
analysis
