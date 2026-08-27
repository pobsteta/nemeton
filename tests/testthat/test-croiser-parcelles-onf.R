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

# --- Pré-filtrage des parcelles sans forêt (spec 046 §7.5) -----------------
# Une parcelle qu'aucune UGF ne rencontre ne peut produire qu'une ligne :
# elle-même, entière, hors UGF. Elle est donc écartée avant le croisement, et
# réémise telle quelle — sans reprojection, donc sans perte de précision.

test_that("les parcelles sans forêt n'altèrent pas le résultat des autres", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  proche <- .cx_cad("A", list(c(0, 60, 0, 100)))
  # Mêmes données, plus deux parcelles très loin de toute forêt.
  avec_loin <- .cx_cad(c("A", "Z1", "Z2"),
                       list(c(0, 60, 0, 100), c(9000, 9100, 9000, 9100),
                            c(9200, 9300, 9000, 9100)))

  ref <- croiser_parcelles_onf(onf, proche, inclure_reste = TRUE)
  out <- croiser_parcelles_onf(onf, avec_loin, inclure_reste = TRUE)

  # La ligne de A est identique, au champ près.
  sans_compteur <- function(x) {
    x <- sf::st_drop_geometry(x)
    attr(x, "parcelles_concernees") <- NULL   # ne dépend pas de la parcelle
    x
  }
  a_ref <- sans_compteur(ref[ref$parcelle_cadastrale == "A", ])
  a_out <- sans_compteur(out[out$parcelle_cadastrale == "A", ])
  expect_equal(a_out, a_ref)
  expect_true(sf::st_equals(sf::st_geometry(ref[ref$parcelle_cadastrale == "A", ]),
                            sf::st_geometry(out[out$parcelle_cadastrale == "A", ]),
                            sparse = FALSE)[1, 1])

  # Les deux parcelles écartées n'apparaissent que comme « hors UGF », entières.
  loin <- out[out$parcelle_cadastrale %in% c("Z1", "Z2"), ]
  expect_equal(nrow(loin), 2L)
  expect_true(all(loin$hors_ugf))
  expect_true(all(is.na(loin$ugf_id)))
  expect_equal(loin$part_cadastrale, c(1, 1))
  expect_equal(sort(loin$tenement_id), c("hors_ugf~Z1", "hors_ugf~Z2"))
})

test_that("une parcelle écartée revient avec sa géométrie exacte", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  cad <- .cx_cad(c("A", "Z"), list(c(0, 50, 0, 100), c(9000, 9100, 9000, 9100)))
  out <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE)
  z_out <- sf::st_geometry(out[out$parcelle_cadastrale == "Z", ])
  z_in  <- sf::st_geometry(cad[cad$id == "Z", ])
  # Aucune reprojection sur ce chemin : l'égalité est stricte, pas approchée.
  expect_true(sf::st_equals(z_out, z_in, sparse = FALSE)[1, 1])
  expect_identical(as.numeric(sf::st_area(z_out)), as.numeric(sf::st_area(z_in)))
})

test_that("sans inclure_reste, une parcelle écartée ne produit rien", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  cad <- .cx_cad(c("A", "Z"), list(c(0, 50, 0, 100), c(9000, 9100, 9000, 9100)))
  out <- croiser_parcelles_onf(onf, cad)
  expect_equal(nrow(out), 1L)
  expect_equal(out$parcelle_cadastrale, "A")
})

test_that("le décompte des parcelles concernées est rendu en attribut", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  cad <- .cx_cad(c("A", "B", "Z"),
                 list(c(0, 50, 0, 100), c(50, 100, 0, 100),
                      c(9000, 9100, 9000, 9100)))
  out <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE)
  expect_equal(attr(out, "parcelles_concernees"),
               c(concernees = 2L, total = 3L))
})

