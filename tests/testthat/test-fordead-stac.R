# test-fordead-stac.R — STAC assembly + FordeadConfig helpers (spec 008 §12)
#
# All tests are offline. Python/reticulate interaction is mocked via
# testthat::local_mocked_bindings(.package = "reticulate") so the
# suite stays fast and doesn't require the FORDEAD venv to exist.

skip_if_no_sf <- function() {
  testthat::skip_if_not_installed("sf")
}

skip_if_no_reticulate <- function() {
  testthat::skip_if_not_installed("reticulate")
}

# Synthesize a small AOI polygon in Lambert-93 (EPSG:2154) — Burgundy area.
.make_test_aoi <- function() {
  sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(900000, 6700000),
      c(910000, 6700000),
      c(910000, 6710000),
      c(900000, 6710000),
      c(900000, 6700000)
    ))),
    crs = 2154
  ))
}


# ----- .aoi_bbox_4326 --------------------------------------------------

test_that(".aoi_bbox_4326 transforms to WGS84 and returns 4-numeric", {
  skip_if_no_sf()
  aoi <- .make_test_aoi()
  bb  <- nemeton:::.aoi_bbox_4326(aoi)
  expect_length(bb, 4)
  expect_type(bb, "double")
  # Burgundy in WGS84: lon ~ 4-6, lat ~ 46-48
  expect_true(bb[1] > 0 && bb[1] < 10, info = sprintf("xmin = %f", bb[1]))
  expect_true(bb[3] > bb[1], info = "xmax must be > xmin")
  expect_true(bb[2] > 40 && bb[2] < 55, info = sprintf("ymin = %f", bb[2]))
  expect_true(bb[4] > bb[2], info = "ymax must be > ymin")
})


test_that(".aoi_bbox_4326 errors on non-sf input", {
  expect_error(nemeton:::.aoi_bbox_4326("not-an-sf"), "must be an")
  expect_error(nemeton:::.aoi_bbox_4326(list()),       "must be an")
  expect_error(nemeton:::.aoi_bbox_4326(NULL),         "must be an")
})


test_that(".aoi_bbox_4326 accepts an sfc (not just sf)", {
  skip_if_no_sf()
  sfc <- sf::st_geometry(.make_test_aoi())
  expect_silent(bb <- nemeton:::.aoi_bbox_4326(sfc))
  expect_length(bb, 4)
})


# ----- .aoi_geometry_reticulate ---------------------------------------

test_that(".aoi_geometry_reticulate round-trips through shapely.wkt", {
  skip_if_no_sf()
  skip_if_no_reticulate()

  captured_wkt <- NA_character_
  fake_shapely <- list(
    loads = function(wkt_str) {
      captured_wkt <<- wkt_str
      list(`__class__` = "shapely.geometry.Polygon")
    }
  )
  testthat::local_mocked_bindings(
    import = function(module, convert = FALSE) {
      if (identical(module, "shapely.wkt")) return(fake_shapely)
      stop("unexpected import: ", module)
    },
    .package = "reticulate"
  )

  aoi    <- .make_test_aoi()
  result <- nemeton:::.aoi_geometry_reticulate(aoi)

  expect_true(grepl("^POLYGON", captured_wkt))
  expect_identical(result$`__class__`, "shapely.geometry.Polygon")
})


test_that(".aoi_geometry_reticulate errors on non-sf input", {
  expect_error(nemeton:::.aoi_geometry_reticulate("foo"), "must be an")
})


# ----- .aoi_geojson_list ----------------------------------------------

test_that(".aoi_geojson_list returns a list with type and coordinates", {
  skip_if_no_sf()
  testthat::skip_if_not_installed("jsonlite")
  aoi <- .make_test_aoi()
  gj  <- nemeton:::.aoi_geojson_list(aoi)
  expect_type(gj, "list")
  expect_true("type" %in% names(gj))
  expect_match(gj$type, "Polygon|MultiPolygon")
  expect_true("coordinates" %in% names(gj))
})


# ----- .check_dates_pair ----------------------------------------------

test_that(".check_dates_pair accepts well-formed ISO dates", {
  expect_silent(nemeton:::.check_dates_pair(c("2016-01-01", "2017-12-31"),
                                            "dates_training"))
})


test_that(".check_dates_pair rejects bad shapes and reverse ranges", {
  expect_error(
    nemeton:::.check_dates_pair("2016-01-01", "x"),
    "length-2"
  )
  expect_error(
    nemeton:::.check_dates_pair(c("bad", "2017-12-31"), "x"),
    "must parse"
  )
  expect_error(
    nemeton:::.check_dates_pair(c("2018-01-01", "2017-12-31"), "x"),
    "before start"
  )
})


