# tests/testthat/test-theia-stac.R
# THEIA STAC resolver: generic STAC search + Theia asset resolution.

# ---- fixtures ----

.fake_theia_item <- function(id) {
  list(
    id = id,
    assets = list(
      height = list(
        href  = sprintf("https://theia.example/%s_height.tif", id),
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

test_that("resolve_theia_assets errors when no STAC API is configured", {
  skip_if_not_installed("sf")
  # theia_snow carries a confirmed stac_collection, but services$theia_stac$url
  # is still "to confirm" — the resolver must abort with guidance.
  aoi <- create_test_units(n_features = 1)
  expect_error(
    resolve_theia_assets("theia_snow", aoi),
    "STAC API"
  )
})

test_that("resolve_theia_assets errors on an unconfirmed STAC collection", {
  skip_if_not_installed("sf")
  # forms_t still has access$stac_collection = "to confirm ..."
  aoi <- create_test_units(n_features = 1)
  expect_error(
    resolve_theia_assets("forms_t", aoi, stac_api = "https://stac.example"),
    "STAC collection"
  )
})

test_that("resolve_theia_assets returns vsicurl-prefixed hrefs", {
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
  expect_true(all(startsWith(hrefs, "/vsicurl/")))
  expect_match(hrefs[1], "S1_height.tif")
})

# ---- load_theia_source ----

test_that("load_theia_source propagates the no-STAC-API error", {
  skip_if_not_installed("sf")
  aoi <- create_test_units(n_features = 1)
  expect_error(
    load_theia_source("theia_snow", aoi),
    "STAC API"
  )
})