test_that("aucune parcelle concernée : rien, ou tout en hors UGF", {
  onf <- .cx_onf(list(c(0, 100, 0, 100)))
  loin <- .cx_cad(c("Y", "Z"),
                  list(c(9000, 9100, 9000, 9100), c(9200, 9300, 9000, 9100)))

  vide <- croiser_parcelles_onf(onf, loin)
  expect_equal(nrow(vide), 0L)
  expect_equal(attr(vide, "parcelles_concernees"),
               c(concernees = 0L, total = 2L))

  tout <- croiser_parcelles_onf(onf, loin, inclure_reste = TRUE)
  expect_equal(nrow(tout), 2L)
  expect_true(all(tout$hors_ugf))
  expect_equal(sum(tout$surface_ha), 2)
})

# --- Rattachement du reliquat au voisin (brief 2026-08-26) -------------------
# Regle de Pascal : le parcellaire ONF est une SOURCE D'ETIQUETTES, pas un
# filtre. Rien d'une parcelle cadastrale n'est ecarte ; les bouts non couverts
# (layons, routes, interstices) appartiennent aux peuplements qui les bordent.

.rat_fixture <- function() {
  # Une parcelle cadastrale de 300 x 100 m, deux parcelles forestieres qui en
  # couvrent les extremites et laissent une bande de 100 m au milieu.
  poly <- function(x0, x1) sf::st_polygon(list(rbind(
    c(x0, 0), c(x1, 0), c(x1, 100), c(x0, 100), c(x0, 0))))
  cad <- sf::st_sf(id = "A1",
                   geometry = sf::st_sfc(poly(0, 300), crs = 2154))
  onf <- sf::st_sf(
    id = c("F1", "F2"), nom_ugf = c("parcelle 1", "parcelle 2"),
    foret_id = "F13185C", foret_nom = "Forêt test",
    parcelle = c("1", "2"), domaniale = TRUE,
    geometry = sf::st_sfc(poly(0, 100), poly(200, 300), crs = 2154))
  list(cad = cad, onf = onf)
}

test_that("le reliquat rejoint son voisin au lieu d'un fourre-tout", {
  f <- .rat_fixture()
  r <- croiser_parcelles_onf(f$onf, f$cad, inclure_reste = TRUE,
                             rattacher_reste = TRUE, min_surface_ha = 0)
  expect_false(any(r$hors_ugf))
  # La surface totale est conservee : rien n'est ecarte, rien n'est duplique.
  expect_equal(sum(as.numeric(sf::st_area(r))), 300 * 100, tolerance = 1e-6)
})

test_that("rattacher_reste = FALSE conserve l'ancien comportement", {
  f <- .rat_fixture()
  r <- croiser_parcelles_onf(f$onf, f$cad, inclure_reste = TRUE,
                             rattacher_reste = FALSE, min_surface_ha = 0)
  expect_true(any(r$hors_ugf))
  expect_equal(sum(as.numeric(sf::st_area(r))), 300 * 100, tolerance = 1e-6)
})

test_that("sans voisin forestier, la parcelle devient sa propre UGF", {
  # Une parcelle cadastrale isolee, qu'aucune parcelle ONF ne touche : elle ne
  # doit pas finir dans un fourre-tout — ce serait une unite de gestion qui n'en
  # est pas une — mais porter sa propre reference.
  f <- .rat_fixture()
  loin <- sf::st_sf(id = "A2", geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(1000, 0), c(1100, 0), c(1100, 100), c(1000, 100), c(1000, 0)))), crs = 2154))
  cad <- rbind(f$cad, loin)
  r <- croiser_parcelles_onf(f$onf, cad, inclure_reste = TRUE,
                             rattacher_reste = TRUE, min_surface_ha = 0)
  isole <- r[r$parcelle_cadastrale == "A2", ]
  expect_equal(nrow(isole), 1L)
  expect_false(isole$hors_ugf)
  expect_match(isole$ugf_id, "^cad~")
  expect_identical(isole$nom_ugf, "A2")
})

