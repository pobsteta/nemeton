# Numéros de tarif Schaeffer par essence × SER (spec 062).

# Arbre synthétique : volume exact d'un numéro donné, C13 en mètres.
arbre_tarif <- function(numero, d_cm, type, espar = "09", idp = "1", veget = "0") {
  data.frame(ESPAR = espar, C13 = d_cm * pi / 100,
             V = volume_tarif_schaeffer(numero, d_cm, type), VEGET = veget, IDP = idp,
             stringsAsFactors = FALSE)
}

test_that("les formules redonnent le numéro d'un volume connu, pour les 4 types", {
  for (t in c("SCHR", "SCHI", "SCHL", "SCHTL")) {
    for (n in c(4, 8.5, 13)) {
      v <- volume_tarif_schaeffer(n, c(20, 35, 60), t)
      expect_equal(numero_tarif_schaeffer(v, c(20, 35, 60), t), rep(n, 3))
    }
  }
  # Constantes de PPtools::TarifFindSch().
  expect_equal(numero_tarif_schaeffer(1, 40, "SCHR"), 1 / 5 * 70000 / (35 * 30) - 8)
  expect_equal(numero_tarif_schaeffer(1, 40, "SCHTL"), 1 / 5 * 101250 / 1600 - 8)
  expect_error(numero_tarif_schaeffer(1, 40, "SCHX"), "Unknown")
})

test_that("aller-retour avec les formules de volume de Marculus", {
  # Cubage.volume() : M = 0,8 + 0,1 N ; rapide M/1400 (D-5)(D-10), lent M/1800 D (D-5).
  for (n in 1:15) {
    m <- 0.8 + 0.1 * n
    d <- 45
    expect_equal(volume_tarif_schaeffer(n, d, "SCHR"), m / 1400 * (d - 5) * (d - 10))
    expect_equal(volume_tarif_schaeffer(n, d, "SCHL"), m / 1800 * d * (d - 5))
  }
})

test_that("C13 est lu en mètres, les bornes de diamètre et l'état VEGET s'appliquent", {
  a <- rbind(arbre_tarif(10, 30, "SCHL"), arbre_tarif(10, 40, "SCHL"),
             arbre_tarif(10, 50, "SCHL"))
  r <- calculer_tarifs_schaeffer(a)
  expect_equal(r$numero[r$type == "SCHL"], 10)
  expect_equal(r$n_arbres[1], 3L)
  # C13 en cm par erreur : D de 940 cm, hors bornes -> aucun arbre.
  b <- a
  b$C13 <- b$C13 * 100
  expect_equal(nrow(calculer_tarifs_schaeffer(b)), 0L)
  # Bornes 17,5-80 cm (17 et 81 cm écartés), arbre mort écarté.
  c2 <- rbind(a, arbre_tarif(30, 17, "SCHL"), arbre_tarif(30, 81, "SCHL"),
              arbre_tarif(30, 40, "SCHL", veget = "5"))
  expect_equal(calculer_tarifs_schaeffer(c2)$n_arbres[1], 3L)
  # Une essence n'est retenue qu'au-delà de 2 arbres.
  expect_equal(nrow(calculer_tarifs_schaeffer(a[1:2, ])), 0L)
})

test_that("moyenne pondérée par le volume et CV à poids de fiabilité", {
  a <- rbind(arbre_tarif(6, 25, "SCHL", idp = "1"), arbre_tarif(12, 60, "SCHL", idp = "2"),
             arbre_tarif(9, 40, "SCHL", idp = "2"))
  r <- calculer_tarifs_schaeffer(a)
  r <- r[r$type == "SCHL", ]
  w <- a$V
  x <- c(6, 12, 9)
  m <- sum(w * x) / sum(w)
  v <- sum(w * (x - m)^2) / (sum(w) - sum(w^2) / sum(w))
  expect_equal(r$numero, round(m, 1))
  expect_equal(r$cv, round(100 * sqrt(v) / m, 1))
  expect_equal(r$n_placettes, 2L)
  # Le gros arbre tire la moyenne : pondération par le volume, pas par l'effectif.
  expect_gt(r$numero, mean(x))
  # Groupe de moins d'1 m3 : variance définie et positive (Hmisc::wtd.var ne l'est pas).
  petits <- rbind(arbre_tarif(6, 18, "SCHL"), arbre_tarif(8, 19, "SCHL"), arbre_tarif(7, 20, "SCHL"))
  expect_lt(sum(petits$V), 1)
  expect_true(all(calculer_tarifs_schaeffer(petits)$cv > 0))
})

