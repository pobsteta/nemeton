#' Database Connection and Migration Helpers (E6 monitoring)
#'
#' @description
#' Thin wrappers around DBI to connect to the monitoring database
#' and apply the SQL migrations bundled in `inst/db/migrations/`.
#'
#' Two backends are supported transparently:
#'
#'   * **PostgreSQL + TimescaleDB + PostGIS** — production / shared
#'     deployment. URL form `postgresql://user:pass@host:port/dbname`.
#'     Uses [RPostgres::Postgres()]. Migrations from
#'     `inst/db/migrations/pg/` are applied. Since 1.0.0 TimescaleDB is
#'     **optional**: the extension is enabled only when the server offers
#'     it, and no table depends on it (PostGIS remains required).
#'   * **SQLite (WAL)** — single-user / local mode for `nemetonshiny`
#'     users who do not run Postgres. URL form `sqlite:///path/to/file.sqlite`
#'     (three slashes for an absolute path). Uses [RSQLite::SQLite()] in
#'     WAL mode (one writer + many concurrent readers across processes).
#'     Migrations from `inst/db/migrations/sqlite/` are applied — same
#'     schema, minus the `CREATE EXTENSION` statements.
#'
#' Selection is driven entirely by the URL scheme, so callers
#' (notably `nemetonshiny::get_monitoring_db_url()`) pick the
#' backend by emitting the right URL — `db_connect()` does the
#' rest.
#'
#' These helpers are only used by the optional monitoring
#' subsystem (spec 007). All DB-dependent code paths gracefully
#' degrade when the required driver package is not installed.
#'
#' @name db
NULL


# ---- Driver selection ------------------------------------------------

# Masque le mot de passe d'une URL de base avant de l'afficher dans un
# message (audit 1.0) : `postgresql://user:secret@host/db` devient
# `postgresql://user:***@host/db`. Les URL sans identifiants (SQLite,
# `user@host`) sont rendues telles quelles.
.mask_db_url <- function(url) {
  if (!is.character(url)) return(url)
  sub("^([A-Za-z][A-Za-z0-9+.-]*://[^:/@]*):[^@]*@", "\\1:***@", url)
}

# Inspect a URL and return the backend identifier. Recognised values:
#   "pg"     for postgres:// or postgresql://
#   "sqlite" for sqlite: (any number of slashes) or a bare path
#            ending in ".sqlite" / ".db"
.detect_driver <- function(url) {
  if (grepl("^postgres(?:ql)?://", url, ignore.case = TRUE)) {
    return("pg")
  }
  if (grepl("^sqlite:", url, ignore.case = TRUE) ||
      grepl("\\.sqlite$|\\.db$", url, ignore.case = TRUE)) {
    return("sqlite")
  }
  # The DuckDB backend was removed in v0.51.0; point legacy URLs at SQLite.
  if (grepl("^duckdb:", url, ignore.case = TRUE) ||
      grepl("\\.duckdb$", url, ignore.case = TRUE)) {
    cli::cli_abort(c(
      "The DuckDB monitoring backend was removed in nemeton 0.51.0.",
      "i" = "Use a SQLite URL instead: {.val sqlite:///path/to/file.sqlite}.",
      "i" = "Local DuckDB data is not migrated automatically; re-ingest into the SQLite file."
    ))
  }
  cli::cli_abort(c(
    "Unrecognised DB URL: {.val {(.mask_db_url(url))}}.",
    "i" = "Expected {.val postgresql://...} or {.val sqlite:///path.sqlite}."
  ))
}