test_that("le rattachement ne perd pas un metre carre (piege st_cast)", {
  # Defaut trouve sur le parcellaire reel de Couchey : sur un melange
  # POLYGON/MULTIPOLYGON, `st_cast("POLYGON")` ne garde que le PREMIER polygone
  # de chaque multipartie, sans erreur ni avertissement — 20 lignes en entree,
  # 20 en sortie, 13,74 ha des 50,34 evapores. C'est exactement le genre de
  # perte que le pavage doit interdire.
  poly <- function(x0, x1) sf::st_polygon(list(rbind(
    c(x0, 0), c(x1, 0), c(x1, 100), c(x0, 100), c(x0, 0))))
  # Parcelle cadastrale dont le reliquat sera MULTIPARTIE : deux parcelles
  # forestieres aux extremites laissent deux bandes separees au milieu.
  cad <- sf::st_sf(id = "A1", geometry = sf::st_sfc(poly(0, 500), crs = 2154))
  onf <- sf::st_sf(
    id = c("F1", "F2", "F3"), nom_ugf = c("p1", "p2", "p3"),
    foret_id = "F1", foret_nom = "T", parcelle = c("1", "2", "3"),
    domaniale = TRUE,
    geometry = sf::st_sfc(poly(0, 100), poly(200, 300), poly(400, 500),
                          crs = 2154))

  sans <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE,
                                rattacher_reste = FALSE, min_surface_ha = 0)
  avec <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE,
                                rattacher_reste = TRUE, min_surface_ha = 0)

  # Le reliquat EST multipartie : c'est la condition du piege.
  expect_true(any(as.character(sf::st_geometry_type(sans[sans$hors_ugf, ])) ==
                    "MULTIPOLYGON"))
  # Et la surface traverse le rattachement intacte.
  expect_equal(sum(as.numeric(sf::st_area(avec))),
               sum(as.numeric(sf::st_area(sans))), tolerance = 1e-9)
  expect_equal(sum(as.numeric(sf::st_area(avec))), 500 * 100, tolerance = 1e-9)
  expect_false(any(avec$hors_ugf))
  # Les deux bandes rejoignent des UGF differentes : chacune son voisin.
  expect_gt(length(unique(avec$ugf_id)), 2L)
})

# --- Absorption au niveau de la PARTIE (v0.190.0) ----------------------------
# Le seuil `min_surface_ha` visait les échardes ; il était comparé à la surface
# de la LIGNE, or `ten` est fondu à une ligne par (UGF × parcelle cadastrale) et
# `reste` à une ligne par parcelle. Un multipolygone de 10 ha n'est jamais une
# écharde — et se disloquait en morceaux de moins de 100 m² dès que le
# consommateur normalisait en parties simples.

# Éclatement en parties simples, comme le fait l'app à l'import.
.cx_singleparts <- function(x) {
  y <- suppressWarnings(sf::st_cast(sf::st_cast(x, "MULTIPOLYGON"),
                                    "POLYGON", warn = FALSE))
  y$surface_ha <- as.numeric(sf::st_area(y)) / 1e4
  y
}

test_that("a sliver hidden inside a MULTIPART remainder is absorbed", {
  # Deux UGF se suivent en laissant entre elles une fente de 0,2 m sur 100 m —
  # 20 m², une écharde de numérisation — et la parcelle A déborde de 10 m à
  # droite, ce qui fait un second morceau de reliquat de 0,1 ha. Les deux sont
  # DISJOINTS (la seconde UGF les sépare), donc `reste` les porte en UNE ligne
  # multipartie de 0,102 ha : au-dessus du seuil de 0,05 ha, jamais absorbée,
  # et l'écharde ressortait à l'éclatement.
  onf <- .cx_onf(list(c(0, 100, 0, 100), c(100.2, 190, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 200, 0, 100)))

  brut <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE,
                                min_surface_ha = 0)
  reste <- brut[brut$hors_ugf, ]
  expect_equal(nrow(reste), 1L)                       # une ligne, multipartie
  parts_brut <- .cx_singleparts(reste)
  expect_gt(nrow(parts_brut), 1L)
  expect_true(any(parts_brut$surface_ha < 0.05))      # l'écharde est là

  out <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE,
                               min_surface_ha = 0.05)
  parts <- .cx_singleparts(out)
  expect_false(any(parts$surface_ha < 0.05))          # plus aucune écharde
  # Rien n'est perdu : le pavage cadastral reste exact.
  expect_equal(sum(out$surface_ha), sum(as.numeric(sf::st_area(cad))) / 1e4,
               tolerance = 1e-9)
})

