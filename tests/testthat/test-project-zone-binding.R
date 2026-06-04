# test-project-zone-binding.R — spec 011: project_uuid binding for
# monitoring_zone. Covers migration 0003, register_monitoring_zone(
# project_uuid =) and find_zone_by_project().

# ---- unit: find_zone_by_project input validation --------------------

test_that("find_zone_by_project rejects non-character or empty input", {
  # `con` is unreached: validation happens before any DB call.
  expect_error(find_zone_by_project(NULL, 42),
               regexp = "non-empty character scalar")
  expect_error(find_zone_by_project(NULL, c("a", "b")),
               regexp = "non-empty character scalar")
  expect_error(find_zone_by_project(NULL, NA_character_),
               regexp = "non-empty character scalar")
  expect_error(find_zone_by_project(NULL, ""),
               regexp = "non-empty character scalar")
})


test_that("register_monitoring_zone rejects malformed project_uuid", {
  # Reaches the validation guard before any DB call; con = NULL.
  pol <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
  placettes <- sf::st_sf(
    plot_id  = "P01",
    geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))

  expect_error(
    register_monitoring_zone(NULL, "Z", pol, placettes,
                             project_uuid = NA_character_),
    regexp = "non-empty character scalar"
  )
  expect_error(
    register_monitoring_zone(NULL, "Z", pol, placettes,
                             project_uuid = ""),
    regexp = "non-empty character scalar"
  )
  expect_error(
    register_monitoring_zone(NULL, "Z", pol, placettes,
                             project_uuid = c("a", "b")),
    regexp = "non-empty character scalar"
  )
  expect_error(
    register_monitoring_zone(NULL, "Z", pol, placettes,
                             project_uuid = 42),
    regexp = "non-empty character scalar"
  )
})


# ---- integration: migration + round-trip ----------------------------

test_that("migration 0003 adds project_uuid column to monitoring_zone", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)

    cols <- DBI::dbGetQuery(con,
      "SELECT column_name FROM information_schema.columns
         WHERE table_name = 'monitoring_zone'")
    expect_true("project_uuid" %in% cols$column_name)
  })
})


test_that("register_monitoring_zone(project_uuid=) round-trips", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))

    zid <- register_monitoring_zone(con, "ZWithUuid", pol, placettes,
                                    project_uuid = "20260520_212017_btfe")
    expect_type(zid, "integer")

    row <- DBI::dbGetQuery(con,
      "SELECT project_uuid FROM monitoring_zone WHERE id = $1",
      params = list(zid))
    expect_equal(row$project_uuid, "20260520_212017_btfe")
  })
})


test_that("find_zone_by_project returns the bound zone id", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))

    zid <- register_monitoring_zone(con, "Z", pol, placettes,
                                    project_uuid = "proj-abc")

    found <- find_zone_by_project(con, "proj-abc")
    expect_type(found, "integer")
    expect_length(found, 1L)
    expect_equal(found, zid)
  })
})


test_that("find_zone_by_project returns integer(0) when nothing matches", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    out <- find_zone_by_project(con, "nope-not-here")
    expect_type(out, "integer")
    expect_length(out, 0L)
  })
})


test_that("find_zone_by_project does NOT fall back to name lookup", {
  # Spec 011 §3.3 intentional: name-based lookup is legacy and
  # brittle; the function only matches on project_uuid.
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))

    # Zone registered WITHOUT project_uuid (legacy path).
    register_monitoring_zone(con, "Villards", pol, placettes)

    expect_length(find_zone_by_project(con, "Villards"),  0L)
    expect_length(find_zone_by_project(con, "villards"),  0L)
  })
})


test_that("(project_uuid, name) is unique; same uuid + new name coexist (spec 020)", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))

    register_monitoring_zone(con, "Z1", pol, placettes, project_uuid = "dup")
    # Spec 020 (migration 0005) relaxes uniqueness from project_uuid alone
    # to (project_uuid, name): a project may now own several strata zones.
    # A second zone with the SAME project_uuid but a DIFFERENT name is OK.
    expect_no_error(
      register_monitoring_zone(con, "Z2", pol, placettes, project_uuid = "dup"))
    expect_equal(nrow(find_zones_by_project(con, "dup")), 2L)

    # But re-using the SAME (project_uuid, name) is still rejected. The
    # aborted transaction leaves an open result set -> benign RPostgres
    # warning, suppressed (the assertion is the error).
    suppressWarnings(
      expect_error(
        register_monitoring_zone(con, "Z1", pol, placettes, project_uuid = "dup")))
  })
})


test_that("multiple NULL project_uuid rows coexist (legacy preserved)", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    placettes <- sf::st_sf(
      plot_id  = "P01",
      geometry = sf::st_sfc(sf::st_point(c(4.5, 47.5)), crs = 4326))

    zid1 <- register_monitoring_zone(con, "Z1", pol, placettes)
    zid2 <- register_monitoring_zone(con, "Z2", pol, placettes)
    expect_true(zid2 != zid1)
  })
})
