# RECONFORT S2 acquisition (spec 021 L2b.2). AOI->tiles uses the
# bundled grid (sf, no network). The download/process orchestration
# mocks the env + subprocess (no GEODES, no real S2). terra-free.

# Tiny AOI helper (Lambert-93 buffer, returned WGS84).
ing_aoi <- function(x, y, r = 5000) {
  pt <- sf::st_sfc(sf::st_point(c(x, y)), crs = 2154)
  sf::st_transform(sf::st_sf(geometry = sf::st_buffer(pt, r)), 4326)
}

test_that("bundled S2 MGRS grid loads (metropolitan France)", {
  g <- nemeton:::.reconfort_load_s2_tiles()
  expect_s3_class(g, "sf")
  expect_equal(sf::st_crs(g)$epsg, 4326L)
  expect_true("tile" %in% names(g))
  expect_gt(nrow(g), 150)   # ~188 tiles
})

test_that("reconfort_aoi_tiles resolves a CVL AOI to its S2 tile(s)", {
  # Loiret (dept 45) centroid in Lambert-93.
  tiles <- reconfort_aoi_tiles(ing_aoi(651018, 6757040, r = 4000))
  expect_true(length(tiles) >= 1L)
  expect_true(all(grepl("^T3[01][A-Z]{3}$", tiles)))   # T-prefixed MGRS
})

test_that("reconfort_aoi_tiles: prefix toggle", {
  aoi <- ing_aoi(651018, 6757040, r = 4000)
  withp  <- reconfort_aoi_tiles(aoi, prefix = TRUE)
  nopref <- reconfort_aoi_tiles(aoi, prefix = FALSE)
  expect_true(all(startsWith(withp, "T")))
  expect_false(any(startsWith(nopref, "T")))
  expect_equal(withp, paste0("T", nopref))
})

test_that("reconfort_aoi_tiles: AOI outside the grid -> empty + warning", {
  # Mid-Atlantic, far from France.
  far <- sf::st_sf(geometry = sf::st_buffer(
    sf::st_sfc(sf::st_point(c(-30, 35)), crs = 4326), 0.2))
  expect_warning(t <- reconfort_aoi_tiles(far), "no Sentinel-2 tile")
  expect_length(t, 0L)
})

test_that("reconfort_aoi_tiles rejects non-sf input", {
  expect_error(reconfort_aoi_tiles("nope"), "must be an sf or sfc")
})

test_that(".reconfort_py_literal serialises R values to Python literals", {
  expect_equal(nemeton:::.reconfort_py_literal("31TCJ"), "'31TCJ'")
  expect_equal(nemeton:::.reconfort_py_literal(c("31TCJ", "T31TCJ")),
               "['31TCJ', 'T31TCJ']")
  expect_equal(nemeton:::.reconfort_py_literal(200L), "200")
})

test_that(".reconfort_write_cfg writes a python-eval'able key=value file", {
  f <- withr::local_tempfile(fileext = ".cfg")
  nemeton:::.reconfort_write_cfg(f, list(
    tile = c("31TCJ", "T31TCJ"), start = "2021-01-01", zip_path = "/tmp/z"))
  lines <- readLines(f)
  expect_match(lines[grep("^tile=", lines)], "['31TCJ', 'T31TCJ']", fixed = TRUE)
  expect_match(lines[grep("^start=", lines)], "'2021-01-01'", fixed = TRUE)
  expect_length(lines, 3L)
})

test_that(".reconfort_geodes_config resolves option / explicit path, aborts on miss", {
  f <- withr::local_tempfile(fileext = ".json"); writeLines("{}", f)
  expect_equal(nemeton:::.reconfort_geodes_config(f), normalizePath(f))

  withr::local_options(nemeton.geodes_config = f)
  expect_equal(nemeton:::.reconfort_geodes_config(), normalizePath(f))

  expect_error(
    nemeton:::.reconfort_geodes_config(file.path(tempdir(), "no-geodes-xyz.json")),
    "not found"
  )
})

test_that("reconfort_ingest_s2 orchestrates download+process per tile (mocked)", {
  calls <- character(0)
  testthat::local_mocked_bindings(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    .reconfort_geodes_config = function(path = NULL) "/tmp/geodes.json",
    .reconfort_account_with_download_dir = function(account, download_dir) {
      file.path(download_dir, ".pygeodes-config.json")
    },
    .reconfort_run_py = function(conda_bin, env, script, cfg, workdir, quiet = FALSE) {
      calls[[length(calls) + 1L]] <<- basename(script)
      0L
    }
  )
  root <- withr::local_tempdir()
  res <- reconfort_ingest_s2(
    tiles = c("T31UDP", "T31TCN"),
    date_from = "2021-01-01", date_to = "2022-12-31",
    s2_root = root, quiet = TRUE)

  expect_equal(res$tiles, c("T31UDP", "T31TCN"))
  expect_length(res$extracted, 2L)
  expect_true(all(dir.exists(res$extracted)))
  # 2 scripts (download then process) per tile, in order.
  expect_equal(calls, rep(c("run_geodes_download.py",
                            "run_process_downloaded_images.py"), 2L))
})

test_that("reconfort_ingest_s2 aborts when a subprocess fails (mocked)", {
  testthat::local_mocked_bindings(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    .reconfort_geodes_config = function(path = NULL) "/tmp/geodes.json",
    .reconfort_account_with_download_dir = function(account, download_dir) {
      file.path(download_dir, ".pygeodes-config.json")
    },
    .reconfort_run_py = function(...) 1L   # non-zero exit
  )
  expect_error(
    reconfort_ingest_s2(tiles = "T31UDP", date_from = "2021-01-01",
                        date_to = "2022-12-31",
                        s2_root = withr::local_tempdir(), quiet = TRUE),
    "download failed"
  )
})

test_that(".reconfort_account_with_download_dir overrides download_dir, keeps key", {
  dir  <- withr::local_tempdir()
  acct <- file.path(dir, "pygeodes-config.json")
  jsonlite::write_json(
    list(api_key = "SECRET", download_dir = "~/elsewhere/", checksum_error = TRUE),
    acct, auto_unbox = TRUE)
  zip_dir <- file.path(dir, "zip", "T31UDP")
  dir.create(zip_dir, recursive = TRUE)

  out <- .reconfort_account_with_download_dir(acct, zip_dir)
  expect_true(file.exists(out))
  conf <- jsonlite::read_json(out, simplifyVector = TRUE)
  # download_dir now points at the per-tile zip dir (trailing slash).
  expect_equal(conf$download_dir, paste0(normalizePath(zip_dir), "/"))
  # api_key and other fields survive the copy untouched.
  expect_equal(conf$api_key, "SECRET")
  expect_true(conf$checksum_error)
})

test_that("reconfort_ingest_s2 needs aoi or tiles", {
  expect_error(
    reconfort_ingest_s2(date_from = "2021-01-01", date_to = "2022-12-31",
                        s2_root = tempdir()),
    "aoi.*tiles|tiles.*aoi"
  )
})
