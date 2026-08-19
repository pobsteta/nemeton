# test-load-onf-parcelles.R — parcellaire forestier public ONF (spec 046)
#
# Le WFS réel n'est pas joué en CI : .onf_wfs_read() est mocké. On teste la
# validation d'entrées, la jointure de domanialité et son repli, les filtres,
# la fusion des parties d'une même parcelle, la 0-ligne et la dégradation NULL.
# Un test de fumée réseau existe en fin de fichier (skip hors ligne).

.onf_aoi <- function() {
  sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(1000, 0), c(1000, 1000),
                              c(0, 1000), c(0, 0)))), crs = 2154))
}

.onf_carre <- function(x0, y0, cote = 200) {
  sf::st_polygon(list(rbind(c(x0, y0), c(x0 + cote, y0),
                            c(x0 + cote, y0 + cote), c(x0, y0 + cote),
                            c(x0, y0))))
}

# Deux parcelles d'une domaniale + une d'une communale, plus une parcelle
# hors AOI (renvoyée par la bbox mais qui ne touche pas l'emprise).
.onf_parcelles_fixture <- function() {
  sf::st_sf(
    iidtn_frt = c("F00001A", "F00001A", "F00002B", "F00002B"),
    llib_frt  = c("Forêt domaniale de Test", "Forêt domaniale de Test",
                  "Forêt communale de Test", "Forêt communale de Test"),
    ccod_prf  = c("10", "2", "7", "99"),
    geometry  = sf::st_sfc(.onf_carre(100, 100), .onf_carre(400, 100),
                           .onf_carre(700, 100), .onf_carre(5000, 5000),
                           crs = 2154))
}

.onf_forets_fixture <- function() {
  sf::st_sf(
    iidtn_frt = c("F00001A", "F00002B"),
    llib_frt  = c("Forêt domaniale de Test", "Forêt communale de Test"),
    cdom_frt  = c("OUI", "NON"),
    cinse_dep = c("39", "39"),
    geometry  = sf::st_sfc(.onf_carre(0, 0, 600), .onf_carre(600, 0, 600),
                           crs = 2154))
}

# Mock aiguillé sur la couche demandée ; `forets = NULL` simule l'échec de la
# seule couche de domanialité.
.onf_mock <- function(parcelles = .onf_parcelles_fixture(),
                      forets = .onf_forets_fixture()) {
  function(url) if (grepl("PARC_PUBL", url, fixed = TRUE)) parcelles else forets
}

test_that("non-sf aoi degrades to NULL", {
  expect_warning(res <- load_onf_parcelles_source(list(1)), "sf/sfc")
  expect_null(res)
})

test_that("aoi without a CRS degrades to NULL", {
  aoi <- sf::st_sfc(sf::st_point(c(0, 0)))   # crs = NA
  expect_warning(res <- load_onf_parcelles_source(aoi), "no CRS")
  expect_null(res)
})

test_that("an unknown territory degrades to NULL", {
  expect_warning(
    res <- load_onf_parcelles_source(.onf_aoi(), territoire = "ZZZ"),
    "unknown")
  expect_null(res)
})

test_that("a failed WFS read degrades to NULL", {
  local_mocked_bindings(.onf_wfs_read = function(url) NULL)
  expect_null(load_onf_parcelles_source(.onf_aoi()))
})

test_that("parcels come back as UGF-ready rows", {
  local_mocked_bindings(.onf_wfs_read = .onf_mock())
  out <- load_onf_parcelles_source(.onf_aoi())

  expect_s3_class(out, "sf")
  expect_equal(names(out),
               c("id", "foret_id", "foret_nom", "parcelle", "domaniale",
                 "nom_ugf", "contenance", "surface_ha", "geometry"))
  # La parcelle 99, hors emprise, est écartée malgré la réponse bbox.
  expect_equal(nrow(out), 3L)
  expect_false("99" %in% out$parcelle)
  # Tri par forêt puis numéro de parcelle *numérique* (2 avant 10).
  expect_equal(out$parcelle, c("7", "2", "10"))
  expect_equal(out$id, c("F00002B-7", "F00001A-2", "F00001A-10"))
  expect_equal(out$domaniale, c(FALSE, TRUE, TRUE))
  expect_equal(out$nom_ugf[1], "Forêt communale de Test — parcelle 7")
  expect_equal(out$contenance, rep(200 * 200, 3))
  expect_equal(out$surface_ha, rep(4, 3))
  expect_equal(sf::st_crs(out)$epsg, 2154L)
})

test_that("ownership filters keep the right parcels", {
  local_mocked_bindings(.onf_wfs_read = .onf_mock())
  dom <- load_onf_parcelles_source(.onf_aoi(), domanialite = "domaniale")
  expect_equal(nrow(dom), 2L)
  expect_true(all(dom$domaniale))

  autre <- load_onf_parcelles_source(.onf_aoi(), domanialite = "autre")
  expect_equal(nrow(autre), 1L)
  expect_false(any(autre$domaniale))
})

test_that("ownership falls back to the forest label when the layer fails", {
  local_mocked_bindings(.onf_wfs_read = .onf_mock(forets = NULL))
  out <- load_onf_parcelles_source(.onf_aoi())
  expect_equal(nrow(out), 3L)
  # « Forêt domaniale de … » vs « Forêt communale de … »
  expect_equal(out$domaniale, c(FALSE, TRUE, TRUE))
})

