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
    expect_true("0001_init" %in% applied)
    # The four tables should now exist
    for (tbl in c("monitoring_zone", "plot", "obs_pixel", "alert")) {
      expect_true(DBI::dbExistsTable(con, tbl), info = tbl)
    }
    # Re-running is a no-op
    again <- db_migrate(con)
    expect_length(again, 0)
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
