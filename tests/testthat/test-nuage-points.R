# Spec 059 — traiter_nuage_points() : MNT, MNS, MNH depuis un nuage de points.

# Nuage synthétique sur 60 x 60 m : sol en pente (z = 100 + 0,1 x), trois
# arbres coniques de 15 m (rayon 3 m), trois points de bruit 80 m au-dessus.
# `sous_couvert = FALSE` imite la photogrammétrie : pas de sol sous les houppiers.
.np_nuage <- function(dir, classe = 0L, decalage = 0, sous_couvert = TRUE,
                      seed = 1L) {
  set.seed(seed)
  n <- 60 * 60 * 15
  x <- stats::runif(n, 0, 60)
  y <- stats::runif(n, 0, 60)
  sol <- 100 + 0.1 * x
  arbres <- data.frame(x = c(15, 30, 45), y = c(15, 40, 25))
  h <- numeric(n)
  for (i in seq_len(nrow(arbres))) {
    r <- sqrt((x - arbres$x[i])^2 + (y - arbres$y[i])^2)
    h <- pmax(h, ifelse(r < 3, 15 * (1 - r / 3), 0))
  }
  # Moitié des points sous un houppier sur le sol (retours LiDAR), sauf
  # en photogrammétrie où seule la surface est vue.
  au_sol <- if (sous_couvert) h > 0 & stats::runif(n) < 0.5 else rep(FALSE, n)
  z <- sol + ifelse(au_sol, 0, h)
  pts <- data.frame(X = c(x, 10, 30, 50), Y = c(y, 50, 10, 30),
                    Z = c(z, 190, 190, 190) + decalage)
  pts$Classification <- if (identical(classe, "vrai")) {
    c(ifelse(h > 0 & !au_sol, 5L, 2L), 1L, 1L, 1L)
  } else {
    as.integer(classe)
  }
  pts$ReturnNumber <- 1L
  pts$NumberOfReturns <- 1L
  las <- lidR::LAS(data.table::as.data.table(pts))
  sf::st_crs(las) <- 2154
  f <- file.path(dir, "nuage.laz")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  lidR::writeLAS(las, f)
  invisible(f)
}

# Maximum d'un raster dans un carré de 2 m de côté centré sur (x, y) : la
# cellule de l'apex d'un cône peut ne contenir aucun point.
.np_max <- function(r, x, y) {
  terra::global(terra::crop(r, terra::ext(x - 1, x + 1, y - 1, y + 1)), "max",
                na.rm = TRUE)[[1]]
}

.np_skip <- function() {
  skip_if_not_installed("lasR")
  skip_if_not_installed("lidR")
  skip_if_not_installed("terra")
  skip_if_not_installed("data.table")
}

test_that("inputs are checked", {
  skip_if_not_installed("lasR")
  skip_if_not_installed("terra")
  d <- withr::local_tempdir()
  expect_error(traiter_nuage_points(file.path(d, "absent.laz")), "not found")
  expect_error(traiter_nuage_points(d), "No .las")
  writeLines("x", file.path(d, "a.txt"))
  expect_error(traiter_nuage_points(file.path(d, "a.txt")), "las")
  expect_error(traiter_nuage_points(d, type = "photogrammetrie"), "mnt_externe")
  expect_error(traiter_nuage_points(d, csf = list(1)), "named list")
})

test_that("drone LiDAR: reclassified ground gives the DTM, trees the CHM", {
  .np_skip()
  couches <- withr::local_tempdir()
  .np_nuage(file.path(couches, "drone_nuage"))
  out <- traiter_nuage_points(file.path(couches, "drone_nuage"),
                              type = "lidar_drone", res = 0.5, verbose = FALSE)

  expect_equal(out$mnt, file.path(couches, "drone_mnt", "mnt.tif"))
  expect_equal(out$mnh, file.path(couches, "drone_mnh", "mnh.tif"))
  mnt <- terra::rast(out$mnt)
  mnh <- terra::rast(out$mnh)
  mns <- terra::rast(out$mns)

  # MNT : le plan de sol, à quelques centimètres près.
  xy <- terra::crds(mnt, na.rm = TRUE)
  ecart <- terra::values(mnt, na.rm = TRUE) - (100 + 0.1 * xy[, 1])
  expect_lt(stats::median(abs(ecart)), 0.1)
  # MNH : les arbres de 15 m, sol nu à 0, rien de négatif.
  expect_gt(.np_max(mnh, 30, 40), 13)
  expect_lt(.np_max(mnh, 5, 55), 0.3)
  expect_gte(terra::global(mnh, "min", na.rm = TRUE)[[1]], 0)
  # Le bruit (190 m) n'entre pas dans le MNS.
  expect_lt(terra::global(mns, "max", na.rm = TRUE)[[1]], 125)
  expect_gt(out$classes[["18"]], 0)

  q <- out$qualite
  expect_gt(q$part_sol, 0.5)
  expect_gt(q$densite, 5)
  expect_true(is.na(q$decalage_vertical))

  # Second appel : resservi par le cache.
  bis <- traiter_nuage_points(file.path(couches, "drone_nuage"),
                              type = "lidar_drone", res = 0.5, verbose = FALSE)
  expect_equal(as.numeric(bis$elapsed), 0)
  expect_equal(bis$qualite$part_sol, q$part_sol)
})

test_that("IGN cloud: own classes kept with classifier = FALSE, ign_* outputs", {
  .np_skip()
  couches <- withr::local_tempdir()
  .np_nuage(file.path(couches, "lidar_nuage"), classe = "vrai")
  out <- traiter_nuage_points(file.path(couches, "lidar_nuage"), type = "lidar_ign",
                              classifier = FALSE, verbose = FALSE)
  expect_equal(out$mns, file.path(couches, "ign_mns", "mns.tif"))
  expect_equal(terra::res(terra::rast(out$mnt)), c(0.5, 0.5))
  expect_gt(.np_max(terra::rast(out$mnh), 15, 15), 13)
  expect_setequal(names(out$classes), c("1", "2", "5"))
})

