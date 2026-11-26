# ICD : indicateur composite de decoloration (spec 071). Sans reseau ni base.

bandes_ref <- function() {
  data.frame(B03 = 0.06, B04 = 0.04, B05 = 0.08, B06 = 0.2, B07 = 0.3,
             B08 = 0.4, B8A = 0.42, B11 = 0.25, B12 = 0.15)
}

test_that("icd_indices : formules sur valeurs connues", {
  r <- icd_indices(bandes_ref())
  expect_named(r, c("GRVI", "CIre", "CRSWIR", "CRre", "NDVI"))
  expect_equal(r$GRVI, (0.06 - 0.04) / (0.06 + 0.04))
  expect_equal(r$CIre, 0.3 / 0.08 - 1)
  expect_equal(r$NDVI, (0.4 - 0.04) / (0.4 + 0.04))
  # CRSWIR et CRre : memes noyaux que reconfort_indices(), pas de duplication
  rc <- reconfort_indices(data.frame(B4 = 0.04, B5 = 0.08, B6 = 0.2,
                                     B8A = 0.42, B11 = 0.25, B12 = 0.15))
  expect_equal(r$CRSWIR, rc$CRswir)
  expect_equal(r$CRre, rc$CRre)
  # coefficients : (1610-865)/(2190-865) = 0,5623 et (704-665)/(741-665) = 0,5132
  expect_equal(r$CRSWIR, 0.25 / (0.42 + 0.5623 * (0.15 - 0.42)), tolerance = 1e-3)
  expect_equal(r$CRre, 0.08 / (0.04 + 0.5132 * (0.2 - 0.04)), tolerance = 1e-3)
  # B3 = B03, indices a la demande, bande manquante refusee
  expect_equal(icd_indices(stats::setNames(bandes_ref(), sub("B0", "B", names(bandes_ref()))),
                           "NDVI")$NDVI, r$NDVI)
  expect_error(icd_indices(bandes_ref()[, c("B03", "B04")], "CIre"), "absent")
  # denominateur nul : NA
  expect_true(is.na(icd_indices(data.frame(B03 = 0, B04 = 0), "GRVI")$GRVI))
})

test_that("icd_indices : SpatRaster en entree et en sortie", {
  b <- terra::rast(nrows = 2, ncols = 2, nlyrs = 9)
  names(b) <- c("B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B11", "B12")
  v <- unlist(bandes_ref())
  for (i in 1:9) terra::values(b[[i]]) <- v[i]
  r <- icd_indices(b, c("NDVI", "GRVI"))
  expect_s4_class(r, "SpatRaster")
  expect_equal(names(r), c("NDVI", "GRVI"))
  expect_equal(unname(terra::values(r[[1]])[1]), (0.4 - 0.04) / 0.44)
})

test_that("composite mensuel : mediane des valeurs valides, mois vide = NA", {
  M <- rbind(c(1, 3, 2), c(NA, 5, 7), c(NA, NA, NA), c(4, NA, NA))
  expect_equal(.icd_composite(M), c(2, 6, NA, 4))
})

test_that("anomalie z : plancher, annee retiree, moins de 4 annees = NA", {
  an <- 2018:2023
  # un pixel stable (MAD nul -> plancher), annee 2023 chute de 0,1
  X <- matrix(c(0.8, 0.8, 0.8, 0.8, 0.8, 0.7), nrow = 1)
  z <- .icd_z(X, an, plancher = 0.01)
  expect_equal(z[1, 6], (0.7 - 0.8) / 0.01)          # mediane des 5 autres, MAD 0
  expect_equal(z[1, 1], 0 / 0.01)                       # 2018 compare aux autres dont 2023
  # MAD : reference 0,7 0,8 0,9 1,0 -> med 0,85, MAD = 0,1 * 1,4826
  Y <- matrix(c(0.7, 0.8, 0.9, 1.0, 0.5), nrow = 1)
  zy <- .icd_z(Y, 2019:2023, plancher = 0.01)
  expect_equal(zy[1, 5], (0.5 - 0.85) / (0.1 * 1.4826))
  # le plancher borne : MAD 0,001 < plancher 0,02
  W <- matrix(c(0.8, 0.801, 0.799, 0.8, 0.7), nrow = 1)
  expect_equal(.icd_z(W, 2019:2023, plancher = 0.02)[1, 5], (0.7 - 0.8) / 0.02)
  # moins de 4 annees de reference valides : NA
  V <- matrix(c(NA, NA, 0.8, 0.8, 0.7), nrow = 1)
  expect_true(all(is.na(.icd_z(V, 2019:2023, plancher = 0.01))))
  expect_true(all(is.na(.icd_z(matrix(c(1, 2, 3, 4), 1), 2020:2023, 0.01)))) # 3 autres seulement
  # liste d'annees saines fournie : 2023 jugee contre 2019-2022 seulement
  U <- matrix(c(0.8, 0.8, 0.8, 0.8, 0.2, 0.7), nrow = 1)
  zu <- .icd_z(U, 2018:2023, 0.01, annees_reference = 2018:2021)
  expect_equal(zu[1, 6], (0.7 - 0.8) / 0.01)
  # l'annee evaluee n'entre pas dans sa propre reference : 2018 n'a que 3 autres
  # annees de reference (< 4) -> NA ; 2022, hors liste, est jugee contre 4 annees
  expect_true(is.na(zu[1, 1]))
  expect_equal(zu[1, 5], (0.2 - 0.8) / 0.01)
})

