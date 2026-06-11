# Resolve a signed THEIA asset URL via the teledetection SDK

Returns a ready-to-read, signed URL for one asset of a THEIA datasource.
THEIA asset objects require an authenticated, time-limited signed URL;
the signing is delegated to the official `teledetection` Python SDK
through reticulate (the `tld.sign_inplace` pystac modifier — a standard
AWS SigV4 presign). The returned URL is prefixed with `/vsicurl/` so
that
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

Requirements: reticulate, plus the Python packages `teledetection` and
`pystac_client` (declared via
[`reticulate::py_require()`](https://rstudio.github.io/reticulate/reference/py_require.html)
automatically), and a registered THEIA API key — see
[`theia_configure_s3`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
and <https://gate.stac.teledetection.fr>.

## Examples

``` r
if (FALSE) { # \dontrun{
href <- theia_signed_href("formspot", year = 2023)
chm <- terra::rast(href)
} # }
```
