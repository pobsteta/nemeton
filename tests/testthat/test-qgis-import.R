# test-qgis-import.R
# Tests for R/qgis_import.R — import_qgis_gpkg, validate_field_data,
# aggregate_plot_metrics and attach_field_data_to_units.

# ------------------------------------------------------------
# Fixtures
# ------------------------------------------------------------

make_placettes <- function() {
  coords <- cbind(c(900000, 900100, 900200),
                  c(6500000, 6500100, 6500200))
  sf::st_sf(
    plot_id = c("P001", "P002", "P003"),
    type    = c("Base", "Base", "Over"),
    visit_order = 1:3,
    geometry = sf::st_sfc(
      apply(coords, 1, sf::st_point, simplify = FALSE),
      crs = 2154
    )
  )
}

make_arbres <- function(include_bad = TRUE) {
  df <- data.frame(
    plot_id = c("P001","P001","P001","P002","P002"),
    tree_id = c("T01","T02","T03","T01","T02"),
    espece  = c("essence_chenaie","essence_chenaie","essence_feuillus_pionniers",
                "essence_hetraie","essence_hetraie"),
    dbh_cm  = c(28, 42, 55, 31, 39),
    h_m     = c(18, 22, 28, 16, 20),
    statut  = c("vivant","vivant","vivant","vivant","mort"),
    stringsAsFactors = FALSE
  )
  if (include_bad) {
    df <- rbind(df, data.frame(
      plot_id = c("P999",           "P001"),
      tree_id = c("T01",            "T04"),
      espece  = c("essence_chenaie","Quercus_invalid"),
      dbh_cm  = c(30,               -5),
      h_m     = c(14,               10),
      statut  = c("vivant",         "vivant"),
      stringsAsFactors = FALSE
    ))
  }
  sf::st_sf(
    df,
    geometry = sf::st_sfc(lapply(seq_len(nrow(df)),
      function(i) sf::st_point(c(900000 + 5 * i, 6500050))),
      crs = 2154
    )
  )
}

write_demo_gpkg <- function(dir, include_bad = TRUE) {
  path <- file.path(dir, "demo.gpkg")
  sf::st_write(make_placettes(), path, layer = "placettes", quiet = TRUE)
  sf::st_write(make_arbres(include_bad = include_bad), path,
               layer = "arbres", quiet = TRUE)
  path
}


# ------------------------------------------------------------
# Import
# ------------------------------------------------------------

test_that("import_qgis_gpkg returns placettes + arbres sf objects", {
  skip_if_not_installed("sf")
  withr::with_tempdir({
    gpkg <- write_demo_gpkg(".")
    res <- import_qgis_gpkg(gpkg)
    expect_true(inherits(res$placettes, "sf"))
    expect_equal(nrow(res$placettes), 3)
    expect_true(inherits(res$arbres, "sf"))
    expect_gt(nrow(res$arbres), 0)
  })
})

test_that("import_qfield_gpkg still works as a deprecated alias", {
  skip_if_not_installed("sf")
  withr::with_tempdir({
    gpkg <- write_demo_gpkg(".")
    expect_warning(res <- import_qfield_gpkg(gpkg), "deprecated")
    expect_true(inherits(res$placettes, "sf"))
    expect_equal(nrow(res$placettes), 3)
  })
})

test_that("import_qgis_gpkg errors when the file is missing or malformed", {
  expect_error(import_qgis_gpkg("/no/such/file.gpkg"), "File not found")

  skip_if_not_installed("sf")
  withr::with_tempdir({
    # GPKG with only a different layer
    sf::st_write(
      sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 2154)),
      "bogus.gpkg", layer = "something_else", quiet = TRUE
    )
    expect_error(import_qgis_gpkg("bogus.gpkg"), "placettes")
  })
})


# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------

test_that("validate_field_data catches orphan plot_ids and bad DBH", {
  pl <- make_placettes()
  tr <- make_arbres(include_bad = TRUE)
  v <- validate_field_data(pl, tr, region = "BFC")

  expect_false(v$ok)
  expect_true(any(grepl("Orphan", v$errors$issue)))
  expect_true(any(grepl("DBH",    v$errors$issue)))
})

