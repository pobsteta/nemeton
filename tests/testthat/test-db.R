# test-db.R — db_connect, db_migrate, db_disconnect (E6 monitoring)

test_that(".parse_db_url splits a postgres URL", {
  parts <- nemeton:::.parse_db_url(
    "postgresql://nemeton:s3cret@127.0.0.1:5432/nemeton")
  expect_equal(parts$user, "nemeton")
  expect_equal(parts$password, "s3cret")
  expect_equal(parts$host, "127.0.0.1")
  expect_equal(parts$port, 5432L)
  expect_equal(parts$dbname, "nemeton")
})

test_that(".parse_db_url accepts the postgres:// scheme", {
  parts <- nemeton:::.parse_db_url(
    "postgres://u:p@db.example.com/mydb")
  expect_equal(parts$host, "db.example.com")
  expect_equal(parts$port, 5432L)
  expect_equal(parts$dbname, "mydb")
})

test_that(".parse_db_url rejects malformed URLs", {
  expect_error(nemeton:::.parse_db_url("not-a-url"), "Invalid DB URL")
})

test_that("db_connect aborts when no URL is provided", {
  withr::with_envvar(c(NEMETON_DB_URL = ""), {
    expect_error(db_connect(""), "No database URL")
  })
})


test_that("db_migrate applies all bundled migrations on a fresh DB", {
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

test_that("0002_fordead adds the validation columns on alert (idempotent)", {
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
    sql <- paste(readLines(
      system.file("db/migrations/0002_fordead.sql", package = "nemeton"),
      warn = FALSE), collapse = "\n")
    expect_no_error(DBI::dbExecute(con, sql, immediate = TRUE))
  })
})

test_that("db_migrate creates a TimescaleDB hypertable for obs_pixel", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    # Hypertable presence query — TimescaleDB-specific catalog
    rs <- DBI::dbGetQuery(con,
      "SELECT hypertable_name FROM timescaledb_information.hypertables
        WHERE hypertable_name = 'obs_pixel'")
    expect_equal(nrow(rs), 1)
  })
})
