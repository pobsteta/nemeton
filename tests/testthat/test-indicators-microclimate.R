# test-indicators-microclimate.R — A3/A4/W4 microclimate indicators (spec 027 L1)
#   * normalisation sense (a3/w4 decreasing, a4 increasing) + 0-100 bounds
#   * raw + score + couverture_pct columns ; augmented flag
#   * micro = NULL / missing layer -> NA, neutral coverage
#   * partial coverage (NA pixels) -> couverture_pct < 100

skip_if_no_terra <- function() testthat::skip_if_not_installed("terra")

mk_r <- function(val, nrow = 10, ncol = 10) {
  r <- terra::rast(nrow = nrow, ncol = ncol, xmin = 0, xmax = 100,
                   ymin = 0, ymax = 100, crs = "EPSG:2154")
  terra::values(r) <- val
  r
}

mk_ugf <- function() {
  poly <- sf::st_polygon(list(rbind(c(10, 10), c(90, 10), c(90, 90),
                                    c(10, 90), c(10, 10))))
  sf::st_sf(ug_id = "u1", geometry = sf::st_sfc(poly, crs = 2154))
}

test_that("A3 maps under-canopy T°max decreasingly (cooler = higher)", {
  skip_if_no_terra()
  u <- mk_ugf()
  out <- indicateur_a3_microclimat(u, micro = list(tmax_understorey = mk_r(25)))
  expect_equal(out$A3_tmax, 25, tolerance = 1e-6)
  expect_equal(out$A3, 60, tolerance = 1e-6)             # 100*(1-(25-15)/25)
  expect_equal(out$A3_couverture_pct, 100, tolerance = 1e-6)
  expect_true("microclimate_model" %in% attr(out, "augmented"))
  # hotter -> lower score
  hot <- indicateur_a3_microclimat(u, micro = list(tmax_understorey = mk_r(35)))
  expect_lt(hot$A3, out$A3)
})

test_that("A3 clamps outside the [lo, hi] bounds", {
  skip_if_no_terra()
  u <- mk_ugf()
  expect_equal(indicateur_a3_microclimat(u, list(tmax_understorey = mk_r(45)))$A3, 0)
  expect_equal(indicateur_a3_microclimat(u, list(tmax_understorey = mk_r(10)))$A3, 100)
})

test_that("A4 buffering increases with the open/understorey gap", {
  skip_if_no_terra()
  u <- mk_ugf()
  out <- indicateur_a4_tamponnement(
    u, micro = list(tmax_open = mk_r(30), tmax_understorey = mk_r(24)))
  expect_equal(out$A4_buffer, 6, tolerance = 1e-6)
  expect_equal(out$A4, 60, tolerance = 1e-6)             # 100*(6/10)
})

test_that("W4 maps VPD decreasingly (moister = higher)", {
  skip_if_no_terra()
  u <- mk_ugf()
  out <- indicateur_w4_vpd(u, micro = list(vpd = mk_r(2)))
  expect_equal(out$W4_vpd, 2, tolerance = 1e-6)
  expect_equal(out$W4, 100 * (1 - (2 - 0.5) / 3.5), tolerance = 1e-6)
})

test_that("missing micro / layer yields NA score and zero coverage", {
  skip_if_no_terra()
  u <- mk_ugf()
  a3 <- indicateur_a3_microclimat(u, micro = NULL)
  expect_true(is.na(a3$A3))
  expect_equal(a3$A3_couverture_pct, 0)
  # A4 needs both layers — only one present -> NA
  a4 <- indicateur_a4_tamponnement(u, micro = list(tmax_understorey = mk_r(24)))
  expect_true(is.na(a4$A4))
})

test_that("partial raster coverage lowers couverture_pct", {
  skip_if_no_terra()
  testthat::skip_if_not_installed("exactextractr")
  u <- mk_ugf()
  r <- mk_r(25)
  # blank out the right half of the raster (x > 50) -> ~half the UGF NA
  r[, 6:10] <- NA
  out <- indicateur_a3_microclimat(u, micro = list(tmax_understorey = r))
  expect_lt(out$A3_couverture_pct, 100)
  expect_gt(out$A3_couverture_pct, 0)
})


# --- R6 sensitivity (heatwave vs average year) -----------------------------

test_that("R6 combines ΔT°max and ΔVPD, decreasing (less sensitive = higher)", {
  skip_if_no_terra()
  u <- mk_ugf()
  moy <- list(tmax_understorey = mk_r(25), vpd = mk_r(1.5))
  can <- list(tmax_understorey = mk_r(31), vpd = mk_r(2.5))   # ΔT=6, ΔVPD=1
  out <- indicateur_r6_sensibilite(u, micro_moyenne = moy, micro_canicule = can)
  expect_equal(out$R6_dtmax, 6, tolerance = 1e-6)
  expect_equal(out$R6_dvpd, 1, tolerance = 1e-6)
  # sT=6/8=.75, sV=1/2=.5 -> sens=.625 -> R6=37.5
  expect_equal(out$R6, 37.5, tolerance = 1e-6)
  expect_true("microclimate_model" %in% attr(out, "augmented"))
  # a hotter heatwave -> more sensitive -> lower R6
  can2 <- list(tmax_understorey = mk_r(33), vpd = mk_r(3))
  out2 <- indicateur_r6_sensibilite(u, micro_moyenne = moy, micro_canicule = can2)
  expect_lt(out2$R6, out$R6)
})

test_that("R6 is NA when a year's micro layer is missing", {
  skip_if_no_terra()
  u <- mk_ugf()
  out <- indicateur_r6_sensibilite(
    u, micro_moyenne = list(tmax_understorey = mk_r(25)),  # no vpd
    micro_canicule = list(tmax_understorey = mk_r(31), vpd = mk_r(2.5)))
  expect_true(is.na(out$R6))
  expect_equal(out$R6_couverture_pct, 0)
})
