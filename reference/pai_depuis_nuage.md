# Plant Area Index from a LiDAR-HD point cloud (spec 027 L1)

Wall-to-wall **PAI** raster from a classified LiDAR-HD point cloud
(`.laz`), via gap-fraction + Beer-Lambert (`lasR`/`lidR`). The PAI feeds
the `lai_max` of
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
(PAI ≈ LAI only for a leaves-on acquisition, spec 027 §9.3).

## Usage

``` r
pai_depuis_nuage(
  dossier_las = NULL,
  grille = NULL,
  res = 2,
  k = 0.5,
  precomputed = NULL,
  ...
)
```

## Arguments

- dossier_las:

  Directory of classified `.laz` tiles (engine path).

- grille:

  Target grid (`SpatRaster` template).

- res:

  Numeric working resolution in metres (default 2).

- k:

  Beer-Lambert extinction coefficient (default 0.5).

- precomputed:

  Optional pre-built PAI `SpatRaster` or raster path.

- ...:

  Reserved (engine parameters).

## Value

A
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
of PAI.

## Details

**Scaffold with a pass-through**: when `precomputed` is a `SpatRaster`
(or a raster file path), it is returned as the PAI. Otherwise the
point-cloud processing needs `lasR`/`lidR` and is not yet wired.

## See also

[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
