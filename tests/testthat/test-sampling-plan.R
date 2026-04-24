# test-sampling-plan.R
# Tests for R/sampling_plan.R — create_sampling_plan() and internals.

# ------------------------------------------------------------
# Fixtures
# ------------------------------------------------------------

make_zone <- function() {
  sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(900000, 6500000), c(901000, 6500000),
    c(901000, 6501000), c(900000, 6501000),
    c(900000, 6500000)
  ))), crs = 2154))
}

make_chm <- function() {
  skip_if_not_installed("terra")
  r <- terra::rast(xmin = 899900, xmax = 901100,
                   ymin = 6499900, ymax = 6501100,
                   resolution = 10, crs = "EPSG:2154")
  terra::values(r) <- rep(seq(5, 30, length.out = ncol(r)),
                          each = nrow(r))
  r
}


# ------------------------------------------------------------
# Fallback path: no auxiliary data → spatial draw only
# ------------------------------------------------------------

test_that("create_sampling_plan falls back to a spatial draw without aux inputs", {
  skip_if_not_installed("sf")
  zone <- make_zone()
  res <- create_sampling_plan(zone, n_base = 10, n_over = 3, seed = 1)

  expect_s3_class(res, "sf")
  expect_equal(nrow(res), 13)
  expect_setequal(unique(res$type), c("Base", "Over"))
  expect_equal(sum(res$type == "Base"), 10)
  expect_equal(sum(res$type == "Over"), 3)
  expect_equal(as.integer(sf::st_crs(res)$epsg), 2154L)
  expect_true(all(c("plot_id", "type", "visit_order", "stratum") %in% names(res)))
  expect_true(attr(res, "method") %in% c("lpm2", "random"))
})


test_that("create_sampling_plan preserves zone CRS other than 2154", {
  skip_if_not_installed("sf")
  # Small zone in WGS84 UTM 30N (EPSG:32630) around central France
  zone <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(500000, 5200000), c(501000, 5200000),
    c(501000, 5201000), c(500000, 5201000),
    c(500000, 5200000)
  ))), crs = 32630))
  res <- create_sampling_plan(zone, n_base = 5, seed = 3)
  expect_equal(as.integer(sf::st_crs(res)$epsg), 32630L)
})


# ------------------------------------------------------------
# Stratification path: CHM drives height quartiles
# ------------------------------------------------------------

test_that("create_sampling_plan stratifies on CHM and uses GRTS when available", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  skip_if_not_installed("spsurvey")

  zone <- make_zone()
  chm  <- make_chm()
  res  <- create_sampling_plan(zone, n_base = 16, n_over = 4,
                               chm = chm, seed = 42)

  expect_s3_class(res, "sf")
  expect_equal(attr(res, "method"), "grts")
  # Four height strata should exist in the draw
  expect_true(length(unique(res$strat_height)) >= 3)
  expect_true(all(res$strat_height %in% c("H1", "H2", "H3", "H4")))
})


test_that("create_sampling_plan degrades gracefully when GRTS fails", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  zone <- make_zone()
  chm  <- make_chm()

  # Force the GRTS branch to bail out by mocking the internal draw helper.
  local_mocked_bindings(
    .draw_grts = function(frame, allocation, n_over_per_stratum) NULL
  )
  res <- create_sampling_plan(zone, n_base = 10, n_over = 2,
                              chm = chm, seed = 7)
  expect_true(attr(res, "method") %in% c("lpm2", "random"))
  expect_equal(nrow(res), 12)
})


# ------------------------------------------------------------
# Constraint path: slope filter removes candidates
# ------------------------------------------------------------

test_that("max_slope constraint reduces the candidate frame", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")

  zone <- make_zone()
  # Slope gradient: steep on the west (x < 900500), gentle on the east.
  # Using init(fun="x") avoids row/col-ordering pitfalls in values<-.
  slope <- terra::rast(xmin = 899900, xmax = 901100,
                       ymin = 6499900, ymax = 6501100,
                       resolution = 10, crs = "EPSG:2154")
  xs <- terra::init(slope, fun = "x")
  slope[] <- ifelse(terra::values(xs) < 900500, 45, 5)

  res <- create_sampling_plan(zone, n_base = 30, n_over = 0,
                              slope = slope, max_slope = 30,
                              seed = 11)
  # Only the east half (x > 900500) should pass the max_slope filter.
  xs_pts <- sf::st_coordinates(res)[, "X"]
  expect_true(mean(xs_pts > 900500) >= 0.8)
})


