# Mission 082 : mosaique de dalles a SRS ecrit differemment.

# Meme projection Lambert-93, ecrite sans nom ni datum (chaine PROJ) : GDAL la
# lit comme « unknown » et terra::vrt() abandonne la dalle (cas de Pascal).
.proj_l93_ecrit_autrement <- paste(
  "+proj=lcc +lat_0=46.5 +lon_0=3 +lat_1=49 +lat_2=44 +x_0=700000",
  "+y_0=6600000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
)

.fab_dalle <- function(dossier, nom, xmin, valeur, crs, ecrire_srs = NULL) {
  r <- terra::rast(xmin = xmin, xmax = xmin + 10, ymin = 0, ymax = 10,
                   resolution = 1, crs = crs)
  terra::values(r) <- valeur
  f <- file.path(dossier, nom)
  if (is.null(ecrire_srs)) {
    terra::writeRaster(r, f, overwrite = TRUE)
  } else {
    tmp <- file.path(dossier, paste0("tmp_", nom))
    terra::writeRaster(r, tmp, overwrite = TRUE)
    sf::gdal_utils("translate", tmp, f, options = c("-a_srs", ecrire_srs), quiet = TRUE)
    unlink(tmp)
  }
  f
}

test_that("deux dalles au meme SRS ecrit differemment : toutes gardees", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  d <- withr::local_tempdir()
  a <- .fab_dalle(d, "a.tif", 0, 1, "EPSG:2154")
  b <- .fab_dalle(d, "b.tif", 10, 2, "EPSG:2154", ecrire_srs = .proj_l93_ecrit_autrement)
  # preuve que le cas est bien celui de la sortie : terra les juge differentes
  expect_false(terra::same.crs(terra::rast(a), terra::rast(b)))

  m <- expect_no_warning(.mosaique_dalles(c(a, b)))
  expect_equal(unname(as.vector(terra::ext(m))), c(0, 20, 0, 10))
  expect_equal(terra::extract(m, cbind(5, 5))[[1]], 1)
  expect_equal(terra::extract(m, cbind(15, 5))[[1]], 2)
})

test_that("contre-epreuve : l'ancien terra::vrt() ne garde qu'une dalle", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  d <- withr::local_tempdir()
  a <- .fab_dalle(d, "a.tif", 0, 1, "EPSG:2154")
  b <- .fab_dalle(d, "b.tif", 10, 2, "EPSG:2154", ecrire_srs = .proj_l93_ecrit_autrement)
  vieux <- suppressWarnings(terra::vrt(c(a, b)))
  expect_equal(unname(as.vector(terra::ext(vieux))), c(0, 10, 0, 10))
})

test_that("une dalle en EPSG:4326 parmi des dalles Lambert-93 : erreur qui la nomme", {
  skip_if_not_installed("terra")
  d <- withr::local_tempdir()
  a <- .fab_dalle(d, "a.tif", 0, 1, "EPSG:2154")
  b <- .fab_dalle(d, "b.tif", 10, 2, "EPSG:2154")
  z <- .fab_dalle(d, "etrangere.tif", 0, 3, "EPSG:4326")
  expect_error(.mosaique_dalles(c(a, b, z)), "etrangere\\.tif")
  expect_error(.mosaique_dalles(c(a, b, z)), "coordinate\\s+system",
               class = "nemeton_mosaique_srs")
})

test_that("une seule dalle : comportement inchange", {
  skip_if_not_installed("terra")
  d <- withr::local_tempdir()
  a <- .fab_dalle(d, "a.tif", 0, 1, "EPSG:2154")
  m <- .mosaique_dalles(a)
  expect_s4_class(m, "SpatRaster")
  expect_equal(unname(as.vector(terra::ext(m))), c(0, 10, 0, 10))
})

test_that("options pass-through et fichier de sortie nomme", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  d <- withr::local_tempdir()
  a <- .fab_dalle(d, "a.tif", 0, 1, "EPSG:2154")
  b <- .fab_dalle(d, "b.tif", 10, 2, "EPSG:2154")
  out <- file.path(d, "m.vrt")
  m <- .mosaique_dalles(c(a, b), filename = out, options = c("-srcnodata", "0", "-vrtnodata", "0"))
  expect_true(file.exists(out))
  expect_equal(unname(as.vector(terra::ext(m))), c(0, 20, 0, 10))
  expect_match(paste(readLines(out), collapse = ""), "NoDataValue>0<")
})

test_that("le controle du nombre de dalles utilisees echoue clairement", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  d <- withr::local_tempdir()
  a <- .fab_dalle(d, "a.tif", 0, 1, "EPSG:2154")
  b <- .fab_dalle(d, "b.tif", 10, 2, "EPSG:2154")
  testthat::local_mocked_bindings(.vrt_sources_utilisees = function(...) 1L)
  expect_error(.mosaique_dalles(c(a, b)), "uses\\s+1\\s+of\\s+2",
               class = "nemeton_mosaique_sources")
})

test_that(".open_raster passe par la mosaique et garde les deux dalles", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  d <- withr::local_tempdir()
  a <- .fab_dalle(d, "a.tif", 0, 1, "EPSG:2154")
  b <- .fab_dalle(d, "b.tif", 10, 2, "EPSG:2154", ecrire_srs = .proj_l93_ecrit_autrement)
  m <- .open_raster(c(a, b))
  expect_equal(unname(as.vector(terra::ext(m))), c(0, 20, 0, 10))
})

