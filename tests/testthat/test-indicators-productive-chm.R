# Tests for the CHM mode of P1 (spec 005 T3.9-T3.11)
# and P2 (spec 005 T2.19-T2.21) of indicateur_p*_station.

# Small helper: build N spatial units over a CHM raster
.make_units_over_chm <- function(chm, n = 4, species = NULL, age = NULL) {
  ext   <- terra::ext(chm)
  xmin  <- ext$xmin; xmax <- ext$xmax
  ymin  <- ext$ymin; ymax <- ext$ymax
  sq    <- ceiling(sqrt(n))
  dx    <- (xmax - xmin) / sq
  dy    <- (ymax - ymin) / sq

  polys <- list()
  for (i in seq_len(sq)) {
    for (j in seq_len(sq)) {
      if (length(polys) >= n) break
      x0 <- xmin + (i - 1) * dx + dx * 0.1
      x1 <- xmin + i * dx       - dx * 0.1
      y0 <- ymin + (j - 1) * dy + dy * 0.1
      y1 <- ymin + j * dy       - dy * 0.1
      polys[[length(polys) + 1]] <- sf::st_polygon(list(rbind(
        c(x0, y0), c(x1, y0), c(x1, y1), c(x0, y1), c(x0, y0)
      )))
    }
  }

  if (is.null(species)) species <- rep("QUPE", n)
  if (is.null(age))     age     <- rep(80L, n)

  sf::st_sf(
    species   = species,
    age       = age,
    fertility = rep(2, n),
    climate   = rep("temperate_oceanic", n),
    geometry  = sf::st_sfc(polys, crs = terra::crs(chm))
  )
}

# ---- CHM mode -----------------------------------------------------

test_that("indicateur_p2_station in CHM mode returns a site index in metres", {
  skip_if_not_installed("terra")
  chm   <- make_fixture_chm(add_artefacts = FALSE)
  units <- .make_units_over_chm(chm, n = 4,
                                species = c("QUPE", "QUPE", "PIAB", "PIAB"),
                                age     = c(80, 80, 40, 40))
  res <- indicateur_p2_station(units, chm = chm)

  expect_s3_class(res, "sf")
  expect_true("P2" %in% names(res))
  expect_true(all(res$P2 > 0))
  expect_true(all(res$P2 < 50))
})

test_that("CHM mode requires species_field and age_field", {
  skip_if_not_installed("terra")
  chm <- make_fixture_chm(add_artefacts = FALSE)
  units <- .make_units_over_chm(chm, n = 2)
  units$species <- NULL
  expect_error(
    indicateur_p2_station(units, chm = chm),
    regexp = "Missing required fields for CHM mode"
  )
})

test_that("CHM mode propagates NA when age or species is missing", {
  skip_if_not_installed("terra")
  chm   <- make_fixture_chm(add_artefacts = FALSE)
  units <- .make_units_over_chm(chm, n = 2,
                                species = c("QUPE", NA),
                                age     = c(80, 80))
  res <- indicateur_p2_station(units, chm = chm)
  expect_false(is.na(res$P2[1]))
  expect_true(is.na(res$P2[2]))
})

test_that("CHM mode respects reference_age", {
  skip_if_not_installed("terra")
  chm   <- make_fixture_chm(add_artefacts = FALSE)
  units <- .make_units_over_chm(chm, n = 2,
                                species = c("QUPE", "QUPE"),
                                age     = c(80, 80))
  at_50  <- indicateur_p2_station(units, chm = chm, reference_age = 50)$P2
  at_100 <- indicateur_p2_station(units, chm = chm, reference_age = 100)$P2
  # At reference age 100 the site index must be larger than at 50
  # (stands keep growing after 50 years).
  expect_true(all(at_100 >= at_50))
})

test_that("CHM mode with a uniformly tall CHM yields a top-class site index", {
  skip_if_not_installed("terra")
  # All pixels at 30 m -> QUPE at age 80 is near class 1
  r <- terra::rast(nrows = 60, ncols = 60,
                   xmin = 0, xmax = 300, ymin = 0, ymax = 300,
                   crs = "EPSG:2154",
                   vals = rep(30, 3600))
  units <- .make_units_over_chm(r, n = 2, species = c("QUPE", "QUPE"),
                                age = c(80, 80))
  res <- indicateur_p2_station(units, chm = r, reference_age = 50)$P2
  # QUPE class_1 @ 50 is ~ 20.7m ; with H_dom ~ 30 at 80 -> near class 1
  expect_true(all(res > 18))
})

# ---- Legacy mode regression ---------------------------------------

