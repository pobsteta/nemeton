# Détection de la décoloration (mission 046) — cas limites 1 à 8 de la fiche

# --- fixtures --------------------------------------------------------------

# Grille de n x n pixels, même essence ; renvoie rc (ligne, colonne)
.fx_grille <- function(n) {
  rc <- as.matrix(expand.grid(r = seq_len(n), c = seq_len(n)))
  unname(rc)
}

# Séries : effet année a_j + effet pixel e_q (le repli doit annuler e)
.fx_annees <- 2017:2026
.fx_a <- c(0.50, 0.52, 0.49, 0.51, 0.53, 0.50, 0.48, 0.52, 0.51, 0.50)

.fx_X <- function(rc) {
  e <- ((seq_len(nrow(rc)) %% 3) - 1) * 0.01
  outer(e, .fx_a, "+")
}

# --- 1. indices ------------------------------------------------------------

test_that("indices : valeurs connues sur des réflectances synthétiques", {
  b <- list(B03 = 0.08, B04 = 0.04, B05 = 0.2, B06 = 0.3, B07 = 0.4,
            B08 = 0.4, B8A = 0.3, B11 = 0.25, B12 = 0.2)
  i <- nemeton:::.decol_indices(b)
  expect_equal(i$GRVI, (0.08 - 0.04) / (0.08 + 0.04))
  expect_equal(i$NDVI, (0.4 - 0.04) / (0.4 + 0.04))
  expect_equal(i$CIRE, 1)
  k <- (1613.7 - 864.7) / (2202.4 - 864.7)
  expect_equal(i$CRSWIR, 0.25 / (0.3 + (0.2 - 0.3) * k))
  kr <- (704 - 665) / (741 - 665)
  expect_equal(i$CRRE, 0.2 / (0.04 + (0.3 - 0.04) * kr))
})

test_that("indices : l'offset de 1000 ne s'applique qu'à la baseline >= 04.00 (chemin de production)", {
  g <- terra::rast(nrows = 1, ncols = 1, xmin = 0, xmax = 20, ymin = 0, ymax = 20,
                   crs = "EPSG:2154")
  lire <- function(b, m) {
    x <- g
    terra::values(x) <- switch(b, SCL = 4, B04 = 1500, B08 = 2500, 2000)
    x
  }
  ndvi <- function(id) terra::values(nemeton:::.decol_indices_scene(lire, id)[["NDVI"]])[1]
  nouveau <- "S2B_MSIL2A_20230610T103031_N0509_R108_T31TGM_20230610T150000"
  ancien  <- "S2A_MSIL2A_20190610T103031_N0207_R108_T31TGM_20190610T150000"
  expect_equal(ndvi(nouveau), (1500 - 500) / (1500 + 500))   # offset retiré
  expect_equal(ndvi(ancien), (2500 - 1500) / (2500 + 1500))  # inchangé
  # réflectance <= 0 après offset : valeur écartée (NA)
  lire0 <- function(b, m) { x <- g; terra::values(x) <- if (b == "SCL") 4 else 900; x }
  expect_true(is.na(terra::values(nemeton:::.decol_indices_scene(lire0, nouveau)[["NDVI"]])[1]))
})

# --- 2. composite ----------------------------------------------------------

test_that("composite : médiane des valeurs valides, mois sans image = NA", {
  g <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 40, ymin = 0, ymax = 40,
                   crs = "EPSG:2154")
  sc <- function(v) {
    r <- terra::rast(lapply(1:5, function(k) { x <- g; terra::values(x) <- v; x }))
    names(r) <- nemeton:::.DECOL_INDICES
    r
  }
  s <- list(sc(c(0.1, 0.2, NA, 0.5)), sc(c(0.3, NA, NA, 0.7)), sc(c(0.5, 0.4, NA, 0.9)))
  m <- nemeton:::.decol_mediane_scenes(s, g)
  expect_equal(unname(terra::values(m[["GRVI"]])[, 1]), c(0.3, 0.3, NA, 0.7))
  vide <- nemeton:::.decol_mediane_scenes(list(), g)
  expect_true(all(is.na(terra::values(vide))))
})

