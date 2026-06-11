# Look up a RECONFORT model registry entry

Look up a RECONFORT model registry entry

## Usage

``` r
reconfort_model_info(version = "v3")
```

## Arguments

- version:

  Model version, one of the names of
  [`RECONFORT_MODELS`](https://pobsteta.github.io/nemeton/reference/RECONFORT_MODELS.md)
  (\`"v3"\`, \`"v3_early_may"\`, \`"v3_chestnut"\`, \`"v3_pine"\`).

## Value

The registry list entry (\`label\`, \`species\`, \`n_classes\`,
\`size_bytes\`, \`md5\`).
