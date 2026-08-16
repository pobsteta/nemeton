# Ce que `create_family_index()` agrège réellement (brief normalisation, 2026-08-16).
#
# Un score `famille_carbone = 0,90 / 100` sur le projet Fordead a fait
# soupçonner que la normalisation n'était pas appliquée. Vérification faite,
# elle l'est — et depuis la v0.10.0 (2026-02-04) : `create_family_index()`
# appelle `normalize_indicator()` sur chaque colonne avant d'agréger. Le 0,90
# est l'agrégation CORRECTE d'entrées réellement quasi nulles (C1 à 0,06 tC/ha,
# C2 négatif car dérivé d'une ortho WMS).
#
# Ces tests verrouillent la propriété qui manquait de preuve, avec les valeurs
# réelles du projet : ce sont elles qui distinguent « normalisé » de « brut ».

skip_if_not_installed("sf")

# Valeurs médianes observées sur les 30 UGF de Fordead (indicators.parquet).
.fordead_medians <- c(
  indicateur_c1_biomasse   = 0.062,      # tC/ha       -> ref_max 150
  indicateur_c2_ndvi       = -0.109,     # NDVI [-1,1] -> clamp 0
  indicateur_s3_population = 9094.5,     # habitants   -> ref_max 10000
  indicateur_p1_volume     = 0,          # m3/ha       -> ref_max 800
  indicateur_p2_station    = 10.9        # m3/ha/an    -> ref_max 15
)

.units_from <- function(values, n = 3) {
  geom <- sf::st_sfc(lapply(seq_len(n), function(i) {
    sf::st_polygon(list(matrix(
      c(i, 0, i + 0.5, 0, i + 0.5, 0.5, i, 0.5, i, 0), ncol = 2, byrow = TRUE)))
  }), crs = 2154)
  df <- as.data.frame(lapply(values, rep, times = n))
  sf::st_sf(df, geometry = geom)
}

test_that("family scores aggregate NORMALIZED values, not raw units", {
  units <- .units_from(.fordead_medians)
  out <- suppressWarnings(create_family_index(units, method = "mean"))

  # S : 9 094 habitants. Brut, la moyenne de famille exploserait ; normalisé,
  # 9094.5 / 10000 * 100 = 90,9. C'est le test décisif — aucune autre hypothèse
  # ne produit un score dans [0, 100] ici.
  expect_equal(out$famille_social[1], 90.945, tolerance = 1e-3)
  expect_lte(out$famille_social[1], 100)

  # C : 0,062 tC/ha -> 0,041 ; NDVI négatif -> 0. Le score très bas est correct,
  # ce sont les ENTRÉES qui sont quasi nulles (cf. C1 canopée, C2 source S2).
  expect_equal(out$famille_carbone[1], mean(c(0.041333, 0)), tolerance = 1e-3)

  # P : (0/800 + 10.9/15) * 100 / 2 = 36,3.
  expect_equal(out$famille_production[1], mean(c(0, 72.667)), tolerance = 1e-3)
})

test_that("a pre-normalized _norm column is used and not normalized twice", {
  # La préférence `_norm` existait mais ne s'appliquait jamais aux noms longs :
  # aucune stratégie de sélection ne retenait ces colonnes.
  units <- .units_from(c(
    indicateur_c1_biomasse = 0.062,
    indicateur_c2_ndvi     = -0.109
  ))
  units$indicateur_c1_biomasse_norm <- rep(80, nrow(units))
  units$indicateur_c2_ndvi_norm     <- rep(60, nrow(units))

  out <- suppressWarnings(create_family_index(units, method = "mean"))
  # 80 et 60 sont repris tels quels : une seconde normalisation les écraserait
  # (80 tC/ha -> 53, par exemple).
  expect_equal(out$famille_carbone[1], 70)
})

test_that("an out-of-range column with no rule warns instead of being clamped in silence", {
  units <- .units_from(c(indicateur_c1_biomasse = 0.062))
  # Colonne rattachée à la famille C par le motif court, sans règle de
  # normalisation ni déclaration « native 0-100 » : le repli l'écrête à 100.
  units$C9 <- c(1e4, 2e4, 3e4)

  expect_warning(
    create_family_index(units, method = "mean"),
    # cli replie le message sur plusieurs lignes : matcher un fragment court.
    "outside \\[0, 100\\]"
  )
  # Le message nomme la colonne ET la famille : `normalize_indicator()` ne
  # connaît pas la famille, et ne prévient que pour les colonnes déclarées.
  expect_warning(create_family_index(units, method = "mean"), "C9")
})

test_that("a native 0-100 indicator does not trigger the warning", {
  units <- .units_from(c(
    indicateur_r1_feu      = 72,
    indicateur_r2_tempete  = 55
  ))
  expect_no_warning(create_family_index(units, method = "mean"))
})

test_that("short codes normalize like their long-form name", {
  # `create_family_index()` accepte les deux écritures — le motif `^C[0-9]` est
  # même sa première stratégie — et la convention des codes courts est celle de
  # la VALEUR BRUTE : `massif_demo_units` porte C1 en tC/ha (20..300) et S3 en
  # habitants (70 200..271 900). Les règles étant indexées sur les noms longs,
  # un code court tombait sur l'écrêtage naïf : 400 m3/ha en `P1` rendait 100 au
  # lieu de 50, et le score de famille était faux sans un mot.
  expect_equal(normalize_indicator("C1", 75),
               normalize_indicator("indicateur_c1_biomasse", 75))
  expect_equal(normalize_indicator("P1", 400),
               normalize_indicator("indicateur_p1_volume", 400))
  expect_equal(normalize_indicator("P1", 400), 50)
  expect_equal(normalize_indicator("S3", 5000), 50)
  # Règle non linéaire (TWI) : même résultat par les deux écritures.
  expect_equal(normalize_indicator("W3", 3.5),
               normalize_indicator("indicateur_w3_humidite", 3.5))
  # Un code court inconnu reste sur le repli, sans invention.
  expect_equal(suppressWarnings(normalize_indicator("Z9", 42)), 42)
})

test_that("massif_demo_units uses its own _norm columns", {
  # La fixture de référence embarque C1_norm / C2_norm. Avant la correction de
  # la préférence `_norm`, elles étaient ignorées et les colonnes brutes étaient
  # écrêtées : famille_carbone valait 80,5 au lieu de 46,6.
  data(massif_demo_units, package = "nemeton")
  expect_true(all(c("C1_norm", "C2_norm") %in% names(massif_demo_units)))

  out <- suppressWarnings(create_family_index(massif_demo_units, method = "mean"))
  attendu <- (massif_demo_units$C1_norm + massif_demo_units$C2_norm) / 2
  expect_equal(out$famille_carbone, attendu, tolerance = 1e-6)
})
