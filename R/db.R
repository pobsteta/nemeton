#' Database Connection and Migration Helpers (E6 monitoring)
#'
#' @description
#' Thin wrappers around DBI/RPostgres to connect to the TimescaleDB
#' instance described in `docker-compose.yml` and apply the SQL
#' migrations bundled in `inst/db/migrations/`.
#'
#' These helpers are only used by the optional monitoring subsystem
#' (spec 007). All DB-dependent code paths gracefully degrade when
#' `DBI` / `RPostgres` are not installed.
#'
#' @name db
NULL


.assert_db_pkgs <- function() {
  if (!requireNamespace("DBI", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg DBI} required. Install with {.code install.packages('DBI')}.")
  }
  if (!requireNamespace("RPostgres", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg RPostgres} required. Install with {.code install.packages('RPostgres')}.")
  }
}


#' Connect to the monitoring database
#'
#' Reads the connection URL from `NEMETON_DB_URL` (or the `url`
#' argument), parses it, and opens a `RPostgres::Postgres()`
#' connection. Use [db_disconnect()] to close it.
#'
#' @param url Character. PostgreSQL URL of the form
#'   `postgresql://user:password@host:port/dbname`. Defaults to
#'   `Sys.getenv("NEMETON_DB_URL")`.
#'
#' @return A `DBIConnection`.
#'
#' @examples
#' \dontrun{
#' Sys.setenv(NEMETON_DB_URL = "postgresql://nemeton:secret@127.0.0.1:5432/nemeton")
#' con <- db_connect()
#' db_disconnect(con)
#' }
#'
#' @export
db_connect <- function(url = Sys.getenv("NEMETON_DB_URL")) {
  .assert_db_pkgs()
  if (!nzchar(url)) {
    cli::cli_abort(c(
      "No database URL provided.",
      "i" = "Set {.envvar NEMETON_DB_URL} or pass {.arg url} explicitly.",
      "i" = "Format: {.val postgresql://user:password@host:port/dbname}"
    ))
  }
  parts <- .parse_db_url(url)
  DBI::dbConnect(
    RPostgres::Postgres(),
    host     = parts$host,
    port     = parts$port,
    dbname   = parts$dbname,
    user     = parts$user,
    password = parts$password
  )
}


#' Disconnect from the monitoring database
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#'
#' @return Invisible `TRUE` if the connection was closed.
#'
#' @export
db_disconnect <- function(con) {
  if (!is.null(con) && DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
  }
  invisible(TRUE)
}


#' Apply pending SQL migrations
#'
#' Reads `*.sql` files in `migrations_dir` (sorted lexicographically),
#' compares against the `schema_migration` table, and executes the
#' files that have not yet been applied. The first run also creates
#' `schema_migration` itself (handled by `0001_init.sql`).
#'
#' Migrations are executed in a single transaction per file and the
#' filename (basename without extension) is recorded as the version
#' identifier.
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param migrations_dir Character. Path to the migrations directory.
#'   Defaults to the bundled `inst/db/migrations/`.
#'
#' @return A character vector of versions applied during this call
#'   (empty if everything was up to date).
#'
#' @export
db_migrate <- function(con,
                       migrations_dir = system.file("db/migrations", package = "nemeton")) {
  .assert_db_pkgs()
  if (!nzchar(migrations_dir) || !dir.exists(migrations_dir)) {
    cli::cli_abort("Migrations directory {.path {migrations_dir}} not found.")
  }
  files <- sort(list.files(migrations_dir, pattern = "\\.sql$", full.names = TRUE))
  if (!length(files)) {
    cli::cli_warn("No {.val .sql} files in {.path {migrations_dir}}.")
    return(character(0))
  }

  applied <- .applied_migrations(con)
  to_apply <- files[!(.migration_version(files) %in% applied)]
  if (!length(to_apply)) {
    cli::cli_alert_info("Database schema up to date ({length(applied)} migration{?s} applied).")
    return(character(0))
  }

  newly_applied <- character(0)
  for (f in to_apply) {
    version <- .migration_version(f)
    sql <- paste(readLines(f, warn = FALSE), collapse = "\n")
    DBI::dbWithTransaction(con, {
      # immediate = TRUE uses the simple-query protocol so a single .sql
      # file with multiple statements (CREATE TABLE; CREATE INDEX; SELECT
      # create_hypertable(...); …) is executed in one round-trip.
      # Without it, RPostgres prepares the statement and PostgreSQL
      # rejects it with "cannot insert multiple commands into a prepared
      # statement".
      DBI::dbExecute(con, sql, immediate = TRUE)
      # schema_migration may have just been created by this very file —
      # record the version *after* the script ran.
      DBI::dbExecute(con,
        "INSERT INTO schema_migration (version) VALUES ($1) ON CONFLICT DO NOTHING",
        params = list(version))
    })
    cli::cli_alert_success("Applied migration {.val {version}}.")
    newly_applied <- c(newly_applied, version)
  }
  newly_applied
}


# ---- Internal helpers ------------------------------------------------

.parse_db_url <- function(url) {
  m <- regmatches(url, regexec(
    "^postgres(?:ql)?://([^:@]+)(?::([^@]*))?@([^:/]+)(?::([0-9]+))?/(.+)$",
    url
  ))[[1]]
  if (length(m) < 6) {
    cli::cli_abort("Invalid DB URL: {.val {url}}.")
  }
  list(
    user     = m[2],
    password = m[3],
    host     = m[4],
    port     = if (nzchar(m[5])) as.integer(m[5]) else 5432L,
    dbname   = m[6]
  )
}

.migration_version <- function(path) {
  tools::file_path_sans_ext(basename(path))
}

.applied_migrations <- function(con) {
  exists <- DBI::dbExistsTable(con, "schema_migration")
  if (!exists) return(character(0))
  rs <- DBI::dbGetQuery(con, "SELECT version FROM schema_migration")
  as.character(rs$version)
}
