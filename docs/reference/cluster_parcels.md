# Cluster Parcels by Multi-Family Profiles

Performs clustering analysis on forest parcels based on their ecosystem
service family profiles. Supports both K-means and hierarchical
clustering with automatic optimal k determination via silhouette
analysis.

## Usage

``` r
cluster_parcels(data, families, k = NULL, method = "kmeans", max_k = 10)
```

## Arguments

- data:

  An sf object or data.frame containing the parcels to cluster

- families:

  Character vector of family column names to use for clustering (e.g.,
  `c("family_C", "family_B", "family_P", "family_S")`)

- k:

  Integer number of clusters. If `NULL` (default), the optimal number of
  clusters is determined automatically using silhouette analysis.

- method:

  Character string specifying clustering method: `"kmeans"` (default) or
  `"hierarchical"` (Ward's linkage)

- max_k:

  Maximum number of clusters to test when k is NULL (default: 10)

## Value

The input data with an additional `cluster` integer column indicating
cluster assignment. The result also has attributes:

- `cluster_profile`: Data frame with mean family values per cluster

- `method`: Clustering method used

- `optimal_k`: Optimal k if auto-determined (only when k=NULL)

- `silhouette_scores`: Silhouette scores for k=2 to max_k (only when
  k=NULL)

If input is sf object, output preserves the sf class and geometry.

## Details

\## Clustering Methods

\- \*\*K-means\*\*: Fast, works well with spherical clusters, sensitive
to outliers - \*\*Hierarchical\*\*: More flexible cluster shapes,
deterministic, slower

\## Automatic K Determination

When `k = NULL`, the function tests k from 2 to `max_k` and selects the
k with highest average silhouette width. Silhouette values range from -1
to 1: - \> 0.7: Strong structure - 0.5-0.7: Reasonable structure -
0.25-0.5: Weak structure - \< 0.25: No substantial structure

\## Cluster Profiles

The function computes cluster profiles (centroid values) for each
family, allowing interpretation of cluster characteristics (e.g., "high
production, low biodiversity" cluster).

## Examples

``` r
if (FALSE) { # \dontrun{
# Load demo dataset
data("massif_demo_units_extended")

# Cluster parcels into 3 groups based on 4 families
result <- cluster_parcels(
  massif_demo_units_extended,
  families = c("family_C", "family_B", "family_P", "family_S"),
  k = 3,
  method = "kmeans"
)

# View cluster assignments
table(result$cluster)

# View cluster profiles
attr(result, "cluster_profile")

# Auto-determine optimal k
result_auto <- cluster_parcels(
  massif_demo_units_extended,
  families = c("family_C", "family_B", "family_P", "family_S"),
  k = NULL
)
attr(result_auto, "optimal_k")
attr(result_auto, "silhouette_scores")

# Use hierarchical clustering
result_hclust <- cluster_parcels(
  massif_demo_units_extended,
  families = c("family_C", "family_B", "family_P", "family_S"),
  k = 3,
  method = "hierarchical"
)

# Visualize clusters spatially
library(ggplot2)
ggplot(result) +
  geom_sf(aes(fill = factor(cluster))) +
  scale_fill_viridis_d() +
  labs(title = "Parcel Clusters", fill = "Cluster")
} # }
```
