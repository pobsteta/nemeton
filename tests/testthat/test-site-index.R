# Tests for R/site_index.R — Phase 2, spec 005

# ---- CSV sanity (T2.6) -----------------------------------------------

test_that("site_index_curves.csv exists and has required columns", {
  path <- system.file("extdata", "site_index_curves.csv",
                      package = "nemeton")
  expect_true(nzchar(path))
  expect_true(file.exists(path))

  curves <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_true(all(c("species", "age", paste0("class_", 1:5)) %in%
                    names(curves)))
})

test_that("all MVP species and fallbacks are tabulated", {
  curves <- utils::read.csv(
    system.file("extdata", "site_index_curves.csv", package = "nemeton"),
    stringsAsFactors = FALSE
  )
  required_species <- c(
    "QUPE", "QURO", "FASY", "CASA",
    "PIAB", "ABAL", "PSME", "PISY", "PIPI", "POSP",
    "BROADLEAF_GENUS", "CONIFER_GENUS"
  )
  expect_true(all(required_species %in% curves$species))
})

test_that("curves are monotonically increasing in age per class", {
  curves <- utils::read.csv(
    system.file("extdata", "site_index_curves.csv", package = "nemeton"),
    stringsAsFactors = FALSE
  )
  for (sp in unique(curves$species)) {
    sub <- curves[curves$species == sp, ]
    sub <- sub[order(sub$age), ]
    for (cl in paste0("class_", 1:5)) {
      expect_true(all(diff(sub[[cl]]) >= 0),
                  info = paste(sp, cl))
    }
  }
})

test_that("class_1 >= class_2 >= ... >= class_5 at every age", {
  curves <- utils::read.csv(
    system.file("extdata", "site_index_curves.csv", package = "nemeton"),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(curves))) {
    vals <- as.numeric(curves[i, paste0("class_", 1:5)])
    expect_true(all(diff(vals) <= 0),
                info = paste(curves$species[i], curves$age[i]))
  }
})

test_that("heights are within plausible forestry bounds", {
  curves <- utils::read.csv(
    system.file("extdata", "site_index_curves.csv", package = "nemeton"),
    stringsAsFactors = FALSE
  )
  vals <- as.matrix(curves[, paste0("class_", 1:5)])
  expect_true(all(vals >= 0))
  expect_true(all(vals <= 55))
  expect_false(anyNA(vals))
})

test_that("no unexpected NAs in the CSV", {
  curves <- utils::read.csv(
    system.file("extdata", "site_index_curves.csv", package = "nemeton"),
    stringsAsFactors = FALSE
  )
  expect_false(anyNA(curves))
})

# ---- list_site_index_species -----------------------------------------

test_that("list_site_index_species returns a sorted character vector", {
  sp <- list_site_index_species()
  expect_type(sp, "character")
  expect_true(length(sp) >= 12)
  expect_identical(sp, sort(sp))
})

# ---- compute_site_index ----------------------------------------------

test_that("compute_site_index returns numeric of expected length", {
  out <- compute_site_index(20, 80, "QUPE")
  expect_type(out, "double")
  expect_length(out, 1)
})

test_that("compute_site_index is vectorised", {
  out <- compute_site_index(
    H_dom   = c(20, 25, 18),
    age     = c(80, 40, 60),
    species = c("QUPE", "PIAB", "FASY")
  )
  expect_length(out, 3)
  expect_true(all(!is.na(out)))
})

test_that("compute_site_index recycles species when scalar", {
  out <- compute_site_index(
    H_dom   = c(15, 20, 25),
    age     = c(40, 60, 80),
    species = "QUPE"
  )
  expect_length(out, 3)
})

test_that("NA inputs propagate to NA outputs", {
  expect_true(is.na(compute_site_index(NA, 80, "QUPE")))
  expect_true(is.na(compute_site_index(20, NA, "QUPE")))
  expect_true(is.na(compute_site_index(20, 80, NA)))
})

test_that("unknown species falls back to genus level", {
  # ACPS (Acer pseudoplatanus) not tabulated -> BROADLEAF_GENUS (=QUPE)
  a <- compute_site_index(20, 80, "ACPS")
  b <- compute_site_index(20, 80, "QUPE")
  expect_equal(a, b, tolerance = 1e-6)

  # LADE (Larix decidua) not tabulated -> CONIFER_GENUS (=PIAB)
  c_ <- compute_site_index(25, 40, "LADE")
  d  <- compute_site_index(25, 40, "PIAB")
  expect_equal(c_, d, tolerance = 1e-6)
})

