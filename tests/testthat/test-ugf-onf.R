# test-ugf-onf.R — UGF d'une forêt publique depuis le parcellaire ONF calé sur
# le cadastre (spec 058).
#
# Géométries synthétiques en Lambert-93, en mètres. Un test de non-régression
# réseau sur Couchey (21200) est en fin de fichier (NEMETON_TEST_ONF_LIVE).

.ug_rect <- function(x0, x1, y0, y1) {
  sf::st_polygon(list(rbind(c(x0, y0), c(x1, y0), c(x1, y1),
                            c(x0, y1), c(x0, y0))))
}

.ug_sfc <- function(rects) {
  sf::st_sfc(lapply(rects, function(r) .ug_rect(r[1], r[2], r[3], r[4])),
             crs = 2154)
}

.ug_cad <- function(idu, rects, insee = "21200") {
  sf::st_sf(idu = idu, code_insee = insee, geometry = .ug_sfc(rects))
}

.ug_onf <- function(rects, parcelles = as.character(seq_along(rects)),
                    foret_id = "F00001A") {
  sf::st_sf(
    id = paste0(foret_id, "-", parcelles), foret_id = foret_id,
    foret_nom = "Forêt communale de Test", parcelle = parcelles,
    domaniale = FALSE, nom_ugf = paste0("Parcelle ", parcelles),
    geometry = .ug_sfc(rects))
}

.ug_proprio <- function(idu) {
  data.frame(idu = idu, code_insee = "21200", publique = TRUE,
             groupe = "commune", proprietaire = "COMMUNE DE TEST",
             natures = "Taillis simples", contenance_m2 = NA_real_)
}

# Écart de pavage d'une parcelle, en m² (différence symétrique).
.ug_ecart <- function(out, cad, id) {
  t <- sf::st_union(sf::st_geometry(out)[out$idu == id])
  d <- sf::st_sym_difference(t, sf::st_geometry(cad)[cad$idu == id])
  sum(as.numeric(sf::st_area(d)))
}

# ---------------------------------------------------------------------------
# IDU et source DGFiP
# ---------------------------------------------------------------------------

test_that("the DGFiP IDU follows the cadastral 14-character layout", {
  idu <- nemeton:::.dgfip_idu(
    code_insee = c("21200", "21200", "21200", "97101"),
    prefixe    = c(NA, "", "123", NA),
    section    = c("A", "AO", "B", "AB"),
    numero     = c(12L, 18L, 7L, 1234L))
  expect_equal(idu, c("212000000A0012", "21200000AO0018", "212001230B0007",
                      "97101000AB1234"))
  expect_true(all(nchar(idu) == 14L))
  expect_equal(nemeton:::.dgfip_departement(c("21200", "2A004", "97101")),
               c("21", "2A", "971"))
})

test_that("DGFiP rows collapse to one row per parcel with a public flag", {
  brut <- data.frame(
    code_insee = c("21200", "21200", "21200", "21200", "21201"),
    departement = "21", code_commune = c("200", "200", "200", "200", "201"),
    prefixe = NA_character_, section = c("A", "A", "AO", "B", "A"),
    numero_parcelle = c(1L, 1L, 18L, 3L, 1L),
    groupe_personne_code = c("4", "4", "0", "1", "4"),
    groupe_personne_libelle = c("commune", "commune",
                                "personnes morales non remarquables", "État",
                                "commune"),
    denomination = c("COMMUNE DE COUCHEY", "COMMUNE DE COUCHEY", "SCI DU BOIS",
                     "ETAT", "COMMUNE VOISINE"),
    nature_culture_libelle = c("Taillis simples", "Landes", "Bois", "Futaies",
                               "Landes"),
    contenance_parcelle_centiare = c(1000, 1000, 500, 2000, 300))
  out <- nemeton:::.dgfip_par_parcelle(brut, "21200")

  expect_equal(nrow(out), 3L)                       # autre commune écartée
  expect_equal(out$idu, sort(c("212000000A0001", "21200000AO0018",
                               "212000000B0003")))
  a1 <- out[out$idu == "212000000A0001", ]
  expect_true(a1$publique)
  expect_equal(a1$natures, "Taillis simples, Landes")
  expect_equal(a1$contenance_m2, 1000)
  expect_false(out$publique[out$idu == "21200000AO0018"])   # SCI : privée
  expect_true(out$publique[out$idu == "212000000B0003"])    # État
})

