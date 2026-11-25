# Schéma 1.7.0 (mission 037, brief groma 2026-11-20 révisé) : dalles MNT de
# 1 km, relief CVAT et houppiers sur toute la forêt, sommet des houppiers.
# Données synthétiques minuscules, sans LiDAR réel ni réseau.

if_pl <- function(ids = c("P1", "P2"), x = c(925000, 925200), y = 6700000) {
  sf::st_sf(plot_id = ids, wgt = 10, stratum = "s1",
            geometry = sf::st_sfc(lapply(seq_along(ids), function(i) sf::st_point(c(x[i], y))),
                                  crs = 2154))
}
if_carre <- function(x0, y0, x1, y1) {
  sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(x0, y0), c(x1, y0), c(x1, y1), c(x0, y1), c(x0, y0)))), crs = 2154))
}
if_mnt <- function(ext = terra::ext(924950, 925250, 6699950, 6700050)) {
  r <- terra::rast(ext, resolution = 1, crs = "EPSG:2154")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- 300 + 0.1 * (xy[, 2] - 6699950)
  r
}
if_mnh <- function(ext = terra::ext(924950, 925250, 6699950, 6700050)) {
  r <- terra::rast(ext, resolution = 0.5, crs = "EPSG:2154")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- 25 * exp(-((xy[, 1] %% 8 - 4)^2 + (xy[, 2] %% 8 - 4)^2) / 6)
  r
}

if_cones <- function(hauteurs) {
  n <- length(hauteurs)
  r <- terra::rast(nrows = 240, ncols = 80 * n, xmin = 0, xmax = 20 * n, ymin = 0, ymax = 60,
                   crs = "EPSG:2154")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  z <- rep(0, nrow(xy))
  for (i in seq_len(n)) {
    d2 <- (xy[, 1] - (20 * (i - 1) + 10))^2 + (xy[, 2] - 30)^2
    z <- pmax(z, hauteurs[i] * exp(-d2 / 18))
  }
  terra::values(r) <- z
  r
}

# ---- Emprise (cas 1 à 4) ----------------------------------------------

test_that("emprise : union des ugf + 50 m, élargie aux placettes", {
  pl <- if_pl()
  ugf <- if_carre(925000, 6700000, 925100, 6700100)
  e <- nemeton:::.iv_emprise(pl, list(ugf = ugf, parcelles = if_carre(0, 0, 10, 10)), 15, 10)
  bb <- sf::st_bbox(e)
  # ugf + 50 m a l'ouest ; la placette P2 (hors ugf) étend l'emprise à l'est
  expect_equal(unname(bb["xmin"]), 924950)
  expect_equal(unname(bb["xmax"]), 925225)
  # les parcelles (ailleurs) ne comptent pas quand il y a des ugf
  expect_false(isTRUE(sf::st_intersects(e, sf::st_sfc(sf::st_point(c(5, 5)), crs = 2154),
                                        sparse = FALSE)[1, 1]))
})

test_that("emprise : sans ugf, les parcelles + 50 m", {
  e <- nemeton:::.iv_emprise(if_pl(), list(ugf = NULL, parcelles = if_carre(925000, 6700000, 925100, 6700100)),
                             15, 10)
  expect_equal(unname(sf::st_bbox(e)["xmin"]), 924950)
  expect_equal(unname(sf::st_bbox(e)["ymax"]), 6700150)
})

test_that("emprise : ni ugf ni parcelles, placettes + rayon + marge", {
  e <- nemeton:::.iv_emprise(if_pl(), list(), 15, 10)
  bb <- sf::st_bbox(e)
  expect_equal(unname(bb[c("xmin", "xmax", "ymin", "ymax")]),
               c(924975, 925225, 6699975, 6700025))
})

test_that("emprise : une placette hors des ugf garde sa zone", {
  pl <- if_pl("P9", x = 930000)
  e <- nemeton:::.iv_emprise(pl, list(ugf = if_carre(925000, 6700000, 925100, 6700100)), 15, 10)
  expect_true(sf::st_intersects(e, sf::st_sfc(sf::st_point(c(930000, 6700000)), crs = 2154),
                                sparse = FALSE)[1, 1])
})

