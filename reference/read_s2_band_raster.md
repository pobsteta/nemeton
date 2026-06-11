# Read a single cached Sentinel-2 band as a SpatRaster

Opens \`\<cache_dir\>/\<sanitized_scene_id\>/\<band\>.tif\` and returns
the corresponding \[terra::SpatRaster\] object. No HTTP. The file is
produced by \[ingest_sentinel2_timeseries()\] when called with a
non-NULL \`cache_dir\`.

## Usage

``` r
read_s2_band_raster(cache_dir, scene_id, band)
```

## Arguments

- cache_dir:

  Character(1). Path to the S2 cache root, e.g.
  \`\<project\>/cache/layers/sentinel2\`.

- scene_id:

  Character(1). The Sentinel-2 scene id as returned by the STAC search
  and stored in \`obs_pixel.scene_id\`. The on-disk directory name is
  its sanitized form (cf. \`nemeton:::.s2_safe_scene_id\`).

- band:

  Character(1). One of \`"B04"\` (Red, 10 m), \`"B08"\` (NIR, 10 m),
  \`"B12"\` (SWIR2, 20 m), \`"B11"\` (SWIR1, 20 m, used by NDMI),
  \`"B05"\` (Red-edge 1, 20 m) or \`"B8A"\` (NIR narrow, 20 m, both used
  by NDRE, spec 022).

## Value

A 1-layer \[terra::SpatRaster\] in the source CRS (typically EPSG:32631
or 32632 — UTM zones over France), or \`NULL\` if the file is missing.
The raster is \*\*not\*\* reprojected — leaflet / leafem handles that
downstream.

## Details

Returns \`NULL\` (not an error) when the file is absent — callers like
\[read_s2_band_stack()\] use this to skip missing scenes silently and
emit a single aggregated warning.

## See also

\[read_s2_band_stack()\] for multi-temporal stacks,
\[build_index_stack()\] for NDVI / NBR, \[extract_pixel_timeseries()\]
for per-pixel time series, \[diagnose_s2_cache()\] to inspect what's on
disk, \[ingest_sentinel2_timeseries()\] for the write path.

## Examples

``` r
if (FALSE) { # \dontrun{
  cache <- "/home/user/projects/myforest/cache/layers/sentinel2"
  r <- read_s2_band_raster(cache,
                           "S2A_MSIL2A_20260508T103651_R008_T31TFN_20260508T191011",
                           "B04")
  terra::plot(r)
} # }
```