test_that("load_parcelles_personnes_morales() reads a given Parquet file", {
  skip_if_not_installed("arrow")
  expect_error(load_parcelles_personnes_morales("2120"), "INSEE")
  expect_error(load_parcelles_personnes_morales("21200", fichier = "absent.parquet"),
               "not found")

  withr::with_tempdir({
    brut <- data.frame(
      millesime = 2025L, departement = c("21", "21", "39"),
      code_commune = c("200", "200", "200"),
      code_insee = c("21200", "21200", "39200"),
      section = c("A", "A", "A"), numero_parcelle = c(12L, 13L, 12L),
      prefixe = NA_character_, groupe_personne_code = c("4", "0", "4"),
      groupe_personne_libelle = c("commune",
                                  "personnes morales non remarquables",
                                  "commune"),
      denomination = c("COMMUNE DE COUCHEY", "SCI", "AUTRE"),
      nature_culture_libelle = "Landes",
      contenance_parcelle_centiare = c(33700L, 100L, 5L))
    arrow::write_parquet(brut, "pm.parquet")
    out <- load_parcelles_personnes_morales("21200", fichier = "pm.parquet")
    expect_equal(out$idu, c("212000000A0012", "212000000A0013"))
    expect_equal(out$publique, c(TRUE, FALSE))
    vide <- load_parcelles_personnes_morales("21999", fichier = "pm.parquet")
    expect_equal(nrow(vide), 0L)
  })
})

# ---------------------------------------------------------------------------
# Calage élastique
# ---------------------------------------------------------------------------

test_that("caler_onf_sur_cadastre() pulls a shifted ONF layer onto the cadastre", {
  cad <- .ug_cad(c("A", "B"), list(c(0, 200, 0, 100), c(200, 400, 0, 100)))
  # ONF décalée de (6, 4) m : partition identique, mal numérisée.
  onf <- .ug_onf(list(c(6, 206, 4, 104), c(206, 406, 4, 104)))
  out <- caler_onf_sur_cadastre(onf, cad)

  expect_s3_class(out, "sf")
  expect_equal(out$id, onf$id)
  expect_equal(sf::st_crs(out), sf::st_crs(onf))
  cal <- attr(out, "calage")
  expect_gt(cal[["n_controle"]], 100)
  expect_lt(cal[["ecart_median_m"]], 10)

  U <- sf::st_union(sf::st_geometry(cad))
  ecart <- function(x) {
    as.numeric(sf::st_area(sf::st_sym_difference(sf::st_union(sf::st_geometry(x)), U)))
  }
  # 6 x 100 + 4 x 400 m de liseré au départ ; quasi rien après.
  expect_gt(ecart(onf), 3000)
  expect_lt(ecart(out), 0.1 * ecart(onf))
  # Partition conservée : pas de chevauchement entre parcelles ONF calées.
  chev <- sum(as.numeric(sf::st_area(out))) - as.numeric(sf::st_area(sf::st_union(out)))
  expect_lt(chev, 1)
})

test_that("caler_onf_sur_cadastre() leaves ONF unwarped without control points", {
  cad <- .ug_cad("A", list(c(0, 100, 0, 100)))
  onf <- .ug_onf(list(c(0, 100, 0, 100)))
  loin <- .ug_cad("Z", list(c(5000, 5100, 0, 100)))
  vide <- caler_onf_sur_cadastre(onf, loin)
  expect_equal(nrow(vide), 0L)

  expect_error(caler_onf_sur_cadastre(list(), cad), "sf")
  expect_error(caler_onf_sur_cadastre(onf, cad, dmax = -1), "positive")
})

test_that("the displacement field is the same with or without FNN", {
  set.seed(1)
  xy <- matrix(runif(400, 0, 1000), ncol = 2)
  P <- matrix(runif(200, 0, 1000), ncol = 2)
  V <- matrix(rnorm(200), ncol = 2)
  skip_if_not_installed("FNN")
  avec <- nemeton:::.ugf_champ(xy, P, V, k = 12, rayon = 200)
  sans <- local({
    local_mocked_bindings(requireNamespace = function(...) FALSE,
                          .package = "base")
    nemeton:::.ugf_champ(xy, P, V, k = 12, rayon = 200)
  })
  expect_equal(avec, sans, tolerance = 1e-12)
})

