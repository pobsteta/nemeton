# Configure GDAL for authenticated THEIA S3 reads

The THEIA / FORMS COG and VRT assets live on an S3-compatible (MinIO)
object store. This helper sets the GDAL configuration options so that
`terra`/GDAL can read `/vsis3/` paths with native SigV4 signing — call
it once per session before
[`load_theia_source`](https://pobsteta.github.io/nemeton/reference/load_theia_source.md).

## Usage

``` r
theia_configure_s3(access_key = NULL, secret_key = NULL, country = "FR")
```

## Arguments

- access_key, secret_key:

  Character. THEIA S3 credentials. When `NULL` (default) they are read
  from `TLD_ACCESS_KEY` and `TLD_SECRET_KEY`.

- country:

  Character. ISO country code. Default `"FR"`.

## Value

`TRUE` invisibly on success.

## Details

Credentials are never stored in the package. They are read from the
`TLD_ACCESS_KEY` and `TLD_SECRET_KEY` environment variables — the same
THEIA API-key pair used by the `teledetection` SDK (create one at
<https://gate.stac.teledetection.fr>, set it in a gitignored
`.Renviron`) — or passed explicitly. The non-secret S3 endpoint, region
and options are read from the `services$theia_s3` entry of the country
configuration.

## Examples

``` r
if (FALSE) { # \dontrun{
theia_configure_s3()
chm <- load_theia_source("formspot", aoi, asset = "height_2023")
} # }
```
