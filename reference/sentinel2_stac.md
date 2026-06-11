# Sentinel-2 STAC Search Helpers (E6 monitoring)

Thin STAC clients for Sentinel-2 L2A imagery. Two backends are
supported, with automatic failover:

- **CDSE** — Copernicus Data Space Ecosystem (priority, ADR-008
  souveraineté UE).

- **Planetary Computer** — Microsoft (fallback, resilience).

Both endpoints accept anonymous STAC search; PC additionally signs the
COG hrefs with a SAS token before returning them so that
\`terra::rast(href)\` reads work without further authentication.

## Usage

``` r
stac_search_s2_cdse(bbox, start, end, max_cloud = 20, limit = 10000L)

stac_search_s2_pc(bbox, start, end, max_cloud = 20, limit = 10000L)
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