test_that("CV positif pour une essence à numéro négatif", {
  a <- rbind(arbre_tarif(-1, 30, "SCHTL"), arbre_tarif(-2, 40, "SCHTL"), arbre_tarif(0.5, 35, "SCHTL"))
  r <- calculer_tarifs_schaeffer(a)
  expect_lt(r$numero[r$type == "SCHTL"], 0)
  expect_true(all(r$cv >= 0))
})

test_that("regroupement par SER", {
  a <- rbind(arbre_tarif(8, 30, "SCHR"), arbre_tarif(8, 40, "SCHR"), arbre_tarif(8, 50, "SCHR"),
             arbre_tarif(12, 30, "SCHR"), arbre_tarif(12, 40, "SCHR"), arbre_tarif(12, 50, "SCHR"))
  a$SER <- rep(c("C20", "C30"), each = 3)
  r <- calculer_tarifs_schaeffer(a, groupes = "SER")
  expect_equal(r$numero[r$type == "SCHR"], c(8, 12))
  expect_equal(r$SER[r$type == "SCHR"], c("C20", "C30"))
})

test_that("la table embarquée a le format Marculus et les essences attendues", {
  f <- system.file("extdata", "ifn_tarif_schaeffer_ser.csv", package = "nemeton")
  expect_identical(readLines(f, n = 1),
                   "niveau;code;espar;essence_libelle;type;numero;n_arbres;cv;millesime")
  expect_false(identical(readBin(f, "raw", 3), as.raw(c(0xef, 0xbb, 0xbf))))
  d <- ifn_tarif_schaeffer_ser()
  expect_setequal(unique(d$niveau), c("SER", "GRECO", "FRANCE"))
  expect_setequal(unique(d$type), c("SCHR", "SCHI", "SCHL", "SCHTL"))
  expect_true(all(d$code[d$niveau == "FRANCE"] == "FR"))
  expect_true(all(d$n_arbres >= 3))
  expect_true(all(d$cv >= 0, na.rm = TRUE))
  # Codes à deux chiffres complétés : chênes et hêtre présents.
  expect_true(all(c("02", "03", "09") %in% d$espar))
  # SER C30 : chêne sessile et hêtre au niveau SER.
  r <- ifn_tarif_schaeffer_reference(c("03", "09"), ser = "C30", type = "SCHL")
  expect_equal(r$niveau_utilise, c("SER", "SER"))
  expect_true(all(r$type_conseille %in% c("SCHR", "SCHI", "SCHL", "SCHTL")))
})

test_that("cascade SER -> GRECO -> France, NA sinon", {
  tab <- data.frame(
    niveau = c("SER", "GRECO", "FRANCE", "SER", "FRANCE"),
    code = c("C20", "C", "FR", "C20", "FR"),
    espar = c("09", "09", "09", "64", "64"),
    essence_libelle = c("Hêtre", "Hêtre", "Hêtre", "Douglas", "Douglas"),
    type = "SCHL", numero = c(8.4, 8.1, 7.9, 12, 11),
    n_arbres = c(500L, 900L, 9000L, 10L, 50L), cv = 30, millesime = "2011-2025",
    stringsAsFactors = FALSE)
  local_mocked_bindings(.tarif_table = function() tab)
  r <- ifn_tarif_schaeffer_reference(c("Hêtre", "64", "03"), ser = "C20", type = "SCHL")
  expect_equal(r$niveau_utilise, c("SER", "FRANCE", NA))
  expect_equal(r$numero, c(8.4, 11, NA))
  r <- ifn_tarif_schaeffer_reference("09", ser = "C20", type = "SCHL", min_arbres = 600)
  expect_equal(r$niveau_utilise, "GRECO")
  expect_equal(r$code, "C")
  r <- ifn_tarif_schaeffer_reference("09", ser = NULL)
  expect_equal(r$niveau_utilise, "FRANCE")
})

