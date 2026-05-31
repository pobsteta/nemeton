# test-qgis-export.R
# Tests for R/field_schema.R and R/qgis_export.R

skip_if_no_sf <- function() {
  skip_if_not_installed("sf")
}

skip_if_no_xml2 <- function() {
  skip_if_not_installed("xml2")
}

make_sample_plots <- function(n_base = 3, n_over = 2, crs = 2154) {
  n <- n_base + n_over
  sf::st_sf(
    plot_id = sprintf("P%02d", seq_len(n)),
    type = c(rep("Base", n_base), rep("Over", n_over)),
    visit_order = seq_len(n),
    geometry = sf::st_sfc(
      lapply(seq_len(n), function(i) sf::st_point(c(900000 + 100 * i, 6500000 + 100 * i))),
      crs = crs
    )
  )
}


# ==============================================================================
# Schema helpers
# ==============================================================================

test_that("get_placette_schema returns the expected fields", {
  schema <- get_placette_schema()
  names_visible <- vapply(Filter(function(f) !startsWith(f$name, "."),
                                 schema), `[[`, character(1), "name")

  expect_true(all(c("plot_id", "visit_order", "type", "date_visite",
                    "pente_pct", "exposition", "photos") %in% names_visible))
  # plot_id must be required
  plot_id <- Filter(function(f) f$name == "plot_id", schema)[[1]]
  expect_true(plot_id$required)
})

test_that("get_arbre_schema pulls the espece domain from species config", {
  schema <- get_arbre_schema(region = "BFC", lang = "fr")
  espece <- Filter(function(f) f$name == "espece", schema)[[1]]

  expect_true(length(espece$domain) > 0)
  expect_true(all(grepl("^essence_", espece$domain)))

  # dbh_cm is required; h_m is not
  dbh <- Filter(function(f) f$name == "dbh_cm", schema)[[1]]
  h   <- Filter(function(f) f$name == "h_m",    schema)[[1]]
  expect_true(dbh$required)
  expect_false(h$required)
})

test_that("schema_to_df drops attachment-only fields", {
  df <- schema_to_df(get_arbre_schema())
  expect_false(any(startsWith(df$name, ".")))
  expect_true(all(c("name", "type", "widget", "label", "required") %in% names(df)))
})


# ==============================================================================
# create_qgis_project()
# ==============================================================================

test_that("create_qgis_project produces a .qgz with the expected layers", {
  skip_if_no_sf()

  pts <- make_sample_plots()
  withr::with_tempdir({
    qgz <- create_qgis_project(pts, output_dir = ".", project_name = "demo")

    expect_true(file.exists(qgz))
    expect_match(qgz, "\\.qgz$")

    # A .qgz is a ZIP containing the .qgs + .gpkg.
    contents <- utils::unzip(qgz, list = TRUE)
    expect_true("demo.qgs"  %in% contents$Name)
    expect_true("demo.gpkg" %in% contents$Name)

    unz_dir <- file.path(tempdir(), "unz_demo")
    dir.create(unz_dir, showWarnings = FALSE)
    utils::unzip(qgz, exdir = unz_dir)

    layers <- sf::st_layers(file.path(unz_dir, "demo.gpkg"))
    expect_true(all(c("placettes", "arbres") %in% layers$name))

    # Both layers are POINT
    for (lyr in c("placettes", "arbres")) {
      gt <- layers$geomtype[[which(layers$name == lyr)]]
      expect_true(grepl("Point", gt, ignore.case = TRUE))
    }

    # Arbres columns match the schema
    arbres <- sf::st_read(file.path(unz_dir, "demo.gpkg"),
                          layer = "arbres", quiet = TRUE)
    expect_true(all(c("plot_id", "tree_id", "espece", "dbh_cm", "h_m",
                      "statut", "qualite") %in% names(arbres)))
    expect_equal(nrow(arbres), 0)
  })
})

test_that("create_qgis_project embeds zone_etude and parcours_tsp when provided", {
  skip_if_no_sf()

  pts <- make_sample_plots(n_base = 2, n_over = 1)
  zone <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(899000, 6499000), c(901000, 6499000),
    c(901000, 6501000), c(899000, 6501000), c(899000, 6499000)
  ))), crs = 2154))
  route <- sf::st_sf(geometry = sf::st_sfc(sf::st_linestring(rbind(
    c(900100, 6500100), c(900200, 6500200), c(900300, 6500300)
  )), crs = 2154))

  withr::with_tempdir({
    qgz <- create_qgis_project(pts, zone_etude = zone, parcours_tsp = route,
                                 output_dir = ".", project_name = "demo2")
    unz_dir <- file.path(tempdir(), "unz_demo2")
    dir.create(unz_dir, showWarnings = FALSE)
    utils::unzip(qgz, exdir = unz_dir)

    layers <- sf::st_layers(file.path(unz_dir, "demo2.gpkg"))
    expect_true(all(c("placettes", "arbres", "zone_etude", "parcours_tsp")
                    %in% layers$name))
  })
})

