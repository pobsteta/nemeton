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
  # v0.24.1 widened the band set from 3 (FAST) to 7 (FAST + FORDEAD).
  expect_named(out, c("scene_id", "obs_date", "cloud_pct",
                      "href_B02", "href_B04", "href_B05", "href_B08",
                      "href_B8A", "href_B11", "href_B12", "source"))
})

test_that("stac_search_s2 rejects end < start", {
  expect_error(
    stac_search_s2(c(4, 47, 5, 48), "2025-07-01", "2025-06-01"),
    "must be on or after"
  )
})


# ---- retry policy (v0.21.5) ------------------------------------------

test_that(".is_stac_transient flags 429 + 5xx as retryable", {
  fake_resp <- function(status) {
    structure(list(status_code = status), class = "httr2_response")
  }
  expect_true(nemeton:::.is_stac_transient(fake_resp(429)))
  expect_true(nemeton:::.is_stac_transient(fake_resp(500)))
  expect_true(nemeton:::.is_stac_transient(fake_resp(502)))
  expect_true(nemeton:::.is_stac_transient(fake_resp(503)))
  expect_true(nemeton:::.is_stac_transient(fake_resp(504)))
  expect_false(nemeton:::.is_stac_transient(fake_resp(200)))
  expect_false(nemeton:::.is_stac_transient(fake_resp(400)))
  expect_false(nemeton:::.is_stac_transient(fake_resp(404)))
})

test_that(".with_stac_retry honours NEMETON_STAC_MAX_TRIES env var", {
  skip_if_not_installed("httr2")
  withr::local_envvar(NEMETON_STAC_MAX_TRIES = "7")
  req <- httr2::request("https://example.test") |>
    nemeton:::.with_stac_retry()
  # httr2 stores the configured policy in req$policies$retry_max_tries
  # (or under a similar key depending on version). Fall back to a
  # structural smoke check if the layout differs across httr2 versions.
  pol <- req$policies %||% list()
  mt <- pol$retry_max_tries %||% pol$retry$max_tries
  if (is.null(mt)) skip("httr2 policy layout differs — covered indirectly")
  expect_equal(as.integer(mt), 7L)
})

test_that(".with_stac_retry falls back to 4 when the env var is invalid", {
  skip_if_not_installed("httr2")
  withr::local_envvar(NEMETON_STAC_MAX_TRIES = "not-a-number")
  req <- httr2::request("https://example.test") |>
    nemeton:::.with_stac_retry()
  pol <- req$policies %||% list()
  mt <- pol$retry_max_tries %||% pol$retry$max_tries
  if (is.null(mt)) skip("httr2 policy layout differs")
  expect_equal(as.integer(mt), 4L)
})

test_that("stac_search_s2 emits an 'All STAC backends failed' warning when every backend errors", {
  testthat::local_mocked_bindings(
    stac_search_s2_cdse = function(...) stop("CDSE 504"),
    stac_search_s2_pc   = function(...) stop("PC 504")
  )
  expect_warning(
    expect_warning(
      expect_warning(
        out <- stac_search_s2(c(4, 47, 5, 48), "2025-06-01", "2025-06-30"),
        "All STAC backends"
      ),
      "STAC backend.*pc.*failed"
    ),
    "STAC backend.*cdse.*failed"
  )
  expect_equal(nrow(out), 0)
})


# ---- .stac_search_paginate (v0.27.0) ----------------------------------

# Build a fake STAC feature list of `n` items with sequential
# scene_ids and dates spread evenly across `date_start` → `date_end`.
.fake_stac_features <- function(n, id_prefix = "S2A", date_start = "2025-01-01") {
  d0 <- as.Date(date_start)
  lapply(seq_len(n), function(i) {
    list(
      id = sprintf("%s_%04d", id_prefix, i),
      properties = list(
        datetime         = paste0(format(d0 + i - 1L), "T10:30:00Z"),
        `eo:cloud_cover` = 5.0
      ),
      assets = list(
        B04 = list(href = sprintf("https://example/%04d/b04.tif", i)),
        B08 = list(href = sprintf("https://example/%04d/b08.tif", i)),
        B12 = list(href = sprintf("https://example/%04d/b12.tif", i))
      )
    )
  })
}

# Build a fake STAC response with optional `next` link.
.fake_stac_resp <- function(features, next_url = NULL) {
  body <- list(features = features)
  if (!is.null(next_url)) {
    body$links <- list(list(rel = "next", href = next_url, method = "POST",
                             body = list(token = "FAKE_TOKEN")))
  } else {
    body$links <- list()
  }
  httr2::response(
    status_code = 200L,
    headers = list(`content-type` = "application/json"),
    body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE, force = TRUE))
  )
}

test_that(".stac_search_paginate returns features from a single page when no next link", {
  skip_if_not_installed("httr2")
  skip_if_not_installed("jsonlite")
  features <- .fake_stac_features(3L)
  httr2::with_mocked_responses(
    function(req) .fake_stac_resp(features, next_url = NULL),
    {
      out <- nemeton:::.stac_search_paginate(
        initial_url  = "https://example/search",
        initial_body = list(collections = list("X"), limit = 1000L)
      )
    }
  )
  expect_length(out, 3L)
  expect_equal(out[[1]]$id, "S2A_0001")
  expect_equal(out[[3]]$id, "S2A_0003")
})

