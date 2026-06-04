# test-monitoring-zones.R — spec 020: monitoring zones from UGF x BD Forêt
# v2 strata (tot/feu/res/mix). Unit tests (no DB) cover the slug, the
# stratum classifier, input validation and the geometry/upsert logic
# (create_monitoring_zone mocked). Integration tests (guarded by
# NEMETON_DB_URL_TEST via with_clean_db) cover the real inserts, the
# UNIQUE(project_uuid, name) constraint and the end-to-end builder.

# ---- .nmt_slug -------------------------------------------------------

test_that(".nmt_slug transliterates accents and slugifies", {
  expect_equal(nemeton:::.nmt_slug("Mouthe"), "mouthe")
  expect_equal(nemeton:::.nmt_slug("Forêt de Mouthe"), "foret_de_mouthe")
  expect_equal(nemeton:::.nmt_slug("Saint-Étienne"), "saint_etienne")
  expect_equal(nemeton:::.nmt_slug("Châteauneuf-du-Faou"), "chateauneuf_du_faou")
  expect_equal(nemeton:::.nmt_slug(""), "projet")
  expect_equal(nemeton:::.nmt_slug("  !!  "), "projet")
})


# ---- .classify_bdforet_strata ----------------------------------------

test_that(".classify_bdforet_strata maps tfv_g11, falls back to essence", {
  df <- data.frame(
    tfv_g11 = c("Forêt fermée feuillus", "Forêt fermée conifères",
                "Forêt fermée mixte", "Forêt ouverte mixte",
                "Formation herbacée", NA),
    essence = c(NA, NA, NA, NA, NA, "Sapin, épicéa"),
    stringsAsFactors = FALSE)
  expect_equal(
    nemeton:::.classify_bdforet_strata(df),
    c("feuillu", "resineux", "mixte", "mixte", "autre", "resineux"))
})

test_that(".classify_bdforet_strata handles empty input", {
  expect_equal(nemeton:::.classify_bdforet_strata(data.frame()), character(0))
})


# ---- input validation (reached before any DB call) -------------------

test_that("find_zones_by_project rejects malformed project_uuid", {
  expect_error(find_zones_by_project(NULL, ""), "non-empty character scalar")
  expect_error(find_zones_by_project(NULL, c("a", "b")), "non-empty character scalar")
  expect_error(find_zones_by_project(NULL, NA_character_), "non-empty character scalar")
})

test_that("create_monitoring_zone validates its inputs", {
  skip_if_not_installed("sf")
  pol <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 0, ymin = 0, xmax = 1, ymax = 1), crs = 4326))
  expect_error(create_monitoring_zone(NULL, "", pol),
               "non-empty character scalar")
  expect_error(create_monitoring_zone(NULL, "Z", "not-sf"),
               "must be an sf/sfc")
  expect_error(create_monitoring_zone(NULL, "Z", pol, project_uuid = NA_character_),
               "non-empty character scalar or")
})


# ---- build_project_monitoring_zones: geometry + upsert (mocked DB) ----

.mk_square <- function(xmin, xmax, ymin = 0, ymax = 100, crs = 2154, ...) {
  sf::st_sf(...,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(xmin, ymin), c(xmax, ymin), c(xmax, ymax),
      c(xmin, ymax), c(xmin, ymin)))), crs = crs))
}

test_that("build_project_monitoring_zones builds tot/feu/res, skips empty mix", {
  skip_if_not_installed("sf")
  ugf <- .mk_square(0, 100)                            # 100 x 100 = 10000
  bdf <- rbind(
    .mk_square(0,  50, tfv_g11 = "Forêt fermée feuillus"),    # left half
    .mk_square(50, 100, tfv_g11 = "Forêt fermée conifères"))  # right half
  # no "mixte" polygon -> _mix stratum empty -> skipped (D4)

  captured <- list(); deleted <- FALSE
  testthat::local_mocked_bindings(
    .assert_db_pkgs       = function(...) invisible(NULL),
    .delete_project_zones = function(con, project_uuid) { deleted <<- TRUE },
    create_monitoring_zone = function(con, zone_name, zone_polygon,
                                      project_uuid = NULL) {
      captured[[zone_name]] <<- as.numeric(sum(sf::st_area(zone_polygon)))
      length(captured)
    },
    .package = "nemeton")

  ids <- expect_warning(
    build_project_monitoring_zones(NULL, "Mouthe", "uuid-1", ugf, bdf),
    "empty")

  expect_true(deleted)                                      # D5 upsert
  expect_setequal(names(captured),
                  c("mouthe_tot", "mouthe_feu", "mouthe_res"))
  expect_false("mouthe_mix" %in% names(captured))           # D4 skip empty
  expect_equal(captured[["mouthe_tot"]], 10000, tolerance = 1)
  expect_equal(captured[["mouthe_feu"]],  5000, tolerance = 1)
  expect_equal(captured[["mouthe_res"]],  5000, tolerance = 1)
  expect_setequal(names(ids), c("tot", "feu", "res"))
})


# ---- integration (guarded by NEMETON_DB_URL_TEST) --------------------

