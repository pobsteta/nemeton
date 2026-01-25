# API Contract: Advanced Analysis Tools

**Category**: Multi-Criteria Decision Analysis
**Feature**: [spec.md](../spec.md) | **Data Model**: [data-model.md](../data-model.md)
**Created**: 2026-01-05

## Overview

This contract defines the API for advanced multi-criteria analysis tools: Pareto optimality detection, clustering, and trade-off visualization. These functions operate on datasets with complete family indices (12 families) to support strategic forest management decisions.

---

## identify_pareto_optimal: Pareto Optimality Detection

### Function Signature

```r
identify_pareto_optimal(
  units,
  families = NULL,
  objectives = c("maximize", "maximize"),
  column_name = "is_pareto_optimal",
  return_dominated = FALSE,
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units with family indices |
| `families` | character vector | No | `NULL` | Family columns to consider (NULL = all family_* columns) |
| `objectives` | character vector | No | All "maximize" | Objective direction per family: "maximize" or "minimize" |
| `column_name` | character | No | `"is_pareto_optimal"` | Name for Pareto flag column |
| `return_dominated` | logical | No | `FALSE` | If TRUE, also add column indicating dominating parcel IDs |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object

**Added Columns**:
- `{column_name}` (logical): TRUE if parcel is Pareto-optimal (non-dominated)
- `dominated_by` (character, if `return_dominated=TRUE`): IDs of dominating parcels (NA if Pareto-optimal)

### Behavior

1. **Family Selection**:
   - If `families = NULL`: Auto-detect all `family_*` columns
   - Otherwise: Use specified families

2. **Pareto Dominance Algorithm**:
   ```r
   # For each pair of parcels (i, j):
   #   i dominates j if:
   #     - i is better or equal on ALL objectives
   #     - i is strictly better on AT LEAST ONE objective

   for i in 1:n_parcels:
     dominated = FALSE
     for j in 1:n_parcels:
       if j != i:
         if all(units[j, families] >= units[i, families]) AND
            any(units[j, families] > units[i, families]):
           dominated = TRUE
           break

     is_pareto[i] = !dominated
   ```

3. **Objective Direction**:
   - `"maximize"`: Higher values better (default for ecosystem services)
   - `"minimize"`: Lower values better (e.g., costs, risks)
   - For minimize objectives: Internally negate values before dominance check

4. **Edge Cases**:
   - Single parcel: Always Pareto-optimal (no comparison)
   - All parcels identical: All Pareto-optimal
   - Missing family values: Parcel excluded from Pareto set (NA flag with warning)

### Example

```r
library(nemeton)
library(sf)

# Load demo data with all 12 families
data(massif_demo_units_extended)

# Identify Pareto-optimal parcels across all families
result <- identify_pareto_optimal(
  units = massif_demo_units_extended,
  families = NULL  # Auto-detect all 12 families
)

# Count Pareto-optimal parcels
table(result$is_pareto_optimal)
#> FALSE  TRUE
#>    14     6

# View Pareto set
result[result$is_pareto_optimal == TRUE, ]

# Production vs Conservation trade-off
result_tradeoff <- identify_pareto_optimal(
  units = massif_demo_units_extended,
  families = c("family_P", "family_B"),  # Production vs Biodiversity
  objectives = c("maximize", "maximize")
)

table(result_tradeoff$is_pareto_optimal)
#> FALSE  TRUE
#>    12     8
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| No family columns found | Stop: "No family indices found in units" |
| Family column has all NA | Warn, exclude from analysis |
| objectives length mismatch families | Stop: "objectives must match families length" |
| Invalid objective value | Stop: "objectives must be 'maximize' or 'minimize'" |

### Dependencies

- `sf`
- `dplyr` (data manipulation)

### Performance

- 20 parcels, 12 families: <1 second
- 1000 parcels, 12 families: ~8 seconds (O(n²) complexity)
- 10,000 parcels: ~10 minutes (consider spatial pre-filtering for large datasets)

**Performance Note**: For datasets >1000 parcels, recommend spatial subsetting or skyline algorithms (future optimization).

---

## cluster_parcels: Multi-Family Clustering

### Function Signature

