# test-cov80-batch16.R
# Coverage boost for R/service_compute.R — download functions & compute orchestration
# Target: download_raster_source, download_vector_source, mosaic_lidar_tiles,
#         download_lidar_tile, query_lidar_wfs, download_ign_dem, download_ign_bdtopo,
#         download_ign_bdforet, download_inpn_wfs, download_layers_for_parcels,
#         start_computation, compute_all_indicators resume, normalize_indicator,
#         save_progress_state, read_progress_state, cancel_computation, is_cancelled,
#         clear_cancel, init_compute_state, create_synthetic_ndvi

# ==============================================================================
# download_raster_source()
# ==============================================================================

test_that("download_raster_source: returns cached raster when file exists", {
  withr::with_tempdir({
    cache_dir <- getwd()
    r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 1,
                     ymin = 0, ymax = 1, crs = "EPSG:4326")
    terra::values(r) <- runif(100)
    terra::writeRaster(r, file.path(cache_dir, "ndvi.tif"))

    result <- nemeton:::download_raster_source(
      "ndvi", list(source = "ign_irc"), c(0, 0, 1, 1), cache_dir
    )
    expect_s4_class(result, "SpatRaster")
    expect_equal(terra::nrow(result), 10)
  })
})

test_that("download_raster_source: unknown source type returns NULL with warning", {
  withr::with_tempdir({
    cache_dir <- getwd()
    expect_warning(
      result <- nemeton:::download_raster_source(
        "mystery", list(source = "unknown_provider"), c(0, 0, 1, 1), cache_dir
      ),
      "Unknown raster source"
    )
    expect_null(result)
  })
})

test_that("download_raster_source: dispatches ign_irc to download_ign_irc_ndvi", {
  withr::with_tempdir({
    cache_dir <- getwd()
    mock_called <- FALSE

    local_mocked_bindings(
      download_ign_irc_ndvi = function(bbox, cache_file) {
        mock_called <<- TRUE
        r <- terra::rast(nrows = 5, ncols = 5, xmin = 0, xmax = 1,
                         ymin = 0, ymax = 1, crs = "EPSG:4326")
        terra::values(r) <- runif(25)
        r
      },
      .package = "nemeton"
    )

    result <- nemeton:::download_raster_source(
      "ndvi", list(source = "ign_irc"), c(0, 0, 1, 1), cache_dir
    )
    expect_true(mock_called)
  })
})

test_that("download_raster_source: dispatches ign_bd_alti to download_ign_dem", {
  withr::with_tempdir({
    cache_dir <- getwd()
    mock_called <- FALSE

    local_mocked_bindings(
      download_ign_dem = function(bbox, cache_file) {
        mock_called <<- TRUE
        NULL
      },
      .package = "nemeton"
    )

    result <- nemeton:::download_raster_source(
      "dem", list(source = "ign_bd_alti"), c(0, 0, 1, 1), cache_dir
    )
    expect_true(mock_called)
    expect_null(result)
  })
})

test_that("download_raster_source: dispatches oso to download_oso", {
  withr::with_tempdir({
    cache_dir <- getwd()
    mock_called <- FALSE

    local_mocked_bindings(
      download_oso = function(bbox, cache_file, progress_callback = NULL) {
        mock_called <<- TRUE
        NULL
      },
      .package = "nemeton"
    )

    result <- nemeton:::download_raster_source(
      "forest_cover", list(source = "oso"), c(0, 0, 1, 1), cache_dir
    )
    expect_true(mock_called)
    expect_null(result)
  })
})

test_that("download_raster_source: dispatches ign_lidar_hd to download_ign_lidar_hd", {
  withr::with_tempdir({
    cache_dir <- getwd()
    mock_called <- FALSE

    local_mocked_bindings(
      download_ign_lidar_hd = function(bbox, cache_dir, product, progress_callback) {
        mock_called <<- TRUE
        NULL
      },
      .package = "nemeton"
    )

    result <- nemeton:::download_raster_source(
      "lidar_mnh",
      list(source = "ign_lidar_hd", product = "mnh"),
      c(0, 0, 1, 1), cache_dir
    )
    expect_true(mock_called)
    expect_null(result)
  })
})

# ==============================================================================
# download_vector_source()
# ==============================================================================

test_that("download_vector_source: returns cached vector when file exists", {
  withr::with_tempdir({
    cache_dir <- getwd()
    pts <- sf::st_sf(
      id = 1:2,
      geometry = sf::st_sfc(
        sf::st_point(c(0.5, 0.5)),
        sf::st_point(c(0.6, 0.6)),
        crs = 4326
      )
    )
    sf::st_write(pts, file.path(cache_dir, "roads.gpkg"), quiet = TRUE)

    result <- nemeton:::download_vector_source(
      "roads", list(source = "ign_bd_topo"), c(0, 0, 1, 1), cache_dir
    )
    expect_s3_class(result, "sf")
    expect_equal(nrow(result), 2)
  })
})

test_that("download_vector_source: unknown source type returns NULL with warning", {
  withr::with_tempdir({
    cache_dir <- getwd()
    expect_warning(
      result <- nemeton:::download_vector_source(
        "mystery", list(source = "unknown_source"), c(0, 0, 1, 1), cache_dir
      ),
      "Unknown vector source"
    )
    expect_null(result)
  })
})

test_that("download_vector_source: dispatches inpn_wfs to download_inpn_wfs", {
  withr::with_tempdir({
    cache_dir <- getwd()
    mock_called <- FALSE

    local_mocked_bindings(
      download_inpn_wfs = function(source_name, bbox, cache_file) {
        mock_called <<- TRUE
        NULL
      },
      .package = "nemeton"
    )

    result <- nemeton:::download_vector_source(
      "protected_areas", list(source = "inpn_wfs"), c(0, 0, 1, 1), cache_dir
    )
    expect_true(mock_called)
    expect_null(result)
  })
})