test_that("multipart parcels are fused into one row with the summed area", {
  parts <- sf::st_sf(
    iidtn_frt = c("F00001A", "F00001A"),
    llib_frt  = c("Forêt domaniale de Test", "Forêt domaniale de Test"),
    ccod_prf  = c("10", "10"),
    geometry  = sf::st_sfc(.onf_carre(100, 100), .onf_carre(400, 100),
                           crs = 2154))
  local_mocked_bindings(.onf_wfs_read = .onf_mock(parcelles = parts))
  out <- load_onf_parcelles_source(.onf_aoi())
  expect_equal(nrow(out), 1L)
  expect_equal(out$contenance, 2 * 200 * 200)
  expect_true(anyDuplicated(out$id) == 0L)
})

test_that("an AOI with no public forest returns a 0-row sf, not NULL", {
  empty <- sf::st_sf(iidtn_frt = character(0), llib_frt = character(0),
                     ccod_prf = character(0), geometry = sf::st_sfc(crs = 2154))
  local_mocked_bindings(.onf_wfs_read = .onf_mock(parcelles = empty))
  out <- load_onf_parcelles_source(.onf_aoi())
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 0L)
  expect_equal(sf::st_crs(out)$epsg, 2154L)
})

test_that("an unexpected schema degrades to NULL", {
  bad <- sf::st_sf(foo = "bar", geometry = sf::st_sfc(.onf_carre(100, 100),
                                                      crs = 2154))
  local_mocked_bindings(.onf_wfs_read = .onf_mock(parcelles = bad))
  expect_warning(out <- load_onf_parcelles_source(.onf_aoi()), "schema")
  expect_null(out)
})

test_that("truncation by max_parcelles is reported", {
  parc <- .onf_parcelles_fixture()
  attr(parc, "numberMatched") <- 9999L
  local_mocked_bindings(.onf_wfs_read = .onf_mock(parcelles = parc))
  expect_warning(load_onf_parcelles_source(.onf_aoi(), max_parcelles = 4),
                 "9999")
})

test_that("clip = TRUE cuts parcels at the AOI boundary", {
  chevauchant <- sf::st_sf(
    iidtn_frt = "F00001A", llib_frt = "Forêt domaniale de Test",
    ccod_prf = "10",
    geometry = sf::st_sfc(.onf_carre(900, 100, 400), crs = 2154))
  local_mocked_bindings(.onf_wfs_read = .onf_mock(parcelles = chevauchant))
  entier <- load_onf_parcelles_source(.onf_aoi())
  coupe  <- load_onf_parcelles_source(.onf_aoi(), clip = TRUE)
  expect_equal(entier$contenance, 400 * 400)
  expect_equal(coupe$contenance, 100 * 400)
})

test_that("the target crs is honoured", {
  local_mocked_bindings(.onf_wfs_read = .onf_mock())
  out <- load_onf_parcelles_source(.onf_aoi(), crs = 4326)
  expect_equal(sf::st_crs(out)$epsg, 4326L)
  # Les surfaces restent mesurées dans le CRS projeté du territoire.
  expect_equal(out$surface_ha, rep(4, 3))
})

test_that("the WFS url carries the territory, the bbox and the count", {
  u <- .onf_wfs_url(.ONF_TERRITOIRES$FR, "PARC_PUBL",
                    c(899000, 6665000, 903000, 6669000), count = 5000)
  expect_true(grepl("ONF_Forets?", u, fixed = TRUE))
  expect_true(grepl("TYPENAMES=ms:PARC_PUBL_FR", u, fixed = TRUE))
  expect_true(grepl("BBOX=899000,6665000,903000,6669000,urn:ogc:def:crs:EPSG::2154",
                    u, fixed = TRUE))
  expect_true(grepl("COUNT=5000", u, fixed = TRUE))

  ru <- .onf_wfs_url(.ONF_TERRITOIRES$REU, "FOR_PUBL", c(0, 0, 1, 1))
  expect_true(grepl("ONF_Forets_reu?", ru, fixed = TRUE))
  expect_true(grepl("TYPENAMES=ms:FOR_PUBL_REU", ru, fixed = TRUE))
  expect_true(grepl("EPSG::2975", ru, fixed = TRUE))
  expect_false(grepl("COUNT=", ru, fixed = TRUE))
})

test_that("the live ONF service answers over the forêt domaniale de Chaux", {
  skip_on_cran()
  skip_if_offline()
  # Opt-in : le WFS ONF est un vieux service qui cale sans prévenir, et un
  # transfert bloqué a déjà tué deux jobs CI au timeout. Idiome des tests
  # d'intégration DB du dépôt — on n'y va que sur demande explicite.
  skip_if_not(identical(tolower(Sys.getenv("NEMETON_TEST_ONF_LIVE")), "true"),
              "set NEMETON_TEST_ONF_LIVE=true to hit the live ONF WFS")
  aoi <- sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(900000, 6666500), c(902000, 6666500),
                              c(902000, 6668500), c(900000, 6668500),
                              c(900000, 6666500)))), crs = 2154))
  out <- load_onf_parcelles_source(aoi, domanialite = "domaniale")
  skip_if(is.null(out), "ONF WFS unreachable")
  expect_s3_class(out, "sf")
  expect_gt(nrow(out), 10L)
  expect_true(all(out$domaniale))
  expect_true(any(grepl("Chaux", out$foret_nom)))
  expect_true(all(out$surface_ha > 0))
})
