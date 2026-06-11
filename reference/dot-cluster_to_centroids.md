# Convert per-class patch rasters into an enriched centroid \`sf\`

Replaces each patch by its centroid (in the raster's CRS), attaching the
per-cluster mean stress index and the per-cluster minimum first-dieback
date (i.e. earliest detected anomaly).

## Usage

``` r
.cluster_to_centroids(
  clusters,
  stress_index_raster = NULL,
  first_dieback_date_raster = NULL
)
```

## Arguments

- clusters:

  A list returned by \[.cluster_anomaly_pixels()\].

- stress_index_raster:

  \`SpatRaster\` of FORDEAD stress index. May be \`NULL\` (then the
  column comes back as NA).

- first_dieback_date_raster:

  \`SpatRaster\` of first-dieback date, expressed as days since
  \`1970-01-01\` (FORDEAD default). May be \`NULL\`.

## Value

An sf POINT with columns \`confidence_class\`, \`stress_index\`,
\`trigger_date\`, \`n_pixels\`, \`area_m2\`, \`cluster_id\`. CRS
inherited from \`clusters\`. Empty sf when no cluster passes the size
threshold.