# ---------------------------------------------------------------------------
# Construction des UGF
# ---------------------------------------------------------------------------

# A et B : communales, couvertes par l'ONF. La limite ONF 1|2 passe à 5 m de la
# limite cadastrale A|B (à accrocher) ; la limite 2|3 coupe B en son milieu
# (vraie coupure). C : privée, couverte par un débordement de l'ONF. D :
# communale de 16 ha, couverte sur sa bande du haut seulement (25 %) ; la
# limite basse de cette bande est à plus de `dmax` de toute limite cadastrale,
# le calage ne la tire pas. E : communale, couverte sur ses 120 m du haut ; les
# 80 m du bas (1,6 ha) restent hors ONF.
.ug_scene <- function() {
  cad <- .ug_cad(c("A", "B", "C", "D", "E"),
                 list(c(0, 200, 0, 100), c(200, 400, 0, 100),
                      c(400, 410, 0, 100), c(0, 400, 100, 500),
                      c(0, 200, -200, 0)))
  onf <- .ug_onf(list(c(0, 205, 0, 100), c(205, 300, 0, 100),
                      c(300, 410, 0, 100), c(0, 400, 400, 500),
                      c(0, 200, -120, 0)),
                 parcelles = c("1", "2", "3", "6", "5"))
  list(cad = cad, onf = onf, proprio = .ug_proprio(c("A", "B", "D", "E")))
}

test_that("construire_ugf_onf() selects, snaps and cuts as specified", {
  s <- .ug_scene()
  out <- construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                            cadastre = s$cad, proprietaires = s$proprio)

  expect_s3_class(out, "sf")
  expect_equal(names(out),
               c("idu", "tenement_id", "ugf_id", "nom_ugf", "foret_id",
                 "foret_nom", "parcelle", "domaniale", "surface_m2",
                 "part_onf", "geometry"))

  # Sélection : C privée, D trop peu couverte.
  pa <- attr(out, "parcelles")
  expect_setequal(pa$idu[pa$retenue], c("A", "B", "E"))
  expect_equal(pa$raison[pa$idu == "C"], "privee")
  expect_equal(pa$raison[pa$idu == "D"], "couverture < 50 %")
  expect_setequal(unique(out$idu), c("A", "B", "E"))

  # A entière dans la parcelle 1 : la limite ONF à 5 m s'est accrochée.
  expect_equal(out$ugf_id[out$idu == "A"], "F00001A-1")
  # B coupée en deux par la limite 2|3, réelle.
  expect_setequal(out$ugf_id[out$idu == "B"], c("F00001A-2", "F00001A-3"))
  expect_equal(sort(out$surface_m2[out$idu == "B"]), c(1e4, 1e4), tolerance = 0.02)
  # E : un bloc hors ONF de 1,6 ha (> 1 ha) reste sa propre unité.
  expect_setequal(out$ugf_id[out$idu == "E"], c("F00001A-5", "cad~E"))
  expect_true(is.na(out$part_onf[out$ugf_id == "cad~E"]))
  expect_true(is.na(out$foret_id[out$ugf_id == "cad~E"]))
  expect_equal(out$nom_ugf[out$ugf_id == "cad~E"], "E")
  expect_true(all(out$part_onf[!startsWith(out$ugf_id, "cad~")] > 0.9))
  expect_equal(out$tenement_id, paste0(out$ugf_id, "~", out$idu))
  expect_equal(out$parcelle[out$ugf_id == "F00001A-2"], "2")
})

test_that("construire_ugf_onf() tiles each kept parcel exactly, without moving it", {
  s <- .ug_scene()
  out <- construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                            cadastre = s$cad, proprietaires = s$proprio)
  for (id in unique(out$idu)) expect_lt(.ug_ecart(out, s$cad, id), 1)
  chev <- sum(as.numeric(sf::st_area(out))) -
    as.numeric(sf::st_area(sf::st_union(out)))
  expect_lt(abs(chev), 0.01)
  # Chaque sommet du cadastre retenu se retrouve dans la sortie, au mm près.
  vc <- sf::st_coordinates(s$cad[s$cad$idu %in% out$idu, ])[, 1:2]
  vo <- sf::st_coordinates(out)[, 1:2]
  d <- apply(vc, 1, function(p) min(sqrt((vo[, 1] - p[1])^2 + (vo[, 2] - p[2])^2)))
  expect_lt(max(d), 1e-3)
})

