# project_lock.R — table-backed, heartbeat-based project lock for the
# multi-user server deployment. Spec: brief-core-project-lock.
# ------------------------------------------------------------------
# One project is edited by at most one user; others open it read-only. The
# lock lives in the `project_lock` table (migration 0008), NOT in a
# `pg_advisory_lock` — the app opens/closes its connection per operation, so
# an advisory lock (tied to the connection) would be released immediately.
# Tenure across a whole Shiny session is held by a periodic heartbeat; a
# lock whose heartbeat is older than `ttl_seconds` is considered expired and
# may be stolen. Expiry is evaluated AT READ TIME against the DB clock — no
# expiry column, no cleanup job.
#
# All four functions take a caller-supplied `con` (the app owns the pool) and
# work on both backends (PostgreSQL = the server target, SQLite = local/test).

# Validate the common arguments. `con` must be a live DBI connection; the two
# ids must be non-empty scalar strings.
.assert_lock_args <- function(con, project_id, holder_id = NULL) {
  if (!requireNamespace("DBI", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg DBI} required. Install with {.code install.packages('DBI')}.")
  }
  if (!methods::is(con, "DBIConnection")) {
    cli::cli_abort("{.arg con} must be a {.cls DBIConnection}.")
  }
  ok_id <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  if (!ok_id(project_id)) {
    cli::cli_abort("{.arg project_id} must be a non-empty single string.")
  }
  if (!is.null(holder_id) && !ok_id(holder_id)) {
    cli::cli_abort("{.arg holder_id} must be a non-empty single string.")
  }
  invisible(TRUE)
}

.lock_is_pg <- function(con) inherits(con, "PqConnection")

# `NOW()` (pg) / `CURRENT_TIMESTAMP` (sqlite) — the DB clock is authoritative,
# so a skew between the app host and the DB host never mis-times a lock.
.lock_now_sql <- function(con) if (.lock_is_pg(con)) "NOW()" else "CURRENT_TIMESTAMP"

.lock_ttl <- function(ttl_seconds) {
  ttl <- suppressWarnings(as.numeric(ttl_seconds))
  if (length(ttl) != 1L || is.na(ttl) || ttl <= 0) {
    cli::cli_abort("{.arg ttl_seconds} must be a single positive number.")
  }
  ttl
}

# SQL predicate, TRUE when the row's heartbeat is older than `ttl` seconds.
# `ttl` is a validated positive number (see .lock_ttl) and is interpolated
# directly — NOT bound as a parameter. This is deliberate: the stale predicate
# sits in the SELECT list, ahead of the `WHERE project_id = $1` placeholder, and
# RSQLite binds an unnamed params list in textual order of appearance. A bound
# `$2` here would take the first slot and misalign project_id. Interpolating a
# validated double keeps every statement on a single, first-position parameter.
.lock_stale_sql <- function(con, ttl) {
  if (.lock_is_pg(con)) {
    sprintf("heartbeat_at < NOW() - make_interval(secs => %.6f)", ttl)
  } else {
    sprintf("heartbeat_at < datetime('now', '-%.6f seconds')", ttl)
  }
}

.lock_na_chr <- function(x) if (length(x) == 0L || is.na(x)) NA_character_ else as.character(x)

# Canonical row read (post-mutation), for authoritative timestamps. Portable —
# avoids relying on RETURNING grammar across backends.
.lock_read <- function(con, project_id) {
  DBI::dbGetQuery(
    con,
    "SELECT holder_id, holder_label, acquired_at, heartbeat_at
       FROM project_lock WHERE project_id = $1",
    params = list(project_id))
}

.lock_ok <- function(row, stolen) {
  list(ok = TRUE,
       holder_id = as.character(row$holder_id[1]),
       holder_label = .lock_na_chr(row$holder_label[1]),
       acquired_at = row$acquired_at[1],
       heartbeat_at = row$heartbeat_at[1],
       stolen = isTRUE(stolen))
}


