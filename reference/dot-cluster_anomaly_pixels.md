# Cluster anomalous pixels into connected patches per class

Splits the reclassified raster into one binary raster per anomaly class
(1..4) and runs \`terra::patches()\` 8-neighbour by default. Patches
smaller than \`min_pixels\` are dropped (G1 — we don't trust isolated
pixels).

## Usage

``` r
.cluster_anomaly_pixels(class_raster, min_pixels = 5L, connectivity = 8L)
```

## Arguments

- class_raster:

  A \`terra::SpatRaster\` returned by \[.classify_pixels_to_classes()\].

- min_pixels:

  Integer. Minimum patch size (in pixels) to be kept. Default 5.

- connectivity:

  Integer 4 or 8. Default 8.

## Value

A list of \`SpatRaster\`s, one per anomaly class (\`"1-faible"\`,
\`"2-moyenne"\`, \`"3-forte"\`, \`"4-sol-nu"\`). Each raster has integer
patch IDs (1..N_class) and NA elsewhere.