.assert_db_pkgs <- function(driver = "pg") {
  if (!requireNamespace("DBI", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg DBI} required. Install with {.code install.packages('DBI')}.")
  }
  if (identical(driver, "pg")) {
    if (!requireNamespace("RPostgres", quietly = TRUE)) {
      cli::cli_abort("Package {.pkg RPostgres} required. Install with {.code install.packages('RPostgres')}.")
    }
  } else if (identical(driver, "sqlite")) {
    if (!requireNamespace("RSQLite", quietly = TRUE)) {
      cli::cli_abort(c(
        "Package {.pkg RSQLite} required for the local monitoring backend.",
        "i" = "Install with {.code install.packages('RSQLite')}."
      ))
    }
  }
}

# Apply the PRAGMAs that make a file-backed SQLite usable as a local
# monitoring backend. RSQLite is strict about the result API and warns
# ("dbGetQuery()/dbSendQuery()/dbFetch() should only be used with SELECT
# queries") when a non-row-returning statement goes through dbGetQuery.
# So route each PRAGMA to the matching call: busy_timeout and
# journal_mode return their (new) value -> dbGetQuery; foreign_keys and
# synchronous return nothing -> dbExecute.
.sqlite_apply_pragmas <- function(con, read_only) {
  invisible(DBI::dbGetQuery(con, "PRAGMA busy_timeout = 10000"))  # ms — wait instead of erroring on a locked write
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON")                 # SQLite does not enforce FKs otherwise
  if (!read_only) {
    # WAL is a persistent property of the database file; only a writer
    # can set it, and it enables one writer + many concurrent readers
    # across processes (the Shiny session + the future worker).
    invisible(DBI::dbGetQuery(con, "PRAGMA journal_mode = WAL"))
    DBI::dbExecute(con, "PRAGMA synchronous = NORMAL")            # safe under WAL, much faster than FULL
  }
  invisible(con)
}