test_that("create_monitoring_zone inserts no placette; find_zones lists them", {
  skip_if_not_installed("sf")
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    z1 <- create_monitoring_zone(con, "mouthe_tot", pol, project_uuid = "u-m")
    z2 <- create_monitoring_zone(con, "mouthe_feu", pol, project_uuid = "u-m")
    expect_type(z1, "integer"); expect_type(z2, "integer")

    zones <- find_zones_by_project(con, "u-m")
    expect_equal(nrow(zones), 2L)
    expect_setequal(zones$name, c("mouthe_tot", "mouthe_feu"))

    np <- DBI::dbGetQuery(con,
      "SELECT count(*)::int AS n FROM plot WHERE zone_id IN ($1, $2)",
      params = list(z1, z2))$n
    expect_equal(np, 0L)                                    # D2: zones have no placette
  })
})

test_that("UNIQUE(project_uuid, name) allows 4 strata, rejects a duplicate", {
  skip_if_not_installed("sf")
  with_clean_db(function(con) {
    db_migrate(con)
    pol <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = 4, ymin = 47, xmax = 5, ymax = 48), crs = 4326))
    for (s in c("tot", "feu", "res", "mix")) {
      create_monitoring_zone(con, paste0("p_", s), pol, project_uuid = "u")
    }
    expect_equal(nrow(find_zones_by_project(con, "u")), 4L)
    # same (uuid, name) -> unique violation (rollback warning suppressed)
    expect_error(suppressWarnings(
      create_monitoring_zone(con, "p_tot", pol, project_uuid = "u")))
  })
})

test_that("build_project_monitoring_zones is end-to-end and idempotent (upsert)", {
  skip_if_not_installed("sf")
  with_clean_db(function(con) {
    db_migrate(con)
    ugf <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(0,0), c(100,0), c(100,100), c(0,100), c(0,0)))), crs = 2154))
    mk <- function(a, b, g) sf::st_sf(tfv_g11 = g,
      geometry = sf::st_sfc(sf::st_polygon(list(rbind(
        c(a,0), c(b,0), c(b,100), c(a,100), c(a,0)))), crs = 2154))
    bdf <- rbind(mk(0, 50, "Forêt fermée feuillus"),
                 mk(50, 100, "Forêt fermée conifères"))

    ids <- suppressWarnings(
      build_project_monitoring_zones(con, "Mouthe", "u-m", ugf, bdf))
    expect_setequal(names(ids), c("tot", "feu", "res"))
    expect_setequal(find_zones_by_project(con, "u-m")$name,
                    c("mouthe_tot", "mouthe_feu", "mouthe_res"))

    # re-run replaces (still 3 zones, not 6)
    suppressWarnings(
      build_project_monitoring_zones(con, "Mouthe", "u-m", ugf, bdf))
    expect_equal(nrow(find_zones_by_project(con, "u-m")), 3L)
  })
})


# ---- prune_orphan_zone_caches ----------------------------------------

.mk_zone_dir <- function(root, sub, id) {
  d <- file.path(root, sub, sprintf("zone_%d", id))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  writeLines("x", file.path(d, "f.tif"))
  d
}

test_that("prune_orphan_zone_caches removes only stale zone dirs", {
  root <- withr::local_tempdir()
  keep1 <- .mk_zone_dir(root, "fast_alert", 1L)
  keep2 <- .mk_zone_dir(root, "fast_alert_mask", 2L)
  orph7 <- .mk_zone_dir(root, "fast_alert", 7L)
  orph9 <- .mk_zone_dir(root, "fordead", 9L)
  testthat::local_mocked_bindings(
    .assert_db_pkgs = function(...) invisible(NULL),
    .db_get_query   = function(con, sql, ...) data.frame(id = c(1L, 2L)),
    .package = "nemeton")

  res <- prune_orphan_zone_caches(NULL, root)
  expect_setequal(res$zone_id, c(7L, 9L))
  expect_true(all(res$removed))
  expect_false(dir.exists(orph7)); expect_false(dir.exists(orph9))
  expect_true(dir.exists(keep1));  expect_true(dir.exists(keep2))
})

test_that("prune_orphan_zone_caches dry_run reports without deleting", {
  root <- withr::local_tempdir()
  d <- .mk_zone_dir(root, "fast_alert", 99L)
  testthat::local_mocked_bindings(
    .assert_db_pkgs = function(...) invisible(NULL),
    .db_get_query   = function(con, sql, ...) data.frame(id = integer(0)),
    .package = "nemeton")

  res <- prune_orphan_zone_caches(NULL, root, dry_run = TRUE)
  expect_equal(res$zone_id, 99L)
  expect_false(any(res$removed))
  expect_true(dir.exists(d))           # untouched on dry-run
})

test_that("prune_orphan_zone_caches ignores non-zone dirs and a missing root", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "sentinel2", "S2A_xyz"), recursive = TRUE)
  testthat::local_mocked_bindings(
    .assert_db_pkgs = function(...) invisible(NULL),
    .db_get_query   = function(con, sql, ...) data.frame(id = integer(0)),
    .package = "nemeton")
  expect_equal(nrow(prune_orphan_zone_caches(NULL, root)), 0L)   # sentinel2 untouched
  expect_true(dir.exists(file.path(root, "sentinel2", "S2A_xyz")))

  testthat::local_mocked_bindings(
    .assert_db_pkgs = function(...) invisible(NULL), .package = "nemeton")
  expect_equal(nrow(prune_orphan_zone_caches(NULL, file.path(root, "nope-xyz"))), 0L)
})
