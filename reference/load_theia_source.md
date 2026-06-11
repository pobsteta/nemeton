# Load a THEIA datasource as a SpatRaster

Loads a Theia datasource for an area of interest and crops it to the
AOI. Two modes:

- **Year targeting** (`year` supplied) — the asset URL is signed through
  the `teledetection` SDK (see
  [`theia_signed_href`](https://pobsteta.github.io/nemeton/reference/theia_signed_href.md))
  and read via `/vsicurl/`. This is the authenticated path that THEIA
  assets require.

- **Spatial search** — resolves `/vsis3/` asset paths via
  [`resolve_theia_assets`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md);
  call
  [`theia_configure_s3`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
  first. Reserved for direct-S3 setups.

## Usage

``` r
load_theia_source(
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

A `SpatRaster` cropped to `aoi`.

## Examples

``` r
if (FALSE) { # \dontrun{
# FORMSpoT canopy height for 2023 (signed via the teledetection SDK)
chm <- load_theia_source("formspot", aoi, year = 2023)
} # }
```