test_that("validate_field_data warns for species outside the region domain", {
  pl <- make_placettes()
  tr <- make_arbres(include_bad = TRUE)
  v  <- validate_field_data(pl, tr, region = "BFC")
  expect_true(any(v$warnings$field == "espece"))
})

test_that("validate_field_data is happy with clean input", {
  pl <- make_placettes()
  tr <- make_arbres(include_bad = FALSE)
  v  <- validate_field_data(pl, tr, region = "BFC")
  expect_true(v$ok)
  expect_equal(nrow(v$errors), 0)
})


# ------------------------------------------------------------
# Aggregation
# ------------------------------------------------------------

test_that("aggregate_plot_metrics returns one row per placette with field_* cols", {
  pl <- make_placettes()
  tr <- make_arbres(include_bad = FALSE)
  agg <- aggregate_plot_metrics(pl, tr, plot_radius = 15)

  expect_s3_class(agg, "sf")
  expect_equal(nrow(agg), 3)

  # Expected columns
  expected <- c("field_n_trees", "field_n_trees_alive",
                "field_dbh_mean_cm", "field_dg_cm",
                "field_h_mean_m", "field_h_dom_m",
                "field_g_ha", "field_cv_dbh", "field_cv_h")
  expect_true(all(expected %in% names(agg)))

  # P001 has 3 trees (DBH 28, 42, 55)
  p1 <- agg[agg$plot_id == "P001", , drop = FALSE]
  expect_equal(p1$field_n_trees, 3L)
  expect_equal(p1$field_dbh_mean_cm, mean(c(28, 42, 55)))
  # dg = sqrt(mean(dbh^2))
  expect_equal(p1$field_dg_cm, sqrt(mean(c(28, 42, 55)^2)))

  # P003 has no trees → NAs on numeric aggregates, 0 on n_trees
  p3 <- agg[agg$plot_id == "P003", , drop = FALSE]
  expect_equal(p3$field_n_trees, 0L)
  expect_true(is.na(p3$field_dbh_mean_cm))
})

test_that("aggregate_plot_metrics discards trees with non-positive DBH", {
  pl <- make_placettes()
  tr <- make_arbres(include_bad = TRUE)   # includes DBH = -5 on P001/T04
  agg <- aggregate_plot_metrics(pl, tr, plot_radius = 15)
  p1 <- agg[agg$plot_id == "P001", , drop = FALSE]
  expect_equal(p1$field_n_trees, 3L)  # bad-DBH tree excluded
})


# ------------------------------------------------------------
# Attach to units
# ------------------------------------------------------------

test_that("attach_field_data_to_units lifts placette aggregates onto polygons", {
  skip_if_not_installed("sf")

  # Two forest units covering the placettes
  poly_a <- sf::st_polygon(list(rbind(
    c(899950, 6499950), c(900150, 6499950),
    c(900150, 6500150), c(899950, 6500150), c(899950, 6499950)
  )))
  poly_b <- sf::st_polygon(list(rbind(
    c(900150, 6500150), c(900350, 6500150),
    c(900350, 6500350), c(900150, 6500350), c(900150, 6500150)
  )))
  units <- sf::st_sf(ug_id = c("UG1", "UG2"),
                     geometry = sf::st_sfc(poly_a, poly_b, crs = 2154))

  agg <- aggregate_plot_metrics(make_placettes(),
                                make_arbres(include_bad = FALSE),
                                plot_radius = 15)
  out <- attach_field_data_to_units(units, agg)

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 2)
  expect_true("field_g_ha" %in% names(out))
  # UG1 contains P001 and P002 (one tree-bearing each); UG2 contains P003 (empty).
  ug1 <- out[out$ug_id == "UG1", ]
  ug2 <- out[out$ug_id == "UG2", ]
  expect_false(is.na(ug1$field_g_ha))
  expect_equal(ug2$field_n_trees, 0L)
})
