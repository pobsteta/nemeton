# Calculate Ecological Connectivity (B3)

Computes ecological connectivity using a multi-method approach combining
structural metrics, cost distance, graph theory, and kernel dispersal,
as described in tutorial 04. Uses BD Foret data and DEM when available.

## Usage

``` r
indicateur_b3_connectivite(
  units,
  bdforet = NULL,
  dem = NULL,
  max_distance = 5000
)
```

## Arguments

- units:

  An sf object with forest parcels.

- bdforet:

  An sf object with BD Foret V2 polygons. If NULL, returns fallback
  score of 50 for all parcels. Default NULL.

- dem:

  A SpatRaster with digital elevation model. Used for cost distance
  refinement. Default NULL.

- max_distance:

  Numeric. Maximum distance threshold (meters) for local connectivity
  scoring. Default 5000.

## Value

The input sf object with added column B3 (0-100 score, higher = better).

## Details

Four components are combined (25

1.  \*\*Structural\*\* (landscapemetrics): cohesion, nearest-neighbour
    distance, aggregation index of forest patches.

2.  \*\*Cost distance\*\* (terra): resistance-weighted distance from
    parcels to nearest forest patch.

3.  \*\*Graph\*\* (igraph): proportion of forest patches in the largest
    connected component (threshold 500m).

4.  \*\*Kernel dispersal\*\* (adehabitatHR): kernel density estimation
    of forest parcel centroids, ratio of 95 as proxy for functional
    connectivity.

Final score: B3 = 0.7 \* B3_global + 0.3 \* local_connectivity where
local_connectivity is distance-based (sf) per-parcel adjustment.

## See also

Other biodiversity-indicators:
[`indicateur_b1_protection()`](https://pobsteta.github.io/nemeton/reference/indicateur_b1_protection.md),
[`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md)
