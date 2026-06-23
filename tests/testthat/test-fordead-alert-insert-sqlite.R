# test-fordead-alert-insert-sqlite.R — regression for the SQLite UPSERT
# parsing ambiguity in .insert_fordead_alerts().
#
# .insert_fordead_alerts() bulk-loads via a
# staging table and then runs `INSERT INTO alert ... SELECT ... FROM
# tmp_fordead_alert_staging ON CONFLICT (...) DO NOTHING`. The same
# INSERT-from-SELECT ambiguity bites SQLite: it mis-parses the trailing
# `ON CONFLICT (...)` as a join constraint and fails at `DO`
# (`near "DO": syntax error`). A `WHERE` clause on the SELECT fixes it.
#
# Fixtures live in helper-sqlite.R. sf is required to build the alert
# geometries and to run the nearest-plot matching inside the function.

test_that(".insert_fordead_alerts persists a pixel alert on SQLite (Phase B)", {
  skip_if_not_installed("sf")
  with_sqlite_monitoring_db(function(con) {
    # Phase B (spec 008 §15) : l'alerte est une entité pixel/cluster
    # rattachée à la zone, sans placette. Centroïde en EPSG:2154 (CRS du
    # masque) → reprojeté en 4326 par la fonction.
    alerts_sf <- sf::st_sf(
      trigger_date     = as.Date("2026-05-20"),
      confidence_class = "3-forte",
      stress_index     = 0.8,
      n_pixels         = 12L,
      area_m2          = 1200,
      geometry = sf::st_sfc(sf::st_point(c(900000, 6500000)), crs = 2154)
    )
    expect_no_error(
      n <- nemeton:::.insert_fordead_alerts(con, alerts_sf, zone_id = 1L)
    )
    expect_equal(n, 1L)
    got <- DBI::dbGetQuery(
      con, "SELECT zone_id, plot_id, alert_type, geom_wkt, n_pixels FROM alert")
    expect_equal(nrow(got), 1L)
    expect_equal(got$zone_id, 1L)
    expect_true(is.na(got$plot_id))                 # plot découplé
    expect_equal(got$alert_type, "fordead_dieback")
    expect_match(got$geom_wkt, "POINT")             # centroïde stocké (4326)
    expect_equal(got$n_pixels, 12L)
  })
})

test_that(".insert_fordead_alerts is idempotent via full zone+type replace", {
  skip_if_not_installed("sf")
  with_sqlite_monitoring_db(function(con) {
    alerts_sf <- sf::st_sf(
      trigger_date     = as.Date("2026-05-20"),
      confidence_class = "3-forte",
      stress_index     = 0.8,
      geometry = sf::st_sfc(sf::st_point(c(900000, 6500000)), crs = 2154)
    )
    nemeton:::.insert_fordead_alerts(con, alerts_sf, zone_id = 1L)
    # Re-run → purge complète (zone, type) puis ré-insertion : toujours
    # 1 ligne, pas 2, sans violation de la clé UNIQUE (cluster_id non stable).
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