```r
cluster_parcels(
  units,
  families = NULL,
  k = NULL,
  method = c("kmeans", "hierarchical"),
  distance_metric = "euclidean",
  auto_k = c("silhouette", "elbow", "none"),
  max_k = 10,
  column_name = "cluster_id",
  return_centers = TRUE,
  return_profile = TRUE,
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units with family indices |
| `families` | character vector | No | `NULL` | Family columns for clustering (NULL = all family_* columns) |
| `k` | integer | Conditional | `NULL` | Number of clusters (required if `auto_k="none"`) |
| `method` | character | No | `"kmeans"` | Clustering algorithm: "kmeans" or "hierarchical" |
| `distance_metric` | character | No | `"euclidean"` | Distance metric for hierarchical ("euclidean", "manhattan", "cosine") |
| `auto_k` | character | No | `"silhouette"` | Method to determine optimal k: "silhouette", "elbow", "none" |
| `max_k` | integer | No | `10` | Maximum k to test for auto_k |
| `column_name` | character | No | `"cluster_id"` | Name for cluster assignment column |
| `return_centers` | logical | No | `TRUE` | Return cluster centers in attributes |
| `return_profile` | logical | No | `TRUE` | Return cluster profiles (mean family scores) |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `sf` object with additional attributes

**Added Columns**:
- `{column_name}` (integer): Cluster assignment (1 to k)

**Attributes** (accessed via `attr(result, "cluster_analysis")`):
- `method`: Clustering method used
- `k`: Number of clusters
- `families`: Family columns used
- `centers` (if `return_centers=TRUE`): Matrix of cluster centers (k × n_families)
- `profile` (if `return_profile=TRUE`): Data frame with mean family scores per cluster
- `silhouette` (if method="kmeans"): Silhouette score for clustering quality
- `withinss` (if method="kmeans"): Within-cluster sum of squares

### Behavior

1. **Optimal k Determination** (if `auto_k != "none"`):
   - **Silhouette method**:
     ```r
     for k in 2:max_k:
       clusters = kmeans(families, centers=k)
       silhouette[k] = mean(silhouette_score(clusters))

     k_optimal = k with max(silhouette)
     ```
   - **Elbow method**:
     ```r
     for k in 2:max_k:
       clusters = kmeans(families, centers=k)
       withinss[k] = sum(clusters$withinss)

     k_optimal = detect_elbow(withinss)  # Max curvature point
     ```

2. **K-means Clustering**:
   ```r
   # Standardize family scores (mean=0, sd=1)
   families_scaled = scale(units[, families])

   # K-means
   clusters = kmeans(families_scaled, centers=k, nstart=25)

   # Assign cluster IDs
   units$cluster_id = clusters$cluster
   ```

3. **Hierarchical Clustering**:
   ```r
   # Compute distance matrix
   dist_matrix = dist(units[, families], method=distance_metric)

   # Hierarchical clustering (Ward's method)
   hc = hclust(dist_matrix, method="ward.D2")

   # Cut tree to k clusters
   units$cluster_id = cutree(hc, k=k)
   ```

4. **Cluster Profile Generation**:
   ```r
   profile = units |>
     group_by(cluster_id) |>
     summarise(across(all_of(families), mean, .names = "{.col}_mean"),
               n_parcels = n())
   ```

5. **Edge Cases**:
   - k > n_parcels: Stop with error
   - k = 1: Warning, all assigned to single cluster
   - Missing family values: Parcel excluded from clustering (cluster_id = NA)
   - Silhouette/elbow fails to converge: Default k = 4 with warning

### Example

```r
library(nemeton)

# Load demo data
data(massif_demo_units_extended)

# Auto-detect optimal k with silhouette
result <- cluster_parcels(
  units = massif_demo_units_extended,
  families = NULL,  # All 12 families
  method = "kmeans",
  auto_k = "silhouette",
  max_k = 8
)

# Optimal k chosen
attr(result, "cluster_analysis")$k
#> [1] 4

# Cluster assignments
table(result$cluster_id)
#> 1  2  3  4
#> 6  5  4  5

# Cluster profiles (mean family scores)
profile <- attr(result, "cluster_analysis")$profile
print(profile)
#>   cluster_id family_C_mean family_B_mean ... n_parcels
#>            1          65.3          42.1 ...         6
#>            2          38.7          78.5 ...         5
#>            3          82.1          28.4 ...         4
#>            4          54.6          55.2 ...         5

# Visualize cluster profiles with radar plot
for (i in 1:4) {
  nemeton_radar(
    profile[i, grep("family_.*_mean", names(profile))],
    title = paste("Cluster", i, "Profile")
  )
}

# Manual k selection
result_manual <- cluster_parcels(
  units = massif_demo_units_extended,
  k = 3,
  method = "hierarchical",
  distance_metric = "euclidean",
  auto_k = "none"
)
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| k=NULL and auto_k="none" | Stop: "Must specify k or enable auto_k" |
| k > n_parcels | Stop: "k cannot exceed number of parcels" |
| k < 2 | Stop: "k must be at least 2 for clustering" |
| No family columns found | Stop: "No family indices found" |
| All family values NA | Stop: "Cannot cluster, all data missing" |
| auto_k fails | Warn: "Auto-k failed, defaulting to k=4" |