test_that("composite : les classes SCL masquées sont retirées", {
  g <- terra::rast(nrows = 1, ncols = 3, xmin = 0, xmax = 60, ymin = 0, ymax = 20,
                   crs = "EPSG:2154")
  cst <- function(v) { x <- g; terra::values(x) <- v; x }
  lire <- function(b, m) {
    if (b == "SCL") return(cst(c(4, 9, 3)))     # végétation, nuage, ombre
    cst(c(3000, 3000, 3000)) + c(B03 = 0, B04 = -500, B05 = 0, B06 = 0, B07 = 0,
                                 B08 = 500, B8A = 0, B11 = 0, B12 = 0)[[b]]
  }
  r <- nemeton:::.decol_indices_scene(lire, "S2B_MSIL2A_20230610T103031_N0509_R108_T31TGM_X")
  expect_false(is.na(terra::values(r[["NDVI"]])[1]))
  expect_true(is.na(terra::values(r[["NDVI"]])[2]))
  expect_true(is.na(terra::values(r[["NDVI"]])[3]))
})

test_that("composite : écriture atomique, relecture et composite illisible refait", {
  withr::with_tempdir({
    g <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 40, ymin = 0, ymax = 40,
                     crs = "EPSG:2154")
    r <- terra::rast(lapply(1:5, function(k) { x <- g; terra::values(x) <- c(0.1234, 0.2, 0.3, NA) * k / 5; x }))
    names(r) <- nemeton:::.DECOL_INDICES
    f <- nemeton:::.decol_composite_chemin(getwd(), 2022, 7, g)
    nemeton:::.decol_composite_ecrire(r, f)
    expect_true(file.exists(f))
    expect_length(list.files(dirname(f), "part"), 0)
    rr <- nemeton:::.decol_composite_lire(f, g)
    expect_equal(unname(terra::values(rr[["GRVI"]])[1:3, 1]), c(0.1234, 0.2, 0.3) / 5 * 1, tolerance = 2e-3)
    # autre grille : erreur claire à la relecture
    g2 <- terra::rast(nrows = 2, ncols = 2, xmin = 20, xmax = 60, ymin = 0, ymax = 40,
                      crs = "EPSG:2154")
    expect_error(nemeton:::.decol_composite_lire(f, g2), "different grid")
    # déjà fait, mois fini depuis longtemps : rien à refaire
    expect_false(nemeton:::.decol_composite_a_faire(f, 2022, 7, as.Date("2026-11-24")))
    # illisible : supprimé et à refaire
    writeLines("pas un tif", f)
    expect_true(nemeton:::.decol_composite_a_faire(f, 2022, 7, as.Date("2026-11-24")))
    expect_false(file.exists(f))
    # mois en cours (pas fini depuis 5 jours) et mois futur : jamais refaits
    f2 <- nemeton:::.decol_composite_chemin(getwd(), 2026, 11, g)
    expect_false(nemeton:::.decol_composite_a_faire(f2, 2026, 11, as.Date("2026-11-24")))
    expect_false(nemeton:::.decol_composite_a_faire(f2, 2026, 12, as.Date("2026-11-24")))
    # mois fini depuis plus de 5 jours, pas de fichier : à faire
    expect_true(nemeton:::.decol_composite_a_faire(f2, 2026, 10, as.Date("2026-11-24")))
  })
})

test_that("composite : catalogue injoignable -> mois non enregistré, événement émis", {
  withr::with_tempdir({
    ev <- list()
    testthat::local_mocked_bindings(
      .decol_chercher_scenes = function(...) stop("catalogue down"))
    g <- terra::rast(nrows = 2, ncols = 2, xmin = 800000, xmax = 800040,
                     ymin = 6700000, ymax = 6700040, crs = "EPSG:2154")
    emprise <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(g)))
    ok <- nemeton:::.decol_composite_assurer(2022, 7, g, emprise, getwd(),
                                             emit = function(p) ev[[length(ev) + 1]] <<- p,
                                             aujourdhui = as.Date("2026-11-24"))
    expect_false(ok)
    expect_equal(ev[[1]]$current, "decoloration:catalogue_injoignable")
  })
})

