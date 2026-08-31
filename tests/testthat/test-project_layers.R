# test-project_layers.R — resolve_project_dem / resolve_project_chm
#
# Filesystem-based unit tests using withr::local_tempdir. No network,
# no real rasters needed — we use 0-byte files when only path-discovery
# matters, and real terra::rast()-able files when `load = TRUE` is
# exercised.

skip_if_no_terra <- function() {
  testthat::skip_if_not_installed("terra")
  skip_if_terra_write_broken()
}

# Tiny 4x4 valid GeoTIFF for "load = TRUE" tests.
.write_tiny_tif <- function(path) {
  skip_if_no_terra()
  r <- terra::rast(nrows = 4, ncols = 4,
                   xmin = 0, xmax = 40, ymin = 0, ymax = 40,
                   crs = "EPSG:2154", vals = seq_len(16))
  terra::writeRaster(r, path, overwrite = TRUE,
                     gdal = c("TILED=YES", "COMPRESS=DEFLATE"))
  invisible(path)
}


# ---- argument validation ---------------------------------------------

test_that("resolve_project_dem rejects invalid project_path", {
  skip_if_not_installed("terra")
  expect_error(resolve_project_dem(NULL), "must be a single non-empty path")
  expect_error(resolve_project_dem(""), "must be a single non-empty path")
  expect_error(resolve_project_dem(c("a", "b")), "must be a single non-empty path")
  expect_error(resolve_project_dem("/no/such/dir"), "does not exist")
})

test_that("resolve_project_chm rejects invalid project_path", {
  skip_if_not_installed("terra")
  expect_error(resolve_project_chm(NULL), "must be a single non-empty path")
  expect_error(resolve_project_chm("/no/such/dir"), "does not exist")
})


# ---- empty project ---------------------------------------------------

test_that("resolve_project_dem returns NULL when no DEM is present", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  expect_null(resolve_project_dem(proj))
  expect_null(resolve_project_dem(proj, load = FALSE))
})

test_that("resolve_project_chm returns NULL when no CHM is present", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  expect_null(resolve_project_chm(proj))
})


# ---- single-file conventions -----------------------------------------

test_that("resolve_project_dem finds <project>/dtm.tif (opencanopy)", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_length(out, 1L)
  expect_equal(normalizePath(out, mustWork = FALSE),
               normalizePath(file.path(proj, "dtm.tif"), mustWork = FALSE))
  expect_identical(attr(out, "nemeton_dem_layer"), "opencanopy DTM")
})

test_that("resolve_project_dem finds <project>/mnt.tif (tutorial)", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "mnt.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "tutorial MNT")
})

test_that("resolve_project_dem finds <project>/data/dtm.tif", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "data"))
  .write_tiny_tif(file.path(proj, "data", "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "data/dtm.tif")
})

test_that("resolve_project_chm finds <project>/chm.tif", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "chm.tif"))
  out <- resolve_project_chm(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_chm_layer"), "single-file CHM")
})


# ---- cache/layers conventions ----------------------------------------

test_that("resolve_project_dem finds cache/layers/lidar_mnt/*.tif", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "lidar_mnt"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "lidar_mnt", "tile_001.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "LiDAR HD MNT")
  expect_length(out, 1L)
})

test_that("resolve_project_chm finds cache/layers/chm/*.tif", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "chm"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "chm", "T31TFN.tif"))
  out <- resolve_project_chm(proj, load = FALSE)
  # Libelle neutre depuis v0.192.2 : Open-Canopy n'ecrit pas la.
  expect_identical(attr(out, "nemeton_chm_layer"), "cache/layers/chm/")
})


# ---- Open-Canopy (cache/layers/opencanopy) ---------------------------
#
# L'app (nemetonshiny::download_chm_opencanopy) depose ses livrables dans
# cache/layers/opencanopy/, que le resolveur ignorait jusqu'a v0.192.2.

