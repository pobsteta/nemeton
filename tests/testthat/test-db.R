# test-db.R — db_connect, db_migrate, db_disconnect (E6 monitoring)
#
# Covers both supported backends:
#   * PostgreSQL + TimescaleDB (skipped without NEMETON_DB_URL_TEST)
#   * DuckDB local file (skipped without the duckdb package)

# ---- URL parsers -----------------------------------------------------

test_that(".parse_pg_url splits a postgres URL", {
  parts <- nemeton:::.parse_pg_url(
    "postgresql://nemeton:s3cret@127.0.0.1:5432/nemeton")
  expect_equal(parts$user, "nemeton")
  expect_equal(parts$password, "s3cret")
  expect_equal(parts$host, "127.0.0.1")
  expect_equal(parts$port, 5432L)
  expect_equal(parts$dbname, "nemeton")
})

test_that(".parse_pg_url accepts the postgres:// scheme", {
  parts <- nemeton:::.parse_pg_url(
    "postgres://u:p@db.example.com/mydb")
  expect_equal(parts$host, "db.example.com")
  expect_equal(parts$port, 5432L)
  expect_equal(parts$dbname, "mydb")
})

test_that(".parse_pg_url rejects malformed URLs", {
  expect_error(nemeton:::.parse_pg_url("not-a-url"),
               "Invalid PostgreSQL URL")
})

test_that(".parse_duckdb_url strips the scheme and keeps the path", {
  expect_equal(nemeton:::.parse_duckdb_url("duckdb:///tmp/x.duckdb"),
               "/tmp/x.duckdb")
  expect_equal(nemeton:::.parse_duckdb_url("duckdb://./rel.duckdb"),
               "./rel.duckdb")
  expect_equal(nemeton:::.parse_duckdb_url("duckdb:/abs/path.duckdb"),
               "/abs/path.duckdb")
})

test_that(".detect_driver classifies URLs correctly", {
  expect_equal(nemeton:::.detect_driver("postgresql://u:p@h/db"), "pg")
  expect_equal(nemeton:::.detect_driver("postgres://u:p@h/db"),   "pg")
  expect_equal(nemeton:::.detect_driver("duckdb:///tmp/x.duckdb"), "duckdb")
  expect_equal(nemeton:::.detect_driver("/tmp/x.duckdb"),          "duckdb")
  expect_error(nemeton:::.detect_driver("redis://x"),
               "Unrecognised DB URL")
})

test_that("db_connect aborts when no URL is provided", {
  withr::with_envvar(c(NEMETON_DB_URL = ""), {
    expect_error(db_connect(""), "No database URL")
  })
})


# ---- Postgres / TimescaleDB integration ------------------------------

test_that("db_migrate applies all bundled migrations on a fresh DB (PG)", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    applied <- db_migrate(con)
    expect_true("0001_init"    %in% applied)
    expect_true("0002_fordead" %in% applied)
    # The four tables should now exist
    for (tbl in c("monitoring_zone", "plot", "obs_pixel", "alert")) {
      expect_true(DBI::dbExistsTable(con, tbl), info = tbl)
    }
    # Re-running is a no-op
    again <- db_migrate(con)
    expect_length(again, 0)
  })
})

test_that("0002_fordead adds the validation columns on alert (idempotent, PG)", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    cols <- DBI::dbGetQuery(con,
      "SELECT column_name, data_type, column_default
         FROM information_schema.columns
        WHERE table_name = 'alert'")
    for (c in c("confidence_class", "stress_index", "validation_status",
                "validation_cause", "validated_by", "validated_at")) {
      expect_true(c %in% cols$column_name, info = c)
    }
    vstatus <- cols[cols$column_name == "validation_status", , drop = FALSE]
    expect_match(vstatus$column_default, "pending")

    idx <- DBI::dbGetQuery(con,
      "SELECT indexname FROM pg_indexes WHERE tablename = 'alert'")
    expect_true("alert_validation_status_idx" %in% idx$indexname)
    expect_true("alert_plot_date_type_idx"    %in% idx$indexname)

    # Re-applying 0002 manually is a no-op (IF NOT EXISTS guard).
    # File now lives under `pg/` since v0.21.0 (DuckDB backend).
    sql <- paste(readLines(
      system.file("db/migrations/pg/0002_fordead.sql", package = "nemeton"),
      warn = FALSE), collapse = "\n")
    expect_no_error(DBI::dbExecute(con, sql, immediate = TRUE))
  })
})

