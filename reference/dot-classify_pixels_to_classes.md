# Reclassify a raw FORDEAD \`state.tif\` into the canonical class layer

Maps integer codes 0–4 onto factor levels in \[\`FORDEAD_CLASSES\`\].
Unknown values become NA. Non-anomaly pixels (code \`0\`) are kept as
the first level so that downstream callers can choose to mask them out
explicitly.

## Usage

``` r
.classify_pixels_to_classes(state_raster)
```

## Arguments

- state_raster:

  A \`terra::SpatRaster\` whose values are integer codes in \`0..4\`.

## Value

A \`terra::SpatRaster\` of integer codes in \`0..4\` (with the value
attribute table set to \[\`FORDEAD_CLASSES\`\]). NA for any pixel
outside \`0..4\`.