# ---- Dalles MNT (cas 5, 6, 7, 14) ---------------------------------------

test_that("dalles : nom du coin sud-ouest, pas de dalle vide au-delà d'une limite", {
  # emprise pile sur 925-926 km x 6700-6701 km
  e <- sf::st_geometry(if_carre(925000, 6700000, 926000, 6701000))
  d <- nemeton:::.iv_dalles_km(e)
  expect_equal(nrow(d), 1L)
  expect_equal(c(d$x, d$y), c(925, 6700))
  # à cheval sur x = 926 km : deux dalles
  e2 <- sf::st_geometry(if_carre(925900, 6700100, 926100, 6700200))
  expect_equal(nrow(nemeton:::.iv_dalles_km(e2)), 2L)
})

if_info <- function(f) paste(sf::gdal_utils("info", f, quiet = TRUE), collapse = "\n")

test_that("dalles : format exact (Float32, DEFLATE, sans prédicteur, non tuilé, nodata -9999, 2154)", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    dir.create("rasters")
    # LiDAR sur 100 m seulement ; emprise de 200 m de large
    dem <- if_mnt(terra::ext(925000, 925100, 6700000, 6700100))
    e <- sf::st_geometry(if_carre(925000, 6700000, 925200, 6700100))
    f <- nemeton:::.iv_ecrire_dalles_mnt(dem, e, ".")
    expect_identical(f, "rasters/mnt_0925_6700.tif")
    info <- if_info(f)
    expect_match(info, "Size is 2000, 2000", fixed = TRUE)
    expect_match(info, "Block=2000x1", fixed = TRUE)          # bandes, non tuilé
    expect_match(info, "Type=Float32", fixed = TRUE)
    expect_match(info, "NoData Value=-9999", fixed = TRUE)
    expect_match(info, "COMPRESSION=DEFLATE", fixed = TRUE)
    expect_match(info, "ID[\"EPSG\",2154]", fixed = TRUE)
    expect_no_match(info, "PREDICTOR=[23]")
    expect_match(info, "Pixel Size = (0.500000000000000,-0.500000000000000)", fixed = TRUE)
    expect_match(info, "Origin = (925000.000000000000000,6701000.000000000000000)", fixed = TRUE)
    # sous le LiDAR : valeur ; hors LiDAR mais dans l'emprise : nodata ; hors emprise : nodata
    r <- terra::rast(f)
    v <- terra::extract(r, cbind(c(925050, 925150, 925500), c(6700050, 6700050, 6700500)))[[1]]
    expect_false(is.na(v[1]))
    expect_true(is.na(v[2]))
    expect_true(is.na(v[3]))
  })
})

test_that("dalles : LiDAR sans aucun recouvrement avec une dalle -> dalle nodata, sans erreur", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    dir.create("rasters")
    dem <- if_mnt(terra::ext(925000, 925100, 6700000, 6700100))
    e <- sf::st_geometry(if_carre(926100, 6700100, 926200, 6700200))
    f <- expect_no_error(nemeton:::.iv_ecrire_dalles_mnt(dem, e, "."))
    r <- terra::rast(f)
    expect_true(all(is.na(terra::values(r))))
  })
})

# ---- Sommets (cas 9) ----------------------------------------------------

test_that("sommet : à l'intérieur du polygone, pour dalponte, silva et watershed", {
  skip_if_not_installed("lidR")
  skip_if_not_installed("stars")
  for (alg in c("dalponte", "silva", "watershed")) {
    h <- segment_houppiers(if_cones(c(25, 18, 12)), ws = 4, hmin = 3, algorithme = alg)
    expect_true(all(c("x_sommet", "y_sommet") %in% names(h)), info = alg)
    expect_gt(nrow(h), 0L)
    pts <- sf::st_as_sf(sf::st_drop_geometry(h), coords = c("x_sommet", "y_sommet"), crs = sf::st_crs(h))
    dedans <- diag(sf::st_within(pts, h, sparse = FALSE))
    expect_true(all(dedans), info = alg)
  }
})