test_that("download_vector_source: dispatches ign_bd_topo to download_ign_bdtopo", {
  withr::with_tempdir({
    cache_dir <- getwd()
    mock_called <- FALSE

    local_mocked_bindings(
      download_ign_bdtopo = function(source_name, bbox, cache_file) {
        mock_called <<- TRUE
        NULL
      },
      .package = "nemeton"
    )

    result <- nemeton:::download_vector_source(
      "water_network", list(source = "ign_bd_topo"), c(0, 0, 1, 1), cache_dir
    )
    expect_true(mock_called)
    expect_null(result)
  })
})

test_that("download_vector_source: dispatches ign_bdforet to download_ign_bdforet", {
  withr::with_tempdir({
    cache_dir <- getwd()
    mock_called <- FALSE

    local_mocked_bindings(
      download_ign_bdforet = function(bbox, cache_file) {
        mock_called <<- TRUE
        NULL
      },
      .package = "nemeton"
    )

    result <- nemeton:::download_vector_source(
      "bdforet", list(source = "ign_bdforet"), c(0, 0, 1, 1), cache_dir
    )
    expect_true(mock_called)
    expect_null(result)
  })
})

# ==============================================================================
# mosaic_lidar_tiles()
# ==============================================================================

test_that("mosaic_lidar_tiles: single tile copies to output", {
  withr::with_tempdir({
    r1 <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 1,
                      ymin = 0, ymax = 1, crs = "EPSG:2154")
    terra::values(r1) <- runif(100)
    f1 <- file.path(getwd(), "tile1.tif")
    terra::writeRaster(r1, f1)

    out <- file.path(getwd(), "mosaic.tif")
    result <- nemeton:::mosaic_lidar_tiles(f1, out)
    expect_s4_class(result, "SpatRaster")
    expect_true(file.exists(out))
  })
})

test_that("mosaic_lidar_tiles: two tiles creates mosaic", {
  withr::with_tempdir({
    r1 <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 1,
                      ymin = 0, ymax = 1, crs = "EPSG:2154")
    terra::values(r1) <- runif(100)
    f1 <- file.path(getwd(), "tile1.tif")
    terra::writeRaster(r1, f1)

    r2 <- terra::rast(nrows = 10, ncols = 10, xmin = 1, xmax = 2,
                      ymin = 0, ymax = 1, crs = "EPSG:2154")
    terra::values(r2) <- runif(100)
    f2 <- file.path(getwd(), "tile2.tif")
    terra::writeRaster(r2, f2)

    out <- file.path(getwd(), "mosaic.tif")
    result <- nemeton:::mosaic_lidar_tiles(c(f1, f2), out)
    expect_s4_class(result, "SpatRaster")
    expect_true(file.exists(out))
    # Mosaic should cover extent of both tiles
    ext <- terra::ext(result)
    expect_equal(as.numeric(ext$xmin), 0)
    expect_equal(as.numeric(ext$xmax), 2)
  })
})

test_that("mosaic_lidar_tiles: handles invalid tile file gracefully", {
  withr::with_tempdir({
    # Create one valid tile and one invalid file
    r1 <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 1,
                      ymin = 0, ymax = 1, crs = "EPSG:2154")
    terra::values(r1) <- runif(100)
    f1 <- file.path(getwd(), "tile1.tif")
    terra::writeRaster(r1, f1)

    f2 <- file.path(getwd(), "tile2.tif")
    writeLines("not a raster", f2)

    out <- file.path(getwd(), "mosaic.tif")
    # Should still succeed by filtering out the bad tile
    result <- suppressWarnings(
      nemeton:::mosaic_lidar_tiles(c(f1, f2), out)
    )
    # Should return something (the valid tile)
    expect_true(!is.null(result))
  })
})

test_that("mosaic_lidar_tiles: all invalid tiles returns NULL or fallback", {
  withr::with_tempdir({
    f1 <- file.path(getwd(), "bad1.tif")
    f2 <- file.path(getwd(), "bad2.tif")
    writeLines("not a raster", f1)
    writeLines("not a raster", f2)

    out <- file.path(getwd(), "mosaic.tif")
    result <- suppressWarnings(
      nemeton:::mosaic_lidar_tiles(c(f1, f2), out)
    )
    # All tiles invalid: should return NULL (or fallback attempt)
    # The function tries rast_list filtering, gets empty list, returns NULL
    # But outer tryCatch catches the error and tries first tile -> also fails -> NULL
    expect_null(result)
  })
})

# ==============================================================================
# download_lidar_tile()
# ==============================================================================

test_that("download_lidar_tile: returns NULL after all retries fail (mocked httr2)", {
  local_mocked_bindings(
    req_perform = function(...) stop("Connection failed"),
    .package = "httr2"
  )

  dest <- tempfile(fileext = ".tif")
  on.exit(unlink(dest), add = TRUE)

  result <- nemeton:::download_lidar_tile("http://fake.url/tile.tif", dest)
  expect_null(result)
})

test_that("download_lidar_tile: returns dest_file on success (mocked httr2)", {
  withr::with_tempdir({
    dest <- file.path(getwd(), "tile_ok.tif")

    # Create a fake response object
    mock_resp <- structure(list(), class = "httr2_response")

    local_mocked_bindings(
      request = function(...) structure(list(), class = "httr2_request"),
      req_timeout = function(req, ...) req,
      req_error = function(req, ...) req,
      req_perform = function(req, path = NULL, ...) {
        # Write >100 bytes to destination
        writeBin(raw(200), path)
        mock_resp
      },
      resp_status = function(resp) 200L,
      .package = "httr2"
    )

    result <- nemeton:::download_lidar_tile("http://fake.url/tile.tif", dest)
    expect_equal(result, dest)
    expect_true(file.exists(dest))
  })
})

