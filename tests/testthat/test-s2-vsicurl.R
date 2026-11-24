# Mission 044 — lecture S2 distante par fenêtre (/vsicurl/)

test_that("cas 1 : une URL http(s) est ouverte en /vsicurl/, le reste est inchangé", {
  u <- "https://acct.blob.core.windows.net/s2/B04.tif?sv=1&se=2030-01-01T00:00:00Z&sig=abc"
  expect_identical(nemeton:::.s2_vsi_path(u), paste0("/vsicurl/", u))
  expect_identical(nemeton:::.s2_vsi_path("http://x/y.tif"), "/vsicurl/http://x/y.tif")
  expect_identical(nemeton:::.s2_vsi_path("/tmp/B04.tif"), "/tmp/B04.tif")
  expect_identical(nemeton:::.s2_vsi_path("/vsicurl/https://x/y.tif"),
                   "/vsicurl/https://x/y.tif")
  expect_identical(nemeton:::.s2_vsi_path("/vsis3/b/k.tif"), "/vsis3/b/k.tif")
})

test_that("cas 2 : le jeton renouvelé n'est pas préfixé deux fois", {
  vus <- character()
  local_mocked_bindings(
    rast = function(x, ...) { vus <<- c(vus, x); stop("HTTP 403 forbidden") },
    .package = "terra"
  )
  local_mocked_bindings(
    .pc_invalidate_token = function(...) invisible(NULL),
    .pc_resign_href = function(href, ...) paste0(sub("\\?.*$", "", href), "?sig=neuf")
  )
  old <- "https://a.blob.core.windows.net/s2/B04.tif?sig=vieux"
  expect_error(suppressWarnings(
    nemeton:::.terra_rast_with_pc_retry(old, max_tries = 2L)))
  expect_identical(vus[1], paste0("/vsicurl/", old))
  expect_identical(vus[2], "/vsicurl/https://a.blob.core.windows.net/s2/B04.tif?sig=neuf")
  expect_false(any(grepl("vsicurl//vsicurl", vus, fixed = TRUE)))
})

test_that("cas 3 : option GDAL posée pendant la lecture, état d'avant restauré", {
  nm <- "GDAL_DISABLE_READDIR_ON_OPEN"
  withr::local_envvar(c(GDAL_DISABLE_READDIR_ON_OPEN = NA))
  pendant <- nemeton:::.with_s2_gdal_opts(Sys.getenv(nm))
  expect_identical(pendant, "EMPTY_DIR")
  expect_identical(Sys.getenv(nm, unset = NA), NA_character_)
  withr::local_envvar(c(GDAL_DISABLE_READDIR_ON_OPEN = "FALSE"))
  nemeton:::.with_s2_gdal_opts(1)
  expect_identical(Sys.getenv(nm), "FALSE")
  try(nemeton:::.with_s2_gdal_opts(stop("boum")), silent = TRUE)
  expect_identical(Sys.getenv(nm), "FALSE")
})

test_that("cas 4 : un raster local est lu à l'identique", {
  withr::with_tempdir({
    r <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 200, ymin = 0,
                     ymax = 200, crs = "EPSG:32631")
    terra::values(r) <- seq_len(400)
    terra::writeRaster(r, "b.tif")
    avant <- terra::rast("b.tif")
    apres <- nemeton:::.terra_rast_with_pc_retry(normalizePath("b.tif"))
    expect_equal(terra::values(apres), terra::values(avant))
    expect_equal(as.vector(terra::ext(apres)), as.vector(terra::ext(avant)))
    expect_equal(terra::res(apres), terra::res(avant))
  })
})