test_that("pixel coupe : retire du calcul a partir du mois de la coupe", {
  X <- matrix(1, nrow = 3, ncol = 3)      # annees 2021-2023, mois 7
  dc <- as.Date(c("2022-07-15", "2022-08-02", NA))
  out <- .icd_retirer_coupes(X, 2021:2023, 7L, dc)
  expect_equal(out[1, ], c(1, NA, NA))    # coupe en juillet 2022 : retire des juillet 2022
  expect_equal(out[2, ], c(1, 1, NA))     # coupe en aout 2022 : juillet 2022 garde, 2023 retire
  expect_equal(out[3, ], c(1, 1, 1))
  expect_identical(.icd_retirer_coupes(X, 2021:2023, 7L, NULL), X)
})

test_that("dates SUFOSAT YYDDD : aller-retour date <-> code", {
  d <- as.Date(c("2018-01-01", "2020-02-29", "2023-12-31", "2024-12-31"))
  code <- .icd_date_vers_yyddd(d)
  expect_equal(code, c(18001, 20060, 23365, 24366))
  expect_equal(.icd_yyddd_vers_date(code), d)
  expect_true(is.na(.icd_yyddd_vers_date(c(0, NA))[1]))        # 0 = jamais coupe
  expect_error(.icd_yyddd_vers_date(18400), "Invalid")
  expect_true(is.na(.icd_date_vers_yyddd(NA)))
})

test_that("poids par defaut : valeurs de la note, somme 1, CRre nul pour les resineux", {
  p <- icd_poids_defaut()
  expect_equal(p$essence, c("chene", "hetre", "sapin_epicea", "douglas"))
  expect_equal(unlist(p[1, c("GRVI", "CIre", "CRSWIR", "CRre", "NDVI")]),
               c(GRVI = .15, CIre = .25, CRSWIR = .15, CRre = .20, NDVI = .25))
  expect_equal(unlist(p[4, c("GRVI", "CIre", "CRSWIR", "CRre", "NDVI")]),
               c(GRVI = .45, CIre = .15, CRSWIR = .25, CRre = 0, NDVI = .15))
  expect_equal(unname(rowSums(p[, c("GRVI", "CIre", "CRSWIR", "CRre", "NDVI")])), rep(1, 4))
  expect_equal(p$mois_debut, c(6, 7, 6, 4)); expect_equal(p$mois_fin, c(8, 8, 10, 9))
  expect_equal(p$CRre[3:4], c(0, 0))
})

test_that("poids invalides : refus avec message", {
  p <- icd_poids_defaut()
  neg <- p; neg$GRVI[2] <- -0.1
  expect_error(icd_poids_valider(neg), "negative")
  res <- p; res$CRre[3] <- 0.1
  expect_error(icd_poids_valider(res), "CRre must be 0 for conifers")
  expect_error(icd_poids_valider(p[p$essence != "hetre", ]), "missing species")
  expect_error(icd_poids_valider(rbind(p, transform(p[1, ], essence = "pin"))), "unknown species")
  expect_error(icd_poids_valider(p[, c("essence", "GRVI")]), "lacks")
  nul <- p; nul[1, c("GRVI", "CIre", "CRSWIR", "CRre", "NDVI")] <- 0
  expect_error(icd_poids_valider(nul), "sum to 0")
  na <- p; na$NDVI[1] <- NA
  expect_error(icd_poids_valider(na), "finite")
  expect_error(icd_poids_valider(1:3), "data.frame")
})

test_that("somme des poids differente de 1 : renormalisee a 1 et dite", {
  p <- icd_poids_defaut()
  expect_silent(icd_poids_valider(p))
  p$GRVI[1] <- 0.30                       # chene : somme 1,15
  p$NDVI[4] <- 0.30                       # douglas : somme 1,15
  expect_message(v <- icd_poids_valider(p), "rescaled")
  expect_equal(unname(rowSums(v[, c("GRVI", "CIre", "CRSWIR", "CRre", "NDVI")])), rep(1, 4))
  expect_equal(v$GRVI[1], 0.30 / 1.15)
  expect_equal(attr(v, "renormalise"), c("chene", "douglas"))
  expect_equal(unname(attr(v, "somme_saisie")[1]), 1.15)
  expect_equal(v$CRre[4], 0)               # un resineux reste sans CRre
})

test_that("ICD : poids par defaut, poids modifies, CRre ignore pour les resineux", {
  z <- list(GRVI = -2, CIre = -1, CRSWIR = 3, CRre = 2, NDVI = -1)
  p <- icd_poids_defaut()
  wh <- unlist(p[p$essence == "hetre", .ICD_INDICES])
  # ICD = w1 z(GRVI) + w2 z(CIre) - w3 z(CRSWIR) - w4 z(CRre) + w5 z(NDVI)
  attendu <- .30 * -2 + .25 * -1 - .15 * 3 - .15 * 2 + .15 * -1
  expect_equal(.icd_icd(z, wh), attendu)
  # poids modifies : le resultat change
  p2 <- p; p2$GRVI[2] <- 0.6
  wh2 <- unlist(icd_poids_valider(p2)[2, .ICD_INDICES])
  expect_false(isTRUE(all.equal(.icd_icd(z, wh2), attendu)))
  # resineux : CRre a poids nul, un z(CRre) different ne change rien
  wd <- unlist(p[p$essence == "douglas", .ICD_INDICES])
  z2 <- z; z2$CRre <- -50
  expect_equal(.icd_icd(z, wd), .icd_icd(z2, wd))
  # un z manquant d'un indice pondere : NA ; d'un indice de poids nul : sans effet
  z3 <- z; z3$CRre <- NA
  expect_true(is.na(.icd_icd(z3, wh)))
  expect_false(is.na(.icd_icd(z3, wd)))
})

