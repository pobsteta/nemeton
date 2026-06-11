# test-fordead-postprocess.R — E6.c.2
#
# Covers:
#   * Constants FORDEAD_CLASSES / FORDEAD_CONFIDENCE_WEIGHTS
#   * Raster post-processing: classify / cluster / centroids
#   * classify_disturbance() (G2 fusion)
#   * list_alerts() integration (with_clean_db)
#   * .insert_fordead_alerts() integration

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()
}

# Helper: tiny SpatRaster of class codes (Lambert-93, 10 m pixels).
make_state_raster <- function(values, nrow = 5L, ncol = 5L) {
  skip_if_no_terra()
  r <- terra::rast(nrow = nrow, ncol = ncol,
                   xmin = 700000, xmax = 700000 + ncol * 10,
                   ymin = 6800000, ymax = 6800000 + nrow * 10,
                   crs = "EPSG:2154")
  terra::values(r) <- values
  names(r) <- "state"
  r
}


# ---- constants -------------------------------------------------------

test_that("FORDEAD_CLASSES is the canonical 5-class vocabulary", {
  skip_if_not_installed("terra")
  expect_equal(FORDEAD_CLASSES,
               c("0-hors-anomalie", "1-faible", "2-moyenne",
                 "3-forte", "4-sol-nu"))
})

test_that("FORDEAD_CONFIDENCE_WEIGHTS reproduces ONF/DSF coefficients", {
  skip_if_not_installed("terra")
  expect_named(FORDEAD_CONFIDENCE_WEIGHTS,
               c("1-faible", "2-moyenne", "3-forte", "4-sol-nu"))
  expect_equal(unname(FORDEAD_CONFIDENCE_WEIGHTS),
               c(0.10, 0.30, 0.82, 0.70))
  # Class 3 is the most trusted; 1 is the least trusted.
  expect_gt(FORDEAD_CONFIDENCE_WEIGHTS[["3-forte"]],
            FORDEAD_CONFIDENCE_WEIGHTS[["1-faible"]])
})


# ---- .classify_pixels_to_classes -------------------------------------

test_that(".classify_pixels_to_classes keeps codes 0..4 and NAs the rest", {
  skip_if_no_terra()
  r <- make_state_raster(c(0, 1, 2, 3, 4,
                           5, -1, NA, 0, 1,
                           2, 3, 4, 0, 0,
                           1, 2, 3, 4, 0,
                           0, 1, 2, 3, 4))
  out <- nemeton:::.classify_pixels_to_classes(r)
  v <- terra::values(out)
  expect_true(all(is.na(v) | v %in% 0:4))
  # Codes 5 and -1 should now be NA, NA stays NA.
  expect_true(all(is.na(v[c(6, 7, 8)])))
})

test_that(".classify_pixels_to_classes rejects non-SpatRaster", {
  skip_if_not_installed("terra")
  expect_error(nemeton:::.classify_pixels_to_classes("not-a-raster"),
               "SpatRaster")
})


# ---- .cluster_anomaly_pixels -----------------------------------------

test_that(".cluster_anomaly_pixels groups class-3 pixels into one patch", {
  skip_if_no_terra()
  vals <- c(0, 0, 0, 0, 0,
            0, 3, 3, 3, 0,
            0, 3, 3, 3, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0)
  r <- make_state_raster(vals)
  out <- nemeton:::.cluster_anomaly_pixels(r, min_pixels = 1L)
  expect_named(out, c("1-faible", "2-moyenne", "3-forte", "4-sol-nu"))
  v3 <- terra::values(out[["3-forte"]])
  expect_equal(length(unique(v3[!is.na(v3)])), 1L)  # one connected patch
  expect_true(all(is.na(terra::values(out[["1-faible"]]))))
})

test_that(".cluster_anomaly_pixels drops patches smaller than min_pixels", {
  skip_if_no_terra()
  vals <- c(0, 0, 0, 0, 0,
            0, 3, 0, 3, 0,   # two singletons of class 3
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0)
  r <- make_state_raster(vals)
  out <- nemeton:::.cluster_anomaly_pixels(r, min_pixels = 5L)
  v3 <- terra::values(out[["3-forte"]])
  expect_true(all(is.na(v3)))   # both singletons dropped
})

test_that(".cluster_anomaly_pixels rejects bad connectivity", {
  skip_if_no_terra()
  r <- make_state_raster(rep(0L, 25L))
  expect_error(
    nemeton:::.cluster_anomaly_pixels(r, connectivity = 7L),
    "connectivity")
})


