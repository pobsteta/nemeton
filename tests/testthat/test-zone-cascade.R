# test-zone-cascade.R — .delete_project_zones() must remove the whole
# monitoring_zone -> plot -> alert chain without tripping the FK enforcer.
#
# Regression: on the local SQLite backend the 0001 schema omits the
# ON DELETE CASCADE clauses the PG schema carries, so with
# PRAGMA foreign_keys = ON (set by db_connect()) the D5 upsert's
# `DELETE FROM monitoring_zone` failed with "FOREIGN KEY constraint
# failed" when re-building a project whose zones already owned plot/alert
# rows. The builder now deletes the chain explicitly, child-first, in one
# transaction (portable PG/SQLite).
#
# The core regression test drives `.delete_project_zones()` directly with
# hand-inserted rows so it runs on every backend without the sf/terra
# geometry path (which the CI runner skips).

# ---- SQLite: the explicit child-first delete ------------------------

test_that(".delete_project_zones removes the whole chain (SQLite)", {
  skip_if_no_sqlite()
  withr::with_tempfile("dbf", fileext = ".sqlite", {
    con <- db_connect(paste0("sqlite:///", dbf))
    on.exit(db_disconnect(con), add = TRUE)
    db_migrate(con)

    # Project under test: 2 strata zones, one with a plot + alert.
    DBI::dbExecute(con, paste0(
      "INSERT INTO monitoring_zone (id, name, zone_wkt, project_uuid) ",
      "VALUES (1, 'z_tot', 'POINT(0 0)', 'proj-1')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO monitoring_zone (id, name, zone_wkt, project_uuid) ",
      "VALUES (2, 'z_feu', 'POINT(0 0)', 'proj-1')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO plot (id, zone_id, plot_id, geom_wkt) ",
      "VALUES (1, 1, 'p1', 'POINT(0 0)')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO alert (id, plot_id, alert_type, trigger_date) ",
      "VALUES (1, 1, 'fordead', '2026-01-01')"))
    # A second project that must stay untouched.
    DBI::dbExecute(con, paste0(
      "INSERT INTO monitoring_zone (id, name, zone_wkt, project_uuid) ",
      "VALUES (3, 'z_other', 'POINT(0 0)', 'proj-2')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO plot (id, zone_id, plot_id, geom_wkt) ",
      "VALUES (2, 3, 'p2', 'POINT(0 0)')"))

    expect_no_error(nemeton:::.delete_project_zones(con, "proj-1"))

    # proj-1 and its children are gone.
    expect_equal(DBI::dbGetQuery(con,
      "SELECT COUNT(*) n FROM monitoring_zone WHERE project_uuid = 'proj-1'")$n, 0L)
    expect_equal(DBI::dbGetQuery(con,
      "SELECT COUNT(*) n FROM plot WHERE zone_id IN (1,2)")$n, 0L)
    expect_equal(DBI::dbGetQuery(con,
      "SELECT COUNT(*) n FROM alert WHERE plot_id = 1")$n, 0L)

    # proj-2 (zone, plot) survives — the delete is scoped by project_uuid.
    expect_equal(DBI::dbGetQuery(con,
      "SELECT COUNT(*) n FROM monitoring_zone WHERE project_uuid = 'proj-2'")$n, 1L)
    expect_equal(DBI::dbGetQuery(con,
      "SELECT COUNT(*) n FROM plot WHERE zone_id = 3")$n, 1L)

    # No PRAGMA side effect: foreign_keys is still ON.
    expect_equal(
      as.integer(DBI::dbGetQuery(con, "PRAGMA foreign_keys")[[1]]), 1L)
  })
})

test_that(".delete_project_zones is a no-op / idempotent on an empty project (SQLite)", {
  skip_if_no_sqlite()
  withr::with_tempfile("dbf", fileext = ".sqlite", {
    con <- db_connect(paste0("sqlite:///", dbf))
    on.exit(db_disconnect(con), add = TRUE)
    db_migrate(con)
    DBI::dbExecute(con, paste0(
      "INSERT INTO monitoring_zone (id, name, zone_wkt, project_uuid) ",
      "VALUES (1, 'z_tot', 'POINT(0 0)', 'proj-1')"))

    expect_no_error(nemeton:::.delete_project_zones(con, "no-such-project"))
    expect_equal(DBI::dbGetQuery(con,
      "SELECT COUNT(*) n FROM monitoring_zone")$n, 1L)

    # Deleting the real project twice is safe (second call removes nothing).
    expect_no_error(nemeton:::.delete_project_zones(con, "proj-1"))
    expect_no_error(nemeton:::.delete_project_zones(con, "proj-1"))
    expect_equal(DBI::dbGetQuery(con,
      "SELECT COUNT(*) n FROM monitoring_zone")$n, 0L)
  })
})


# ---- SQLite: the reported symptom on the real builder ----------------
# Secondary coverage — exercises build_project_monitoring_zones end to
# end. Guarded by sf; the CI runner may skip it on a terra anomaly, the
# direct .delete_project_zones tests above are the backend-agnostic guard.

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

test_that("build_project_monitoring_zones re-build survives FK + child rows (SQLite)", {
  skip_if_no_sqlite()
  skip_if_not_installed("sf")
  fx <- .cascade_fixtures()
  withr::with_tempfile("dbf", fileext = ".sqlite", {
    con <- db_connect(paste0("sqlite:///", dbf))
    on.exit(db_disconnect(con), add = TRUE)
    db_migrate(con)

    uuid <- "proj-cascade-1"
    suppressWarnings(
      build_project_monitoring_zones(con, "Forêt de Mouthe", uuid,
                                     fx$ugf, fx$bdforet))
    zones1 <- find_zones_by_project(con, uuid)
    expect_gt(nrow(zones1), 0)

    # Attach a validation plot + a FORDEAD alert to the first zone, so the
    # re-build's delete has child rows to remove.
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
    # The orphaned plot/alert of the dropped zones were removed.
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM plot")$n, 0L)
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM alert")$n, 0L)
    expect_equal(
      as.integer(DBI::dbGetQuery(con, "PRAGMA foreign_keys")[[1]]), 1L)
  })
})


# ---- PostgreSQL: parity (cascade is also present at the schema level) -

test_that(".delete_project_zones removes the whole chain (PG)", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    DBI::dbExecute(con, paste0(
      "INSERT INTO monitoring_zone (id, name, zone_wkt, project_uuid) ",
      "VALUES (1, 'z_tot', 'POINT(0 0)', 'proj-1')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO plot (id, zone_id, plot_id, geom_wkt) ",
      "VALUES (1, 1, 'p1', 'POINT(0 0)')"))
    DBI::dbExecute(con, paste0(
      "INSERT INTO alert (id, plot_id, alert_type, trigger_date) ",
      "VALUES (1, 1, 'fordead', '2026-01-01')"))

    expect_no_error(nemeton:::.delete_project_zones(con, "proj-1"))
    expect_equal(DBI::dbGetQuery(con,
      "SELECT COUNT(*) AS n FROM monitoring_zone")$n, 0)
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM plot")$n, 0)
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM alert")$n, 0)
  })
})
