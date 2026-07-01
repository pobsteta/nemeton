# RECONFORT Random-Forest model registry

Metadata for the four RECONFORT models versioned in the upstream
repository (\`fl.mouret/reconfort\`, Apache-2.0). Each entry carries the
calibrated species, number of classes, the file size, the MD5 checksum
used by
[`ensure_reconfort_model`](https://pobsteta.github.io/nemeton/reference/ensure_reconfort_model.md)
to verify a fetch, and \`edate\` – the \`"MM-DD"\` end of the
model-bound analysis window within \`s2_year\` (\`10-29\` for the 2-year
models, \`05-31\` for the 1.5-year \`v3_early_may\`). \`edate\` is what
[`reconfort_latest_complete_year`](https://pobsteta.github.io/nemeton/reference/reconfort_latest_complete_year.md)
uses to tell whether a given \`s2_year\` season is already complete.

## Usage

``` r
RECONFORT_MODELS
```

## Details

- v3:

  Oak (*Quercus*), 2-year series, 3 classes.

- v3_early_may:

  Oak, 1.5-year series (Jan-\>May), 3 classes.

- v3_chestnut:

  Sweet chestnut (*Castanea*), 3 classes.

- v3_pine:

  Scots pine (*Pinus sylvestris*), 2 classes.
