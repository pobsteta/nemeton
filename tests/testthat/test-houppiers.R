# Segmentation des houppiers sur MNH — brief
# `nemetonshiny/specs/BRIEF-nemeton-houppiers-mnh.md` (§2 du rattrapage
# 2026-08-23). Le contrat de sortie est fige par Marculus : une couche
# `houppier`, une entite par couronne, `h_max` en metres dans 1-70.

# MNH synthetique : `n` cones gaussiens de hauteurs connues sur une grille
# metrique. Tout est verifiable sans donnee externe.
.mnh_synthetique <- function(hauteurs = c(25, 18, 12), res = 0.25, crs = "EPSG:2154") {
  n <- length(hauteurs)
  r <- terra::rast(nrows = 240, ncols = 80 * n, xmin = 0, xmax = 20 * n,
                   ymin = 0, ymax = 60, crs = crs)
  terra::res(r) <- res
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  z <- rep(0, nrow(xy))
  for (i in seq_len(n)) {
    cx <- 20 * (i - 1) + 10; cy <- 30
    d2 <- (xy[, 1] - cx)^2 + (xy[, 2] - cy)^2
    z <- pmax(z, hauteurs[i] * exp(-d2 / (2 * 3^2)))   # sigma 3 m -> houppier ~9 m
  }
  terra::values(r) <- z
  r
}

test_that("une couronne par arbre, avec la hauteur de son apex", {
  skip_if_not_installed("lidR")
  h <- segment_houppiers(.mnh_synthetique(c(25, 18, 12)), ws = 4, hmin = 3)

  expect_s3_class(h, "sf")
  expect_identical(as.character(unique(sf::st_geometry_type(h))), "POLYGON")
  expect_identical(names(h), c("houppier_id", "h_max", "surface_m2", "geometry"))
  expect_equal(nrow(h), 3L)

  # Les trois hauteurs sont retrouvees. L'agregation par max introduit un
  # BIAIS VERS LE HAUT assume (la cellule la plus haute de chaque agregat
  # gagne) : jamais sous la verite, jamais au-dessus de plus d'un metre.
  trouve <- sort(h$h_max, decreasing = TRUE)
  expect_true(all(trouve <= c(25, 18, 12) + 1))
  expect_true(all(trouve >= c(25, 18, 12) - 1))

  # Trie par hauteur decroissante, identifiants 1..n.
  expect_identical(h$houppier_id, seq_len(nrow(h)))
  expect_false(is.unsorted(rev(h$h_max)))
})

test_that("le contrat aval est tenu : rien hors de 1-70 m ne sort", {
  skip_if_not_installed("lidR")
  # Un peuplement de 25 m, mais une fenetre qui n'admet que ce qui depasse 30 m.
  h <- segment_houppiers(.mnh_synthetique(c(25, 18)), ws = 4, hmin = 3,
                         h_range = c(30, 70))
  expect_equal(nrow(h), 0L)
  # Zero houppier reste un `sf` avec les bonnes colonnes : l'app ecrit une
  # couche VIDE, pas une couche manquante.
  expect_s3_class(h, "sf")
  expect_identical(names(h), c("houppier_id", "h_max", "surface_m2", "geometry"))

  # Et par defaut, aucune valeur ne sort de la plage.
  h2 <- segment_houppiers(.mnh_synthetique(c(25, 18)), ws = 4, hmin = 3)
  expect_true(all(h2$h_max >= 1 & h2$h_max <= 70))
})

test_that("aucun apex au-dessus de hmin : zero houppier, pas une erreur", {
  skip_if_not_installed("lidR")
  h <- segment_houppiers(.mnh_synthetique(c(8, 6)), ws = 4, hmin = 20)
  expect_equal(nrow(h), 0L)
  expect_s3_class(h, "sf")
})

test_that("l'AOI decoupe, et le CRS de sortie porte son code d'autorite", {
  skip_if_not_installed("lidR")
  mnh <- .mnh_synthetique(c(25, 18, 12))
  # AOI sur le premier arbre seulement.
  aoi <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(0, 20), c(20, 20), c(20, 40), c(0, 40), c(0, 20)))), crs = 2154))
  h <- segment_houppiers(mnh, aoi = aoi, ws = 4, hmin = 3)

  expect_equal(nrow(h), 1L)
  expect_equal(h$h_max, 25, tolerance = 1)
  expect_identical(sf::st_crs(h)$epsg, 2154L)
  # La geometrie ne deborde pas de l'emprise demandee.
  expect_true(all(sf::st_bbox(h)[c("xmin", "xmax")] >= -1e-6))
  expect_lte(as.numeric(sf::st_bbox(h)["xmax"]), 20 + 1e-6)
})

