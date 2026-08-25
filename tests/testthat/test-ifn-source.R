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
  # `skip_if_offline()` teste la connectivite GENERALE, pas le serveur de
  # l'IGN. Sur un runner GitHub, Internet est debout et c'est l'IGN qui ne
  # repond pas : la garde passait, la sonde echouait, et un job REQUIS
  # tombait sur une panne amont (2026-08-25, PR #430 — une PR qui ne
  # touchait que DESCRIPTION et un fichier Markdown).
  #
  # La garde porte donc sur la dependance REELLE. Ce n'est pas taire le
  # test : s'il repond, les assertions valent, et un serveur qui servirait
  # une campagne anterieure a 2024 le ferait toujours echouer — c'est
  # exactement ce pour quoi il existe.
  info <- tryCatch(ifn_campagne_disponible(), error = function(e) NULL)
  skip_if(is.null(info),
          "Serveur d'export IFN de l'IGN injoignable depuis cet environnement")
  expect_true(is.numeric(info$campagne))
  # Le point de la reimplementation : ne pas rester fige sur 2023 comme
  # FrenchNFIfindeR. Au 22/07/2026 la campagne servie est 2024.
  expect_gte(info$campagne, 2024)
  expect_equal(info$millesime, paste0("2005-", info$campagne))
})
