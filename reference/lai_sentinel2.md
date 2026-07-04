# LAI from Sentinel-2 via PROSAIL inversion — NDP-0 canopy fallback (spec 033)

Retrieve a **LAI** raster over `aoi` from **Sentinel-2 L2A** by
**PROSAIL hybrid inversion** (`prosail`), as the NDP-0 fallback for the
reGénération canopy inputs when LiDAR HD is absent — `lai_max` of
[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md)
(direct fit) and, as a degraded proxy, `pai` of
[`regen_sensibilite`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md)
(LAI is leaves only; PAI includes wood). **NDP ≥ 1 always keeps the
structural LiDAR PAI of
[`pai_depuis_nuage`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md).**

## Usage

``` r
lai_sentinel2(
  aoi = NULL,
  refl = NULL,
  start = NULL,
  end = NULL,
  reducer = "p90",
  source = "muscate",
  sensor = "Sentinel_2A",
  selected_bands = c("B3", "B4", "B8"),
  geom_acq = NULL,
  mask = NULL,
  cache_dir = NULL,
  precomputed = NULL,
  ...
)
```

## Arguments

- aoi:

  An `sf`/`sfc` extent (used by the MUSCATE auto-fetch path).

- refl:

  S2 L2A reflectance for the engine path: a `SpatRaster` (bands in `srf`
  order) or a file path / vector of paths (one per date). When `NULL`, a
  best-effort MUSCATE fetch is attempted over `aoi`/`start`/`end`.

- start, end:

  Date bounds (`"YYYY-MM-DD"`) for the S2 search.

- reducer:

  Temporal reducer over dates: `"p90"` (default, D1), `"max"`,
  `"median"` or `"mean"`.

- source:

  S2 STAC backend (default `"muscate"`, spec 029).

- sensor:

  PROSAIL sensor SRF: `"Sentinel_2A"` (default), `"Sentinel_2B"`.

- selected_bands:

  S2 bands used for the LAI inversion (default `c("B3","B4","B8")`).

- geom_acq:

  Optional acquisition-geometry range (`list(min=, max=)` of
  `data.frame(tto, tts, psi)`); default a France-summer range.

- mask:

  Optional cloud/shadow mask raster path for the application.

- cache_dir:

  Directory for the trained model and intermediate rasters (default: a
  session temp dir).

- precomputed:

  Optional pre-computed LAI (`SpatRaster` or file path).

- ...:

  Reserved.

## Value

A single-layer LAI `SpatRaster` (`lai`), or `NULL` on degradation (no
`prosail`, no scene, engine failure).

## Details

**Two paths.** *Fast-path*: pass `precomputed` (a LAI `SpatRaster`, or a
multi-date stack) and only the temporal reduction (`reducer`, default
`"p90"`) is applied. *Engine path*: trains the PROSAIL hybrid model for
the S2 sensor/geometry (cached in `cache_dir`), applies it to the S2
reflectance raster(s) `refl`, and reduces the per-date LAI to one layer.
Needs `prosail` + real S2 scenes and is **not runnable in CI** — the
engine is validated on real data (training verified; application per the
official tutorial).

## See also

[`regen_bilan_hydrique`](https://pobsteta.github.io/nemeton/reference/regen_bilan_hydrique.md),
[`regen_sensibilite`](https://pobsteta.github.io/nemeton/reference/regen_sensibilite.md),
[`pai_depuis_nuage`](https://pobsteta.github.io/nemeton/reference/pai_depuis_nuage.md)
