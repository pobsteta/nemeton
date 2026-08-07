# Plafond mémoire terra posé au chargement du paquet (.onLoad).
#
# Contexte : `memfrac` est une *fraction* de la RAM totale, donc le plafond
# effectif varie du simple au décuple d'une machine à l'autre, et il ignore ce
# que la machine peut réellement céder. Le 2026-08-07, terra s'autorisait ~15 Go
# dans une session qui partageait le user slice avec RStudio et un navigateur :
# systemd-oomd a tué le scope entier bien avant que terra ne songe à écrire sur
# disque. `memmax` est un plafond absolu en Go, identique partout, et adaptatif
# (terra ne bascule sur disque que pour les rasters qui le dépassent).

skip_if_not_installed("terra")

# `devtools::load_all()` ne réexporte pas les hooks de chargement : on va
# chercher .onLoad dans le namespace plutôt que dans l'environnement de test.
onload <- get(".onLoad", envir = asNamespace("nemeton"))

local_terra_mem <- function(env = parent.frame()) {
  before <- terra::terraOptions(print = FALSE)
  withr::defer(
    terra::terraOptions(memmax = before$memmax, memfrac = before$memfrac),
    envir = env
  )
}

test_that(".onLoad caps terra memory at an absolute 3 GB by default", {
  local_terra_mem()
  withr::local_options(nemeton.terra_memmax = NULL)
  withr::local_envvar(NEMETON_TERRA_MEMMAX = NA)

  onload(NULL, "nemeton")

  expect_equal(terra::terraOptions(print = FALSE)$memmax, 3)
})

test_that(".onLoad honours the option, then the environment variable", {
  local_terra_mem()

  withr::local_envvar(NEMETON_TERRA_MEMMAX = "6")
  onload(NULL, "nemeton")
  expect_equal(terra::terraOptions(print = FALSE)$memmax, 6)

  withr::local_options(nemeton.terra_memmax = 8)
  onload(NULL, "nemeton")
  expect_equal(terra::terraOptions(print = FALSE)$memmax, 8)
})

test_that(".onLoad opts out on a non-positive cap (terra spells that -1)", {
  local_terra_mem()
  withr::local_envvar(NEMETON_TERRA_MEMMAX = NA)

  for (v in list(-1, 0)) {
    withr::local_options(nemeton.terra_memmax = v)
    onload(NULL, "nemeton")
    expect_equal(terra::terraOptions(print = FALSE)$memmax, -1, info = format(v))
  }
})

test_that(".onLoad still sets memfrac, and survives an unusable setting", {
  local_terra_mem()
  withr::local_envvar(NEMETON_TERRA_MEMMAX = NA)
  withr::local_options(nemeton.terra_memfrac = 0.3,
                       nemeton.terra_memmax = "beaucoup")

  # Un réglage illisible ne doit jamais faire échouer le chargement du paquet.
  expect_no_error(onload(NULL, "nemeton"))
  expect_equal(terra::terraOptions(print = FALSE)$memfrac, 0.3)
})

test_that("the memfrac guard rejects values terra would refuse", {
  local_terra_mem()
  before <- terra::terraOptions(print = FALSE)$memfrac
  withr::local_options(nemeton.terra_memfrac = 2)  # hors (0, 0.9]

  onload(NULL, "nemeton")

  expect_equal(terra::terraOptions(print = FALSE)$memfrac, before)
})