#' Acquire the edit lock on a project
#'
#' @description
#' Try to take the single-writer edit lock on `project_id` for `holder_id`.
#' Succeeds when the project is **free**, **already held by `holder_id`**
#' (re-entrant — the heartbeat is refreshed), or **held by a lock whose
#' heartbeat is older than `ttl_seconds`** (expired — the lock is stolen).
#' Fails when another holder's lock is still fresh.
#'
#' The whole decision runs in one transaction with a row lock (`FOR UPDATE`
#' on PostgreSQL), so two concurrent acquisitions on a free project yield
#' exactly one winner. Expiry is judged against the database clock.
#'
#' @param con A `DBIConnection` (PostgreSQL server, or SQLite for local/test).
#' @param project_id Application project identifier (string).
#' @param holder_id Stable identity of the acquirer (e.g. OAuth email).
#' @param holder_label Optional display name shown to other users.
#' @param ttl_seconds Heartbeat time-to-live in seconds (default 120). A lock
#'   whose last heartbeat is older than this is stealable.
#'
#' @return On success, a list `ok = TRUE`, `holder_id`, `holder_label`,
#'   `acquired_at`, `heartbeat_at`, `stolen` (TRUE when an expired lock was
#'   taken over). On failure, `ok = FALSE` with the current holder's
#'   `holder_id`, `holder_label`, `heartbeat_at`.
#' @seealso [project_lock_heartbeat()], [project_lock_release()],
#'   [project_lock_status()]
#' @export
project_lock_acquire <- function(con, project_id, holder_id,
                                 holder_label = NULL, ttl_seconds = 120L) {
  .assert_lock_args(con, project_id, holder_id)
  ttl <- .lock_ttl(ttl_seconds)
  now_sql   <- .lock_now_sql(con)
  stale_sql <- .lock_stale_sql(con, ttl)
  for_update <- if (.lock_is_pg(con)) " FOR UPDATE" else ""
  label <- if (is.null(holder_label)) NA_character_ else as.character(holder_label)

  DBI::dbWithTransaction(con, {
    cur <- DBI::dbGetQuery(
      con,
      sprintf("SELECT holder_id, holder_label, acquired_at, heartbeat_at,
                      (%s) AS stale
                 FROM project_lock WHERE project_id = $1%s", stale_sql, for_update),
      params = list(project_id))

    if (nrow(cur) == 0L) {
      # Free — insert. `ON CONFLICT DO NOTHING` covers the PostgreSQL race
      # where a concurrent transaction inserted between our SELECT and here
      # (its row is invisible under READ COMMITTED until it commits).
      n <- DBI::dbExecute(
        con,
        sprintf("INSERT INTO project_lock
                   (project_id, holder_id, holder_label, acquired_at, heartbeat_at)
                 VALUES ($1, $2, $3, %s, %s)
                 ON CONFLICT (project_id) DO NOTHING", now_sql, now_sql),
        params = list(project_id, holder_id, label))
      if (n > 0L) {
        .lock_ok(.lock_read(con, project_id), stolen = FALSE)
      } else {
        row <- .lock_read(con, project_id)
        list(ok = FALSE,
             holder_id = as.character(row$holder_id[1]),
             holder_label = .lock_na_chr(row$holder_label[1]),
             heartbeat_at = row$heartbeat_at[1])
      }
    } else {
      reentrant <- identical(as.character(cur$holder_id[1]), holder_id)
      stale <- isTRUE(as.logical(cur$stale[1]))
      if (reentrant) {
        # Own lock: refresh heartbeat, keep acquired_at, optionally update label.
        # Placeholders numbered in textual order (RSQLite binds an unnamed list
        # by order of appearance; PostgreSQL binds by number — this ordering
        # satisfies both).
        DBI::dbExecute(
          con,
          sprintf("UPDATE project_lock
                      SET holder_label = COALESCE($1, holder_label),
                          heartbeat_at = %s
                    WHERE project_id = $2", now_sql),
          params = list(label, project_id))
        .lock_ok(.lock_read(con, project_id), stolen = FALSE)
      } else if (stale) {
        # Expired lock of another holder: take it over (reset both stamps).
        DBI::dbExecute(
          con,
          sprintf("UPDATE project_lock
                      SET holder_id = $1, holder_label = $2,
                          acquired_at = %s, heartbeat_at = %s
                    WHERE project_id = $3", now_sql, now_sql),
          params = list(holder_id, label, project_id))
        .lock_ok(.lock_read(con, project_id), stolen = TRUE)
      } else {
        # Held fresh by another holder.
        list(ok = FALSE,
             holder_id = as.character(cur$holder_id[1]),
             holder_label = .lock_na_chr(cur$holder_label[1]),
             heartbeat_at = cur$heartbeat_at[1])
      }
    }
  })
}


#' Refresh the heartbeat on a held project lock
#'
#' @description
#' Set `heartbeat_at = now()` for `project_id` **only if** `holder_id` still
#' holds it. A no-op otherwise. The app calls this periodically (every
#' ~30–60 s) so the lock survives past `ttl_seconds`.
#'
#' @param con A `DBIConnection`.
#' @param project_id Application project identifier.
#' @param holder_id The holder refreshing its lock.
#'
#' @return `TRUE` if the lock is held by `holder_id` after the call (heartbeat
#'   refreshed), `FALSE` if `holder_id` does not hold it.
#' @seealso [project_lock_acquire()]
#' @export
project_lock_heartbeat <- function(con, project_id, holder_id) {
  .assert_lock_args(con, project_id, holder_id)
  n <- DBI::dbExecute(
    con,
    sprintf("UPDATE project_lock SET heartbeat_at = %s
              WHERE project_id = $1 AND holder_id = $2", .lock_now_sql(con)),
    params = list(project_id, holder_id))
  n > 0L
}


#' Release a project lock
#'
#' @description
#' Delete the lock on `project_id` **only if** `holder_id` holds it. Idempotent:
#' releasing a lock you do not hold (or that is already gone) is a safe no-op.
#'
#' @param con A `DBIConnection`.
#' @param project_id Application project identifier.
#' @param holder_id The holder releasing its lock.
#'
#' @return `TRUE` if a lock was released, `FALSE` otherwise.
#' @seealso [project_lock_acquire()]
#' @export
project_lock_release <- function(con, project_id, holder_id) {
  .assert_lock_args(con, project_id, holder_id)
  n <- DBI::dbExecute(
    con,
    "DELETE FROM project_lock WHERE project_id = $1 AND holder_id = $2",
    params = list(project_id, holder_id))
  n > 0L
}


#' Inspect the lock state of a project
#'
#' @description
#' Read-only lookup of who holds `project_id`. Returns `NULL` when the project
#' is **free** (no lock row). When a lock exists, returns its holder and stamps
#' plus a `stale` flag (`TRUE` when the heartbeat is older than `ttl_seconds`),
#' so the caller can tell **free** (`NULL`), **held-fresh** (`stale = FALSE`)
#' and **held-expired** (`stale = TRUE`) apart.
#'
#' @param con A `DBIConnection`.
#' @param project_id Application project identifier.
#' @param ttl_seconds Heartbeat time-to-live used to compute `stale`
#'   (default 120).
#'
#' @return `NULL` if the project is free, otherwise a list `holder_id`,
#'   `holder_label`, `acquired_at`, `heartbeat_at`, `stale`.
#' @seealso [project_lock_acquire()]
#' @export
project_lock_status <- function(con, project_id, ttl_seconds = 120L) {
  .assert_lock_args(con, project_id)
  ttl <- .lock_ttl(ttl_seconds)
  cur <- DBI::dbGetQuery(
    con,
    sprintf("SELECT holder_id, holder_label, acquired_at, heartbeat_at,
                    (%s) AS stale
               FROM project_lock WHERE project_id = $1", .lock_stale_sql(con, ttl)),
    params = list(project_id))
  if (nrow(cur) == 0L) return(NULL)
  list(holder_id = as.character(cur$holder_id[1]),
       holder_label = .lock_na_chr(cur$holder_label[1]),
       acquired_at = cur$acquired_at[1],
       heartbeat_at = cur$heartbeat_at[1],
       stale = isTRUE(as.logical(cur$stale[1])))
}
