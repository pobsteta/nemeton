# Tests ifn_source.R — accès aux données brutes IFN (spec 040).
# Les cas réseau sont skippés hors ligne : la CI ne doit pas dépendre de
# la disponibilité du serveur de l'IGN.

test_that("argument validation happens before any network access", {
  expect_error(ifn_telecharger(), "dest_dir")
  expect_error(ifn_telecharger(c("a", "b")), "dest_dir")
  expect_error(ifn_charger(character(0)), "non-empty")
  expect_error(ifn_charger("ARBRE", visite = 3), "visite")
})

test_that("the export URL follows the IGN naming scheme", {
  u <- nemeton:::.ifn_url(2024)
  expect_match(u, "export_dataifn_2005_2024\\.zip$")
  expect_match(u, "^https://inventaire-forestier\\.ign\\.fr/")
})

test_that("the latest campaign is discovered, not hard-coded", {
  skip_on_cran()
  skip_if_offline()
  info <- ifn_campagne_disponible()
  expect_true(is.numeric(info$campagne))
  # Le point de la reimplementation : ne pas rester fige sur 2023 comme
  # FrenchNFIfindeR. Au 22/07/2026 la campagne servie est 2024.
  expect_gte(info$campagne, 2024)
  expect_equal(info$millesime, paste0("2005-", info$campagne))
})