# ---- .cluster_to_centroids -------------------------------------------

test_that(".cluster_to_centroids returns one POINT per patch with metadata", {
  skip_if_no_terra()
  state_vals <- c(0, 0, 0, 0, 0,
                  0, 3, 3, 3, 0,
                  0, 3, 3, 3, 0,
                  0, 0, 0, 0, 4,
                  0, 0, 0, 0, 4)
  state <- make_state_raster(state_vals)
  stress <- make_state_raster(seq(0.1, 2.5, length.out = 25))
  fdate  <- make_state_raster(rep(20000L, 25L))  # 2024-10-04

  cl <- nemeton:::.classify_pixels_to_classes(state)
  patches <- nemeton:::.cluster_anomaly_pixels(cl, min_pixels = 2L)
  pts <- nemeton:::.cluster_to_centroids(patches,
                                         stress_index_raster       = stress,
                                         first_dieback_date_raster = fdate)

  expect_s3_class(pts, "sf")
  expect_setequal(unique(pts$confidence_class), c("3-forte", "4-sol-nu"))
  expect_setequal(c("confidence_class", "stress_index", "trigger_date",
                    "n_pixels", "area_m2", "cluster_id"),
                  setdiff(names(pts), "geometry"))
  # The class-3 patch covers 6 pixels, the class-4 patch 2.
  k3 <- pts[pts$confidence_class == "3-forte", ]
  k4 <- pts[pts$confidence_class == "4-sol-nu", ]
  expect_equal(sum(k3$n_pixels), 6L)
  expect_equal(sum(k4$n_pixels), 2L)
  # 10 m pixels → 100 m² each.
  expect_equal(sum(k3$area_m2), 600)
  # All clusters share the same date raster.
  expect_true(all(format(pts$trigger_date) == "2024-10-04"))
})

test_that(".cluster_to_centroids on empty input returns an empty sf", {
  skip_if_no_terra()
  pts <- nemeton:::.cluster_to_centroids(list())
  expect_s3_class(pts, "sf")
  expect_equal(nrow(pts), 0L)
})


# ---- .postprocess_fordead_rasters (top-level) ------------------------

test_that(".postprocess_fordead_rasters loads from paths and returns POINT sf", {
  skip_if_no_terra()
  tmp <- withr::local_tempdir()
  state_vals <- c(rep(0L, 10L), rep(3L, 10L), rep(0L, 5L))
  state_path <- file.path(tmp, "state.tif")
  terra::writeRaster(make_state_raster(state_vals), state_path,
                     overwrite = TRUE, datatype = "INT2S")

  pts <- nemeton:::.postprocess_fordead_rasters(
    list(state = state_path,
         stress_index = NULL,
         first_dieback_date = NULL),
    min_pixels = 1L)
  expect_s3_class(pts, "sf")
  expect_true(nrow(pts) >= 1L)
  expect_true(all(is.na(pts$stress_index)))
  expect_true(all(is.na(pts$trigger_date)))
})

test_that(".postprocess_fordead_rasters errors when state is missing", {
  skip_if_not_installed("terra")
  expect_error(
    nemeton:::.postprocess_fordead_rasters(list(state = NULL)),
    "rasters\\$state")
})


# ---- classify_disturbance --------------------------------------------

test_that("classify_disturbance handles an empty data frame", {
  skip_if_not_installed("terra")
  df <- data.frame(plot_id = integer(0), alert_type = character(0),
                   trigger_date = as.Date(character(0)))
  out <- classify_disturbance(df)
  expect_equal(nrow(out), 0L)
  expect_true("disturbance_type" %in% names(out))
})

test_that("classify_disturbance: lone fordead → progressive, paired → mechanical", {
  skip_if_not_installed("terra")
  df <- data.frame(
    plot_id      = c(1L, 2L, 2L),
    alert_type   = c("fordead_dieback", "fordead_dieback", "ndvi_drop"),
    trigger_date = as.Date(c("2024-06-01", "2024-06-15", "2024-06-20")),
    stringsAsFactors = FALSE
  )
  out <- classify_disturbance(df, window_days = 30)
  expect_equal(out$disturbance_type[1], "progressive")  # plot 1 — alone
  expect_equal(out$disturbance_type[2], "mechanical")   # plot 2 — paired
  # The companion ndvi_drop is masked: the FORDEAD row carries the verdict.
  expect_true(is.na(out$disturbance_type[3]))
})

