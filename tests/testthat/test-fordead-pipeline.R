# test-fordead-pipeline.R — orchestrator run_fordead_dieback (E6.c.1)
#
# All FORDEAD Python phases are mocked: we never touch reticulate
# or a virtualenv. The fake module records the order and arguments
# of the calls so we can assert on the orchestration contract.

skip_if_no_reticulate <- function() {
  testthat::skip_if_not_installed("reticulate")
}

make_aoi <- function(crs = 2154) {
  pol <- sf::st_polygon(list(matrix(
    c(0, 0,  100, 0,  100, 100,  0, 100,  0, 0),
    ncol = 2, byrow = TRUE
  )))
  sf::st_sf(geometry = sf::st_sfc(pol, crs = crs))
}

# Build a fake `fd` module recording the calls. Each step is a
# nested function-of-function so calls look like:
#   fd$steps$step1_compute_masked_vegetationindex$compute_masked_vegetationindex(...)
make_fake_fordead_module <- function(env, fail_at = NULL) {
  step <- function(label) {
    list2 <- list()
    list2[[label]] <- function(...) {
      env$calls <- c(env$calls, label)
      env$args[[label]] <- list(...)
      if (!is.null(fail_at) && identical(fail_at, label)) {
        stop(paste0("simulated FORDEAD error in ", label))
      }
      invisible(NULL)
    }
    list2
  }
  list(
    `__version__` = "2.1.4",
    steps = list(
      step1_compute_masked_vegetationindex = step("compute_masked_vegetationindex"),
      step2_train_model                    = step("train_model"),
      step3_dieback_detection              = step("dieback_detection"),
      step5_export_results                 = step("export_results")
    )
  )
}


# ---- argument validation ---------------------------------------------

test_that("rejects non-sf aoi", {
  expect_error(run_fordead_dieback(aoi = "not-sf"),
               "must be an sf")
})

test_that("rejects aoi in wrong CRS", {
  aoi_4326 <- make_aoi(crs = 4326)
  expect_error(run_fordead_dieback(aoi = aoi_4326),
               "EPSG:2154|Lambert")
})

test_that("rejects unknown vegetation_index", {
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi, vegetation_index = "EVI"),
    "vegetation_index"
  )
})

test_that("rejects threshold_anomaly out of [0.05, 0.50]", {
  aoi <- make_aoi()
  expect_error(run_fordead_dieback(aoi, threshold_anomaly = 0.0),
               "threshold_anomaly")
  expect_error(run_fordead_dieback(aoi, threshold_anomaly = 0.6),
               "threshold_anomaly")
})

test_that("rejects non-chronological dates_training", {
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi,
                        dates_training = c("2018-01-01", "2017-01-01")),
    "dates_training"
  )
})

test_that("rejects dates_monitoring starting before dates_training", {
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi,
                        dates_training   = c("2018-01-01", "2019-12-31"),
                        dates_monitoring = c("2017-06-01", "2024-01-01")),
    "dates_monitoring"
  )
})


# ---- successful orchestration ----------------------------------------

test_that("runs all five steps in order and returns success", {
  skip_if_no_reticulate()
  aoi <- make_aoi()
  rec <- new.env(parent = emptyenv()); rec$calls <- character(0); rec$args <- list()
  fake_fd <- make_fake_fordead_module(rec)

  testthat::local_mocked_bindings(
    .ensure_fordead_python       = function(env_name = "test", verbose = TRUE, ...) fake_fd,
    .postprocess_fordead_rasters = function(rasters, min_pixels = 5L,
                                            connectivity = 8L) {
      sf::st_sf(
        confidence_class = character(0),
        stress_index     = numeric(0),
        trigger_date     = as.Date(character(0)),
        n_pixels         = integer(0),
        area_m2          = numeric(0),
        cluster_id       = integer(0),
        geometry         = sf::st_sfc(crs = 2154)
      )
    },
    .package = "nemeton"
  )
  testthat::local_mocked_bindings(
    py_capture_output = function(expr) { force(expr); "" },
    py_get_attr       = function(x, name, silent = TRUE) x[[name]],
    py_to_r           = function(x) x,
    .package = "reticulate"
  )

  res <- run_fordead_dieback(aoi, verbose = FALSE)

  expect_equal(res$status, "success")
  expect_equal(rec$calls, c("compute_masked_vegetationindex",
                            "train_model",
                            "dieback_detection",
                            "export_results"))
  expect_equal(res$fordead_version, "2.1.4")
  expect_true(dir.exists(res$output_dir))
  expect_named(res$rasters,
               c("state", "first_dieback_date", "stress_index"))
  expect_equal(res$n_alerts_inserted, 0L)
  expect_null(res$alerts_sf)   # empty postprocess collapses to NULL
  expect_true(is.numeric(res$duration_sec) && res$duration_sec >= 0)
})


