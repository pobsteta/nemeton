# tests/testthat/test-theia-stac.R
# THEIA STAC resolver: generic STAC search + Theia asset resolution.

# ---- fixtures ----

.fake_theia_item <- function(id) {
  list(
    id = id,
    assets = list(
      height = list(
        href  = sprintf(
          "https://s3-data.meso.umontpellier.fr/sm1-gdc-ext/FORMSpoT/%s_height.tif",
          id
        ),
        roles = list("data"),
        type  = "image/tiff; application=geotiff; profile=cloud-optimized"
      ),
      thumbnail = list(
        href  = sprintf("https://theia.example/%s.png", id),
        roles = list("thumbnail")
      )
    )
  )
}

.fake_theia_resp <- function(features) {
  body <- list(features = features, links = list())
  httr2::response(
    status_code = 200L,
    headers = list(`content-type` = "application/json"),
    body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE, force = TRUE))
  )
}

# ---- .stac_pick_asset ----

test_that(".stac_pick_asset returns the named asset", {
  item <- .fake_theia_item("X1")
  href <- nemeton:::.stac_pick_asset(item, asset = "height")
  expect_match(href, "X1_height.tif")
})

test_that(".stac_pick_asset falls back to the data-role asset", {
  item <- .fake_theia_item("X2")
  href <- nemeton:::.stac_pick_asset(item, asset = NULL)
  expect_match(href, "X2_height.tif")
})

test_that(".stac_pick_asset errors on an unknown asset name", {
  item <- .fake_theia_item("X3")
  expect_error(
    nemeton:::.stac_pick_asset(item, asset = "nonexistent"),
    "no asset"
  )
})

test_that(".stac_pick_asset errors when the item has no assets", {
  expect_error(
    nemeton:::.stac_pick_asset(list(id = "X4", assets = list())),
    "no assets"
  )
})

# ---- stac_search_items ----

test_that("stac_search_items rejects an empty stac_api", {
  skip_if_not_installed("httr2")
  expect_error(
    stac_search_items("", "forms-t", c(6, 47, 6.3, 47.3)),
    "stac_api"
  )
})

test_that("stac_search_items rejects a malformed bbox", {
  skip_if_not_installed("httr2")
  expect_error(
    stac_search_items("https://stac.example", "forms-t", c(6, 47, 6.3)),
    "bbox"
  )
})

test_that("stac_search_items returns the matching item features", {
  skip_if_not_installed("httr2")
  skip_if_not_installed("jsonlite")
  items <- list(.fake_theia_item("A1"), .fake_theia_item("A2"))
  httr2::with_mocked_responses(
    function(req) .fake_theia_resp(items),
    {
      out <- stac_search_items("https://stac.example", "forms-t",
                               bbox = c(6, 47, 6.3, 47.3))
    }
  )
  expect_length(out, 2L)
  expect_equal(out[[1]]$id, "A1")
})

# ---- resolve_theia_assets ----

test_that("resolve_theia_assets errors on an unknown datasource", {
  skip_if_not_installed("sf")
  aoi <- create_test_units(n_features = 1)
  expect_error(
    resolve_theia_assets("does_not_exist", aoi, stac_api = "https://x"),
    "Unknown datasource"
  )
})

test_that(".theia_stac_api resolves the configured FR endpoint", {
  url <- nemeton:::.theia_stac_api("FR")
  expect_match(url, "api.stac.teledetection.fr")
})

test_that(".theia_stac_api aborts when no endpoint is configured", {
  # EU.json carries no services$theia_stac entry.
  expect_error(
    nemeton:::.theia_stac_api("EU"),
    "STAC API"
  )
})

test_that("resolve_theia_assets errors on an unconfirmed STAC collection", {
  skip_if_not_installed("sf")
  # s2_biophysical still has access$stac_collection = "to confirm ..."
  aoi <- create_test_units(n_features = 1)
  expect_error(
    resolve_theia_assets("s2_biophysical", aoi, stac_api = "https://stac.example"),
    "STAC collection"
  )
})

test_that("resolve_theia_assets returns /vsis3/ paths", {
  skip_if_not_installed("sf")
  skip_if_not_installed("httr2")
  skip_if_not_installed("jsonlite")
  aoi <- create_test_units(n_features = 1)
  items <- list(.fake_theia_item("S1"), .fake_theia_item("S2"))
  httr2::with_mocked_responses(
    function(req) .fake_theia_resp(items),
    {
      hrefs <- resolve_theia_assets("theia_snow", aoi,
                                    asset = "height",
                                    stac_api = "https://stac.example")
    }
  )
  expect_length(hrefs, 2L)
  expect_true(all(startsWith(hrefs, "/vsis3/")))
  expect_match(hrefs[1], "/vsis3/sm1-gdc-ext/FORMSpoT/S1_height.tif", fixed = TRUE)
})

# ---- .theia_href_to_gdal ----

test_that(".theia_href_to_gdal normalises the download-gateway form", {
  href <- paste0(
    "https://gate.stac.teledetection.fr/download?url=",
    utils::URLencode(
      "https://s3-data.meso.umontpellier.fr/sm1-gdc-ext/FORMSpoT/2023/full_2023.vrt",
      reserved = TRUE
    )
  )
  expect_equal(
    nemeton:::.theia_href_to_gdal(href),
    "/vsis3/sm1-gdc-ext/FORMSpoT/2023/full_2023.vrt"
  )
})

test_that(".theia_href_to_gdal normalises s3:// and https object URLs", {
  expect_equal(
    nemeton:::.theia_href_to_gdal("s3://sm1-gdc-ext/FORMSpoT/x.tif"),
    "/vsis3/sm1-gdc-ext/FORMSpoT/x.tif"
  )
  expect_equal(
    nemeton:::.theia_href_to_gdal(
      "https://s3-data.meso.umontpellier.fr/sm1-gdc-ext/FORMSpoT/x.tif"
    ),
    "/vsis3/sm1-gdc-ext/FORMSpoT/x.tif"
  )
})

test_that(".theia_href_to_gdal leaves a /vsi path untouched", {
  expect_equal(
    nemeton:::.theia_href_to_gdal("/vsis3/sm1-gdc-ext/x.tif"),
    "/vsis3/sm1-gdc-ext/x.tif"
  )
})

# ---- theia_configure_s3 ----

test_that("theia_configure_s3 aborts when credentials are absent", {
  withr::local_envvar(THEIA_S3_ACCESS_KEY = "", THEIA_S3_SECRET_KEY = "")
  expect_error(theia_configure_s3(), "credentials")
})

test_that("theia_configure_s3 succeeds with explicit credentials", {
  skip_if_not_installed("terra")
  expect_invisible(
    res <- theia_configure_s3(access_key = "AKfake", secret_key = "SKfake")
  )
  expect_true(res)
})

# ---- load_theia_source ----

test_that("load_theia_source propagates an unknown-datasource error", {
  skip_if_not_installed("sf")
  aoi <- create_test_units(n_features = 1)
  expect_error(
    load_theia_source("does_not_exist", aoi, stac_api = "https://stac.example"),
    "Unknown datasource"
  )
})
