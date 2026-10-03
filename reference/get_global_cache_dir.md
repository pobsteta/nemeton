# Get global shared cache directory

Returns the path to a global cache directory shared across all projects.
Used for large datasets like OSO, TWI caches, and nasapower wind data.

The environment variable `NEMETON_CACHE_DIR`, when set, takes precedence
(used by the test suite to stay out of the user's real cache).

## Usage

``` r
get_global_cache_dir()
```

## Value

Character. Path to the global cache directory.