test_that("propagates Python errors as status='error' with message", {
  skip_if_no_reticulate()
  aoi <- make_aoi()
  rec <- new.env(parent = emptyenv()); rec$calls <- character(0); rec$args <- list()
  fake_fd <- make_fake_fordead_module(rec, fail_at = "dieback_detection")

  testthat::local_mocked_bindings(
    .ensure_fordead_python = function(env_name = "test", verbose = TRUE, ...) fake_fd,
    .package = "nemeton"
  )
  testthat::local_mocked_bindings(
    py_capture_output = function(expr) { force(expr); "" },
    py_get_attr       = function(x, name, silent = TRUE) x[[name]],
    py_to_r           = function(x) x,
    .package = "reticulate"
  )

  res <- run_fordead_dieback(aoi, verbose = FALSE)
  expect_equal(res$status, "error")
  expect_match(res$message, "dieback_detection")
  # Pipeline stopped before export_results was called.
  expect_false("export_results" %in% rec$calls)
})


test_that("forest_mask = NULL routes through the BD Forêt stub", {
  skip_if_no_reticulate()
  aoi <- make_aoi()
  rec <- new.env(parent = emptyenv()); rec$calls <- character(0); rec$args <- list()
  fake_fd <- make_fake_fordead_module(rec)

  bd_called <- 0L
  testthat::local_mocked_bindings(
    .ensure_fordead_python = function(env_name = "test", verbose = TRUE, ...) fake_fd,
    .download_or_use_cached_bd_foret = function(aoi) {
      bd_called <<- bd_called + 1L
      NULL
    },
    .postprocess_fordead_rasters = function(rasters, min_pixels = 5L,
                                            connectivity = 8L) {
      sf::st_sf(
        confidence_class = character(0),
        stress_index     = numeric(0),
        trigger_date     = as.Date(character(0)),
        n_pixels         = integer(0),
        area_m2          = numeric(0),
        cluster_id       = integer(0),
        geometry         = sf::st_sfc(crs = 2154)
      )
    },
    .package = "nemeton"
  )
  testthat::local_mocked_bindings(
    py_capture_output = function(expr) { force(expr); "" },
    py_get_attr       = function(x, name, silent = TRUE) x[[name]],
    py_to_r           = function(x) x,
    .package = "reticulate"
  )

  res <- run_fordead_dieback(aoi, forest_mask = NULL, verbose = FALSE)
  expect_equal(res$status, "success")
  expect_equal(bd_called, 1L)
})


