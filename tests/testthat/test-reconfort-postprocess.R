# test-reconfort-postprocess.R — RECONFORT post-process (L3, spec 021)
#   * constants RECONFORT_CLASSES / _CONFIDENCE_WEIGHTS / _ALERT_CLASSES
#   * .reconfort_continuous_score formula
#   * .classify_pixels_to_reconfort_classes / .cluster_reconfort_pixels
#   * .postprocess_reconfort_rasters (orchestration)
#   * classify_disturbance() 3-way fusion + method_overlap
#   * .insert_reconfort_alerts() integration (with_clean_db)

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()
}

# EPSG:2154 raster, 10 m pixels, same origin as the FORDEAD fixtures.
make_reconfort_raster <- function(values, nrow = 5L, ncol = 5L) {
  skip_if_no_terra()
  r <- terra::rast(nrow = nrow, ncol = ncol,
                   xmin = 700000, xmax = 700000 + ncol * 10,
                   ymin = 6800000, ymax = 6800000 + nrow * 10,
                   crs = "EPSG:2154")
  terra::values(r) <- values
  r
}

reconfort_seed_zone <- function(con) {
  pol <- sf::st_as_sfc(sf::st_bbox(c(xmin = 700000, ymin = 6800000,
                                     xmax = 701000, ymax = 6801000),
                                   crs = 2154))
  pl <- sf::st_sf(plot_id = c("P1", "P2"),
                  geometry = sf::st_sfc(
                    sf::st_point(c(700100, 6800100)),
                    sf::st_point(c(700500, 6800500)),
                    crs = 2154))
  register_monitoring_zone(con, "Zone-reconfort-test", pol, pl)
}


# ---- constants -------------------------------------------------------

test_that("RECONFORT_CLASSES has 3 classes for oak/chestnut, 2 for pine", {
  expect_equal(length(RECONFORT_CLASSES$CHE), 3L)
  expect_equal(length(RECONFORT_CLASSES$CHT), 3L)
  expect_equal(length(RECONFORT_CLASSES$PS), 2L)
  expect_equal(RECONFORT_CLASSES$CHE[1], "1-sain")
  expect_equal(RECONFORT_CLASSES$PS[2], "2-deperissant")
})

test_that("RECONFORT_CONFIDENCE_WEIGHTS / ALERT_CLASSES are coherent", {
  expect_equal(unname(RECONFORT_CONFIDENCE_WEIGHTS$CHE["1-sain"]), 0)
  expect_true(RECONFORT_CONFIDENCE_WEIGHTS$CHE["3-tres-deperissant"] >
              RECONFORT_CONFIDENCE_WEIGHTS$CHE["2-deperissant"])
  expect_setequal(RECONFORT_ALERT_CLASSES,
                  c("2-deperissant", "3-tres-deperissant"))
  expect_false("1-sain" %in% RECONFORT_ALERT_CLASSES)
})


# ---- continuous score ------------------------------------------------

test_that(".reconfort_continuous_score matches the production formula", {
  # healthy: P1=1000 -> ~0 ; severe: P3=1000 -> ~100
  expect_equal(nemeton:::.reconfort_continuous_score(1000, 0, 0),
               (1001 - 1000) / 30)
  expect_equal(nemeton:::.reconfort_continuous_score(0, 0, 1000),
               (1001 + 2000) / 30)
  # pine (no P3): defaults to 0
  expect_equal(nemeton:::.reconfort_continuous_score(0, 1000),
               (1001 + 1000) / 30)
})


# ---- reclassify ------------------------------------------------------

test_that(".classify_pixels_to_reconfort_classes keeps 1..n, NAs the rest", {
  skip_if_no_terra()
  r <- make_reconfort_raster(c(0, 1, 2, 3, 4,
                               rep(1L, 20L)))
  out <- nemeton:::.classify_pixels_to_reconfort_classes(r, "CHE")
  v <- terra::values(out)[1:5]
  expect_true(is.na(v[1]))                 # code 0 (masked) -> NA
  expect_equal(v[2:4], c(1, 2, 3))         # 1..3 kept
  expect_true(is.na(v[5]))                 # code 4 out of range -> NA
})