test_that("sommet : pixel de h_max ; à égalité, la cellule la plus au nord puis à l'ouest", {
  r <- terra::rast(nrows = 6, ncols = 6, xmin = 0, xmax = 6, ymin = 0, ymax = 6, crs = "EPSG:2154")
  terra::values(r) <- 5
  r[2, 3] <- 9            # sommet unique
  poly <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(0, 0), c(6, 0), c(6, 6), c(0, 6), c(0, 0)))), crs = 2154))
  s <- nemeton:::.houppier_sommets(poly, r)
  expect_equal(c(s$x, s$y), c(2.5, 4.5))
  # plateau : première cellule dans l'ordre du raster (nord-ouest)
  terra::values(r) <- 9
  s2 <- nemeton:::.houppier_sommets(poly, r)
  expect_equal(c(s2$x, s2$y), c(0.5, 5.5))
})

test_that("segment_houppiers : zéro houppier garde les colonnes de sommet", {
  skip_if_not_installed("lidR")
  h <- segment_houppiers(if_cones(c(25, 18)), ws = 4, hmin = 3, h_range = c(30, 70))
  expect_true(all(c("x_sommet", "y_sommet") %in% names(h)))
})

# ---- CVAT (cas 11, 12, 13) ----------------------------------------------

if_cvat_float <- function(vals, ext = terra::ext(925000, 925100, 6700000, 6700100), crs = "EPSG:2154") {
  r <- terra::rast(ext, resolution = 2, crs = crs)
  terra::values(r) <- rep_len(vals, terra::ncell(r))
  r
}

test_that("cvat : Byte, DEFLATE, nodata 0 déclaré, flottant [0, 1] -> 1 + round(v * 254), NA -> 0", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    dir.create("rasters")
    # une valeur par colonne de 2 m : 0, 0.5, 1, 0.2, 0.8, NA
    ext <- terra::ext(925000, 925012, 6700000, 6700002)
    src <- terra::rast(ext, resolution = 2, crs = "EPSG:2154")
    terra::values(src) <- c(0, 0.5, 1, 0.2, 0.8, NA)
    terra::writeRaster(src, "src.tif", overwrite = TRUE)
    e <- sf::st_geometry(if_carre(925000, 6700000, 925020, 6700002))   # dépasse le CVAT
    f <- nemeton:::.iv_ecrire_cvat("src.tif", e, ".")
    expect_identical(f, "rasters/cvat.tif")
    info <- if_info(f)
    expect_match(info, "Type=Byte", fixed = TRUE)
    expect_match(info, "NoData Value=0", fixed = TRUE)
    expect_match(info, "COMPRESSION=DEFLATE", fixed = TRUE)
    expect_match(info, "ID[\"EPSG\",2154]", fixed = TRUE)
    expect_match(info, "Pixel Size = (2.000000000000000,-2.000000000000000)", fixed = TRUE)
    r <- terra::rast(f)
    # le 0 déclaré nodata est lu NA par terra : on le remet à 0 pour comparer
    zero <- function(x) { x <- unname(x); x[is.na(x)] <- 0; x }
    v <- unlist(terra::extract(r, cbind(925000 + 2 * (0:5) + 1, 6700001)))
    # 0 -> 1 ; 0.5 -> 128 ; 1 -> 255 ; 0.2 -> 1 + 51 ; 0.8 -> 1 + 203 ; NA -> 0
    expect_equal(zero(v), c(1, 128, 255, 52, 204, 0))
    # hors de la couverture du CVAT : 0 (nodata)
    expect_equal(zero(unlist(terra::extract(r, cbind(925015, 6700001)))), 0)
  })
})

# Rasters Byte synthétiques : `nodata` déclaré (NA = aucun), grille 2 m par défaut.
if_cvat_octets <- function(nom, vals, nodata, res = 2, type = "INT1U",
                           ext = NULL, crs = "EPSG:2154") {
  n <- length(vals)
  if (is.null(ext)) ext <- terra::ext(925000, 925000 + n * res, 6700000, 6700000 + res)
  r <- terra::rast(ext, resolution = res, crs = crs)
  terra::values(r) <- rep_len(vals, terra::ncell(r))
  terra::writeRaster(r, nom, overwrite = TRUE, datatype = type, NAflag = nodata)
  nom
}