#' Connect to the monitoring database
#'
#' Reads the connection URL from `NEMETON_DB_URL` (or the `url`
#' argument), inspects its scheme, and opens the matching
#' connection. Use [db_disconnect()] to close it.
#'
#' @param url Character. Connection URL. Two schemes are
#'   supported:
#'   * `postgresql://user:password@host:port/dbname` — opens a
#'     [RPostgres::Postgres()] connection. Reserved characters in the
#'     user, password or database name are percent-encoded (`%40` for
#'     `@`) and decoded before reaching libpq; an optional query string
#'     (`?sslmode=require&application_name=x`) is passed through as libpq
#'     parameters (explicit arguments such as `connect_timeout` win).
#'   * `sqlite:///absolute/path/to/file.sqlite` — opens a
#'     [RSQLite::SQLite()] connection on the given file in WAL mode
#'     (the local backend). The file is created if it does not exist. A
#'     bare path ending in `.sqlite` or `.db` is also accepted for
#'     convenience.
#'   Defaults to `Sys.getenv("NEMETON_DB_URL")`.
#'
#'   The DuckDB backend was removed in 0.51.0; a `duckdb:///` URL now
#'   raises an error pointing at `sqlite:///`.
#' @param read_only Logical. Open the connection in read-only mode.
#'   Defaults to `FALSE`. Relevant only for the SQLite file backend; the
#'   file must already exist and its parent directory is *not* created.
#'   For **PostgreSQL** the flag is a no-op (it manages concurrent
#'   readers and writers natively).
#' @param connect_timeout Positive number of seconds bounding the
#'   connection attempt. Passed to libpq as the `connect_timeout`
#'   parameter for the **PostgreSQL** backend (caps the hang on an
#'   unreachable host); **ignored** for the SQLite file backend.
#'   Defaults to `10L`.
#'
#' @details
#' **SQLite is the local backend.** Opened in WAL (write-ahead logging)
#' mode, a file-backed SQLite database supports a single writer plus
#' several concurrent readers *across processes* — so a Shiny session and
#' a `future` ingestion worker can use the same file at once.
#' `busy_timeout` is set so a momentarily locked write waits instead of
#' erroring, and `foreign_keys` is enabled.
#'
#' @return A `DBIConnection`.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @examples
#' \dontrun{
#' # Postgres (production)
#' Sys.setenv(NEMETON_DB_URL = "postgresql://nemeton:secret@127.0.0.1:5432/nemeton")
#' con <- db_connect()
#' db_disconnect(con)
#'
#' # SQLite (recommended local mode, WAL)
#' Sys.setenv(NEMETON_DB_URL = "sqlite:///tmp/my_project/monitoring.sqlite")
#' con <- db_connect()
#' db_disconnect(con)
#'
#' # SQLite read-only reader, safe to open while a worker writes
#' ro <- db_connect("sqlite:///tmp/my_project/monitoring.sqlite",
#'                  read_only = TRUE)
#' db_disconnect(ro)
#' }
#'
#' @export
db_connect <- function(url = Sys.getenv("NEMETON_DB_URL"),
                       read_only = FALSE,
                       connect_timeout = 10L) {
  if (!nzchar(url)) {
    cli::cli_abort(c(
      "No database URL provided.",
      "i" = "Set {.envvar NEMETON_DB_URL} or pass {.arg url} explicitly.",
      "i" = "Format: {.val postgresql://user:password@host:port/dbname}",
      "i" = "Or local: {.val sqlite:///path/to/file.sqlite}"
    ))
  }
  if (!is.logical(read_only) || length(read_only) != 1L || is.na(read_only)) {
    cli::cli_abort("{.arg read_only} must be a single {.code TRUE}/{.code FALSE}.")
  }
  if (!is.numeric(connect_timeout) || length(connect_timeout) != 1L ||
      is.na(connect_timeout) || connect_timeout <= 0) {
    cli::cli_abort("{.arg connect_timeout} must be a single positive number of seconds.")
  }
  driver <- .detect_driver(url)
  .assert_db_pkgs(driver)
  switch(driver,
    pg = {
      parts <- .parse_pg_url(url)
      # `read_only` is intentionally ignored for Postgres: it manages
      # concurrent readers/writers natively, there is no file lock to
      # work around.
      # `connect_timeout` is a libpq connection parameter (seconds): it
      # bounds the wait when the Postgres host is unreachable instead of
      # hanging on the default OS TCP timeout.
      # Les paramètres libpq de la query string (sslmode, application_name…)
      # sont transmis tels quels ; les paramètres explicites priment.
      args <- list(
        host            = parts$host,
        port            = parts$port,
        dbname          = parts$dbname,
        user            = parts$user,
        password        = parts$password,
        connect_timeout = as.integer(connect_timeout)
      )
      extra <- parts$options[setdiff(names(parts$options), names(args))]
      do.call(DBI::dbConnect, c(list(RPostgres::Postgres()), args, extra))
    },
    sqlite = {
      path <- .parse_sqlite_url(url)
      if (read_only) {
        # A read-only SQLite connection cannot create the file.
        if (!file.exists(path)) {
          cli::cli_abort(c(
            "Cannot open SQLite database read-only: file does not exist.",
            "x" = "{.path {path}}",
            "i" = "Open it read-write once to create it, or drop {.code read_only = TRUE}."
          ))
        }
        con <- DBI::dbConnect(RSQLite::SQLite(), dbname = path,
                              flags = RSQLite::SQLITE_RO)
      } else {
        parent <- dirname(path)
        if (!dir.exists(parent)) {
          dir.create(parent, recursive = TRUE, showWarnings = FALSE)
        }
        con <- DBI::dbConnect(RSQLite::SQLite(), dbname = path,
                              flags = RSQLite::SQLITE_RWC)
      }
      .sqlite_apply_pragmas(con, read_only)
      con
    }
  )
}


#' Disconnect from the monitoring database
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#'
#' @return Invisible `TRUE` if the connection was closed.
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
db_disconnect <- function(con) {
  if (!is.null(con) && DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
  }
  invisible(TRUE)
}


# ---- Migration directory selection -----------------------------------