test_that("db_migrate creates a TimescaleDB hypertable for obs_pixel", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    rs <- DBI::dbGetQuery(con,
      "SELECT hypertable_name FROM timescaledb_information.hypertables
        WHERE hypertable_name = 'obs_pixel'")
    expect_equal(nrow(rs), 1)
  })
})


# ---- DuckDB local backend -------------------------------------------

# DuckDB tests use a per-test temp file, so they always start fresh
# and do not depend on any external server. Skipped only when the
# duckdb package itself is not installed.

test_that("db_connect opens a DuckDB file when given a duckdb:// URL", {
  skip_if_not_installed("duckdb")
  withr::with_tempfile("dbf", fileext = ".duckdb", {
    con <- db_connect(paste0("duckdb:///", dbf))
    on.exit(db_disconnect(con), add = TRUE)
    expect_s4_class(con, "duckdb_connection")
    expect_true(DBI::dbIsValid(con))
  })
})

test_that("db_connect creates the parent directory if missing (DuckDB)", {
  skip_if_not_installed("duckdb")
  withr::with_tempdir({
    target <- file.path("nested", "subdir", "monitoring.duckdb")
    expect_false(dir.exists(dirname(target)))
    con <- db_connect(paste0("duckdb:///", normalizePath(".", winslash = "/"),
                             "/", target))
    on.exit(db_disconnect(con), add = TRUE)
    expect_true(dir.exists(dirname(target)))
    expect_true(file.exists(target))
  })
})

test_that("db_migrate applies the DuckDB-flavoured migrations on a fresh file", {
  skip_if_not_installed("duckdb")
  withr::with_tempfile("dbf", fileext = ".duckdb", {
    con <- db_connect(paste0("duckdb:///", dbf))
    on.exit(db_disconnect(con), add = TRUE)

    applied <- db_migrate(con)
    expect_true("0001_init"    %in% applied)
    expect_true("0002_fordead" %in% applied)

    # Same four tables as PG, all present.
    for (tbl in c("monitoring_zone", "plot", "obs_pixel", "alert",
                  "schema_migration")) {
      expect_true(DBI::dbExistsTable(con, tbl), info = tbl)
    }

    # Re-running is a no-op.
    expect_length(db_migrate(con), 0)
  })
})

test_that("DuckDB schema carries the FORDEAD validation columns", {
  skip_if_not_installed("duckdb")
  withr::with_tempfile("dbf", fileext = ".duckdb", {
    con <- db_connect(paste0("duckdb:///", dbf))
    on.exit(db_disconnect(con), add = TRUE)
    db_migrate(con)

    cols <- DBI::dbGetQuery(con,
      "SELECT column_name FROM information_schema.columns
        WHERE table_name = 'alert'")
    for (c in c("confidence_class", "stress_index", "validation_status",
                "validation_cause", "validated_by", "validated_at")) {
      expect_true(c %in% cols$column_name, info = c)
    }
  })
})


# ---- SQL splitter (DuckDB migration helper) --------------------------

test_that(".split_sql_statements splits on `;` outside quoted strings", {
  out <- nemeton:::.split_sql_statements(
    "CREATE TABLE t (x TEXT);
     INSERT INTO t VALUES ('a; b'); -- trailing comment
     SELECT 1;")
  expect_length(out, 3L)
  expect_match(out[1], "^CREATE TABLE")
  expect_match(out[2], "VALUES \\('a; b'\\)$")
  expect_match(out[3], "^SELECT 1$")
})

test_that(".split_sql_statements strips -- comments", {
  out <- nemeton:::.split_sql_statements(
    "-- header comment
     SELECT 1; -- inline comment
     -- another comment
     SELECT 2;")
  expect_length(out, 2L)
})
