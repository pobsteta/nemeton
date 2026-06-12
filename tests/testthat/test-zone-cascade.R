# test-zone-cascade.R — migration 0006: ON DELETE CASCADE on the
# monitoring_zone -> plot -> alert FK chain.
#
# Regression: on the local SQLite backend (Windows single-user mode), the
# 0001 schema deliberately dropped the ON DELETE CASCADE clauses the PG
# schema carries. With PRAGMA foreign_keys = ON (set by db_connect()),
# build_project_monitoring_zones(replace = TRUE) then failed with "FOREIGN
# KEY constraint failed" when re-building a project whose zones already
# owned plot/alert rows. Migration 0006 rebuilds `plot` and `alert` with
# ON DELETE CASCADE, bringing SQLite to parity with PG.

# Minimal UGF (1 km square) + BD Forêt v2 sf (one broadleaf, one conifer
# polygon inside the UGF), all in Lambert-93, to drive the strata builder.
.cascade_fixtures <- function() {
  sq <- function(x0, y0, x1, y1) {
    sf::st_polygon(list(rbind(
      c(x0, y0), c(x1, y0), c(x1, y1), c(x0, y1), c(x0, y0))))
  }
  ugf <- sf::st_sf(geometry = sf::st_sfc(sq(0, 0, 1000, 1000), crs = 2154))
  bdforet <- sf::st_sf(
    tfv_g11  = c("Forêt fermée de feuillus", "Forêt fermée de conifères"),
    geometry = sf::st_sfc(sq(0, 0, 500, 1000), sq(500, 0, 1000, 1000),
                          crs = 2154))
  list(ugf = ugf, bdforet = bdforet)
}


# ---- SQLite: the migration installs the cascade ----------------------

test_that("migration 0006 installs ON DELETE CASCADE on the SQLite chain", {
  skip_if_no_sqlite()
  withr::with_tempfile("dbf", fileext = ".sqlite", {
    con <- db_connect(paste0("sqlite:///", dbf))
    on.exit(db_disconnect(con), add = TRUE)
    applied <- db_migrate(con)
    expect_true("0006_zone_cascade" %in% applied)

    DBI::dbExecute(con, paste0(
      "INSERT INTO monitoring_zone (id, name, zone_wkt) ",
      "VALUES (1, 'z', 'POINT(0 0)')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO plot (id, zone_id, plot_id, geom_wkt) ",
      "VALUES (1, 1, 'p1', 'POINT(0 0)')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO alert (id, plot_id, alert_type, trigger_date) ",
      "VALUES (1, 1, 'fordead', '2026-01-01')"))

    # Deleting the parent zone now cascades to plot + alert instead of
    # raising "FOREIGN KEY constraint failed".
    expect_no_error(
      DBI::dbExecute(con, "DELETE FROM monitoring_zone WHERE id = 1"))
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM plot")$n, 0L)
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM alert")$n, 0L)

    # The migration preserves FK enforcement (defer_foreign_keys auto-resets
    # at COMMIT; foreign_keys stays ON for the connection).
    expect_equal(
      as.integer(DBI::dbGetQuery(con, "PRAGMA foreign_keys")[[1]]), 1L)
  })
})