test_that("classes : alerte (persistance 2 mois), surveillance, normal, date d'alerte", {
  mois <- 6:8
  M <- rbind(
    c(-2.5, -2.1, 0),      # alerte des juin
    c(0, -2.2, -2.6),      # alerte, date = juillet
    c(-2.5, 0, -2.5),      # un mois isole, pas de persistance : surveillance
    c(-1.6, 0, 0),         # surveillance
    c(0.5, 0.2, -1),       # normal
    c(-2.5, NA, -2.5),     # un mois NA rompt la suite : surveillance
    c(NA, NA, NA))         # aucun mois valide
  a <- .icd_classe_annuelle(M, mois)
  expect_equal(a$classe, c(2, 2, 1, 1, 0, 1, NA))
  expect_equal(a$mois_alerte, c(6L, 7L, NA, NA, NA, NA, NA))
  expect_equal(a$icd_min, c(-2.5, -2.6, -2.5, -1.6, -1, -2.5, NA))
  # seuils stricts : -2 exactement n'est pas une alerte, -1,5 non plus
  b <- .icd_classe_annuelle(rbind(c(-2, -2, -2), c(-1.5, 0, 0)), mois)
  expect_equal(b$classe, c(1, 0))
})

test_that("niveaux 0 a 4", {
  classe <- c(0, 1, 2, 2, 2, 2, NA)
  icd_min <- c(0, -1.7, -2.5, -3.5, -2.5, -3.5, NA)
  prec <-   c(NA, NA, 0, 0, 2, 2, NA)
  expect_equal(.icd_niveaux(classe, icd_min, prec), c(0, 1, 2, 3, 4, 4, NA))
  # exactement -3 : pas de niveau 3
  expect_equal(.icd_niveaux(2, -3, 0), 2)
})

test_that("indice a date : mois lisibles et mois en cours", {
  expect_equal(.icd_mois_utilisables(as.Date("2026-07-31")), 4:7)
  expect_equal(.icd_mois_utilisables(as.Date("2026-07-19")), 4:6)   # juillet entame depuis < 20 j
  expect_equal(.icd_mois_utilisables(as.Date("2026-07-20")), 4:7)
  expect_equal(.icd_mois_utilisables(as.Date("2026-03-10")), integer(0))
  expect_equal(.icd_mois_utilisables(as.Date("2026-11-26")), 4:10)
  # mois en cours : jusqu'a 5 jours apres sa fin
  expect_true(.icd_mois_en_cours(2026, 7L, as.Date("2026-08-04")))
  expect_false(.icd_mois_en_cours(2026, 7L, as.Date("2026-08-06")))
  # lecture a date : le niveau d'une annee passee est relu sur les memes mois
  M <- matrix(c(0, 0, 0, 0, 0, 0, -3, -3, -3, -3, -3, -3), nrow = 1)  # 7 mois : seuls aout-oct bas
  M <- matrix(c(NA, NA, 0, 0, -3, -3, -3), nrow = 1)                  # avril..oct
  ess <- 4L  # douglas, avril-septembre
  complet <- .icd_annuel(M, ess, NULL, NULL)
  a_date  <- .icd_annuel(M, ess, NULL, 4:7)                           # fin juillet
  expect_equal(complet$classe, 2)
  expect_equal(a_date$classe, 0)
  expect_equal(a_date$n_mois_valides, 2L)
})

test_that("kappa et classes FAST", {
  expect_equal(.icd_kappa(c(1, 1, 0, 0), c(1, 1, 0, 0)), 1)
  expect_equal(.icd_kappa(c(1, 0, 1, 0), c(0, 1, 0, 1)), -1)
  expect_true(is.na(.icd_kappa(c(1, 1), c(1, 1))))
  cl <- .icd_classes_fast(c(0, 0, 1, 2, 3, 4, 5, 6, 7, 8))
  expect_equal(cl[1:2], c(0, 0))
  expect_true(all(cl[3:10] %in% 1:4)); expect_equal(max(cl), 4)
})

test_that("S2 : les bandes ajoutees pour l'ICD ne changent pas ce que lit FAST", {
  expect_true(all(c("B03", "B06", "B07", "SCL") %in% .S2_STAC_BANDS))
  expect_identical(.S2_STAC_REQUIRED_BANDS, c("B04", "B08", "B12"))
  expect_true(all(.ICD_BANDES %in% .S2_STAC_BANDS))
})

# --- Chaine complete sur un cache fabrique (sans reseau) ---------------------

fabriquer_cache <- function(racine, annees = 2019:2023, mois = 7:8,
                            degrade = list(annee = 2023, pixels = c(1L, 2L)),
                            bruit = 0.003,
                            facteurs = c(B04 = 1.5, B08 = 0.6, B07 = 0.6, B8A = 0.6)) {
  g <- terra::rast(xmin = 850000, xmax = 850200, ymin = 6700000, ymax = 6700200,
                   resolution = 20, crs = "EPSG:2154")
  base <- c(B03 = 600, B04 = 400, B05 = 800, B06 = 2000, B07 = 3000,
            B08 = 4000, B8A = 4200, B11 = 2500, B12 = 1500)
  set.seed(1)
  for (a in annees) for (m in mois) for (jour in c(5, 20)) {
    sid <- sprintf("S2A_MSIL2A_%04d%02d%02dT103031_N0214_R108_T31TFM_%04d%02d%02dT133000",
                   a, m, jour, a, m, jour)
    d <- file.path(racine, sid); dir.create(d, recursive = TRUE)
    f <- 1 + stats::rnorm(1, 0, bruit)
    for (b in names(base)) {
      v <- rep(base[[b]] * f, terra::ncell(g))
      if (a == degrade$annee) {
        k <- degrade$pixels
        v[k] <- v[k] * (if (b %in% names(facteurs)) facteurs[[b]] else 1)
      }
      terra::writeRaster(terra::setValues(g, v), file.path(d, paste0(b, ".tif")),
                         overwrite = TRUE, datatype = "FLT4S")
    }
    scl <- rep(4, terra::ncell(g))
    if (jour == 5) scl[3] <- 9      # un nuage sur le pixel 3 le 5 : l'autre image sert
    terra::writeRaster(terra::setValues(g, scl), file.path(d, "SCL.tif"),
                       overwrite = TRUE, datatype = "INT1U")
  }
  g
}