# Pick the bundled migrations directory matching the active driver.
# Falls back to the legacy `inst/db/migrations/` location for
# backwards compatibility with installations that pin an older
# nemeton: if the new `pg/` subdir does not exist, treat the
# top-level dir as the PG migrations.
.default_migrations_dir <- function(con) {
  driver <- if (inherits(con, "SQLiteConnection")) "sqlite" else "pg"
  pkg_root <- system.file("db/migrations", package = "nemeton")
  candidate <- file.path(pkg_root, driver)
  if (dir.exists(candidate)) candidate else pkg_root
}


#' Apply pending SQL migrations
#'
#' Reads `*.sql` files in `migrations_dir` (sorted lexicographically),
#' compares against the `schema_migration` table, and executes the
#' files that have not yet been applied. The first run also creates
#' `schema_migration` itself (handled by `0001_initial_v1.sql`).
#'
#' When `migrations_dir` is left `NULL`, the directory is picked
#' automatically based on the connection's driver — `pg/` for
#' Postgres, `sqlite/` for SQLite.
#'
#' Migrations are executed in a single transaction per file and the
#' filename (basename without extension) is recorded as the version
#' identifier.
#'
#' Concurrent calls (e.g. a Shiny session and a worker process) are
#' serialised: each file's transaction takes a lock first (a PostgreSQL
#' transaction-level advisory lock, `BEGIN IMMEDIATE` on SQLite) and
#' re-checks `schema_migration`, so a migration applied meanwhile by
#' another connection is skipped instead of being run twice.
#'
#' @section Schema 1.0.0 (no upgrade path):
#' nemeton 1.0.0 starts from a fresh schema: the former migrations
#' `0001_init` to `0008_project_lock` are merged into a single initial
#' migration, `0001_initial_v1`, per backend. A database created by an
#' earlier version — one whose `schema_migration` lists any of those
#' former versions, or one holding monitoring tables (`monitoring_zone`,
#' `plot`, `alert`, `project_lock`) without a `schema_migration` table —
#' is **refused** with an error ("Database predates nemeton 1.0.0:
#' recreate it", condition class `nemeton_legacy_schema`); it is never
#' migrated. Recreate the database (new SQLite file, or an empty
#' PostgreSQL database) and re-run the monitoring pipelines. Later
#' migrations (`0002_*`, ...) apply on top of `0001_initial_v1` as usual.
#'
#' On PostgreSQL, TimescaleDB is optional: `0001_initial_v1` enables it
#' only when `pg_available_extensions` lists it (a `NOTICE` is raised
#' otherwise) and creates no hypertable. PostGIS is still required.
#'
#' @param con A `DBIConnection` returned by [db_connect()].
#' @param migrations_dir Character or `NULL`. Path to the migrations
#'   directory. Defaults to the bundled `inst/db/migrations/<driver>/`.
#'
#' @return A character vector of versions applied during this call
#'   (empty if everything was up to date).
#'
#' @section Lifecycle:
#' Stable: covered by the 1.0 API contract (spec 057).
#'
#' @export
db_migrate <- function(con,
                       migrations_dir = NULL) {
  if (!requireNamespace("DBI", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg DBI} required. Install with {.code install.packages('DBI')}.")
  }
  if (is.null(migrations_dir)) {
    migrations_dir <- .default_migrations_dir(con)
  }
  if (!nzchar(migrations_dir) || !dir.exists(migrations_dir)) {
    cli::cli_abort("Migrations directory {.path {migrations_dir}} not found.")
  }
  files <- sort(list.files(migrations_dir, pattern = "\\.sql$", full.names = TRUE))
  if (!length(files)) {
    cli::cli_warn("No {.val .sql} files in {.path {migrations_dir}}.")
    return(character(0))
  }

  # 1.0.0 : une base d'un schéma antérieur est refusée, jamais migrée.
  .assert_schema_v1(con)

  applied <- .applied_migrations(con)
  to_apply <- files[!(.migration_version(files) %in% applied)]
  if (!length(to_apply)) {
    cli::cli_alert_info("Database schema up to date ({length(applied)} migration{?s} applied).")
    return(character(0))
  }

  # PostgreSQL accepts a whole multi-statement file in one round-trip via
  # the simple-query protocol (`immediate = TRUE`). SQLite does not, so we
  # split the file on `;` and run statements one at a time.
  is_pg <- inherits(con, "PqConnection")
  newly_applied <- character(0)
  for (f in to_apply) {
    version <- .migration_version(f)
    sql <- paste(readLines(f, warn = FALSE), collapse = "\n")
    # Verrou + revérification (audit 1.0) : deux processus (session Shiny et
    # worker) lançant db_migrate() en même temps appliquaient tous deux la
    # même migration (« duplicate column »). Sous le verrou, une migration
    # appliquée entre-temps est sautée.
    applied_now <- .with_migration_lock(con, is_pg, {
      if (.migration_is_applied(con, version)) {
        FALSE
      } else {
        if (is_pg) {
          # Without immediate = TRUE, RPostgres prepares the statement and
          # PostgreSQL rejects it with "cannot insert multiple commands into
          # a prepared statement".
          DBI::dbExecute(con, sql, immediate = TRUE)
        } else {
          # The migration files are hand-written and use no exotic literal
          # forms, so a naive split on `;` is sufficient.
          for (stmt in .split_sql_statements(sql)) {
            if (nzchar(stmt)) DBI::dbExecute(con, stmt)
          }
        }
        # `ON CONFLICT DO NOTHING` with no conflict-target is valid on
        # PostgreSQL but only on SQLite >= 3.35.0; older SQLite engines
        # raise `near "DO": syntax error`. `INSERT OR IGNORE` is the
        # portable SQLite-native form and behaves identically on every
        # 3.x. Branch by backend so each engine gets its own idiom.
        if (is_pg) {
          .db_execute(con,
            "INSERT INTO schema_migration (version) VALUES ($1) ON CONFLICT DO NOTHING",
            params = list(version))
        } else {
          .db_execute(con,
            "INSERT OR IGNORE INTO schema_migration (version) VALUES ($1)",
            params = list(version))
        }
        TRUE
      }
    })
    if (!isTRUE(applied_now)) next
    cli::cli_alert_success("Applied migration {.val {version}}.")
    newly_applied <- c(newly_applied, version)
  }
  newly_applied
}


