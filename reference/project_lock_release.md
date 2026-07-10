# Release a project lock

Delete the lock on `project_id` **only if** `holder_id` holds it.
Idempotent: releasing a lock you do not hold (or that is already gone)
is a safe no-op.

## Usage

``` r
project_lock_release(con, project_id, holder_id)
```

## Arguments

- con:

  A `DBIConnection`.

- project_id:

  Application project identifier.

- holder_id:

  The holder releasing its lock.

## Value

`TRUE` if a lock was released, `FALSE` otherwise.

## See also

[`project_lock_acquire`](https://pobsteta.github.io/nemeton/reference/project_lock_acquire.md)
