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


# ---- cache complet, atomique, jamais rogné en place (audit 1.0) -----------

# Projet factice : une dalle .laz (contenu sans importance, lasR est mocké)
# et un faux pipeline qui écrit deux rasters 100 x 100 m en Lambert-93.
.faux_projet_lidar <- function() {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  laz_dir <- file.path(root, "lidar_nuage")
  dir.create(laz_dir)
  writeBin(as.raw(1:10), file.path(laz_dir, "dalle.copc.laz"))
  list(root = root, laz_dir = laz_dir,
       dtm = file.path(root, "lidar_mnt", "dtm.tif"),
       chm = file.path(root, "lidar_mnh", "chm.tif"))
}

.faux_lasr <- function(compteur_env) {
  function(laz_files, dtm_file, chm_file, res, ncores) {
    compteur_env$n <- compteur_env$n + 1L
    r <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                     resolution = 1, crs = "EPSG:2154", vals = 1)
    terra::writeRaster(r, dtm_file)
    terra::writeRaster(r * 20, chm_file)
    list(ok = TRUE)
  }
}

test_that("an interrupted lasR run leaves no partial cache (audit 1.0)", {
  skip_if_not_installed("lasR")
  p <- .faux_projet_lidar()
  local_mocked_bindings(.lasr_derive = function(laz_files, dtm_file, chm_file, ...) {
    # MNT écrit, puis coupure avant le MNH.
    terra::writeRaster(terra::rast(nrows = 5, ncols = 5, vals = 1), dtm_file)
    stop("killed")
  })
  expect_warning(out <- compute_dtm_chm_from_laz(p$laz_dir, verbose = FALSE),
                 "lasR pipeline failed")
  expect_null(out)
  expect_false(file.exists(p$dtm))
  expect_length(list.files(dirname(p$dtm), all.files = TRUE, no.. = TRUE), 0L)
})

test_that("the shared cache is never cropped in place (audit 1.0)", {
  skip_if_not_installed("lasR")
  p <- .faux_projet_lidar()
  cpt <- new.env(); cpt$n <- 0L
  local_mocked_bindings(.lasr_derive = .faux_lasr(cpt))
  carre <- function(x0) sf::st_sfc(sf::st_polygon(list(rbind(
    c(x0, 0), c(x0 + 20, 0), c(x0 + 20, 20), c(x0, 20), c(x0, 0)))),
    crs = 2154)

  a <- compute_dtm_chm_from_laz(p$laz_dir, aoi = carre(0), verbose = FALSE)
  b <- compute_dtm_chm_from_laz(p$laz_dir, aoi = carre(60), verbose = FALSE)
  expect_identical(cpt$n, 1L)  # le cache complet a servi au second appel

  # Le cache partagé garde l'emprise complète des dalles.
  expect_equal(unname(as.vector(terra::ext(terra::rast(p$chm)))),
               c(0, 100, 0, 100))
  # Chaque AOI reçoit sa propre découpe, à sa propre emprise.
  expect_false(identical(a$chm, b$chm))
  expect_equal(terra::xmin(terra::rast(b$chm)), 60)
  # Les découpes ne sont pas visibles du résolveur (premier niveau seul).
  expect_identical(list.files(dirname(p$chm), pattern = "\\.tif$"), "chm.tif")
})

test_that("a cache without a matching key is rebuilt (audit 1.0)", {
  skip_if_not_installed("lasR")
  p <- .faux_projet_lidar()
  # Cache hérité d'une version antérieure (sans clé, possiblement rogné).
  dir.create(dirname(p$dtm)); dir.create(dirname(p$chm))
  petit <- terra::rast(xmin = 0, xmax = 10, ymin = 0, ymax = 10,
                       resolution = 1, crs = "EPSG:2154", vals = 1)
  terra::writeRaster(petit, p$dtm); terra::writeRaster(petit, p$chm)
  cpt <- new.env(); cpt$n <- 0L
  local_mocked_bindings(.lasr_derive = .faux_lasr(cpt))
  compute_dtm_chm_from_laz(p$laz_dir, verbose = FALSE)
  expect_identical(cpt$n, 1L)
  expect_equal(terra::xmax(terra::rast(p$chm)), 100)

  # Une autre résolution ne resservira pas ce cache.
  compute_dtm_chm_from_laz(p$laz_dir, res = 2, verbose = FALSE)
  expect_identical(cpt$n, 2L)
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