zone_et_foret <- function(g) {
  bb <- sf::st_bbox(c(xmin = 849900, ymin = 6699900, xmax = 850300, ymax = 6700300),
                    crs = sf::st_crs(2154))
  poly <- sf::st_as_sfc(bb)
  zone <- sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(terra::ext(g), crs = sf::st_crs(2154))))
  list(zone = zone,
       bdforet = sf::st_sf(code_tfv = "FF1-09-09", geometry = poly))
}

test_that("run_icd_decoloration : chaine complete, alertes, serie d'un pixel, poids", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  tmp <- withr::local_tempdir()
  cache <- file.path(tmp, "cache"); dir.create(cache)
  g <- fabriquer_cache(cache)
  zf <- zone_et_foret(g)
  evts <- character(0)
  res <- run_icd_decoloration(
    con = NULL, zone_id = 7L, cache_dir = cache, result_dir = file.path(tmp, "icd"),
    bdforet = zf$bdforet, aoi = zf$zone, ingest = FALSE, write_alerts = FALSE,
    start_year = 2019L, end_year = 2023L, today = as.Date("2023-11-15"),
    progress_callback = function(p) evts <<- c(evts, p$current))
  expect_equal(res$status, "success")
  expect_equal(evts[1], "icd:start"); expect_equal(evts[length(evts)], "icd:complete")
  expect_true(all(c("icd:composite", "icd:anomalies", "icd:annuel") %in% evts))
  expect_false(res$coupes_retirees)
  expect_equal(res$n_pixels_icd, 100L)
  expect_equal(res$n_pixels_sans_icd, 0L)

  # composites : un par mois avec image (juillet, aout) et par annee
  zdir <- res$zone_dir
  expect_length(list.files(file.path(zdir, "composites"), "\\.tif$"), 10L)
  # niveau 2023 : pixels 1 et 2 degrades (alerte forte), le reste normal ;
  # le pixel 3 (nuage le 5) reste normal grace a l'autre image du mois
  niv <- read_icd_raster(7L, 2023L, file.path(tmp, "icd"), "niveau")
  v <- terra::values(niv, mat = FALSE)
  expect_equal(v[1:2], c(3, 3))
  expect_true(all(v[-(1:2)] == 0))
  expect_equal(attr(niv, "n_pixels_icd"), 100L)
  expect_equal(terra::values(read_icd_raster(7L, 2023L, file.path(tmp, "icd"), "mois_alerte"),
                             mat = FALSE)[1], 7)
  expect_equal(terra::values(read_icd_raster(7L, 2022L, file.path(tmp, "icd"), "niveau"),
                             mat = FALSE)[1], 0)
  expect_null(read_icd_raster(7L, 2030L, file.path(tmp, "icd")))

  # alertes en centroides (pas d'ecriture en base ici)
  al <- .icd_alertes_sf(zdir, 2023L, terra::rast(file.path(zdir, "essence.tif")))
  expect_s3_class(al, "sf")
  expect_equal(sum(al$n_pixels), 2)
  expect_equal(unique(al$confidence_class), "alerte_forte")
  expect_equal(as.character(unique(al$trigger_date)), "2023-07-01")

  # serie d'un pixel : par annee et par mois, brut et z, ICD, seuils, classe
  xy <- terra::xyFromCell(g, 1)
  s <- read_icd_pixel_series(7L, xy, crs = 2154, result_dir = file.path(tmp, "icd"))
  expect_equal(s$essence, "hetre")
  expect_equal(s$mois_sensibles, 7:8)
  expect_equal(s$seuils[["alerte"]], -2)
  expect_equal(sort(unique(s$serie$annee)), 2019:2023)
  expect_equal(sort(unique(s$serie$indice)), sort(c("GRVI", "CIre", "CRSWIR", "CRre", "NDVI")))
  z23 <- s$serie[s$serie$annee == 2023 & s$serie$mois == 7 & s$serie$indice == "NDVI", ]
  expect_lt(z23$z, -10)
  expect_equal(z23$brut, (0.24 - 0.06) / (0.24 + 0.06), tolerance = 0.02)   # B08 x 0,6 et B04 x 1,5
  expect_lt(s$icd$icd[s$icd$annee == 2023 & s$icd$mois == 7], -3)
  expect_true(all(s$icd$sensible[s$icd$mois %in% 7:8]))
  expect_equal(s$annuel$niveau[s$annuel$annee == 2023], 3)
  expect_true(s$annuel$provisoire[s$annuel$annee == 2023])
  expect_equal(s$annuel$date_alerte[s$annuel$annee == 2023], as.Date("2023-07-01"))
  expect_equal(s$poids[["GRVI"]], 0.30)
  expect_null(read_icd_pixel_series(7L, c(0, 0), crs = 2154, result_dir = file.path(tmp, "icd")))

  # sans bdforet : pas d'ICD, on le dit (statut error, evenement terminal)
  evts2 <- character(0)
  r2 <- run_icd_decoloration(NULL, 7L, cache, file.path(tmp, "icd2"), bdforet = NULL,
                             aoi = zf$zone, ingest = FALSE, today = as.Date("2023-11-15"),
                             progress_callback = function(p) evts2 <<- c(evts2, p$current))
  expect_equal(r2$status, "error"); expect_match(r2$message, "bdforet")
  expect_equal(evts2[length(evts2)], "icd:error")
})

