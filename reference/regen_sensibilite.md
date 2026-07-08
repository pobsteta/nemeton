# Microclimate exposure per unit — microclimf engine (spec 027 L1)

Per-unit summer under-canopy exposure (T°max, VPD, canopy buffering,
heatwave-vs-average sensitivity, robustness) from the mechanistic
**microclimf** model driven by LiDAR-HD structure and ERA5-Land forcing.
Produces the §7 exposure columns consumed by
[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md).

## Usage

``` r
regen_sensibilite(
  units,
  mnt = NULL,
  mnh = NULL,
  las = NULL,
  annees_moy = NULL,
  annees_canic = NULL,
  mois_ete = 6:8,
  res = 2,
  tampon = 150,
  reqhgt = 0.5,
  k = 0.5,
  pai = NULL,
  pai_cache = NULL,
  cache_dir = NULL,
  progress_callback = NULL,
  precomputed = NULL,
  ...
)
```

## Arguments

- units:

  An `sf` of UGF.

- mnt, mnh:

  Optional LiDAR-HD DTM / canopy-height inputs for the engine path: a
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
  or a directory of `.tif` tiles (VRT-mosaicked).

- las:

  Optional directory of classified LiDAR `.las`/`.laz` tiles (PAI via
  [`pai_depuis_nuage`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)).

- annees_moy, annees_canic:

  Integer years for the average / heatwave summers (engine path). See
  [`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md).

- mois_ete:

  Integer months of the summer window (default `6:8`).

- res:

  Target grid resolution in metres (default `2`).

- tampon:

  Buffer in metres around the units for the working extent (default
  `150`).

- reqhgt:

  Height (m) above ground for the microclimate (default `0.5`).

- k:

  Beer-Lambert extinction coefficient for PAI (default `0.5`).

- pai:

  Optional canopy `SpatRaster` to use instead of the LiDAR PAI. The
  NDP-0 fallback: a Sentinel-2/PROSAIL LAI from
  [`lai_sentinel2`](https://pobsteta.github.io/nemeton/reference/lai_sentinel2.md)
  (degraded proxy — LAI ≠ structural PAI). When supplied, `las` is not
  required.

- pai_cache:

  Optional path to a GeoTIFF caching the LiDAR-derived PAI. The PAI
  depends only on the point cloud and the working grid (invariant for a
  given project / AOI / `res`), yet
  [`pai_depuis_nuage`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)
  is the slowest step before ERA5. When the file exists **and** its
  geometry matches the working grid it is read back (no recompute);
  otherwise the PAI is computed and written there. A geometry mismatch
  (AOI / `res` changed) invalidates it (recompute + overwrite). Ignored
  when `pai` is supplied. `NULL` (default) disables caching — the
  v0.144.x behaviour.

- cache_dir:

  Directory for the ERA5 `.nc` and per-year microclimate `.tif` caches.
  `NULL` (default) uses a session temp dir; pass a persistent path to
  reuse expensive runs.

- progress_callback:

  Optional function called at each step with a
  `list(current = <key>, …)` payload (monitoring pattern). Keys:
  `"regen_expo:pai"` (`source` = `"lidar"`/`"cache"`/`"raster"`, once,
  when the vegetation-structure PAI is built/read),
  `"regen_expo:microclimf"` (`category`), `"regen_expo:era5"`
  (`category`/`year`/`i`/`n`, once per reference year) and
  `"regen_expo:complete"`. No-op when `NULL`; never fatal. The monthly
  ERA5 split is internal to `mcera5`.

- precomputed:

  Optional per-unit microclimf output (`data.frame`/list).

- ...:

  Reserved (engine parameters).

## Value

`units` with the §7 exposure columns (`tmax_moyenne`, `tmax_canicule`,
`vpd_moyenne`, `vpd_canicule`, `d_tmax`, `d_vpd`, `sensibilite`,
`rang_sensibilite`, `robustesse`, `signal_robuste`, `couverture_pct`),
plus `parcelle_sensible` / `priorite`.

## Details

**Two paths.** *Fast-path*: pass `precomputed` (a microclimf run output)
and the metrics are attached as §7 columns without the GPL engine;
missing `d_tmax`/`d_vpd` are derived from the canicule − moyenne
difference, and `rang_sensibilite` from `sensibilite` (1 = most
sensitive). *Engine path* (portage of the prototype
`microclimat_parcelles_robuste.R`): builds the fixed LiDAR-HD grid (DTM,
canopy height, PAI via
[`pai_depuis_nuage`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)),
runs **microclimf** per year forced by ERA5-Land (`mcera5`) with disk
caching, averages the average vs heatwave summers (canopy held fixed),
and aggregates ΔT°max / ΔVPD, a z-score `sensibilite` and a signal/noise
`robustesse` per unit. The engine path needs LiDAR HD + ERA5/CDS and is
**not runnable in CI** — validated on real data.

## See also

[`indice_priorite_regen`](https://pobsteta.github.io/nemeton/reference/indice_priorite_regen.md),
[`microclimate_detect_years`](https://pobsteta.github.io/nemeton/reference/microclimate_detect_years.md),
[`pai_depuis_nuage`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)