test_that("un WKT degenere est re-tamponne, pas propage", {
  skip_if_not_installed("lidR")
  # Le MNH de Couchey porte le NOM « EPSG:2154 » sans autorite : `st_crs()$epsg`
  # y lit NA, et le GeoPackage embarquerait un CRS que le telephone ne sait pas
  # rattacher. Reproduit en retirant l'autorite.
  mnh <- .mnh_synthetique(c(25, 18))
  # Fidele au fichier reel : le NOM du systeme est la chaine « EPSG:2154 »,
  # et le bloc d'autorite ID[...] a disparu.
  wkt <- terra::crs(mnh)
  wkt <- sub('^PROJCRS\\["[^"]*"', 'PROJCRS["EPSG:2154"', wkt)
  wkt <- gsub('\\s*,?\\s*ID\\["EPSG",[0-9]+\\]', '', wkt)
  terra::crs(mnh) <- wkt
  skip_if(!is.na(terra::crs(mnh, describe = TRUE)$code),
          "le WKT a garde son autorite, cas non reproduit ici")

  h <- segment_houppiers(mnh, ws = 4, hmin = 3)
  expect_identical(sf::st_crs(h)$epsg, 2154L)
})

test_that("la resolution de travail est decidee par le coeur, par le MAXIMUM", {
  # C'est la decision technique qui porte la fonction : une agregation lissante
  # effacerait les apex que la detection cherche.
  r <- terra::rast(nrows = 100, ncols = 100, xmin = 0, xmax = 20, ymin = 0,
                   ymax = 20, crs = "EPSG:2154")
  terra::values(r) <- 0
  r[50, 50] <- 30                       # un apex isole, une seule cellule

  fac <- nemeton:::.houppier_agg_factor(r, resolution = 0.5, max_cells = 2e7)
  expect_gt(fac, 1L)
  agrege_max  <- terra::aggregate(r, fact = fac, fun = "max")
  agrege_mean <- terra::aggregate(r, fact = fac, fun = "mean")
  expect_equal(as.numeric(terra::minmax(agrege_max)[2]), 30)
  expect_lt(as.numeric(terra::minmax(agrege_mean)[2]), 30)  # l'apex a fondu
})

test_that("le plafond de cellules borne un MNH que la resolution ne borne pas", {
  # Cas Couchey : 418 M de cellules a 0,20 m. A 0,5 m il en resterait 67 M —
  # au-dessus du plafond, donc le facteur doit encore monter.
  # `terra::res<-` conserve l'ETENDUE et recalcule les dimensions : construire
  # le raster par son etendue, sinon on teste un raster de 1,6 M de cellules.
  r <- terra::rast(xmin = 0, xmax = 14695 * 0.2, ymin = 0, ymax = 28481 * 0.2,
                   resolution = 0.2, crs = "EPSG:2154")
  expect_equal(terra::ncell(r), 418528295, tolerance = 1e-6)

  fac_res <- nemeton:::.houppier_agg_factor(r, resolution = 0.5, max_cells = Inf)
  fac_cap <- nemeton:::.houppier_agg_factor(r, resolution = 0.5, max_cells = 2e7)
  expect_gt(fac_cap, fac_res)
  expect_lte(terra::ncell(r) / fac_cap^2, 2e7)

  # Un MNH deja plus grossier que la resolution demandee n'est pas raffine.
  grossier <- terra::rast(xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                          resolution = 2, crs = "EPSG:2154")
  expect_identical(nemeton:::.houppier_agg_factor(grossier, 0.5, 2e7), 1L)
})

test_that("les trois algorithmes rendent la meme forme de sortie", {
  skip_if_not_installed("lidR")
  mnh <- .mnh_synthetique(c(25, 18, 12))
  for (a in c("dalponte", "silva", "watershed")) {
    h <- segment_houppiers(mnh, ws = 4, hmin = 3, algorithme = a)
    expect_true(inherits(h, "sf"), info = a)
    expect_identical(names(h), c("houppier_id", "h_max", "surface_m2", "geometry"),
                     info = a)
    expect_true(all(h$h_max >= 1 & h$h_max <= 70), info = a)
  }
})

