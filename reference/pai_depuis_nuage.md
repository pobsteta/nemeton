# Plant Area Index from a LiDAR-HD point cloud (spec 027 L1)

Wall-to-wall **PAI** raster from a classified LiDAR-HD point cloud
(`.las`/`.laz`), via per-pixel gap fraction + Beer-Lambert:
`P_gap = N_ground / (N_ground + N_veg)` then `PAI = -(1/k) * ln(P_gap)`.
The PAI feeds the `lai_max` of
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
and the canopy of
[`regen_sensibilite`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
(PAI ≈ LAI only for a leaves-on acquisition, spec 027 §9.3).

## Usage

``` r
pai_depuis_nuage(
  dossier_las = NULL,
  grille = NULL,
  res = 2,
  k = 0.5,
  parcelle = NULL,
  fenetre = NA,
  cl_sol = 2L,
  cl_veg = c(3L, 4L, 5L),
  epsg = 2154,
  pai_max = 8,
  precomputed = NULL,
  ...
)
```

## Arguments

- dossier_las:

  Directory of classified `.las`/`.laz` tiles covering the parcels plus
  a buffer.

- grille:

  Target grid (`SpatRaster`, typically the working DTM) — the PAI is
  resampled onto it, and (when `parcelle` is `NULL`) its extent bounds
  the LiDAR read window (`-keep_xy`), so only tiles/points over the AOI
  are read.

- res:

  Numeric working resolution in metres (default 2).

- k:

  Beer-Lambert extinction coefficient (default 0.5).

- parcelle:

  Optional `SpatVector`/`sf`: bounds the LiDAR read window (`-keep_xy`,
  buffered) **and** masks the final raster. `NULL` uses `grille`'s
  extent for the read window and applies no final mask.

- fenetre:

  Optional smoothing window in metres (`NA` = none).

- cl_sol, cl_veg:

  ASPRS classes counted as ground / vegetation (defaults `2` and
  `c(3, 4, 5)`).

- epsg:

  CRS forced on the tiles when absent (LiDAR HD = `2154`).

- pai_max:

  Upper clamp on PAI (default 8).

- precomputed:

  Optional pre-built PAI `SpatRaster` or raster path.

- ...:

  Reserved.

## Value

A
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
of PAI (layer `pai`).

## Details

The point-cloud path uses the **`lasR`** pipeline (single read, two
class-filtered rasterizations) and is resampled onto `grille` (the
working DTM). Heavy dependency in `Suggests`, guarded by
`requireNamespace`. When `precomputed` is a `SpatRaster` (or raster file
path) it is returned as-is, so the pipeline can run on a pre-built PAI
without `lasR`.

## See also

[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md),
[`regen_sensibilite`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
