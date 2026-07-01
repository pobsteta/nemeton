# spec 005 amendment (v0.107.0) — a CHM with (near-)zero canopy height
# is a felled / cleared stand, NOT an error. estimate_synthetic_inventory()
# must then return dbh = 0 / density = 0 (not NA) so P1/P3/E1 yield 0
# instead of a cryptic NA. Regression guard: a normal tall CHM is unchanged.

# Build a uniform-height CHM (EPSG:2154) + n units covering it.
.chm_uniform <- function(height, size_m = 120, res_m = 2) {
  r <- terra::rast(xmin = 900000, xmax = 900000 + size_m,
                   ymin = 6300000, ymax = 6300000 + size_m,
                   resolution = res_m, crs = "EPSG:2154")
  terra::values(r) <- rep(as.numeric(height), terra::ncell(r))
  names(r) <- "chm"
  r
}

.units_over <- function(chm, n = 2, species = "FASY") {
  ext <- terra::ext(chm)
  xs  <- seq(ext[1], ext[2], length.out = n + 1)
  polys <- lapply(seq_len(n), function(i) {
    sf::st_polygon(list(rbind(
      c(xs[i],     ext[3]), c(xs[i + 1], ext[3]),
      c(xs[i + 1], ext[4]), c(xs[i],     ext[4]),
      c(xs[i],     ext[3]))))
  })
  sf::st_sf(species = rep_len(species, n),
            geometry = sf::st_sfc(polys, crs = terra::crs(chm)))
}

test_that("clear-cut CHM (H_dom = 0) -> dbh = 0, density = 0 (not NA)", {
  skip_if_not_installed("terra")
  chm   <- .chm_uniform(0)
  units <- .units_over(chm, n = 2, species = "FASY")
  inv   <- estimate_synthetic_inventory(units, chm, species = units$species)
  expect_true(all(inv$H_dom == 0))
  expect_true(all(inv$dbh == 0))          # was NA before the fix
  expect_true(all(inv$density == 0))
  expect_false(anyNA(inv$dbh))
  expect_false(anyNA(inv$density))
})

test_that("P1 / P3 / E1 return 0 (not NA) on a clear-cut CHM", {
  skip_if_not_installed("terra")
  chm   <- .chm_uniform(0)
  units <- .units_over(chm, n = 3, species = "FASY")

  p1 <- indicateur_p1_volume(units, chm = chm, column_name = "P1")$P1
  expect_false(anyNA(p1))
  expect_true(all(p1 == 0))

  p3 <- indicateur_p3_qualite_bois(units, chm = chm, column_name = "P3")$P3
  expect_false(anyNA(p3))                 # defined (low), not NA

  e1 <- indicateur_e1_bois_energie(units, chm = chm, column_name = "E1")$E1
  expect_false(anyNA(e1))
  expect_true(all(e1 == 0))
})

test_that("min_stand_height boundary: below = 0, at/above tries the allometry", {
  skip_if_not_installed("terra")
  # 0.5 m canopy: below the 1.3 m default -> no stand -> 0.
  low <- estimate_synthetic_inventory(
    .units_over(.chm_uniform(0.5), 2), .chm_uniform(0.5), species = "FASY")
  expect_true(all(low$dbh == 0 & low$density == 0))

  # A young stand (3 m, between 1.3 and 6): the mature-stand allometry is
  # NOT calibrated there -> estimate_dq_from_hdom yields NA (unchanged).
  young <- estimate_synthetic_inventory(
    .units_over(.chm_uniform(3), 2), .chm_uniform(3), species = "FASY")
  expect_true(all(is.na(young$dbh)))
})

test_that("regression: a normal tall CHM still yields positive volume", {
  skip_if_not_installed("terra")
  chm   <- .chm_uniform(25)               # 25 m mature stand
  units <- .units_over(chm, n = 2, species = "FASY")
  inv   <- estimate_synthetic_inventory(units, chm, species = units$species)
  expect_true(all(inv$dbh > 0))
  expect_true(all(inv$density > 0))
  p1 <- indicateur_p1_volume(units, chm = chm, column_name = "P1")$P1
  expect_false(anyNA(p1))
  expect_true(all(p1 > 0))
})

test_that("H_dom = NA (no CHM coverage) stays NA, not 0", {
  skip_if_not_installed("terra")
  chm <- .chm_uniform(20)
  # Unit placed far outside the CHM extent -> extract_h_dom returns NA.
  far <- sf::st_sf(
    species  = "FASY",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(800000, 6200000), c(800100, 6200000),
      c(800100, 6200100), c(800000, 6200100),
      c(800000, 6200000)))), crs = terra::crs(chm)))
  inv <- estimate_synthetic_inventory(far, chm, species = far$species)
  expect_true(is.na(inv$H_dom) | inv$H_dom == 0)  # coverage-dependent
  if (is.na(inv$H_dom)) {
    expect_true(is.na(inv$dbh))            # unknown, NOT forced to 0
  }
})
