# Assemble the masked observed-CRSWIR stack (spec 008 §14.3)

Stacks every per-date \`CRSWIR\` raster fordead 2.x wrote into one
multiband \`SpatRaster\`, masks each band with the matching
\`INVALID_PIXEL_MASK\` (cloud / shadow / soil — values \`\> 0\` become
\`NA\`), and tags \`terra::time()\` with the observation dates. This is
the CRSWIR series exactly as FORDEAD modelled it, ready to be persisted
as \`crswir_stack.tif\` in the diagnostic bundle.

## Usage

``` r
.build_crswir_masked_stack(output_dir)
```

## Arguments

- output_dir:

  Character(1). Root FordeadProcess output dir.

## Value

A \`terra::SpatRaster\`, one band per observation date with
\`terra::time()\` set, or \`NULL\` when no \`CRSWIR\` layer exists.

## Details

Dates with no \`INVALID_PIXEL_MASK\` counterpart are persisted unmasked
(best-effort — the raw CRSWIR is still informative) with a warning.