test_that("classify_disturbance: lone ndvi_drop → recent_event", {
  skip_if_not_installed("terra")
  df <- data.frame(
    plot_id      = c(1L, 1L),
    alert_type   = c("ndvi_drop", "nbr_drop"),
    trigger_date = as.Date(c("2024-07-01", "2024-08-15")),
    stringsAsFactors = FALSE
  )
  out <- classify_disturbance(df, window_days = 30)
  expect_equal(out$disturbance_type, c("recent_event", "recent_event"))
})

test_that("classify_disturbance respects window_days", {
  skip_if_not_installed("terra")
  df <- data.frame(
    plot_id      = c(1L, 1L),
    alert_type   = c("fordead_dieback", "ndvi_drop"),
    trigger_date = as.Date(c("2024-06-01", "2024-08-15")),  # 75 days apart
    stringsAsFactors = FALSE
  )
  out_short <- classify_disturbance(df, window_days = 30)
  out_long  <- classify_disturbance(df, window_days = 90)
  expect_equal(out_short$disturbance_type[1], "progressive")
  expect_equal(out_long$disturbance_type[1],  "mechanical")
})

test_that("classify_disturbance does not pair an alert with itself", {
  skip_if_not_installed("terra")
  df <- data.frame(
    plot_id      = 1L,
    alert_type   = "fordead_dieback",
    trigger_date = as.Date("2024-06-01")
  )
  expect_equal(classify_disturbance(df)$disturbance_type, "progressive")
})

test_that("classify_disturbance rejects missing columns", {
  skip_if_not_installed("terra")
  expect_error(classify_disturbance(data.frame(x = 1)),
               "plot_id|alert_type|trigger_date")
})

test_that("classify_disturbance ignores cross-plot pairs", {
  skip_if_not_installed("terra")
  df <- data.frame(
    plot_id      = c(1L, 2L),
    alert_type   = c("fordead_dieback", "ndvi_drop"),
    trigger_date = as.Date(c("2024-06-01", "2024-06-05")),
    stringsAsFactors = FALSE
  )
  out <- classify_disturbance(df)
  expect_equal(out$disturbance_type[1], "progressive")
  expect_equal(out$disturbance_type[2], "recent_event")
})

test_that("classify_disturbance leaves unknown alert_type as NA", {
  skip_if_not_installed("terra")
  df <- data.frame(
    plot_id      = 1L,
    alert_type   = "future_alert",
    trigger_date = as.Date("2024-06-01")
  )
  expect_true(is.na(classify_disturbance(df)$disturbance_type))
})


# ---- list_alerts integration -----------------------------------------

# Helper: register a minimal zone with two plots, optionally insert
# fixture alerts. Returns the zone_id.
seed_zone <- function(con) {
  pol <- sf::st_as_sfc(sf::st_bbox(c(xmin = 700000, ymin = 6800000,
                                     xmax = 701000, ymax = 6801000),
                                   crs = 2154))
  pl <- sf::st_sf(plot_id = c("P1", "P2"),
                  geometry = sf::st_sfc(
                    sf::st_point(c(700100, 6800100)),
                    sf::st_point(c(700500, 6800500)),
                    crs = 2154))
  register_monitoring_zone(con, "Zone-fordead-test", pol, pl)
}


test_that("list_alerts honours the G1 default class filter", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    zid <- seed_zone(con)
    plots <- DBI::dbGetQuery(con,
      "SELECT id FROM plot WHERE zone_id = $1 ORDER BY plot_id",
      params = list(zid))$id
    DBI::dbExecute(con,
      "INSERT INTO alert (plot_id, alert_type, trigger_date,
                          confidence_class, stress_index)
       VALUES
         ($1, 'fordead_dieback', '2024-06-01', '1-faible', 0.5),
         ($1, 'fordead_dieback', '2024-06-15', '3-forte',  1.5),
         ($2, 'ndvi_drop',       '2024-07-01', NULL,       NULL)",
      params = list(plots[1], plots[2]))

    default <- list_alerts(con, zid)
    # Default keeps class 3-forte + everything without a class
    # (rolling-window) but drops the 1-faible row.
    expect_equal(nrow(default), 2L)
    expect_setequal(default$alert_type,
                    c("fordead_dieback", "ndvi_drop"))

    all_classes <- list_alerts(con, zid, classes = NULL)
    expect_equal(nrow(all_classes), 3L)
  })
})