.write_opencanopy_project <- function(files) {
  proj <- withr::local_tempdir(.local_envir = parent.frame())
  oc <- file.path(proj, "cache", "layers", "opencanopy")
  dir.create(oc, recursive = TRUE)
  for (f in files) .write_tiny_tif(file.path(oc, f))
  proj
}

test_that("resolve_project_chm finds the Open-Canopy 0.2 m CHM", {
  skip_if_not_installed("terra")
  proj <- .write_opencanopy_project("chm_predicted_0_2m.tif")
  out <- resolve_project_chm(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_chm_layer"), "Open-Canopy CHM 0,2 m")
  expect_length(out, 1L)
  expect_match(out, "chm_predicted_0_2m\\.tif$")
})

test_that("resolve_project_chm prefers 0.2 m over 1.5 m and the witness", {
  skip_if_not_installed("terra")
  proj <- .write_opencanopy_project(c("chm_1_5m.tif",
                                      "chm_predicted_1_5m.tif",
                                      "chm_predicted_0_2m.tif"))
  expect_identical(attr(resolve_project_chm(proj, load = FALSE),
                        "nemeton_chm_layer"),
                   "Open-Canopy CHM 0,2 m")

  # Sans le 0,2 m, le 1,5 m predit passe devant le temoin.
  file.remove(file.path(proj, "cache", "layers", "opencanopy",
                        "chm_predicted_0_2m.tif"))
  expect_identical(attr(resolve_project_chm(proj, load = FALSE),
                        "nemeton_chm_layer"),
                   "Open-Canopy CHM 1,5 m")

  file.remove(file.path(proj, "cache", "layers", "opencanopy",
                        "chm_predicted_1_5m.tif"))
  expect_identical(attr(resolve_project_chm(proj, load = FALSE),
                        "nemeton_chm_layer"),
                   "Open-Canopy CHM (temoin)")
})

test_that("resolve_project_chm never mosaics orthos and indices with the CHM", {
  skip_if_not_installed("terra")
  # Le test qui compte : cache/layers/opencanopy/ contient aussi des
  # orthophotos et des indices spectraux. Un candidat sans `file`
  # rendrait un VRT de dix couches heterogenes.
  proj <- .write_opencanopy_project(c("chm_predicted_0_2m.tif",
                                      "chm_vegetation_0_2m.tif",
                                      "ortho_rvb.tif", "ortho_irc.tif",
                                      "ndvi.tif", "ndwi.tif",
                                      "gndvi.tif", "savi.tif"))
  paths <- resolve_project_chm(proj, load = FALSE)
  expect_length(paths, 1L)
  expect_match(paths, "chm_predicted_0_2m\\.tif$")
  # Le derive vegetation n'est jamais choisi.
  expect_false(any(grepl("chm_vegetation", paths)))

  r <- resolve_project_chm(proj, load = TRUE)
  expect_s4_class(r, "SpatRaster")
  expect_equal(terra::nlyr(r), 1L)
})

test_that("resolve_project_chm prefers LiDAR HD MNH over Open-Canopy", {
  skip_if_not_installed("terra")
  # ADR-007 : le LiDAR local porte un NDP superieur au produit ML.
  proj <- .write_opencanopy_project("chm_predicted_0_2m.tif")
  dir.create(file.path(proj, "cache", "layers", "lidar_mnh"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "lidar_mnh", "mnh.tif"))
  out <- resolve_project_chm(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_chm_layer"), "LiDAR HD MNH")
})


# ---- priority order --------------------------------------------------

test_that("resolve_project_dem prefers LiDAR HD MNT over opencanopy DTM", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  # Both present — LiDAR HD wins (it's #1 in the search order).
  dir.create(file.path(proj, "cache", "layers", "lidar_mnt"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "lidar_mnt", "x.tif"))
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "LiDAR HD MNT")
})

test_that("resolve_project_dem falls back from BD ALTI to opencanopy DTM", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  # No LiDAR / DEM / BD ALTI / etc. — only opencanopy DTM.
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "opencanopy DTM")
})


# ---- multi-tile mosaic -----------------------------------------------

