# Build a tiny zone with two plots and seed a few alerts on top of
# them. Returns a list (zone_id, plot_db_ids) for the test.
seed_zone_with_alerts <- function(con, zone_name = "Zone-health-test") {
  pol <- sf::st_sf(
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(700000, 6800000),
      c(701000, 6800000),
      c(701000, 6801000),
      c(700000, 6801000),
      c(700000, 6800000)
    ))), crs = 2154)
  )
  pl <- sf::st_sf(
    plot_id = c("P1", "P2", "P3"),
    geometry = sf::st_sfc(
      sf::st_point(c(700100, 6800100)),
      sf::st_point(c(700500, 6800500)),
      sf::st_point(c(700800, 6800800)),
      crs = 2154
    )
  )
  zid <- nemeton::register_monitoring_zone(con, zone_name, pol, pl)

  plots_db <- DBI::dbGetQuery(con,
    "SELECT id, plot_id FROM plot WHERE zone_id = $1 ORDER BY plot_id",
    params = list(zid))

  # G4 (validation terrain) reste sur des alertes ancrées placette tant
  # que sa refonte n'est pas faite (Phase B.2, D-B4). On garde donc
  # `plot_id` ici, en ajoutant le `zone_id` désormais NOT NULL (Phase B).
  DBI::dbExecute(con,
    "INSERT INTO alert (zone_id, plot_id, alert_type, trigger_date,
                        confidence_class, stress_index)
     VALUES
       ($1, $2, 'fordead_dieback', '2024-06-15', '3-forte',  1.5),
       ($1, $3, 'fordead_dieback', '2024-06-15', '1-faible', 0.4),
       ($1, $4, 'fordead_dieback', '2024-06-15', '4-sol-nu', 2.0)",
    params = list(zid, plots_db$id[1], plots_db$id[2], plots_db$id[3]))

  list(zone_id = zid, plots = plots_db)
}


# Write a synthetic GPKG mimicking what QField would hand back.
# `coords` is a 3xN matrix in Lambert-93; `stades` and `causes`
# are character vectors of the same length.
write_health_gpkg <- function(coords, stades, causes = NA_character_,
                              plot_ids = NULL,
                              path = tempfile(fileext = ".gpkg")) {
  n <- nrow(coords)
  if (length(causes) == 1L) causes <- rep(causes, n)
  if (is.null(plot_ids)) plot_ids <- sprintf("HV-%04d", seq_len(n))
  geom <- lapply(seq_len(n), function(i) sf::st_point(coords[i, ]))
  pl <- sf::st_sf(
    plot_id = plot_ids,
    stade_deperissement = stades,
    cause = causes,
    obs_by = "alice@example.com",
    geometry = sf::st_sfc(geom, crs = 2154)
  )
  sf::st_write(pl, path, layer = "placettes",
               driver = "GPKG", delete_dsn = TRUE, quiet = TRUE)
  path
}


test_that("ingest_health_validation snaps and updates 'sain' as false_positive", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)

    # Plot sits ~10 m from P2 (1-faible alert), labelled "sain"
    gpkg <- write_health_gpkg(
      coords = matrix(c(700510, 6800500), ncol = 2),
      stades = "sain"
    )
    res <- ingest_health_validation(con, gpkg, seed$zone_id)

    expect_equal(res$n_updated, 1L)
    expect_equal(res$n_false_positive, 1L)
    expect_equal(res$n_unmatched, 0L)

    rows <- DBI::dbGetQuery(con,
      "SELECT validation_status, validation_cause, validated_by
         FROM alert WHERE plot_id = $1",
      params = list(seed$plots$id[2]))
    expect_equal(rows$validation_status, "false_positive")
    expect_equal(rows$validation_cause, "sain_terrain")
  })
})


test_that("scolyte stages flag alerts as confirmed/scolyte_terrain", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)
    gpkg <- write_health_gpkg(
      coords = matrix(c(700100, 6800100,
                        700800, 6800800), ncol = 2, byrow = TRUE),
      stades = c("scolyte_rouge", "scolyte_gris")
    )
    res <- ingest_health_validation(con, gpkg, seed$zone_id)
    expect_equal(res$n_confirmed, 2L)
    expect_equal(res$n_false_positive, 0L)

    rows <- DBI::dbGetQuery(con,
      "SELECT plot_id, validation_status, validation_cause
         FROM alert WHERE plot_id IN ($1, $2)
         ORDER BY plot_id",
      params = list(seed$plots$id[1], seed$plots$id[3]))
    expect_true(all(rows$validation_status == "confirmed"))
    expect_true(all(rows$validation_cause == "scolyte_terrain"))
  })
})


test_that("coupe_rase rule is class-dependent (1-faible → false_positive)", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)

    # Three plots, one per alert. coupe_rase applied uniformly.
    gpkg <- write_health_gpkg(
      coords = matrix(c(700100, 6800100,
                        700500, 6800500,
                        700800, 6800800),
                      ncol = 2, byrow = TRUE),
      stades = rep("coupe_rase", 3L)
    )
    res <- ingest_health_validation(con, gpkg, seed$zone_id)
    # 3-forte → confirmed; 1-faible → false_positive; 4-sol-nu → confirmed
    expect_equal(res$n_confirmed, 2L)
    expect_equal(res$n_false_positive, 1L)

    rows <- DBI::dbGetQuery(con,
      "SELECT a.confidence_class, a.validation_status
         FROM alert a JOIN plot p ON p.id = a.plot_id
        WHERE p.zone_id = $1 ORDER BY a.confidence_class",
      params = list(seed$zone_id))
    expect_equal(rows$validation_status[rows$confidence_class == "1-faible"],
                 "false_positive")
    expect_equal(rows$validation_status[rows$confidence_class == "3-forte"],
                 "confirmed")
    expect_equal(rows$validation_status[rows$confidence_class == "4-sol-nu"],
                 "confirmed")
  })
})