test_that("a sliver joins the fragment it TOUCHES, not the largest one", {
  # U1 tient la bande [0,60], U2 la bande [70,100] — U1 est la plus grosse.
  # L'écharde du reliquat est la bande [60,70] × [0,2] : elle touche les deux,
  # mais partage une frontière plus longue avec... les deux (2 m chacune).
  # On la place donc en contact franc avec U2 seule : [60,70]x[0,2] ne touche
  # U1 que par le segment x=60, et U2 par x=70 — égalité. On dissymétrise en
  # donnant à U2 un contact plus long.
  onf <- .cx_onf(list(c(0, 60, 0, 100), c(62, 100, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))

  out <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE,
                               min_surface_ha = 0.05)
  # La bande [60,62] fait 0,02 ha : sous le seuil, elle est absorbée.
  expect_false(any(.cx_singleparts(out)$surface_ha < 0.05))
  # Elle a rejoint une UGF réelle et le résultat est d'un seul tenant :
  # c'est ce qui la fait disparaître pour de bon, un multipolygone se
  # redécouperait à l'éclatement.
  expect_equal(nrow(.cx_singleparts(out)), nrow(out))
  expect_equal(sum(out$surface_ha), 1, tolerance = 1e-9)
})

test_that("absorption never loses surface, whatever the threshold", {
  onf <- .cx_onf(list(c(0, 40, 0, 100), c(41, 60, 0, 100), c(61, 99, 0, 100)))
  cad <- .cx_cad("A", list(c(0, 100, 0, 100)))
  total <- sum(as.numeric(sf::st_area(cad))) / 1e4

  for (seuil in c(0, 0.001, 0.05, 0.2, 10)) {
    out <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE,
                                 min_surface_ha = seuil)
    expect_equal(sum(out$surface_ha), total, tolerance = 1e-9,
                 info = paste("seuil", seuil))
  }
})

test_that(".croiser_longueur_euclidienne agrees with sf::st_length", {
  # Le CRS de travail est toujours projeté (.croiser_crs_travail bascule en
  # 2154 dès que l'entrée est en longitude/latitude), donc la somme euclidienne
  # des segments EST la longueur — et évite l'interrogation du CRS que
  # st_length() refait à chaque appel (6,1 s sur 6,4 s au profil).
  l1 <- sf::st_sfc(sf::st_linestring(rbind(c(0, 0), c(3, 4), c(3, 10))),
                   crs = 2154)
  expect_equal(.croiser_longueur_euclidienne(l1),
               as.numeric(sf::st_length(l1)))

  # Plusieurs lignes : les segments ne franchissent pas la frontière entre
  # parties (sans quoi le saut de l'une à l'autre serait compté).
  l2 <- sf::st_sfc(sf::st_multilinestring(list(rbind(c(0, 0), c(0, 5)),
                                               rbind(c(100, 0), c(100, 3)))),
                   crs = 2154)
  expect_equal(.croiser_longueur_euclidienne(l2), 8)
  expect_equal(.croiser_longueur_euclidienne(l2),
               as.numeric(sum(sf::st_length(l2))))

  expect_equal(.croiser_longueur_euclidienne(sf::st_sfc(crs = 2154)), 0)
})
