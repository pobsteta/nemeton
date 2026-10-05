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

test_that("reconfort_aoi_tiles repairs a degenerate AOI ring (duplicate vertex)", {
  # Reproduces the RECONFORT dieback crash: a project zone with a degenerate
  # edge (duplicate consecutive vertex) over the Loiret. Valid-looking to
  # GEOS planar ops but aborts s2 ("Loop N is not valid: Edge M is
  # degenerate") during tile resolution against the longlat grid.
  ring <- rbind(
    c(2.40, 47.90), c(2.50, 47.90), c(2.50, 47.90),  # <- duplicate vertex
    c(2.50, 48.00), c(2.40, 48.00), c(2.40, 47.90))
  bad <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(ring)), crs = 4326))
  expect_false(suppressWarnings(all(sf::st_is_valid(bad))))
  tiles <- reconfort_aoi_tiles(bad)          # must not abort
  expect_true(length(tiles) >= 1L)
  expect_true(all(grepl("^T3[01][A-Z]{3}$", tiles)))
})

test_that(".reconfort_cfg_value serialises R values to JSON literals", {
  expect_equal(nemeton:::.reconfort_cfg_value("31TCJ"), "\"31TCJ\"")
  expect_equal(nemeton:::.reconfort_cfg_value(c("31TCJ", "T31TCJ")),
               "[\"31TCJ\",\"T31TCJ\"]")
  expect_equal(nemeton:::.reconfort_cfg_value(200L), "200")
  # Quote, antislash, saut de ligne : échappés, jamais du code Python.
  expect_equal(nemeton:::.reconfort_cfg_value("a'b\\c\nd"),
               "\"a'b\\\\c\\nd\"")
})

test_that(".reconfort_write_cfg writes a JSON-valued key=value file", {
  f <- withr::local_tempfile(fileext = ".cfg")
  nemeton:::.reconfort_write_cfg(f, list(
    tile = c("31TCJ", "T31TCJ"), start = "2021-01-01", zip_path = "/tmp/z"))
  lines <- readLines(f)
  expect_match(lines[grep("^tile=", lines)], "[\"31TCJ\",\"T31TCJ\"]", fixed = TRUE)
  expect_match(lines[grep("^start=", lines)], "\"2021-01-01\"", fixed = TRUE)
  expect_length(lines, 3L)
  expect_error(nemeton:::.reconfort_write_cfg(f, list(`a=b` = 1)), "Invalid")
})

