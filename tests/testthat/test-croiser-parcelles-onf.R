# test-croiser-parcelles-onf.R — croisement ONF x cadastre (spec 046 §7)
#
# Géométries synthétiques en Lambert-93, en mètres : une parcelle cadastrale
# de 1 ha (100 x 100) découpée par des parcelles forestières.

.cx_rect <- function(x0, x1, y0, y1) {
  sf::st_polygon(list(rbind(c(x0, y0), c(x1, y0), c(x1, y1),
                            c(x0, y1), c(x0, y0))))
}

.cx_cad <- function(ids = "A", rects = list(c(0, 100, 0, 100))) {
  sf::st_sf(id = ids,
            geometry = sf::st_sfc(lapply(rects, function(r)
              .cx_rect(r[1], r[2], r[3], r[4])), crs = 2154))
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
    geometry = sf::st_sfc(lapply(rects, function(r)
      .cx_rect(r[1], r[2], r[3], r[4])), crs = 2154))
}

test_that("non-sf inputs are rejected", {
  expect_error(croiser_parcelles_onf(list(1), .cx_onf(list(c(0, 1, 0, 1)))),
               "cadastral")
  expect_error(croiser_parcelles_onf(.cx_cad(), list(1)), "forest parcels")
})

test_that("a layer without CRS is rejected", {
  cad <- .cx_cad()
  sf::st_crs(cad) <- NA
  expect_error(croiser_parcelles_onf(cad, .cx_onf(list(c(0, 1, 0, 1)))), "CRS")
})

test_that("cadastral parcels need an identifier column", {
  cad <- .cx_cad()
  names(cad)[1] <- "libelle"
  expect_error(croiser_parcelles_onf(cad, .cx_onf(list(c(0, 1, 0, 1)))),
               "identifier column")
})

test_that("a layer that is not an ONF result is rejected", {
  onf <- .cx_onf(list(c(0, 1, 0, 1)))
  onf$nom_ugf <- NULL
  expect_error(croiser_parcelles_onf(.cx_cad(), onf), "nom_ugf")
})

test_that("fragments carry both shares and tile the cadastral parcel", {
  # P1 couvre la moitié gauche mais déborde en y (part_onf = 0.5),
  # P2 couvre 40 % à droite et tient entièrement dans la parcelle.
  onf <- .cx_onf(list(c(0, 50, 0, 200), c(60, 100, 0, 100)))
  out <- croiser_parcelles_onf(.cx_cad(), onf)

  expect_s3_class(out, "sf")
  expect_equal(names(out),
               c("parcelle_cadastrale", "id_onf", "nom_ugf", "foret_id",
                 "foret_nom", "parcelle", "domaniale", "reste", "surface_ha",
                 "part_cadastrale", "part_onf", "geometry"))
  expect_equal(nrow(out), 3L)                     # 2 attribués + 1 reste
  expect_equal(sum(out$surface_ha), 1)            # pavage exact de 1 ha
  expect_equal(sum(out$part_cadastrale), 1)

  p1 <- out[which(out$id_onf == "F00001A-1"), ]
  expect_equal(p1$surface_ha, 0.5)
  expect_equal(p1$part_cadastrale, 0.5)
  expect_equal(p1$part_onf, 0.5)                  # 0,5 ha retenus sur 1 ha
  p2 <- out[which(out$id_onf == "F00001A-2"), ]
  expect_equal(p2$part_onf, 1)                    # entièrement dans la sélection

  reste <- out[out$reste, ]
  expect_equal(reste$surface_ha, 0.1)             # bande 50-60 m
  expect_true(is.na(reste$id_onf))
  expect_true(is.na(reste$part_onf))
})

