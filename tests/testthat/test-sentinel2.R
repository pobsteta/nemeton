# test-sentinel2.R — STAC search with mocked HTTP backends

test_that(".zone_to_bbox4326 reprojects an sf object", {
  skip_if_not_installed("sf")
  bb <- sf::st_bbox(c(xmin = 700000, ymin = 6500000,
                      xmax = 750000, ymax = 6550000), crs = 2154)
  pol <- sf::st_as_sfc(bb)
  out <- nemeton:::.zone_to_bbox4326(pol)
  expect_length(out, 4)
  # Should now be near 3-4°E, 47-48°N
  expect_true(out[1] > 0 && out[1] < 10)
  expect_true(out[2] > 40 && out[2] < 55)
})

test_that(".zone_to_bbox4326 accepts a numeric bbox", {
  out <- nemeton:::.zone_to_bbox4326(c(4, 47, 5, 48))
  expect_equal(out, c(4, 47, 5, 48))
})


test_that(".features_to_tibble parses STAC features", {
  features <- list(
    list(
      id = "S2A_TEST_001",
      properties = list(datetime = "2025-06-10T10:30:00Z",
                        `eo:cloud_cover` = 5.0),
      assets = list(B04 = list(href = "https://example/b04.tif"),
                    B08 = list(href = "https://example/b08.tif"),
                    B12 = list(href = "https://example/b12.tif"))
    )
  )
  out <- nemeton:::.features_to_tibble(features, source = "cdse")
  expect_equal(nrow(out), 1)
  expect_equal(out$scene_id, "S2A_TEST_001")
  expect_equal(out$obs_date, as.Date("2025-06-10"))
  expect_equal(out$cloud_pct, 5)
  expect_equal(out$source, "cdse")
})

test_that(".features_to_tibble drops scenes missing band hrefs", {
  features <- list(
    list(id = "missing_B12",
         properties = list(datetime = "2025-06-10T10:30:00Z"),
         assets = list(B04 = list(href = "x"), B08 = list(href = "y")))
  )
  out <- nemeton:::.features_to_tibble(features, source = "cdse")
  expect_equal(nrow(out), 0)
})


test_that("stac_search_s2 falls back from CDSE to PC on error", {
  testthat::local_mocked_bindings(
    stac_search_s2_cdse = function(...) stop("CDSE down"),
    stac_search_s2_pc   = function(...) {
      data.frame(scene_id = "S2A_PC_001",
                 obs_date = as.Date("2025-06-10"),
                 cloud_pct = 2,
                 href_B04 = "x", href_B08 = "y", href_B12 = "z",
                 source = "pc",
                 stringsAsFactors = FALSE)
    }
  )
  out <- stac_search_s2(c(4, 47, 5, 48), "2025-06-01", "2025-06-30")
  expect_equal(nrow(out), 1)
  expect_equal(out$source, "pc")
})

test_that("stac_search_s2 returns empty tibble when both backends are silent", {
  testthat::local_mocked_bindings(
    stac_search_s2_cdse = function(...) nemeton:::.empty_scene_tibble(),
    stac_search_s2_pc   = function(...) nemeton:::.empty_scene_tibble()
  )
  out <- stac_search_s2(c(4, 47, 5, 48), "2025-06-01", "2025-06-30")
  expect_equal(nrow(out), 0)
  expect_named(out, c("scene_id", "obs_date", "cloud_pct",
                      "href_B04", "href_B08", "href_B12", "source"))
})

test_that("stac_search_s2 rejects end < start", {
  expect_error(
    stac_search_s2(c(4, 47, 5, 48), "2025-07-01", "2025-06-01"),
    "must be on or after"
  )
})


# ---- .pc_apply_token ---------------------------------------------------

test_that(".pc_apply_token appends a SAS token to bare hrefs", {
  href  <- "https://sentinel2l2a01.blob.core.windows.net/sentinel2-l2/X/Y/Z.tif"
  token <- "se=2026-05-06T13Z&sp=r&sig=abc%3D"
  out <- nemeton:::.pc_apply_token(href, token)
  expect_equal(out, paste0(href, "?", token))
})