test_that("load_config_variable parses the cfg without evaluating code", {
  py <- Sys.which("python3")
  skip_if(!nzchar(py), "python3 not available")
  utils_dir <- system.file("python", "reconfort", package = "nemeton")
  skip_if(!nzchar(utils_dir), "vendored RECONFORT python not found")
  sentinel <- file.path(withr::local_tempdir(), "pwned")
  # Charge utile qui aurait été exécutée par l'ancien eval() (échappement
  # R limité à `'` : un antislash final cassait la chaîne).
  py_str <- function(s) sprintf("bytes([%s]).decode()",
                                paste(as.integer(charToRaw(s)), collapse = ","))
  payload <- paste0("x\\', __import__(", py_str("os"), ").system(",
                    py_str(paste("touch", sentinel)), ") #'")
  f <- withr::local_tempfile(fileext = ".cfg")
  nemeton:::.reconfort_write_cfg(f, list(
    label = payload, tile = c("31TCJ", "T31TCJ"), n = 3L,
    flag = TRUE, eq = "a=b"))
  # Ligne au format amont (littéral Python) : toujours lisible, sans eval.
  cat("legacy='abc'\n", file = f, append = TRUE)
  script <- withr::local_tempfile(fileext = ".py")
  writeLines(c(
    "import json, sys",
    sprintf("sys.path.insert(0, %s)", jsonlite::toJSON(utils_dir, auto_unbox = TRUE)),
    "from utils.utils import load_config_variable",
    "print(json.dumps(load_config_variable(sys.argv[1])))"
  ), script)
  out <- system2(py, c(shQuote(script), shQuote(f)), stdout = TRUE)
  got <- jsonlite::fromJSON(paste(out, collapse = ""))
  expect_false(file.exists(sentinel))
  expect_identical(got$label, payload)
  expect_identical(got$tile, c("31TCJ", "T31TCJ"))
  expect_identical(got$n, 3L)
  expect_true(got$flag)
  expect_identical(got$eq, "a=b")
  expect_identical(got$legacy, "abc")
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
    # A faithful mock: download drops a .zip in zip_path, process drops
    # a scene folder in out_dir — so the post-conditions are satisfied.
    .reconfort_run_py = function(conda_bin, env, script, cfg, workdir, quiet = FALSE) {
      calls[[length(calls) + 1L]] <<- basename(script)
      kv <- readLines(cfg)
      getv <- function(k) sub(paste0("^", k, '="?([^"]*)"?$'), "\\1",
                              grep(paste0("^", k, "="), kv, value = TRUE))
      if (basename(script) == "run_geodes_download.py") {
        file.create(file.path(getv("zip_path"), "SENTINEL2C_test_T31UDP.zip"))
      } else {
        dir.create(file.path(getv("out_dir"), "SENTINEL2C_test_scene"),
                   recursive = TRUE, showWarnings = FALSE)
      }
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

test_that("reconfort_ingest_s2 aborts when download yields no archive (exit 0)", {
  # The upstream downloader swallows a broken connection and still exits
  # 0; the post-condition must catch the empty zip dir.
  testthat::local_mocked_bindings(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    .reconfort_geodes_config = function(path = NULL) "/tmp/geodes.json",
    .reconfort_account_with_download_dir = function(account, download_dir) {
      file.path(download_dir, ".pygeodes-config.json")
    },
    .reconfort_run_py = function(...) 0L   # "success" but writes nothing
  )
  expect_error(
    reconfort_ingest_s2(tiles = "T31UDP", date_from = "2021-01-01",
                        date_to = "2022-12-31",
                        s2_root = withr::local_tempdir(), quiet = TRUE),
    "no archive"
  )
})

test_that("reconfort_ingest_s2 aborts when unzip yields no scene (exit 0)", {
  testthat::local_mocked_bindings(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    .reconfort_geodes_config = function(path = NULL) "/tmp/geodes.json",
    .reconfort_account_with_download_dir = function(account, download_dir) {
      file.path(download_dir, ".pygeodes-config.json")
    },
    # Download drops a zip (post-cond 1 ok) but process extracts nothing.
    .reconfort_run_py = function(conda_bin, env, script, cfg, workdir, quiet = FALSE) {
      if (basename(script) == "run_geodes_download.py") {
        kv <- readLines(cfg)
        zp <- sub('^zip_path="?([^"]*)"?$', "\\1",
                  grep("^zip_path=", kv, value = TRUE))
        file.create(file.path(zp, "SENTINEL2C_test.zip"))
      }
      0L
    }
  )
  expect_error(
    reconfort_ingest_s2(tiles = "T31UDP", date_from = "2021-01-01",
                        date_to = "2022-12-31",
                        s2_root = withr::local_tempdir(), quiet = TRUE),
    "no scene folder"
  )
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
  # The secret config lives outside the project cache (a tempfile), so
  # the api_key never lands in the downloaded-data tree.
  expect_false(startsWith(normalizePath(out), normalizePath(dir)))
  conf <- jsonlite::read_json(out, simplifyVector = TRUE)
  # download_dir now points at the per-tile zip dir (trailing slash).
  expect_equal(conf$download_dir, paste0(normalizePath(zip_dir), "/"))
  # api_key and other fields survive the copy untouched.
  expect_equal(conf$api_key, "SECRET")
  expect_true(conf$checksum_error)
  unlink(out, force = TRUE)
})

test_that("reconfort_ingest_s2 needs aoi or tiles", {
  expect_error(
    reconfort_ingest_s2(date_from = "2021-01-01", date_to = "2022-12-31",
                        s2_root = tempdir()),
    "aoi.*tiles|tiles.*aoi"
  )
})

test_that("reconfort_ingest_s2 writes delete_zip_after_extract from keep_zips", {
  seen_cfg <- NULL
  mocks <- list(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    .reconfort_geodes_config = function(path = NULL) "/tmp/geodes.json",
    .reconfort_account_with_download_dir = function(account, download_dir) {
      file.path(download_dir, ".pygeodes-config.json")
    },
    .reconfort_run_py = function(conda_bin, env, script, cfg, workdir, quiet = FALSE) {
      kv <- readLines(cfg)
      if (basename(script) == "run_geodes_download.py") {
        zp <- sub('^zip_path="?([^"]*)"?$', "\\1", grep("^zip_path=", kv, value = TRUE))
        file.create(file.path(zp, "SENTINEL2C_test.zip"))
      } else {
        seen_cfg <<- kv
        od <- sub('^out_dir="?([^"]*)"?$', "\\1", grep("^out_dir=", kv, value = TRUE))
        dir.create(file.path(od, "scene"), recursive = TRUE, showWarnings = FALSE)
      }
      0L
    }
  )

  do.call(testthat::local_mocked_bindings, mocks)
  reconfort_ingest_s2(tiles = "T31UDP", date_from = "2021-01-01",
                      date_to = "2022-12-31",
                      s2_root = withr::local_tempdir(), quiet = TRUE)
  expect_true(any(seen_cfg == "delete_zip_after_extract=true"))

  seen_cfg <- NULL
  do.call(testthat::local_mocked_bindings, mocks)
  reconfort_ingest_s2(tiles = "T31UDP", date_from = "2021-01-01",
                      date_to = "2022-12-31", keep_zips = TRUE,
                      s2_root = withr::local_tempdir(), quiet = TRUE)
  expect_true(any(seen_cfg == "delete_zip_after_extract=false"))
})

test_that(".reconfort_crop_scene_to_aoi clips to window, drops SRE, keeps masks+xml", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  dir   <- withr::local_tempdir()
  nm    <- "SENTINEL2A_20250101-104724-247_L2A_T31UFQ_C_V4-0"
  scene <- file.path(dir, nm)
  dir.create(file.path(scene, "MASKS"), recursive = TRUE)
  r <- terra::rast(nrows = 100, ncols = 100, xmin = 900000, xmax = 901000,
                   ymin = 6500000, ymax = 6501000, crs = "EPSG:2154")
  terra::values(r) <- seq_len(terra::ncell(r))
  terra::writeRaster(r, file.path(scene, paste0(nm, "_FRE_B2.tif")))
  terra::writeRaster(r, file.path(scene, paste0(nm, "_SRE_B2.tif")))  # dropped
  terra::writeRaster(r, file.path(scene, "MASKS", paste0(nm, "_CLM_R2.tif")))
  writeLines("<meta/>", file.path(scene, paste0(nm, "_MTD.xml")))

  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 900300, ymin = 6500300, xmax = 900500, ymax = 6500500), crs = 2154))
  win <- .reconfort_aoi_window(aoi, 2154, buffer_m = 0)
  out <- file.path(dir, "out_scene")
  n   <- .reconfort_crop_scene_to_aoi(scene, out, win, 2154)

  expect_equal(n, 2L)  # FRE + CLM clipped; SRE skipped
  expect_true(file.exists(file.path(out, paste0(nm, "_FRE_B2.tif"))))
  expect_false(file.exists(file.path(out, paste0(nm, "_SRE_B2.tif"))))
  expect_true(file.exists(file.path(out, "MASKS", paste0(nm, "_CLM_R2.tif"))))
  expect_true(file.exists(file.path(out, paste0(nm, "_MTD.xml"))))
  cr <- terra::rast(file.path(out, paste0(nm, "_FRE_B2.tif")))
  expect_lt(terra::ncol(cr), 100L)  # clipped smaller than the source tile
})