test_that("list_alerts filters by validation_status and period", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    zid <- seed_zone(con)
    plots <- DBI::dbGetQuery(con,
      "SELECT id FROM plot WHERE zone_id = $1 ORDER BY plot_id",
      params = list(zid))$id
    DBI::dbExecute(con,
      "INSERT INTO alert (plot_id, alert_type, trigger_date,
                          confidence_class, validation_status)
       VALUES
         ($1, 'fordead_dieback', '2024-05-01', '3-forte', 'pending'),
         ($1, 'fordead_dieback', '2024-08-01', '3-forte', 'confirmed'),
         ($2, 'fordead_dieback', '2024-09-01', '3-forte', 'false_positive')",
      params = list(plots[1], plots[2]))

    only_confirmed <- list_alerts(con, zid,
                                  validation_status = "confirmed")
    expect_equal(nrow(only_confirmed), 1L)

    summer <- list_alerts(con, zid,
                          period = c("2024-07-01", "2024-08-31"))
    expect_equal(nrow(summer), 1L)

    multi <- list_alerts(con, zid,
                         validation_status = c("pending", "confirmed"))
    expect_equal(nrow(multi), 2L)
  })
})

test_that("list_alerts returns an empty sf when no alert matches", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    zid <- seed_zone(con)
    out <- list_alerts(con, zid)
    expect_s3_class(out, "sf")
    expect_equal(nrow(out), 0L)
  })
})


# ---- .insert_fordead_alerts integration ------------------------------

# Build a centroid sf in EPSG:2154 placed on / near the zone plots
make_centroids <- function(coords, classes,
                           dates  = as.Date("2024-06-15"),
                           stress = 1.5) {
  pts <- lapply(seq_len(nrow(coords)), function(i) {
    sf::st_point(c(coords[i, 1], coords[i, 2]))
  })
  sf::st_sf(
    confidence_class = classes,
    stress_index     = rep_len(stress, nrow(coords)),
    trigger_date     = rep_len(as.Date(dates), nrow(coords)),
    n_pixels         = rep(10L, nrow(coords)),
    area_m2          = rep(1000, nrow(coords)),
    cluster_id       = seq_len(nrow(coords)),
    geometry         = sf::st_sfc(pts, crs = 2154)
  )
}

test_that(".insert_fordead_alerts inserts new rows and is idempotent", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    zid <- seed_zone(con)

    # Two centroids, one near each plot
    pts <- make_centroids(matrix(c(700110, 6800110,
                                   700510, 6800510),
                                 ncol = 2, byrow = TRUE),
                          classes = c("3-forte", "4-sol-nu"))
    n1 <- nemeton:::.insert_fordead_alerts(con, pts, zone_id = zid)
    expect_equal(n1, 2L)

    n2 <- nemeton:::.insert_fordead_alerts(con, pts, zone_id = zid)
    expect_equal(n2, 0L)

    rs <- DBI::dbGetQuery(con,
      "SELECT alert_type, confidence_class, stress_index, validation_status
         FROM alert ORDER BY id")
    expect_equal(nrow(rs), 2L)
    expect_equal(unique(rs$alert_type), "fordead_dieback")
    expect_setequal(rs$confidence_class, c("3-forte", "4-sol-nu"))
    expect_equal(unique(rs$validation_status), "pending")
  })
})

test_that(".insert_fordead_alerts skips centroids beyond radius_m", {
  skip_if_no_timescaledb()
  with_clean_db(function(con) {
    db_migrate(con)
    zid <- seed_zone(con)

    far <- make_centroids(matrix(c(710000, 6810000), ncol = 2),
                          classes = "3-forte")
    expect_warning(
      n <- nemeton:::.insert_fordead_alerts(con, far, zone_id = zid,
                                            radius_m = 200),
      "farther than"
    )
    expect_equal(n, 0L)
  })
})

test_that(".insert_fordead_alerts on empty input is a no-op", {
  skip_if_not_installed("terra")
  empty <- sf::st_sf(
    confidence_class = character(0),
    stress_index     = numeric(0),
    trigger_date     = as.Date(character(0)),
    n_pixels         = integer(0),
    area_m2          = numeric(0),
    cluster_id       = integer(0),
    geometry         = sf::st_sfc(crs = 2154)
  )
  # No DB call at all — short-circuit on empty.
  expect_equal(nemeton:::.insert_fordead_alerts(NULL, empty, zone_id = 1),
               0L)
})
