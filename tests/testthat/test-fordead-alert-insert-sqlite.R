# test-fordead-alert-insert-sqlite.R — regression for the SQLite UPSERT
# parsing ambiguity in .insert_fordead_alerts().
#
# Like .insert_obs_pixel(), .insert_fordead_alerts() bulk-loads via a
# staging table and then runs `INSERT INTO alert ... SELECT ... FROM
# tmp_fordead_alert_staging ON CONFLICT (...) DO NOTHING`. The same
# INSERT-from-SELECT ambiguity bites SQLite: it mis-parses the trailing
# `ON CONFLICT (...)` as a join constraint and fails at `DO`
# (`near "DO": syntax error`). A `WHERE` clause on the SELECT fixes it.
#
# Fixtures live in helper-sqlite.R. sf is required to build the alert
# geometries and to run the nearest-plot matching inside the function.

test_that(".insert_fordead_alerts does not raise SQLite 'near DO' error", {
  skip_if_not_installed("sf")
  with_sqlite_monitoring_db(function(con) {
    # One dieback centroid sitting exactly on the single registered plot
    # (POINT(0 0), see helper) so it is kept within the default radius.
    alerts_sf <- sf::st_sf(
      trigger_date     = as.Date("2026-05-20"),
      confidence_class = "high",
      stress_index     = 0.8,
      geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
    )
    # This is where the fatal `near "DO": syntax error` surfaced on SQLite.
    expect_no_error(
      n <- nemeton:::.insert_fordead_alerts(con, alerts_sf, zone_id = 1L)
    )
    expect_equal(n, 1L)
    got <- DBI::dbGetQuery(
      con, "SELECT alert_type FROM alert WHERE plot_id = 1")
    expect_equal(nrow(got), 1L)
    expect_equal(got$alert_type, "fordead_dieback")
  })
})

test_that(".insert_fordead_alerts stays idempotent on SQLite (DO NOTHING)", {
  skip_if_not_installed("sf")
  with_sqlite_monitoring_db(function(con) {
    alerts_sf <- sf::st_sf(
      trigger_date     = as.Date("2026-05-20"),
      confidence_class = "high",
      stress_index     = 0.8,
      geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
    )
    nemeton:::.insert_fordead_alerts(con, alerts_sf, zone_id = 1L)
    # Re-inserting the same (plot_id, alert_type, trigger_date) must be a
    # no-op, not a primary-key violation.
    expect_no_error(
      nemeton:::.insert_fordead_alerts(con, alerts_sf, zone_id = 1L))
    got <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM alert")
    expect_equal(got$n, 1L)
  })
})

# db_migrate's `INSERT INTO schema_migration ... ON CONFLICT DO NOTHING`
# (no conflict target) is only valid on SQLite >= 3.35.0; the fix routes
# SQLite through `INSERT OR IGNORE`. A fresh migrate must populate
# schema_migration and stay idempotent on every SQLite 3.x.
test_that("db_migrate records versions on SQLite via INSERT OR IGNORE", {
  with_sqlite_monitoring_db(function(con) {
    versions <- DBI::dbGetQuery(
      con, "SELECT version FROM schema_migration ORDER BY version")$version
    expect_true("0001_init" %in% versions)
    # Re-running applies nothing new and does not raise.
    expect_no_error(out <- db_migrate(con))
    expect_length(out, 0L)
  })
})