# --- 3. anomalie propre ----------------------------------------------------

test_that("anomalie propre : 3 années de référence -> NA, 4 -> valeur", {
  an <- 2017:2022
  # pixel A : 4 années valides au total (3 de référence pour l'une d'elles)
  A <- c(1, 2, 3, 4, NA, NA); B <- c(1, 2, 3, 4, 5, NA)
  X <- rbind(A, B)
  z <- nemeton:::.decol_zscore(X, an, an, 0.01, c(1L, 1L), cbind(1:2, 1L), repli = FALSE)
  expect_true(is.na(z$z[1, 4]))              # 3 autres années
  expect_equal(z$origine[1, 4], 0L)
  expect_equal(z$z[2, 5], (5 - median(c(1, 2, 3, 4))) / (1.4826 * 1), tolerance = 1e-4)
  expect_equal(z$origine[2, 5], 1L)
})

# --- 4. pixel coupé en 2019 : repli par les voisins ------------------------

.fx_coupe_2019 <- function(rc, X, p) {
  coupe <- matrix(FALSE, nrow(X), ncol(X))
  coupe[p, .fx_annees >= 2019] <- TRUE
  coupe
}

test_that("pixel coupé en 2019 : sans repli pas d'anomalie en 2018, avec repli origine voisins", {
  rc <- .fx_grille(30); X <- .fx_X(rc)
  p <- which(rc[, 1] == 15 & rc[, 2] == 15)
  coupe <- .fx_coupe_2019(rc, X, p)
  ess <- rep(1L, nrow(rc))
  sans <- nemeton:::.decol_zscore(X, .fx_annees, .fx_annees, 0.01, ess, rc, coupe, repli = FALSE)
  expect_true(is.na(sans$z[p, 2]))                     # 2018
  avec <- nemeton:::.decol_zscore(X, .fx_annees, .fx_annees, 0.01, ess, rc, coupe, repli = TRUE)
  expect_equal(avec$origine[p, 2], 2L)
  expect_equal(avec$origine[p, 1], 2L)                 # 2017 aussi
  # valeur attendue à la main : l'effet du pixel et celui des voisins s'annulent,
  # reste (a_2018 - médiane des autres années) / max(MAD, plancher)
  a_autres <- .fx_a[-2]
  attendu <- (.fx_a[2] - median(a_autres)) / max(mad(a_autres), 0.01)
  expect_equal(avec$z[p, 2], attendu, tolerance = 1e-8)
  # les autres pixels gardent leur normale propre
  expect_equal(avec$origine[1, 5], 1L)
  # pixel coupé : plus de valeur après la coupe
  expect_true(is.na(avec$z[p, 3]))
})

# --- 5. moins de 20 voisins ------------------------------------------------

test_that("moins de 20 voisins : NA et origine aucune, jamais niveau 0", {
  rc <- .fx_grille(4); X <- .fx_X(rc)               # 16 pixels < 20
  p <- 6
  coupe <- .fx_coupe_2019(rc, X, p)
  r <- nemeton:::.decol_zscore(X, .fx_annees, .fx_annees, 0.01, rep(1L, 16), rc, coupe)
  expect_true(is.na(r$z[p, 2]))
  expect_equal(r$origine[p, 2], 0L)
  # l'ICD est NA (pas 0) et le niveau aussi
  w <- matrix(1 / 5, 16, 5, dimnames = list(NULL, nemeton:::.DECOL_INDICES))
  zs <- lapply(nemeton:::.DECOL_INDICES, function(i) r)
  names(zs) <- nemeton:::.DECOL_INDICES
  icd <- nemeton:::.decol_icd(zs, w)
  expect_true(is.na(icd$icd[p, 2]))
  expect_equal(icd$origine[p, 2], 0L)
  al <- nemeton:::.decol_alerte(matrix(icd$icd[p, 2], 1))
  expect_true(is.na(nemeton:::.decol_niveau(al$classe, al$icd_min, FALSE)))
})

