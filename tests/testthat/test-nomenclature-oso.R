# Nomenclature OSO 23 classes partagee (audit 1.0) : L1, L2, A1, RECONFORT et
# FR.json doivent lire les memes codes (16 = feuillus, 17 = coniferes).

test_that("OSO nomenclature has the 23 Theia/CESBIO classes", {
  expect_equal(OSO_NOMENCLATURE$code, 1:23)
  expect_equal(OSO_NOMENCLATURE$cle[OSO_NOMENCLATURE$code %in% OSO_CLASSES_FORET],
               c("foret_feuillus", "foret_coniferes"))
  expect_equal(OSO_NOMENCLATURE$cle[18], "pelouses")
  expect_equal(OSO_CLASSE_FEUILLUS, OSO_CLASSES_FORET[["foret_feuillus"]])
})

test_that("forest defaults of L1, L2, A1 and RECONFORT use the shared OSO codes", {
  foret <- as.numeric(OSO_CLASSES_FORET)
  for (f in c("indicateur_l1_effet_lisiere", "indicateur_l2_morcellement",
              "indicateur_l2_fragmentation", "indicateur_l1_sylvosphere")) {
    expect_equal(eval(formals(get(f))$forest_values), foret, info = f)
  }
  expect_equal(eval(formals(indicateur_a1_couverture)$forest_classes), foret)
  expect_equal(eval(formals(.reconfort_oso_broadleaf_mask)$broadleaf_class),
               OSO_CLASSE_FEUILLUS)
})

test_that("FR.json OSO forest classes match the shared nomenclature", {
  oso <- get_data_source("oso", "FR")
  expect_setequal(as.integer(names(oso$forest_classes)),
                  as.integer(OSO_CLASSES_FORET))
})

test_that("A1 no longer counts OSO grassland (18) as forest", {
  units <- create_test_units(n_features = 1)
  r <- terra::rast(xmin = 565000, xmax = 568500, ymin = 6613500,
                   ymax = 6617000, resolution = 50, crs = "EPSG:2154")
  terra::values(r) <- 18L
  res <- suppressMessages(indicateur_a1_couverture(units, land_cover = r))
  expect_equal(res$A1, 0)
  terra::values(r) <- 17L
  res <- suppressMessages(indicateur_a1_couverture(units, land_cover = r))
  expect_equal(res$A1, 100)
})

test_that("L1 reads the edge matrix with the OSO 23-class contrast table", {
  local_mocked_bindings(get_nasapower_wind = function(...) 225)
  units <- create_test_units(n_features = 1)
  r <- terra::rast(xmin = 566000, xmax = 567000, ymin = 6614800,
                   ymax = 6615800, resolution = 10, crs = "EPSG:2154")
  l1_with <- function(code) {
    terra::values(r) <- code
    lay <- structure(list(rasters = list(landcover = r)),
                     class = "nemeton_layers")
    suppressMessages(indicateur_l1_effet_lisiere(units, lay)$L1)
  }
  foret <- l1_with(16L)
  # Bati dense (1) : contraste 90 (avant : code inconnu -> 50)
  expect_equal(l1_with(1L) - foret, 0.4 * 90, tolerance = 0.11)
  # Pelouses (18) : contraste 20 (avant : comptees comme foret -> 0)
  expect_equal(l1_with(18L) - foret, 0.4 * 20, tolerance = 0.11)
  # Coniferes (17) : foret, contraste nul
  expect_equal(l1_with(17L), foret)
})