test_that("les entrees impossibles sont refusees, pas devinees", {
  mnh <- .mnh_synthetique(c(25))
  expect_error(segment_houppiers(mnh, ws = 0), "positive")
  expect_error(segment_houppiers(mnh, ws = c(1, 2)), "single")
  expect_error(segment_houppiers(mnh, h_range = c(70, 1)), "increasing")
  expect_error(segment_houppiers("/non/existant/chm.tif"), "not found")
  expect_error(segment_houppiers(42), "SpatRaster")

  # Un CRS geographique lirait `ws` en degres et trouverait un arbre par
  # peuplement : refuser plutot que rendre un resultat absurde.
  lonlat <- terra::rast(nrows = 50, ncols = 50, crs = "EPSG:4326")
  terra::values(lonlat) <- 10
  expect_error(segment_houppiers(lonlat), "geographic CRS")

  # Une AOI disjointe est une erreur, pas une couche vide : c'est un mauvais
  # appel, pas un peuplement sans arbre.
  ailleurs <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(1e6, 1e6), c(1e6+10, 1e6), c(1e6+10, 1e6+10), c(1e6, 1e6+10),
    c(1e6, 1e6)))), crs = 2154))
  expect_error(segment_houppiers(mnh, aoi = ailleurs), "does not intersect")
})


# --- Emprise : selectionner sans couper -------------------------------------
# Demande de Pascal (2026-08-25) : un houppier qui deborde de l'UGF doit etre
# CONSERVE ENTIER, pas rogne au bord de la parcelle.

test_that("emprise = 'intersecte' garde entier un houppier a cheval sur le bord", {
  skip_if_not_installed("lidR")
  mnh <- .mnh_synthetique(c(25, 18, 12))
  # AOI dont le bord coupe le PREMIER arbre en deux (centre en x = 10).
  aoi <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(0, 0), c(10, 0), c(10, 60), c(0, 60), c(0, 0)))), crs = 2154))

  garde <- segment_houppiers(mnh, aoi = aoi, ws = 4, hmin = 3,
                             emprise = "intersecte")
  coupe <- segment_houppiers(mnh, aoi = aoi, ws = 4, hmin = 3,
                             emprise = "decoupe")

  expect_gte(nrow(garde), 1L)
  expect_gte(nrow(coupe), 1L)

  # Le houppier conserve entier est PLUS GRAND que le meme, rogne.
  expect_gt(max(garde$surface_m2), max(coupe$surface_m2))

  # Et il deborde reellement de l'AOI : c'est la definition de « pas coupe ».
  hors <- sf::st_difference(garde, sf::st_union(sf::st_geometry(aoi)))
  expect_gt(sum(as.numeric(sf::st_area(hors))), 0)

  # Le mode « decoupe », lui, ne deborde pas d'un metre carre.
  hors_coupe <- sf::st_difference(coupe, sf::st_union(sf::st_geometry(aoi)))
  expect_lt(sum(as.numeric(sf::st_area(hors_coupe))), 1)
})

test_that("la hauteur d'un houppier de bord n'est plus rabotee", {
  skip_if_not_installed("lidR")
  # L'apex du premier arbre (25 m) est en x = 10 ; une AOI s'arretant a x = 8
  # le laisse DEHORS. En « decoupe », le houppier retenu porte la hauteur du
  # flanc ; en « intersecte », celle du sommet.
  mnh <- .mnh_synthetique(c(25, 18))
  aoi <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(0, 0), c(8, 0), c(8, 60), c(0, 60), c(0, 0)))), crs = 2154))

  garde <- segment_houppiers(mnh, aoi = aoi, ws = 4, hmin = 3,
                             emprise = "intersecte")
  coupe <- segment_houppiers(mnh, aoi = aoi, ws = 4, hmin = 3,
                             emprise = "decoupe")
  skip_if(nrow(garde) == 0L || nrow(coupe) == 0L, "aucun apex retenu de ce cote")
  expect_gt(max(garde$h_max), max(coupe$h_max))
})

test_that("la selection n'introduit aucun houppier etranger a l'AOI", {
  skip_if_not_installed("lidR")
  # La marge sert a COMPLETER les houppiers du bord, pas a en ramener d'autres :
  # le troisieme arbre (x = 50) est loin, il ne doit pas apparaitre.
  mnh <- .mnh_synthetique(c(25, 18, 12))
  aoi <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(rbind(
    c(0, 0), c(15, 0), c(15, 60), c(0, 60), c(0, 0)))), crs = 2154))
  h <- segment_houppiers(mnh, aoi = aoi, ws = 4, hmin = 3, marge_m = 12)

  expect_true(all(lengths(sf::st_intersects(h, sf::st_union(sf::st_geometry(aoi)))) > 0))
  expect_false(any(h$h_max < 13))          # l'arbre de 12 m est reste dehors
})