# --- 6. sécheresse régionale ----------------------------------------------

test_that("sécheresse régionale : l'anomalie de repli la voit, elle ne s'annule pas", {
  rc <- .fx_grille(30); X <- .fx_X(rc)
  X[, 2] <- X[, 2] - 0.2                             # tous les pixels baissent en 2018
  p <- which(rc[, 1] == 15 & rc[, 2] == 15)
  coupe <- .fx_coupe_2019(rc, X, p)
  r <- nemeton:::.decol_zscore(X, .fx_annees, .fx_annees, 0.01, rep(1L, nrow(rc)), rc, coupe)
  expect_equal(r$origine[p, 2], 2L)
  expect_lt(r$z[p, 2], -5)
})

# --- 7. ICD ----------------------------------------------------------------

test_that("ICD : poids et signes du § 7, indice sans poids ignoré", {
  tab <- nemeton:::.decol_essences()
  expect_equal(rowSums(tab[, grep("^w_", names(tab))]), rep(1, 4))
  un <- list(z = matrix(1, 1, 1), origine = matrix(1L, 1, 1))
  zs <- stats::setNames(rep(list(un), 5), nemeton:::.DECOL_INDICES)
  w_de <- function(e) matrix(unlist(tab[e, paste0("w_", nemeton:::.DECOL_INDICES)]), 1,
                             dimnames = list(NULL, nemeton:::.DECOL_INDICES))
  expect_equal(nemeton:::.decol_icd(zs, w_de(1))$icd[1, 1], 0.15 + 0.25 - 0.15 - 0.20 + 0.25)
  expect_equal(nemeton:::.decol_icd(zs, w_de(2))$icd[1, 1], 0.30 + 0.25 - 0.15 - 0.15 + 0.15)
  # conifères : CRRE sans poids, son z manquant n'efface pas l'ICD
  zs$CRRE <- list(z = matrix(NA_real_, 1, 1), origine = matrix(NA_integer_, 1, 1))
  expect_equal(nemeton:::.decol_icd(zs, w_de(3))$icd[1, 1], 0.35 + 0.15 - 0.35 + 0.15)
  # mois suivis par essence
  m <- nemeton:::.decol_mois_essence()
  expect_equal(m$chene, 6:8); expect_equal(m$hetre, 7:8)
  expect_equal(m$sapin_epicea, 6:10); expect_equal(m$douglas, 4:9)
})

# --- 8. alerte et niveaux ---------------------------------------------------

test_that("alerte : persistance de 2 mois valides, surveillance, normal", {
  f <- nemeton:::.decol_alerte_pixel
  expect_equal(f(c(-2.5, -2.1, 0)), c(2, -2.5))
  expect_equal(f(c(-2.5, NA, -2.1)), c(2, -2.5))     # mois valides consécutifs
  expect_equal(f(c(-2.5, -1, -2.5)), c(1, -2.5))     # jamais 2 de suite
  expect_equal(f(c(-1.6, 0)), c(1, -1.6))
  expect_equal(f(c(-1, 0)), c(0, -1))
  expect_true(is.na(f(c(NA, NA))[1]))
})

test_that("niveaux : 2, 3 (ICD min < -3) et 4 (alerte l'année d'avant)", {
  n <- nemeton:::.decol_niveau
  expect_equal(n(c(0, 1, 2, 2, 2), c(0, -1.6, -2.5, -3.5, -3.5), c(FALSE, FALSE, FALSE, FALSE, TRUE)),
               c(0L, 1L, 2L, 3L, 4L))
  expect_true(is.na(n(NA_real_, NA_real_, TRUE)))
})