test_that("migration 0006 preserves existing plot/alert rows (SQLite)", {
  skip_if_no_sqlite()
  # Apply 0001..0005, populate, then apply 0006 alone and check the rebuild
  # copies every row (no data loss in the table rebuild).
  withr::with_tempfile("dbf", fileext = ".sqlite", {
    con <- db_connect(paste0("sqlite:///", dbf))
    on.exit(db_disconnect(con), add = TRUE)

    mdir <- system.file("db/migrations/sqlite", package = "nemeton")
    pre  <- sort(list.files(mdir, pattern = "\\.sql$", full.names = TRUE))
    pre  <- pre[!grepl("0006_zone_cascade", pre)]
    # Hand-apply 0001..0005 (mirrors db_migrate's per-statement SQLite path).
    for (f in pre) {
      for (stmt in nemeton:::.split_sql_statements(
        paste(readLines(f, warn = FALSE), collapse = "\n"))) {
        if (nzchar(stmt)) DBI::dbExecute(con, stmt)
      }
    }
    DBI::dbExecute(con, paste0(
      "INSERT INTO monitoring_zone (id, name, zone_wkt) ",
      "VALUES (7, 'z7', 'POINT(0 0)')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO plot (id, zone_id, plot_id, plot_type, geom_wkt, radius_m) ",
      "VALUES (3, 7, 'pA', 'grts', 'POINT(1 1)', 12)"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO alert (id, plot_id, alert_type, trigger_date, ",
      "validation_status, stress_index) ",
      "VALUES (5, 3, 'fordead', '2026-03-01', 'confirmed', 0.42)"))

    # Apply 0006 inside one transaction — exactly db_migrate's SQLite path
    # (PRAGMA defer_foreign_keys only holds for the current transaction).
    DBI::dbWithTransaction(con, {
      for (stmt in nemeton:::.split_sql_statements(paste(readLines(
        file.path(mdir, "0006_zone_cascade.sql"), warn = FALSE),
        collapse = "\n"))) {
        if (nzchar(stmt)) DBI::dbExecute(con, stmt)
      }
    })

    p <- DBI::dbGetQuery(con, "SELECT * FROM plot")
    a <- DBI::dbGetQuery(con, "SELECT * FROM alert")
    expect_equal(nrow(p), 1L)
    expect_equal(p$id, 3L)
    expect_equal(p$radius_m, 12)
    expect_equal(p$plot_type, "grts")
    expect_equal(nrow(a), 1L)
    expect_equal(a$id, 5L)
    expect_equal(a$validation_status, "confirmed")
    expect_equal(a$stress_index, 0.42)
  })
})


# ---- SQLite: the reported symptom on the real builder ----------------

test_that("build_project_monitoring_zones re-build survives FK + child rows (SQLite)", {
  skip_if_no_sqlite()
  skip_if_not_installed("sf")
  fx <- .cascade_fixtures()
  withr::with_tempfile("dbf", fileext = ".sqlite", {
    con <- db_connect(paste0("sqlite:///", dbf))
    on.exit(db_disconnect(con), add = TRUE)
    db_migrate(con)

    uuid <- "proj-cascade-1"
    z1 <- suppressWarnings(
      build_project_monitoring_zones(con, "Forêt de Mouthe", uuid,
                                     fx$ugf, fx$bdforet))
    zones1 <- find_zones_by_project(con, uuid)
    expect_gt(nrow(zones1), 0)

    # Attach a validation plot + a FORDEAD alert to the first zone, so the
    # re-build's DELETE FROM monitoring_zone has child rows to cascade.
    zid <- zones1$id[1]
    DBI::dbExecute(con, sprintf(paste0(
      "INSERT INTO plot (zone_id, plot_id, geom_wkt) ",
      "VALUES (%d, 'pv1', 'POINT(250 500)')"), zid))
    pid <- DBI::dbGetQuery(con,
      "SELECT id FROM plot ORDER BY id DESC LIMIT 1")$id[1]
    DBI::dbExecute(con, sprintf(paste0(
      "INSERT INTO alert (plot_id, alert_type, trigger_date) ",
      "VALUES (%d, 'fordead', '2026-02-01')"), pid))

    # Re-build (replace = TRUE) must not raise the FK error.
    expect_no_error(suppressWarnings(
      build_project_monitoring_zones(con, "Forêt de Mouthe", uuid,
                                     fx$ugf, fx$bdforet)))

    # Idempotence: same set / count of strata zones.
    zones2 <- find_zones_by_project(con, uuid)
    expect_equal(sort(zones2$name), sort(zones1$name))
    expect_equal(nrow(zones2), nrow(zones1))
    # The orphaned plot/alert of the dropped zones were cascaded away.
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM plot")$n, 0L)
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM alert")$n, 0L)
    # No PRAGMA side effect: foreign_keys is still ON after the upsert.
    expect_equal(
      as.integer(DBI::dbGetQuery(con, "PRAGMA foreign_keys")[[1]]), 1L)
  })
})


# ---- PostgreSQL: parity (cascade already present since 0001) ---------

test_that("monitoring_zone delete cascades to plot + alert (PG)", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    DBI::dbExecute(con,
      "INSERT INTO monitoring_zone (id, name, zone_wkt) VALUES (1, 'z', 'POINT(0 0)')")
    DBI::dbExecute(con,
      "INSERT INTO plot (id, zone_id, plot_id, geom_wkt) VALUES (1, 1, 'p1', 'POINT(0 0)')")
    DBI::dbExecute(con,
      "INSERT INTO alert (id, plot_id, alert_type, trigger_date) VALUES (1, 1, 'fordead', '2026-01-01')")

    expect_no_error(
      DBI::dbExecute(con, "DELETE FROM monitoring_zone WHERE id = 1"))
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM plot")$n, 0)
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM alert")$n, 0)

    # 0006 is idempotent (re-applying drops + re-adds the same constraints).
    sql <- paste(readLines(system.file(
      "db/migrations/pg/0006_zone_cascade.sql", package = "nemeton"),
      warn = FALSE), collapse = "\n")
    expect_no_error(DBI::dbExecute(con, sql, immediate = TRUE))
  })
})