test_that("reconfort_ingest_s2 AOI streaming: download->extract->crop->delete, idempotent", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if(Sys.which("zip") == "", "needs an external zip program")

  root <- withr::local_tempdir()
  nm   <- "SENTINEL2A_20250101-104724-247_L2A_T31UFQ_C_V4-0"
  bld  <- file.path(root, "build", nm)
  dir.create(file.path(bld, "MASKS"), recursive = TRUE)
  r <- terra::rast(nrows = 80, ncols = 80, xmin = 900000, xmax = 900800,
                   ymin = 6500000, ymax = 6500800, crs = "EPSG:2154")
  terra::values(r) <- seq_len(terra::ncell(r))
  terra::writeRaster(r, file.path(bld, paste0(nm, "_FRE_B2.tif")))
  terra::writeRaster(r, file.path(bld, "MASKS", paste0(nm, "_CLM_R2.tif")))
  writeLines("<meta/>", file.path(bld, paste0(nm, "_MTD.xml")))
  prebuilt <- file.path(root, "prebuilt.zip")
  withr::with_dir(file.path(root, "build"),
                  utils::zip(prebuilt, nm, flags = "-r9Xq"))

  dl_calls <- 0L
  testthat::local_mocked_bindings(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    .reconfort_geodes_config = function(path = NULL) "/tmp/geodes.json",
    .reconfort_account_with_download_dir = function(account, download_dir) {
      file.path(download_dir, ".acct.json")
    },
    .reconfort_list_s2_items = function(conda_bin, env, glue, cfg, manifest_dir,
                                        quiet = FALSE) {
      dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
      j <- file.path(manifest_dir, "item0.json")
      writeLines("{}", j)
      data.frame(idx = 0L, item_id = "URN:ITEM:1", datetime = "2025-01-01",
                 filesize = 10L, json = j, stringsAsFactors = FALSE)
    },
    .reconfort_download_s2_item = function(conda_bin, env, glue, account,
                                           item_json, outfile, quiet = FALSE) {
      dl_calls <<- dl_calls + 1L
      file.copy(prebuilt, outfile, overwrite = TRUE)
      0L
    }
  )

  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 900200, ymin = 6500200, xmax = 900500, ymax = 6500500), crs = 2154))
  s2 <- file.path(root, "s2")
  events <- list()
  res <- reconfort_ingest_s2(aoi = aoi, tiles = "T31UFQ",
                             date_from = "2025-01-01", date_to = "2026-12-31",
                             s2_root = s2, buffer_m = 0, quiet = TRUE,
                             progress_callback = function(p) {
                               events[[length(events) + 1L]] <<- p
                             })

  out_tile <- file.path(s2, "extracted", "T31UFQ")
  expect_true(file.exists(file.path(out_tile, nm, paste0(nm, "_FRE_B2.tif"))))
  expect_false(file.exists(file.path(out_tile, nm, paste0(nm, "_SRE_B2.tif"))))
  # archive freed, scratch removed, marker written
  expect_length(list.files(file.path(s2, "zip", "T31UFQ"), pattern = "\\.zip$"), 0L)
  expect_false(dir.exists(file.path(s2, "scratch", "T31UFQ")))
  expect_length(list.files(file.path(s2, "ingested", "T31UFQ")), 1L)
  expect_equal(dl_calls, 1L)

  # progress events: one listing + per-item steps (download -> done)
  currents <- vapply(events, function(e) e$current %||% "", character(1))
  steps    <- vapply(events, function(e) as.character(e$step %||% ""), character(1))
  expect_true("reconfort:ingest_listed" %in% currents)
  expect_true("reconfort:ingest_item" %in% currents)
  expect_true(all(c("download", "done") %in% steps))
  listed <- events[[which(currents == "reconfort:ingest_listed")[1]]]
  expect_equal(as.integer(listed$total), 1L)

  # idempotence: a second run skips the already-cropped scene (no re-download)
  reconfort_ingest_s2(aoi = aoi, tiles = "T31UFQ",
                      date_from = "2025-01-01", date_to = "2026-12-31",
                      s2_root = s2, buffer_m = 0, quiet = TRUE)
  expect_equal(dl_calls, 1L)
})