test_that("détection complète : niveaux 3 puis 4, indice « à date », origine propre", {
  withr::with_tempdir({
    ext <- sf::st_as_sfc(sf::st_bbox(c(xmin = 800000, ymin = 6700000,
                                       xmax = 800500, ymax = 6700500), crs = 2154))
    g <- nemeton:::.decol_grille(ext)
    yrs <- 2017:2023
    eff <- c(0, 0.01, -0.01, 0.02, -0.02, 0.01, 0)
    base <- c(GRVI = 0.2, CIRE = 3, CRSWIR = 0.9, CRRE = 1.1, NDVI = 0.8)
    mult <- c(GRVI = 1, CIRE = 5, CRSWIR = 1, CRRE = 1, NDVI = 1)
    sens <- nemeton:::.DECOL_SENS
    bloc <- terra::rast(g); terra::values(bloc) <- 0
    bloc[1:5, ] <- 1                                  # 5 lignes dégradées
    for (j in seq_along(yrs)) for (m in 4:10) {
      couches <- lapply(names(base), function(i) {
        r <- terra::rast(g); terra::values(r) <- base[[i]] + eff[j] * mult[[i]]
        dec <- yrs[j] %in% c(2022, 2023) && m %in% c(5, 6, 7, 8)
        if (dec) r <- r - bloc * sens[[i]] * 0.15 * mult[[i]]
        r
      })
      comp <- terra::rast(couches); names(comp) <- names(base)
      nemeton:::.decol_composite_ecrire(comp, nemeton:::.decol_composite_chemin(getwd(), yrs[j], m, g))
    }
    ess <- terra::rast(g); terra::values(ess) <- 1L
    res <- decoloration_detecter(ext, yrs, ess, dossier_cache = getwd(),
                                 calculer_composites = FALSE)
    niv <- terra::values(res$niveaux)
    colnames(niv) <- yrs
    expect_true(all(niv[bloc[] == 1, "2022"] == 3))
    expect_true(all(niv[bloc[] == 1, "2023"] == 4))    # alerte aussi l'année d'avant
    expect_true(all(niv[bloc[] == 0, ] == 0))
    expect_true(all(terra::values(res$origine) == 1))
    # le mois 5 est hors saison du chêne : il n'a pas compté
    # indice « à date » : jusqu'en juin, un seul mois suivi -> pas d'alerte
    date <- decoloration_detecter(ext, yrs, ess, dossier_cache = getwd(),
                                  calculer_composites = FALSE, mois_a_date = 6)
    nd <- terra::values(date$niveaux); colnames(nd) <- yrs
    expect_true(all(nd[bloc[] == 1, "2022"] == 1))
    expect_equal(dim(terra::values(res$icd_min)), dim(niv))
  })
})

# --- carte d'essences -------------------------------------------------------

test_that("carte d'essences : codes TFV, libellé en préfixe, retrait de lisière", {
  p <- sf::st_sfc(
    sf::st_polygon(list(rbind(c(800000, 6700000), c(800100, 6700000), c(800100, 6700100),
                              c(800000, 6700100), c(800000, 6700000)))),
    sf::st_polygon(list(rbind(c(800100, 6700000), c(800200, 6700000), c(800200, 6700100),
                              c(800100, 6700100), c(800100, 6700000)))),
    sf::st_polygon(list(rbind(c(800000, 6700100), c(800100, 6700100), c(800100, 6700200),
                              c(800000, 6700200), c(800000, 6700100)))), crs = 2154)
  x <- sf::st_sf(TFV = c("FF1G01-01", "FF2-64-64 Foret fermee de douglas pur", "FF1-00-00"),
                 geometry = p)
  r <- decoloration_carte_essences(x, p)
  v <- terra::values(r)[, 1]
  expect_setequal(unique(v[!is.na(v)]), c(1, 4))
  expect_gt(sum(v == 1, na.rm = TRUE), 3)
  expect_lt(sum(v == 1, na.rm = TRUE), 25)           # la lisière de 10 m est retirée
  expect_equal(sum(!is.na(v)), sum(v %in% c(1, 4)))  # TFV inconnu ignoré
  expect_error(decoloration_carte_essences(sf::st_sf(AUTRE = "x", geometry = p[1]), p),
               "TFV")
})

# --- revue de la PR : cache par grille, à date, repli, robustesse ------------