if_lire_cvat <- function(f) {
  v <- terra::values(terra::rast(f), mat = FALSE)
  v[is.na(v)] <- 0                    # le 0 déclaré nodata est lu NA par terra
  v
}

test_that("cvat Byte foretaccess (nodata 255) : source + 1, 255 -> 0 (cas 1)", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    dir.create("rasters")
    if_cvat_octets("fa.tif", c(0, 127, 254, 255), nodata = 255)
    e <- sf::st_geometry(if_carre(925000, 6700000, 925008, 6700002))
    f <- nemeton:::.iv_ecrire_cvat("fa.tif", e, ".")
    expect_identical(f, "rasters/cvat.tif")
    expect_equal(if_lire_cvat(f), c(1, 128, 255, 0))
    expect_match(if_info(f), "Type=Byte", fixed = TRUE)
    expect_match(if_info(f), "NoData Value=0", fixed = TRUE)
  })
})

test_that("cvat Byte déjà au format Groma (nodata 0) : recopié sans changement de valeur (cas 2)", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    dir.create("rasters")
    if_cvat_octets("gr.tif", c(1, 128, 254, 255, 0), nodata = 0)
    e <- sf::st_geometry(if_carre(925000, 6700000, 925010, 6700002))
    f <- nemeton:::.iv_ecrire_cvat("gr.tif", e, ".")
    expect_equal(if_lire_cvat(f), c(1, 128, 254, 255, 0))
  })
})

test_that("cvat flottant [0, 1] : 1 + round(v * 254), NA -> 0, bornes 0 et 1 admises (cas 3)", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    dir.create("rasters")
    src <- terra::rast(terra::ext(925000, 925008, 6700000, 6700002), resolution = 2, crs = "EPSG:2154")
    terra::values(src) <- c(0, 1, 0.5, NA)
    terra::writeRaster(src, "fl.tif", overwrite = TRUE)
    e <- sf::st_geometry(if_carre(925000, 6700000, 925008, 6700002))
    f <- nemeton:::.iv_ecrire_cvat("fl.tif", e, ".")
    expect_equal(if_lire_cvat(f), c(1, 255, 128, 0))
  })
})

test_that("cvat : codage non reconnu -> erreur de classe dédiée, aucun cvat.tif (cas 4)", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    dir.create("rasters")
    e <- sf::st_geometry(if_carre(925000, 6700000, 925008, 6700002))
    mauvais <- list(
      octet_sans_nodata = if_cvat_octets("a.tif", c(10, 20, 30, 40), nodata = NA),
      octet_autre_nodata = if_cvat_octets("a2.tif", c(10, 20, 30, 40), nodata = 7),
      int16 = if_cvat_octets("b.tif", c(10, 20, 30, 40), nodata = -1, type = "INT2S"),
      float_hors_01 = if_cvat_octets("c.tif", c(-0.5, 0.2, 1.7, 0.4), nodata = NA, type = "FLT4S"),
      octet_5_m = if_cvat_octets("d.tif", c(10, 20), nodata = 255, res = 5,
                                 ext = terra::ext(925000, 925010, 6700000, 6700005)),
      octet_4326 = if_cvat_octets("e.tif", c(10, 20), nodata = 255, crs = "EPSG:4326",
                                  ext = terra::ext(3, 3.0003, 47, 47.0003)))
    for (n in names(mauvais)) {
      expect_error(nemeton:::.iv_ecrire_cvat(mauvais[[n]], e, "."),
                   class = "nemeton_erreur_cvat_codage", info = n)
    }
    writeLines("pas un raster", "faux.tif")
    expect_error(nemeton:::.iv_ecrire_cvat("faux.tif", e, "."),
                 class = "nemeton_erreur_cvat_codage")
    expect_false(file.exists("rasters/cvat.tif"))
  })
})