test_that(".check_dates_pair allows NA end when allow_open_end = TRUE", {
  expect_silent(
    nemeton:::.check_dates_pair(c("2018-01-01", NA_character_),
                                "dates_monitoring",
                                allow_open_end = TRUE)
  )
  expect_error(
    nemeton:::.check_dates_pair(c("2018-01-01", NA_character_),
                                "dates_training",
                                allow_open_end = FALSE),
    "must parse"
  )
})


# ----- .build_fordead_config ------------------------------------------

# Build a fake fordead.config module that captures every kwarg
# passed to FordeadConfig / SpectralIndexConfig / FitConfig / PredictConfig.
.make_fake_fordead_config_module <- function() {
  captured <- new.env(parent = emptyenv())
  captured$FordeadConfig       <- NULL
  captured$SpectralIndexConfig <- NULL
  captured$FitConfig           <- NULL
  captured$PredictConfig       <- NULL

  mod <- list(
    SpectralIndexConfig = function(...) {
      captured$SpectralIndexConfig <- list(...)
      list(`__class__` = "SpectralIndexConfig")
    },
    FitConfig = function(...) {
      captured$FitConfig <- list(...)
      list(`__class__` = "FitConfig")
    },
    PredictConfig = function(...) {
      captured$PredictConfig <- list(...)
      list(`__class__` = "PredictConfig")
    },
    FordeadConfig = function(...) {
      captured$FordeadConfig <- list(...)
      list(`__class__` = "FordeadConfig")
    }
  )
  list(module = mod, captured = captured)
}


test_that(".build_fordead_config passes the four exposed knobs to fordead", {
  skip_if_no_reticulate()
  fc <- .make_fake_fordead_config_module()
  testthat::local_mocked_bindings(
    import = function(module, convert = FALSE) {
      if (identical(module, "fordead.config")) return(fc$module)
      stop("unexpected import: ", module)
    },
    .package = "reticulate"
  )

  out <- nemeton:::.build_fordead_config(
    dates_training    = c("2016-01-01", "2017-12-31"),
    dates_monitoring  = c("2018-01-01", "2018-06-01"),
    vegetation_index  = "CRSWIR",
    threshold_anomaly = 0.16
  )

  expect_identical(out$`__class__`,                           "FordeadConfig")
  expect_identical(fc$captured$SpectralIndexConfig$name,      "CRSWIR")
  expect_identical(fc$captured$FitConfig$start,               "2016-01-01")
  expect_identical(fc$captured$FitConfig$end,                 "2017-12-31")
  expect_identical(fc$captured$PredictConfig$start,           "2018-01-01")
  expect_identical(fc$captured$PredictConfig$end,             "2018-06-01")
  expect_identical(fc$captured$PredictConfig$threshold,       0.16)
})


test_that(".build_fordead_config translates NA monitoring end to NULL (open period)", {
  skip_if_no_reticulate()
  fc <- .make_fake_fordead_config_module()
  testthat::local_mocked_bindings(
    import = function(module, convert = FALSE) fc$module,
    .package = "reticulate"
  )

  nemeton:::.build_fordead_config(
    dates_training   = c("2016-01-01", "2017-12-31"),
    dates_monitoring = c("2018-01-01", NA_character_)
  )

  expect_null(fc$captured$PredictConfig$end)
})


test_that(".build_fordead_config validates inputs", {
  skip_if_no_reticulate()
  fc <- .make_fake_fordead_config_module()
  testthat::local_mocked_bindings(
    import = function(module, convert = FALSE) fc$module,
    .package = "reticulate"
  )

  expect_error(
    nemeton:::.build_fordead_config(
      dates_training    = c("2016-01-01", "2017-12-31"),
      dates_monitoring  = c("2018-01-01", "2018-06-01"),
      vegetation_index  = ""
    ),
    "non-empty"
  )
  expect_error(
    nemeton:::.build_fordead_config(
      dates_training    = c("2016-01-01", "2017-12-31"),
      dates_monitoring  = c("2018-01-01", "2018-06-01"),
      threshold_anomaly = -0.1
    ),
    "positive"
  )
  expect_error(
    nemeton:::.build_fordead_config(
      dates_training    = c("bad", "2017-12-31"),
      dates_monitoring  = c("2018-01-01", "2018-06-01")
    ),
    "must parse"
  )
})


# ----- .build_stac_collection_for_aoi ---------------------------------