test_that("deux emprises, même cache : résultats égaux à ceux de caches séparés", {
  withr::with_tempdir({
    yrs <- 2017:2022
    eff <- c(0, 0.01, -0.01, 0.02, -0.02, 0.01)
    base <- c(GRVI = 0.2, CIRE = 3, CRSWIR = 0.9, CRRE = 1.1, NDVI = 0.8)
    mult <- c(GRVI = 1, CIRE = 5, CRSWIR = 1, CRRE = 1, NDVI = 1)
    ecrire <- function(g, cache, deg) {
      for (j in seq_along(yrs)) for (m in 4:10) {
        comp <- terra::rast(lapply(names(base), function(i) {
          r <- terra::rast(g); v <- base[[i]] + eff[j] * mult[[i]]
          terra::values(r) <- v + (seq_len(terra::ncell(g)) %% 7) * 1e-3
          if (yrs[j] == 2022 && m %in% 6:7 && deg)
            r <- r - nemeton:::.DECOL_SENS[[i]] * 0.15 * mult[[i]]
          r
        }))
        names(comp) <- names(base)
        nemeton:::.decol_composite_ecrire(comp, nemeton:::.decol_composite_chemin(cache, yrs[j], m, g))
      }
    }
    mk <- function(x0) sf::st_as_sfc(sf::st_bbox(c(xmin = x0, ymin = 6700000, xmax = x0 + 300,
                                                   ymax = 6700300), crs = 2154))
    eA <- mk(800000); eB <- mk(800100)                       # B décalée de 5 pixels
    gA <- nemeton:::.decol_grille(eA); gB <- nemeton:::.decol_grille(eB)
    expect_false(identical(nemeton:::.decol_empreinte_grille(gA), nemeton:::.decol_empreinte_grille(gB)))
    ess <- function(g) { r <- terra::rast(g); terra::values(r) <- 1L; r }
    # cache partagé : A dégradée, B saine
    ecrire(gA, "partage", TRUE); ecrire(gB, "partage", FALSE)
    ecrire(gB, "seul", FALSE)
    rB1 <- decoloration_detecter(eB, yrs, ess(gB), dossier_cache = "partage", calculer_composites = FALSE)
    rB2 <- decoloration_detecter(eB, yrs, ess(gB), dossier_cache = "seul", calculer_composites = FALSE)
    expect_equal(terra::values(rB1$niveaux), terra::values(rB2$niveaux))
    expect_true(all(terra::values(rB1$niveaux) == 0))
    rA <- decoloration_detecter(eA, yrs, ess(gA), dossier_cache = "partage", calculer_composites = FALSE)
    expect_true(all(terra::values(rA$niveaux[["2022"]]) >= 2))
  })
})

test_that("indice à date automatique : dernier composite, mois en cours dès le 20e jour", {
  withr::with_tempdir({
    g <- terra::rast(nrows = 1, ncols = 1, xmin = 0, xmax = 20, ymin = 0, ymax = 20, crs = "EPSG:2154")
    r <- terra::rast(lapply(1:5, function(k) { x <- g; terra::values(x) <- 0.5; x }))
    names(r) <- nemeton:::.DECOL_INDICES
    for (m in 4:7) nemeton:::.decol_composite_ecrire(r, nemeton:::.decol_composite_chemin(getwd(), 2026, m, g))
    f <- nemeton:::.decol_mois_a_date
    expect_equal(f(getwd(), g, 2026, as.Date("2026-07-10")), 6)   # juillet entamé < 20 j
    expect_equal(f(getwd(), g, 2026, as.Date("2026-07-25")), 7)
    expect_equal(f(getwd(), g, 2026, as.Date("2026-11-24")), 7)   # dernier composite
    expect_equal(f(getwd(), g, 2019, as.Date("2026-11-24")), 10)  # aucun : saison entière
  })
})