test_that("cvat Byte de nemetonshiny : marqueur NA retiré avant le rééchantillonnage", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    dir.create("rasters")
    # grille 2 m DÉCALÉE d'1 m en x par rapport à la grille de sortie (qui
    # s'aligne sur les multiples de 2 m) ; relief 200, zone NA (255) au milieu
    r <- terra::rast(terra::ext(925001, 925101, 6700000, 6700100), resolution = 2, crs = "EPSG:2154")
    m <- matrix(200L, nrow = 50, ncol = 50)
    m[20:30, 20:30] <- 255L
    terra::values(r) <- as.vector(t(m))
    terra::writeRaster(r, "b.tif", overwrite = TRUE, datatype = "INT1U", NAflag = 255)
    # emprise décalée d'1 m : grille de sortie décalée par rapport à la source
    e <- sf::st_geometry(if_carre(925001, 6700001, 925099, 6700099))
    f <- nemeton:::.iv_ecrire_cvat("b.tif", e, ".")
    v <- terra::values(terra::rast(f), mat = FALSE)
    v[is.na(v)] <- 0
    attendu <- 200 + 1                              # source + 1
    expect_setequal(unique(v), c(0, attendu))      # aucune valeur intermédiaire
    expect_gt(sum(v == 0), 0L)                      # la zone NA existe bien
  })
})

test_that("cvat : reprojeté quand il n'est pas en EPSG:2154", {
  skip_if_terra_write_broken()
  withr::with_tempdir({
    dir.create("rasters")
    src <- if_cvat_float(0.5)
    src <- terra::project(src, "EPSG:4326")
    terra::writeRaster(src, "g.tif", overwrite = TRUE)
    e <- sf::st_geometry(if_carre(925020, 6700020, 925080, 6700080))
    f <- nemeton:::.iv_ecrire_cvat("g.tif", e, ".")
    r <- terra::rast(f)
    expect_true(terra::same.crs(r, "EPSG:2154"))
    expect_true(128 %in% terra::values(r, mat = FALSE))
  })
})

test_that("cvat_path absent : avertissement ; illisible : erreur ; pas de cvat.tif", {
  withr::with_tempdir({
    dir.create("rasters")
    e <- sf::st_geometry(if_carre(925000, 6700000, 925100, 6700100))
    expect_warning(r <- nemeton:::.iv_ecrire_cvat("nexiste_pas.tif", e, "."), "cvat_path")
    expect_null(r)
    writeLines("pas un raster", "faux.tif")
    expect_error(nemeton:::.iv_ecrire_cvat("faux.tif", e, "."), class = "nemeton_erreur_cvat_codage")
    expect_false(file.exists("rasters/cvat.tif"))
  })
})

# ---- Projet complet (cas 8, 10, 12, 14, 15, 16, 17) ---------------------

if_creer <- function(sortie, ..., pl = if_pl()) {
  suppressWarnings(creer_projet_inventaire_video(
    pl, dem = if_mnt(), chm = if_mnh(), output_dir = sortie, ...))
}

test_that("projet : houppiers sur toute l'emprise, plot_id NULL hors placette, sommets, index", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    qgz <- if_creer("sortie")
    utils::unzip(qgz, exdir = "x")
    gpkg <- file.path("x", "inventaire_video.gpkg")
    h <- sf::st_read(gpkg, layer = "houppiers", quiet = TRUE)
    expect_true(all(c("x_sommet", "y_sommet") %in% names(h)))
    # emprise = zones des placettes seulement (25 m) : houppiers hors placette
    # possibles à la marge d'un houppier qui dépasse la zone ; ici on exige
    # surtout des plot_id renseignés ET la règle NA sur un cas construit
    expect_true(any(!is.na(h$plot_id)))
    pts <- sf::st_as_sf(sf::st_drop_geometry(h), coords = c("x_sommet", "y_sommet"), crs = 2154)
    expect_true(all(diag(sf::st_within(pts, h, sparse = FALSE))))
    expect_false(anyDuplicated(h$houppier_id) > 0)
    con <- DBI::dbConnect(RSQLite::SQLite(), gpkg)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    idx <- DBI::dbGetQuery(con, "PRAGMA index_info('idx_houppiers_x_sommet_y_sommet')")
    expect_equal(idx$name, c("x_sommet", "y_sommet"))
  })
})