# IFN synthétique : `n_riche` placettes autour du point (925000, 6700000),
# 6 hêtres de numéro SchL 11 chacune ; une placette lointaine.
ifn_synthetique <- function(n_riche) {
  pl <- data.frame(IDP = as.character(seq_len(n_riche + 1)), CAMPAGNE = "2024",
                   SER = "C20",
                   XL = c(925000 + 100 * seq_len(n_riche), 1000000),
                   YL = c(rep(6700000, n_riche), 6800000), stringsAsFactors = FALSE)
  ar <- do.call(rbind, lapply(pl$IDP, function(i) {
    a <- do.call(rbind, lapply(c(25, 30, 35, 40, 45, 50), function(d) arbre_tarif(11, d, "SCHL", idp = i)))
    a$CAMPAGNE <- "2024"
    a
  }))
  list(ARBRE = ar, PLACETTE = pl)
}

test_that("tarif_schaeffer_local : forêt riche au niveau forêt, forêt pauvre en repli SER", {
  foret <- sf::st_sf(geometry = sf::st_sfc(sf::st_buffer(sf::st_point(c(925000, 6700000)), 300),
                                           crs = 2154))
  r <- tarif_schaeffer_local(foret, especes = "Hêtre", ifn = ifn_synthetique(6), ser = "C20")
  r <- r[r$type == "SCHL", ]
  expect_equal(r$niveau_utilise, "foret")
  expect_equal(r$numero, 11)
  expect_equal(r$n_arbres, 36L)
  expect_equal(r$n_placettes, 6L)
  expect_gte(attr(tarif_schaeffer_local(foret, especes = "09", ifn = ifn_synthetique(6), ser = "C20"),
                  "tampon_m"), 450)
  # 2 placettes : 12 arbres < 30 -> table de référence de la SER.
  r <- tarif_schaeffer_local(foret, especes = "09", ifn = ifn_synthetique(2), ser = "C20")
  expect_equal(unique(r$niveau_utilise), "SER")
  expect_equal(unique(r$code), "C20")
})

test_that("communes_ser : parts sommant à 1, commune à cheval sur deux SER", {
  d <- communes_ser()
  expect_identical(names(d), c("insee", "nom", "departement", "ser", "part", "greco"))
  s <- tapply(d$part, d$insee, sum)
  expect_true(all(abs(s - 1) < 1e-3))
  expect_true(all(d$part >= 0.0099))
  expect_true(all(d$greco == substr(d$ser, 1, 1)))
  g <- communes_ser("21295")   # Gevrey-Chambertin
  expect_setequal(g$ser, c("C20", "C51"))
  expect_equal(sum(g$part), 1, tolerance = 1e-3)
  ser <- read.table(system.file("extdata", "ser.csv", package = "nemeton"), header = TRUE,
                    sep = ";", colClasses = "character", encoding = "UTF-8", quote = "\"")
  expect_identical(names(ser), c("code", "nom", "greco"))
  expect_equal(nrow(ser), 86L)
  expect_true(all(d$ser %in% ser$code))
})

test_that("exporter_tarifs_marculus écrit les fichiers attendus, moins de 3 Mo", {
  withr::with_tempdir({
    f <- exporter_tarifs_marculus("tarifs")
    expect_setequal(basename(f), c("ifn_tarif_schaeffer_ser.csv", "communes_ser.csv",
                                   "ser.csv", "LISEZMOI.txt"))
    expect_true(all(file.exists(f)))
    expect_lt(sum(file.size(f)), 3e6)
    expect_identical(readLines(file.path("tarifs", "communes_ser.csv"), n = 1),
                     "insee;nom;departement;ser;part;greco")
    expect_identical(readLines(file.path("tarifs", "ser.csv"), n = 1), "code;nom;greco")
    lis <- readLines(file.path("tarifs", "LISEZMOI.txt"), encoding = "UTF-8")
    expect_true(any(grepl("Etalab", lis)))
    expect_true(any(grepl("Bruciamacchie", lis)))
    expect_true(any(grepl("Millesime IFN : [0-9]{4}-[0-9]{4}", lis)))
    for (fi in f[grepl("csv$", f)]) {
      expect_false(any(grepl("(^|;)NA(;|$)", readLines(fi, encoding = "UTF-8"))))
    }
  })
})