test_that(".rsen_load_raster lit un dossier de dalles heterogenes", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  d <- withr::local_tempdir()
  .fab_dalle(d, "a.tif", 0, 1, "EPSG:2154")
  .fab_dalle(d, "b.tif", 10, 2, "EPSG:2154", ecrire_srs = .proj_l93_ecrit_autrement)
  r <- .rsen_load_raster(d, terra::ext(0, 20, 0, 10), "MNH")
  expect_equal(unname(as.vector(terra::ext(r))), c(0, 20, 0, 10))
})

test_that("plus aucun terra::vrt() direct sur une liste de dalles dans R/", {
  skip_if_not(file.exists("../../R/mosaique_dalles.R"))
  src <- unlist(lapply(list.files("../../R", pattern = "\\.R$", full.names = TRUE),
                       function(f) {
                         if (basename(f) == "mosaique_dalles.R") return(character())
                         x <- readLines(f, warn = FALSE)
                         x[!grepl("^\\s*#", x)]
                       }))
  expect_false(any(grepl("terra::vrt\\(", src)))
})

test_that("FORDEAD : deux scenes de meme date sur deux fuseaux UTM : avertissement, une scene gardee", {
  skip_if_not_installed("terra")
  d <- withr::local_tempdir()
  # la scene 31T est plus etendue : c'est elle qui est gardee
  r1 <- terra::rast(xmin = 0, xmax = 20, ymin = 0, ymax = 20, resolution = 1, crs = "EPSG:32631")
  r2 <- terra::rast(xmin = 0, xmax = 10, ymin = 0, ymax = 10, resolution = 1, crs = "EPSG:32632")
  terra::values(r1) <- 1; terra::values(r2) <- 2
  f1 <- file.path(d, "s1_B04.tif"); f2 <- file.path(d, "s2_B04.tif")
  terra::writeRaster(r1, f1); terra::writeRaster(r2, f2)
  dt <- as.Date("2023-06-15")
  grp <- list(list(sid = "S1", dt = dt, band_paths = f1),
              list(sid = "S2", dt = dt, band_paths = f2))
  expect_warning(out <- .fordead_mosaic_same_date(grp, "B04"),
                 "different\\s+CRSs")
  expect_equal(out$sid, "S1")
  # contre-epreuve : le helper de mosaique, lui, refuse (erreur claire)
  expect_error(.mosaique_dalles(c(f1, f2)), "s2_B04\\.tif",
               class = "nemeton_mosaique_srs")
})

test_that(".srs_deux_equivalents distingue le sens, pas l'ecriture", {
  skip_if_not_installed("terra")
  w <- function(x) terra::crs(x)
  l93_proj <- w(.proj_l93_ecrit_autrement)
  expect_true(.srs_deux_equivalents(w("EPSG:2154"), l93_proj))
  expect_false(.srs_deux_equivalents(w("EPSG:2154"), w("EPSG:27572")))
  expect_false(.srs_deux_equivalents(w("EPSG:32631"), w("EPSG:32632")))
  expect_false(.srs_deux_equivalents(w("EPSG:2154"), w("EPSG:3035")))
  decale <- w(sub("+x_0=700000", "+x_0=700001", .proj_l93_ecrit_autrement, fixed = TRUE))
  expect_false(.srs_deux_equivalents(w("EPSG:2154"), decale))
})


# --- Mission 085 : equivalence semantique des SRS --------------------------

test_that("cas reel : SRS « EPSG:2154 » sans autorite contre WKT complet : equivalents", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  d <- withr::local_tempdir()
  a <- .ecrire_dalle_ign(d, "LHD_FXX_0000_0000_MNH_0M50_LAMB93_IGN69.tif", 0, 1)
  b <- .ecrire_dalle_ign(d, "LHD_FXX_0000_0001_MNH_0M50_LAMB93_IGN69.tif", 10, 2)
  c1 <- .fab_dalle(d, "chm.tif", 0, 3, "EPSG:2154")
  # les trois faits du poste de Pascal
  expect_equal(terra::crs(terra::rast(a), describe = TRUE)$name, "EPSG:2154")
  expect_equal(terra::crs(terra::rast(c1), describe = TRUE)$name, "RGF93 v1 / Lambert-93")
  expect_false(terra::same.crs(terra::rast(a), terra::rast(c1)))
  expect_true(all(.srs_equivalents(c(a, c1))))
  expect_true(all(.srs_equivalents(c(c1, a))))
  m <- .mosaique_dalles(c(a, b, c1))
  expect_equal(unname(as.vector(terra::ext(m))), c(0, 20, 0, 10))
})

test_that("identite des points : les SRS reellement differents restent refuses", {
  skip_if_not_installed("terra")
  w <- function(x) terra::crs(x)
  pts <- cbind(x = c(370999, 371999), y = c(6388000, 6389000))
  expect_true(.srs_deux_equivalents(w(.wkt_dalle_ign), w("EPSG:2154"), pts))
  expect_false(.srs_deux_equivalents(w("EPSG:2154"), w("EPSG:27572"), pts))
  expect_false(.srs_deux_equivalents(w("EPSG:2154"), w("EPSG:3035"), pts))
  expect_false(.srs_deux_equivalents(w("EPSG:32631"), w("EPSG:32632"),
                                     cbind(500000, 5000000)))
  decale <- w(sub("+x_0=700000", "+x_0=700001", .proj_l93_ecrit_autrement, fixed = TRUE))
  expect_false(.srs_deux_equivalents(w("EPSG:2154"), decale, pts))
  # sans point : repli sur terra::same.crs et la chaine PROJ, jamais d'erreur
  expect_false(.srs_deux_equivalents(w(.wkt_dalle_ign), w("EPSG:2154")))
})
