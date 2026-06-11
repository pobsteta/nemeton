# Search Sentinel-2 L2A scenes via STAC

Façade around CDSE (priority) and Planetary Computer (fallback). Returns
a tibble with one row per scene, holding the COG hrefs for bands B04,
B08, B12 (used to derive NDVI and NBR downstream).

## Usage

``` r
stac_search_s2(
  zone,
  start,
  end,
  max_cloud = 20,
  source = c("cdse", "pc"),
  limit = 10000L
)
```

## Arguments

- zone:

  An sf or sfc object covering the area of interest. Re-projected to
  WGS84 internally.

- start, end:

  Date or character \`"YYYY-MM-DD"\`.

- max_cloud:

  Numeric. Maximum scene cloud cover in percent. Default 20.

- source:

  Character vector. Order in which to try backends. Default \`c("cdse",
  "pc")\`.

- limit:

  Integer. Maximum total number of scenes to return per backend (across
  all pagination pages). Default \`10000L\` — covers ~10 years of
  Sentinel-2 revisit at one tile. The backend page size is fixed
  internally at 1000 (the maximum accepted by both CDSE and Planetary
  Computer); pagination follows the STAC \`links\[rel=next\]\`
  convention until the \`limit\` cap is hit or the backend stops
  returning a \`next\` link. Use a smaller value to truncate (e.g.
  \`limit = 50\` for a quick preview).

## Value

A tibble with columns \`scene_id\`, \`obs_date\`, \`cloud_pct\`,
\`href_B04\`, \`href_B08\`, \`href_B12\`, \`source\`. Empty tibble (0
rows) when no scene matches.

## Details

Each backend request is automatically retried on transient HTTP errors
(429, 500, 502, 503, 504) with exponential backoff capped at 60 s.
Default budget is 4 attempts per backend; override with the
\`NEMETON_STAC_MAX_TRIES\` environment variable. When every configured
backend exhausts its retry budget the function emits a single “All STAC
backends failed” warning (in addition to the per-backend warnings) and
returns the canonical empty tibble — callers (e.g. \`nemetonshiny\`) can
use that aggregated warning to render one toast instead of stacking one
per backend.

## Examples

``` r
if (FALSE) { # \dontrun{
library(sf)
aoi <- st_as_sfc(st_bbox(c(xmin = 4.0, ymin = 47.5,
                           xmax = 4.5, ymax = 48.0), crs = 4326))
scenes <- stac_search_s2(aoi, "2025-06-01", "2025-09-30")
} # }
```
