# Inspect the lock state of a project

Read-only lookup of who holds `project_id`. Returns `NULL` when the
project is **free** (no lock row). When a lock exists, returns its
holder and stamps plus a `stale` flag (`TRUE` when the heartbeat is
older than `ttl_seconds`), so the caller can tell **free** (`NULL`),
**held-fresh** (`stale = FALSE`) and **held-expired** (`stale = TRUE`)
apart.

## Usage

``` r
project_lock_status(con, project_id, ttl_seconds = 120L)
```

## Arguments

- con:

  A `DBIConnection`.

- project_id:

  Application project identifier.

- ttl_seconds:

  Heartbeat time-to-live used to compute `stale` (default 120).

## Value

`NULL` if the project is free, otherwise a list `holder_id`,
`holder_label`, `acquired_at`, `heartbeat_at`, `stale`.

## See also

[`project_lock_acquire`](https://pobsteta.github.io/nemeton/reference/project_lock_acquire.md)