test_that(".classify_pixels_to_reconfort_classes rejects pine code 3", {
  skip_if_no_terra()
  r <- make_reconfort_raster(c(1, 2, 3, rep(1L, 22L)))
  out <- nemeton:::.classify_pixels_to_reconfort_classes(r, "PS")
  expect_true(is.na(terra::values(out)[3]))   # n=2 for pine -> 3 is NA
})

test_that(".reconfort_species_classes rejects unknown species", {
  expect_error(nemeton:::.reconfort_species_classes("EPC"), "Unknown")
})


# ---- clustering ------------------------------------------------------

# 6-pixel class-3 block (one patch) + 2 isolated class-2 pixels (dropped).
.reconfort_cluster_values <- c(
  3, 3, 3, 1, 1,
  3, 3, 3, 1, 2,
  1, 1, 1, 1, 1,
  2, 1, 1, 1, 1,
  1, 1, 1, 1, 1
)

test_that(".cluster_reconfort_pixels keeps the class-3 patch, drops tiny", {
  skip_if_no_terra()
  r  <- make_reconfort_raster(.reconfort_cluster_values)
  cl <- nemeton:::.classify_pixels_to_reconfort_classes(r, "CHE")
  patches <- nemeton:::.cluster_reconfort_pixels(cl, "CHE", min_pixels = 5L)

  expect_named(patches, c("2-deperissant", "3-tres-deperissant"))
  # class 2: 2 isolated pixels, both < min_pixels -> all NA
  expect_true(all(is.na(terra::values(patches[["2-deperissant"]]))))
  # class 3: one patch of 6 pixels survives
  v3 <- terra::values(patches[["3-tres-deperissant"]])
  expect_equal(sum(!is.na(v3)), 6L)
  expect_equal(length(unique(v3[!is.na(v3)])), 1L)
})

test_that(".cluster_reconfort_pixels for pine only iterates class 2", {
  skip_if_no_terra()
  r  <- make_reconfort_raster(c(rep(2L, 6L), rep(1L, 19L)))
  cl <- nemeton:::.classify_pixels_to_reconfort_classes(r, "PS")
  patches <- nemeton:::.cluster_reconfort_pixels(cl, "PS", min_pixels = 5L)
  expect_named(patches, "2-deperissant")
})


# ---- orchestration ---------------------------------------------------

test_that(".postprocess_reconfort_rasters stamps trigger_date + stress", {
  skip_if_no_terra()
  classif <- make_reconfort_raster(.reconfort_cluster_values)
  # continuous score: 90 on the class-3 block, NA elsewhere
  score_vals <- ifelse(.reconfort_cluster_values == 3, 90, NA_real_)
  score <- make_reconfort_raster(score_vals)

  run_date <- as.Date("2025-08-15")
  out <- nemeton:::.postprocess_reconfort_rasters(
    list(classif = classif, continuous_score = score),
    species = "CHE", trigger_date = run_date, min_pixels = 5L)

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 1L)                       # one surviving patch
  expect_equal(out$confidence_class, "3-tres-deperissant")
  expect_equal(out$n_pixels, 6L)
  expect_equal(out$stress_index, 90)                # mean score on the patch
  expect_equal(out$trigger_date, run_date)          # run date stamped
  expect_true(sf::st_crs(out) == sf::st_crs(2154))
})

test_that(".postprocess_reconfort_rasters errors without classif", {
  expect_error(
    nemeton:::.postprocess_reconfort_rasters(list(), species = "CHE",
                                             trigger_date = Sys.Date()),
    "classif")
})


# ---- G2 fusion (3 voies) ---------------------------------------------

test_that("classify_disturbance: lone RECONFORT -> progressive, no overlap", {
  df <- data.frame(plot_id = 1L, alert_type = "reconfort_dieback",
                   trigger_date = as.Date("2025-06-01"))
  out <- classify_disturbance(df)
  expect_equal(out$disturbance_type, "progressive")
  expect_false(out$method_overlap)
})

test_that("classify_disturbance: RECONFORT + FAST -> mechanical", {
  df <- data.frame(
    plot_id = c(1L, 1L),
    alert_type = c("reconfort_dieback", "ndvi_drop"),
    trigger_date = as.Date(c("2025-06-01", "2025-06-10")))
  out <- classify_disturbance(df, window_days = 30L)
  expect_equal(out$disturbance_type[1], "mechanical")     # reconfort
  expect_true(is.na(out$disturbance_type[2]))             # fast paired
})

