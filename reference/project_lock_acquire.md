# Acquire the edit lock on a project

Try to take the single-writer edit lock on `project_id` for `holder_id`.
Succeeds when the project is **free**, **already held by `holder_id`**
(re-entrant — the heartbeat is refreshed), or **held by a lock whose
heartbeat is older than `ttl_seconds`** (expired — the lock is stolen).
Fails when another holder's lock is still fresh.

The whole decision runs in one transaction with a row lock (`FOR UPDATE`
on PostgreSQL), so two concurrent acquisitions on a free project yield
exactly one winner. Expiry is judged against the database clock.

## Usage

``` r
project_lock_acquire(
  con,
  project_id,
  holder_id,
  holder_label = NULL,
  ttl_seconds = 120L
)
```

## Arguments

- con:

  A `DBIConnection` (PostgreSQL server, or SQLite for local/test).

- project_id:

  Application project identifier (string).

- holder_id:

  Stable identity of the acquirer (e.g. OAuth email).

- holder_label:

  Optional display name shown to other users.

- ttl_seconds:

  Heartbeat time-to-live in seconds (default 120). A lock whose last
  heartbeat is older than this is stealable.

## Value

On success, a list `ok = TRUE`, `holder_id`, `holder_label`,
`acquired_at`, `heartbeat_at`, `stolen` (TRUE when an expired lock was
taken over). On failure, `ok = FALSE` with the current holder's
`holder_id`, `holder_label`, `heartbeat_at`.

## See also

[`project_lock_heartbeat`](https://pobsteta.github.io/nemeton/reference/project_lock_heartbeat.md),
[`project_lock_release`](https://pobsteta.github.io/nemeton/reference/project_lock_release.md),
[`project_lock_status`](https://pobsteta.github.io/nemeton/reference/project_lock_status.md)