test_that("download_lidar_tile: retries on non-200 status then fails", {
  withr::with_tempdir({
    dest <- file.path(getwd(), "tile_retry.tif")
    call_count <- 0L

    mock_resp <- structure(list(), class = "httr2_response")

    local_mocked_bindings(
      request = function(...) structure(list(), class = "httr2_request"),
      req_timeout = function(req, ...) req,
      req_error = function(req, ...) req,
      req_perform = function(req, path = NULL, ...) {
        call_count <<- call_count + 1L
        if (!is.null(path)) writeBin(raw(50), path)  # < 100 bytes
        mock_resp
      },
      resp_status = function(resp) 500L,
      .package = "httr2"
    )

    result <- nemeton:::download_lidar_tile("http://fake.url/tile.tif", dest)
    expect_null(result)
    expect_equal(call_count, 3L)  # max_retries = 3
  })
})

# ==============================================================================
# query_lidar_wfs()
# ==============================================================================

test_that("query_lidar_wfs: returns sf on valid GeoJSON response", {
  # Build a valid GeoJSON string
  geojson <- '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"id":1,"url":"http://x.com/t.tif"},"geometry":{"type":"Point","coordinates":[2.5,46.5]}}]}'

  mock_resp <- structure(list(), class = "httr2_response")

  local_mocked_bindings(
    request = function(...) structure(list(), class = "httr2_request"),
    req_timeout = function(req, ...) req,
    req_error = function(req, ...) req,
    req_perform = function(req, ...) mock_resp,
    resp_status = function(resp) 200L,
    resp_body_string = function(resp) geojson,
    .package = "httr2"
  )

  result <- nemeton:::query_lidar_wfs("IGNF_MNH-LIDAR-HD:dalle", c(2, 46, 3, 47))
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 1)
})

test_that("query_lidar_wfs: returns NULL on non-200 status", {
  mock_resp <- structure(list(), class = "httr2_response")

  local_mocked_bindings(
    request = function(...) structure(list(), class = "httr2_request"),
    req_timeout = function(req, ...) req,
    req_error = function(req, ...) req,
    req_perform = function(req, ...) mock_resp,
    resp_status = function(resp) 500L,
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::query_lidar_wfs("IGNF_MNH-LIDAR-HD:dalle", c(2, 46, 3, 47)),
    "status"
  )
  expect_null(result)
})

test_that("query_lidar_wfs: returns NULL on empty response body", {
  mock_resp <- structure(list(), class = "httr2_response")

  local_mocked_bindings(
    request = function(...) structure(list(), class = "httr2_request"),
    req_timeout = function(req, ...) req,
    req_error = function(req, ...) req,
    req_perform = function(req, ...) mock_resp,
    resp_status = function(resp) 200L,
    resp_body_string = function(resp) "{}",
    .package = "httr2"
  )

  result <- nemeton:::query_lidar_wfs("IGNF_MNH-LIDAR-HD:dalle", c(2, 46, 3, 47))
  expect_null(result)
})

