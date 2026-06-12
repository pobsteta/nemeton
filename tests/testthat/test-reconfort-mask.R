# Tests for the RECONFORT OSO broadleaf-mask fetch/cache (lot L2b.3).
# Real downloads (~54 MB) never run here — the network step is mocked.

test_that("RECONFORT_OSO_MASK registry entry is well-formed", {
  expect_type(RECONFORT_OSO_MASK, "list")
  expect_identical(RECONFORT_OSO_MASK$file, "mask_oso_deciduous_compress.tif")
  expect_gt(RECONFORT_OSO_MASK$size_bytes, 1e7)
  expect_match(RECONFORT_OSO_MASK$md5, "^[0-9a-f]{32}$")
})

test_that(".reconfort_mask_url honours the option override", {
  withr::local_options(nemeton.reconfort_mask_base_url = "https://mirror.example/masks")
  expect_equal(nemeton:::.reconfort_mask_url(),
               "https://mirror.example/masks/mask_oso_deciduous_compress.tif")
})

test_that("ensure_reconfort_oso_mask uses a verified local_path, skips download", {
  dir <- withr::local_tempdir()
  m   <- file.path(dir, "custom_mask.tif")
  writeLines("not a real raster", m)
  # verify = FALSE so a stand-in custom mask is accepted as-is.
  out <- ensure_reconfort_oso_mask(local_path = m, verify = FALSE, quiet = TRUE)
  expect_equal(normalizePath(out), normalizePath(m))
})

test_that("ensure_reconfort_oso_mask aborts on a missing local_path", {
  expect_error(
    ensure_reconfort_oso_mask(local_path = "/no/such/mask.tif", verify = FALSE),
    "does not exist"
  )
})

test_that("ensure_reconfort_oso_mask returns a verified cached copy without download", {
  cache <- withr::local_tempdir()
  dest  <- file.path(cache, RECONFORT_OSO_MASK$file)
  writeLines("cached", dest)
  # Mock verification to accept the cached file; the cache hit returns
  # before any download is attempted.
  testthat::local_mocked_bindings(
    .reconfort_verify_mask = function(path, abort = TRUE) TRUE
  )
  out <- ensure_reconfort_oso_mask(cache_dir = cache, quiet = TRUE)
  expect_equal(out, dest)
})
