# Build a \`geopandas.GeoSeries\` from an \`sf\` AOI

Returns a CRS-aware GeoSeries in EPSG:4326 wrapping a single
(Multi)Polygon. fordead 2.x's \`FordeadProcess.geometry\` setter detects
\`to_crs\` + \`total_bounds\` on the input and automatically:

## Usage

``` r
.aoi_geometry_reticulate(aoi)
```

## Arguments

- aoi:

  An \`sf\` or \`sfc\` object. Reprojected to EPSG:4326.

## Value

A Python \`geopandas.GeoSeries\` with \`crs = "EPSG:4326"\`.

## Details

1\. reprojects to the collection's CRS via \`value.to_crs(self.crs)\`;
2. derives \`self.bbox\` from \`value.total_bounds\`.

Pre-v0.25.3 this returned a raw \`shapely.geometry.Polygon\` (no
\`to_crs\` / \`total_bounds\` attributes), so the setter could not
reproject. When the collection was in EPSG:32631 (Sentinel-2 UTM tiles)
but the geometry stayed in EPSG:4326, stackstac clipped to a
degree-valued bbox on meter-valued data and raised
\`rioxarray.NoDataInBounds\`.