# Transaction de migration sérialisée entre processus (audit 1.0).
# PostgreSQL : verrou consultatif de transaction (relâché au COMMIT /
# ROLLBACK). SQLite : BEGIN IMMEDIATE prend le verrou d'écriture dès
# l'ouverture (un BEGIN différé ne le prend qu'à la première écriture,
# trop tard pour la revérification).
.MIGRATION_LOCK_KEY <- 7036372L  # clé arbitraire, propre à nemeton

.with_migration_lock <- function(con, is_pg, code) {
  if (is_pg) {
    return(DBI::dbWithTransaction(con, {
      DBI::dbGetQuery(con, sprintf("SELECT pg_advisory_xact_lock(%d)",
                                   .MIGRATION_LOCK_KEY))
      force(code)
    }))
  }
  DBI::dbExecute(con, "BEGIN IMMEDIATE")
  ok <- FALSE
  on.exit(if (!ok) try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE),
          add = TRUE)
  res <- force(code)
  DBI::dbExecute(con, "COMMIT")
  ok <- TRUE
  res
}

# Revérification, sous verrou, qu'une version n'a pas été appliquée
# entre-temps par une autre connexion.
.migration_is_applied <- function(con, version) {
  if (!DBI::dbExistsTable(con, "schema_migration")) return(FALSE)
  rs <- .db_get_query(con,
    "SELECT COUNT(*) AS n FROM schema_migration WHERE version = $1",
    params = list(version))
  isTRUE(as.numeric(rs$n[1L]) > 0)
}