test_that("legacy mode is unchanged when chm is NULL", {
  skip_if_not_installed("terra")
  sp  <- c("FASY", "FASY", "PIAB", "PIAB")
  fe  <- c(1, 2, 1, 2)
  cl  <- c("temperate_oceanic", "temperate_oceanic",
           "mountainous",       "mountainous")
  # Minimal polygons
  polys <- lapply(seq_along(sp), function(i) {
    ox <- (i - 1) * 20
    sf::st_polygon(list(rbind(
      c(ox, 0), c(ox + 10, 0), c(ox + 10, 10), c(ox, 10), c(ox, 0)
    )))
  })
  units <- sf::st_sf(
    species = sp, fertility = fe, climate = cl,
    geometry = sf::st_sfc(polys, crs = 2154)
  )
  res <- indicateur_p2_station(units)
  expect_s3_class(res, "sf")
  expect_true("P2" %in% names(res))
  expect_true(all(res$P2 > 0))
  expect_true(all(res$P2 < 20))  # legacy m3/ha/yr range
})

# ---- Rank correlation CHM vs legacy (T2.21) -----------------------

test_that("CHM and legacy modes give positively correlated rankings", {
  skip_if_not_installed("terra")
  # Build a small dataset with clearly differentiated stands and
  # check that the two modes agree on at least the ordering of
  # productivity (Spearman rho > 0).
  set.seed(7)
  sp <- c("QUPE", "QUPE", "FASY", "FASY", "PIAB", "PIAB",
          "PIAB", "PSME", "PSME", "PISY")
  fe <- c(3, 2, 2, 1, 2, 1, 3, 1, 2, 3)
  cl <- rep("temperate_oceanic", 10)
  ag <- c(80, 80, 80, 80, 50, 50, 50, 40, 40, 60)

  # CHM heights crafted to correlate with the legacy fertility
  h_vals <- c(14, 20, 22, 28, 20, 26, 14, 35, 28, 12)

  ext_size <- 300
  cell_size <- 10
  rlist <- lapply(seq_along(sp), function(i) {
    r <- terra::rast(nrows = 10, ncols = 10,
                     xmin = (i - 1) * ext_size, xmax = i * ext_size,
                     ymin = 0, ymax = ext_size,
                     crs = "EPSG:2154",
                     vals = rep(h_vals[i], 100))
    r
  })
  chm <- do.call(terra::merge, rlist)

  polys <- lapply(seq_along(sp), function(i) {
    ox <- (i - 1) * ext_size + 50
    sf::st_polygon(list(rbind(
      c(ox, 50), c(ox + 200, 50),
      c(ox + 200, 250), c(ox, 250), c(ox, 50)
    )))
  })
  units <- sf::st_sf(
    species = sp, age = ag, fertility = fe, climate = cl,
    geometry = sf::st_sfc(polys, crs = 2154)
  )

  res_legacy <- indicateur_p2_station(units)$P2
  res_chm    <- indicateur_p2_station(units, chm = chm)$P2

  # Keep only units where both modes returned a value
  ok <- !is.na(res_legacy) & !is.na(res_chm)
  expect_true(sum(ok) >= 6)

  rho <- suppressWarnings(
    stats::cor(res_legacy[ok], res_chm[ok], method = "spearman")
  )
  expect_true(rho > 0)
})


# ===================================================================
# P1 volume — CHM mode (spec 005 T3.9-T3.11)
# ===================================================================

# Helper: units over a CHM with dbh/density ready for P1
.make_p1_units <- function(chm, species, dbh, density, height = NA) {
  n     <- length(species)
  ext   <- terra::ext(chm)
  xmin  <- ext$xmin; xmax <- ext$xmax
  ymin  <- ext$ymin; ymax <- ext$ymax
  sq    <- ceiling(sqrt(n))
  dx    <- (xmax - xmin) / sq
  dy    <- (ymax - ymin) / sq

  polys <- list()
  for (i in seq_len(sq)) {
    for (j in seq_len(sq)) {
      if (length(polys) >= n) break
      x0 <- xmin + (i - 1) * dx + dx * 0.1
      x1 <- xmin + i * dx       - dx * 0.1
      y0 <- ymin + (j - 1) * dy + dy * 0.1
      y1 <- ymin + j * dy       - dy * 0.1
      polys[[length(polys) + 1]] <- sf::st_polygon(list(rbind(
        c(x0, y0), c(x1, y0), c(x1, y1), c(x0, y1), c(x0, y0)
      )))
    }
  }

  sf::st_sf(
    species  = species,
    dbh      = dbh,
    density  = density,
    height   = height,
    geometry = sf::st_sfc(polys, crs = terra::crs(chm))
  )
}

test_that("P1 CHM mode returns positive volumes for 3 species", {
  skip_if_not_installed("terra")
  # Uniform 25 m CHM, 3 species (oak, beech, spruce)
  chm <- terra::rast(nrows = 30, ncols = 30,
                     xmin = 0, xmax = 300, ymin = 0, ymax = 300,
                     crs = "EPSG:2154",
                     vals = rep(25, 900))
  units <- .make_p1_units(
    chm,
    species = c("QUPE", "FASY", "PIAB"),
    dbh     = c(40, 35, 30),
    density = c(150, 180, 250)
  )
  res <- indicateur_p1_volume(units, chm = chm)
  expect_true(all(!is.na(res$P1)))
  expect_true(all(res$P1 > 0))
})

