# test-lidar_processing.R
#
# Unit tests for the lasR-backed MNT/MNH fallback (compute_dtm_chm_from_laz)
# and its integration into resolve_project_dem / resolve_project_chm.
#
# Heavy lifting (real .laz files + a working lasR install) is exercised in
# the integration suite. Here we focus on the guards: missing tiles, missing
# package, argument validation, opt-out flag, and that the resolve_project_*
# fallback never errors when nothing can be done.

# ---- argument validation --------------------------------------------------

test_that("compute_dtm_chm_from_laz rejects invalid laz_dir", {
  expect_error(
    compute_dtm_chm_from_laz(NULL),
    "must be a single non-empty path"
  )
  expect_error(
    compute_dtm_chm_from_laz(c("a", "b")),
    "must be a single non-empty path"
  )
})

test_that("compute_dtm_chm_from_laz warns + NULL when laz_dir is missing", {
  expect_warning(
    out <- compute_dtm_chm_from_laz("/no/such/dir", verbose = FALSE),
    "does not exist"
  )
  expect_null(out)
})

test_that("compute_dtm_chm_from_laz warns + NULL when no .laz tiles exist", {
  laz_dir <- withr::local_tempdir()
  expect_warning(
    out <- compute_dtm_chm_from_laz(laz_dir, verbose = FALSE),
    "No .laz"
  )
  expect_null(out)
})


# ---- integration with resolve_project_dem / resolve_project_chm ----------

test_that("resolve_project_dem does not error when fallback has no .laz", {
  proj <- withr::local_tempdir()
  # No rasters, no .laz — fallback is opportunistic and must return NULL
  # silently rather than blowing up.
  expect_null(resolve_project_dem(proj))
})

test_that("resolve_project_chm does not error when fallback has no .laz", {
  proj <- withr::local_tempdir()
  expect_null(resolve_project_chm(proj))
})

test_that("try_compute_from_laz = FALSE skips the fallback entirely", {
  proj <- withr::local_tempdir()
  laz_dir <- file.path(proj, "cache", "layers", "lidar_nuage")
  dir.create(laz_dir, recursive = TRUE)
  # Touch a fake .laz so the fallback *would* fire if not opted out.
  file.create(file.path(laz_dir, "fake.laz"))

  # With opt-out the function must return NULL without ever calling lasR.
  # (If lasR were called on a fake 0-byte .laz it would error.)
  expect_null(resolve_project_dem(proj, try_compute_from_laz = FALSE))
  expect_null(resolve_project_chm(proj, try_compute_from_laz = FALSE))
})

test_that("fallback is skipped (without error) when lasR is unavailable", {
  skip_if(requireNamespace("lasR", quietly = TRUE),
          "lasR is installed; the no-lasR guard cannot be exercised here.")
  proj <- withr::local_tempdir()
  laz_dir <- file.path(proj, "cache", "layers", "lidar_nuage")
  dir.create(laz_dir, recursive = TRUE)
  file.create(file.path(laz_dir, "fake.laz"))
  # Must return NULL silently, never error, even with a fake tile present.
  expect_null(resolve_project_dem(proj))
  expect_null(resolve_project_chm(proj))
})


# ---- diagnostic helper ---------------------------------------------------

test_that("probe_ign_lidar_tile rejects invalid url argument", {
  skip_if_not_installed("httr2")
  expect_error(probe_ign_lidar_tile(NULL),       "single non-empty URL")
  expect_error(probe_ign_lidar_tile(""),         "single non-empty URL")
  expect_error(probe_ign_lidar_tile(c("a", "b")), "single non-empty URL")
})

test_that("probe_ign_lidar_tile returns a connection-failure result on bad host", {
  skip_if_not_installed("httr2")
  skip_on_cran()
  # RFC 6761 reserved domain that never resolves — safe for offline CI.
  res <- probe_ign_lidar_tile(
    "https://this-host-does-not-exist.invalid./LHD_FXX_0929_6592_MNT.tif",
    timeout = 3
  )
  expect_false(res$ok)
  expect_true(is.na(res$status))
  expect_true(res$category %in% c("dns", "connection", "timeout", "other"))
  expect_true(nzchar(res$message))
})

test_that("probe_ign_lidar_tiles returns an empty data.frame for length-0 input", {
  skip_if_not_installed("httr2")
  out <- probe_ign_lidar_tiles(character(0))
  expect_s3_class(out, "data.frame")
  expect_named(out, c("url", "status", "category", "message", "content_length"))
  expect_equal(nrow(out), 0L)
})
