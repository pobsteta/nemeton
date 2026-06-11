# All fordead-written \`.tif\` files for a layer, sorted by embedded date

fordead 2.x writes per-date layers under
\`\<out_dir\>/\<LAYER\>/fordead\_\<YYYYMMDD\>\_\<LAYER\>.tif\`. This
helper lists them ordered by \`YYYYMMDD\` ascending.

## Usage

``` r
.list_layer_files(output_dir, layer)
```

## Arguments

- output_dir:

  Character(1). Root output directory of a \`FordeadProcess\` run.

- layer:

  Character(1). Layer name (e.g. \`"ANOMALY_CONFIRMED"\`,
  \`"ANOMALY_INDEX"\`, \`"CONSECUTIVE_DETECTIONS"\`).

## Value

Character vector of absolute paths, possibly empty. Always sorted by
ascending date.
