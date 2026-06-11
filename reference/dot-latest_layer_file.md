# Path to the most recent fordead-written file for a layer

Path to the most recent fordead-written file for a layer

## Usage

``` r
.latest_layer_file(output_dir, layer)
```

## Arguments

- output_dir:

  Character(1). Root output directory of a \`FordeadProcess\` run.

- layer:

  Character(1). Layer name (e.g. \`"ANOMALY_CONFIRMED"\`,
  \`"ANOMALY_INDEX"\`, \`"CONSECUTIVE_DETECTIONS"\`).

## Value

Character(1) absolute path, or \`NA_character\_\` when the layer
directory is missing or empty.