test_that("run_icd_decoloration : poids modifies changent l'ICD, somme != 1 dite", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  tmp <- withr::local_tempdir()
  cache <- file.path(tmp, "cache"); dir.create(cache)
  g <- fabriquer_cache(cache)
  zf <- zone_et_foret(g)
  lancer <- function(poids, dossier) {
    run_icd_decoloration(NULL, 1L, cache, file.path(tmp, dossier), poids = poids,
                         bdforet = zf$bdforet, aoi = zf$zone, ingest = FALSE,
                         write_alerts = FALSE, start_year = 2019L, end_year = 2023L,
                         today = as.Date("2023-11-15"))
  }
  r1 <- lancer(icd_poids_defaut(), "a")
  p <- icd_poids_defaut(); p$GRVI[2] <- 0.9                  # hetre : somme 1,6
  expect_message(r2 <- lancer(p, "b"), "rescaled")
  expect_equal(attr(r2$poids, "renormalise"), "hetre")
  expect_equal(r2$poids$GRVI[2], 0.9 / 1.6)
  ig <- function(r) terra::values(terra::rast(file.path(r$zone_dir, "icd", "2023-07.tif")),
                                  mat = FALSE)[1]
  expect_false(isTRUE(all.equal(ig(r1), ig(r2))))
  meta <- jsonlite::read_json(file.path(r2$zone_dir, "meta.json"), simplifyVector = TRUE)
  expect_equal(meta$renormalise, "hetre")
})

test_that("run_icd_decoloration : annulation cooperative, evenement terminal icd:cancelled", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  tmp <- withr::local_tempdir()
  cache <- file.path(tmp, "cache"); dir.create(cache)
  g <- fabriquer_cache(cache)
  zf <- zone_et_foret(g)
  flag <- file.path(tmp, "stop.flag")
  evts <- character(0)
  res <- run_icd_decoloration(
    NULL, 1L, cache, file.path(tmp, "icd"), bdforet = zf$bdforet, aoi = zf$zone,
    ingest = FALSE, write_alerts = FALSE, start_year = 2019L, end_year = 2023L,
    today = as.Date("2023-11-15"), cancel_path = flag,
    progress_callback = function(p) {
      evts <<- c(evts, p$current)
      if (identical(p$current, "icd:composite") && p$completed >= 8) file.create(flag)
    })
  expect_equal(res$status, "cancelled")
  expect_equal(evts[length(evts)], "icd:cancelled")
  expect_false("icd:complete" %in% evts)
  # ce qui est ecrit reste valide
  fs <- list.files(file.path(res$zone_dir, "composites"), "\\.tif$", full.names = TRUE)
  expect_true(length(fs) > 0)
  expect_true(all(vapply(fs, .icd_composite_lisible, logical(1))))
})

test_that("composites : illisible refait, mois en cours garde, coupes SUFOSAT retirees", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  tmp <- withr::local_tempdir()
  cache <- file.path(tmp, "cache"); dir.create(cache)
  g <- fabriquer_cache(cache)
  zf <- zone_et_foret(g)
  lancer <- function(today, ...) {
    run_icd_decoloration(NULL, 1L, cache, file.path(tmp, "icd"), bdforet = zf$bdforet,
                         aoi = zf$zone, ingest = FALSE, write_alerts = FALSE,
                         start_year = 2019L, end_year = 2023L, today = as.Date(today), ...)
  }
  r <- lancer("2023-08-10")                      # aout 2023 en cours
  j <- file.path(r$zone_dir, "composites", "2023-08.json")
  expect_false(jsonlite::read_json(j)$final)
  lancer("2023-08-12")                           # garder : tel quel
  expect_equal(jsonlite::read_json(j)$ecrit_le, "2023-08-10")
  lancer("2023-08-12", mois_en_cours = "refaire")
  expect_equal(jsonlite::read_json(j)$ecrit_le, "2023-08-12")
  lancer("2023-09-20")                           # termine depuis plus de 5 jours : refait, final
  expect_true(jsonlite::read_json(j)$final)

  # un composite illisible est detecte, supprime et refait
  f <- file.path(r$zone_dir, "composites", "2021-07.tif")
  writeLines("pas un tiff", f)
  expect_false(.icd_composite_lisible(f))
  expect_message(lancer("2023-11-15"), "Unreadable")
  expect_true(.icd_composite_lisible(f))

  # coupe rase SUFOSAT du pixel 1 en juillet 2023 : pas d'ICD ce mois-la
  sd <- terra::setValues(g, NA_real_)
  sd[1] <- .icd_date_vers_yyddd(as.Date("2023-07-10"))
  res <- lancer("2023-11-15", sufosat_dates = sd)
  expect_true(res$coupes_retirees)
  v <- terra::values(terra::rast(file.path(res$zone_dir, "icd", "2023-07.tif")), mat = FALSE)
  expect_true(is.na(v[1])); expect_false(is.na(v[2]))
})