# ------------------------------------------------------------
# Error surfaces
# ------------------------------------------------------------

test_that("create_sampling_plan rejects non-sf zones and non-positive n_base", {
  expect_error(
    create_sampling_plan(data.frame(x = 1), n_base = 5),
    "must be an sf"
  )
  expect_error(
    create_sampling_plan(make_zone(), n_base = 0),
    "n_base"
  )
})


# ------------------------------------------------------------
# target_error / cv path
# ------------------------------------------------------------

test_that("create_sampling_plan sizes n_base from (target_error, cv)", {
  plan <- create_sampling_plan(
    make_zone(),
    target_error = 0.10,
    cv = 0.30,
    n_over = 0L  # let over_ratio kick in
  )
  ss <- attr(plan, "sample_size")
  expect_false(is.null(ss))
  # Computed n should roughly match normal-approx (1.96 * 0.3 / 0.1)^2 ~= 35.
  expect_gte(ss$n, 34L)
  expect_lte(ss$n, 40L)
  # n_base in the plan should be >= computed n (may be slightly less if
  # some candidates were filtered out by constraints).
  n_base_in_plan <- sum(plan$type == "Base")
  expect_true(n_base_in_plan > 0)
  # Over plots ~ 20 % of n_base.
  n_over_in_plan <- sum(plan$type == "Over")
  expect_true(n_over_in_plan >= 1L)
})


test_that("create_sampling_plan errors when target_error is set without cv", {
  expect_error(
    create_sampling_plan(make_zone(), target_error = 0.10),
    "cv.*must be provided"
  )
})


test_that("Base plots are reordered into a sensible walking tour", {
  # Draw on a wide rectangle so the TSP has something to untangle.
  set.seed(1)
  zone <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(0, 0), c(4000, 0), c(4000, 1000),
      c(0, 1000), c(0, 0)
    ))),
    crs = 2154
  ))
  plan <- create_sampling_plan(zone, n_base = 30, n_over = 0, seed = 1)
  base <- plan[plan$type == "Base", ]
  base <- base[order(base$visit_order), ]
  coords <- sf::st_coordinates(base)

  # Length of the obtained tour.
  seg <- sqrt(diff(coords[, 1])^2 + diff(coords[, 2])^2)
  tour_len <- sum(seg)

  # Compare with the original draw order (which is random / not
  # optimised). The TSP tour should be materially shorter.
  ord_random <- sample(nrow(base))
  coords_rand <- coords[ord_random, ]
  seg_rand <- sqrt(diff(coords_rand[, 1])^2 + diff(coords_rand[, 2])^2)
  rand_len <- sum(seg_rand)

  expect_lt(tour_len, rand_len * 0.6)
  # First plot (visit_order == 1) should be near the SE corner.
  first <- sf::st_coordinates(base[1, ])
  expect_true(first[1] > 2500)  # east half
})


test_that("TSP helper returns a permutation of 1:n and starts at SE", {
  set.seed(2)
  coords <- cbind(runif(10, 0, 1000), runif(10, 0, 1000))
  tour <- nemeton:::.tsp_tour(coords)
  expect_equal(sort(tour), 1:10)
  # Start = SE-most point (max x - y).
  expect_equal(tour[1], which.max(coords[, 1] - coords[, 2]))
})


test_that("TSP fallback is reachable and also correct", {
  set.seed(3)
  coords <- cbind(runif(8, 0, 1000), runif(8, 0, 1000))
  start <- which.max(coords[, 1] - coords[, 2])
  tour <- nemeton:::.tsp_fallback(coords, start)
  expect_equal(sort(tour), 1:8)
  expect_equal(tour[1], start)
})


test_that("create_sampling_plan errors when neither n_base nor target_error is given", {
  expect_error(
    create_sampling_plan(make_zone()),
    "Either.*n_base.*target_error"
  )
})


# ------------------------------------------------------------
# Internal: allocation respects min_per_stratum and caps
# ------------------------------------------------------------

test_that(".allocate_per_stratum honors min_per_stratum and caps at counts", {
  counts <- c(A = 50, B = 50, C = 1)
  alloc  <- nemeton:::.allocate_per_stratum(counts, n_main = 20,
                                            min_per_stratum = 2)
  expect_equal(sum(alloc), 20)
  expect_true(alloc[["C"]] <= 1)      # cannot exceed stratum size
  expect_true(alloc[["A"]] >= 2)
  expect_true(alloc[["B"]] >= 2)
})