# --- Marqueur lié à la fenêtre, recadrage atomique (audit 1.0) --------------

# Monte le décor du streaming (scène MUSCATE zippée + mocks GEODES) et
# renvoie un environnement avec le compteur de téléchargements.
.decor_streaming <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  nm   <- "SENTINEL2A_20250101-104724-247_L2A_T31UFQ_C_V4-0"
  bld  <- file.path(root, "build", nm)
  dir.create(file.path(bld, "MASKS"), recursive = TRUE)
  r <- terra::rast(nrows = 80, ncols = 80, xmin = 900000, xmax = 900800,
                   ymin = 6500000, ymax = 6500800, crs = "EPSG:2154")
  terra::values(r) <- seq_len(terra::ncell(r))
  terra::writeRaster(r, file.path(bld, paste0(nm, "_FRE_B2.tif")))
  terra::writeRaster(r, file.path(bld, "MASKS", paste0(nm, "_CLM_R2.tif")))
  writeLines("<meta/>", file.path(bld, paste0(nm, "_MTD.xml")))
  prebuilt <- file.path(root, "prebuilt.zip")
  withr::with_dir(file.path(root, "build"),
                  utils::zip(prebuilt, nm, flags = "-r9Xq"))
  st <- new.env()
  st$dl <- 0L; st$root <- root; st$nm <- nm; st$s2 <- file.path(root, "s2")
  testthat::local_mocked_bindings(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    .reconfort_geodes_config = function(path = NULL) "/tmp/geodes.json",
    .reconfort_account_with_download_dir = function(account, download_dir) {
      file.path(download_dir, ".acct.json")
    },
    .reconfort_list_s2_items = function(conda_bin, env, glue, cfg, manifest_dir,
                                        quiet = FALSE) {
      dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
      j <- file.path(manifest_dir, "item0.json")
      writeLines("{}", j)
      data.frame(idx = 0L, item_id = "URN:ITEM:1", datetime = "2025-01-01",
                 filesize = 10L, json = j, stringsAsFactors = FALSE)
    },
    .reconfort_download_s2_item = function(conda_bin, env, glue, account,
                                           item_json, outfile, quiet = FALSE) {
      st$dl <- st$dl + 1L
      file.copy(prebuilt, outfile, overwrite = TRUE)
      0L
    },
    .env = env
  )
  st
}

