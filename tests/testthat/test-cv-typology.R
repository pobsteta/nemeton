# Tests for cv_typology(), cv_lookup(), bdforet_v2_mapping(),
# and the area-weighted cv_from_bdforet() aggregator.

test_that("cv_typology loads the reference CSV with the expected shape", {
  t <- cv_typology()
  expect_true(inherits(t, "data.frame"))
  expect_gte(nrow(t), 8L)
  expect_true(all(c("context_key", "context_fr", "context_en",
                    "variable", "level", "cv_low", "cv_mid",
                    "cv_high", "notes_fr") %in% names(t)))
  # Sanity: low <= mid <= high, all fractions in [0, 2].
  expect_true(all(t$cv_low <= t$cv_mid))
  expect_true(all(t$cv_mid <= t$cv_high))
  expect_true(all(t$cv_low >= 0))
  expect_true(all(t$cv_high <= 2))
})


test_that("cv_lookup returns the requested bound and errors on unknown key", {
  expect_equal(cv_lookup("futaie_reguliere_resineuse", "low"),  0.20)
  expect_equal(cv_lookup("futaie_reguliere_resineuse", "mid"),  0.275)
  expect_equal(cv_lookup("futaie_reguliere_resineuse", "high"), 0.35)
  expect_error(cv_lookup("unknown_context"), "not found")
})


test_that("bdforet_v2_mapping loads the 32 TFV codes", {
  m <- bdforet_v2_mapping()
  expect_gte(nrow(m), 32L)
  expect_true(all(c("tfv_code", "context_key", "confidence") %in% names(m)))
  expect_true(all(m$confidence %in% c("clear", "ambiguous")))
})


test_that("cv_from_bdforet aggregates per-polygon CV by area", {
  skip_if_not_installed("sf")
  # Two 100 x 200 m polygons in Lambert-93:
  #  - a 2 ha Douglas stand (FF2-64-64 -> conifer plantation, CV 0.275 mid)
  #  - a 2 ha Chênaie stand  (FF1G01-01 -> broadleaf high forest, CV 0.35 mid)
  p1 <- sf::st_polygon(list(rbind(c(0,0), c(100,0), c(100,200),
                                  c(0,200), c(0,0))))
  p2 <- sf::st_polygon(list(rbind(c(200,0), c(300,0), c(300,200),
                                  c(200,200), c(200,0))))
  bd <- sf::st_sf(
    TFV = c("FF2-64-64", "FF1G01-01"),
    geometry = sf::st_sfc(p1, p2, crs = 2154)
  )

  res <- cv_from_bdforet(bd)
  expect_true(is.list(res))
  expect_named(res, c("cv", "position", "coverage", "summary",
                      "ambiguous", "unmapped"))
  # Equal areas, shares ~0.5 each -> cv = mean(0.275, 0.35) = 0.3125.
  expect_equal(res$cv, 0.3125, tolerance = 1e-6)
  expect_equal(res$coverage, 1, tolerance = 1e-6)
  expect_equal(nrow(res$summary), 2L)
  expect_equal(length(res$unmapped), 0L)
})


test_that("cv_from_bdforet drops unmappable classes (FF0, LA4) from the CV", {
  skip_if_not_installed("sf")
  # 2 ha Douglas + 2 ha of FF0 (non-forest in mapping).
  p1 <- sf::st_polygon(list(rbind(c(0,0), c(100,0), c(100,200),
                                  c(0,200), c(0,0))))
  p2 <- sf::st_polygon(list(rbind(c(200,0), c(300,0), c(300,200),
                                  c(200,200), c(200,0))))
  bd <- sf::st_sf(
    TFV = c("FF2-64-64", "FF0"),
    geometry = sf::st_sfc(p1, p2, crs = 2154)
  )

  res <- cv_from_bdforet(bd)
  # FF0 is mapped to NA in the reference file; only Douglas counts.
  expect_equal(res$cv, 0.275, tolerance = 1e-6)
  expect_equal(res$coverage, 0.5, tolerance = 1e-6)
})


test_that("cv_from_bdforet matches on French libellé when codes are absent", {
  skip_if_not_installed("sf")
  # The IGN WFS layer `LANDCOVER.FORESTINVENTORY.V2:formation_vegetale`
  # exposes its `tfv` column as the libellé (upper-cased, dashed)
  # rather than the TFV code. cv_from_bdforet() should still resolve
  # the context via the label_key fallback.
  p1 <- sf::st_polygon(list(rbind(c(0,0), c(100,0), c(100,200),
                                  c(0,200), c(0,0))))
  p2 <- sf::st_polygon(list(rbind(c(200,0), c(300,0), c(300,200),
                                  c(200,200), c(200,0))))
  bd <- sf::st_sf(
    # Label-style input, no TFV code. Normalization in
    # cv_from_bdforet uppercases + dashes these.
    tfv = c("Forêt fermée de douglas pur",
            "Forêt fermée à mélange de conifères"),
    geometry = sf::st_sfc(p1, p2, crs = 2154)
  )
  res <- cv_from_bdforet(bd, tfv_col = "tfv")
  # Equal-area -> mean(0.275, 0.275) = 0.275. Both polygons resolve
  # to futaie_reguliere_resineuse through the label fallback.
  expect_equal(res$cv, 0.275, tolerance = 1e-6)
  expect_equal(length(res$unmapped), 0L)
})


test_that("cv_from_bdforet reports truly unknown codes and ignores mapped non-forest", {
  skip_if_not_installed("sf")
  p <- sf::st_polygon(list(rbind(c(0,0), c(100,0), c(100,100),
                                 c(0,100), c(0,0))))
  bd <- sf::st_sf(
    # FF0 is mapped to NA (non-forest) and must NOT show up as
    # unmapped; ZZZ-00 is truly absent from the mapping.
    TFV = c("FF0", "ZZZ-00", "FF2-64-64"),
    geometry = sf::st_sfc(p, p, p, crs = 2154)
  )
  res <- cv_from_bdforet(bd)
  expect_true("ZZZ-00" %in% res$unmapped)
  expect_false("FF0" %in% res$unmapped)
  # Coverage is the forest area over the AOI: only FF2-64-64 counts,
  # FF0 and ZZZ-00 are both excluded from the numerator.
  expect_equal(res$coverage, 1 / 3, tolerance = 1e-6)
  # No ambiguous rows now that the CSV flips every entry to clear.
  expect_equal(nrow(res$ambiguous), 0L)
})
