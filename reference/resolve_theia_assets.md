# Resolve the asset paths of a THEIA datasource

Looks up a Theia datasource declared in
`inst/datasources/<country>.json` and returns GDAL-readable paths to the
matching assets. Each asset is signed through the teledetection gateway
([`theia_sign_urls`](https://pobsteta.github.io/nemeton/reference/theia_sign_urls.md),
keys `TLD_ACCESS_KEY` / `TLD_SECRET_KEY`) and returned as a `/vsicurl/`
pre-signed URL, the only form the MESO store accepts. When signing is
unavailable (no keys, gateway down) the unsigned `/vsis3/` paths are
returned instead; they are only readable on a direct-S3 setup.

Two access modes:

- **Year targeting** — when `year` is supplied and the datasource
  declares an `access$item_id_template` (such as FORMSpoT, one item per
  year), the matching item is fetched directly by id and a single asset
  path is returned.

- **Spatial search** — otherwise, the THEIA STAC API is searched for
  items of the collection intersecting `aoi`.

## Usage

``` r
resolve_theia_assets(
  source_key,
  aoi,
  asset = NULL,
  year = NULL,
  datetime = NULL,
  country = "FR",
  stac_api = NULL,
  limit = 50L
)
```

## Arguments

- source_key:

  Character. Theia datasource key (e.g. `"forms_t"`). Its
  `access$stac_collection` field provides the STAC collection id.

- aoi:

  An `sf`/`sfc` area of interest. Used for the spatial search; ignored
  in year-targeting mode.

- asset:

  Optional character. Name of the STAC asset to resolve. When `NULL`: in
  year mode the `access$asset_template` (with `{year}` substituted) is
  used; otherwise the first `"data"`-role asset.

- year:

  Optional integer. Target a single year of an annual time-series
  collection. Requires the datasource to declare
  `access$item_id_template`.

- datetime:

  Optional character. STAC datetime filter (see
  [`stac_search_items`](https://pobsteta.github.io/nemeton/reference/stac_search_items.md)).

- country:

  Character. ISO country code. Default `"FR"`.

- stac_api:

  Optional character. Overrides the STAC API URL read from
  `services$theia_stac`.

- limit:

  Integer. Maximum number of items to resolve in search mode. Default
  `50`.

## Value

A character vector of asset paths (length 1 in year-targeting mode):
signed `/vsicurl/` URLs, or unsigned `/vsis3/` paths when signing is
unavailable.
