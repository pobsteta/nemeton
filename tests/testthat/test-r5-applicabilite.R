# r5_applicabilite() : dire AVANT calcul si R5 s'applique, et sinon pourquoi.
#
# Contexte : le 2026-08-17, la question « peut-on savoir depuis les parcelles
# cadastrales si R5 est calculable ? » a montré que `check_fordead_validity()`
# répondait mal sur un cas : le projet Reconfort (chêne) en sortait « non
# calculable », alors que RECONFORT est précisément la méthode faite pour lui.
# Le contrôle historique ne connaît que la route FORDEAD ; il confondait donc
# « mauvaise espèce pour FORDEAD » et « aucune méthode applicable ».
#
# Deuxième confusion à défaire : hors des cinq départements de calibration
# (ONF/DSF 2024), un sapin pectiné reste un sapin pectiné. « Hors calibration »
# et « mauvaise espèce » sont deux verdicts distincts.

skip_if_not_installed("sf")

# Unités dans les Vosges (88, DANS la zone) ou en Ardennes (08, hors zone).
.r5_units <- function(species, dans_zone = TRUE, n = length(species)) {
  x0 <- if (dans_zone) 950000 else 800000     # Vosges vs Ardennes, Lambert-93
  y0 <- if (dans_zone) 6800000 else 6950000
  geom <- sf::st_sfc(lapply(seq_len(n), function(i) {
    sf::st_polygon(list(matrix(c(
      x0 + i * 600, y0, x0 + i * 600 + 500, y0,
      x0 + i * 600 + 500, y0 + 500, x0 + i * 600, y0 + 500,
      x0 + i * 600, y0), ncol = 2, byrow = TRUE)))
  }), crs = 2154)
  sf::st_sf(id = seq_len(n), species = species, geometry = geom)
}

test_that("silver fir inside the calibration zone routes to FORDEAD", {
  u <- .r5_units(rep("Abies alba", 3), dans_zone = TRUE)
  a <- r5_applicabilite(u)

  expect_identical(a$status, "eligible_fordead")
  expect_identical(a$method, "fordead")
  expect_true(a$in_calibration)
  expect_equal(a$n_fordead, 3L)
  expect_true("88" %in% a$dept_codes)
})

test_that("out of calibration is NOT the same verdict as wrong species", {
  # Même essence, autre département : la donnée reste exploitable, seule la
  # confiance des classes l'est moins. C'est la nuance que le projet Fordead
  # (sapin en Ardennes) rendait visible.
  u <- .r5_units(rep("Abies alba", 3), dans_zone = FALSE)
  a <- r5_applicabilite(u)

  expect_identical(a$status, "eligible_fordead_out_of_calibration")
  expect_identical(a$method, "fordead")          # la méthode reste FORDEAD
  expect_false(a$in_calibration)
  expect_equal(a$n_fordead, 3L)                  # les unités restent éligibles
  expect_equal(a$geo_pct, 0)
})

test_that("oak routes to RECONFORT, which has no published validity zone", {
  u <- .r5_units(rep("Quercus petraea", 4), dans_zone = FALSE)
  a <- r5_applicabilite(u)

  expect_identical(a$status, "eligible_reconfort")
  expect_identical(a$method, "reconfort")
  # NA et non FALSE : aucune zone n'est publiée pour RECONFORT, donc rien n'a
  # été constaté. FALSE laisserait croire à un hors-zone mesuré.
  expect_true(is.na(a$in_calibration))
  expect_equal(a$n_reconfort, 4L)
})

test_that("a species neither conifer nor RECONFORT is not applicable", {
  u <- .r5_units(rep("Fagus sylvatica", 3), dans_zone = TRUE)
  a <- r5_applicabilite(u)

  expect_identical(a$status, "not_applicable")
  expect_true(is.na(a$method))
  expect_equal(a$n_fordead, 0L)
  expect_equal(a$n_reconfort, 0L)
  # Le hêtre est bien reconnu comme essence : ce n'est pas un « no_species ».
  expect_equal(nrow(a$per_unit), 3L)
})

test_that("no species column and no BD Foret gives no_species, not a wrong verdict", {
  u <- .r5_units(rep("Abies alba", 2), dans_zone = TRUE)
  u$species <- NULL

  a <- suppressWarnings(r5_applicabilite(u))
  expect_identical(a$status, "no_species")
  expect_true(is.na(a$method))
  # La part géographique reste renseignée : elle ne dépend pas de l'essence.
  expect_true(a$in_calibration)
})

test_that("routing is per unit, a mixed massif is not an all-or-nothing verdict", {
  u <- .r5_units(c("Abies alba", "Abies alba", "Quercus petraea", "Fagus sylvatica"),
                 dans_zone = TRUE)
  a <- r5_applicabilite(u)

  expect_equal(a$n_fordead, 2L)
  expect_equal(a$n_reconfort, 1L)
  expect_identical(a$per_unit$method, c("fordead", "fordead", "reconfort", NA))
  # La méthode dominante décide du statut rendu, le détail reste consultable.
  expect_identical(a$method, "fordead")
})

test_that("explicit share columns bypass species derivation", {
  u <- .r5_units(rep("Fagus sylvatica", 3), dans_zone = TRUE)
  u$part_resineux <- c(0.8, 0.9, 0.1)

  a <- r5_applicabilite(u, resineux_col = "part_resineux")
  expect_identical(a$method, "fordead")
  expect_equal(a$n_fordead, 2L)         # 0.1 est sous le seuil de 0.3
  expect_equal(a$n_reconfort, 0L)
})

test_that("empty units are reported, not crashed on", {
  u <- .r5_units(character(0), n = 0)
  a <- r5_applicabilite(u)
  expect_identical(a$status, "not_applicable")
  expect_equal(a$n_units, 0L)
})

test_that("the status vocabulary is stable", {
  # Contrat avec l'aval (clés i18n côté app) : verrouillé ici.
  statuses <- c("eligible_fordead", "eligible_fordead_out_of_calibration",
                "eligible_reconfort", "no_species", "not_applicable")
  a <- r5_applicabilite(.r5_units(rep("Abies alba", 2), dans_zone = TRUE))
  expect_true(a$status %in% statuses)
  expect_named(a, c("status", "method", "in_calibration", "geo_pct",
                    "dept_codes", "resineux_pct", "feuillus_pct",
                    "n_units", "n_fordead", "n_reconfort", "per_unit"))
})
