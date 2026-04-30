# Build a synthetic alert centroids sf with a controlled mix of
# confidence classes (Lambert-93). Each point is offset slightly
# so GRTS has spatial information to balance on.
make_alerts <- function(per_class = c(`1-faible` = 5L,
                                      `2-moyenne` = 10L,
                                      `3-forte`   = 30L,
                                      `4-sol-nu`  = 5L),
                        seed = 42L) {
  set.seed(seed)
  n <- sum(per_class)
  cls <- rep(names(per_class), per_class)
  cx  <- 950000 + stats::runif(n, 0, 5000)
  cy  <- 6790000 + stats::runif(n, 0, 5000)
  geom <- lapply(seq_len(n), function(i) {
    sf::st_point(c(cx[i], cy[i]))
  })
  sf::st_sf(
    id               = seq_len(n),
    confidence_class = cls,
    stress_index     = stats::runif(n, 0, 2),
    trigger_date     = as.Date("2024-06-15") + sample.int(60L, n, replace = TRUE),
    geometry         = sf::st_sfc(geom, crs = 2154)
  )
}


test_that(".allocate_health_strata gives every present class >= 1 plot", {
  counts <- c(`1-faible` = 5L, `2-moyenne` = 10L,
              `3-forte`  = 30L, `4-sol-nu`  = 5L)
  alloc <- nemeton:::.allocate_health_strata(counts, 30L)
  expect_equal(sum(alloc), 30L)
  expect_true(all(alloc >= 1L))
  # The largest stratum (3-forte) must get at least proportionally more
  # than 1-faible.
  expect_gt(alloc[["3-forte"]], alloc[["1-faible"]])
})

test_that(".allocate_health_strata respects per-class capacity", {
  counts <- c(A = 2L, B = 100L)
  alloc <- nemeton:::.allocate_health_strata(counts, 50L)
  expect_lte(alloc[["A"]], counts[["A"]])
  expect_equal(sum(alloc), 50L)
})

test_that(".allocate_health_strata handles n_total < k strata gracefully", {
  counts <- c(A = 5L, B = 10L, C = 3L, D = 7L)
  alloc <- nemeton:::.allocate_health_strata(counts, 2L)
  expect_equal(sum(alloc), 2L)
  expect_true(all(alloc <= 1L))
})

test_that("generate_health_validation_plots draws exactly n plots", {
  alerts <- make_alerts()
  out <- generate_health_validation_plots(alerts, n = 20L,
                                          method = "random")
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 20L)
  # Result keeps schema-required columns
  expect_true(all(c("plot_id", "alert_id", "confidence_class",
                    "stress_index", "trigger_date",
                    "stade_deperissement") %in% names(out)))
  expect_true(all(grepl("^HV-\\d{4}$", out$plot_id)))
})

test_that("the result is reprojected to the requested CRS", {
  alerts <- make_alerts()
  out_2154 <- generate_health_validation_plots(alerts, n = 5L,
                                               method = "random")
  expect_equal(sf::st_crs(out_2154)$epsg, 2154L)
  out_4326 <- generate_health_validation_plots(alerts, n = 5L,
                                               method = "random",
                                               crs = 4326)
  expect_equal(sf::st_crs(out_4326)$epsg, 4326L)
})

test_that("every confidence class present in the input is sampled", {
  alerts <- make_alerts()
  out <- generate_health_validation_plots(alerts, n = 10L,
                                          method = "random")
  expect_setequal(unique(out$confidence_class),
                  unique(alerts$confidence_class))
})

test_that("editable schema columns are pre-allocated as typed NAs", {
  alerts <- make_alerts()
  out <- generate_health_validation_plots(alerts, n = 5L,
                                          method = "random")
  expect_true(all(is.na(out$stade_deperissement)))
  expect_type(out$stade_deperissement, "character")
  expect_true(all(is.na(out$taux_couvert)))
  expect_type(out$taux_couvert, "double")
  expect_s3_class(out$obs_date, "POSIXct")
})

test_that("sampling_method tag reflects the actual draw mode", {
  alerts <- make_alerts()
  out <- generate_health_validation_plots(alerts, n = 5L,
                                          method = "random")
  expect_true(all(out$sampling_method == "random"))

  # GRTS path silently degrades to random when spsurvey is missing —
  # sampling_method should follow the actual outcome, not the request.
  testthat::local_mocked_bindings(
    requireNamespace = function(pkg, ...) {
      if (identical(pkg, "spsurvey")) FALSE else base::requireNamespace(pkg, ...)
    },
    .package = "base"
  )
  out2 <- generate_health_validation_plots(alerts, n = 5L,
                                           method = "grts")
  expect_true(all(out2$sampling_method == "random"))
})

test_that("empty alerts_sf returns an empty sf with a warning", {
  alerts <- make_alerts()[0L, ]
  expect_warning(
    out <- generate_health_validation_plots(alerts, n = 10L,
                                            method = "random"),
    "Empty"
  )
  expect_equal(nrow(out), 0L)
})

test_that("missing confidence_class column is rejected", {
  alerts <- make_alerts()
  alerts$confidence_class <- NULL
  expect_error(
    generate_health_validation_plots(alerts, n = 5L),
    "missing required column"
  )
})

test_that("bad inputs raise typed errors", {
  expect_error(generate_health_validation_plots("nope", n = 5L),
               "must be an sf")
  alerts <- make_alerts()
  expect_error(generate_health_validation_plots(alerts, n = 0L),
               "positive integer")
  expect_error(generate_health_validation_plots(alerts, n = -3L),
               "positive integer")
})
