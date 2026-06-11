# Read a multi-temporal stack for one Sentinel-2 band

Stacks the cached \`\<band\>.tif\` files of several scenes into a single
\[terra::SpatRaster\] with one layer per observation date. Layers are
named by \`as.character(obs_date)\` and the corresponding
\[terra::time()\] attribute is set, so callers can index by date.

## Usage

``` r
read_s2_band_stack(cache_dir, scenes_df, band)
```

## Arguments

- cache_dir:

  Character(1). Same as \[read_s2_band_raster()\].

- scenes_df:

  A \`data.frame\` with at minimum columns \`scene_id\` (character) and
  \`obs_date\` (Date, or coercible). Extra columns are ignored. Rows are
  re-ordered by \`obs_date\` internally. In practice this is the listing
  of scenes present in the COG cache directory for the zone.

- band:

  Character(1). One of \`"B04"\`, \`"B08"\`, \`"B12"\`, \`"B11"\`.

## Value

A multi-layer \[terra::SpatRaster\] in source CRS, with \`names(out)\` =
\`as.character(obs_date)\` and \`terra::time(out)\` set to the dates of
the surviving scenes. \`NULL\` when no scene could be opened.

## Details

Missing scenes (no \`\<band\>.tif\` on disk) are skipped silently and
reported via a \*\*single aggregated warning\*\* — never one warning per
missing scene. Returns \`NULL\` if every scene is missing.

## See also

\[read_s2_band_raster()\], \[build_index_stack()\] for computed NDVI /
NBR layers, \[extract_pixel_timeseries()\].

## Examples

``` r
if (FALSE) { # \dontrun{
  cache <- "/proj/cache/layers/sentinel2"
  # scenes is a data.frame of (scene_id, obs_date); typically the
  # cache directory listing for the zone.
  scenes <- data.frame(
    scene_id = "S2A_MSIL2A_20250610T103031_R108_T31TGM",
    obs_date = as.Date("2025-06-10"))
  stack  <- read_s2_band_stack(cache, scenes, "B04")
  terra::time(stack)        # the dates as a vector
  terra::plot(stack[[1]])   # first scene
} # }
```
