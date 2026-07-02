# Sentinel-2 STAC Search Helpers (E6 monitoring)

Thin STAC clients for Sentinel-2 L2A imagery. Three backends are
supported, with automatic failover:

- **CDSE** — Copernicus Data Space Ecosystem (priority, ADR-008
  souveraineté UE).

- **Planetary Computer** — Microsoft (fallback, resilience).

- **Theia MUSCATE** — CNES / DATA TERRA surface reflectance via the MTD
  STAC API (French-sovereign last-resort fallback, spec 029). Only
  queried when both CDSE and PC fail.

CDSE and PC accept anonymous STAC search; PC additionally signs the COG
hrefs with a SAS token. MUSCATE assets live on the Theia S3 store: their
hrefs are reduced to GDAL-readable \`/vsis3/\` paths and read with
native SigV4 signing (see
[`theia_configure_s3`](https://pobsteta.github.io/nemeton/reference/theia_configure_s3.md)).
The MUSCATE reflectance-asset dialect (\`SRE_B4\`/\`FRE_B4\`/\`B4\`, no
leading zero) is remapped to the nemeton \`B02/B04/…\` band keys so all
three backends return the same normalised scene tibble.

## Usage

``` r
stac_search_s2_cdse(bbox, start, end, max_cloud = 20, limit = 10000L)

stac_search_s2_pc(bbox, start, end, max_cloud = 20, limit = 10000L)

stac_search_s2_theia_muscate(
  bbox,
  start,
  end,
  max_cloud = 20,
  limit = 10000L,
  country = "FR"
)
```

## Arguments

- bbox:

  Numeric length 4: c(xmin, ymin, xmax, ymax) in WGS84.

- start, end:

  Character or Date. Search window bounds, \`"YYYY-MM-DD"\`.

- max_cloud:

  Numeric. Maximum scene cloud cover (percent). Default 20.

- limit:

  Integer. Maximum number of scenes to return. Default \`10000L\`.

- country:

  Character. Country config used to resolve the Theia STAC API endpoint
  and the MUSCATE collection id. Default \`"FR"\`.
