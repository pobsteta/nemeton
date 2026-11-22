# Stop a capped run

Stops the run named by a marker written by
[`run_memory_capped()`](https://pobsteta.github.io/nemeton/reference/run_memory_capped.md)
(`marker_path =`): `systemctl --user stop` on its scope, or — without
systemd — `SIGTERM` to its process. The caller of
[`run_memory_capped()`](https://pobsteta.github.io/nemeton/reference/run_memory_capped.md)
then sees its child fail, as for any other external stop.

## Usage

``` r
stop_memory_capped(marker_path, timeout = 10)
```

## Arguments

- marker_path:

  Path of the JSON run marker.

- timeout:

  Seconds to wait for the run to be gone.

## Value

`TRUE` (invisibly) when a live run was stopped, `FALSE` when there was
nothing to stop.

## Lifecycle

Experimental.

## See also

[`capped_run_alive()`](https://pobsteta.github.io/nemeton/reference/capped_run_alive.md),
[`run_memory_capped()`](https://pobsteta.github.io/nemeton/reference/run_memory_capped.md)