test_that("zone modifiee : les resultats sont recalcules", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  tmp <- withr::local_tempdir()
  cache <- file.path(tmp, "cache"); dir.create(cache)
  g <- fabriquer_cache(cache)
  zf <- zone_et_foret(g)
  lancer <- function(zone) {
    run_icd_decoloration(NULL, 1L, cache, file.path(tmp, "icd"), bdforet = zf$bdforet,
                         aoi = zone, ingest = FALSE, write_alerts = FALSE,
                         start_year = 2019L, end_year = 2023L, today = as.Date("2023-11-15"))
  }
  expect_equal(lancer(zf$zone)$n_pixels_zone, 100L)
  moitie <- sf::st_sf(geometry = sf::st_as_sfc(
    sf::st_bbox(c(xmin = 850000, ymin = 6700000, xmax = 850100, ymax = 6700200),
                crs = sf::st_crs(2154))))
  r <- lancer(moitie)
  expect_lt(r$n_pixels_zone, 100L)
  expect_equal(r$n_pixels_icd, r$n_pixels_zone)
})

test_that("pixels hors des quatre peuplements purs : pas d'ICD, nombre dit", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  tmp <- withr::local_tempdir()
  cache <- file.path(tmp, "cache"); dir.create(cache)
  g <- fabriquer_cache(cache)
  zf <- zone_et_foret(g)
  # hetre seulement sur la moitie ouest ; l'autre partie est un TFV hors liste
  ouest <- sf::st_sf(code_tfv = c("FF1-09-09", "FF1-00-00"), geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(849900, 6699900), c(850100, 6699900), c(850100, 6700300),
                              c(849900, 6700300), c(849900, 6699900)))),
    sf::st_polygon(list(rbind(c(850100, 6699900), c(850300, 6699900), c(850300, 6700300),
                              c(850100, 6700300), c(850100, 6699900)))), crs = 2154))
  r <- run_icd_decoloration(NULL, 1L, cache, file.path(tmp, "icd"), bdforet = ouest,
                            aoi = zf$zone, ingest = FALSE, write_alerts = FALSE,
                            start_year = 2019L, end_year = 2023L, today = as.Date("2023-11-15"))
  expect_gt(r$n_pixels_sans_icd, 0L)
  expect_equal(r$n_pixels_icd + r$n_pixels_sans_icd, r$n_pixels_zone)
  expect_equal(r$par_essence[["hetre"]], r$n_pixels_icd)
  niv <- read_icd_raster(1L, 2023L, file.path(tmp, "icd"))
  expect_true(any(is.na(terra::values(niv, mat = FALSE))))
  # le pixel de l'est : serie sans essence, motif dit
  xy <- terra::xyFromCell(g, terra::ncell(g))
  s <- read_icd_pixel_series(1L, xy, crs = 2154, result_dir = file.path(tmp, "icd"))
  expect_true(is.na(s$essence)); expect_match(s$motif, "peuplements purs")
  expect_true(all(is.na(s$icd$icd)))
})

test_that("comparer_fast_icd : croisement, accord, kappa, surface alertee egale", {
  skip_if_not_installed("terra")
  tmp <- withr::local_tempdir()
  g <- terra::rast(xmin = 0, xmax = 200, ymin = 0, ymax = 200, resolution = 20, crs = "EPSG:2154")
  zdir <- file.path(tmp, "zone_3"); dir.create(file.path(zdir, "annuel"), recursive = TRUE)
  niveau <- rep(0, 100); niveau[1:10] <- 2; niveau[11:15] <- 3; niveau[16:20] <- 1
  r <- terra::rast(g, nlyrs = 5)
  terra::values(r) <- cbind(ifelse(niveau >= 2, 2, niveau), niveau, NA, NA, 1)
  names(r) <- c("classe", "niveau", "icd_min", "mois_alerte", "n_mois_valides")
  terra::writeRaster(r, file.path(zdir, "annuel", "2023.tif"))
  .icd_ecrire_meta(zdir, list(annee_provisoire = 2023L, n_pixels_zone = 100L))

  # FAST d'accord avec l'ICD : score eleve la ou le niveau est >= 2
  sc <- rep(0, 100); sc[1:15] <- seq(15, 1)
  fast <- terra::setValues(g, sc)
  cmp <- comparer_fast_icd(3L, 2023L, tmp, fast = fast)
  expect_equal(cmp$statut, "ok"); expect_equal(cmp$n_pixels, 100L)
  expect_equal(sum(cmp$croisement$n_pixels), 100)
  expect_equal(sum(cmp$croisement$surface_ha), 100 * 0.04)
  expect_equal(nrow(cmp$croisement), 25L)
  # surface alertee egale : 15 pixels (niveau >= 2) alertes de part et d'autre
  se <- cmp$surface_egale
  expect_equal(se$n_alertes, 15L); expect_equal(se$part_alertee, 0.15)
  expect_equal(se$les_deux, 15 * 0.04); expect_equal(se$fast_seul, 0)
  expect_equal(se$accord, 1); expect_equal(se$kappa, 1)

  # FAST en desaccord : les alertes FAST sont ailleurs
  sc2 <- rep(0, 100); sc2[51:65] <- seq(15, 1)
  cmp2 <- comparer_fast_icd(3L, 2023L, tmp, fast = terra::setValues(g, sc2))
  expect_equal(cmp2$surface_egale$les_deux, 0)
  expect_equal(cmp2$surface_egale$fast_seul, 15 * 0.04)
  expect_equal(cmp2$surface_egale$icd_seul, 15 * 0.04)
  expect_lt(cmp2$surface_egale$kappa, 0)
  expect_lt(cmp2$kappa, cmp$kappa)

  # FAST a 10 m : ramene sur la grille 20 m (moyenne)
  g10 <- terra::rast(xmin = 0, xmax = 200, ymin = 0, ymax = 200, resolution = 10, crs = "EPSG:2154")
  cmp3 <- comparer_fast_icd(3L, 2023L, tmp, fast = terra::resample(fast, g10, "near"))
  expect_equal(cmp3$n_pixels, 100L)

  # absences dites
  expect_equal(comparer_fast_icd(3L, 2023L, tmp)$statut, "fast_absent")
  expect_equal(comparer_fast_icd(3L, 2010L, tmp, fast = fast)$statut, "icd_absent")
  expect_equal(comparer_fast_icd(3L, 2023L, tmp,
                                 fast = terra::setValues(g, NA_real_))$statut, "sans_pixel_commun")
})

