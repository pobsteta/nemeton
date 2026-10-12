# T2 mesuré sur une série FORMS-T (spec 060)

# Série synthétique de 20 x 10 pixels de 10 m, 2019 à 2024, en cm.
# - moitié ouest (colonnes 1-10) : couvert stable qui pousse de 30 cm/an ;
# - moitié est (colonnes 11-20) : coupée en 2022 (25 m -> 1 m, puis repousse
#   lente), sauf la ligne 1, qui fait un creux d'un an en 2021 puis revient ;
# - ligne 10, colonnes 11-20 : lande basse (2 m), hors couvert.
.t2_serie <- function() {
  annees <- 2019:2024
  r <- terra::rast(nrows = 10, ncols = 20, xmin = 800000, xmax = 800200,
                   ymin = 6600000, ymax = 6600100, crs = "EPSG:2154",
                   nlyrs = length(annees))
  vals <- sapply(seq_along(annees), function(k) {
    m <- matrix(0, 10, 20)
    m[, 1:10] <- 2000 + 30 * (k - 1)
    m[, 11:20] <- if (annees[k] < 2022) 2500 else 100 + 50 * (annees[k] - 2022)
    m[1, 11:20] <- if (annees[k] == 2021) 1000 else 2500
    m[10, 11:20] <- 200
    as.vector(t(m))
  })
  terra::values(r) <- vals
  names(r) <- annees
  r
}

.t2_unites <- function() {
  ouest <- sf::st_polygon(list(rbind(c(800000, 6600000), c(800100, 6600000),
                                     c(800100, 6600100), c(800000, 6600100),
                                     c(800000, 6600000))))
  est <- sf::st_polygon(list(rbind(c(800100, 6600000), c(800200, 6600000),
                                   c(800200, 6600100), c(800100, 6600100),
                                   c(800100, 6600000))))
  sf::st_sf(id = c("ouest", "est"), geometry = sf::st_sfc(ouest, est, crs = 2154))
}

test_that("T2 measures canopy stability from FORMS-T", {
  skip_if_not_installed("exactextractr")
  res <- indicateur_t2_changement(.t2_unites(), forms_t = .t2_serie())
  expect_s3_class(res, "sf")
  expect_equal(res$t2_status, c("forms_t", "forms_t"))
  # Ouest : aucun pixel en perte, croissance 0,3 m/an.
  expect_equal(res$T2[1], 100)
  expect_equal(res$t2_perte_pct[1], 0)
  expect_equal(res$t2_croissance_m_an[1], 0.3)
  # Est : 8 lignes coupées sur 9 lignes de couvert (le creux d'un an de la
  # ligne 1 ne compte pas, la lande de la ligne 10 est hors couvert).
  expect_equal(res$t2_perte_pct[2], 100 * 8 / 9, tolerance = 1e-6)
  expect_equal(res$T2[2], 100 / 9, tolerance = 1e-6)
  # Le creux d'un an revient à 25 m : pente nulle sur le couvert sans perte.
  expect_equal(res$t2_croissance_m_an[2], 0)
  expect_equal(res$t2_annees, c("2019-2024", "2019-2024"))
})

test_that("T2 threshold and height unit are honoured", {
  skip_if_not_installed("exactextractr")
  serie_m <- .t2_serie() / 100
  names(serie_m) <- 2019:2024
  res_m <- indicateur_t2_changement(.t2_unites(), forms_t = serie_m,
                                    unite_hauteur = "m")
  res_cm <- indicateur_t2_changement(.t2_unites(), forms_t = .t2_serie())
  expect_equal(res_m$T2, res_cm$T2)
  # Seuil de 16 m : le creux de 2021 (25 -> 10 m) reste sous le seuil et
  # la coupe (25 -> 1 m) le dépasse toujours.
  res_16 <- indicateur_t2_changement(.t2_unites(), forms_t = .t2_serie(),
                                     seuil_perte = 16)
  expect_equal(res_16$T2, res_cm$T2)
  # Seuil de 30 m : plus aucune perte.
  res_30 <- indicateur_t2_changement(.t2_unites(), forms_t = .t2_serie(),
                                     seuil_perte = 30)
  expect_true(all(is.na(res_30$T2) | res_30$T2 == 100))
})