test_that(".pc_apply_token accepts a leading '?' in the token", {
  href  <- "https://example.blob.core.windows.net/c/x.tif"
  token <- "?se=2026-05-06T13Z&sig=xyz"
  out <- nemeton:::.pc_apply_token(href, token)
  expect_equal(out, paste0(href, "?se=2026-05-06T13Z&sig=xyz"))
})

test_that(".pc_apply_token uses '&' when the href already has a query", {
  href  <- "https://example.blob.core.windows.net/c/x.tif?cache=1"
  token <- "se=Z&sig=Q"
  out <- nemeton:::.pc_apply_token(href, token)
  expect_equal(out, "https://example.blob.core.windows.net/c/x.tif?cache=1&se=Z&sig=Q")
})

test_that(".pc_apply_token returns href unchanged on empty token", {
  href <- "https://example/x.tif"
  expect_equal(nemeton:::.pc_apply_token(href, NULL),  href)
  expect_equal(nemeton:::.pc_apply_token(href, ""),    href)
  expect_equal(nemeton:::.pc_apply_token("",   "sig"), "")
})


# ---- .pc_collection_token ---------------------------------------------

test_that(".pc_collection_token returns a cached token while it is fresh", {
  # Pre-seed the cache with a far-future expiry.
  rm(list = ls(nemeton:::.pc_token_cache, all.names = TRUE),
     envir = nemeton:::.pc_token_cache)
  on.exit(rm(list = ls(nemeton:::.pc_token_cache, all.names = TRUE),
             envir = nemeton:::.pc_token_cache), add = TRUE)
  assign("sentinel-2-l2a",
         list(token = "se=cached&sig=AAA",
              expiry = Sys.time() + 3600),
         envir = nemeton:::.pc_token_cache)
  # If the function tried to make an HTTP call, we'd see a real
  # network attempt; the cached path returns without touching httr2.
  out <- nemeton:::.pc_collection_token("sentinel-2-l2a")
  expect_equal(out, "se=cached&sig=AAA")
})

test_that(".pc_collection_token refreshes when the cached entry has expired", {
  rm(list = ls(nemeton:::.pc_token_cache, all.names = TRUE),
     envir = nemeton:::.pc_token_cache)
  on.exit(rm(list = ls(nemeton:::.pc_token_cache, all.names = TRUE),
             envir = nemeton:::.pc_token_cache), add = TRUE)
  # Cached but expired — must be replaced.
  assign("sentinel-2-l2a",
         list(token = "se=stale&sig=OLD",
              expiry = Sys.time() - 60),
         envir = nemeton:::.pc_token_cache)
  fake_resp <- structure(list(), class = "httr2_response")
  testthat::local_mocked_bindings(
    request       = function(url) structure(list(url = url), class = "httr2_request"),
    req_timeout   = function(req, seconds) req,
    req_perform   = function(req) fake_resp,
    resp_body_json = function(resp) list(
      token = "se=fresh&sig=NEW",
      `msft:expiry` = format(Sys.time() + 1800, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    ),
    .package = "httr2"
  )
  out <- nemeton:::.pc_collection_token("sentinel-2-l2a")
  expect_equal(out, "se=fresh&sig=NEW")
  # Cache must now hold the new value.
  expect_equal(nemeton:::.pc_token_cache[["sentinel-2-l2a"]]$token,
               "se=fresh&sig=NEW")
})

test_that(".pc_collection_token returns NULL on HTTP failure", {
  rm(list = ls(nemeton:::.pc_token_cache, all.names = TRUE),
     envir = nemeton:::.pc_token_cache)
  on.exit(rm(list = ls(nemeton:::.pc_token_cache, all.names = TRUE),
             envir = nemeton:::.pc_token_cache), add = TRUE)
  testthat::local_mocked_bindings(
    request     = function(url) structure(list(url = url), class = "httr2_request"),
    req_timeout = function(req, seconds) req,
    req_perform = function(req) stop("network down"),
    .package = "httr2"
  )
  expect_warning(
    out <- nemeton:::.pc_collection_token("sentinel-2-l2a"),
    "PC token fetch failed"
  )
  expect_null(out)
  # And nothing was cached.
  expect_false("sentinel-2-l2a" %in% ls(nemeton:::.pc_token_cache))
})
