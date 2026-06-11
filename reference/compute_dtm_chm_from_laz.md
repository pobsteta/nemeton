# Derive DTM and CHM rasters from IGN LiDAR HD point clouds

Fallback used when IGN's pre-rasterized MNT / MNH GeoTIFFs cannot be
downloaded (404 on derived products, bandwidth issues, dalles produced
but tiles not yet published) but the raw COPC point cloud tiles
\*\*are\*\* present under \`cache/layers/lidar_nuage/\`.

Wraps a minimal \[\`lasR\`\](https://r-lidar.github.io/lasR/) pipeline:

1.  read all \`.copc.laz\` / \`.laz\` tiles in \`laz_dir\`,

2.  triangulate ground returns (class 2) into a TIN,

3.  rasterize the TIN to a DTM (1 m default),

4.  normalize the cloud by subtracting the TIN,

5.  rasterize the maximum normalized Z to a CHM.

Outputs are written under the exact directory layout expected by
\[\`resolve_project_dem()\`\] / \[\`resolve_project_chm()\`\], so
calling code that already discovers MNT/MNH rasters via those helpers
picks the derived products up transparently.

## Usage

``` r
compute_dtm_chm_from_laz(
  laz_dir,
  dtm_dir = NULL,
  chm_dir = NULL,
  res = 1,
  aoi = NULL,
  ncores = 1L,
  overwrite = FALSE,
  verbose = TRUE
)
```

## Arguments

- laz_dir:

  Character. Directory containing the COPC tiles (typically
  \`\<project\>/cache/layers/lidar_nuage\`).

- dtm_dir:

  Character. Output directory for the DTM. Defaults to sibling
  \`lidar_mnt/\` of \`laz_dir\` (i.e.
  \`\<project\>/cache/layers/lidar_mnt\`).

- chm_dir:

  Character. Output directory for the CHM. Defaults to sibling
  \`lidar_mnh/\` of \`laz_dir\`.

- res:

  Numeric. Output raster resolution in metres. Default 1 to match IGN
  LiDAR HD MNH / MNT native resolution.

- aoi:

  Optional \`sf\` / \`sfc\`. When supplied, the output rasters are
  cropped (and masked) to this AOI.

- ncores:

  Integer. Number of cores passed to \`lasR::exec()\`. Default 1 — set
  to \`parallel::detectCores() - 1\` for large blocks.

- overwrite:

  Logical. Re-derive even if \`dtm.tif\` / \`chm.tif\` already exist in
  the output directories. Default \`FALSE\`.

- verbose:

  Logical. When \`TRUE\`, log each stage via \`cli\`. Default \`TRUE\`.

## Value

Invisibly, a list with:

- dtm:

  Path to the derived DTM (or \`NULL\` if not produced).

- chm:

  Path to the derived CHM (or \`NULL\` if not produced).

- n_tiles:

  Number of input \`.laz\` tiles processed.

- elapsed:

  \`difftime\` of the lasR pipeline run.

Returns \`NULL\` invisibly (with a \`cli::cli_warn\`) when no tiles are
found or when \`lasR\` is not installed.

## Installation

\`lasR\` is not on CRAN. Install it from r-universe: “\`r
install.packages("lasR", repos = "https://r-lidar.r-universe.dev") “\`

## Examples

``` r
if (FALSE) { # \dontrun{
# Standalone:
compute_dtm_chm_from_laz(
  laz_dir = "<project>/cache/layers/lidar_nuage",
  ncores  = 4
)

# Then resolve as usual — the derived tifs are picked up:
dem <- resolve_project_dem("<project>")
chm <- resolve_project_chm("<project>")
} # }
```
