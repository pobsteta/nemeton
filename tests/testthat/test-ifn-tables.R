# Tests ifn_volume_essence_ser() / ifn_volume_reference() — spec 040 lots 2-3.

test_that("the bundled table carries the three nested levels", {
  d <- ifn_volume_essence_ser()
  expect_true(all(c("niveau", "ser", "greco", "espar", "n_plac_presence",
                    "vol_ha_present", "vol_ha_maille", "millesime",
                    "source") %in% names(d)))
  expect_setequal(unique(d$niveau), c("ser", "greco", "national"))
  expect_gt(nrow(d), 5000)
})

test_that("SER rows carry a SER, national rows carry none", {
  s <- ifn_volume_essence_ser(niveau = "ser")
  expect_false(any(is.na(s$ser)))
  n <- ifn_volume_essence_ser(niveau = "national")
  expect_true(all(is.na(n$ser)))
  expect_true(all(is.na(n$greco)))
})

test_that("the GRECO is the SER code's first letter", {
  s <- ifn_volume_essence_ser(niveau = "ser")
  expect_equal(sort(unique(substr(s$ser, 1, 1))),
               sort(unique(ifn_volume_essence_ser(niveau = "greco")$greco)))
})

test_that("filters compose", {
  d <- ifn_volume_essence_ser(espar = "09", ser = "C20")
  expect_equal(nrow(d), 1L)
  expect_equal(d$espar, "09")
  expect_equal(d$niveau, "ser")
})

test_that("vol_ha_present is at least vol_ha_maille", {
  # Par construction : la moyenne sur les placettes de présence ne peut pas
  # être inférieure à la moyenne diluée sur toutes les placettes.
  d <- ifn_volume_essence_ser(niveau = "ser")
  expect_true(all(d$vol_ha_present >= d$vol_ha_maille - 1e-6))
})

test_that("the ladder uses the SER level when it is deep enough", {
  r <- ifn_volume_reference("09", ser = "C20", min_plac = 30)
  expect_equal(r$niveau_utilise, "ser")
  expect_equal(r$ser, "C20")
  expect_gt(r$vol_ha, 0)
})

test_that("the ladder falls back when the SER cell is too thin", {
  # Seuil derive de la donnee, pas code en dur : le nombre de placettes croit
  # a chaque campagne, une constante rendrait ce test faux au prochain
  # millesime (constate au passage 2005-2019 -> 2005-2024).
  cell <- ifn_volume_essence_ser(espar = "09", ser = "C20")
  r <- ifn_volume_reference("09", ser = "C20",
                            min_plac = cell$n_plac_presence + 1)
  expect_true(r$niveau_utilise %in% c("greco", "national"))
  expect_false(identical(r$niveau_utilise, "ser"))
})

test_that("without a SER the ladder starts national", {
  r <- ifn_volume_reference("09")
  expect_equal(r$niveau_utilise, "national")
  expect_true(is.na(r$ser))
})

test_that("an unknown species yields NA rather than a figure", {
  r <- ifn_volume_reference("ZZZ", ser = "C20")
  expect_true(is.na(r$vol_ha))
  expect_true(is.na(r$niveau_utilise))
})

test_that("the ladder is vectorised over species and keeps order", {
  r <- ifn_volume_reference(c("09", "02", "ZZZ"), ser = "C20")
  expect_equal(nrow(r), 3L)
  expect_equal(r$espar, c("09", "02", "ZZZ"))
})

test_that("mesure switches between the stand and resource figures", {
  a <- ifn_volume_reference("09", ser = "C20", mesure = "present")
  b <- ifn_volume_reference("09", ser = "C20", mesure = "maille")
  expect_gt(a$vol_ha, b$vol_ha)
})

test_that("invalid arguments are refused", {
  expect_error(ifn_volume_reference(character(0)), "non-empty")
  expect_error(ifn_volume_reference("09", ser = c("C20", "D11")), "single SER")
  expect_error(ifn_volume_reference("09", min_plac = -1), "non-negative")
})

# --- Prélèvement (spec 040, D4) --------------------------------------

test_that("the harvest table carries the three levels and a yearly rate", {
  d <- ifn_prelevement_essence_ser()
  expect_setequal(unique(d$niveau), c("ser", "greco", "national"))
  expect_true(all(c("prelev_ha_an_present", "prelev_ha_an_maille") %in% names(d)))
  expect_true(all(d$prelev_ha_an_maille >= 0))
})

test_that("national harvest matches the published order of magnitude", {
  # Somme sur toutes les essences au niveau national : la recolte francaise
  # est de l'ordre de 2,5-3 m3/ha/an. Garde-fou contre une erreur d'echelle
  # (oubli du /5, mauvaise colonne, double comptage).
  n <- ifn_prelevement_essence_ser(niveau = "national")
  total <- sum(n$prelev_ha_an_maille, na.rm = TRUE)
  expect_gt(total, 1.5)
  expect_lt(total, 5)
})

test_that("harvest never exceeds standing volume for a given cell", {
  v <- ifn_volume_essence_ser(niveau = "national")
  p <- ifn_prelevement_essence_ser(niveau = "national")
  m <- merge(v[, c("espar", "vol_ha_maille")],
             p[, c("espar", "prelev_ha_an_maille")], by = "espar")
  # Un prelevement annuel superieur au stock sur pied serait absurde.
  expect_true(all(m$prelev_ha_an_maille <= m$vol_ha_maille))
})

test_that("the harvest ladder declares the level it used", {
  r <- ifn_taux_prelevement("62", ser = "C20")
  expect_true(r$niveau_utilise %in% c("ser", "greco", "national"))
  expect_true(is.numeric(r$taux_m3_ha_an))
  expect_gte(r$taux_m3_ha_an, 0)
})

test_that("mesure switches the harvest figure, present >= maille", {
  a <- ifn_taux_prelevement("19", mesure = "present")
  b <- ifn_taux_prelevement("19", mesure = "maille")
  # Peuplier cultive : coupe rase tres localisee, l'ecart est enorme.
  expect_gt(a$taux_m3_ha_an, b$taux_m3_ha_an)
})

test_that("an unknown species yields NA rather than a rate", {
  r <- ifn_taux_prelevement("ZZZ")
  expect_true(is.na(r$taux_m3_ha_an))
  expect_true(is.na(r$niveau_utilise))
})
