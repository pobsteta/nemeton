# Refresh the heartbeat on a held project lock

Set `heartbeat_at = now()` for `project_id` **only if** `holder_id`
still holds it. A no-op otherwise. The app calls this periodically
(every ~30–60 s) so the lock survives past `ttl_seconds`.

## Usage

``` r
project_lock_heartbeat(con, project_id, holder_id)
```

## Arguments

- con:

  A `DBIConnection`.

- project_id:

  Application project identifier.

- holder_id:

  The holder refreshing its lock.

## Value

`TRUE` if the lock is held by `holder_id` after the call (heartbeat
refreshed), `FALSE` if `holder_id` does not hold it.

## See also

[`project_lock_acquire`](https://pobsteta.github.io/nemeton/reference/project_lock_acquire.md)
