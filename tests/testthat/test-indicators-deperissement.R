# Helpers ------------------------------------------------------------

# Build a sf with `n` square forest units of `size_m` metres on a
# regular grid in Lambert-93. `species` is recycled across the
# units (default = all spruce).
make_units <- function(n = 4L, size_m = 1000,
                       species = "EPC",
                       origin = c(950000, 6790000)) {
  cols <- ceiling(sqrt(n))
  geom <- vector("list", n)
  for (i in seq_len(n)) {
    cx <- origin[1] + ((i - 1L) %% cols) * size_m * 1.2
    cy <- origin[2] + ((i - 1L) %/% cols) * size_m * 1.2
    geom[[i]] <- sf::st_polygon(list(rbind(
      c(cx,            cy),
      c(cx + size_m,   cy),
      c(cx + size_m,   cy + size_m),
      c(cx,            cy + size_m),
      c(cx,            cy)
    )))
  }
  sf::st_sf(
    id                = seq_len(n),
    essence_dominante = rep(species, length.out = n),
    geometry          = sf::st_sfc(geom, crs = 2154)
  )
}

# Build a fordead_results-shaped list with cluster centroids placed
# on top of the units. `coverage_per_unit` is a list of (class,
# fraction) pairs per unit — a fraction `f` produces a single
# cluster of area `f * unit_area`. NULL pairs leave the unit clean.
make_fordead <- function(units, coverage_per_unit) {
  cents <- list()
  cls   <- character(0)
  areas <- numeric(0)
  for (i in seq_along(coverage_per_unit)) {
    spec <- coverage_per_unit[[i]]
    if (is.null(spec)) next
    geom <- sf::st_geometry(units)[[i]]
    centroid <- sf::st_centroid(geom)
    unit_area <- as.numeric(sf::st_area(geom))
    for (entry in spec) {
      cents[[length(cents) + 1L]] <- centroid
      cls   <- c(cls, entry$class)
      areas <- c(areas, entry$frac * unit_area)
    }
  }
  if (length(cents) == 0L) {
    return(list(alerts_sf = sf::st_sf(
      cluster_id       = integer(0),
      confidence_class = character(0),
      area_m2          = numeric(0),
      stress_index     = numeric(0),
      geometry         = sf::st_sfc(crs = 2154)
    )))
  }
  list(alerts_sf = sf::st_sf(
    cluster_id       = seq_along(cents),
    confidence_class = cls,
    area_m2          = areas,
    stress_index     = rep(1.0, length(cents)),
    geometry         = sf::st_sfc(cents, crs = 2154)
  ))
}


# Tests --------------------------------------------------------------

test_that("R5 = NA + skipped_no_fordead when no FORDEAD results given", {
  skip_if_not_installed("terra")
  u <- make_units(n = 3L)
  out <- indicateur_r5_deperissement(u)
  expect_true(all(is.na(out$R5)))
  expect_true(all(out$r5_status == "skipped_no_fordead"))
  expect_s3_class(out, "sf")
})

test_that("R5 = NA when fordead_results$alerts_sf is empty", {
  skip_if_not_installed("terra")
  u <- make_units(n = 2L)
  fr <- list(alerts_sf = make_fordead(u, list(NULL, NULL))$alerts_sf)
  out <- indicateur_r5_deperissement(u, fr)
  expect_true(all(is.na(out$R5)))
  expect_true(all(out$r5_status == "skipped_no_fordead"))
})

test_that("mono-class 50% coverage of class 3-forte gives R5 = 41 (0.82 * 0.5)", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L)
  fr <- make_fordead(u, list(list(list(class = "3-forte", frac = 0.5))))
  out <- indicateur_r5_deperissement(u, fr)
  expect_equal(out$r5_status, "calculated")
  # 0.82 * 0.5 = 0.41 -> rescaled to 41 / 100
  expect_equal(out$R5, 41, tolerance = 1e-6)
})

test_that("multi-class coverage adds up linearly (3-forte + 4-sol-nu)", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L)
  fr <- make_fordead(u, list(list(
    list(class = "3-forte", frac = 0.3),
    list(class = "4-sol-nu", frac = 0.2)
  )))
  out <- indicateur_r5_deperissement(u, fr)
  # 0.82 * 0.3 + 0.70 * 0.2 = 0.246 + 0.140 = 0.386 -> 38.6
  expect_equal(out$R5, 38.6, tolerance = 1e-6)
})

test_that("oak unit routes to RECONFORT → skipped_no_reconfort when no run", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L, species = "Quercus petraea")
  fr <- make_fordead(u, list(list(list(class = "3-forte", frac = 0.5))))
  out <- indicateur_r5_deperissement(u, fr)   # oak -> reconfort, none given
  expect_true(is.na(out$R5))
  expect_equal(out$r5_status, "skipped_no_reconfort")
})