test_that("create_qgis_project .qgs XML is well-formed and wires field constraints", {
  skip_if_no_sf()
  skip_if_no_xml2()

  pts <- make_sample_plots()
  withr::with_tempdir({
    qgz <- create_qgis_project(pts, output_dir = ".", project_name = "xmlt")
    unz_dir <- file.path(tempdir(), "unz_xmlt")
    dir.create(unz_dir, showWarnings = FALSE)
    utils::unzip(qgz, exdir = unz_dir)

    doc <- xml2::read_xml(file.path(unz_dir, "xmlt.qgs"))
    expect_equal(xml2::xml_name(doc), "qgis")

    crs_authid <- xml2::xml_text(xml2::xml_find_first(doc,
      ".//projectCrs/spatialrefsys/authid"))
    expect_equal(crs_authid, "EPSG:2154")

    layer_names <- xml2::xml_text(xml2::xml_find_all(doc, ".//maplayer/layername"))
    expect_true(all(c("Placettes", "Arbres") %in% layer_names))

    # The datasource path is relative (QField requirement)
    datasources <- xml2::xml_text(xml2::xml_find_all(doc, ".//maplayer/datasource"))
    expect_true(all(startsWith(datasources, "./xmlt.gpkg|layername=")))

    # NotNull constraints exist on the required fields
    notnull_fields <- vapply(
      xml2::xml_find_all(doc, ".//constraint[@notnull_strength=\"1\"]"),
      function(c) xml2::xml_attr(c, "field"), character(1)
    )
    expect_true("plot_id" %in% notnull_fields)
    expect_true("tree_id" %in% notnull_fields)
    expect_true("dbh_cm"  %in% notnull_fields)

    # espece ValueMap contains the species domain (at least one entry).
    # QGIS 3.x canonical structure: map → List of Map, each Map wraps a
    # QString whose name= is the key (and value= the displayed label).
    espece_keys <- xml2::xml_find_all(doc,
      "//maplayer[layername=\"Arbres\"]//field[@name=\"espece\"]//Option[@name=\"map\"]/Option/Option[@type=\"QString\"]")
    leaf_names <- vapply(espece_keys, function(o) xml2::xml_attr(o, "name"), character(1))
    expect_true(length(leaf_names) > 0)
    expect_true(any(grepl("^essence_", leaf_names)))
  })
})

test_that("create_qgis_project refuses overwriting when overwrite=FALSE", {
  skip_if_no_sf()

  pts <- make_sample_plots()
  # Use an ABSOLUTE output_dir rather than "." inside with_tempdir:
  # create_qgis_project() does an internal setwd(stage) for the zip
  # step, so a cwd-relative output_dir makes this test depend on every
  # prior test perfectly restoring the process working directory. An
  # absolute path is immune to that cross-test coupling.
  out  <- withr::local_tempdir()
  qgz  <- file.path(out, "once.qgz")

  create_qgis_project(pts, output_dir = out, project_name = "once")
  # The first write must have produced the file — assert it explicitly
  # so a genuine write failure can't masquerade as a wrong overwrite
  # error below.
  expect_true(file.exists(qgz))

  # `cli` line-wraps the abort message, so "already exists" may be split
  # by a newline when the (absolute) path is long — match across any
  # whitespace rather than a literal space.
  expect_error(
    create_qgis_project(pts, output_dir = out, project_name = "once",
                        overwrite = FALSE),
    "already\\s+exists"
  )
})

test_that("create_qgis_project rejects non-sf placettes", {
  expect_error(
    create_qgis_project(data.frame(plot_id = "P01"),
                          output_dir = tempdir()),
    "must be an sf object"
  )
})

test_that("create_qgis_project rejects placettes without plot_id", {
  skip_if_no_sf()

  bad <- sf::st_sf(
    foo = 1:2,
    geometry = sf::st_sfc(sf::st_point(c(0, 0)), sf::st_point(c(1, 1)), crs = 2154)
  )
  expect_error(
    create_qgis_project(bad, output_dir = tempdir()),
    "plot_id"
  )
})


test_that("create_qfield_project still works as a deprecated alias", {
  skip_if_no_sf()

  pts <- make_sample_plots()
  withr::with_tempdir({
    expect_warning(
      qgz <- create_qfield_project(pts, output_dir = ".",
                                   project_name = "deprecated_alias"),
      "deprecated"
    )
    expect_true(file.exists(qgz))
    expect_match(qgz, "deprecated_alias\\.qgz$")
  })
})