test_that("projet : houppier hors de toute placette écrit avec plot_id NULL", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    # Une placette, et des ugf (projet nemetonshiny) qui débordent largement : on
    # teste la règle directement sur l'assignation.
    pl <- if_pl("P1", x = 925000)
    e <- sf::st_geometry(if_carre(924950, 6699950, 925250, 6700050))
    h <- nemeton:::.iv_houppiers_emprise(if_mnh(), e, pl, 25)
    expect_true(any(is.na(h$plot_id)))
    expect_true(any(!is.na(h$plot_id)))
    expect_true(all(h$plot_id[!is.na(h$plot_id)] == "P1"))
    # le houppier écrit dans le GeoPackage garde NULL
    h2 <- nemeton:::.iv_conformer(h, schema_inventaire_video("houppiers"), "POLYGON")
    nemeton:::.iv_ecrire_couche(h2, "t.gpkg", "houppiers", TRUE)
    lu <- sf::st_read("t.gpkg", layer = "houppiers", quiet = TRUE)
    expect_true(any(is.na(lu$plot_id)))
  })
})

test_that("projet : dalles MNT à plat dans le dossier et le .qgz, aucune dalle MNH, rasters par placette", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    qgz <- if_creer("sortie")
    contenu <- utils::unzip(qgz, list = TRUE)$Name
    dalles <- grep("^rasters/mnt_[0-9]{4}_[0-9]{4}\\.tif$", contenu, value = TRUE)
    expect_gt(length(dalles), 0L)
    expect_true("rasters/mnt_0925_6700.tif" %in% dalles)
    expect_false(any(grepl("mnh_[0-9]", contenu)))
    expect_false(any(grepl("^rasters/.+/", contenu)))     # aucun sous-dossier
    expect_true(all(c("rasters/P1_mnt.tif", "rasters/P1_mnh.tif",
                      "rasters/P2_mnt.tif", "rasters/P2_mnh.tif") %in% contenu))
    expect_false("rasters/cvat.tif" %in% contenu)           # cas 12 : sans cvat_path
    dossier <- file.path("sortie", "inventaire_video", "rasters")
    expect_true(all(basename(dalles) %in% list.files(dossier)))
    # les dalles sont dans la légende du .qgz
    utils::unzip(qgz, exdir = "x")
    qgs <- paste(readLines(file.path("x", "inventaire_video.qgs"), warn = FALSE), collapse = "\n")
    expect_match(qgs, "mnt_0925_6700")
    # chaque dalle : même format que rasters.format
    r <- terra::rast(file.path("x", dalles[1]))
    expect_equal(dim(r)[1:2], c(2000L, 2000L))
    expect_equal(terra::datatype(r), "FLT4S")
  })
})

# Empreinte des rasters par placette, calculée avec le code de `origin/main`
# (70618fd) sur le même jeu synthétique : md5 des valeurs écrites à 4 décimales.
if_empreinte <- function(f) {
  t <- tempfile(fileext = ".txt")
  writeLines(sprintf("%.4f", terra::values(terra::rast(f), mat = FALSE)), t)
  unname(tools::md5sum(t))
}

test_that("projet : cvat_path -> cvat.tif dans le .qgz et le dossier ; rasters par placette identiques à main", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    terra::writeRaster(if_cvat_float(0.5, terra::ext(924950, 925250, 6699950, 6700050)),
                       "cvat_src.tif", overwrite = TRUE)
    avec <- if_creer("avec", cvat_path = "cvat_src.tif")
    expect_true("rasters/cvat.tif" %in% utils::unzip(avec, list = TRUE)$Name)
    expect_true(file.exists(file.path("avec", "inventaire_video", "rasters", "cvat.tif")))
    utils::unzip(avec, exdir = "a")
    attendu <- c(P1_mnt = "77ef55bb6c31561245b8e9ce0a3f16d8",
                 P1_mnh = "fa34d1dea424481b71a39070ad8ee384",
                 P2_mnt = "77ef55bb6c31561245b8e9ce0a3f16d8",
                 P2_mnh = "fa34d1dea424481b71a39070ad8ee384")
    for (n in names(attendu)) {
      expect_identical(if_empreinte(file.path("a", "rasters", paste0(n, ".tif"))), attendu[[n]], info = n)
    }
  })
})