test_that("classes 1-faible / 2-moyenne are excluded by default (G1)", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L)
  fr <- make_fordead(u, list(list(
    list(class = "1-faible", frac = 0.5),
    list(class = "2-moyenne", frac = 0.4)
  )))
  out_default <- indicateur_r5_deperissement(u, fr)
  expect_equal(out_default$R5, 0)  # all alerts dropped → no anomaly
  expect_equal(out_default$r5_status, "calculated")
})

test_that("include_low_classes = TRUE pulls in 1-faible / 2-moyenne", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L)
  fr <- make_fordead(u, list(list(
    list(class = "1-faible", frac = 0.5),
    list(class = "2-moyenne", frac = 0.4)
  )))
  out <- indicateur_r5_deperissement(u, fr, include_low_classes = TRUE)
  # 0.10 * 0.5 + 0.30 * 0.4 = 0.05 + 0.12 = 0.17 -> 17
  expect_equal(out$R5, 17, tolerance = 1e-6)
})

test_that("R5 is capped at 100", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L)
  # huge cluster that more than fills the unit
  fr <- make_fordead(u, list(list(list(class = "3-forte", frac = 5))))
  out <- indicateur_r5_deperissement(u, fr)
  expect_equal(out$R5, 100)
})

test_that("clusters outside the unit do not contribute", {
  skip_if_not_installed("terra")
  u <- make_units(n = 2L)
  # First unit has a cluster, second one is clean.
  fr <- make_fordead(u, list(
    list(list(class = "3-forte", frac = 0.5)),
    NULL
  ))
  out <- indicateur_r5_deperissement(u, fr)
  expect_equal(out$R5[1], 41, tolerance = 1e-6)
  expect_equal(out$R5[2], 0)
  expect_true(all(out$r5_status == "calculated"))
})

test_that("custom resineux_col overrides species detection", {
  skip_if_not_installed("terra")
  u <- make_units(n = 2L, species = "Quercus")
  u$pct_resineux <- c(0.8, 0.1)
  fr <- make_fordead(u, list(
    list(list(class = "3-forte", frac = 0.5)),
    list(list(class = "3-forte", frac = 0.5))
  ))
  out <- indicateur_r5_deperissement(u, fr,
                                     resineux_col = "pct_resineux")
  expect_equal(out$r5_status,
               c("calculated", "skipped_no_method"))
  expect_equal(out$R5[1], 41, tolerance = 1e-6)
  expect_true(is.na(out$R5[2]))
})

test_that("custom resineux_col is clamped to [0, 1]", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L, species = "Quercus")
  u$pct_resineux <- 5  # nonsense value
  fr <- make_fordead(u, list(list(list(class = "3-forte", frac = 0.5))))
  out <- indicateur_r5_deperissement(u, fr,
                                     resineux_col = "pct_resineux")
  expect_equal(out$r5_status, "calculated")
})

test_that("min_resineux threshold is honoured", {
  skip_if_not_installed("terra")
  u <- make_units(n = 2L, species = "Quercus")
  u$pct_resineux <- c(0.4, 0.2)
  fr <- make_fordead(u, list(
    list(list(class = "3-forte", frac = 0.5)),
    list(list(class = "3-forte", frac = 0.5))
  ))
  # Threshold 0.3 → unit 1 is in (0.4 >= 0.3), unit 2 out (0.2 < 0.3).
  out <- indicateur_r5_deperissement(u, fr,
                                     resineux_col = "pct_resineux",
                                     min_resineux = 0.3)
  expect_equal(out$r5_status,
               c("calculated", "skipped_no_method"))
})

test_that("custom weights override the default ONF/DSF table", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L)
  fr <- make_fordead(u, list(list(list(class = "3-forte", frac = 0.5))))
  custom <- c("3-forte" = 1, "4-sol-nu" = 1)
  out <- indicateur_r5_deperissement(u, fr, weights = custom)
  # 1.0 * 0.5 = 0.5 -> 50
  expect_equal(out$R5, 50, tolerance = 1e-6)
})

test_that("empty units returns an empty sf with R5/r5_status columns", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L)[0L, ]
  out <- indicateur_r5_deperissement(u)
  expect_equal(nrow(out), 0L)
  expect_true(all(c("R5", "r5_status") %in% names(out)))
})

test_that("non-sf units raises a typed error", {
  skip_if_not_installed("terra")
  expect_error(indicateur_r5_deperissement(list(a = 1)),
               "must be an sf")
})

test_that("missing required column on alerts_sf raises a typed error", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L)
  fr <- list(alerts_sf = sf::st_sf(
    cluster_id = 1L,
    geometry = sf::st_sfc(sf::st_point(c(950500, 6790500)), crs = 2154)
  ))
  expect_error(indicateur_r5_deperissement(u, fr),
               "missing required column")
})

