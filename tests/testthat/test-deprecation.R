# Avertissement de dépréciation (.avertir_depreciation) : une fois par session.
# Premiers usages : eobs_downscale(), eobs_downscale_bivariate() et
# tendances_estivales_eobs(), dépréciées en 2026.10.16 et retirées en 2026.10.18.

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