### Dependencies

- `sf`
- `cluster` (silhouette, PAM for hierarchical)
- `stats` (kmeans, hclust, dist)
- `dplyr` (profile calculation)

### Performance

- 20 parcels, k=4, kmeans: <1 second
- 1000 parcels, k=4, kmeans: ~3 seconds
- 1000 parcels, hierarchical: ~15 seconds (distance matrix computation)
- auto_k silhouette (max_k=10): ×10 slower (tests multiple k)

---

## plot_tradeoff: Trade-off Visualization

### Function Signature

```r
plot_tradeoff(
  units,
  family_x,
  family_y,
  highlight_ids = NULL,
  show_pareto = TRUE,
  pareto_line_color = "red",
  point_size = 3,
  point_alpha = 0.7,
  add_labels = FALSE,
  label_field = NULL,
  title = NULL,
  theme = "minimal",
  lang = "en"
)
```

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `units` | `sf` (POLYGON) | Yes | - | Spatial units with family indices |
| `family_x` | character | Yes | - | Family column for X-axis |
| `family_y` | character | Yes | - | Family column for Y-axis |
| `highlight_ids` | character vector | No | `NULL` | Parcel IDs to highlight (different color/label) |
| `show_pareto` | logical | No | `TRUE` | Overlay Pareto frontier |
| `pareto_line_color` | character | No | `"red"` | Color for Pareto frontier line |
| `point_size` | numeric | No | `3` | Size of scatter points |
| `point_alpha` | numeric | No | `0.7` | Transparency of points (0-1) |
| `add_labels` | logical | No | `FALSE` | Add text labels to points |
| `label_field` | character | No | `NULL` | Column for labels (required if `add_labels=TRUE`) |
| `title` | character | No | `NULL` | Plot title (auto-generated if NULL) |
| `theme` | character | No | `"minimal"` | ggplot2 theme: "minimal", "bw", "classic" |
| `lang` | character | No | `"en"` | Message language |

### Returns

**Type**: `ggplot` object (can be further customized with ggplot2 functions)

### Behavior

1. **Scatterplot Creation**:
   ```r
   ggplot(units, aes(x = .data[[family_x]], y = .data[[family_y]])) +
     geom_point(size = point_size, alpha = point_alpha, color = "steelblue") +
     labs(x = family_x, y = family_y, title = title)
   ```

2. **Pareto Frontier Overlay** (if `show_pareto=TRUE`):
   ```r
   # Identify Pareto-optimal points for family_x and family_y
   pareto_set = identify_pareto_optimal(units, families = c(family_x, family_y))

   # Sort by family_x and connect with line
   pareto_points = pareto_set[pareto_set$is_pareto_optimal, ]
   pareto_points = pareto_points[order(pareto_points[[family_x]]), ]

   # Add to plot
   geom_line(data = pareto_points, color = pareto_line_color, size = 1.2) +
   geom_point(data = pareto_points, color = pareto_line_color, size = point_size+1)
   ```

3. **Highlight Points** (if `highlight_ids` provided):
   ```r
   highlight_data = units[units$parcel_id %in% highlight_ids, ]

   geom_point(data = highlight_data, color = "orange", size = point_size+2)
   ```

4. **Add Labels** (if `add_labels=TRUE`):
   ```r
   geom_text_repel(aes(label = .data[[label_field]]),
                   size = 3, box.padding = 0.5)
   ```

5. **Zone Annotations** (optional):
   - Quadrant lines at median values
   - Color-code zones: win-win (high-high), trade-off (high-low), lose-lose (low-low)

6. **Auto Title** (if `title=NULL`):
   ```r
   title = paste("Trade-off:", family_x, "vs", family_y)
   ```

### Example