test_that("in 'foret' mode, parcels off the ONF layer are listed as 'hors ONF'", {
  s <- .ug_scene()
  cad <- rbind(s$cad, .ug_cad("F", list(c(1000, 1200, 0, 100))))
  out <- construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                            cadastre = cad,
                            proprietaires = .ug_proprio(c("A", "B", "D", "E", "F")))
  pa <- attr(out, "parcelles")
  expect_setequal(pa$idu, c("A", "B", "C", "D", "E", "F"))
  f <- pa[pa$idu == "F", ]
  expect_false(f$retenue)
  expect_equal(f$raison, "hors ONF")
  expect_equal(f$couverture_onf, 0)
  expect_true(f$publique)
  expect_equal(f$surface_ha, 2)
  expect_false("F" %in% out$idu)
  # Le reste est inchangé par l'ajout de F.
  ref <- construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                            cadastre = s$cad, proprietaires = s$proprio)
  expect_equal(sort(out$tenement_id), sort(ref$tenement_id))
  expect_equal(sum(out$surface_m2), sum(ref$surface_m2), tolerance = 1e-9)
})

test_that("several communes are processed together", {
  s <- .ug_scene()
  # B et E passent dans une commune voisine, jointive de la première.
  cad <- s$cad
  cad$code_insee[cad$idu %in% c("B", "E")] <- "21201"
  cad$idu <- ifelse(cad$code_insee == "21201", paste0("21201", cad$idu),
                    paste0("21200", cad$idu))
  proprio <- .ug_proprio(c("21200A", "21201B", "21200D", "21201E"))
  onf <- s$onf

  # insee déduit du cadastre, deux communes à la fois.
  out <- construire_ugf_onf(parcelles_onf = onf, cadastre = cad,
                            proprietaires = proprio)
  ref <- construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                            cadastre = s$cad, proprietaires = s$proprio)
  expect_setequal(unique(out$idu), c("21200A", "21201B", "21201E"))
  # Même découpage que sur une seule commune : seuls les identifiants changent.
  expect_equal(sort(out$surface_m2), sort(ref$surface_m2), tolerance = 1e-6)
  expect_equal(sort(gsub("2120[01]", "", out$tenement_id)),
               sort(ref$tenement_id))
  for (id in unique(out$idu)) {
    t <- sf::st_union(sf::st_geometry(out)[out$idu == id])
    g <- sf::st_geometry(cad)[cad$idu == id]
    expect_lt(sum(as.numeric(sf::st_area(sf::st_sym_difference(t, g)))), 1)
  }
  # Un insee explicite à deux communes donne le même résultat.
  out2 <- construire_ugf_onf(insee = c("21200", "21201"), parcelles_onf = onf,
                             cadastre = cad, proprietaires = proprio)
  expect_equal(out2$tenement_id, out$tenement_id)
  # Le cadastre fourni n'est plus filtré sur `insee`.
  out3 <- construire_ugf_onf(insee = "21200", parcelles_onf = onf,
                             cadastre = cad, proprietaires = proprio)
  expect_setequal(unique(out3$idu), unique(out$idu))
})

test_that("load_parcelles_personnes_morales() reads several communes and départements", {
  skip_if_not_installed("arrow")
  withr::with_tempdir({
    brut <- data.frame(
      millesime = 2025L, departement = c("21", "21", "39", "39"),
      code_commune = c("200", "201", "200", "300"),
      code_insee = c("21200", "21201", "39200", "39300"),
      section = "A", numero_parcelle = c(1L, 2L, 3L, 4L),
      prefixe = NA_character_, groupe_personne_code = "4",
      groupe_personne_libelle = "commune", denomination = "COMMUNE",
      nature_culture_libelle = "Bois", contenance_parcelle_centiare = 100L)
    arrow::write_parquet(brut, "pm.parquet")
    out <- load_parcelles_personnes_morales(c("21200", "39200", "21201"),
                                            fichier = "pm.parquet")
    expect_setequal(out$idu, c("212000000A0001", "212010000A0002",
                               "392000000A0003"))
    expect_equal(out$code_insee[out$idu == "392000000A0003"], "39200")
    expect_error(load_parcelles_personnes_morales(c("21200", NA)), "INSEE")
  })
})

