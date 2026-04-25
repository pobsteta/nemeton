# Helpers shared by the E6 monitoring test files.

skip_if_no_timescaledb <- function() {
  url <- Sys.getenv("NEMETON_DB_URL_TEST", Sys.getenv("NEMETON_DB_URL", ""))
  if (!nzchar(url)) {
    testthat::skip("NEMETON_DB_URL_TEST not set — TimescaleDB integration test skipped.")
  }
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("RPostgres", quietly = TRUE)) {
    testthat::skip("DBI / RPostgres not installed.")
  }
  con <- tryCatch(db_connect(url), error = function(e) NULL)
  if (is.null(con)) {
    testthat::skip(sprintf("Cannot connect to TimescaleDB at %s.", url))
  }
  db_disconnect(con)
}


# Open a fresh connection for an integration test, drop the four tables
# (and schema_migration) at the *start* and end of each test so the test
# is idempotent and doesn't leak state into other tests.
with_clean_db <- function(code) {
  url <- Sys.getenv("NEMETON_DB_URL_TEST", Sys.getenv("NEMETON_DB_URL", ""))
  con <- db_connect(url)
  reset_schema <- function() {
    DBI::dbExecute(con, "DROP TABLE IF EXISTS alert CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS obs_pixel CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS plot CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS monitoring_zone CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS schema_migration CASCADE")
  }
  reset_schema()
  on.exit({
    tryCatch(reset_schema(), error = function(e) NULL)
    db_disconnect(con)
  }, add = TRUE)
  force(code)(con)
}


# Build a tiny scenes tibble compatible with what stac_search_s2()
# returns. Used to mock the STAC layer in monitoring tests.
fake_scenes <- function(dates = as.Date(c("2025-06-10", "2025-06-25", "2025-07-10")),
                        cloud = c(5, 8, 3),
                        source = "cdse") {
  data.frame(
    scene_id  = sprintf("S2A_FAKE_%s", format(dates, "%Y%m%d")),
    obs_date  = dates,
    cloud_pct = cloud,
    href_B04  = "fake://B04.tif",
    href_B08  = "fake://B08.tif",
    href_B12  = "fake://B12.tif",
    source    = rep(source, length(dates)),
    stringsAsFactors = FALSE
  )
}