test_that("ingest_s2_raw_bands_to_cache : SCL accepte, annulation sondee par scene (s2:cancelled)", {
  tmp <- withr::local_tempdir()
  zone <- sf::st_sf(geometry = sf::st_as_sfc(sf::st_bbox(
    c(xmin = 900000, ymin = 6600000, xmax = 900200, ymax = 6600200), crs = sf::st_crs(2154))))
  scenes <- data.frame(
    scene_id = sprintf("S2A_MSIL2A_2023070%dT103031_N0214_R108_T31TFM_2023070%dT133000", 1:4, 1:4),
    obs_date = as.Date("2023-07-01") + 0:3, cloud_pct = 10, source = "pc",
    stringsAsFactors = FALSE)
  appels <- character(0)
  testthat::local_mocked_bindings(
    .assert_db_pkgs = function() invisible(NULL),
    .get_zone_aoi = function(con, zone_id) zone,
    stac_search_s2 = function(...) scenes,
    .scene_cogs_cached = function(...) FALSE,
    .get_s2_band_raster = function(sc, b, ...) { appels <<- c(appels, paste(sc$scene_id, b)); TRUE })
  flag <- file.path(tmp, "stop")
  evts <- character(0)
  res <- ingest_s2_raw_bands_to_cache(
    NULL, 1L, bands = c("B04", "SCL"), start = "2023-07-01", end = "2023-07-31",
    cache_dir = tmp, cancel_path = flag,
    progress_callback = function(p) {
      evts <<- c(evts, p$current)
      if (identical(p$current, "s2:scene") && p$completed == 1) file.create(flag)
    })
  expect_true(res$cancelled)
  expect_equal(evts[length(evts)], "s2:cancelled")
  expect_false("s2:complete" %in% evts)
  expect_true(any(grepl("SCL$", appels)))
  expect_length(unique(sub(" .*", "", appels)), 2L)     # 2 scenes lues sur 4
  # sans cancel_path : comportement inchange, evenement s2:complete
  evts2 <- character(0)
  r2 <- ingest_s2_raw_bands_to_cache(NULL, 1L, bands = "SCL", start = "2023-07-01",
                                     end = "2023-07-31", cache_dir = tmp,
                                     progress_callback = function(p) evts2 <<- c(evts2, p$current))
  expect_false(r2$cancelled); expect_equal(evts2[length(evts2)], "s2:complete")
  expect_error(ingest_s2_raw_bands_to_cache(NULL, 1L, bands = "NDVI", start = "2023-07-01",
                                            end = "2023-07-31", cache_dir = tmp), "raw Sentinel-2")
})

# --- Verrous demandes a la relecture ------------------------------------------

# Une scene de 12 pixels dont la SCL porte les classes `scl`, reflectances
# constantes = bandes_ref() (DN = reflectance * 10000 + offset).
scene_scl <- function(racine, sid, scl, offset = 0) {
  g <- terra::rast(xmin = 0, xmax = 80, ymin = 0, ymax = 60, resolution = 20, crs = "EPSG:2154")
  d <- file.path(racine, sid); dir.create(d, recursive = TRUE)
  for (b in names(bandes_ref())) {
    terra::writeRaster(terra::setValues(g, bandes_ref()[[b]] * 10000 + offset),
                       file.path(d, paste0(b, ".tif")), overwrite = TRUE, datatype = "FLT4S")
  }
  terra::writeRaster(terra::setValues(g, scl), file.path(d, "SCL.tif"),
                     overwrite = TRUE, datatype = "INT1U")
  g
}

test_that("masque SCL : classes 0, 1, 3, 8, 9, 10, 11 masquent, les autres non", {
  tmp <- withr::local_tempdir()
  expect_equal(.ICD_SCL_MASQUE, c(0L, 1L, 3L, 8L, 9L, 10L, 11L))
  scl <- c(0, 1, 3, 8, 9, 10, 11, 4, 5, 6, 7, 2)
  sid <- "S2A_MSIL2A_20230715T103031_N0214_R108_T31TFM_20230715T133000"
  g <- scene_scl(tmp, sid, scl)
  r <- .icd_indices_scene(file.path(tmp, sid), sid, g)
  v <- terra::values(r[["NDVI"]], mat = FALSE)
  expect_true(all(is.na(v[1:7])))
  expect_false(anyNA(v[8:12]))              # classe 4 (vegetation) et 2, 5, 6, 7 : gardees
  expect_true(all(terra::values(r, mat = TRUE)[1:7, ] |> is.na()))
})