test_that("query_lidar_wfs: returns NULL on network error", {
  local_mocked_bindings(
    request = function(...) structure(list(), class = "httr2_request"),
    req_timeout = function(req, ...) req,
    req_error = function(req, ...) req,
    req_perform = function(req, ...) stop("Network error"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::query_lidar_wfs("IGNF_MNH-LIDAR-HD:dalle", c(2, 46, 3, 47)),
    "failed"
  )
  expect_null(result)
})

# ==============================================================================
# download_ign_dem()
# ==============================================================================

test_that("download_ign_dem: returns NULL on non-200 WMS response", {
  withr::with_tempdir({
    mock_resp <- structure(list(), class = "httr2_response")

    local_mocked_bindings(
      request = function(...) structure(list(), class = "httr2_request"),
      req_timeout = function(req, ...) req,
      req_error = function(req, ...) req,
      req_perform = function(req, ...) mock_resp,
      resp_status = function(resp) 500L,
      .package = "httr2"
    )

    cache_file <- file.path(getwd(), "dem_test.tif")
    expect_warning(
      result <- nemeton:::download_ign_dem(c(2, 46, 2.1, 46.1), cache_file),
      "status"
    )
    expect_null(result)
  })
})

test_that("download_ign_dem: returns NULL on network error", {
  withr::with_tempdir({
    local_mocked_bindings(
      request = function(...) structure(list(), class = "httr2_request"),
      req_timeout = function(req, ...) req,
      req_error = function(req, ...) req,
      req_perform = function(req, ...) stop("Timeout"),
      .package = "httr2"
    )

    cache_file <- file.path(getwd(), "dem_err.tif")
    expect_warning(
      result <- nemeton:::download_ign_dem(c(2, 46, 2.1, 46.1), cache_file),
      "Failed to download"
    )
    expect_null(result)
  })
})

test_that("download_ign_dem: handles bbox as sf bbox object", {
  withr::with_tempdir({
    mock_resp <- structure(list(), class = "httr2_response")

    local_mocked_bindings(
      request = function(...) structure(list(), class = "httr2_request"),
      req_timeout = function(req, ...) req,
      req_error = function(req, ...) req,
      req_perform = function(req, ...) mock_resp,
      resp_status = function(resp) 500L,
      .package = "httr2"
    )

    bbox_obj <- sf::st_bbox(c(xmin = 2, ymin = 46, xmax = 2.1, ymax = 46.1),
                            crs = sf::st_crs(4326))
    cache_file <- file.path(getwd(), "dem_bbox.tif")
    suppressWarnings(
      result <- nemeton:::download_ign_dem(bbox_obj, cache_file)
    )
    expect_null(result)
  })
})

test_that("download_ign_dem: returns NULL on small/empty downloaded file", {
  withr::with_tempdir({
    mock_resp <- structure(list(), class = "httr2_response")

    local_mocked_bindings(
      request = function(...) structure(list(), class = "httr2_request"),
      req_timeout = function(req, ...) req,
      req_error = function(req, ...) req,
      req_perform = function(req, path = NULL, ...) {
        # Write a tiny file (< 1000 bytes)
        if (!is.null(path)) writeBin(raw(10), path)
        mock_resp
      },
      resp_status = function(resp) 200L,
      .package = "httr2"
    )

    cache_file <- file.path(getwd(), "dem_small.tif")
    expect_warning(
      result <- nemeton:::download_ign_dem(c(2, 46, 2.1, 46.1), cache_file),
      "Invalid|empty"
    )
    expect_null(result)
  })
})

# ==============================================================================
# download_ign_bdtopo()
# ==============================================================================

test_that("download_ign_bdtopo: returns NULL for unknown layer name", {
  expect_warning(
    result <- nemeton:::download_ign_bdtopo(
      "nonexistent_layer", c(2, 46, 2.1, 46.1), tempfile()
    ),
    "Unknown BD TOPO layer"
  )
  expect_null(result)
})

test_that("download_ign_bdtopo: returns NULL on happign WFS error", {
  # Mock happign::get_wfs to fail
  local_mocked_bindings(
    get_wfs = function(...) stop("Connection refused"),
    .package = "happign"
  )

  expect_warning(
    result <- nemeton:::download_ign_bdtopo(
      "roads", c(2, 46, 2.1, 46.1), tempfile()
    ),
    "Failed to download"
  )
  expect_null(result)
})

test_that("download_ign_bdtopo: handles bbox as sf bbox object", {
  # Mock happign::get_wfs to return NULL
  local_mocked_bindings(
    get_wfs = function(...) NULL,
    .package = "happign"
  )

  bbox_obj <- sf::st_bbox(c(xmin = 2, ymin = 46, xmax = 2.1, ymax = 46.1),
                          crs = sf::st_crs(4326))
  result <- nemeton:::download_ign_bdtopo("roads", bbox_obj, tempfile())
  expect_null(result)
})

# ==============================================================================
# download_ign_bdforet()
# ==============================================================================

test_that("download_ign_bdforet: returns NULL on non-200 response", {
  mock_resp <- structure(list(), class = "httr2_response")

  local_mocked_bindings(
    request = function(...) structure(list(), class = "httr2_request"),
    req_timeout = function(req, ...) req,
    req_error = function(req, ...) req,
    req_perform = function(req, ...) mock_resp,
    resp_status = function(resp) 500L,
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::download_ign_bdforet(c(2, 46, 2.1, 46.1), tempfile()),
    "status"
  )
  expect_null(result)
})

test_that("download_ign_bdforet: returns NULL on short response (< 50 chars)", {
  mock_resp <- structure(list(), class = "httr2_response")

  local_mocked_bindings(
    request = function(...) structure(list(), class = "httr2_request"),
    req_timeout = function(req, ...) req,
    req_error = function(req, ...) req,
    req_perform = function(req, ...) mock_resp,
    resp_status = function(resp) 200L,
    resp_body_string = function(resp) "{}",
    .package = "httr2"
  )

  result <- nemeton:::download_ign_bdforet(c(2, 46, 2.1, 46.1), tempfile())
  expect_null(result)
})

test_that("download_ign_bdforet: returns NULL on network error", {
  local_mocked_bindings(
    request = function(...) structure(list(), class = "httr2_request"),
    req_timeout = function(req, ...) req,
    req_error = function(req, ...) req,
    req_perform = function(req, ...) stop("Connection refused"),
    .package = "httr2"
  )

  expect_warning(
    result <- nemeton:::download_ign_bdforet(c(2, 46, 2.1, 46.1), tempfile()),
    "Failed to download"
  )
  expect_null(result)
})

test_that("download_ign_bdforet: handles bbox as sf bbox object", {
  mock_resp <- structure(list(), class = "httr2_response")

  local_mocked_bindings(
    request = function(...) structure(list(), class = "httr2_request"),
    req_timeout = function(req, ...) req,
    req_error = function(req, ...) req,
    req_perform = function(req, ...) mock_resp,
    resp_status = function(resp) 500L,
    .package = "httr2"
  )

  bbox_obj <- sf::st_bbox(c(xmin = 2, ymin = 46, xmax = 2.1, ymax = 46.1),
                          crs = sf::st_crs(4326))
  suppressWarnings(
    result <- nemeton:::download_ign_bdforet(bbox_obj, tempfile())
  )
  expect_null(result)
})

# ==============================================================================
# download_inpn_wfs()
# ==============================================================================

test_that("download_inpn_wfs: returns NULL for unknown layer name", {
  local_mocked_bindings(
    get_layers_metadata = function(...) {
      data.frame(Name = "patrinat_layer1", stringsAsFactors = FALSE)
    },
    .package = "happign"
  )

  expect_warning(
    result <- nemeton:::download_inpn_wfs(
      "totally_unknown", c(2, 46, 2.1, 46.1), tempfile()
    ),
    "Unknown INPN layer"
  )
  expect_null(result)
})

test_that("download_inpn_wfs: returns NULL when WFS catalog returns NULL", {
  local_mocked_bindings(
    get_layers_metadata = function(...) NULL,
    .package = "happign"
  )

  result <- nemeton:::download_inpn_wfs(
    "protected_areas", c(2, 46, 2.1, 46.1), tempfile()
  )
  expect_null(result)
})

test_that("download_inpn_wfs: returns NULL when WFS catalog query fails", {
  local_mocked_bindings(
    get_layers_metadata = function(...) stop("Cannot reach WFS"),
    .package = "happign"
  )

  expect_warning(
    result <- nemeton:::download_inpn_wfs(
      "protected_areas", c(2, 46, 2.1, 46.1), tempfile()
    ),
    "Failed to get WFS"
  )
  expect_null(result)
})

test_that("download_inpn_wfs: returns NULL when no patrinat layers found", {
  local_mocked_bindings(
    get_layers_metadata = function(...) {
      data.frame(Name = c("some_other_layer"), stringsAsFactors = FALSE)
    },
    .package = "happign"
  )

  result <- nemeton:::download_inpn_wfs(
    "protected_areas", c(2, 46, 2.1, 46.1), tempfile()
  )
  expect_null(result)
})

# ==============================================================================
# download_layers_for_parcels()
# ==============================================================================

test_that("download_layers_for_parcels: returns nemeton_layers with mocked downloads", {
  units <- create_test_units(n_features = 3)

  withr::with_tempdir({
    project_path <- file.path(getwd(), "test_project")
    dir.create(project_path, recursive = TRUE)

    local_mocked_bindings(
      download_raster_source = function(...) NULL,
      download_vector_source = function(...) NULL,
      download_ign_lidar_hd = function(...) NULL,
      get_global_cache_dir = function() file.path(getwd(), ".cache"),
      .package = "nemeton"
    )

    result <- nemeton:::download_layers_for_parcels(
      parcels = units,
      project_path = project_path
    )

    expect_s3_class(result, "nemeton_layers")
    expect_type(result$rasters, "list")
    expect_type(result$vectors, "list")
    expect_true(!is.null(result$bbox))
  })
})

test_that("download_layers_for_parcels: calls progress_callback", {
  units <- create_test_units(n_features = 2)

  withr::with_tempdir({
    project_path <- file.path(getwd(), "test_project")
    dir.create(project_path, recursive = TRUE)

    local_mocked_bindings(
      download_raster_source = function(...) NULL,
      download_vector_source = function(...) NULL,
      download_ign_lidar_hd = function(...) NULL,
      get_global_cache_dir = function() file.path(getwd(), ".cache"),
      .package = "nemeton"
    )

    callback_calls <- list()
    callback_fn <- function(info) {
      callback_calls[[length(callback_calls) + 1]] <<- info
    }

    result <- nemeton:::download_layers_for_parcels(
      parcels = units,
      project_path = project_path,
      progress_callback = callback_fn
    )

    # Should have been called at least for each raster + vector source
    expect_true(length(callback_calls) > 5)
  })
})

test_that("download_layers_for_parcels: includes download_warnings in result", {
  units <- create_test_units(n_features = 2)

  withr::with_tempdir({
    project_path <- file.path(getwd(), "test_project")
    dir.create(project_path, recursive = TRUE)

    # All downloads return NULL to trigger warning collection
    local_mocked_bindings(
      download_raster_source = function(...) NULL,
      download_vector_source = function(...) NULL,
      download_ign_lidar_hd = function(...) NULL,
      get_global_cache_dir = function() file.path(getwd(), ".cache"),
      .package = "nemeton"
    )

    result <- nemeton:::download_layers_for_parcels(
      parcels = units,
      project_path = project_path
    )

    # Warnings should be accumulated for NULL vector sources
    expect_type(result$warnings, "list")
  })
})

# ==============================================================================
# start_computation()
# ==============================================================================

test_that("start_computation: errors when project not found", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )

  expect_error(
    nemeton:::start_computation("nonexistent_project"),
    "Project not found"
  )
})