# Build a fake pystac module that returns lightweight R lists for
# Item / Asset construction. The fake records every add_asset call
# so tests can assert per-band wiring.
.make_fake_pystac_module <- function() {
  state <- new.env(parent = emptyenv())
  state$items <- list()

  Asset <- function(href, roles, media_type, ...) {
    list(`__class__` = "Asset", href = href, roles = roles,
         media_type = media_type)
  }

  Item <- function(id, geometry, bbox, datetime, properties) {
    self <- new.env(parent = emptyenv())
    self$id         <- id
    self$geometry   <- geometry
    self$bbox       <- bbox
    self$datetime   <- datetime
    self$assets     <- new.env(parent = emptyenv())
    self$add_asset  <- function(name, asset) {
      assign(name, asset, envir = self$assets)
      invisible(NULL)
    }
    state$items[[length(state$items) + 1L]] <- self
    self
  }

  list(
    module = list(Item = Item, Asset = Asset),
    state  = state
  )
}

.make_fake_simplestac_module <- function() {
  state <- new.env(parent = emptyenv())
  state$collection_calls <- list()
  list(
    module = list(
      ItemCollection = function(items) {
        state$collection_calls[[length(state$collection_calls) + 1L]] <- items
        list(`__class__` = "ItemCollection", items = items, n = length(items))
      }
    ),
    state = state
  )
}

.make_fake_datetime_module <- function() {
  list(
    datetime = list(
      fromisoformat = function(s) {
        list(`__class__` = "datetime", iso = s)
      }
    )
  )
}

# Build a temporary cache layout `<cache>/<safe_scene_id>/<band>.tif`
# for the requested scene_id / band pairs.
.write_fake_cache <- function(cache_dir, scene_id, bands) {
  safe_id <- gsub("[^A-Za-z0-9._-]", "_", scene_id)
  d <- file.path(cache_dir, safe_id)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  for (b in bands) {
    f <- file.path(d, paste0(b, ".tif"))
    file.create(f)
  }
  invisible(d)
}

test_that(".build_stac_collection_for_aoi builds one item per complete scene", {
  skip_if_no_sf()
  skip_if_no_reticulate()

  cache_dir <- withr::local_tempdir()
  bands     <- c("B02", "B04", "B05", "B8A", "B11", "B12")
  .write_fake_cache(cache_dir, "S2A_MSIL2A_20210105T103441", bands)
  .write_fake_cache(cache_dir, "S2A_MSIL2A_20210115T103441", bands)

  scenes_df <- data.frame(
    scene_id = c("S2A_MSIL2A_20210105T103441", "S2A_MSIL2A_20210115T103441"),
    obs_date = as.Date(c("2021-01-05", "2021-01-15")),
    stringsAsFactors = FALSE
  )

  ps <- .make_fake_pystac_module()
  ss <- .make_fake_simplestac_module()
  dt <- .make_fake_datetime_module()

  testthat::local_mocked_bindings(
    import = function(module, convert = FALSE) {
      switch(module,
        pystac     = ps$module,
        simplestac.utils = ss$module,
        datetime   = dt,
        stop("unexpected: ", module)
      )
    },
    r_to_py = function(x) x,
    dict    = function(...) list(),
    .package = "reticulate"
  )

  aoi <- .make_test_aoi()
  out <- nemeton:::.build_stac_collection_for_aoi(
    aoi            = aoi,
    scenes_df      = scenes_df,
    cache_dir      = cache_dir,
    bands_required = bands
  )

  expect_identical(out$`__class__`, "ItemCollection")
  expect_equal(out$n, 2L)

  # Items are ordered by date.
  expect_equal(ps$state$items[[1L]]$id, "fordead_20210105")
  expect_equal(ps$state$items[[2L]]$id, "fordead_20210115")

  # Each item has all 6 bands as assets, hrefs pointing at the cache.
  for (it in ps$state$items) {
    asset_names <- ls(it$assets)
    expect_setequal(asset_names, bands)
    for (b in bands) {
      a <- get(b, envir = it$assets)
      expect_true(file.exists(a$href))
      expect_match(a$href, paste0(b, "\\.tif$"))
    }
  }
})


