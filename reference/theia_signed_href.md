# Resolve a signed THEIA asset URL via the teledetection gateway

Returns a ready-to-read, signed URL for one asset of a THEIA datasource.
THEIA asset objects require an authenticated, time-limited signed URL
minted by the teledetection signing gateway (a standard AWS SigV4
presign); this is done in pure R via
[`theia_sign_urls`](https://pobsteta.github.io/nemeton/reference/theia_sign_urls.md)
(no Python / reticulate needed). The returned URL is prefixed with
`/vsicurl/` so that
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
reads it directly.

## Usage

``` r
theia_signed_href(
  source_key,
  year = NULL,
  asset = NULL,
  item_id = NULL,
  country = "FR",
  stac_api = NULL
)
```

## Arguments

- source_key:

  Character. Theia datasource key (e.g. `"formspot"`).

- year:

  Optional integer. Target year of an annual collection; the item id and
  asset name are built from the datasource `access$item_id_template` /
  `access$asset_template`.

- asset:

  Optional character. Asset name. Overrides the template-derived name.

- item_id:

  Optional character. STAC item id. Overrides the template-derived id
  (use instead of `year`).

- country:

  Character. ISO country code. Default `"FR"`.

- stac_api:

  Optional character. Overrides the STAC API URL.

## Value

A character scalar: `/vsicurl/`-prefixed signed URL.

## Details

Requirements: a registered THEIA API key in `TLD_ACCESS_KEY` /
`TLD_SECRET_KEY` — see
[`theia_sign_urls`](https://pobsteta.github.io/nemeton/reference/theia_sign_urls.md)
and <https://gate.stac.teledetection.fr>.

## Examples

``` r
if (FALSE) { # \dontrun{
href <- theia_signed_href("formspot", year = 2023)
chm <- terra::rast(href)
} # }
```
