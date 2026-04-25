# test-alerts.R — detect_alerts SQL window logic

# Integration test only: the rolling window function uses
# TimescaleDB-flavoured INTERVAL syntax and a real obs_pixel
# hypertable. Pure-unit coverage of the SQL is impractical; we exercise
# end-to-end on the live DB.

test_that("detect_alerts flags an NDVI drop and is idempotent", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)

    # Register a zone and one plot
    DBI::dbExecute(con,
      "INSERT INTO monitoring_zone (name, zone_wkt, crs_epsg)
         VALUES ('Z1', 'POLYGON((4 47,5 47,5 48,4 48,4 47))', 4326)")
    zone_id <- DBI::dbGetQuery(con, "SELECT id FROM monitoring_zone WHERE name='Z1'")$id
    DBI::dbExecute(con,
      "INSERT INTO plot (zone_id, plot_id, plot_type, geom_wkt, radius_m)
         VALUES ($1, 'P01', 'Base', 'POINT(4.5 47.5)', 15)",
      params = list(zone_id))
    plot_pk <- DBI::dbGetQuery(con,
      "SELECT id FROM plot WHERE zone_id = $1", params = list(zone_id))$id

    # Insert 30 days of stable NDVI = 0.80, then a drop to 0.55
    dates <- seq(as.Date("2025-06-01"), as.Date("2025-06-30"), by = "day")
    obs_stable <- data.frame(
      plot_id = plot_pk, obs_date = dates, band = "NDVI",
      value = 0.80, cloud_pct = 5, source = "cdse",
      scene_id = "fake", stringsAsFactors = FALSE)
    obs_drop <- data.frame(
      plot_id = plot_pk, obs_date = as.Date("2025-07-05"), band = "NDVI",
      value = 0.55, cloud_pct = 5, source = "cdse",
      scene_id = "fake_drop", stringsAsFactors = FALSE)
    DBI::dbAppendTable(con, "obs_pixel", rbind(obs_stable, obs_drop))

    # First call: should flag exactly one alert
    res1 <- detect_alerts(con, zone_id,
                          threshold_ndvi_drop = 0.15,
                          window_days = 30)
    expect_s3_class(res1, "sf")
    expect_equal(nrow(res1), 1)
    expect_equal(res1$alert_type, "ndvi_drop")
    expect_equal(res1$trigger_date, as.Date("2025-07-05"))

    # Second call: idempotent — same one alert, no duplicates
    res2 <- detect_alerts(con, zone_id,
                          threshold_ndvi_drop = 0.15,
                          window_days = 30)
    expect_equal(nrow(res2), 1)
  })
})

test_that("detect_alerts ignores drops below the threshold", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    DBI::dbExecute(con,
      "INSERT INTO monitoring_zone (name, zone_wkt, crs_epsg)
         VALUES ('Z2', 'POLYGON((4 47,5 47,5 48,4 48,4 47))', 4326)")
    zone_id <- DBI::dbGetQuery(con, "SELECT id FROM monitoring_zone WHERE name='Z2'")$id
    DBI::dbExecute(con,
      "INSERT INTO plot (zone_id, plot_id, geom_wkt) VALUES ($1, 'P01', 'POINT(4.5 47.5)')",
      params = list(zone_id))
    plot_pk <- DBI::dbGetQuery(con,
      "SELECT id FROM plot WHERE zone_id = $1", params = list(zone_id))$id

    dates <- seq(as.Date("2025-06-01"), as.Date("2025-06-30"), by = "day")
    obs <- rbind(
      data.frame(plot_id = plot_pk, obs_date = dates, band = "NDVI",
                 value = 0.80, cloud_pct = 5, source = "cdse",
                 scene_id = "stable", stringsAsFactors = FALSE),
      # Drop of only 0.05 → below 0.15 threshold
      data.frame(plot_id = plot_pk, obs_date = as.Date("2025-07-05"),
                 band = "NDVI", value = 0.75, cloud_pct = 5,
                 source = "cdse", scene_id = "weak_drop",
                 stringsAsFactors = FALSE)
    )
    DBI::dbAppendTable(con, "obs_pixel", obs)

    res <- detect_alerts(con, zone_id, threshold_ndvi_drop = 0.15,
                         window_days = 30)
    expect_equal(nrow(res), 0)
  })
})
