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

test_that("create_qgis_project keeps the design weights through the QField round trip (audit 1.0)", {
  skip_if_no_sf()

  pts <- make_sample_plots(n_base = 3, n_over = 1)
  pts$wgt <- c(10, 20, 30, 40)
  pts$ip <- 1 / pts$wgt
  pts$stratum <- c("H1", "H2", "H3", "H1")
  withr::with_tempdir({
    qgz <- create_qgis_project(pts, output_dir = ".", project_name = "poids")
    unz_dir <- file.path(getwd(), "unz_poids")
    dir.create(unz_dir)
    utils::unzip(qgz, exdir = unz_dir)

    back <- import_qgis_gpkg(file.path(unz_dir, "poids.gpkg"))$placettes
    back <- back[match(pts$plot_id, back$plot_id), ]
    expect_equal(back$wgt, pts$wgt)
    expect_equal(back$ip, pts$ip)
    expect_equal(back$stratum, pts$stratum)

    # Champs caches du formulaire QGIS (non saisissables)
    qgs <- paste(readLines(file.path(unz_dir, "poids.qgs"), warn = FALSE),
                 collapse = "\n")
    expect_match(qgs, "name=\"wgt\"")
    expect_match(qgs, "type=\"Hidden\"")
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
  # Use an ABSOLUTE output_dir rather than "." inside with_tempdir, so the
  # test does not depend on prior tests restoring the working directory.
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

test_that("a failed rebuild keeps the existing .qgz intact (audit 1.0)", {
  skip_if_no_sf()
  pts <- make_sample_plots()
  out <- withr::local_tempdir()
  qgz <- create_qgis_project(pts, output_dir = out, project_name = "garde")
  avant <- unname(tools::md5sum(qgz))
  owd <- getwd()
  # Commande zip qui échoue : l'ancien .qgz était supprimé avant le zip.
  withr::local_envvar(R_ZIPCMD = "false")
  expect_error(
    create_qgis_project(pts, output_dir = out, project_name = "garde"),
    "Failed to build"
  )
  expect_true(file.exists(qgz))
  expect_identical(unname(tools::md5sum(qgz)), avant)
  expect_identical(getwd(), owd)
  # aucun temporaire laissé dans output_dir
  expect_identical(list.files(out, all.files = TRUE, no.. = TRUE), "garde.qgz")
})

test_that("create_qgis_project rejects non-sf placettes", {
  expect_error(
    create_qgis_project(data.frame(plot_id = "P01"),
                          output_dir = tempdir()),
    "must be an sf object"
  )
})

test_that("create_qgis_project rejects an unsafe project_name (audit 1.0)", {
  skip_if_no_sf()
  pts <- make_sample_plots()
  out <- withr::local_tempdir()
  for (bad in c("../evil", "a/b", "-x -T", "nom avec espace", "", NA_character_)) {
    expect_error(
      create_qgis_project(pts, output_dir = out, project_name = bad),
      "project_name"
    )
  }
  expect_length(list.files(dirname(out), pattern = "^evil"), 0L)
  expect_length(list.files(out), 0L)
})

test_that("create_qgis_project handles a CRS without EPSG code (audit 1.0)", {
  skip_if_no_sf()
  pts <- make_sample_plots()
  # Lambert-93 décrit en PROJ, sans code EPSG : $epsg vaut NA
  l93 <- sf::st_crs(paste(
    "+proj=lcc +lat_0=46.5 +lon_0=3 +lat_1=49 +lat_2=44",
    "+x_0=700000 +y_0=6600000 +ellps=GRS80 +units=m +no_defs"))
  pts_proj <- sf::st_transform(pts, l93)
  expect_true(is.na(sf::st_crs(pts_proj)$epsg))
  out <- withr::local_tempdir()
  qgz <- create_qgis_project(pts_proj, output_dir = out, project_name = "noepsg")
  expect_true(file.exists(qgz))

  # sans CRS du tout : erreur explicite
  pts_na <- sf::st_set_crs(pts, NA)
  expect_error(create_qgis_project(pts_na, output_dir = out, project_name = "nocrs"),
               "no CRS")
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
  # Etat de session remis a zero (l'avertissement n'est emis qu'une fois).
  st <- get(".qgis_export_state", envir = asNamespace("nemeton"))
  st$qfield_deprecation_warned <- FALSE
  withr::defer(st$qfield_deprecation_warned <- FALSE)
  withr::with_tempdir({
    expect_warning(
      qgz <- create_qfield_project(pts, output_dir = ".",
                                   project_name = "deprecated_alias"),
      "deprecated"
    )
    expect_true(file.exists(qgz))
    expect_match(qgz, "deprecated_alias\\.qgz$")
    # Annonce « une fois » : le deuxieme appel n'avertit plus (audit 1.0).
    expect_no_warning(
      create_qfield_project(pts, output_dir = ".",
                            project_name = "deprecated_alias2"))
  })
})