test_that("marge_m vaut 3 x ws par defaut et refuse l'absurde", {
  mnh <- .mnh_synthetique(c(25))
  expect_error(segment_houppiers(mnh, marge_m = -1), "non-negative")
  expect_error(segment_houppiers(mnh, marge_m = c(1, 2)), "single")
  # Sans aoi, la marge n'a aucun effet : pas d'erreur, pas de selection.
  skip_if_not_installed("lidR")
  expect_s3_class(segment_houppiers(mnh, ws = 4, hmin = 3, marge_m = 99), "sf")
})

# --- Garde CRS des apex (rapport du 2026-08-23) ------------------------------

test_that("un apex sans CRS est repare depuis le raster, pas propage", {
  skip_if_not_installed("lidR")
  # Le rapport decrivait un echec « st_crs(x) == st_crs(y) is not TRUE » leve
  # par `sf` DEPUIS lidR — un symptome, pas une cause. L'hypothese : a grande
  # echelle, `locate_trees()` rend un objet non vide mais sans CRS.
  #
  # Non reproduit (le raster incrimine rend 46 158 houppiers en 71 s, et le
  # diff montre que le code n'avait pas bouge entre la version qui passait et
  # celle qui echouait). Le mode de defaillance est simule ici.
  mnh <- .mnh_synthetique(c(25, 18))
  vrai_locate <- lidR::locate_trees
  testthat::local_mocked_bindings(
    locate_trees = function(las, algorithm, ...) {
      tops <- vrai_locate(las, algorithm, ...)
      sf::st_crs(tops) <- NA          # l'anomalie decrite par le rapport
      tops
    },
    .package = "lidR"
  )
  h <- segment_houppiers(mnh, ws = 4, hmin = 3)
  expect_s3_class(h, "sf")
  expect_gte(nrow(h), 1L)
  expect_identical(sf::st_crs(h)$epsg, 2154L)
})

test_that("un apex dans un AUTRE CRS est nomme, pas laisse en langage sf", {
  skip_if_not_installed("lidR")
  mnh <- .mnh_synthetique(c(25, 18))
  vrai_locate <- lidR::locate_trees
  testthat::local_mocked_bindings(
    locate_trees = function(las, algorithm, ...) {
      tops <- vrai_locate(las, algorithm, ...)
      sf::st_crs(tops) <- 4326        # incoherent avec le MNH
      tops
    },
    .package = "lidR"
  )
  expect_error(segment_houppiers(mnh, ws = 4, hmin = 3),
               "different CRS than the CHM")
})

# --- lidR n'accepte pas un raster sur disque ---------------------------------
# Brief `briefs/vers-nemeton/2026-08-26-lidr-raster-en-memoire.md`, cause
# PROUVEE de ce que deux rapports precedents poursuivaient sous la formulation
# trompeuse « st_crs(x) == st_crs(y) is not TRUE ».

test_that("un MNH sur disque est segmente (materialisation avant lidR)", {
  skip_if_not_installed("lidR")
  # Le piege qui a fait passer tous les tests precedents : `terra::aggregate()`
  # rend son resultat EN MEMOIRE. Tout raster assez fin pour etre agrege
  # esquivait donc le defaut, et un raster deja a la bonne resolution — facteur
  # 1, aucune agregation — restait sur disque et echouait. La taille n'y etait
  # pour rien : une dalle de 4 M cellules echouait quand un MNH de 11,9 M
  # passait.
  #
  # `resolution = 1` sur un raster deja a 1 m : facteur 1, donc pas
  # d'agregation. C'est le chemin qui echouait.
  mnh <- .mnh_synthetique(c(25, 18, 12), res = 1)
  f <- withr::local_tempfile(fileext = ".tif")
  terra::writeRaster(mnh, f, overwrite = TRUE)

  sur_disque <- terra::rast(f)
  expect_false(terra::inMemory(sur_disque))

  h <- segment_houppiers(f, ws = 4, hmin = 3, resolution = 1)
  expect_s3_class(h, "sf")
  expect_gte(nrow(h), 1L)
  expect_true(all(h$h_max >= 1 & h$h_max <= 70))
})

test_that("le chemin par chemin de fichier vaut celui par objet", {
  skip_if_not_installed("lidR")
  mnh <- .mnh_synthetique(c(25, 18), res = 1)
  f <- withr::local_tempfile(fileext = ".tif")
  terra::writeRaster(mnh, f, overwrite = TRUE)

  par_objet <- segment_houppiers(mnh, ws = 4, hmin = 3, resolution = 1)
  par_chemin <- segment_houppiers(f, ws = 4, hmin = 3, resolution = 1)
  expect_equal(nrow(par_objet), nrow(par_chemin))
  expect_equal(sort(round(par_objet$h_max, 3)), sort(round(par_chemin$h_max, 3)))
})