```r
library(nemeton)
library(ggplot2)

# Load demo data
data(massif_demo_units_extended)

# Production vs Biodiversity trade-off
p1 <- plot_tradeoff(
  units = massif_demo_units_extended,
  family_x = "family_P",  # Production
  family_y = "family_B",  # Biodiversity
  show_pareto = TRUE,
  title = "Production-Biodiversity Trade-off"
)

print(p1)

# Customize further with ggplot2
p1 +
  geom_vline(xintercept = median(massif_demo_units_extended$family_P),
             linetype = "dashed", alpha = 0.5) +
  geom_hline(yintercept = median(massif_demo_units_extended$family_B),
             linetype = "dashed", alpha = 0.5) +
  annotate("text", x = 20, y = 80, label = "High Bio\nLow Prod", color = "gray50") +
  annotate("text", x = 80, y = 80, label = "Win-Win", color = "darkgreen") +
  annotate("text", x = 80, y = 20, label = "High Prod\nLow Bio", color = "gray50")

# Highlight specific parcels
highlight_ids <- c("parcel_001", "parcel_005", "parcel_012")
p2 <- plot_tradeoff(
  units = massif_demo_units_extended,
  family_x = "family_E",  # Energy
  family_y = "family_N",  # Naturalness
  highlight_ids = highlight_ids,
  add_labels = TRUE,
  label_field = "name"
)

print(p2)

# Multi-panel trade-off matrix (all pairs)
families <- c("family_P", "family_B", "family_N", "family_E")
plots <- list()

for (i in 1:(length(families)-1)) {
  for (j in (i+1):length(families)) {
    plots[[paste(i,j)]] <- plot_tradeoff(
      units = massif_demo_units_extended,
      family_x = families[i],
      family_y = families[j],
      point_size = 2
    )
  }
}

# Arrange in grid (requires patchwork or gridExtra)
library(patchwork)
wrap_plots(plots, ncol = 3)
```

### Error Handling

| Error Condition | Response |
|-----------------|----------|
| family_x or family_y not found | Stop: "Column '{family}' not found" |
| add_labels=TRUE but label_field=NULL | Stop: "label_field required when add_labels=TRUE" |
| label_field not found | Stop: "Label column '{label_field}' not found" |
| Empty dataset after NA removal | Stop: "No valid data for plotting" |

### Dependencies

- `ggplot2` (plotting)
- `ggrepel` (label repulsion)
- `sf` (spatial data handling)

### Performance

- 20 parcels: <1 second
- 1000 parcels: ~1 second (ggplot rendering)
- Label repulsion slows with many labels (recommend add_labels=FALSE for >100 points)

---

## Integration Example: Complete Multi-Criteria Workflow

```r
library(nemeton)
library(sf)
library(ggplot2)
library(dplyr)

# Load complete 12-family dataset
data(massif_demo_units_extended)

# 1. Identify Pareto-optimal parcels
parcels_pareto <- identify_pareto_optimal(
  units = massif_demo_units_extended,
  families = NULL  # All 12 families
)

message("Pareto set size: ", sum(parcels_pareto$is_pareto_optimal), " / 20 parcels")

# 2. Cluster parcels into management zones
parcels_clustered <- cluster_parcels(
  units = parcels_pareto,
  k = 4,
  method = "kmeans",
  auto_k = "none"
)

# View cluster profiles
profile <- attr(parcels_clustered, "cluster_analysis")$profile
print(profile)

# 3. Visualize key trade-offs
p_prod_bio <- plot_tradeoff(
  units = parcels_clustered,
  family_x = "family_P",
  family_y = "family_B",
  show_pareto = TRUE,
  title = "Production vs Biodiversity"
)

p_energy_natural <- plot_tradeoff(
  units = parcels_clustered,
  family_x = "family_E",
  family_y = "family_N",
  show_pareto = TRUE,
  title = "Energy vs Naturalness"
)

# Combine plots
library(patchwork)
p_prod_bio + p_energy_natural

# 4. Strategic recommendations
# Example: Identify parcels for each management strategy
strategies <- parcels_clustered |>
  st_drop_geometry() |>
  mutate(
    strategy = case_when(
      cluster_id == 1 ~ "Intensive Production",
      cluster_id == 2 ~ "Biodiversity Conservation",
      cluster_id == 3 ~ "Multi-Objective (Balanced)",
      cluster_id == 4 ~ "Wilderness Protection"
    )
  )

table(strategies$strategy)
```

---

## Testing Requirements

### Unit Tests

- ✅ Pareto dominance logic (2D, 3D, 12D)
- ✅ K-means clustering (convergence, reproducibility)
- ✅ Hierarchical clustering (dendrogram cutting)
- ✅ Silhouette calculation
- ✅ Elbow detection
- ✅ Trade-off plot generation
- ✅ Pareto frontier overlay
- ✅ Edge cases (k=1, single parcel, all identical)

### Integration Tests

- ✅ Full workflow: Pareto → Clustering → Trade-off plots
- ✅ Compatibility with 12-family datasets
- ✅ Plot customization with ggplot2

### Fixtures

- `tests/testthat/fixtures/pareto_reference.rds`: Expected Pareto sets for test datasets
- `tests/testthat/fixtures/cluster_reference.rds`: Expected cluster assignments

---

**Document Version**: 1.0
**Last Updated**: 2026-01-05
**Status**: Contract Complete
**Implemented**: TBD (Phase 9 tasks)