test_that("offset BOA : une scene posterieure au 25 janvier 2022 est corrigee", {
  tmp <- withr::local_tempdir()
  attendu <- icd_indices(bandes_ref())
  apres <- "S2B_MSIL2A_20230715T103031_N0509_R108_T31TFM_20230715T133000"   # N0500 ou plus
  avant <- "S2A_MSIL2A_20210715T103031_N0214_R108_T31TFM_20210715T133000"
  g <- scene_scl(tmp, apres, rep(4, 12), offset = 1000)
  scene_scl(tmp, avant, rep(4, 12), offset = 0)
  expect_equal(.s2_boa_offset(apres), -1000); expect_equal(.s2_boa_offset(avant), 0)
  ra <- .icd_indices_scene(file.path(tmp, apres), apres, g)
  rb <- .icd_indices_scene(file.path(tmp, avant), avant, g)
  expect_equal(unname(unlist(terra::values(ra, mat = TRUE)[1, ])), unname(unlist(attendu)), tolerance = 1e-5)
  expect_equal(unname(unlist(terra::values(rb, mat = TRUE)[1, ])), unname(unlist(attendu)), tolerance = 1e-5)
})

test_that("planchers de l'ecart-type robuste : valeurs de la note, et effet de bout en bout", {
  expect_equal(.ICD_PLANCHERS, c(GRVI = 0.01, CIre = 0.05, CRSWIR = 0.02, CRre = 0.01, NDVI = 0.01))
  tmp <- withr::local_tempdir()
  cache <- file.path(tmp, "cache"); dir.create(cache)
  # annees identiques (MAD nul), seule B07 baisse de 10 % en 2023 : seul CIre bouge
  g <- fabriquer_cache(cache, bruit = 0, facteurs = c(B07 = 0.9))
  zf <- zone_et_foret(g)
  r <- run_icd_decoloration(NULL, 1L, cache, file.path(tmp, "icd"), bdforet = zf$bdforet,
                            aoi = zf$zone, ingest = FALSE, write_alerts = FALSE,
                            start_year = 2019L, end_year = 2023L, today = as.Date("2023-11-15"))
  z <- terra::values(terra::rast(file.path(r$zone_dir, "z", "2023-07.tif")), mat = TRUE)
  d_cire <- 3000 * 0.9 / 800 - 3000 / 800                 # variation de CIre (B05 = 800)
  expect_equal(unname(z[1, "CIre"]), d_cire / 0.05, tolerance = 1e-4)   # plancher 0,05, pas 0,01
  expect_equal(unname(z[3, "CIre"]), 0)
})

test_that("persistance : la suite de k mois consecutifs vient de la constante", {
  mois <- 4:9
  M <- rbind(c(-2.5, -2.5, 0, 0, 0, 0),          # 2 mois seulement
             c(0, -2.5, -2.5, -2.5, 0, 0),       # 3 mois a partir de mai
             c(-2.5, -2.5, -2.5, 0, 0, 0))       # 3 mois a partir d'avril
  a2 <- .icd_classe_annuelle(M, mois, persistance = 2L)
  expect_equal(a2$classe, c(2, 2, 2)); expect_equal(a2$mois_alerte, c(4L, 5L, 4L))
  a3 <- .icd_classe_annuelle(M, mois, persistance = 3L)
  expect_equal(a3$classe, c(1, 2, 2)); expect_equal(a3$mois_alerte, c(NA, 5L, 4L))
  expect_equal(.icd_classe_annuelle(M, mois)$classe, a2$classe)     # defaut = .ICD_PERSISTANCE (2)
  expect_equal(.ICD_PERSISTANCE, 2L)
  a7 <- .icd_classe_annuelle(M, mois, persistance = 7L)            # plus que de mois : jamais d'alerte
  expect_equal(a7$classe, c(1, 1, 1))
})

test_that("ingestion : avril a octobre seulement, pas le mois en cours non termine depuis 5 jours", {
  f <- .icd_fenetres_ingestion(2022:2023, as.Date("2023-07-10"), "garder")
  # 2022 : avril a octobre ; 2023 : juin est termine depuis plus de 5 jours, pas juillet
  expect_equal(f$start, c("2022-04-01", "2023-04-01"))
  expect_equal(f$end, c("2022-10-31", "2023-06-30"))
  # juin termine depuis moins de 5 jours : encore en cours
  expect_equal(.icd_fenetres_ingestion(2023L, as.Date("2023-07-03"), "garder")$end, "2023-05-31")
  expect_equal(.icd_fenetres_ingestion(2023L, as.Date("2023-07-10"), "refaire")$end, "2023-07-10")
  expect_equal(nrow(.icd_fenetres_ingestion(2023L, as.Date("2023-04-03"), "garder")), 0L)
  expect_equal(.icd_fenetres_ingestion(2023L, as.Date("2023-12-01"), "garder")$end, "2023-10-31")

  # dates reellement passees a ingest_s2_raw_bands_to_cache
  tmp <- withr::local_tempdir()
  cache <- file.path(tmp, "cache"); dir.create(cache)
  g <- fabriquer_cache(cache); zf <- zone_et_foret(g)
  appels <- list()
  testthat::local_mocked_bindings(
    ingest_s2_raw_bands_to_cache = function(con, zone_id, bands, start, end, ...) {
      appels[[length(appels) + 1L]] <<- c(start = start, end = end, bands = paste(bands, collapse = ","))
      list(cancelled = FALSE)
    })
  run_icd_decoloration(structure(list(), class = "fausse_con"), 1L, cache, file.path(tmp, "icd"),
                       bdforet = zf$bdforet, aoi = zf$zone, ingest = TRUE, write_alerts = FALSE,
                       start_year = 2022L, end_year = 2023L, today = as.Date("2023-07-10"))
  expect_equal(vapply(appels, `[[`, "", "start"), c("2022-04-01", "2023-04-01"))
  expect_equal(vapply(appels, `[[`, "", "end"), c("2022-10-31", "2023-06-30"))
  expect_match(appels[[1]][["bands"]], "SCL")
})
