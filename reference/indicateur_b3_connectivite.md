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

  An sf object with BD Foret V2 polygons. If NULL, B3 is NA for all
  parcels (connectivity not measurable). Default NULL.

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
local_connectivity is distance-based (sf) per-parcel adjustment
(distance from the unit centroid to the nearest forest polygon, 0 when
the centroid lies inside forest).

A component that cannot be measured (missing package, error, fewer than
5 forest units for the kernel) is NA: it is excluded and the remaining
weights are renormalised, instead of entering the mean as a fixed 50.
Computations run in metres: geographic inputs are projected to
ETRS89-LAEA (EPSG:3035) and the result is attached to the original
units.

## See also

Other biodiversity-indicators:
[`indicateur_b1_protection()`](https://pobsteta.github.io/nemeton/reference/indicateur_b1_protection.md),
[`indicateur_b2_structure()`](https://pobsteta.github.io/nemeton/reference/indicateur_b2_structure.md)