test_that("start_computation: errors when project dir does not exist", {
  local_mocked_bindings(
    get_project_path = function(id) "/nonexistent/path/to/project",
    .package = "nemeton"
  )

  expect_error(
    nemeton:::start_computation("missing_dir"),
    "Project not found"
  )
})

test_that("start_computation: errors when no parcels file found", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      get_computation_progress = function(id) list(
        computed_indicators = character(0), last_indicator = NULL, last_saved_at = NULL
      ),
      clear_cancel = function(...) NULL,
      update_project_status = function(...) NULL,
      .package = "nemeton"
    )

    result <- nemeton:::start_computation("test_proj", indicators = c("carbon_biomass"))
    expect_false(result$success)
    expect_true(grepl("Parcels file not found|could not be loaded", result$error))
  })
})

test_that("start_computation: orchestrates full flow with mocked internals", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    # Create parcels file
    units <- create_test_units(n_features = 3)
    sf::st_write(units, file.path(proj_path, "data", "parcels.gpkg"), quiet = TRUE)

    layers_obj <- structure(
      list(rasters = list(), vectors = list(), point_clouds = list(),
           bbox = c(0, 0, 1, 1), crs = sf::st_crs(2154),
           cache_dir = tempdir(), warnings = list()),
      class = "nemeton_layers"
    )

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      get_computation_progress = function(id) list(
        computed_indicators = character(0), last_indicator = NULL, last_saved_at = NULL
      ),
      clear_cancel = function(...) NULL,
      update_project_status = function(...) NULL,
      download_layers_for_parcels = function(...) layers_obj,
      is_cancelled = function(...) FALSE,
      compute_all_indicators = function(parcels, layers, indicators, ...) parcels,
      save_indicators = function(...) TRUE,
      .package = "nemeton"
    )

    callback_calls <- list()
    result <- nemeton:::start_computation(
      "test_proj",
      indicators = c("carbon_biomass"),
      progress_callback = function(state) {
        callback_calls[[length(callback_calls) + 1]] <<- state
      }
    )

    expect_true(result$success)
    expect_equal(result$state$status, "completed")
    expect_true(length(callback_calls) > 0)
  })
})

