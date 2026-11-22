# Path of the cached E-OBS daily series

Where
[`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)
(`source = "cds"`) keeps the downloaded E-OBS series of one variable,
and whether it is there. Since November 2026 the CDS delivers the whole
series (1950 onwards) in a single netCDF per variable (about 4.3 GB at
0.1°), so callers should share one cache — the default, under
[`get_global_cache_dir()`](https://pobsteta.github.io/nemeton/reference/get_global_cache_dir.md)
— instead of downloading it once per project.

## Usage

``` r
eobs_cached_file(
  var = "tx",
  version = "34.0e",
  resolution = "0.1deg",
  cache_dir = NULL
)
```

## Arguments

- var:

  E-OBS variable: `"tx"`, `"tg"`, `"tn"` or `"rr"`.

- version, resolution:

  As in
  [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md).

- cache_dir:

  As in
  [`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md);
  `NULL` (default) is the global E-OBS cache.

## Value

The netCDF path when the series is cached, otherwise `NULL`.

## Lifecycle

Experimental.

## See also

[`load_eobs_source()`](https://pobsteta.github.io/nemeton/reference/load_eobs_source.md)