test_that("a user-supplied forest_mask path bypasses the BD Forêt stub", {
  skip_if_no_reticulate()
  aoi <- make_aoi()
  rec <- new.env(parent = emptyenv()); rec$calls <- character(0); rec$args <- list()
  fake_fd <- make_fake_fordead_module(rec)

  tmp_mask <- tempfile(fileext = ".tif")
  file.create(tmp_mask)
  on.exit(unlink(tmp_mask), add = TRUE)

  bd_called <- 0L
  testthat::local_mocked_bindings(
    .ensure_fordead_python = function(env_name = "test", verbose = TRUE, ...) fake_fd,
    .download_or_use_cached_bd_foret = function(aoi) {
      bd_called <<- bd_called + 1L
      NULL
    },
    .postprocess_fordead_rasters = function(rasters, min_pixels = 5L,
                                            connectivity = 8L) {
      sf::st_sf(
        confidence_class = character(0),
        stress_index     = numeric(0),
        trigger_date     = as.Date(character(0)),
        n_pixels         = integer(0),
        area_m2          = numeric(0),
        cluster_id       = integer(0),
        geometry         = sf::st_sfc(crs = 2154)
      )
    },
    .package = "nemeton"
  )
  testthat::local_mocked_bindings(
    py_capture_output = function(expr) { force(expr); "" },
    py_get_attr       = function(x, name, silent = TRUE) x[[name]],
    py_to_r           = function(x) x,
    .package = "reticulate"
  )

  res <- run_fordead_dieback(aoi, forest_mask = tmp_mask, verbose = FALSE)
  expect_equal(res$status, "success")
  expect_equal(bd_called, 0L)
})


test_that("rejects a forest_mask path that does not exist", {
  aoi <- make_aoi()
  expect_error(
    run_fordead_dieback(aoi, forest_mask = "/no/such/file.tif"),
    "forest_mask"
  )
})


test_that("non-empty postprocess sets alerts_sf, INSERT skipped without con", {
  skip_if_no_reticulate()
  aoi <- make_aoi()
  rec <- new.env(parent = emptyenv()); rec$calls <- character(0); rec$args <- list()
  fake_fd <- make_fake_fordead_module(rec)

  fake_alerts <- sf::st_sf(
    confidence_class = c("3-forte", "4-sol-nu"),
    stress_index     = c(1.5, 2.1),
    trigger_date     = as.Date(c("2024-06-01", "2024-07-15")),
    n_pixels         = c(10L, 20L),
    area_m2          = c(1000, 2000),
    cluster_id       = c(1L, 2L),
    geometry         = sf::st_sfc(sf::st_point(c(700100, 6800100)),
                                  sf::st_point(c(700500, 6800500)),
                                  crs = 2154)
  )
  insert_called <- 0L
  testthat::local_mocked_bindings(
    .ensure_fordead_python       = function(env_name = "test", verbose = TRUE, ...) fake_fd,
    .postprocess_fordead_rasters = function(rasters, min_pixels = 5L,
                                            connectivity = 8L) fake_alerts,
    .insert_fordead_alerts       = function(con, alerts_sf, zone_id, ...) {
      insert_called <<- insert_called + 1L
      nrow(alerts_sf)
    },
    .package = "nemeton"
  )
  testthat::local_mocked_bindings(
    py_capture_output = function(expr) { force(expr); "" },
    py_get_attr       = function(x, name, silent = TRUE) x[[name]],
    py_to_r           = function(x) x,
    .package = "reticulate"
  )

  # Without con/zone_id : alerts_sf populated but no INSERT.
  res <- run_fordead_dieback(aoi, verbose = FALSE)
  expect_equal(nrow(res$alerts_sf), 2L)
  expect_equal(res$n_alerts_inserted, 0L)
  expect_equal(insert_called, 0L)

  # With con + zone_id : insert is called and the count propagates.
  res2 <- run_fordead_dieback(aoi, verbose = FALSE,
                              con = "fake-con", zone_id = 42)
  expect_equal(res2$n_alerts_inserted, 2L)
  expect_equal(insert_called, 1L)
})


test_that(".empty_fordead_result has the documented shape", {
  out <- nemeton:::.empty_fordead_result(
    output_dir = "/tmp/x", python_env = "env", status = "error",
    message = "boom"
  )
  expect_equal(out$status, "error")
  expect_equal(out$message, "boom")
  expect_equal(out$n_alerts_inserted, 0L)
  expect_named(out$rasters, c("state", "first_dieback_date", "stress_index"))
})