test_that("repli : décalage ramené à 0 quand toutes les autres années sont écartées, signalé", {
  rc <- .fx_grille(30); X <- .fx_X(rc)
  p <- which(rc[, 1] == 15 & rc[, 2] == 15)
  coupe <- .fx_coupe_2019(rc, X, p)
  # 2017 : presque tous les voisins sans valeur -> année 2017 écartée du décalage
  X[setdiff(seq_len(nrow(X)), p), 1] <- NA
  r <- nemeton:::.decol_zscore(X, .fx_annees, .fx_annees, 0.01, rep(1L, nrow(rc)), rc, coupe)
  # évaluée en 2018, la seule autre année du pixel (2017) est écartée
  expect_true(r$decalage_nul[p, 2])
  expect_equal(r$origine[p, 2], 2L)
  expect_false(any(r$decalage_nul[-p, ]))
})

test_that("composite : second essai des scènes en échec", {
  withr::with_tempdir({
    options(nemeton.decoloration_pause_s = 0)
    on.exit(options(nemeton.decoloration_pause_s = NULL), add = TRUE)
    essais <- 0L
    testthat::local_mocked_bindings(
      .decol_chercher_scenes = function(...) data.frame(scene_id = c("S2B_MSIL2A_20220610T103031_N0400_R108_T31TGM_X")),
      .decol_indices_scene = function(...) {
        essais <<- essais + 1L
        if (essais == 1L) stop("réseau coupé")
        NULL
      })
    g <- terra::rast(nrows = 2, ncols = 2, xmin = 800000, xmax = 800040,
                     ymin = 6700000, ymax = 6700040, crs = "EPSG:2154")
    emprise <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(g)))
    ok <- nemeton:::.decol_composite_assurer(2022, 6, g, emprise, getwd(),
                                             aujourdhui = as.Date("2026-11-24"))
    expect_equal(essais, 2L)
    expect_true(ok)   # le second essai a réussi : composite enregistré
  })
})

test_that("bandes 10 m : aperçu natif lu et mis en cache, repli sur le lecteur sinon", {
  withr::with_tempdir({
    g <- terra::rast(nrows = 40, ncols = 40, xmin = 800000, xmax = 800400,
                     ymin = 6700000, ymax = 6700400, crs = "EPSG:2154")
    terra::values(g) <- seq_len(1600)
    terra::writeRaster(g, "B04.tif", overwrite = TRUE)
    # sans aperçu : NULL (le lecteur ordinaire prend le relais)
    sc0 <- data.frame(scene_id = "sans_apercu", href_B04 = normalizePath("B04.tif"),
                      stringsAsFactors = FALSE)
    emp0 <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(g)))
    expect_null(nemeton:::.decol_lire_apercu(sc0, "B04", emp0, getwd()))
    sf::gdal_addo("B04.tif", method = "AVERAGE", overviews = 2)
    sc <- data.frame(scene_id = "S2B_MSIL2A_20220610T103031_N0400_R108_T31TGM_X",
                     href_B04 = normalizePath("B04.tif"), stringsAsFactors = FALSE)
    emprise <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(g)))
    r <- nemeton:::.decol_lire_apercu(sc, "B04", emprise, getwd())
    expect_s4_class(r, "SpatRaster")
    expect_true(file.exists(file.path("decoloration", "apercu20m",
                                      nemeton:::.s2_safe_scene_id(sc$scene_id), "B04.tif")))
    sc$href_B04 <- "/inexistant/B04.tif"
    expect_s4_class(nemeton:::.decol_lire_apercu(sc, "B04", emprise, getwd()), "SpatRaster")  # cache
    sc$scene_id <- "autre"
    expect_null(nemeton:::.decol_lire_apercu(sc, "B04", emprise, getwd()))
  })
})

test_that("carte d'essences : colonne ess_id (1 à 4) acceptée", {
  p <- sf::st_sfc(sf::st_polygon(list(rbind(c(800000, 6700000), c(800100, 6700000),
                  c(800100, 6700100), c(800000, 6700100), c(800000, 6700000)))), crs = 2154)
  r <- decoloration_carte_essences(sf::st_sf(ess_id = 3L, geometry = p), p)
  expect_setequal(unique(stats::na.omit(terra::values(r)[, 1])), 3)
})
