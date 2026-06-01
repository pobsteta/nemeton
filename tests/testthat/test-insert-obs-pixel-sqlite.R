# test-insert-obs-pixel-sqlite.R — regression for the SQLite UPSERT
# parsing ambiguity in .insert_obs_pixel().
#
# .insert_obs_pixel() bulk-loads via `INSERT INTO obs_pixel ... SELECT
# ... FROM staging ON CONFLICT (...) DO NOTHING`. When an INSERT draws
# its rows from a SELECT, SQLite cannot tell whether the trailing `ON`
# opens the UPSERT clause or a join's `ON`; it mis-parses
# `ON CONFLICT (...)` and dies at `DO` with `near "DO": syntax error`.
# The Sentinel-2 worker hit exactly this on the local SQLite backend.
# A `WHERE` clause on the SELECT disambiguates the grammar.
#
# Unlike the rest of the monitoring suite (which is Postgres-only via
# skip_if_no_timescaledb), this runs on the file-backed SQLite backend
# — the backend that was actually broken — so it needs no external DB.

skip_if_no_sqlite <- function() {
  if (!requireNamespace("RSQLite", quietly = TRUE) ||
      !requireNamespace("DBI", quietly = TRUE)) {
    testthat::skip("RSQLite / DBI not installed.")
  }
}

# Spin up a fresh, migrated SQLite monitoring DB with one zone + one plot
# so obs_pixel's FK is satisfiable, then hand the open connection to
# `code`. Everything lives in a tempdir that withr cleans up.
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

obs_row <- function(date, band, value) {
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

test_that(".insert_obs_pixel does not raise SQLite 'near DO' syntax error", {
  with_sqlite_monitoring_db(function(con) {
    obs <- rbind(
      obs_row("2026-05-26", "B04", 0.12),
      obs_row("2026-05-26", "B08", 0.34)
    )
    # The bug surfaced here as a fatal `near "DO": syntax error`.
    expect_no_error(.insert_obs_pixel(con, obs))
    got <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM obs_pixel")
    expect_equal(got$n, 2L)
  })
})

test_that(".insert_obs_pixel keeps ON CONFLICT DO NOTHING idempotent", {
  with_sqlite_monitoring_db(function(con) {
    obs <- obs_row("2026-05-26", "B04", 0.12)
    .insert_obs_pixel(con, obs)
    # Re-inserting the same (plot_id, obs_date, band) must be a no-op,
    # not a primary-key violation — that's what DO NOTHING buys us.
    expect_no_error(.insert_obs_pixel(con, obs))
    got <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM obs_pixel")
    expect_equal(got$n, 1L)
  })
})

test_that(".insert_obs_pixel on empty input is a no-op", {
  with_sqlite_monitoring_db(function(con) {
    empty <- obs_row("2026-05-26", "B04", 0.12)[0, ]
    expect_equal(.insert_obs_pixel(con, empty), 0L)
  })
})
