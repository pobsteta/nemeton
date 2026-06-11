# Observation dates of a persisted CRSWIR stack

Reads the per-band dates of a \`crswir_stack.tif\` written by
\[.write_fordead_model_bundle()\]. \`terra::time()\` is the primary
source; the \`YYYY-MM-DD\` layer names are the fallback (both are set at
write time, but \`time()\` does not always survive a GeoTIFF
round-trip).

## Usage

``` r
.crswir_stack_dates(r)
```

## Arguments

- r:

  A \`terra::SpatRaster\` (the loaded CRSWIR stack).

## Value

A \`Date\` vector of length \`terra::nlyr(r)\`.
