# Resolve the AOI sf POLYGON of a monitoring zone (EPSG:2154)

Queries \`monitoring_zone\` for the zone's WKT + CRS, parses it via
\`sf::st_as_sfc()\`, and reprojects to Lambert-93 if needed. Errors out
with a typed message when the zone is unknown so the caller surfaces an
actionable message rather than an empty sf.

## Usage

``` r
.get_zone_aoi(con, zone_id)
```

## Arguments

- con:

  A \`DBIConnection\`.

- zone_id:

  Integer scalar identifying the row in \`monitoring_zone\`.

## Value

An \`sf\` POLYGON in EPSG:2154 (Lambert-93).

## Details

Used as the single source of truth for the AOI of both the FORDEAD
pipeline (\[run_fordead_dieback()\]) and the FAST surveillance pipeline
(\[ingest_sentinel2_timeseries()\], \[ingest_s2_raw_bands_to_cache()\])
since spec 012. Sharing this resolver guarantees that both pipelines
read the \*same\* COG crop, so the on-disk S2 cache is reused across
them (a FORDEAD pre-fetch warms the FAST cache and vice versa).