test_that("plots farther than snap_distance_m are not matched", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)
    # Coordinates are 200 m offset from the closest plot.
    gpkg <- write_health_gpkg(
      coords = matrix(c(700300, 6800100), ncol = 2),
      stades = "scolyte_rouge"
    )
    res <- ingest_health_validation(con, gpkg, seed$zone_id,
                                    snap_distance_m = 50)
    expect_equal(res$n_unmatched, 1L)
    expect_equal(res$n_updated, 0L)

    # No alert was touched.
    pending <- DBI::dbGetQuery(con,
      "SELECT COUNT(*) AS n FROM alert
         WHERE validation_status = 'pending'")$n
    expect_equal(pending, 3L)
  })
})


test_that("plots without stade are skipped, not unmatched", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)
    gpkg <- write_health_gpkg(
      coords = matrix(c(700100, 6800100), ncol = 2),
      stades = NA_character_
    )
    res <- ingest_health_validation(con, gpkg, seed$zone_id)
    expect_equal(res$n_skipped, 1L)
    expect_equal(res$n_updated, 0L)
    expect_equal(res$n_unmatched, 0L)
  })
})


test_that("validated_by precedence: arg > obs_by > Sys.info()", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)
    gpkg <- write_health_gpkg(
      coords = matrix(c(700100, 6800100), ncol = 2),
      stades = "scolyte_rouge"
    )
    # Explicit arg wins over obs_by
    ingest_health_validation(con, gpkg, seed$zone_id,
                             validated_by = "audit-bot")
    rows <- DBI::dbGetQuery(con,
      "SELECT validated_by FROM alert WHERE plot_id = $1",
      params = list(seed$plots$id[1]))
    expect_equal(rows$validated_by, "audit-bot")
  })
})


test_that("free-form 'cause' from the field overrides the auto-mapped cause", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)
    gpkg <- write_health_gpkg(
      coords = matrix(c(700100, 6800100), ncol = 2),
      stades = "scolyte_rouge",
      causes = "scolyte_typographe_T1"
    )
    ingest_health_validation(con, gpkg, seed$zone_id)
    rows <- DBI::dbGetQuery(con,
      "SELECT validation_cause FROM alert WHERE plot_id = $1",
      params = list(seed$plots$id[1]))
    expect_equal(rows$validation_cause, "scolyte_typographe_T1")
  })
})


test_that("zone with no alerts returns counts and empty details", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_sf(
      geometry = sf::st_sfc(sf::st_polygon(list(rbind(
        c(700000, 6800000), c(701000, 6800000),
        c(701000, 6801000), c(700000, 6801000),
        c(700000, 6800000)
      ))), crs = 2154)
    )
    pl <- sf::st_sf(plot_id = "P1",
                    geometry = sf::st_sfc(
                      sf::st_point(c(700100, 6800100)), crs = 2154))
    zid <- register_monitoring_zone(con, "empty-zone", pol, pl)

    gpkg <- write_health_gpkg(
      coords = matrix(c(700100, 6800100), ncol = 2),
      stades = "scolyte_rouge"
    )
    expect_warning(
      res <- ingest_health_validation(con, gpkg, zid),
      "no alerts"
    )
    expect_equal(res$n_updated, 0L)
    expect_equal(res$n_unmatched, 1L)
  })
})


test_that("missing GPKG path raises a typed error", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)
    expect_error(
      ingest_health_validation(con, "/nonexistent.gpkg", seed$zone_id),
      "GPKG not found"
    )
  })
})


test_that("GPKG without stade_deperissement column is rejected", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)
    pl <- sf::st_sf(
      plot_id = "HV-0001",
      cause   = "scolyte",
      geometry = sf::st_sfc(sf::st_point(c(700100, 6800100)), crs = 2154)
    )
    p <- tempfile(fileext = ".gpkg")
    sf::st_write(pl, p, layer = "placettes",
                 driver = "GPKG", delete_dsn = TRUE, quiet = TRUE)
    expect_error(
      ingest_health_validation(con, p, seed$zone_id),
      "stade_deperissement"
    )
  })
})


test_that("details data.frame has one row per processed plot", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    seed <- seed_zone_with_alerts(con)
    gpkg <- write_health_gpkg(
      coords = matrix(c(700100, 6800100,
                        700500, 6800500,
                        710000, 6810000), ncol = 2, byrow = TRUE),
      stades = c("scolyte_rouge", "sain", NA_character_)
    )
    res <- ingest_health_validation(con, gpkg, seed$zone_id)
    expect_equal(nrow(res$details), 3L)
    expect_setequal(res$details$reason,
                    c("ok", "ok", "missing_stade"))
  })
})
