# Dépréciation d'eobs_downscale(), eobs_downscale_bivariate() et
# tendances_estivales_eobs() (2026.10.16, spec 063) : une fois par session.

.reset_depreciations <- function() {
  rm(list = ls(nemeton:::.DEPRECIATIONS_SIGNALEES),
     envir = nemeton:::.DEPRECIATIONS_SIGNALEES)
}

test_that("l'avertissement part une seule fois par fonction et par session", {
  withr::local_options(nemeton.deprecation_silencieuse = FALSE)
  .reset_depreciations(); withr::defer(.reset_depreciations())
  expect_warning(nemeton:::.avertir_depreciation("f_test", "2026.10.16", "`g()`"),
                 class = "nemeton_deprecated")
  expect_no_warning(nemeton:::.avertir_depreciation("f_test", "2026.10.16", "`g()`"))
  withr::local_options(nemeton.deprecation_silencieuse = TRUE)
  expect_no_warning(nemeton:::.avertir_depreciation("autre", "2026.10.16", "`g()`"))
})

test_that("les trois fonctions E-OBS de contexte sont dépréciées", {
  withr::local_options(nemeton.deprecation_silencieuse = FALSE)
  .reset_depreciations(); withr::defer(.reset_depreciations())
  aoi <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(4e6, 3e6)), crs = 3035))
  expect_warning(try(tendances_estivales_eobs(aoi), silent = TRUE),
                 "climat_tendance_bivariee", class = "nemeton_deprecated")
  expect_warning(try(eobs_downscale("tx", eobs = NULL, aoi = aoi), silent = TRUE),
                 "eobs_downscale", class = "nemeton_deprecated")
  # La bivariée n'avertit que pour elle-même, pas pour ses appels internes.
  .reset_depreciations()
  w <- character(0)
  withCallingHandlers(
    try(eobs_downscale_bivariate(NULL, NULL, aoi = aoi), silent = TRUE),
    nemeton_deprecated = function(c) {
      w <<- c(w, conditionMessage(c)); invokeRestart("muffleWarning")
    })
  expect_length(w, 1L)
  expect_match(w, "eobs_downscale_bivariate")
})