test_that("R5 is picked up by create_family_index() under the R family", {
  skip_if_not_installed("terra")
  u <- make_units(n = 2L)
  u$R1 <- c(50, 60)
  u$R2 <- c(70, 30)
  u$R3 <- c(40, 50)
  u$R4 <- c(60, 80)
  fr <- make_fordead(u, list(
    list(list(class = "3-forte", frac = 0.5)),
    NULL
  ))
  u <- indicateur_r5_deperissement(u, fr)
  out <- suppressWarnings(create_family_index(u, family_codes = "R"))
  expect_true("famille_risque" %in% names(out))
  # The unit-1 famille_risque should now reflect R1..R5 (with R5 = 41).
  # We don't assert the exact mean here, just that the value is finite
  # and lies in [0, 100].
  expect_true(all(out$famille_risque >= 0 & out$famille_risque <= 100,
                  na.rm = TRUE))
})

# ---- L4: species routing (RECONFORT vs FORDEAD) ----------------------

test_that("oak unit + RECONFORT run → calculated_reconfort", {
  skip_if_not_installed("terra")
  u  <- make_units(n = 1L, species = "Quercus petraea")
  rr <- make_fordead(u, list(list(list(class = "3-tres-deperissant", frac = 0.5))))
  out <- indicateur_r5_deperissement(u, reconfort_results = rr)
  expect_equal(out$r5_status, "calculated_reconfort")
  expect_equal(out$R5, 40, tolerance = 1e-6)        # 0.80 * 0.5
})

test_that("Scots pine routes to RECONFORT (PS)", {
  skip_if_not_installed("terra")
  u  <- make_units(n = 1L, species = "PS")
  rr <- make_fordead(u, list(list(list(class = "2-deperissant", frac = 0.5))))
  out <- indicateur_r5_deperissement(u, reconfort_results = rr)
  expect_equal(out$r5_status, "calculated_reconfort")
  expect_equal(out$R5, 25, tolerance = 1e-6)        # 0.50 * 0.5 (flat default)
})

test_that("mixed zone routes EPC→FORDEAD and oak→RECONFORT", {
  skip_if_not_installed("terra")
  u  <- make_units(n = 2L, species = c("EPC", "Quercus petraea"))
  fr <- make_fordead(u, list(list(list(class = "3-forte", frac = 0.5)), NULL))
  rr <- make_fordead(u, list(NULL, list(list(class = "3-tres-deperissant", frac = 0.5))))
  out <- indicateur_r5_deperissement(u, fordead_results = fr,
                                     reconfort_results = rr)
  expect_equal(out$r5_status, c("calculated", "calculated_reconfort"))
  expect_equal(out$R5[1], 41, tolerance = 1e-6)     # FORDEAD 0.82 * 0.5
  expect_equal(out$R5[2], 40, tolerance = 1e-6)     # RECONFORT 0.80 * 0.5
})

test_that("species matching no method → skipped_no_method", {
  skip_if_not_installed("terra")
  u  <- make_units(n = 1L, species = "Fagus sylvatica")   # beech: neither
  fr <- make_fordead(u, list(list(list(class = "3-forte", frac = 0.5))))
  rr <- make_fordead(u, list(list(list(class = "3-tres-deperissant", frac = 0.5))))
  out <- indicateur_r5_deperissement(u, fordead_results = fr,
                                     reconfort_results = rr)
  expect_true(is.na(out$R5))
  expect_equal(out$r5_status, "skipped_no_method")
})

test_that("feuillus_col forces RECONFORT routing over species", {
  skip_if_not_installed("terra")
  u <- make_units(n = 2L, species = "EPC")              # would be FORDEAD
  u$pct_feuillus <- c(0.8, 0.1)
  rr <- make_fordead(u, list(
    list(list(class = "3-tres-deperissant", frac = 0.5)),
    list(list(class = "3-tres-deperissant", frac = 0.5))))
  out <- indicateur_r5_deperissement(u, reconfort_results = rr,
                                     feuillus_col = "pct_feuillus")
  expect_equal(out$r5_status, c("calculated_reconfort", "skipped_no_method"))
  expect_equal(out$R5[1], 40, tolerance = 1e-6)
})

test_that("R5 NA values do not poison family aggregation when other R indicators exist", {
  skip_if_not_installed("terra")
  u <- make_units(n = 1L, species = "Quercus")
  u$R1 <- 50; u$R2 <- 70; u$R3 <- 40; u$R4 <- 60
  out <- indicateur_r5_deperissement(u)  # NA + skipped_no_fordead
  expect_true(is.na(out$R5))
  fam <- suppressWarnings(create_family_index(out, family_codes = "R"))
  expect_false(is.na(fam$famille_risque))
})