test_that("resolve_project_dem returns a VRT when multiple tiles match", {
  skip_if_no_terra()
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "bd_alti"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "bd_alti", "tile_A.tif"))
  .write_tiny_tif(file.path(proj, "cache", "layers", "bd_alti", "tile_B.tif"))

  # load = FALSE returns both paths.
  paths <- resolve_project_dem(proj, load = FALSE)
  expect_length(paths, 2L)

  # load = TRUE returns one SpatRaster (VRT-mosaiced).
  r <- resolve_project_dem(proj)
  expect_s4_class(r, "SpatRaster")
  expect_identical(attr(r, "nemeton_dem_layer"), "IGN BD ALTI")
})


# ---- verbose mode ----------------------------------------------------

test_that("resolve_project_dem logs probed paths when verbose = TRUE", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  # Should at minimum emit one "Found … opencanopy DTM" message.
  expect_message(
    resolve_project_dem(proj, load = FALSE, verbose = TRUE),
    "opencanopy DTM"
  )
})

test_that("resolve_project_dem warns when nothing is found and verbose = TRUE", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  expect_message(
    resolve_project_dem(proj, verbose = TRUE),
    "No DEM found"
  )
})


# ---- direct files under cache/layers/ (v0.25.5) ----------------------

test_that("resolve_project_dem finds cache/layers/dem.tif (direct file)", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "dem.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "cache/layers/dem.tif")
})

test_that("resolve_project_dem finds cache/layers/dtm.tif (direct file)", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "cache/layers/dtm.tif")
})

test_that("resolve_project_dem prefers cache/layers/dem.tif over <project>/dtm.tif", {
  skip_if_not_installed("terra")
  # Both present — cache/layers/dem.tif wins (it's higher in the list).
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "dem.tif"))
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "cache/layers/dem.tif")
})

test_that("resolve_project_dem finds <project>/dem.tif at project root", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "dem.tif"))
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "project DEM")
})

test_that("resolve_project_chm finds cache/layers/chm.tif (direct file)", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "chm.tif"))
  out <- resolve_project_chm(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_chm_layer"), "cache/layers/chm.tif")
})


# ---- file matching is case-insensitive (Windows DTM.tif vs dtm.tif) --

test_that("resolve_project_dem matches dtm.tif case-insensitively", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  .write_tiny_tif(file.path(proj, "DTM.tif"))  # uppercase
  out <- resolve_project_dem(proj, load = FALSE)
  expect_identical(attr(out, "nemeton_dem_layer"), "opencanopy DTM")
})


# ---- validate : sauter un candidat inexploitable ---------------------
#
# v0.193.0. `resolve_project_*` rendait le premier chemin qui matche sans
# regarder ce qu'il y a dedans : un MNH plat arretait la recherche, et les
# appelants re-sondaient a la main pour trouver la source suivante.

.write_flat_tif <- function(path, value = 0) {
  skip_if_no_terra()
  r <- terra::rast(nrows = 4, ncols = 4,
                   xmin = 0, xmax = 40, ymin = 0, ymax = 40,
                   crs = "EPSG:2154", vals = rep(value, 16))
  terra::writeRaster(r, path, overwrite = TRUE)
  invisible(path)
}

# Le garde de contenu de l'app : un modele de hauteur sans hauteur n'en
# est pas un.
.has_height <- function(r) {
  v <- terra::values(r)
  any(is.finite(v)) && max(v, na.rm = TRUE) >= 5
}