test_that(".build_stac_collection_for_aoi skips scenes with missing bands and warns", {
  skip_if_no_sf()
  skip_if_no_reticulate()

  cache_dir <- withr::local_tempdir()
  bands     <- c("B02", "B04", "B05", "B8A", "B11", "B12")
  .write_fake_cache(cache_dir, "S2A_complete", bands)
  # Second scene is missing B12 -> should be skipped.
  .write_fake_cache(cache_dir, "S2A_partial",  setdiff(bands, "B12"))

  scenes_df <- data.frame(
    scene_id = c("S2A_complete", "S2A_partial"),
    obs_date = as.Date(c("2021-01-05", "2021-01-15")),
    stringsAsFactors = FALSE
  )

  ps <- .make_fake_pystac_module()
  ss <- .make_fake_simplestac_module()
  dt <- .make_fake_datetime_module()

  testthat::local_mocked_bindings(
    import = function(module, convert = FALSE) {
      switch(module, pystac = ps$module, simplestac.utils = ss$module,
             datetime = dt, stop("?"))
    },
    r_to_py = function(x) x, dict = function(...) list(),
    .package = "reticulate"
  )

  aoi <- .make_test_aoi()
  expect_warning(
    out <- nemeton:::.build_stac_collection_for_aoi(aoi, scenes_df, cache_dir, bands),
    "Skipped 1/2"
  )
  expect_equal(out$n, 1L)
  expect_equal(ps$state$items[[1L]]$id, "fordead_20210105")
})


test_that(".build_stac_collection_for_aoi errors when no scene is complete", {
  skip_if_no_sf()
  skip_if_no_reticulate()

  cache_dir <- withr::local_tempdir()
  bands     <- c("B02", "B04", "B05", "B8A", "B11", "B12")
  .write_fake_cache(cache_dir, "S2A_partial", setdiff(bands, "B12"))

  scenes_df <- data.frame(
    scene_id = "S2A_partial",
    obs_date = as.Date("2021-01-05"),
    stringsAsFactors = FALSE
  )

  ps <- .make_fake_pystac_module()
  ss <- .make_fake_simplestac_module()
  dt <- .make_fake_datetime_module()
  testthat::local_mocked_bindings(
    import = function(module, convert = FALSE) {
      switch(module, pystac = ps$module, simplestac.utils = ss$module,
             datetime = dt, stop("?"))
    },
    r_to_py = function(x) x, dict = function(...) list(),
    .package = "reticulate"
  )

  aoi <- .make_test_aoi()
  expect_error(
    suppressWarnings(
      nemeton:::.build_stac_collection_for_aoi(aoi, scenes_df, cache_dir, bands)
    ),
    "No scene"
  )
})


test_that(".build_stac_collection_for_aoi validates scenes_df shape", {
  cache_dir <- withr::local_tempdir()
  aoi <- .make_test_aoi()

  bad_df <- data.frame(scene_id = "x", date = Sys.Date())  # wrong col name
  expect_error(
    nemeton:::.build_stac_collection_for_aoi(aoi, bad_df, cache_dir),
    "scene_id"
  )

  expect_error(
    nemeton:::.build_stac_collection_for_aoi(aoi, "not-a-df", cache_dir),
    "data.frame"
  )

  expect_error(
    nemeton:::.build_stac_collection_for_aoi(
      aoi,
      data.frame(scene_id = "x", obs_date = Sys.Date()),
      "/no/such/path"
    ),
    "existing directory"
  )
})


test_that(".build_stac_collection_for_aoi de-duplicates and orders by date", {
  skip_if_no_sf()
  skip_if_no_reticulate()

  cache_dir <- withr::local_tempdir()
  bands     <- c("B02", "B04", "B05", "B8A", "B11", "B12")
  .write_fake_cache(cache_dir, "S2_A", bands)
  .write_fake_cache(cache_dir, "S2_B", bands)
  .write_fake_cache(cache_dir, "S2_C", bands)

  # Input is reversed and contains a duplicate.
  scenes_df <- data.frame(
    scene_id = c("S2_C", "S2_B", "S2_A", "S2_B"),
    obs_date = as.Date(c("2021-03-01", "2021-02-01", "2021-01-01", "2021-02-01")),
    stringsAsFactors = FALSE
  )

  ps <- .make_fake_pystac_module()
  ss <- .make_fake_simplestac_module()
  dt <- .make_fake_datetime_module()
  testthat::local_mocked_bindings(
    import = function(module, convert = FALSE) {
      switch(module, pystac = ps$module, simplestac.utils = ss$module,
             datetime = dt, stop("?"))
    },
    r_to_py = function(x) x, dict = function(...) list(),
    .package = "reticulate"
  )

  aoi <- .make_test_aoi()
  out <- nemeton:::.build_stac_collection_for_aoi(aoi, scenes_df, cache_dir, bands)
  expect_equal(out$n, 3L)
  expect_equal(
    vapply(ps$state$items, function(it) it$id, character(1)),
    c("fordead_20210101", "fordead_20210201", "fordead_20210301")
  )
})
