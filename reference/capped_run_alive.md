# Is a capped run still alive?

Reads the run marker written by
[`run_memory_capped()`](https://pobsteta.github.io/nemeton/reference/run_memory_capped.md)
(`marker_path =`) and asks systemd — or, without systemd, the process
table — whether that run is still going. A stale marker (its run is
gone) is removed.

## Usage

``` r
capped_run_alive(marker_path)
```

## Arguments

- marker_path:

  Path of the JSON run marker.

## Value

The marker as a list (`unit`, `pid`, `parent_pid`, `fun`, `package`,
`started`) when the run is alive, otherwise `NULL`.

## Lifecycle

Experimental.

## See also

[`stop_memory_capped()`](https://pobsteta.github.io/nemeton/reference/stop_memory_capped.md),
[`run_memory_capped()`](https://pobsteta.github.io/nemeton/reference/run_memory_capped.md)