test_that("start_computation: calls progress_callback for file-based progress", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    units <- create_test_units(n_features = 2)
    sf::st_write(units, file.path(proj_path, "data", "parcels.gpkg"), quiet = TRUE)

    layers_obj <- structure(
      list(rasters = list(), vectors = list(), point_clouds = list(),
           bbox = c(0, 0, 1, 1), crs = sf::st_crs(2154),
           cache_dir = tempdir(), warnings = list()),
      class = "nemeton_layers"
    )

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      get_computation_progress = function(id) list(
        computed_indicators = character(0), last_indicator = NULL, last_saved_at = NULL
      ),
      clear_cancel = function(...) NULL,
      update_project_status = function(...) NULL,
      download_layers_for_parcels = function(...) layers_obj,
      is_cancelled = function(...) FALSE,
      compute_all_indicators = function(parcels, layers, indicators, ...) parcels,
      save_indicators = function(...) TRUE,
      save_progress_state = function(...) NULL,
      .package = "nemeton"
    )

    result <- nemeton:::start_computation(
      "test_proj",
      indicators = c("carbon_biomass"),
      use_file_progress = TRUE,
      project_path = proj_path
    )

    expect_true(result$success)
  })
})

test_that("start_computation: cancellation after download phase returns cancelled", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    units <- create_test_units(n_features = 2)
    sf::st_write(units, file.path(proj_path, "data", "parcels.gpkg"), quiet = TRUE)

    layers_obj <- structure(
      list(rasters = list(), vectors = list(), point_clouds = list(),
           bbox = c(0, 0, 1, 1), crs = sf::st_crs(2154),
           cache_dir = tempdir(), warnings = list()),
      class = "nemeton_layers"
    )

    cancel_check_count <- 0L
    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      get_computation_progress = function(id) list(
        computed_indicators = character(0), last_indicator = NULL, last_saved_at = NULL
      ),
      clear_cancel = function(...) NULL,
      update_project_status = function(...) NULL,
      download_layers_for_parcels = function(...) layers_obj,
      is_cancelled = function(...) {
        cancel_check_count <<- cancel_check_count + 1L
        TRUE  # Always cancelled
      },
      .package = "nemeton"
    )

    result <- nemeton:::start_computation(
      "test_proj",
      indicators = c("carbon_biomass")
    )

    expect_false(result$success)
    expect_true(result$cancelled)
    expect_equal(result$state$status, "cancelled")
  })
})

# ==============================================================================
# normalize_indicator()
# ==============================================================================

test_that("normalize_indicator: carbon_biomass uses ref_max 150", {
  values <- c(0, 75, 150, 300)
  result <- nemeton:::normalize_indicator("carbon_biomass", values)
  expect_equal(result[1], 0)
  expect_equal(result[2], 50)
  expect_equal(result[3], 100)
  expect_equal(result[4], 100)  # capped
})

test_that("normalize_indicator: carbon_ndvi scales 0-1 to 0-100", {
  values <- c(0, 0.5, 1)
  result <- nemeton:::normalize_indicator("carbon_ndvi", values)
  expect_equal(result, c(0, 50, 100))
})

test_that("normalize_indicator: water_twi rescales 2.5-4.5 to 0-100", {
  values <- c(2.5, 3.5, 4.5, 5.5)
  result <- nemeton:::normalize_indicator("water_twi", values)
  expect_equal(result[1], 0)
  expect_equal(result[2], 50)
  expect_equal(result[3], 100)
  expect_equal(result[4], 100)  # capped
})

test_that("normalize_indicator: social_trails inverts distance", {
  values <- c(0, 1000, 2000, 3000)
  result <- nemeton:::normalize_indicator("social_trails", values)
  expect_equal(result[1], 100)  # 0m = max accessibility
  expect_equal(result[2], 50)
  expect_equal(result[3], 0)
  expect_equal(result[4], 0)   # capped
})

test_that("normalize_indicator: social_accessibility inverts distance", {
  values <- c(500, 1500)
  result <- nemeton:::normalize_indicator("social_accessibility", values)
  expect_equal(result[1], 75)
  expect_equal(result[2], 25)
})

test_that("normalize_indicator: already-0-100 indicator just clamps", {
  # risk_fire is not in ref_max map, so just clamps
  values <- c(-5, 50, 110)
  result <- nemeton:::normalize_indicator("risk_fire", values)
  expect_equal(result, c(0, 50, 100))
})

test_that("normalize_indicator: production_volume uses ref_max 800", {
  values <- c(0, 400, 800, 1600)
  result <- nemeton:::normalize_indicator("production_volume", values)
  expect_equal(result[1], 0)
  expect_equal(result[2], 50)
  expect_equal(result[3], 100)
  expect_equal(result[4], 100)
})

test_that("normalize_indicator: water_network uses ref_max 50", {
  values <- c(0, 25, 50, 100)
  result <- nemeton:::normalize_indicator("water_network", values)
  expect_equal(result[1], 0)
  expect_equal(result[2], 50)
  expect_equal(result[3], 100)
  expect_equal(result[4], 100)
})

test_that("normalize_indicator: energy_wood uses ref_max 0.3", {
  values <- c(0, 0.15, 0.3, 0.6)
  result <- nemeton:::normalize_indicator("energy_wood", values)
  expect_equal(result[1], 0)
  expect_equal(result[2], 50)
  expect_equal(result[3], 100)
  expect_equal(result[4], 100)
})

# ==============================================================================
# save_progress_state() and read_progress_state()
# ==============================================================================