test_that("houppier touchant deux placettes : deux lignes ; hors placette : une ligne NA", {
  skip_if_not_installed("lidR")
  pl <- if_pl(c("P1", "P2"), x = c(925000, 925030))     # zones de 25 m qui se recouvrent
  e <- sf::st_geometry(if_carre(924950, 6699950, 925100, 6700050))
  h <- nemeton:::.iv_houppiers_emprise(if_mnh(), e, pl, 25)
  par_houppier <- split(h$plot_id, h$houppier_id)
  expect_true(any(vapply(par_houppier, function(p) sum(!is.na(p)) == 2L, logical(1))))
  # hors de toute placette : exactement une ligne, plot_id NA
  seul <- Filter(function(p) any(is.na(p)), par_houppier)
  expect_gt(length(seul), 0L)
  expect_true(all(lengths(seul) == 1L))
  # une ligne par placette touchée, jamais deux fois la même
  expect_false(any(duplicated(h[!is.na(h$plot_id), c("plot_id", "houppier_id")] |> sf::st_drop_geometry())))
  # même houppier -> même géométrie
  par_geom <- tapply(sf::st_as_text(sf::st_geometry(h)), h$houppier_id, function(g) length(unique(g)))
  expect_true(all(par_geom == 1L))
})

test_that("sommet LSMS : dans le polygone, pixel du h_max (OTB mis à l'écart)", {
  skip_if_not(nzchar(nemeton:::.lsms_otb_dir()), "needs an OTB installation")
  skip_if_not_installed("terra")
  chm <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 10, ymin = 0, ymax = 10,
                     crs = "EPSG:2154")
  terra::values(chm) <- 8
  chm[3, 4] <- 20                                        # sommet du segment 1
  chm[15, 15] <- 18                                      # sommet du segment 2
  img <- chm
  # OTB n'est pas lancé : on lui substitue deux segments connus
  testthat::local_mocked_bindings(
    .lsms_executer = function(image_path, sortie_shp, ...) {
      sq <- function(x0, y0, x1, y1) sf::st_polygon(list(rbind(
        c(x0, y0), c(x1, y0), c(x1, y1), c(x0, y1), c(x0, y0))))
      sf::st_write(sf::st_sf(DN = 1:2, geometry = sf::st_sfc(
        sq(0, 5, 5, 10), sq(5, 0, 10, 5), crs = 2154)), sortie_shp, quiet = TRUE)
    },
    .package = "nemeton")
  h <- segment_houppiers(chm, image = img, algorithme = "lsms", usage = "martelage",
                         budget_s = 0)
  expect_equal(nrow(h), 2L)
  expect_true(all(c("x_sommet", "y_sommet") %in% names(h)))
  pts <- sf::st_as_sf(sf::st_drop_geometry(h), coords = c("x_sommet", "y_sommet"), crs = 2154)
  expect_true(all(diag(sf::st_within(pts, h, sparse = FALSE))))
  expect_equal(c(h$x_sommet[1], h$y_sommet[1]), c(1.75, 8.75))   # h_max 20
  expect_equal(c(h$x_sommet[2], h$y_sommet[2]), c(7.25, 2.75))   # h_max 18
})

test_that("projet : cvat_path illisible n'empêche pas le projet", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    expect_warning(qgz <- creer_projet_inventaire_video(
      if_pl(), dem = if_mnt(), chm = if_mnh(), cvat_path = "absent.tif",
      output_dir = "sortie"), "cvat_path")
    expect_true(file.exists(qgz))
    expect_false("rasters/cvat.tif" %in% utils::unzip(qgz, list = TRUE)$Name)
  })
})

