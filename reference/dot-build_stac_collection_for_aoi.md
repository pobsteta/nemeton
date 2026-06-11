# Build a \`simplestac.ItemCollection\` from a scenes_df + local COG cache

Walks \`scenes_df\`, locates
\`\<cache_dir\>/\<safe_scene_id\>/\<band\>.tif\` for each scene/band
pair, and constructs one \`pystac.Item\` per scene whose bands are all
present on disk. Scenes with one or more missing bands are skipped with
a warning (aggregated, one \`cli::cli_warn\` at the end). The items are
wrapped in a \`simplestac.ItemCollection\`.

## Usage

``` r
.build_stac_collection_for_aoi(
  aoi,
  scenes_df,
  cache_dir,
  bands_required = c("B02", "B04", "B05", "B8A", "B11", "B12")
)
```

## Arguments

- aoi:

  An \`sf\` or \`sfc\` object — used for \`Item.geometry\`,
  \`Item.bbox\`, and as a per-item property. Reprojected to EPSG:4326.

- scenes_df:

  A \`data.frame\` (or tibble) with at minimum the columns \`scene_id\`
  (character) and \`obs_date\` (Date or coercible). Exact \`scene_id\`
  duplicates and ESA reprocessing duplicates (same acquisition, newer
  processing baseline) are silently removed.

- cache_dir:

  Character(1). Root directory of the COG cache, typically
  \`\<project\>/cache/layers/sentinel2\`.

- bands_required:

  Character vector of band codes required by FORDEAD. Default \`c("B02",
  "B04", "B05", "B8A", "B11", "B12")\` covers CRSWIR + cloud / shadow /
  soil masks.

## Value

A Python \`simplestac.utils.ItemCollection\` object. The number of items
equals the number of scenes whose bands are all present.

## Details

Why local COG paths and not the remote PC/CDSE hrefs:

\* Local paths don't expire — long \`fit()\` / \`predict()\` runs are
safe against PC SAS token expiry (cf. v0.22.1). \* Re-running FORDEAD on
the same AOI is fast (no network). \* The cache is already extent-aware
(cf. v0.21.4 / v0.21.8), so we know each \`\<band\>.tif\` covers at
least the AOI.
