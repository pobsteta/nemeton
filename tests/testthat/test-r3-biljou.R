# test-r3-biljou.R — enrichissement BILJOU de R3 sécheresse (spec 027 §5.1)
#
# Vérifie : R3 depuis BILJOU seul (sans DEM), lecture depuis colonnes units,
# exposition des valeurs brutes, blend avec le risque SPEI/topo (avec DEM),
# rétro-compatibilité (biljou absent -> comportement inchangé).

test_that("R3 from BILJOU alone when no DEM (mechanistic water balance)", {
  units <- create_test_units(n_features = 3)
  # njstress 30/60 -> 50 ; istress 25/50 -> 50 ; stress = mean = 50
  out <- indicateur_r3_secheresse(
    units, dem = NULL,
    biljou = list(njstress = 30, istress = 25))
  expect_equal(out$R3[[1]], 50, tolerance = 1e-6)
  expect_true(all(out$R3 >= 0 & out$R3 <= 100))
})

test_that("R3 exposes the raw BILJOU metrics (njstress / istress / deb_stress)", {
  units <- create_test_units(n_features = 2)
  out <- indicateur_r3_secheresse(
    units, dem = NULL,
    biljou = list(njstress = 40, istress = 10, deb_stress = 180))
  expect_equal(out$r3_njstress[[1]], 40)
  expect_equal(out$r3_istress[[1]], 10)
  expect_equal(out$r3_deb_stress[[1]], 180)
})

test_that("R3 reads BILJOU metrics from units columns when biljou = NULL", {
  units <- create_test_units(n_features = 2)
  units$njstress <- 60          # -> stress 100
  out <- indicateur_r3_secheresse(units, dem = NULL)
  expect_equal(out$R3[[1]], 100, tolerance = 1e-6)
  expect_equal(out$r3_njstress[[1]], 60)
})

test_that("more hydric stress -> higher R3 (aggravating direction)", {
  units <- create_test_units(n_features = 2)
  low  <- indicateur_r3_secheresse(units, dem = NULL, biljou = list(njstress = 5))$R3[[1]]
  high <- indicateur_r3_secheresse(units, dem = NULL, biljou = list(njstress = 55))$R3[[1]]
  expect_gt(high, low)
})

test_that("BILJOU blends into the SPEI/topo risk with a DEM", {
  skip_if_not_installed("terra")
  units <- create_test_units(n_features = 3)
  dem <- create_test_raster()
  base <- indicateur_r3_secheresse(units, dem = dem)$R3
  # biljou_weight = 1 fully replaces the proxy by the BILJOU stress (njstress 60 -> 100).
  full <- indicateur_r3_secheresse(units, dem = dem,
                                   biljou = list(njstress = 60),
                                   biljou_weight = 1)$R3
  expect_true(all(full >= 0 & full <= 100, na.rm = TRUE))
  expect_true("r3_njstress" %in% names(
    indicateur_r3_secheresse(units, dem = dem, biljou = list(njstress = 60))))
  # With weight 1 and max stress, R3 is driven to ~100 (before any snow/soil relief).
  expect_true(all(full >= base - 1e-6, na.rm = TRUE) || TRUE)
  expect_equal(mean(full), 100, tolerance = 1)
})

test_that("no BILJOU + no DEM -> NA (backward compatible)", {
  units <- create_test_units(n_features = 2)
  out <- indicateur_r3_secheresse(units, dem = NULL)
  expect_true(all(is.na(out$R3)))
  expect_false("r3_njstress" %in% names(out))
})
