# Sign THEIA object URLs via the teledetection signing gateway

THEIA / DATA TERRA assets (MUSCATE Sentinel-2, FORMS, …) live on the
MESO@UM S3 store but are **not** readable with the portal API key
directly: the store only recognises **pre-signed URLs** minted by the
teledetection signing gateway (`signing.stac.teledetection.fr`), the
same model as Planetary Computer's SAS tokens. This function POSTs the
object URLs to the gateway (authenticated with the API key sent as
`access-key` / `secret-key` headers) and returns short-lived pre-signed
URLs (`X-Amz-*` query string, ~8 h) that GDAL reads with `/vsicurl/` —
no
[`theia_configure_s3`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)
needed.

## Usage

``` r
theia_sign_urls(
  urls,
  access_key = NULL,
  secret_key = NULL,
  endpoint = NULL,
  country = "FR"
)
```

## Arguments

- urls:

  Character vector of `https://<...>.meso.umontpellier.fr/...` object
  URLs to sign. Non-MESO URLs are returned unchanged.

- access_key, secret_key:

  THEIA API key pair (default the `TLD_ACCESS_KEY` / `TLD_SECRET_KEY`
  environment variables; create one at
  <https://gate.stac.teledetection.fr>).

- endpoint:

  Signing gateway base URL (default `services$theia_signing$endpoint`
  from the country config, else
  `https://signing.stac.teledetection.fr`).

- country:

  Country config key (default `"FR"`).

## Value

A named character vector mapping each input URL to its signed
counterpart (names are the original URLs), in the input order.

## See also

[`theia_configure_s3`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md),
[`resolve_theia_assets`](https://pobsteta.github.io/nemeton/reference/resolve_theia_assets.md)
