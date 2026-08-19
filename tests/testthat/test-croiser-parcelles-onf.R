# test-croiser-parcelles-onf.R — pour chaque UGF, ses tènements (spec 046 §7)
#
# Géométries synthétiques en Lambert-93, en mètres.

.cx_rect <- function(x0, x1, y0, y1) {
  sf::st_polygon(list(rbind(c(x0, y0), c(x1, y0), c(x1, y1),
                            c(x0, y1), c(x0, y0))))
}

.cx_sfc <- function(rects) {
  sf::st_sfc(lapply(rects, function(r) .cx_rect(r[1], r[2], r[3], r[4])),
             crs = 2154)
}

.cx_cad <- function(ids, rects) {
  sf::st_sf(id = ids, geometry = .cx_sfc(rects))
}

# Fabrique un résultat de load_onf_parcelles_source().
.cx_onf <- function(rects, parcelles = as.character(seq_along(rects)),
                    foret = "Forêt domaniale de Test", foret_id = "F00001A",
                    domaniale = TRUE) {
  sf::st_sf(
    id = paste0(foret_id, "-", parcelles),
    foret_id = foret_id, foret_nom = foret, parcelle = parcelles,
    domaniale = domaniale,
    nom_ugf = paste0(foret, " — parcelle ", parcelles),
    geometry = .cx_sfc(rects))
}

test_that("inputs are validated", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))

  expect_error(croiser_parcelles_onf(list(1), cad), "forest parcels")
  expect_error(croiser_parcelles_onf(onf, list(1)), "cadastral")

  sans_crs <- cad; sf::st_crs(sans_crs) <- NA
  expect_error(croiser_parcelles_onf(onf, sans_crs), "CRS")

  sans_nom <- onf; sans_nom$nom_ugf <- NULL
  expect_error(croiser_parcelles_onf(sans_nom, cad), "nom_ugf")

  sans_id <- cad; names(sans_id)[1] <- "libelle"
  expect_error(croiser_parcelles_onf(onf, sans_id), "identifier column")

  expect_error(croiser_parcelles_onf(onf, cad, seuil_calage = 0), "share")
  expect_error(croiser_parcelles_onf(onf, cad, seuil_calage = 1.5), "share")
})

test_that("each UGF comes back with the cadastral parcels it meets", {
  # Une UGF de 2 ha à cheval sur deux parcelles cadastrales de 1 ha.
  onf <- .cx_onf(list(c(0, 200, 0, 100)))
  cad <- .cx_cad(c("A", "B"), list(c(0, 100, 0, 100), c(100, 200, 0, 100)))
  out <- croiser_parcelles_onf(onf, cad)

  expect_s3_class(out, "sf")
  expect_equal(names(out),
               c("ugf_id", "nom_ugf", "foret_id", "foret_nom", "parcelle",
                 "domaniale", "tenement_id", "parcelle_cadastrale", "hors_ugf",
                 "surface_ha", "part_ugf", "part_cadastrale", "n_tenements",
                 "geometry"))
  expect_equal(nrow(out), 2L)
  expect_true(all(out$ugf_id == "F00001A-1"))
  expect_equal(sort(out$parcelle_cadastrale), c("A", "B"))
  expect_equal(sort(out$tenement_id), c("F00001A-1~A", "F00001A-1~B"))
  expect_equal(unique(out$n_tenements), 2L)
  expect_equal(sum(out$part_ugf), 1)          # l'UGF est entièrement couverte
  expect_true(all(out$part_cadastrale == 1))  # chaque parcelle est prise entière
  expect_equal(sum(out$surface_ha), 2)
  expect_false(any(out$hors_ugf))
})

test_that("part_ugf says how much of the forest parcel the selection holds", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))            # 1 ha
  cad <- .cx_cad("A", list(c(0, 40, 0, 100)))        # n'en couvre que 40 %
  out <- croiser_parcelles_onf(onf, cad)
  expect_equal(nrow(out), 1L)
  expect_equal(out$part_ugf, 0.4)
  expect_equal(out$part_cadastrale, 1)
  expect_equal(out$n_tenements, 1L)
})

test_that("the part outside any UGF is dropped by default, returned on demand", {
  onf <- .cx_onf(list(c(0, 60, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))

  out <- croiser_parcelles_onf(onf, cad)
  expect_equal(nrow(out), 1L)
  expect_false(any(out$hors_ugf))

  avec <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE)
  expect_equal(nrow(avec), 2L)
  r <- avec[avec$hors_ugf, ]
  expect_true(is.na(r$ugf_id))
  expect_true(is.na(r$part_ugf))
  expect_equal(r$surface_ha, 0.4)
  expect_equal(r$tenement_id, "hors_ugf~A")
  expect_equal(sum(avec$surface_ha), 1)       # la parcelle reste pavée
})

