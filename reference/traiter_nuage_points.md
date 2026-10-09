# Derive DTM, DSM and CHM rasters from a point cloud

Builds the three elevation models from a point cloud, whatever its
source (spec 059):

- `"lidar_ign"`: IGN LiDAR HD tiles delivered without their derived MNT
  / MNS / MNH rasters;

- `"lidar_drone"`: drone LiDAR, usually unclassified;

- `"photogrammetrie"`: a structure-from-motion cloud from an RGB drone.
  It only sees the canopy surface, so the terrain comes from
  `mnt_externe`.

The **DTM** (MNT) is the ground surface, the **DSM** (MNS) the highest
surface (canopy, buildings) and the **CHM** (MNH) the height above
ground.

## Usage

``` r
traiter_nuage_points(
  nuage,
  type = c("lidar_ign", "lidar_drone", "photogrammetrie"),
  res = NULL,
  classifier = TRUE,
  methode_sol = c("csf", "ptd"),
  csf = list(),
  mnt_externe = NULL,
  mnh_reference = NULL,
  recalage_vertical = TRUE,
  aoi = NULL,
  dossier = NULL,
  ncores = 1L,
  overwrite = FALSE,
  verbose = TRUE
)
```

## Arguments

- nuage:

  Character. A directory of `.las` / `.laz` / `.copc.laz` files, or a
  vector of such files.

- type:

  One of `"lidar_ign"`, `"lidar_drone"`, `"photogrammetrie"`.

- res:

  Numeric. Output resolution in metres. `NULL` (default): 0.5 for
  `"lidar_ign"` (as the published IGN rasters), 0.25 for drone sources.

- classifier:

  Logical. Reset and reclassify noise and ground before building the
  models. Default `TRUE`. With `FALSE`, the classes of the file are used
  as they are (ground and water must be present for the LiDAR types).
  For `"photogrammetrie"`, only noise is classified.

- methode_sol:

  Ground classification: `"csf"` (cloth simulation, default) or `"ptd"`
  (progressive TIN densification).

- csf:

  Named list of arguments passed to
  [`lasR::classify_with_csf()`](https://rdrr.io/pkg/lasR/man/classify_with_csf.html),
  overriding the defaults (`slope_smooth = TRUE`,
  `cloth_resolution = 0.5`, `rigidness = 1`, `class_threshold = 0.5`).

- mnt_externe:

  `SpatRaster` or path. Terrain for `"photogrammetrie"` (required there,
  ignored otherwise).

- mnh_reference:

  `SpatRaster` or path. Reference CHM (IGN LiDAR HD MNH) used to find
  bare ground for the vertical shift of `"photogrammetrie"`.

- recalage_vertical:

  Logical. Estimate and remove the vertical shift of a photogrammetric
  DSM. Default `TRUE`; skipped with a warning when `mnh_reference` is
  missing or holds fewer than 100 bare-ground cells.

- aoi:

  Optional `sf` / `sfc`. When supplied, cropped and masked copies are
  returned (written under `aoi/` in each output directory); the
  full-extent rasters stay in place.

- dossier:

  Character. Parent directory of the outputs. `NULL` (default): the
  parent of the cloud's directory, i.e. `<project>/cache/layers` for a
  cloud under `<project>/cache/layers/<name>/`.

- ncores:

  Integer. Number of files processed concurrently by lasR. Default 1.

- overwrite:

  Logical. Re-run the LiDAR pass even if a cache with the same key
  exists. Default `FALSE`.

- verbose:

  Logical. Progress messages. Default `TRUE`.

## Value

A list:

- `mnt`, `mns`, `mnh`: paths of the GeoTIFFs;

- `classes`: number of points per class after processing;

- `qualite`: list with `n_points`, `densite` (points per m²), `part_sol`
  (share of non-noise points classified as ground, `NA` for
  photogrammetry), `part_bruit`, `part_mnh_negatif` (share of CHM cells
  below -0.5 m before clamping), `decalage_vertical`, `decalage_iqr` and
  `n_sol_nu` (photogrammetry);

- `elapsed`: duration of the LiDAR pass (0 when served from cache).

A warning is issued when less than 5 % of the points are ground, or when
the bare-ground differences are too spread (interquartile range above
0.5 m) for the vertical shift to be trusted.

## Details

**LiDAR sources** (`"lidar_ign"`, `"lidar_drone"`) run one
[lasR](https://r-lidar.github.io/lasR/) pass:

1.  With `classifier = TRUE` (default), every class is reset, isolated
    points are flagged as noise (`classify_with_ivf()`, class 18) and
    the ground is classified again (`classify_with_csf()`, or
    `classify_with_ptd()`). IGN classes are thus not trusted as
    delivered.

2.  A TIN of ground and water points (classes 2 and 9) gives the DTM.

3.  The DSM is the highest non-noise point of each cell.

4.  Points are normalised against the TIN and the CHM is the highest
    normalised point, which is more accurate on slopes than DSM - DTM.
    Negative heights are set to 0.

**Photogrammetry** keeps the drone DSM (noise removed with
`classify_with_sor()`) and never derives a terrain from it.
`mnt_externe`, typically the IGN LiDAR HD DTM, is resampled onto the DSM
grid (bilinear). A SfM cloud is often shifted vertically (no ground
control points, ellipsoidal heights): with `recalage_vertical = TRUE`,
the shift is the median of DSM - DTM over bare-ground cells, i.e. cells
where `mnh_reference` (the IGN CHM) is below 0.5 m, and it is removed
from the DSM. The CHM is DSM - DTM, negative heights set to 0.

On the IGN tile `LHD_FXX_0633_6767` (20.7 M points), the reclassified
DTM matches the published IGN DTM within 1.1 cm (median, 95th percentile
7.7 cm) and the CHM within 0 m (median); a 2.30 m shift added to the DSM
is recovered within 3 mm.

**Outputs** are written as `mnt.tif`, `mns.tif` and `mnh.tif` in three
sub-directories of `dossier`: `ign_mnt/`, `ign_mns/`, `ign_mnh/` for
`"lidar_ign"`, `drone_mnt/`, `drone_mns/`, `drone_mnh/` otherwise. In a
project (`dossier` = `<project>/cache/layers`),
[`resolve_project_dem()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)
and
[`resolve_project_chm()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)
pick the drone products first, then the published IGN rasters, then the
`ign_*` ones, and the drone products raise the project to NDP 2. The
LiDAR pass is cached: it is re-run only when the tiles, the resolution
or the classification settings change.

## Lifecycle

Experimental (spec 059): may change in any release.

## See also

[`compute_dtm_chm_from_laz()`](https://pobsteta.github.io/nemeton/reference/compute_dtm_chm_from_laz.md),
[`resolve_project_dem()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md),
[`resolve_project_chm()`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)

## Examples

``` r
if (FALSE) { # \dontrun{
couches <- file.path(projet, "cache", "layers")
# IGN cloud delivered alone
ign <- traiter_nuage_points(file.path(couches, "lidar_nuage"),
                            type = "lidar_ign", ncores = 4)
# Photogrammetric drone flight, terrain from IGN
sfm <- traiter_nuage_points(file.path(couches, "drone_nuage"),
                            type = "photogrammetrie",
                            mnt_externe = ign$mnt,
                            mnh_reference = ign$mnh)
sfm$qualite$decalage_vertical
} # }
```
