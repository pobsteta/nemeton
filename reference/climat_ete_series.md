# Summer climate series on a circle around the project (E-OBS, CHELSA, SAFRAN)

Per-year **summer** maximum temperature and precipitation on a circle of
`rayon_km` around the project centroid, at the **native resolution** of
the source (no downscaling, spec 063): E-OBS 0.1° (EPSG:4326), CHELSA
v2.1 30″ (~1 km, EPSG:4326) or SAFRAN 8 km (EPSG:2154, metropolitan
France only). Tmax is the mean of the monthly means of `mois`,
precipitation the sum of the monthly totals; only years where every
month of `mois` is complete are kept. Cells touching the circle are kept
whole.

Acquisition:

- **E-OBS**: full daily files from KNMI (`version`, default `"33.0e"`,
  resumable download, no key), aggregated **once** into monthly France
  GeoTIFFs in a machine-wide cache (`eobs_cache_dir`, default
  `file.path(get_global_cache_dir(), "eobs")`); falls back to the CDS
  ([`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)
  key) when KNMI is unreachable. Each project then crops the cached
  GeoTIFF. Licence: non-commercial use.

- **CHELSA**: remote reads (`/vsicurl/`) of the monthly COGs, cropped to
  the circle, cached per project and circle (`cache_dir`).

- **SAFRAN**: GéoSAS OGC-EDR API (INRAE), one request per month on the
  circle's Lambert-93 bounding box, cached per summer.

## Usage

``` r
climat_ete_series(
  aoi,
  source = c("eobs", "chelsa", "safran"),
  rayon_km = 25,
  mois = 5:9,
  annees = NULL,
  cache_dir = NULL,
  eobs_cache_dir = NULL,
  version = "33.0e",
  progress_callback = NULL,
  ...
)
```

## Arguments

- aoi:

  An `sf`/`sfc` of the project units (the circle is centred on the
  centroid of their union).

- source:

  `"eobs"`, `"chelsa"` or `"safran"`.

- rayon_km:

  Circle radius in kilometres (default 25).

- mois:

  Summer months (default `5:9`, May to September).

- annees:

  Optional years; default all available (E-OBS 1950-, CHELSA 1979-2021,
  SAFRAN 1959 to the last complete summer).

- cache_dir:

  Optional project cache directory. When given, CHELSA months and SAFRAN
  summers are cached under `cache_dir/climat/<source>/<key>/`, and the
  resulting series are written as `<key>_tx.tif`, `<key>_rr.tif`,
  `<key>_cercle.gpkg` and `<key>.meta.json` under `cache_dir/climat/`
  (reused on later calls). The key encodes source, radius, months and
  circle centre.

- eobs_cache_dir:

  Machine-wide E-OBS cache (see above).

- version:

  E-OBS version for the KNMI files (default `"33.0e"`).

- progress_callback:

  Optional function receiving `list(current = <step>, ...)` payloads:
  `"climat:cache_hit"`, `"climat:telechargement"` (`var`, `file`,
  `essai`), `"climat:mensualisation"` and `"climat:annee"` (`annee`,
  `i`, `n`), `"climat:complete"`, `"climat:indisponible"` (`reason`,
  `message`).

- ...:

  Reserved.

## Value

`list(tx, rr, cercle, meta)`: `tx` and `rr` are `SpatRaster`s with one
layer per year (named by year), `NULL` unless `meta$status == "ok"`;
`cercle` is the circle (`sf`, EPSG:4326); `meta` holds `status` (`"ok"`,
`"hors_couverture"`, `"indisponible"`, `"donnees_insuffisantes"`),
`reason`, `source`, `resolution_native`, `annees`, `mois`, `crs`,
`rayon_km`, `centre` (lon, lat), `attribution` and `fichiers` (cached
paths, when `cache_dir` is given).

## Lifecycle

Experimental: may change in any release, without deprecation (spec 057).

## See also

[`climat_tendance_bivariee()`](https://pobsteta.github.io/nemeton/reference/climat_tendance_bivariee.md),
[`climat_nuages_annuels()`](https://pobsteta.github.io/nemeton/reference/climat_nuages_annuels.md)