test_that("a sliver is absorbed by the largest tenement of the same parcel", {
  # U2 n'attrape que 100 m² (0,01 ha) de la parcelle A, U1 en tient 0,99 ha.
  onf <- .cx_onf(list(c(0, 99, 0, 100), c(99, 100, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))

  brut <- croiser_parcelles_onf(onf, cad, min_surface_ha = 0)
  expect_equal(nrow(brut), 2L)
  expect_true(any(brut$surface_ha < 0.05))

  out <- croiser_parcelles_onf(onf, cad)
  expect_equal(nrow(out), 1L)
  expect_equal(out$ugf_id, "F00001A-1")       # l'écharde a changé de camp
  expect_equal(out$surface_ha, 1)             # rien n'est perdu
  expect_equal(out$part_cadastrale, 1)
})

test_that("caler_sur_cadastre snaps the UGF edge onto the parcel edge", {
  # U1 tient 95 % de A : au-dessus du seuil, elle prend A en entier.
  onf <- .cx_onf(list(c(0, 95, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))

  sans <- croiser_parcelles_onf(onf, cad)
  expect_equal(sans$surface_ha, 0.95)
  expect_equal(sans$part_cadastrale, 0.95)

  avec <- croiser_parcelles_onf(onf, cad, caler_sur_cadastre = TRUE)
  expect_equal(avec$surface_ha, 1)
  expect_equal(avec$part_cadastrale, 1)
  # L'UGF a gagné : elle tient plus que la parcelle forestière d'origine.
  expect_gt(avec$part_ugf, 1)
})

test_that("a genuinely shared parcel stays cut", {
  onf <- .cx_onf(list(c(0, 60, 0, 100), c(60, 100, 0, 100)))   # 60 / 40
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))
  out <- croiser_parcelles_onf(onf, cad, caler_sur_cadastre = TRUE)
  expect_equal(nrow(out), 2L)
  expect_equal(sort(out$surface_ha), c(0.4, 0.6))
  expect_equal(sum(out$part_cadastrale), 1)
})

test_that("the seuil_calage threshold is honoured", {
  onf <- .cx_onf(list(c(0, 92, 0, 100)))                        # 92 %
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))
  expect_equal(croiser_parcelles_onf(onf, cad, caler_sur_cadastre = TRUE,
                                     seuil_calage = 0.9)$surface_ha, 1)
  expect_equal(croiser_parcelles_onf(onf, cad, caler_sur_cadastre = TRUE,
                                     seuil_calage = 0.95)$surface_ha, 0.92)
})

test_that("calage never lets the outside swallow forest", {
  # 80 % de la parcelle est hors forêt : la dominante est le « hors UGF », mais
  # elle ne peut pas prendre la parcelle — sinon on supprimerait de la forêt.
  onf <- .cx_onf(list(c(0, 20, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))
  out <- croiser_parcelles_onf(onf, cad, caler_sur_cadastre = TRUE)
  expect_equal(nrow(out), 1L)
  expect_equal(out$ugf_id, "F00001A-1")
  expect_equal(out$surface_ha, 0.2)
})

test_that("one tenement per (UGF, cadastral parcel) even when multipart", {
  # La parcelle cadastrale A est multipartie : l'UGF la rencontre en deux
  # morceaux disjoints, qui ne doivent donner qu'un seul tènement.
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  cad_bis <- sf::st_sf(id = "A", geometry = sf::st_sfc(
    sf::st_multipolygon(list(list(sf::st_coordinates(
      .cx_rect(0, 20, 0, 100))[, 1:2]),
      list(sf::st_coordinates(.cx_rect(80, 100, 0, 100))[, 1:2]))),
    crs = 2154))
  out <- croiser_parcelles_onf(onf, cad_bis)
  expect_equal(nrow(out), 1L)
  expect_equal(out$surface_ha, 0.4)
  expect_equal(out$n_tenements, 1L)
})

test_that("empty layers give a 0-row result, not an error", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))
  expect_equal(nrow(croiser_parcelles_onf(onf[0, ], cad)), 0L)
  expect_equal(nrow(croiser_parcelles_onf(onf, cad[0, ])), 0L)
  # Couches disjointes : plus rien une fois le reste écarté.
  loin <- .cx_cad("Z", list(c(5000, 5100, 5000, 5100)))
  expect_equal(nrow(croiser_parcelles_onf(onf, loin)), 0L)
})

test_that("the output keeps the CRS of the forest layer", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  cad <- sf::st_transform(.cx_cad("A", list(c(0, 50, 0, 100))), 4326)
  out <- croiser_parcelles_onf(onf, cad)
  expect_equal(sf::st_crs(out)$epsg, 2154L)
  expect_equal(out$surface_ha, 0.5, tolerance = 1e-3)

  onf_wgs <- sf::st_transform(onf, 4326)
  out2 <- croiser_parcelles_onf(onf_wgs, cad)
  expect_equal(sf::st_crs(out2)$epsg, 4326L)
  expect_equal(out2$surface_ha, 0.5, tolerance = 1e-3)   # mesurée en mètres
})

test_that("id_col picks the identifier column explicitly", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 50, 0, 100)))
  names(cad)[1] <- "ref"
  out <- croiser_parcelles_onf(onf, cad, id_col = "ref")
  expect_equal(out$parcelle_cadastrale, "A")
})