# ---- Internal helpers ------------------------------------------------

.parse_pg_url <- function(url) {
  # Query string (`?sslmode=require&…`) séparée AVANT l'analyse (audit
  # 1.0) : elle se collait sinon au nom de base.
  query <- ""
  qpos <- regexpr("?", url, fixed = TRUE)
  base <- url
  if (qpos > 0L) {
    query <- substring(url, qpos + 1L)
    base  <- substr(url, 1L, qpos - 1L)
  }
  m <- regmatches(base, regexec(
    "^postgres(?:ql)?://([^:@]+)(?::([^@]*))?@([^:/]+)(?::([0-9]+))?/(.+)$",
    base
  ))[[1]]
  if (length(m) < 6) {
    cli::cli_abort("Invalid PostgreSQL URL: {.val {(.mask_db_url(url))}}.")
  }
  # Décodage des %XX (audit 1.0) : un mot de passe contenant `@`, `:` ou `/`
  # doit être encodé dans l'URL (RFC 3986) et transmis décodé à libpq.
  dec <- function(x) utils::URLdecode(x)
  options <- list()
  if (nzchar(query)) {
    for (kv in strsplit(query, "&", fixed = TRUE)[[1]]) {
      if (!nzchar(kv)) next
      eq <- regexpr("=", kv, fixed = TRUE)
      key <- if (eq > 0L) substr(kv, 1L, eq - 1L) else kv
      val <- if (eq > 0L) substring(kv, eq + 1L) else ""
      options[[dec(key)]] <- dec(val)
    }
  }
  list(
    user     = dec(m[2]),
    password = dec(m[3]),
    host     = dec(m[4]),
    port     = if (nzchar(m[5])) as.integer(m[5]) else 5432L,
    dbname   = dec(m[6]),
    options  = options
  )
}

# Extract the filesystem path from a SQLite URL.
# Accepts:
#   sqlite:///abs/path.sqlite       -> /abs/path.sqlite
#   sqlite://./relative.sqlite      -> ./relative.sqlite
#   sqlite:/path.sqlite             -> /path.sqlite
#   /raw/path.sqlite                -> /raw/path.sqlite (no scheme)
# A bare path (no scheme) ending in .sqlite/.db is also accepted by
# .detect_driver() and passes through unchanged here.
.parse_sqlite_url <- function(url) {
  path <- sub("^sqlite:(?://)?", "", url, ignore.case = TRUE)
  if (!nzchar(path)) {
    cli::cli_abort("Empty SQLite path in URL: {.val {(.mask_db_url(url))}}.")
  }
  path
}

# ---- Backend-portable parametrised queries ---------------------------
#
# The monitoring code binds parameters with Postgres-style `$n`
# placeholders and an *unnamed* `params = list(...)`. RSQLite treats `$n`
# as a *named* parameter ("n") and would not bind it from an unnamed
# list, so for SQLite connections we rewrite `$n` to the anonymous `?`
# form (which RSQLite binds positionally) and reorder `params` to match
# each placeholder's textual position. PostgreSQL is passed through
# unchanged.

.sqlite_translate_params <- function(sql, params) {
  toks <- regmatches(sql, gregexpr("\\$[0-9]+", sql))[[1]]
  if (!length(toks)) {
    return(list(sql = sql, params = params))
  }
  idx <- as.integer(sub("^\\$", "", toks))
  list(
    sql    = gsub("\\$[0-9]+", "?", sql),
    params = params[idx]
  )
}

.db_execute <- function(con, sql, params = NULL) {
  if (is.null(params)) {
    return(DBI::dbExecute(con, sql))
  }
  if (inherits(con, "SQLiteConnection")) {
    tr <- .sqlite_translate_params(sql, params)
    return(DBI::dbExecute(con, tr$sql, params = tr$params))
  }
  DBI::dbExecute(con, sql, params = params)
}

