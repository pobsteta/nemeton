# Discover the best available DEM / CHM raster in a Nemeton project

Néméton projects accumulate digital terrain models (MNT / DEM / DTM) and
canopy height models (MNH / CHM) from several sources — IGN RGE ALTI
downloaded by tutorials, LiDAR HD MNT produced by \`lidR\`,
\`opencanopy\`'s \`dtm.tif\`, Open-Canopy CHM tiles — each landing under
its own naming convention. These helpers walk a list of well-known
locations in \*\*priority order\*\* (highest quality first) and return
the first match, so callers don't have to hard-code paths.

When multiple tiles sit in the same directory (e.g. several \`BD ALTI\`
tiles), the raster returned is a virtual mosaic (\`terra::vrt()\`), so
downstream \`terra::extract\` / \`terra::crop\` calls transparently
cover the full footprint.

## Usage

``` r
resolve_project_dem(
  project_path,
  load = TRUE,
  verbose = FALSE,
  try_compute_from_laz = TRUE
)

resolve_project_chm(
  project_path,
  load = TRUE,
  verbose = FALSE,
  try_compute_from_laz = TRUE
)
```

## Arguments

- project_path:

  Character. Root of the Nemeton project tree.

- load:

  Logical. When \`TRUE\` (default), open the raster via
  \`terra::rast()\` (or \`terra::vrt()\` for multi-tile dirs) and return
  the \`SpatRaster\`. When \`FALSE\`, return the matching path(s) as a
  character vector — useful for diagnostics and for callers that want to
  control how the raster is loaded.

- verbose:

  Logical. When \`TRUE\`, log every probed location via
  \`cli::cli_alert_info()\`. Default \`FALSE\`.

- try_compute_from_laz:

  Logical. When no pre-rasterized MNT / MNH is found \*and\*
  \`\<project\>/cache/layers/lidar_nuage/\*.laz\` tiles are present,
  attempt to derive them on the fly with
  \[\`compute_dtm_chm_from_laz()\`\] (via \`lasR\`) and re-probe.
  Default \`TRUE\`. The fallback is opportunistic: missing \`lasR\`
  simply skips it without erroring.

## Value

When \`load = TRUE\`: a \`SpatRaster\`, or \`NULL\` if no matching
raster exists. When \`load = FALSE\`: a character vector of file paths
(length 1 for single-file matches, longer for tile directories), or
\`NULL\`. The returned object also carries the matched layer label as
attribute \`"nemeton_dem_layer"\` / \`"nemeton_chm_layer"\`.

## Search order (DEM)

1.  \`\<project\>/cache/layers/lidar_mnt/\*.tif\` — LiDAR HD (1 m)

2.  \`\<project\>/cache/layers/dem/\*.tif\` — generic DEM cache

3.  \`\<project\>/cache/layers/bd_alti/\*.tif\` — IGN BD ALTI (25 m)

4.  \`\<project\>/cache/layers/rge_alti/\*.tif\` — IGN RGE ALTI (5 m)

5.  \`\<project\>/cache/layers/dtm/\*.tif\` — generic DTM cache

6.  \`\<project\>/cache/layers/mnt/\*.tif\` — generic MNT cache

7.  \`\<project\>/cache/layers/dem.tif\` — direct file (v0.25.5)

8.  \`\<project\>/cache/layers/dtm.tif\` — direct file (v0.25.5)

9.  \`\<project\>/cache/layers/mnt.tif\` — direct file (v0.25.5)

10. \`\<project\>/dtm.tif\` — \`opencanopy\` convention

11. \`\<project\>/dem.tif\` — project root (v0.25.5)

12. \`\<project\>/mnt.tif\` — tutorial convention

13. \`\<project\>/data/dtm.tif\` — alt project layout

14. \`\<project\>/data/dem.tif\` — alt project layout (v0.25.5)

15. \`\<project\>/data/mnt.tif\` — alt project layout

## Search order (CHM)

1.  \`\<project\>/cache/layers/lidar_mnh/\*.tif\` — LiDAR HD MNH

2.  \`\<project\>/cache/layers/mnh/\*.tif\` — generic MNH cache

3.  \`\<project\>/cache/layers/opencanopy/chm_predicted_0_2m.tif\` —
    Open-Canopy CHM 0.2 m (v0.192.2)

4.  \`\<project\>/cache/layers/opencanopy/chm_predicted_1_5m.tif\` —
    Open-Canopy CHM 1.5 m (v0.192.2)

5.  \`\<project\>/cache/layers/opencanopy/chm_1_5m.tif\` — Open-Canopy
    CHM, completion witness (v0.192.2)

6.  \`\<project\>/cache/layers/chm/\*.tif\` — generic CHM cache

7.  \`\<project\>/cache/layers/chm.tif\` — direct file (v0.25.5)

8.  \`\<project\>/cache/layers/mnh.tif\` — direct file (v0.25.5)

9.  \`\<project\>/chm.tif\` — single-file convention

10. \`\<project\>/mnh.tif\` — tutorial convention

11. \`\<project\>/data/chm.tif\` — alt project layout

12. \`\<project\>/data/mnh.tif\` — alt project layout

The Open-Canopy entries are named file by file on purpose:
\`cache/layers/opencanopy/\` also holds orthophotos (\`ortho_rvb.tif\`,
\`ortho_irc.tif\`) and spectral indices (\`ndvi.tif\`, \`ndwi.tif\`,
...), which a directory-wide candidate would mosaic together with the
height models. \`chm_vegetation_0_2m.tif\` is excluded as well: it is a
masked derivative, not the reference height model.

## Examples

``` r
if (FALSE) { # \dontrun{
dem <- resolve_project_dem("C:/.../projects/20260416_112240_gomv",
                           verbose = TRUE)
if (is.null(dem)) {
  stop("No DEM found — download one with opencanopy or happign.")
}
attr(dem, "nemeton_dem_layer")  # "opencanopy DTM"
plan <- create_sampling_plan(zone, mnt = dem, ...)
} # }
if (FALSE) { # \dontrun{
chm <- resolve_project_chm("C:/.../projects/20260416_112240_gomv")
plan <- create_sampling_plan(zone, mnt = dem, chm = chm, ...)
} # }
```