test_that("T2 without FORMS-T is unchanged (proxy, no extra column)", {
  u <- .t2_unites()
  u$N2 <- c(80, NA)
  u$T1 <- c(NA, 40)
  res <- indicateur_t2_changement(u)
  expect_equal(res$T2, c(80, 40))
  expect_false(any(grepl("^t2_", names(res))))
})

test_that("T2 falls back on the proxy for a unit outside the series", {
  skip_if_not_installed("exactextractr")
  u <- .t2_unites()
  loin <- sf::st_polygon(list(rbind(c(900000, 6700000), c(900100, 6700000),
                                    c(900100, 6700100), c(900000, 6700100),
                                    c(900000, 6700000))))
  u <- rbind(u, sf::st_sf(id = "loin", geometry = sf::st_sfc(loin, crs = 2154)))
  u$N2 <- c(10, 10, 70)
  res <- indicateur_t2_changement(u, forms_t = .t2_serie())
  expect_equal(res$t2_status, c("forms_t", "forms_t", "proxy"))
  expect_equal(res$T2[3], 70)
  expect_true(is.na(res$t2_perte_pct[3]))
  expect_true(is.na(res$t2_annees[3]))
  # Sans proxy non plus : no_source.
  u$N2 <- NULL
  res2 <- indicateur_t2_changement(u, forms_t = .t2_serie())
  expect_equal(res2$t2_status[3], "no_source")
  expect_true(is.na(res2$T2[3]))
})

test_that("T2 reads a forms_t raster from layers", {
  skip_if_not_installed("exactextractr")
  lay <- structure(list(rasters = list(forms_t = .t2_serie())),
                   class = "nemeton_layers")
  res <- indicateur_t2_changement(.t2_unites(), layers = lay)
  expect_equal(res$T2[1], 100)
  expect_equal(res$t2_status, c("forms_t", "forms_t"))
})

test_that("T2 rejects a malformed FORMS-T series", {
  s <- .t2_serie()
  names(s) <- paste0("couche", letters[1:6])
  expect_error(indicateur_t2_changement(.t2_unites(), forms_t = s), "named by year")
  expect_error(indicateur_t2_changement(.t2_unites(), forms_t = .t2_serie()[[1:2]]),
               "at least three years")
})

test_that("charger_forms_t_hauteurs reads local yearly files", {
  skip_if_terra_write_broken()
  dossier <- withr::local_tempdir()
  s <- .t2_serie()
  for (k in c(1, 2, 4, 5)) {
    terra::writeRaster(s[[k]], file.path(dossier, sprintf("Height_%s.tif", names(s)[k])))
  }
  aoi <- .t2_unites()
  # Pas de réseau dans les tests : Theia est simulé hors ligne.
  local_mocked_bindings(load_theia_source = function(...) stop("hors ligne"))
  # 2021 et 2024 absents : avertis et sautés, les autres lus et triés.
  avis <- character(0)
  h <- withCallingHandlers(
    charger_forms_t_hauteurs(aoi, 2019:2024, dossier = dossier),
    warning = function(w) {
      avis <<- c(avis, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_length(avis, 2L)
  expect_match(avis[1], "2021")
  expect_match(avis[2], "2024")
  expect_s4_class(h, "SpatRaster")
  expect_equal(names(h), c("2019", "2020", "2022", "2023"))
  expect_equal(terra::nrow(h), 10)
  # Moins de trois années : NULL avec avertissement.
  expect_null(suppressWarnings(
    charger_forms_t_hauteurs(aoi, c(2019, 2021, 2024), dossier = dossier)
  ))
  expect_error(charger_forms_t_hauteurs("pas un sf"), "sf")
})