test_that("classify_disturbance: FORDEAD + RECONFORT -> progressive + overlap", {
  df <- data.frame(
    plot_id = c(1L, 1L),
    alert_type = c("fordead_dieback", "reconfort_dieback"),
    trigger_date = as.Date(c("2025-06-01", "2025-06-05")))
  out <- classify_disturbance(df)
  expect_equal(out$disturbance_type, c("progressive", "progressive"))
  expect_true(all(out$method_overlap))                   # both methods
})

test_that("classify_disturbance: all three -> mechanical + overlap", {
  df <- data.frame(
    plot_id = c(1L, 1L, 1L),
    alert_type = c("fordead_dieback", "reconfort_dieback", "nbr_drop"),
    trigger_date = as.Date(c("2025-06-01", "2025-06-03", "2025-06-08")))
  out <- classify_disturbance(df)
  expect_equal(out$disturbance_type[1:2], c("mechanical", "mechanical"))
  expect_true(all(out$method_overlap[1:2]))
  expect_true(is.na(out$disturbance_type[3]))            # fast paired
})

test_that("classify_disturbance: 2-way FORDEAD behaviour is preserved", {
  df <- data.frame(
    plot_id = c(1L, 2L),
    alert_type = c("fordead_dieback", "fordead_dieback"),
    trigger_date = as.Date(c("2025-06-01", "2025-06-01")))
  out <- classify_disturbance(df)
  expect_equal(out$disturbance_type, c("progressive", "progressive"))
  expect_false(any(out$method_overlap))
})

test_that("classify_disturbance: empty df gains the two columns", {
  df <- data.frame(plot_id = integer(0), alert_type = character(0),
                   trigger_date = as.Date(character(0)))
  out <- classify_disturbance(df)
  expect_true(all(c("disturbance_type", "method_overlap") %in% names(out)))
  expect_equal(nrow(out), 0L)
})


# ---- DB insertion ----------------------------------------------------

test_that(".insert_reconfort_alerts inserts reconfort_dieback, idempotent", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    zid <- reconfort_seed_zone(con)

    pts <- sf::st_sf(
      confidence_class = c("2-deperissant", "3-tres-deperissant"),
      stress_index     = c(45, 92),
      trigger_date     = as.Date(c("2025-08-15", "2025-08-15")),
      n_pixels         = c(8L, 12L),
      area_m2          = c(800, 1200),
      cluster_id       = 1:2,
      geometry = sf::st_sfc(
        sf::st_point(c(700110, 6800110)),
        sf::st_point(c(700510, 6800510)), crs = 2154))

    n1 <- nemeton:::.insert_reconfort_alerts(con, pts, zone_id = zid)
    expect_equal(n1, 2L)
    # Full zone+type replace (idempotent) : re-run → purge + ré-insertion,
    # total = 2 (pas de doublon).
    n2 <- nemeton:::.insert_reconfort_alerts(con, pts, zone_id = zid)
    expect_equal(n2, 2L)

    rs <- DBI::dbGetQuery(con,
      "SELECT zone_id, plot_id, alert_type, confidence_class, stress_index
         FROM alert ORDER BY cluster_id")
    expect_equal(nrow(rs), 2L)                            # pas de doublon
    expect_true(all(rs$zone_id == zid))
    expect_true(all(is.na(rs$plot_id)))                  # plot découplé
    expect_equal(unique(rs$alert_type), "reconfort_dieback")
    expect_setequal(rs$confidence_class,
                    c("2-deperissant", "3-tres-deperissant"))
  })
})

test_that(".insert_reconfort_alerts on empty / NULL input is a no-op", {
  empty <- sf::st_sf(geometry = sf::st_sfc(crs = 2154))
  expect_equal(nemeton:::.insert_reconfort_alerts(NULL, empty, zone_id = 1L),
               0L)
})

test_that("the alert_type index exists after migration", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    idx <- DBI::dbGetQuery(con,
      "SELECT indexname FROM pg_indexes WHERE tablename = 'alert'")
    expect_true("alert_type_idx" %in% idx$indexname)
  })
})