test_that(".stac_search_paginate follows next link across multiple pages", {
  skip_if_not_installed("httr2")
  skip_if_not_installed("jsonlite")
  page1 <- .fake_stac_features(2L, id_prefix = "P1")
  page2 <- .fake_stac_features(2L, id_prefix = "P2")
  page3 <- .fake_stac_features(1L, id_prefix = "P3")
  call_n <- 0L
  httr2::with_mocked_responses(
    function(req) {
      call_n <<- call_n + 1L
      switch(as.character(call_n),
        "1" = .fake_stac_resp(page1, next_url = "https://example/search?page=2"),
        "2" = .fake_stac_resp(page2, next_url = "https://example/search?page=3"),
        "3" = .fake_stac_resp(page3, next_url = NULL),
        .fake_stac_resp(list(), next_url = NULL)
      )
    },
    {
      out <- nemeton:::.stac_search_paginate(
        initial_url  = "https://example/search",
        initial_body = list(collections = list("X"), limit = 1000L)
      )
    }
  )
  expect_equal(call_n, 3L)
  expect_length(out, 5L)
  expect_equal(vapply(out, function(f) f$id, character(1)),
               c("P1_0001", "P1_0002", "P2_0001", "P2_0002", "P3_0001"))
})

test_that(".stac_search_paginate truncates at max_total", {
  skip_if_not_installed("httr2")
  skip_if_not_installed("jsonlite")
  page1 <- .fake_stac_features(3L, id_prefix = "P1")
  page2 <- .fake_stac_features(3L, id_prefix = "P2")
  call_n <- 0L
  httr2::with_mocked_responses(
    function(req) {
      call_n <<- call_n + 1L
      switch(as.character(call_n),
        "1" = .fake_stac_resp(page1, next_url = "https://example/search?page=2"),
        "2" = .fake_stac_resp(page2, next_url = "https://example/search?page=3"),
        .fake_stac_resp(list(), next_url = NULL)
      )
    },
    {
      out <- nemeton:::.stac_search_paginate(
        initial_url  = "https://example/search",
        initial_body = list(),
        max_total    = 4L
      )
    }
  )
  # Truncation happens after page 2 is accumulated → cap hit before page 3.
  expect_equal(call_n, 2L)
  expect_length(out, 4L)
})

test_that(".stac_search_paginate stops on empty page", {
  skip_if_not_installed("httr2")
  skip_if_not_installed("jsonlite")
  call_n <- 0L
  httr2::with_mocked_responses(
    function(req) {
      call_n <<- call_n + 1L
      .fake_stac_resp(list(), next_url = "https://example/search?page=2")
    },
    {
      out <- nemeton:::.stac_search_paginate(
        initial_url  = "https://example/search",
        initial_body = list()
      )
    }
  )
  expect_equal(call_n, 1L)
  expect_length(out, 0L)
})

