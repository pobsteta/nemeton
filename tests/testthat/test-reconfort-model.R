# RECONFORT model fetch/cache (spec 021 L2a). No real download: the
# upstream models are 5.7-197 MB, so download.file() is mocked and
# verification is exercised on tiny synthetic files.

test_that("RECONFORT_MODELS registry has the four models with required fields", {
  expect_setequal(names(RECONFORT_MODELS),
                  c("v3", "v3_early_may", "v3_chestnut", "v3_pine"))
  for (v in names(RECONFORT_MODELS)) {
    e <- RECONFORT_MODELS[[v]]
    expect_true(all(c("label", "species", "n_classes", "size_bytes", "md5")
                    %in% names(e)))
    expect_match(e$md5, "^[0-9a-f]{32}$")
    expect_gt(e$size_bytes, 0)
    expect_true(e$species %in% c("CHE", "CHT", "PS"))
  }
  # Oak/chestnut are 3-class, pine is 2-class (spec 021 Q6).
  expect_equal(RECONFORT_MODELS$v3$n_classes, 3L)
  expect_equal(RECONFORT_MODELS$v3_pine$n_classes, 2L)
})

test_that("reconfort_model_info resolves and validates the version", {
  expect_equal(reconfort_model_info("v3_chestnut")$species, "CHT")
  expect_equal(reconfort_model_info("v3")$n_classes, 3L)
  expect_error(reconfort_model_info("nope"), "Unknown RECONFORT model")
  expect_error(reconfort_model_info(c("v3", "v3")), "single non-NA")
  expect_error(reconfort_model_info(NA_character_), "single non-NA")
})

test_that(".reconfort_model_url builds the framagit URL and respects the option", {
  expect_match(
    nemeton:::.reconfort_model_url("v3"),
    "framagit.org/fl.mouret/reconfort/-/raw/main/models/v3/model_1_seed_0.txt",
    fixed = TRUE
  )
  withr::local_options(nemeton.reconfort_model_base_url = "https://mirror/m")
  expect_equal(nemeton:::.reconfort_model_url("v3_pine"),
               "https://mirror/m/v3_pine/model_1_seed_0.txt")
})

test_that(".reconfort_verify_model checks size and MD5", {
  f <- withr::local_tempfile(fileext = ".txt")
  writeLines("hello reconfort", f)
  good <- list(size_bytes = file.size(f), md5 = unname(tools::md5sum(f)))
  expect_true(nemeton:::.reconfort_verify_model(f, good, "x", abort = FALSE))

  bad_md5 <- list(size_bytes = file.size(f),
                  md5 = "00000000000000000000000000000000")
  expect_false(nemeton:::.reconfort_verify_model(f, bad_md5, "x", abort = FALSE))
  expect_error(
    nemeton:::.reconfort_verify_model(f, bad_md5, "x", abort = TRUE),
    "failed verification"
  )

  bad_size <- list(size_bytes = file.size(f) + 1, md5 = good$md5)
  expect_false(nemeton:::.reconfort_verify_model(f, bad_size, "x", abort = FALSE))
})

test_that("ensure_reconfort_model uses local_path without downloading", {
  f <- withr::local_tempfile(fileext = ".txt")
  writeLines("x", f)
  # verify = FALSE -> the path is returned as-is.
  p <- ensure_reconfort_model("v3_pine", local_path = f,
                              verify = FALSE, quiet = TRUE)
  expect_equal(normalizePath(p), normalizePath(f))

  # verify = TRUE on a non-matching file -> abort.
  expect_error(
    ensure_reconfort_model("v3_pine", local_path = f,
                           verify = TRUE, quiet = TRUE),
    "failed verification"
  )

  # missing local_path -> abort.
  expect_error(
    ensure_reconfort_model("v3_pine",
                           local_path = file.path(tempdir(), "nope-xyz.txt"),
                           quiet = TRUE),
    "does not exist"
  )
})

test_that("ensure_reconfort_model downloads, caches, and serves from cache (mocked)", {
  cache <- withr::local_tempdir()
  calls <- 0L
  testthat::local_mocked_bindings(
    download.file = function(url, destfile, ...) {
      calls <<- calls + 1L
      writeLines("fake-model", destfile)
      0L
    }
  )
  p <- ensure_reconfort_model("v3_pine", cache_dir = cache,
                              verify = FALSE, quiet = TRUE)
  expect_true(file.exists(p))
  expect_match(p, "v3_pine")
  expect_equal(calls, 1L)

  # Second call -> served from cache, no re-download.
  p2 <- ensure_reconfort_model("v3_pine", cache_dir = cache,
                               verify = FALSE, quiet = TRUE)
  expect_identical(p, p2)
  expect_equal(calls, 1L)

  # force = TRUE -> re-download.
  ensure_reconfort_model("v3_pine", cache_dir = cache, force = TRUE,
                         verify = FALSE, quiet = TRUE)
  expect_equal(calls, 2L)
})

test_that("ensure_reconfort_model aborts on checksum mismatch (mocked)", {
  cache <- withr::local_tempdir()
  testthat::local_mocked_bindings(
    download.file = function(url, destfile, ...) {
      writeLines("wrong-content", destfile); 0L
    }
  )
  expect_error(
    ensure_reconfort_model("v3_pine", cache_dir = cache,
                           verify = TRUE, quiet = TRUE),
    "Checksum mismatch"
  )
})

test_that("ensure_reconfort_model aborts when the download is empty (mocked)", {
  cache <- withr::local_tempdir()
  testthat::local_mocked_bindings(
    download.file = function(url, destfile, ...) {
      file.create(destfile); 0L  # empty file
    }
  )
  expect_error(
    ensure_reconfort_model("v3_pine", cache_dir = cache,
                           verify = FALSE, quiet = TRUE),
    "empty or missing"
  )
})

test_that("ensure_reconfort_model aborts with a helpful message on download error (mocked)", {
  cache <- withr::local_tempdir()
  testthat::local_mocked_bindings(
    download.file = function(url, destfile, ...) stop("network down")
  )
  expect_error(
    ensure_reconfort_model("v3_pine", cache_dir = cache, quiet = TRUE),
    "Failed to download"
  )
})
