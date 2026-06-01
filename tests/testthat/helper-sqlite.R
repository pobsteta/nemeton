# Helpers for the SQLite-backend regression tests.
#
# Unlike the Postgres integration suite (skip_if_no_timescaledb), these
# spin up a throwaway, file-backed SQLite monitoring DB in a tempdir —
# the backend that ships as the local single-user mode and that had
# never been exercised end-to-end for the UPSERT SQL. No external server
# and no NEMETON_DB_URL_TEST contract: the DB is created fresh per test
# and dropped with the tempdir, so there is nothing to guard against.

skip_if_no_sqlite <- function() {
  if (!requireNamespace("RSQLite", quietly = TRUE) ||
      !requireNamespace("DBI", quietly = TRUE)) {
    testthat::skip("RSQLite / DBI not installed.")
  }
}

# Spin up a fresh, migrated SQLite monitoring DB with one zone + one plot
# (so obs_pixel / alert foreign keys are satisfiable), then hand the open
# connection to `code`. Everything lives in a tempdir withr cleans up.
with_sqlite_monitoring_db <- function(code) {
  skip_if_no_sqlite()
  withr::with_tempdir({
    con <- db_connect(sprintf("sqlite:///%s", file.path(getwd(), "mon.sqlite")))
    on.exit(db_disconnect(con), add = TRUE)
    db_migrate(con)
    DBI::dbExecute(con, paste0(
      "INSERT INTO monitoring_zone (id, name, zone_wkt) ",
      "VALUES (1, 'z', 'POINT(0 0)')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO plot (id, zone_id, plot_id, geom_wkt) ",
      "VALUES (1, 1, 'p1', 'POINT(0 0)')"))
    force(code)(con)
  })
}

# One obs_pixel row in the shape dbAppendTable expects.
sqlite_obs_row <- function(date, band, value) {
  data.frame(
    plot_id   = 1L,
    obs_date  = as.Date(date),
    band      = band,
    value     = value,
    cloud_pct = 3,
    source    = "cdse",
    scene_id  = "S2A_FAKE",
    stringsAsFactors = FALSE
  )
}