test_that("a sliver is absorbed by the largest fragment, area preserved", {
  # P2 est une écharde de 100 m² (0,01 ha) contre P1 qui fait 0,99 ha.
  onf <- .cx_onf(list(c(0, 99, 0, 100), c(99, 100, 0, 100)))
  brut <- croiser_parcelles_onf(.cx_cad(), onf, absorber_echardes = FALSE)
  expect_equal(nrow(brut), 2L)
  expect_true(any(brut$surface_ha < 0.05))

  out <- croiser_parcelles_onf(.cx_cad(), onf)
  expect_equal(nrow(out), 1L)
  expect_equal(out$id_onf, "F00001A-1")           # l'écharde a changé de camp
  expect_equal(out$surface_ha, 1)                 # rien n'est perdu
  expect_equal(out$part_cadastrale, 1)
})

test_that("the sliver threshold is honoured", {
  onf <- .cx_onf(list(c(0, 90, 0, 100), c(90, 100, 0, 100)))  # 0,9 / 0,1 ha
  garde <- croiser_parcelles_onf(.cx_cad(), onf, min_surface_ha = 0.05)
  expect_equal(nrow(garde), 2L)                   # 0,1 ha > seuil : conservé
  absorbe <- croiser_parcelles_onf(.cx_cad(), onf, min_surface_ha = 0.2)
  expect_equal(nrow(absorbe), 1L)
  expect_equal(absorbe$surface_ha, 1)
})

test_that("a lone remainder below the threshold is kept, not erased", {
  onf <- .cx_onf(list(c(500, 600, 500, 600)))     # ailleurs
  petite <- .cx_cad("A", list(c(0, 10, 0, 10)))   # 100 m² = 0,01 ha
  out <- croiser_parcelles_onf(petite, onf)
  expect_equal(nrow(out), 1L)
  expect_true(out$reste)
  expect_equal(out$surface_ha, 0.01)
  expect_equal(out$part_cadastrale, 1)
})

test_that("parcels outside any public forest come back as pure remainder", {
  onf <- .cx_onf(list(c(500, 600, 500, 600)))
  out <- croiser_parcelles_onf(.cx_cad(c("A", "B"),
                                       list(c(0, 100, 0, 100),
                                            c(200, 300, 0, 100))), onf)
  expect_equal(nrow(out), 2L)
  expect_true(all(out$reste))
  expect_true(all(is.na(out$id_onf)))
  expect_equal(sum(out$surface_ha), 2)
})

test_that("one forest parcel spanning several cadastral parcels keeps its share", {
  cad <- .cx_cad(c("A", "B"), list(c(0, 100, 0, 100), c(100, 200, 0, 100)))
  onf <- .cx_onf(list(c(0, 200, 0, 100)))         # 2 ha à cheval sur A et B
  out <- croiser_parcelles_onf(cad, onf)
  expect_equal(nrow(out), 2L)
  expect_true(all(out$id_onf == "F00001A-1"))
  expect_equal(sort(out$part_onf), c(0.5, 0.5))   # moitié dans chaque parcelle
  expect_equal(sum(out$surface_ha), 2)
})

test_that("an empty layer gives a 0-row result, not an error", {
  vide <- .cx_onf(list(c(0, 1, 0, 1)))[0, ]
  out <- croiser_parcelles_onf(.cx_cad(), vide)
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 0L)
})

test_that("the output keeps the CRS of the cadastral layer", {
  onf <- .cx_onf(list(c(0, 50, 0, 100)))
  cad <- sf::st_transform(.cx_cad(), 4326)
  out <- croiser_parcelles_onf(cad, onf)
  expect_equal(sf::st_crs(out)$epsg, 4326L)
  # Surfaces mesurées en mètres malgré l'entrée en degrés.
  expect_equal(sum(out$surface_ha), 1, tolerance = 1e-3)
})

test_that("id_col picks the identifier column explicitly", {
  cad <- .cx_cad()
  names(cad)[1] <- "ref"
  onf <- .cx_onf(list(c(0, 50, 0, 100)))
  out <- croiser_parcelles_onf(cad, onf, id_col = "ref")
  expect_equal(unique(out$parcelle_cadastrale), "A")
})