test_that("save_progress_state: writes JSON state file", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    state <- list(
      project_id = "test_proj",
      status = "computing",
      phase = "downloading",
      progress = 5,
      progress_max = 40,
      current_task = "download:source_ndvi",
      indicators_total = 30,
      indicators_completed = 0,
      indicators_skipped = 0,
      indicators_failed = 0,
      indicators_status = list(carbon_biomass = "pending"),
      errors = list(),
      started_at = Sys.time(),
      completed_at = NULL
    )

    nemeton:::save_progress_state("test_proj", state)

    progress_file <- file.path(proj_path, "data", "progress_state.json")
    expect_true(file.exists(progress_file))

    loaded <- jsonlite::read_json(progress_file)
    expect_equal(loaded$status, "computing")
    expect_equal(loaded$progress, 5)
  })
})

test_that("save_progress_state: returns invisible NULL for missing project", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )

  result <- nemeton:::save_progress_state("nonexistent", list())
  expect_null(result)
})

test_that("read_progress_state: returns NULL for missing project", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )

  result <- nemeton:::read_progress_state("nonexistent")
  expect_null(result)
})

test_that("read_progress_state: returns NULL when no progress file", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    result <- nemeton:::read_progress_state("test_proj")
    expect_null(result)
  })
})

test_that("save_progress_state + read_progress_state round-trip", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    state <- list(
      project_id = "test_proj",
      status = "completed",
      phase = "complete",
      progress = 40,
      progress_max = 40,
      current_task = "complete",
      indicators_total = 30,
      indicators_completed = 30,
      indicators_skipped = 0,
      indicators_failed = 0,
      indicators_status = list(carbon_biomass = "completed"),
      errors = list(),
      started_at = Sys.time(),
      completed_at = Sys.time()
    )

    nemeton:::save_progress_state("test_proj", state)
    loaded <- nemeton:::read_progress_state("test_proj")

    expect_type(loaded, "list")
    expect_equal(loaded$status, "completed")
    expect_equal(loaded$progress, 40)
  })
})

# ==============================================================================
# cancel_computation(), is_cancelled(), clear_cancel()
# ==============================================================================

test_that("cancel_computation: creates cancel file", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    nemeton:::cancel_computation("test_proj")

    cancel_file <- file.path(proj_path, "data", "cancel_requested")
    expect_true(file.exists(cancel_file))
  })
})

test_that("is_cancelled: returns TRUE when cancel file exists", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    # No cancel file yet
    expect_false(nemeton:::is_cancelled("test_proj"))

    # Create cancel file
    writeLines("cancel", file.path(proj_path, "data", "cancel_requested"))
    expect_true(nemeton:::is_cancelled("test_proj"))
  })
})

test_that("is_cancelled: returns FALSE for NULL project path", {
  local_mocked_bindings(
    get_project_path = function(id) NULL,
    .package = "nemeton"
  )

  expect_false(nemeton:::is_cancelled("nonexistent"))
})

test_that("clear_cancel: removes cancel file", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    cancel_file <- file.path(proj_path, "data", "cancel_requested")
    writeLines("cancel", cancel_file)
    expect_true(file.exists(cancel_file))

    nemeton:::clear_cancel("test_proj")
    expect_false(file.exists(cancel_file))
  })
})

test_that("clear_cancel: silent when no cancel file", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      .package = "nemeton"
    )

    expect_silent(nemeton:::clear_cancel("test_proj"))
  })
})

# ==============================================================================
# init_compute_state()
# ==============================================================================

test_that("init_compute_state: initializes with all indicators", {
  local_mocked_bindings(
    get_computation_progress = function(id) list(
      computed_indicators = character(0), last_indicator = NULL, last_saved_at = NULL
    ),
    .package = "nemeton"
  )

  state <- nemeton:::init_compute_state("test_proj", "all")
  expect_type(state, "list")
  expect_equal(state$project_id, "test_proj")
  expect_equal(state$status, "pending")
  expect_true(state$indicators_total > 25)  # list_available_indicators returns 30
  expect_equal(state$indicators_completed, 0)
  expect_false(state$is_resume)
})

test_that("init_compute_state: specific indicators subset", {
  local_mocked_bindings(
    get_computation_progress = function(id) list(
      computed_indicators = character(0), last_indicator = NULL, last_saved_at = NULL
    ),
    .package = "nemeton"
  )

  state <- nemeton:::init_compute_state("test_proj", c("carbon_biomass", "water_twi"))
  expect_equal(state$indicators_total, 2)
  expect_equal(length(state$indicators_status), 2)
  expect_true(all(state$indicators_status == "pending"))
})

test_that("init_compute_state: resume with already computed indicators", {
  local_mocked_bindings(
    get_computation_progress = function(id) list(
      computed_indicators = list("carbon_biomass"),
      last_indicator = "carbon_biomass",
      last_saved_at = "2025-01-01 12:00:00"
    ),
    .package = "nemeton"
  )

  state <- nemeton:::init_compute_state(
    "test_proj", c("carbon_biomass", "water_twi")
  )
  expect_true(state$is_resume)
  expect_equal(state$indicators_completed, 1)
  expect_equal(state$indicators_skipped, 1)
  expect_equal(state$indicators_status[["carbon_biomass"]], "completed")
  expect_equal(state$indicators_status[["water_twi"]], "pending")
})

# ==============================================================================
# create_synthetic_ndvi()
# ==============================================================================

test_that("create_synthetic_ndvi: creates realistic NDVI raster", {
  withr::with_tempdir({
    cache_file <- file.path(getwd(), "synth_ndvi.tif")
    result <- nemeton:::create_synthetic_ndvi(c(2, 46, 2.1, 46.1), cache_file)

    expect_s4_class(result, "SpatRaster")
    expect_true(file.exists(cache_file))

    vals <- terra::values(result)
    expect_true(all(vals >= 0.5 & vals <= 0.85, na.rm = TRUE))
    expect_equal(names(result), "ndvi")
  })
})