test_that("selection = 'toutes' keeps the caller's parcels without DGFiP", {
  s <- .ug_scene()
  # Sans `proprietaires` : en mode « toutes », la DGFiP n'est pas lue.
  local_mocked_bindings(load_parcelles_personnes_morales = function(...) {
    stop("DGFiP must not be read")
  })
  # F ne touche pas l'ONF : elle reste, comme unité propre.
  cad <- rbind(s$cad, .ug_cad("F", list(c(1000, 1200, 0, 100))))
  out <- construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                            cadastre = cad, selection = "toutes")
  pa <- attr(out, "parcelles")
  expect_true(all(pa$retenue))
  expect_true(all(is.na(pa$publique)))
  expect_setequal(unique(out$idu), c("A", "B", "C", "D", "E", "F"))
  expect_equal(out$ugf_id[out$idu == "F"], "cad~F")
  # C (10 m de large, couverte) rejoint une UGF ; D, découverte sur 300 m de
  # haut, garde sa partie hors ONF comme unité propre.
  expect_false("cad~C" %in% out$ugf_id)
  expect_true("cad~D" %in% out$ugf_id)
  for (id in unique(out$idu)) expect_lt(.ug_ecart(out, cad, id), 1)
  expect_error(construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                                  cadastre = s$cad, selection = "x"), "should be one of")
})

test_that("construire_ugf_onf() validates its inputs and reports empty results", {
  s <- .ug_scene()
  expect_error(construire_ugf_onf(parcelles_onf = s$onf), "insee")
  expect_error(construire_ugf_onf(insee = "2120", parcelles_onf = s$onf), "INSEE")
  expect_error(construire_ugf_onf(insee = "21200"), "aoi")
  expect_error(construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                                  cadastre = s$cad, proprietaires = s$proprio,
                                  seuil_couverture = 2), "share")
  expect_error(construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                                  cadastre = s$cad,
                                  proprietaires = data.frame(x = 1)), "publique")

  # Personne publique nulle part : aucune parcelle retenue.
  prive <- s$proprio; prive$publique <- FALSE
  expect_warning(
    vide <- construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                               cadastre = s$cad, proprietaires = prive),
    "qualifies")
  expect_equal(nrow(vide), 0L)
  expect_true(all(attr(vide, "parcelles")$raison == "privee"))

  # Aucune parcelle fournie ne touche l'ONF.
  loin <- .ug_cad("Z", list(c(5000, 5100, 0, 100)))
  expect_warning(
    res <- construire_ugf_onf(insee = "21200", parcelles_onf = s$onf,
                              cadastre = loin, proprietaires = s$proprio),
    "No cadastral parcel")
  expect_null(res)
})

# ---------------------------------------------------------------------------
# Rattachements finaux (§ 3.5), sur des tènements synthétiques
# ---------------------------------------------------------------------------

.ug_ten <- function(idu, ugf, rects) {
  x <- sf::st_sf(idu = idu, ugf = ugf, geometry = .ug_sfc(rects))
  sf::st_geometry(x) <- sf::st_cast(sf::st_geometry(x), "MULTIPOLYGON")
  sf::st_agr(x) <- "constant"
  x
}

test_that("a small ONF piece enclosed by one other UGF moves into it", {
  # X (U2, 0,25 ha) est entouré par U1 seule ; U2 a ailleurs un gros morceau
  # (donc l'UGF dépasse 0,5 ha) qui ne touche pas X.
  ten <- .ug_ten(
    c("P", "P", "P", "P", "Q"),
    c("U1", "U1", "U1", "U2", "U2"),
    list(c(0, 150, 0, 50), c(0, 150, 100, 150), c(0, 50, 50, 100),
         c(50, 100, 50, 100), c(500, 700, 0, 100)))
  out <- nemeton:::.ugf_rattacher(ten, seuil = 0.5, seuil_hors = 1)
  x <- out[out$idu == "P", ]
  expect_equal(unique(x$ugf), "U1")
  expect_equal(out$ugf[out$idu == "Q"], "U2")
})