.aoi_carre <- function(x0) sf::st_as_sfc(sf::st_bbox(
  c(xmin = x0, ymin = 6500200, xmax = x0 + 200, ymax = 6500400), crs = 2154))

test_that("AOI streaming: a marker from another AOI window does not count", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if(Sys.which("zip") == "", "needs an external zip program")
  st <- .decor_streaming()
  ingest <- function(aoi) reconfort_ingest_s2(
    aoi = aoi, tiles = "T31UFQ", date_from = "2025-01-01",
    date_to = "2026-12-31", s2_root = st$s2, buffer_m = 0, quiet = TRUE)
  fre <- file.path(st$s2, "extracted", "T31UFQ", st$nm,
                   paste0(st$nm, "_FRE_B2.tif"))

  ingest(.aoi_carre(900000))
  expect_equal(st$dl, 1L)
  expect_equal(terra::xmin(terra::rast(fre)), 900000)

  # Autre fenêtre : la scène est retéléchargée et recadrée sur la nouvelle.
  ingest(.aoi_carre(900400))
  expect_equal(st$dl, 2L)
  expect_equal(terra::xmin(terra::rast(fre)), 900400)
  # Un seul marqueur valide pour la scène.
  expect_length(list.files(file.path(st$s2, "ingested", "T31UFQ")), 1L)

  # Même fenêtre : idempotent.
  ingest(.aoi_carre(900400))
  expect_equal(st$dl, 2L)
})

test_that("AOI streaming: a half-cropped scene never lands in extracted/", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if(Sys.which("zip") == "", "needs an external zip program")
  st <- .decor_streaming()
  testthat::local_mocked_bindings(
    .reconfort_crop_scene_to_aoi = function(scene, out_scene_dir, win,
                                            target_crs = 2154) {
      dir.create(out_scene_dir, recursive = TRUE, showWarnings = FALSE)
      writeLines("partiel", file.path(out_scene_dir, "B2.tif"))
      stop("gdalwarp killed")
    }
  )
  expect_error(reconfort_ingest_s2(
    aoi = .aoi_carre(900000), tiles = "T31UFQ", date_from = "2025-01-01",
    date_to = "2026-12-31", s2_root = st$s2, buffer_m = 0, quiet = TRUE),
    "gdalwarp killed")
  expect_length(list.dirs(file.path(st$s2, "extracted", "T31UFQ"),
                          recursive = FALSE), 0L)
  expect_length(list.files(file.path(st$s2, "ingested", "T31UFQ")), 0L)
})

test_that(".reconfort_window_key depends on the window and the CRS", {
  w <- c(xmin = 0, ymin = 0, xmax = 100, ymax = 100)
  expect_identical(.reconfort_window_key(w, 2154), .reconfort_window_key(w, 2154))
  expect_false(identical(.reconfort_window_key(w, 2154),
                         .reconfort_window_key(w, 3035)))
  expect_false(identical(.reconfort_window_key(w, 2154),
                         .reconfort_window_key(w + 20, 2154)))
  expect_match(.reconfort_window_key(w, 2154), "^[0-9a-f]{12}$")
})