.db_get_query <- function(con, sql, params = NULL) {
  if (is.null(params)) {
    return(DBI::dbGetQuery(con, sql))
  }
  if (inherits(con, "SQLiteConnection")) {
    tr <- .sqlite_translate_params(sql, params)
    return(DBI::dbGetQuery(con, tr$sql, params = tr$params))
  }
  DBI::dbGetQuery(con, sql, params = params)
}

# Split a SQL script into individual statements. Honours
# single-quoted string literals so a `;` inside a comment or string
# does not split mid-statement. Strips `--` line comments.
.split_sql_statements <- function(sql) {
  # Remove --line comments (keep newlines so error reports stay
  # readable). Block comments /* ... */ are not used in the bundled
  # migrations so we do not strip them.
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1]]
  lines <- sub("--.*$", "", lines)
  text  <- paste(lines, collapse = "\n")

  out <- character(0)
  buf <- ""
  in_str <- FALSE
  chars <- strsplit(text, "", fixed = TRUE)[[1]]
  for (ch in chars) {
    if (ch == "'") {
      in_str <- !in_str
      buf <- paste0(buf, ch)
    } else if (ch == ";" && !in_str) {
      trimmed <- trimws(buf)
      if (nzchar(trimmed)) out <- c(out, trimmed)
      buf <- ""
    } else {
      buf <- paste0(buf, ch)
    }
  }
  trimmed <- trimws(buf)
  if (nzchar(trimmed)) out <- c(out, trimmed)
  out
}

.migration_version <- function(path) {
  tools::file_path_sans_ext(basename(path))
}

# ---- Garde-fou schéma 1.0.0 ------------------------------------------

# Versions des migrations d'avant la 1.0.0, fusionnées dans
# `0001_initial_v1`. Leur présence dans `schema_migration` signe une base
# créée par une version antérieure : la 1.0.0 repart de zéro, sans chemin
# de migration (décision 2026-10-06).
.LEGACY_MIGRATIONS <- c(
  "0001_init", "0002_fordead", "0003_project_uuid", "0004_drop_obs_pixel",
  "0005_multi_zone_per_project", "0006_reconfort",
  "0007_alert_pixel_geometry", "0008_project_lock"
)

# Tables du schéma de suivi : présentes sans `schema_migration`, elles
# trahissent une base antérieure au suivi des versions (ou bricolée).
.MONITORING_TABLES <- c("monitoring_zone", "plot", "alert", "project_lock")

# Refuse une base antérieure à 1.0.0, avec un message actionnable.
.assert_schema_v1 <- function(con) {
  legacy <- character(0)
  if (DBI::dbExistsTable(con, "schema_migration")) {
    legacy <- intersect(.applied_migrations(con), .LEGACY_MIGRATIONS)
  } else {
    present <- .MONITORING_TABLES[vapply(
      .MONITORING_TABLES, function(t) DBI::dbExistsTable(con, t), logical(1))]
    if (length(present)) {
      legacy <- paste0("table ", present, " without schema_migration")
    }
  }
  if (length(legacy)) {
    cli::cli_abort(c(
      "Database predates nemeton 1.0.0: recreate it.",
      "x" = "Pre-1.0.0 schema detected: {.val {legacy}}.",
      "i" = "nemeton 1.0.0 starts from a fresh schema and does not migrate older databases.",
      "i" = "Point {.envvar NEMETON_DB_URL} at a new SQLite file or an empty PostgreSQL database, then re-run the monitoring pipelines."
    ), class = "nemeton_legacy_schema")
  }
  invisible(TRUE)
}

.applied_migrations <- function(con) {
  exists <- DBI::dbExistsTable(con, "schema_migration")
  if (!exists) return(character(0))
  rs <- DBI::dbGetQuery(con, "SELECT version FROM schema_migration")
  as.character(rs$version)
}