test_that(".stac_page_size honours NEMETON_STAC_PAGE_SIZE env var", {
  withr::local_envvar(NEMETON_STAC_PAGE_SIZE = "250")
  expect_equal(nemeton:::.stac_page_size(), 250L)
  withr::local_envvar(NEMETON_STAC_PAGE_SIZE = "bogus")
  expect_equal(nemeton:::.stac_page_size(), 1000L)
  withr::local_envvar(NEMETON_STAC_PAGE_SIZE = "0")
  expect_equal(nemeton:::.stac_page_size(), 1000L)
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

# ---- .pc_invalidate_token / .pc_resign_href (v0.21.6) ----------------

test_that(".pc_invalidate_token drops the cached entry", {
  rm(list = ls(nemeton:::.pc_token_cache, all.names = TRUE),
     envir = nemeton:::.pc_token_cache)
  on.exit(rm(list = ls(nemeton:::.pc_token_cache, all.names = TRUE),
             envir = nemeton:::.pc_token_cache), add = TRUE)
  assign("sentinel-2-l2a",
         list(token = "se=x&sig=Y", expiry = Sys.time() + 3600),
         envir = nemeton:::.pc_token_cache)
  expect_true("sentinel-2-l2a" %in% ls(nemeton:::.pc_token_cache))
  nemeton:::.pc_invalidate_token("sentinel-2-l2a")
  expect_false("sentinel-2-l2a" %in% ls(nemeton:::.pc_token_cache))
  # Idempotent: a second call on an empty entry is a no-op.
  expect_silent(nemeton:::.pc_invalidate_token("sentinel-2-l2a"))
  expect_silent(nemeton:::.pc_invalidate_token(""))
})

test_that(".pc_resign_href strips the old query and applies a fresh token", {
  testthat::local_mocked_bindings(
    .pc_collection_token = function(collection, ...) "se=NEW&sp=r&sig=FRESH",
    .package = "nemeton"
  )
  href <- "https://sentinel2l2a01.blob.core.windows.net/c/X.tif?se=OLD&sig=STALE"
  out <- nemeton:::.pc_resign_href(href)
  expect_match(out, "\\?se=NEW&sp=r&sig=FRESH$")
  expect_false(grepl("STALE", out, fixed = TRUE))
  expect_false(grepl("OLD", out, fixed = TRUE))
})

test_that(".pc_resign_href returns NULL when token refresh fails", {
  testthat::local_mocked_bindings(
    .pc_collection_token = function(collection, ...) NULL,
    .package = "nemeton"
  )
  out <- nemeton:::.pc_resign_href("https://x.blob.core.windows.net/c/X.tif?sig=Z")
  expect_null(out)
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

# ---- v0.22.1: proactive SAS token expiry check -----------------------

test_that(".pc_href_expires_at parses a valid `se=` parameter", {
  href <- paste0(
    "https://sentinel2l2a01.blob.core.windows.net/x/B04.tif",
    "?st=2026-05-15T08%3A00%3A00Z&se=2026-05-15T09%3A00%3A00Z",
    "&sp=rl&sig=abc"
  )
  out <- nemeton:::.pc_href_expires_at(href)
  expect_s3_class(out, "POSIXct")
  expect_equal(
    format(out, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    "2026-05-15 09:00:00"
  )
})

test_that(".pc_href_expires_at returns NA on hrefs without `se=`", {
  # No query
  expect_true(is.na(nemeton:::.pc_href_expires_at(
    "https://example/B04.tif"
  )))
  # Query but no se=
  expect_true(is.na(nemeton:::.pc_href_expires_at(
    "https://example/B04.tif?sig=abc"
  )))
  # Empty / NA / non-character
  expect_true(is.na(nemeton:::.pc_href_expires_at("")))
  expect_true(is.na(nemeton:::.pc_href_expires_at(NA_character_)))
  expect_true(is.na(nemeton:::.pc_href_expires_at(NULL)))
})

test_that(".pc_ensure_fresh_href is a no-op on non-PC URLs", {
  # CDSE STAC backend, no PC blob
  href_cdse <- "https://datahub.copernicus.eu/x/B04.tif?token=xyz"
  expect_identical(nemeton:::.pc_ensure_fresh_href(href_cdse), href_cdse)
  # Unsigned PC URL (no sig=) — left as-is, the retry helper will fix it
  href_unsigned <- "https://sentinel2l2a01.blob.core.windows.net/x/B04.tif"
  expect_identical(nemeton:::.pc_ensure_fresh_href(href_unsigned),
                   href_unsigned)
})

test_that(".pc_ensure_fresh_href is a no-op when the token is still fresh", {
  # se= 2 hours in the future
  future <- format(Sys.time() + 2 * 3600, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  href <- paste0(
    "https://sentinel2l2a01.blob.core.windows.net/x/B04.tif",
    "?st=2026-05-15T08%3A00%3A00Z&se=", utils::URLencode(future, reserved = TRUE),
    "&sp=rl&sig=abc"
  )
  # Mock to assert we did NOT call .pc_resign_href
  n_resign <- 0L
  testthat::local_mocked_bindings(
    .pc_resign_href = function(...) { n_resign <<- n_resign + 1L; "RESIGNED" },
    .package = "nemeton"
  )
  out <- nemeton:::.pc_ensure_fresh_href(href)
  expect_identical(out, href)
  expect_equal(n_resign, 0L)
})

test_that(".pc_ensure_fresh_href resigns when the token is within grace_seconds", {
  # se= 30 seconds in the future — under default grace = 60s
  near <- format(Sys.time() + 30, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  href <- paste0(
    "https://sentinel2l2a01.blob.core.windows.net/x/B04.tif",
    "?st=2026-05-15T08%3A00%3A00Z&se=", utils::URLencode(near, reserved = TRUE),
    "&sp=rl&sig=stale"
  )
  testthat::local_mocked_bindings(
    .pc_resign_href = function(...) {
      "https://sentinel2l2a01.blob.core.windows.net/x/B04.tif?se=fresh&sig=new"
    },
    .package = "nemeton"
  )
  out <- nemeton:::.pc_ensure_fresh_href(href)
  expect_match(out, "sig=new", fixed = TRUE)
  expect_false(grepl("sig=stale", out, fixed = TRUE))
})

test_that(".pc_ensure_fresh_href falls back to the original href when resign fails", {
  near <- format(Sys.time() + 10, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  href <- paste0(
    "https://sentinel2l2a01.blob.core.windows.net/x/B04.tif",
    "?st=2026-05-15T08%3A00%3A00Z&se=", utils::URLencode(near, reserved = TRUE),
    "&sp=rl&sig=stale"
  )
  testthat::local_mocked_bindings(
    .pc_resign_href = function(...) NULL,   # simulate token endpoint down
    .package = "nemeton"
  )
  # Falls back to original (the reactive retry will then trigger)
  expect_identical(nemeton:::.pc_ensure_fresh_href(href), href)
})