test_that("reconfort_ingest_s2 AOI streaming aborts when the manifest is empty", {
  skip_if_not_installed("sf")
  testthat::local_mocked_bindings(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    .reconfort_geodes_config = function(path = NULL) "/tmp/geodes.json",
    .reconfort_account_with_download_dir = function(account, download_dir) {
      file.path(download_dir, ".acct.json")
    },
    .reconfort_list_s2_items = function(conda_bin, env, glue, cfg, manifest_dir,
                                        quiet = FALSE) {
      data.frame(item_id = character(0), json = character(0))
    }
  )
  aoi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = 900200, ymin = 6500200, xmax = 900500, ymax = 6500500), crs = 2154))
  expect_error(
    reconfort_ingest_s2(aoi = aoi, tiles = "T31UFQ", date_from = "2025-01-01",
                        date_to = "2026-12-31",
                        s2_root = withr::local_tempdir(), quiet = TRUE),
    "No Sentinel-2 item"
  )
})

test_that("reconfort_ingest_s2 aborts before extraction when disk is too small", {
  testthat::local_mocked_bindings(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    .reconfort_geodes_config = function(path = NULL) "/tmp/geodes.json",
    .reconfort_account_with_download_dir = function(account, download_dir) {
      file.path(download_dir, ".pygeodes-config.json")
    },
    # Almost no free space — the guard must fire before the unzip runs.
    .reconfort_free_bytes = function(path) 1,
    .reconfort_run_py = function(conda_bin, env, script, cfg, workdir, quiet = FALSE) {
      if (basename(script) == "run_geodes_download.py") {
        kv <- readLines(cfg)
        zp <- sub('^zip_path="?([^"]*)"?$', "\\1", grep("^zip_path=", kv, value = TRUE))
        # A non-empty archive so the guard's size estimate is > 0.
        writeBin(raw(2048), file.path(zp, "SENTINEL2C_test.zip"))
      } else {
        stop("unzip must not run when the disk guard fires")
      }
      0L
    }
  )
  expect_error(
    reconfort_ingest_s2(tiles = "T31UDP", date_from = "2021-01-01",
                        date_to = "2022-12-31",
                        s2_root = withr::local_tempdir(), quiet = TRUE),
    "free disk space|Not enough free disk"
  )
})

test_that(".reconfort_memory_max honours the option and derives a default", {
  # Le plafond lui-meme est decide par `.memory_ceiling()` (memory-ceiling.R,
  # 50 % de MemTotal depuis le 2026-08-22) ; ici on verifie seulement que
  # l'alias RECONFORT y delegue et respecte les memes interrupteurs.
  withr::local_envvar(NEMETON_MEMORY_MAX = NA)
  withr::local_options(nemeton.reconfort_memory_max = "12G")
  expect_identical(nemeton:::.reconfort_memory_max(), "12G")

  # FALSE / "" desactivent le plafond.
  withr::local_options(nemeton.reconfort_memory_max = FALSE)
  expect_null(nemeton:::.reconfort_memory_max())
  withr::local_options(nemeton.reconfort_memory_max = "")
  expect_null(nemeton:::.reconfort_memory_max())
})

test_that(".reconfort_cap_memory wraps in a capped scope, or passes through", {
  # Plafond + systemd dispo -> scope transitoire.
  out <- nemeton:::.reconfort_cap_memory(
    "conda", c("run", "-n", "e", "python", "s.py"),
    memory_max = "20G", systemd_run = "/usr/bin/systemd-run")
  expect_identical(out$command, "/usr/bin/systemd-run")
  expect_true("--scope" %in% out$args)
  expect_true("--property=MemoryMax=20G" %in% out$args)
  # La commande d'origine suit le `--`, intacte.
  i <- which(out$args == "--")
  expect_identical(out$args[(i + 1L):length(out$args)],
                   c("conda", "run", "-n", "e", "python", "s.py"))

  # Pas de systemd (ou pas de plafond) -> commande inchangee, jamais d'erreur.
  passthrough <- nemeton:::.reconfort_cap_memory(
    "conda", c("run", "-n", "e"), memory_max = "20G", systemd_run = NULL)
  expect_identical(passthrough, list(command = "conda", args = c("run", "-n", "e")))
  passthrough2 <- nemeton:::.reconfort_cap_memory(
    "conda", c("run", "-n", "e"), memory_max = NULL, systemd_run = "/usr/bin/systemd-run")
  expect_identical(passthrough2$command, "conda")
})