test_that("classifier = FALSE without ground points stops", {
  .np_skip()
  couches <- withr::local_tempdir()
  .np_nuage(file.path(couches, "n"), classe = 1L)
  expect_error(traiter_nuage_points(file.path(couches, "n"), type = "lidar_drone",
                                    classifier = FALSE, verbose = FALSE),
               "ground|lasR")
})

test_that("photogrammetry: external DTM, vertical shift found and removed", {
  .np_skip()
  couches <- withr::local_tempdir()
  .np_nuage(file.path(couches, "drone_nuage"), decalage = 2, sous_couvert = FALSE)
  gabarit <- terra::rast(xmin = -10, xmax = 70, ymin = -10, ymax = 70, res = 1,
                         crs = "EPSG:2154")
  mnt_ext <- terra::init(gabarit, "x") * 0.1 + 100
  mnh_ref <- terra::rasterize(
    terra::buffer(terra::vect(cbind(c(15, 30, 45), c(15, 40, 25)), crs = "EPSG:2154"), 3),
    gabarit, field = 15, background = 0)

  expect_warning(
    traiter_nuage_points(file.path(couches, "drone_nuage"), type = "photogrammetrie",
                         mnt_externe = mnt_ext, verbose = FALSE),
    "mnh_reference")
  out <- traiter_nuage_points(file.path(couches, "drone_nuage"),
                              type = "photogrammetrie", mnt_externe = mnt_ext,
                              mnh_reference = mnh_ref, verbose = FALSE)
  q <- out$qualite
  expect_equal(q$decalage_vertical, 2, tolerance = 0.05)
  expect_gt(q$n_sol_nu, 100)
  expect_true(is.na(q$part_sol))
  mnh <- terra::rast(out$mnh)
  expect_gt(.np_max(mnh, 45, 25), 13)
  expect_lt(.np_max(mnh, 5, 55), 0.3)
  # Le MNS rendu est recalé ; le MNT est le MNT externe sur la grille du MNS.
  expect_equal(.np_max(terra::rast(out$mns), 5, 55), 100.6, tolerance = 0.2)
  expect_equal(terra::res(terra::rast(out$mnt)), c(0.25, 0.25))
})

test_that("drone products come first in resolve_project_*() and give NDP 2", {
  .np_skip()
  projet <- withr::local_tempdir()
  couches <- file.path(projet, "cache", "layers")
  r <- terra::rast(xmin = 0, xmax = 10, ymin = 0, ymax = 10, res = 1,
                   crs = "EPSG:2154", vals = 1)
  for (d in c("lidar_mnt", "lidar_mnh", "drone_mnt", "drone_mnh", "ign_mnt")) {
    dir.create(file.path(couches, d), recursive = TRUE)
  }
  terra::writeRaster(r, file.path(couches, "lidar_mnt", "a.tif"))
  terra::writeRaster(r, file.path(couches, "lidar_mnh", "a.tif"))
  terra::writeRaster(r, file.path(couches, "ign_mnt", "mnt.tif"))
  expect_equal(detect_ndp_from_cache(projet), 1L)
  expect_equal(attr(resolve_project_dem(projet), "nemeton_dem_layer"), "LiDAR HD MNT")

  terra::writeRaster(r, file.path(couches, "drone_mnt", "mnt.tif"))
  terra::writeRaster(r, file.path(couches, "drone_mnh", "mnh.tif"))
  expect_equal(attr(resolve_project_dem(projet), "nemeton_dem_layer"), "drone MNT")
  expect_equal(attr(resolve_project_chm(projet), "nemeton_chm_layer"), "drone MNH")
  expect_equal(detect_ndp_from_cache(projet), 2L)

  unlink(file.path(couches, c("lidar_mnt", "drone_mnt")), recursive = TRUE)
  expect_equal(attr(resolve_project_dem(projet), "nemeton_dem_layer"),
               "LiDAR HD MNT (point cloud)")
})

# Non-régression réelle : dalle IGN avec ses MNT/MNH publiés (hors CI).
test_that("IGN tile: reclassified DTM and CHM match the published rasters (live)", {
  skip_on_cran()
  skip_on_ci()
  .np_skip()
  dalle <- Sys.getenv("NEMETON_TEST_NUAGE_IGN")
  skip_if_not(nzchar(dalle) && file.exists(dalle), "NEMETON_TEST_NUAGE_IGN not set")
  couches <- dirname(dirname(dalle))
  id <- sub("_PTS_.*$", "", basename(dalle))
  mnt_ign <- list.files(file.path(couches, "lidar_mnt"), paste0("^", id, "_MNT"), full.names = TRUE)
  mnh_ign <- list.files(file.path(couches, "lidar_mnh"), paste0("^", id, "_MNH"), full.names = TRUE)
  skip_if_not(length(mnt_ign) == 1L && length(mnh_ign) == 1L, "published rasters missing")
  out <- traiter_nuage_points(dalle, type = "lidar_ign", dossier = withr::local_tempdir(),
                              ncores = 4L, verbose = FALSE)
  ecart <- function(a, b) {
    d <- terra::rast(a) - terra::resample(terra::rast(b), terra::rast(a))
    stats::median(abs(terra::values(d, na.rm = TRUE)))
  }
  expect_lt(ecart(out$mnt, mnt_ign), 0.5)
  expect_lt(ecart(out$mnh, mnh_ign), 1)
})