# ------------------------------------------------------------
# Internal: .fit_stratum degrades 3D → 2D → 1D when strata are too thin
# ------------------------------------------------------------

test_that(".fit_stratum drops topo first when 3D combo is too thin", {
  # 3D stratum: 2 height × 2 type × 2 topo = up to 8 bins. We design the
  # data so the 3D combo has at least one singleton stratum (too thin),
  # but the 2D combo (height × type) has enough candidates everywhere.
  set.seed(1)
  n <- 40
  frame <- data.frame(
    strat_height = rep(c("H1", "H2"), each = n / 2),
    strat_type   = rep(c("FEU", "CON"), times = n / 2),
    strat_topo   = c(rep("BAS", n - 1), "HAU")   # one singleton in topo
  )
  fit <- nemeton:::.fit_stratum(frame, c("height", "type", "topo"),
                                n_base = 10, n_over = 4, min_per_stratum = 2)
  expect_false(is.null(fit))
  expect_setequal(fit$dims, c("height", "type"))
  expect_true(all(fit$allocation + fit$n_over_per_stratum <=
                    as.integer(fit$counts[names(fit$allocation)])))
})


test_that(".fit_stratum degrades to 1D (height) when 2D still too thin", {
  # Design: a rare type combination that makes every 2D (h × type) bucket
  # thin, but the 1D height stratification is fine.
  frame <- data.frame(
    strat_height = rep(c("H1", "H2"), each = 20),
    strat_type   = c(rep("FEU", 19), "CON", rep("CON", 19), "FEU"),
    strat_topo   = rep("BAS", 40)
  )
  fit <- nemeton:::.fit_stratum(frame, c("height", "type", "topo"),
                                n_base = 20, n_over = 6, min_per_stratum = 2)
  expect_false(is.null(fit))
  expect_identical(fit$dims, "height")
  expect_equal(length(fit$counts), 2L)
})


test_that(".fit_stratum returns NULL when even 1D is too thin", {
  # Only 2 candidates in one stratum, but the allocation + over is 3+.
  frame <- data.frame(
    strat_height = c(rep("H1", 30), "H2", "H2"),
    strat_type   = rep("AUT", 32),
    strat_topo   = rep("NA", 32)
  )
  fit <- nemeton:::.fit_stratum(frame, c("height"),
                                n_base = 20, n_over = 10, min_per_stratum = 2)
  # H2 has only 2 candidates; allocation is >= 2 (min) + at least 1 over.
  expect_null(fit)
})


test_that("create_sampling_plan clamps n_base + n_over to frame capacity", {
  skip_if_not_installed("sf")
  zone <- make_zone()
  # grid_step = 250 m on a 1 km × 1 km zone → 4×4 = 16 candidates only.
  # Ask for 30 Base + 10 Over = 40 (far more than the frame holds).
  suppressWarnings(
    res <- create_sampling_plan(zone, n_base = 30, n_over = 10,
                                grid_step = 250, seed = 1)
  )
  # The draw should not exceed the frame capacity.
  expect_lte(nrow(res), 16)
  # The Base/Over ratio should be roughly preserved (30/40 = 0.75).
  n_b <- sum(res$type == "Base")
  n_o <- sum(res$type == "Over")
  expect_true(n_b >= 1L)
  # Never silently lose *all* Over plots.
  expect_true(n_o >= 1L)
  # Ratio within ~±1 unit of 0.75.
  expect_true(abs(n_b / (n_b + n_o) - 0.75) <= 0.1)
})


test_that("create_sampling_plan warns when the frame is too small", {
  skip_if_not_installed("sf")
  zone <- make_zone()
  expect_warning(
    create_sampling_plan(zone, n_base = 30, n_over = 10,
                         grid_step = 250, seed = 1),
    regexp = "Candidate frame has .* points but n_base=30"
  )
})


test_that(".fit_stratum skips combos that degenerate to a single stratum", {
  frame <- data.frame(
    strat_height = rep("H1", 20),      # constant
    strat_type   = rep(c("FEU", "CON"), each = 10),
    strat_topo   = rep(c("BAS", "HAU"), times = 10)
  )
  fit <- nemeton:::.fit_stratum(frame, c("height", "type", "topo"),
                                n_base = 10, n_over = 4, min_per_stratum = 2)
  # 3D, 2D (h × type) and 1D (height) all contain a constant "height"
  # component, but the combo stays multi-stratum thanks to type/topo.
  expect_false(is.null(fit))
  expect_true(length(fit$counts) > 1L)
})
