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

test_that("un re-run conserve les alertes validées sur le terrain (audit 1.0)", {
  skip_if_not_installed("sf")
  with_sqlite_monitoring_db(function(con) {
    pts <- function(xy) sf::st_sf(
      trigger_date     = as.Date("2026-05-20"),
      confidence_class = "3-forte",
      stress_index     = 0.8,
      geometry = sf::st_sfc(lapply(xy, sf::st_point), crs = 2154))
    # Run 1 : deux foyers distants de 1 km.
    nemeton:::.insert_fordead_alerts(
      con, pts(list(c(900000, 6500000), c(901000, 6500000))), zone_id = 1L)
    # Validation terrain du premier foyer.
    id1 <- DBI::dbGetQuery(con, "SELECT id FROM alert ORDER BY id LIMIT 1")$id
    DBI::dbExecute(con, "UPDATE alert SET validation_status = 'confirmed',
      validation_cause = 'scolyte', validated_by = 'agent' WHERE id = ?",
      params = list(id1))
    # Run 2 : le premier foyer re-détecté à 8 m, le second disparu, un nouveau.
    n <- nemeton:::.insert_fordead_alerts(
      con, pts(list(c(900008, 6500000), c(905000, 6500000))), zone_id = 1L)
    got <- DBI::dbGetQuery(con,
      "SELECT id, validation_status, validation_cause FROM alert ORDER BY id")
    expect_equal(n, 1L)                         # seul le nouveau foyer est inséré
    expect_equal(nrow(got), 2L)                 # validé conservé + nouveau
    expect_true(id1 %in% got$id)
    expect_equal(got$validation_cause[got$id == id1], "scolyte")
    expect_equal(sum(got$validation_status == "pending"), 1L)
  })
})

test_that("un run sans alerte purge les alertes pending précédentes (audit 1.0)", {
  skip_if_not_installed("sf")
  with_sqlite_monitoring_db(function(con) {
    pts <- function(xy, dt = as.Date("2026-05-20")) sf::st_sf(
      trigger_date     = dt,
      confidence_class = "3-forte",
      stress_index     = 0.8,
      geometry = sf::st_sfc(lapply(xy, sf::st_point), crs = 2154))
    nemeton:::.insert_fordead_alerts(
      con, pts(list(c(900000, 6500000), c(901000, 6500000))), zone_id = 1L)
    id1 <- DBI::dbGetQuery(con, "SELECT id FROM alert ORDER BY id LIMIT 1")$id
    DBI::dbExecute(con,
      "UPDATE alert SET validation_status = 'confirmed' WHERE id = ?",
      params = list(id1))

    # NULL = post-traitement en échec : rien n'est touché.
    expect_equal(nemeton:::.insert_fordead_alerts(con, NULL, zone_id = 1L), 0L)
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM alert")$n, 2L)

    # Run réussi sans alerte : la pending disparaît, la validée reste.
    empty <- pts(list(c(0, 0)))[0, ]
    expect_equal(nemeton:::.insert_fordead_alerts(con, empty, zone_id = 1L), 0L)
    got <- DBI::dbGetQuery(con, "SELECT id, validation_status FROM alert")
    expect_equal(got$id, id1)
    expect_equal(got$validation_status, "confirmed")

    # Toutes les lignes écartées (trigger_date NA) : purge appliquée aussi.
    nemeton:::.insert_fordead_alerts(
      con, pts(list(c(905000, 6500000))), zone_id = 1L)
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM alert")$n, 2L)
    expect_warning(
      n <- nemeton:::.insert_fordead_alerts(
        con, pts(list(c(906000, 6500000)), dt = as.Date(NA)), zone_id = 1L),
      "trigger_date")
    expect_equal(n, 0L)
    expect_equal(DBI::dbGetQuery(con, "SELECT id FROM alert")$id, id1)
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
    expect_true("0001_initial_v1" %in% versions)
    # Re-running applies nothing new and does not raise.
    expect_no_error(out <- db_migrate(con))
    expect_length(out, 0L)
  })
})

test_that("list_alerts : mêmes types de sortie sous SQLite que sous PG (audit 1.0)", {
  skip_if_not_installed("sf")
  with_sqlite_monitoring_db(function(con) {
    alerts_sf <- sf::st_sf(
      trigger_date     = as.Date("2026-05-20"),
      confidence_class = "3-forte",
      stress_index     = 0.8,
      geometry = sf::st_sfc(sf::st_point(c(900000, 6500000)), crs = 2154)
    )
    nemeton:::.insert_fordead_alerts(con, alerts_sf, zone_id = 1L)
    DBI::dbExecute(con, "UPDATE alert SET validated_at = '2026-06-01 08:30:00'")
    out <- list_alerts(con, 1L)
    # SQLite rendait des chaînes : Date / POSIXct UTC comme sous PG.
    expect_s3_class(out$trigger_date, "Date")
    expect_equal(out$trigger_date, as.Date("2026-05-20"))
    expect_s3_class(out$validated_at, "POSIXct")
    expect_equal(format(out$validated_at, tz = "UTC"), "2026-06-01 08:30:00")
  })
})

test_that("list_alerts : classes / validation_status vides sans liste IN vide (audit 1.0)", {
  skip_if_not_installed("sf")
  seen <- character(0)
  local_mocked_bindings(
    .assert_db_pkgs = function(...) invisible(TRUE),
    .db_get_query = function(con, sql, params = NULL) {
      seen <<- c(seen, sql)
      data.frame()
    })
  list_alerts(structure(list(), class = "FakeConn"), 1L,
              classes = character(0))
  list_alerts(structure(list(), class = "FakeConn"), 1L,
              classes = NULL, validation_status = character(0))
  expect_length(seen, 2L)
  expect_false(any(grepl("IN\\s*\\(\\s*\\)", seen)))
  # classes = character(0) : seules les alertes sans classe (FAST) passent.
  expect_match(seen[1], "(a.confidence_class IS NULL)", fixed = TRUE)
  # validation_status = character(0) : aucun statut retenu -> aucune ligne.
  expect_match(seen[2], "1 = 0", fixed = TRUE)
})