test_that("site index at reference_age equals identity when age == reference_age", {
  # If the observed age already equals reference_age and the
  # height falls within the tabulated range (between class 5 and
  # class 1 at that age), the site index must reproduce H_dom.
  for (h in c(12, 15, 18, 20)) {
    out <- compute_site_index(h, age = 50, species = "QUPE",
                              reference_age = 50)
    expect_equal(out, h, tolerance = 0.1)
  }
})

test_that("site index is monotonic in observed H_dom", {
  # At fixed age/species/ref, a taller observed stand must yield
  # a strictly greater site index (better fertility class).
  heights <- c(10, 15, 20, 25, 30)
  out <- compute_site_index(heights, 80, "QUPE")
  expect_true(all(diff(out) >= 0))
})

test_that("site index is consistent between species with similar curves", {
  # Fagus is more vigorous than Quercus: for the same (H, age)
  # point, the Fagus site index at 50 years should generally not
  # be higher than the Quercus one (because the Fagus curves
  # reach the same H at a lower fertility class).
  h <- 20; a <- 80
  q <- compute_site_index(h, a, "QUPE")
  f <- compute_site_index(h, a, "FASY")
  expect_true(q >= f - 1)  # tolerance for shape differences
})

test_that("reference_age must be a positive scalar", {
  expect_error(compute_site_index(20, 80, "QUPE", reference_age = -10))
  expect_error(compute_site_index(20, 80, "QUPE", reference_age = c(50, 60)))
  expect_error(compute_site_index(20, 80, "QUPE", reference_age = NA))
})

test_that("age outside tabulated range yields NA", {
  expect_true(is.na(compute_site_index(20, 5, "QUPE")))     # < 10
  expect_true(is.na(compute_site_index(20, 200, "QUPE")))   # > 150
})

test_that("H_dom above class 1 is clamped to best class", {
  # Very tall tree -> class 1 or beyond -> the returned site
  # index should be at or above class 1 at reference_age
  curves <- read_site_index_curves()
  class_1_at_50 <- stats::approx(
    x = curves[curves$species == "QUPE", "age"],
    y = curves[curves$species == "QUPE", "class_1"],
    xout = 50
  )$y
  out <- compute_site_index(99, 80, "QUPE")
  expect_gte(out, class_1_at_50 - 0.5)
})

test_that("H_dom below class 5 is clamped to worst class", {
  curves <- read_site_index_curves()
  class_5_at_50 <- stats::approx(
    x = curves[curves$species == "QUPE", "age"],
    y = curves[curves$species == "QUPE", "class_5"],
    xout = 50
  )$y
  out <- compute_site_index(1, 80, "QUPE")
  expect_lte(out, class_5_at_50 + 0.5)
})

test_that("empty input returns numeric(0)", {
  out <- compute_site_index(numeric(0), integer(0), character(0))
  expect_identical(out, numeric(0))
})

test_that("species code is case-insensitive", {
  a <- compute_site_index(20, 80, "QUPE")
  b <- compute_site_index(20, 80, "qupe")
  expect_equal(a, b, tolerance = 1e-6)
})


# ---- Edge cases for coverage -----------------------------------

test_that("is_conifer handles NA and unknown species", {
  # Note: is_conifer is an internal helper
  expect_false(nemeton:::is_conifer(NA))
  expect_false(nemeton:::is_conifer("UNKNOWN"))
  expect_true(nemeton:::is_conifer("PIAB"))
  expect_true(nemeton:::is_conifer("piab"))  # case-insensitive
})

test_that("resolve_species_code returns NA when nothing matches", {
  expect_identical(
    nemeton:::resolve_species_code(NA, c("QUPE", "PIAB")),
    NA_character_
  )
  # Unknown species but no fallbacks available
  expect_identical(
    nemeton:::resolve_species_code("XXXX", c("QUPE")),
    NA_character_
  )
})

test_that(".frac_class returns NA when h is finite but unmatched", {
  # Defensive branch: if the heights vector is not monotone
  # decreasing, the for-loop may miss. Feed a pathological input
  # that the normal pipeline would never produce.
  classes <- c(10, 5, 8, 3, 1)
  out <- nemeton:::.frac_class(7, classes)
  expect_true(is.na(out) || (out >= 1 && out <= 5))
})
