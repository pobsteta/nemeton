# spec 005 §3.5 — dette H_dom faible/nul (items #1, #2, #3).
# #2 young stand -> merchantable 0 ; #1 degenerate-CHM guard ;
# #3 site index NA below breast height.

.chm_uniform <- function(height, size_m = 100, res_m = 5) {
  r <- terra::rast(xmin = 900000, xmax = 900000 + size_m,
                   ymin = 6300000, ymax = 6300000 + size_m,
                   resolution = res_m, crs = "EPSG:2154")
  terra::values(r) <- rep(as.numeric(height), terra::ncell(r))
  names(r) <- "chm"
  r
}

.units_over <- function(chm, species = "FASY", H_dom = NULL) {
  ext <- terra::ext(chm)
  poly <- sf::st_polygon(list(rbind(
    c(ext[1], ext[3]), c(ext[2], ext[3]),
    c(ext[2], ext[4]), c(ext[1], ext[4]), c(ext[1], ext[3]))))
  u <- sf::st_sf(species = species,
                 geometry = sf::st_sfc(poly, crs = terra::crs(chm)))
  if (!is.null(H_dom)) u$H_dom <- H_dom
  u
}

# ---- #2 : young / pre-merchantable stand [1.3, 6) m -> 0 ------------------

test_that("young stand (H_dom in [1.3, 6)) yields merchantable 0, not NA", {
  skip_if_not_installed("terra")
  chm   <- .chm_uniform(30)                     # tall CHM => not suspect
  units <- .units_over(chm, H_dom = 4)          # but this unit is young (4 m)

  inv <- estimate_synthetic_inventory(units, chm, species = units$species)
  expect_equal(inv$dbh, 0)
  expect_equal(inv$density, 0)
  expect_false(isTRUE(attr(inv, "chm_suspect")))  # CHM max = 30 => not suspect
})

test_that("tall stand with missing species stays NA (height test, not is.na(dq))", {
  skip_if_not_installed("terra")
  chm   <- .chm_uniform(30)
  units <- .units_over(chm, species = NA_character_, H_dom = 25)

  inv <- estimate_synthetic_inventory(units, chm, species = units$species)
  expect_true(is.na(inv$dbh))        # unknown species -> genuinely NA
  expect_false(inv$dbh %in% 0)       # NOT forced to 0
})

test_that("backward-compat: min_merchantable_height == min_stand_height keeps young as NA", {
  skip_if_not_installed("terra")
  chm   <- .chm_uniform(30)
  units <- .units_over(chm, H_dom = 4)
  inv <- estimate_synthetic_inventory(
    units, chm, species = units$species,
    min_stand_height = 1.3, min_merchantable_height = 1.3)
  expect_true(is.na(inv$dbh))        # v0.107.0 behaviour restored
})

# ---- #1 : degenerate-CHM guard -------------------------------------------

test_that("degenerate CHM (all-zero) warns and flags chm_suspect", {
  skip_if_not_installed("terra")
  chm   <- .chm_uniform(0)                       # failed / all-zero prediction
  units <- .units_over(chm)                      # H_dom extracted ~ 0

  expect_warning(
    inv <- estimate_synthetic_inventory(units, chm, species = units$species),
    "degenerate")
  expect_true(isTRUE(attr(inv, "chm_suspect")))
  expect_equal(inv$dbh, 0)                        # still treated as 0
})

test_that("normal tall CHM is not flagged suspect and emits no warning", {
  skip_if_not_installed("terra")
  chm   <- .chm_uniform(28)
  units <- .units_over(chm)
  expect_no_warning(
    inv <- estimate_synthetic_inventory(units, chm, species = units$species))
  expect_false(isTRUE(attr(inv, "chm_suspect")))
  expect_true(inv$dbh > 0)
})

test_that("ensure_inventory_fields propagates chm_suspect onto the sf", {
  skip_if_not_installed("terra")
  chm   <- .chm_uniform(0)
  units <- .units_over(chm)
  suppressWarnings(
    out <- ensure_inventory_fields(units, chm = chm))
  expect_true(isTRUE(attr(out, "chm_suspect")))
})

# ---- #3 : site index NA below breast height ------------------------------

test_that("compute_site_index returns NA below min_stand_height (bare CHM)", {
  expect_true(is.na(compute_site_index(H_dom = 0,   age = 40, species = "QUPE")))
  expect_true(is.na(compute_site_index(H_dom = 0.5, age = 40, species = "QUPE")))
})

test_that("compute_site_index stays finite for an established stand", {
  si <- compute_site_index(H_dom = 20, age = 80, species = "QUPE")
  expect_false(is.na(si))
  expect_true(si > 0)
})
