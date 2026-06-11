# Load a raster datasource as a SpatRaster

Resolves a datasource key declared in `inst/datasources/<country>.json`
to a ready-to-use `SpatRaster`. Handles remote Cloud-Optimised GeoTIFF /
VRT sources by prepending `/vsicurl/` so that GDAL reads only the
requested window. If an area of interest is provided, the raster is
cropped to that AOI (reprojected into the raster's native CRS) — which
is the right thing for planet-scale sources like SoilGrids, where
reading the full grid is never desirable.

## Usage

``` r
load_raster_source(
  source_key,
  country = "FR",
  aoi = NULL,
  section = NULL,
  path = NULL
)
```

## Arguments

- source_key:

  Character. The datasource key (e.g., `"soilgrids_cec"`).

- country:

  Character. ISO country code. Default `"FR"`.

- aoi:

  Optional `sf` object. When provided, the returned raster is cropped to
  this AOI (reprojected to the raster's CRS, `snap = "out"`).

- section:

  Character. Configuration section to search in. See
  [`get_data_source`](https://pobsteta.github.io/nemeton/reference/get_data_source.md).

- path:

  Optional character. Explicit path to a raster. Required for
  `raster_local` datasources that carry no declared `path`. It may be a
  local file (which must exist), or a remote / GDAL-virtual path: an
  `s3://bucket/key` URI, an `http(s)://` COG URL, or a `/vsi*` path —
  these are normalised (`s3://` to `/vsis3/`, `http(s)://` to
  `/vsicurl/`) and handed straight to GDAL. Ignored for `raster_remote`
  datasources.

## Value

A `SpatRaster`.

## Details

Supported `type` values: `"raster_remote"` (an `url` field is required),
`"raster_local"` (a `path` field is required, or an explicit `path`
argument). `"raster_local"` entries with no declared path (such as
`chm_opencanopy` or the Theia datasources `forms_t`, `theia_soil`, ...)
are produced or distributed externally: pass the downloaded file via the
`path` argument, or load them from their producing package.

## Examples

``` r
if (FALSE) { # \dontrun{
# Full-planet SoilGrids CEC (reads only the requested window)
aoi <- sf::st_as_sf(data.frame(id = 1), geom = sf::st_sfc(
  sf::st_polygon(list(rbind(
    c(646000, 6848000), c(650000, 6848000),
    c(650000, 6852000), c(646000, 6852000),
    c(646000, 6848000)
  ))), crs = 2154
))
cec <- load_raster_source("soilgrids_cec", "FR", aoi = aoi)

# A Theia product downloaded locally (no declared path)
chm <- load_raster_source(
  "forms_t", "FR",
  path = "~/data/theia/FORMS-T_height_2023.tif"
)
} # }
```