test_that(".reconfort_memory_max derives a default from the system RAM", {
  # Sans option : dérivé de /proc/meminfo (Linux) ou NULL ailleurs / si trop peu
  # de RAM. Dans les deux cas, jamais d'erreur et jamais une valeur absurde.
  withr::local_envvar(NEMETON_MEMORY_MAX = NA)
  withr::local_options(nemeton.reconfort_memory_max = NULL,
                       nemeton.memory_max = NULL)
  val <- nemeton:::.reconfort_memory_max()
  if (!is.null(val)) {
    expect_match(val, "^[0-9]+G$")
    expect_gte(as.integer(sub("G$", "", val)), 4L)
  } else {
    expect_null(val)
  }
})

test_that(".reconfort_systemd_run probes once and caches its verdict", {
  # Renvoie un chemin utilisable, ou NULL (non-Linux, conteneur sans bus
  # utilisateur, CI) — auquel cas le plafond est simplement sauté.
  rm(list = ls(nemeton:::.reconfort_cache), envir = nemeton:::.reconfort_cache)
  first <- nemeton:::.reconfort_systemd_run()
  expect_true(is.null(first) || (is.character(first) && nzchar(first)))
  # Verdict mémorisé -> le second appel ne re-sonde pas.
  expect_true(exists("systemd_run", envir = nemeton:::.reconfort_cache))
  expect_identical(nemeton:::.reconfort_systemd_run(), first)
})

test_that(".reconfort_run_py runs the command produced by .reconfort_cap_memory", {
  skip_on_os("windows")
  wd <- withr::local_tempdir()
  seen <- NULL
  testthat::local_mocked_bindings(
    .reconfort_cap_memory = function(command, args, ...) {
      seen <<- list(command = command, args = args)
      list(command = "true", args = character())   # inoffensif, exit 0
    }
  )
  st <- nemeton:::.reconfort_run_py("conda", "envx", "s.py", "cfg.cfg", wd, quiet = TRUE)
  expect_identical(as.integer(st), 0L)
  # La commande conda est bien celle soumise au plafond.
  expect_identical(seen$command, "conda")
  expect_true(all(c("run", "-n", "envx", "python", "s.py") %in% seen$args))
})

test_that("GEODES scripts force TLS verification and the warning is not silenced", {
  # Plus de filtre masquant InsecureRequestWarning côté R.
  expect_false(grepl("Unverified HTTPS", .RECONFORT_PYWARN, fixed = TRUE))
  glue <- .reconfort_glue_dir()
  # Chaque script GEODES appelle enforce_tls_verification() AVANT Geodes().
  for (s in c("list_s2_items.py", "download_s2_item.py",
              "run_geodes_download.py")) {
    src <- readLines(file.path(glue, s))
    i_tls <- grep("enforce_tls_verification(conf)", src, fixed = TRUE)
    i_geo <- grep("Geodes(conf=conf)", src, fixed = TRUE)
    expect_length(i_tls, 1L)
    expect_true(length(i_geo) == 1L && i_tls < i_geo, info = s)
  }
})

test_that("enforce_tls_verification points pygeodes to a CA bundle", {
  py <- Sys.which("python3")
  skip_if(!nzchar(py), "python3 not available")
  # Le python3 du PATH peut être un interpréteur provisionné par reticulate,
  # sans certifi ni magasin système : le helper retombe alors (à raison) sur
  # « pas de bundle ». Ce test vérifie le cas où un bundle existe.
  a_bundle <- suppressWarnings(system2(py, c("-c", shQuote(paste(
    "import ssl, os, importlib.util;",
    "c = importlib.util.find_spec('certifi') is not None;",
    "p = ssl.get_default_verify_paths();",
    "print(c or any(os.path.exists(x or '') for x in (p.cafile, p.openssl_cafile)))"))),
    stdout = TRUE))
  skip_if(!identical(a_bundle, "True"), "no CA bundle visible to this python3")
  glue <- normalizePath(.reconfort_glue_dir())
  # Faux paquet pygeodes : reproduit la constante lue par RequestMaker.
  stub <- withr::local_tempdir()
  dir.create(file.path(stub, "pygeodes", "utils"), recursive = TRUE)
  file.create(file.path(stub, "pygeodes", "__init__.py"),
              file.path(stub, "pygeodes", "utils", "__init__.py"))
  writeLines('SSL_CERT_PATH = ""',
             file.path(stub, "pygeodes", "utils", "request.py"))
  script <- withr::local_tempfile(fileext = ".py")
  writeLines(c(
    "import os, sys",
    sprintf("sys.path[:0] = [%s, %s]",
            jsonlite::toJSON(stub, auto_unbox = TRUE),
            jsonlite::toJSON(glue, auto_unbox = TRUE)),
    "from utils.tls import enforce_tls_verification",
    "import pygeodes.utils.request as rq",
    "class C: use_async_requests = True",
    "c = C()",
    "ca = enforce_tls_verification(c)",
    "print(ca is not None and os.path.isfile(rq.SSL_CERT_PATH) and rq.SSL_CERT_PATH == ca)",
    "print(c.use_async_requests)"
  ), script)
  out <- system2(py, shQuote(script), stdout = TRUE)
  expect_identical(out, c("True", "False"))
})