test_that("resolve_project_chm skips a flat candidate and falls through", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "lidar_mnh"), recursive = TRUE)
  dir.create(file.path(proj, "cache", "layers", "opencanopy"), recursive = TRUE)
  # Le LiDAR gagne au rang... mais ne porte aucune vegetation.
  .write_flat_tif(file.path(proj, "cache", "layers", "lidar_mnh", "plat.tif"))
  .write_tiny_tif(file.path(proj, "cache", "layers", "opencanopy",
                            "chm_predicted_0_2m.tif"))

  # Sans validate : le comportement d'avant, le plat gagne.
  expect_identical(attr(resolve_project_chm(proj, load = FALSE),
                        "nemeton_chm_layer"),
                   "LiDAR HD MNH")

  # Avec validate : le plat est saute, la source suivante sert.
  out <- resolve_project_chm(proj, load = FALSE, validate = .has_height)
  expect_identical(attr(out, "nemeton_chm_layer"), "Open-Canopy CHM 0,2 m")
  expect_match(out, "chm_predicted_0_2m\\.tif$")

  # load = TRUE rend bien le raster retenu, pas celui qui a echoue.
  r <- resolve_project_chm(proj, validate = .has_height)
  expect_s4_class(r, "SpatRaster")
  expect_gte(max(terra::values(r), na.rm = TRUE), 5)
})

test_that("resolve_project_chm returns NULL when every candidate fails", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "opencanopy"), recursive = TRUE)
  .write_flat_tif(file.path(proj, "cache", "layers", "opencanopy",
                            "chm_predicted_0_2m.tif"))
  expect_null(resolve_project_chm(proj, load = FALSE, validate = .has_height))
})

test_that("resolve_project_dem takes validate too", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "lidar_mnt"), recursive = TRUE)
  .write_flat_tif(file.path(proj, "cache", "layers", "lidar_mnt", "nodata.tif"),
                  value = NA)
  .write_tiny_tif(file.path(proj, "dtm.tif"))
  out <- resolve_project_dem(proj, load = FALSE,
                             validate = function(r) any(is.finite(terra::values(r))))
  expect_identical(attr(out, "nemeton_dem_layer"), "opencanopy DTM")
})

test_that("validate is checked, and a nonsense verdict is an error", {
  skip_if_not_installed("terra")
  proj <- withr::local_tempdir()
  dir.create(file.path(proj, "cache", "layers", "opencanopy"), recursive = TRUE)
  .write_tiny_tif(file.path(proj, "cache", "layers", "opencanopy",
                            "chm_predicted_0_2m.tif"))
  expect_error(resolve_project_chm(proj, validate = "oui"),
               "must be a function")
  expect_error(resolve_project_chm(proj, validate = function(r) NA),
               "single .*TRUE")
  # Une erreur du predicat remonte : au caller de decider si un fichier
  # illisible vaut « suivant » ou « stop ».
  expect_error(resolve_project_chm(proj, validate = function(r) stop("boom")),
               "boom")
})

test_that("validate sees the mosaic, once per candidate — not once per tile", {
  skip_if_not_installed("terra")
  # Contrat fige avec la session app : sur un repertoire de dalles, le
  # predicat recoit le SpatRaster TEL QU'IL SERAIT RENDU (le VRT), une
  # seule fois. Appele dalle par dalle, une dalle de clairiere ferait
  # rejeter une source valide.
  proj <- withr::local_tempdir()
  d <- file.path(proj, "cache", "layers", "lidar_mnh")
  dir.create(d, recursive = TRUE)
  mk <- function(path, xmin, vals) {
    r <- terra::rast(nrows = 4, ncols = 4,
                     xmin = xmin, xmax = xmin + 40, ymin = 0, ymax = 40,
                     crs = "EPSG:2154", vals = vals)
    terra::writeRaster(r, path, overwrite = TRUE)
  }
  mk(file.path(d, "clairiere.tif"), 0,  rep(0, 16))    # dalle sans hauteur
  mk(file.path(d, "foret.tif"),     40, rep(20, 16))   # dalle boisee

  seen <- list()
  out <- resolve_project_chm(proj, load = FALSE, validate = function(r) {
    seen[[length(seen) + 1L]] <<- terra::ncell(r)
    max(terra::values(r), na.rm = TRUE) >= 5
  })

  expect_length(seen, 1L)                 # une fois, pas deux
  expect_equal(seen[[1]], 32)             # les deux dalles, mosaiquees
  expect_identical(attr(out, "nemeton_chm_layer"), "LiDAR HD MNH")
  expect_length(out, 2L)                  # les deux chemins sont rendus
})