# ==============================================================================
# list_available_indicators()
# ==============================================================================

test_that("list_available_indicators: returns all indicator names", {
  result <- nemeton:::list_available_indicators()
  expect_type(result, "character")
  expect_true(length(result) >= 30)
  expect_true("carbon_biomass" %in% result)
  expect_true("risk_fire" %in% result)
  expect_true("naturalness_score" %in% result)
})

# ==============================================================================
# compute_all_indicators with resume - deeper coverage
# ==============================================================================

test_that("compute_all_indicators: skips indicators with non-zero existing values", {
  units <- create_test_units(n_features = 2)

  layers <- structure(
    list(rasters = list(), vectors = list(),
         metadata = list(n_rasters = 0, n_vectors = 0),
         cache_dir = NULL),
    class = "nemeton_layers"
  )

  # Return existing results with carbon_biomass already computed and water_twi all zeros
  existing <- units
  existing$carbon_biomass <- c(80, 90)
  existing$water_twi <- c(0, 0)  # All zeros -> should recompute

  compute_calls <- character()
  local_mocked_bindings(
    compute_single_indicator = function(indicator, parcels, layers) {
      compute_calls <<- c(compute_calls, indicator)
      c(50, 60)
    },
    load_indicators = function(project_id) existing,
    save_indicators_incremental = function(...) TRUE,
    is_cancelled = function(...) FALSE,
    .package = "nemeton"
  )

  result <- nemeton:::compute_all_indicators(
    units,
    layers,
    indicators = c("carbon_biomass", "water_twi"),
    progress_callback = NULL,
    project_id = "test_proj"
  )

  # carbon_biomass should be skipped (has real data), water_twi should be computed (all zeros)
  expect_true("water_twi" %in% compute_calls)
  expect_false("carbon_biomass" %in% compute_calls)
})

test_that("compute_all_indicators: recomputes all-NA columns from existing results", {
  units <- create_test_units(n_features = 2)

  layers <- structure(
    list(rasters = list(), vectors = list(),
         metadata = list(n_rasters = 0, n_vectors = 0),
         cache_dir = NULL),
    class = "nemeton_layers"
  )

  existing <- units
  existing$carbon_biomass <- c(NA_real_, NA_real_)  # All NA -> should recompute

  compute_calls <- character()
  local_mocked_bindings(
    compute_single_indicator = function(indicator, parcels, layers) {
      compute_calls <<- c(compute_calls, indicator)
      c(50, 60)
    },
    load_indicators = function(project_id) existing,
    save_indicators_incremental = function(...) TRUE,
    is_cancelled = function(...) FALSE,
    .package = "nemeton"
  )

  result <- nemeton:::compute_all_indicators(
    units,
    layers,
    indicators = c("carbon_biomass"),
    progress_callback = NULL,
    project_id = "test_proj"
  )

  expect_true("carbon_biomass" %in% compute_calls)
})

# ==============================================================================
# COMPUTE_STATUS and DATA_SOURCES constants
# ==============================================================================

test_that("COMPUTE_STATUS contains expected status codes", {
  statuses <- nemeton:::COMPUTE_STATUS
  expect_type(statuses, "list")
  expect_equal(statuses$PENDING, "pending")
  expect_equal(statuses$COMPLETED, "completed")
  expect_equal(statuses$ERROR, "error")
  expect_equal(statuses$CANCELLED, "cancelled")
})

test_that("DATA_SOURCES has rasters and vectors", {
  ds <- nemeton:::DATA_SOURCES
  expect_type(ds, "list")
  expect_true("rasters" %in% names(ds))
  expect_true("vectors" %in% names(ds))
  expect_true("ndvi" %in% names(ds$rasters))
  expect_true("roads" %in% names(ds$vectors))
  expect_true("bdforet" %in% names(ds$vectors))
})

# ==============================================================================
# start_computation: download warnings propagation
# ==============================================================================

test_that("start_computation: propagates download warnings to state errors", {
  withr::with_tempdir({
    proj_path <- file.path(getwd(), "test_proj")
    dir.create(file.path(proj_path, "data"), recursive = TRUE)

    units <- create_test_units(n_features = 2)
    sf::st_write(units, file.path(proj_path, "data", "parcels.gpkg"), quiet = TRUE)

    # Layers with warnings
    layers_obj <- structure(
      list(rasters = list(), vectors = list(), point_clouds = list(),
           bbox = c(0, 0, 1, 1), crs = sf::st_crs(2154),
           cache_dir = tempdir(),
           warnings = list(
             list(type = "warning", source = "OSO", message = "Download failed")
           )),
      class = "nemeton_layers"
    )

    local_mocked_bindings(
      get_project_path = function(id) proj_path,
      get_computation_progress = function(id) list(
        computed_indicators = character(0), last_indicator = NULL, last_saved_at = NULL
      ),
      clear_cancel = function(...) NULL,
      update_project_status = function(...) NULL,
      download_layers_for_parcels = function(...) layers_obj,
      is_cancelled = function(...) FALSE,
      compute_all_indicators = function(parcels, layers, indicators, ...) parcels,
      save_indicators = function(...) TRUE,
      .package = "nemeton"
    )

    captured_states <- list()
    result <- nemeton:::start_computation(
      "test_proj",
      indicators = c("carbon_biomass"),
      progress_callback = function(state) {
        captured_states[[length(captured_states) + 1]] <<- state
      }
    )

    expect_true(result$success)
    # State should have accumulated errors from download warnings
    has_errors <- any(vapply(captured_states, function(s) length(s$errors) > 0, logical(1)))
    expect_true(has_errors)
  })
})