test_that("conda run streams the python output (--no-capture-output)", {
  # Sans --no-capture-output, `conda run` retient stdout/stderr jusqu'à la
  # fin du processus : si le scope systemd est tué (OOM), tout est perdu.
  skip_on_os("windows")
  wd <- withr::local_tempdir()
  seen <- NULL
  testthat::local_mocked_bindings(
    .reconfort_cap_memory = function(command, args, ...) {
      seen <<- list(command = command, args = args)
      list(command = "true", args = character())
    }
  )
  nemeton:::.reconfort_run_py("conda", "envx", "s.py", "cfg.cfg", wd, quiet = TRUE)
  expect_identical(seen$args[1:2], c("run", "--no-capture-output"))

  # Téléchargement d'une archive : faux binaire conda qui consigne ses
  # arguments.
  log <- file.path(wd, "args.txt")
  fake <- file.path(wd, "fake_conda.sh")
  writeLines(c("#!/bin/sh", sprintf("printf '%%s\\n' \"$@\" > '%s'", log)), fake)
  Sys.chmod(fake, "0755")
  nemeton:::.reconfort_download_s2_item(fake, "envx", wd, "acct", "item.json",
                                        file.path(wd, "out.zip"), quiet = TRUE)
  args <- readLines(log)
  expect_identical(args[1:2], c("run", "--no-capture-output"))
})

test_that("les chemins passes a python sont absolus, et aucun __pycache__ n'est ecrit (audit 1.0)", {
  # Le sous-processus tourne sous with_dir(workdir) : un chemin relatif au
  # repertoire courant de R y pointait ailleurs. Et python, lance depuis le
  # dossier installe du paquet, y ecrivait ses __pycache__.
  skip_on_os("windows")
  base <- normalizePath(withr::local_tempdir())
  wd <- file.path(base, "work"); dir.create(wd)
  log <- file.path(base, "log.txt")
  fake <- file.path(base, "fake_conda.sh")
  writeLines(c("#!/bin/sh",
               sprintf("echo \"bytecode=$PYTHONDONTWRITEBYTECODE\" > '%s'", log),
               sprintf("printf '%%s\\n' \"$@\" >> '%s'", log)), fake)
  Sys.chmod(fake, "0755")
  testthat::local_mocked_bindings(.reconfort_memory_max = function() NULL)

  withr::with_dir(base, {
    file.create("rel.cfg")
    nemeton:::.reconfort_run_py(fake, "envx", "s.py", "rel.cfg", wd, quiet = TRUE)
  })
  out <- readLines(log)
  expect_identical(out[1], "bytecode=1")
  cfg_arg <- out[which(out == "-config_file") + 1L]
  expect_identical(cfg_arg, file.path(base, "rel.cfg"))

  withr::with_dir(base, {
    file.create(c("acct.json", "item.json"))
    nemeton:::.reconfort_download_s2_item(fake, "envx", wd, "acct.json",
                                          "item.json", "out.zip", quiet = TRUE)
  })
  out <- readLines(log)
  expect_identical(out[1], "bytecode=1")
  for (flag in c("-account", "-item_json", "-outfile")) {
    p <- out[which(out == flag) + 1L]
    expect_identical(dirname(p), base, info = flag)
  }
})