test_that("projet : cvat_path mal codé -> erreur, ni .qgz ni dossier de projet (cas 4)", {
  skip_if_not_installed("RSQLite")
    skip_if_terra_write_broken()
  withr::with_tempdir({
    if_cvat_octets("sans_nodata.tif", c(10, 20, 30, 40), nodata = NA,
                   ext = terra::ext(924950, 925250, 6699950, 6699952))
    expect_error(creer_projet_inventaire_video(
      if_pl(), dem = if_mnt(), cvat_path = "sans_nodata.tif",
      output_dir = "sortie"), class = "nemeton_erreur_cvat_codage")
    expect_length(list.files("sortie", recursive = TRUE, all.files = TRUE), 0L)
  })
})

test_that("projet : cvat_path foretaccess -> cvat.tif source + 1 dans le projet (cas 1)", {
  skip_if_not_installed("RSQLite")
    skip_if_terra_write_broken()
  withr::with_tempdir({
    r <- terra::rast(terra::ext(924950, 925250, 6699950, 6700050), resolution = 2, crs = "EPSG:2154")
    terra::values(r) <- 200
    terra::writeRaster(r, "fa.tif", overwrite = TRUE, datatype = "INT1U", NAflag = 255)
    qgz <- suppressWarnings(creer_projet_inventaire_video(if_pl(), dem = if_mnt(), cvat_path = "fa.tif", output_dir = "fa_out"))
    utils::unzip(qgz, files = "rasters/cvat.tif", exdir = "x")
    v <- terra::values(terra::rast("x/rasters/cvat.tif"), mat = FALSE)
    expect_true(201 %in% v)
    expect_false(200 %in% v)
  })
})

test_that("projet 1.6.0 (sans sommets) et 1.7.0 restent lisibles par nemeton", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  # 1.6.0 : l'exemple du dépôt
  g <- import_qgis_gpkg(testthat::test_path("fixtures", "inventaire_video", "inventaire_video.gpkg"))
  expect_gt(nrow(g$placettes), 0L)
  withr::with_tempdir({
    qgz <- if_creer("sortie")
    utils::unzip(qgz, exdir = "x")
    g2 <- import_qgis_gpkg(file.path("x", "inventaire_video.gpkg"))
    expect_gt(nrow(g2$placettes), 0L)
    r <- suppressWarnings(importer_inventaire_video(file.path("x", "inventaire_video.gpkg")))
    expect_s3_class(r$placettes, "sf")
  })
})

test_that("sommet LSMS « couvert » : pixel du CHM s'il est fourni, absent sans CHM", {
  skip_if_not(nzchar(nemeton:::.lsms_otb_dir()), "needs an OTB installation")
  skip_if_not_installed("terra")
  chm <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 10, ymin = 0, ymax = 10,
                     crs = "EPSG:2154")
  terra::values(chm) <- 8
  chm[3, 4] <- 20
  chm[15, 15] <- 18
  testthat::local_mocked_bindings(
    .lsms_executer = function(image_path, sortie_shp, ...) {
      sq <- function(x0, y0, x1, y1) sf::st_polygon(list(rbind(
        c(x0, y0), c(x1, y0), c(x1, y1), c(x0, y1), c(x0, y0))))
      sf::st_write(sf::st_sf(DN = 1:2, geometry = sf::st_sfc(
        sq(0, 5, 5, 10), sq(5, 0, 10, 5), crs = 2154)), sortie_shp, quiet = TRUE)
    },
    .package = "nemeton")
  h <- segment_houppiers(chm, image = chm, algorithme = "lsms", usage = "couvert", budget_s = 0)
  expect_false("h_max" %in% names(h))
  expect_true(all(c("x_sommet", "y_sommet") %in% names(h)))
  pts <- sf::st_as_sf(sf::st_drop_geometry(h), coords = c("x_sommet", "y_sommet"), crs = 2154)
  expect_true(all(diag(sf::st_within(pts, h, sparse = FALSE))))
  expect_setequal(paste(h$x_sommet, h$y_sommet), c("1.75 8.75", "7.25 2.75"))
  # sans CHM : pas de hauteur, donc pas de sommet
  h0 <- segment_houppiers(chm = NULL, image = chm, algorithme = "lsms", usage = "couvert",
                          budget_s = 0)
  expect_false(any(c("h_max", "x_sommet", "y_sommet") %in% names(h0)))
})