test_that("P1 CHM mode uses H_dom from the CHM instead of height_field", {
  skip_if_not_installed("terra")
  # CHM at 30 m vs stored height_field at 15 m -> P1 must use 30 m
  chm_30 <- terra::rast(nrows = 20, ncols = 20,
                        xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                        crs = "EPSG:2154",
                        vals = rep(30, 400))
  units <- .make_p1_units(
    chm_30,
    species = c("QUPE", "QUPE"),
    dbh     = c(35, 35),
    density = c(200, 200),
    height  = c(15, 15)
  )
  res_chm    <- indicateur_p1_volume(units, chm = chm_30)
  res_legacy <- indicateur_p1_volume(units)

  # CHM provides taller trees than the stored height -> volume up
  expect_true(all(res_chm$P1 > res_legacy$P1))
})

test_that("P1 without CHM reproduces legacy behaviour (regression)", {
  skip_if_not_installed("terra")
  # Identical runs of indicateur_p1_volume without chm should be
  # stable across calls — we cannot compare against a fossilised
  # value without a snapshot, so check determinism and legacy
  # unit range.
  polys <- list(
    sf::st_polygon(list(rbind(c(0,0), c(10,0), c(10,10), c(0,10), c(0,0)))),
    sf::st_polygon(list(rbind(c(20,0), c(30,0), c(30,10), c(20,10), c(20,0))))
  )
  units <- sf::st_sf(
    species = c("FASY", "PIAB"),
    dbh     = c(30, 25),
    height  = c(22, 18),
    density = c(200, 280),
    geometry = sf::st_sfc(polys, crs = 2154)
  )
  a <- indicateur_p1_volume(units)$P1
  b <- indicateur_p1_volume(units)$P1
  expect_identical(a, b)
  expect_true(all(a > 50))        # reasonable for mature stands
  expect_true(all(a < 10000))     # sanity upper bound
})

test_that("P1 CHM mode warns when pct_masked > 0.3", {
  skip_if_not_installed("terra")
  chm <- terra::rast(nrows = 20, ncols = 20,
                     xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                     crs = "EPSG:2154",
                     vals = rep(25, 400))
  units <- .make_p1_units(
    chm,
    species = "QUPE",
    dbh     = 35,
    density = 200
  )
  expect_warning(
    indicateur_p1_volume(units, chm = chm, pct_masked = 0.45),
    regexp = "heavily masked"
  )
  # No warning for pct_masked below threshold
  expect_no_warning(
    indicateur_p1_volume(units, chm = chm, pct_masked = 0.2)
  )
})

test_that("P1 CHM mode propagates NA for units with missing DBH", {
  skip_if_not_installed("terra")
  chm <- terra::rast(nrows = 20, ncols = 20,
                     xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                     crs = "EPSG:2154",
                     vals = rep(25, 400))
  units <- .make_p1_units(
    chm,
    species = c("QUPE", "PIAB"),
    dbh     = c(35, NA),
    density = c(200, 200)
  )
  res <- indicateur_p1_volume(units, chm = chm)$P1
  expect_false(is.na(res[1]))
  expect_true(is.na(res[2]))
})

test_that("P1 CHM mode correlates with legacy mode on varied stands", {
  skip_if_not_installed("terra")
  # Vary DBH and CHM heights to get a spread, then check Spearman
  # rank correlation between CHM-P1 and legacy-P1.
  set.seed(11)
  n  <- 8
  dbh_vals    <- c(20, 30, 25, 40, 50, 35, 45, 55)
  h_vals      <- c(15, 22, 18, 28, 32, 26, 30, 34)
  sp          <- c("QUPE", "FASY", "QUPE", "FASY",
                   "PIAB", "PIAB", "PSME", "PSME")

  # Build a mosaic CHM: tile i has a uniform height h_vals[i]
  rlist <- lapply(seq_along(sp), function(i) {
    terra::rast(nrows = 10, ncols = 10,
                xmin = (i - 1) * 100, xmax = i * 100,
                ymin = 0, ymax = 100,
                crs = "EPSG:2154",
                vals = rep(h_vals[i], 100))
  })
  chm <- do.call(terra::merge, rlist)

  polys <- lapply(seq_along(sp), function(i) {
    ox <- (i - 1) * 100 + 10
    sf::st_polygon(list(rbind(
      c(ox, 10), c(ox + 80, 10),
      c(ox + 80, 90), c(ox, 90), c(ox, 10)
    )))
  })
  units <- sf::st_sf(
    species  = sp,
    dbh      = dbh_vals,
    height   = h_vals - 3,  # legacy height a bit underestimated
    density  = rep(200, n),
    geometry = sf::st_sfc(polys, crs = 2154)
  )

  p1_legacy <- indicateur_p1_volume(units)$P1
  p1_chm    <- indicateur_p1_volume(units, chm = chm)$P1

  rho <- suppressWarnings(
    stats::cor(p1_legacy, p1_chm, method = "spearman")
  )
  expect_true(rho > 0.7)
})