test_that("an uncovered piece under seuil_hors joins its longest-boundary neighbour", {
  # cad~P (0,8 ha) borde U1 sur 80 m et U2 sur 100 m.
  ten <- .ug_ten(c("P", "P", "P"), c("U1", "U2", "cad~P"),
                 list(c(0, 100, 0, 200), c(100, 300, 80, 200),
                      c(100, 200, 0, 80)))
  out <- nemeton:::.ugf_rattacher(ten, seuil = 0.5, seuil_hors = 1)
  expect_false(any(startsWith(out$ugf, "cad~")))
  expect_equal(sort(unique(out$ugf)), c("U1", "U2"))
  a <- tapply(as.numeric(sf::st_area(out)), out$ugf, sum)
  expect_equal(a[["U2"]], 200 * 120 + 100 * 80)
})

test_that("a whole UGF under seuil is shared out to its longest-boundary neighbour", {
  # U3 (0,4 ha) borde U1 sur 100 m et U2 sur 40 m : la règle 1 ne s'applique
  # pas (deux UGF voisines), la règle 3 la verse dans U1.
  ten <- .ug_ten(c("P", "P", "P"), c("U1", "U2", "U3"),
                 list(c(0, 300, 0, 100), c(100, 140, 100, 300),
                      c(0, 100, 100, 140)))
  out <- nemeton:::.ugf_rattacher(ten, seuil = 0.5, seuil_hors = 1)
  expect_false("U3" %in% out$ugf)
  a <- tapply(as.numeric(sf::st_area(out)), out$ugf, sum)
  expect_equal(a[["U1"]], 300 * 100 + 100 * 40)
})

# ---------------------------------------------------------------------------
# Option dans croiser_parcelles_onf()
# ---------------------------------------------------------------------------

test_that("croiser_parcelles_onf() keeps its default and offers the elastic calage", {
  withr::local_options(nemeton.deprecation_verbosity = "quiet")
  cad <- sf::st_sf(id = c("A", "B"),
                   geometry = .ug_sfc(list(c(0, 200, 0, 100), c(200, 400, 0, 100))))
  onf <- .ug_onf(list(c(6, 206, 4, 104), c(206, 406, 4, 104)))

  defaut <- croiser_parcelles_onf(onf, cad)
  expect_identical(defaut, croiser_parcelles_onf(onf, cad, calage_elastique = FALSE))

  # Le décalage de (6, 4) m laisse hors ONF un liseré de 6 x 100 + 4 x 400 m²
  # le long des limites cadastrales ; calée, l'ONF le recouvre presque.
  hors <- function(x) sum(x$surface_ha[x$hors_ugf]) * 1e4
  brut <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE, min_surface_ha = 0)
  cale <- croiser_parcelles_onf(onf, cad, inclure_reste = TRUE, min_surface_ha = 0,
                                calage_elastique = TRUE)
  expect_gt(hors(brut), 2000)
  expect_lt(hors(cale), 0.2 * hors(brut))
  # Le cadastre ne bouge pas : chaque parcelle reste pavée.
  pav <- tapply(cale$surface_ha, cale$parcelle_cadastrale, sum)
  expect_equal(as.numeric(pav), c(2, 2), tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# Non-régression réseau : Couchey (21200), brief du 2026-10-08
# ---------------------------------------------------------------------------

test_that("Couchey: 19 parcels, about 63 UGF, none under 2 ha (live)", {
  skip_on_cran()
  skip_on_ci()
  skip_if_offline()
  skip_if_not(identical(tolower(Sys.getenv("NEMETON_TEST_ONF_LIVE")), "true"),
              "NEMETON_TEST_ONF_LIVE is not 'true'")
  skip_if_not_installed("arrow")
  skip_if_not_installed("happign")

  # Emprise du projet Couchey (23 parcelles), en Lambert-93.
  aoi <- sf::st_as_sfc(sf::st_bbox(c(xmin = 843644, ymin = 6685580,
                                     xmax = 849240, ymax = 6688419),
                                   crs = sf::st_crs(2154)))
  out <- construire_ugf_onf(aoi, insee = "21200")
  skip_if(is.null(out), "a source is unreachable")

  pa <- attr(out, "parcelles")
  expect_equal(sum(pa$retenue), 19L)
  ugf <- tapply(out$surface_m2, out$ugf_id, sum) / 1e4
  expect_equal(length(ugf), 63L, tolerance = 0.1)
  expect_false(any(startsWith(names(ugf), "cad~")))
  expect_gte(min(ugf), 2)
})
