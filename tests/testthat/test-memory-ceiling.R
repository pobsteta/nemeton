# Politique de plafond mémoire — une seule, partagée par les trois chemins
# lourds (run_memory_capped, .reconfort_run_py, .reconfort_cap_memory).
# Décision 2026-08-22 : 50 % de MemTotal, cf. l'en-tête de R/memory-ceiling.R.

test_that(".memory_ceiling derives 50% of MemTotal by default", {
  skip_if_not(file.exists("/proc/meminfo"), "Linux only")
  withr::local_options(nemeton.memory_max = NULL,
                       nemeton.reconfort_memory_max = NULL)
  withr::local_envvar(NEMETON_MEMORY_MAX = NA)

  kb  <- nemeton:::.mem_total_kb()
  skip_if(is.na(kb) || kb <= 0, "MemTotal unreadable")
  expected_gb <- floor(kb / 1048576 * 0.5)

  val <- nemeton:::.memory_ceiling()
  if (expected_gb < 4) {
    # Trop peu de RAM pour un plafond utile : aucun plafond, pas un plafond
    # ridicule qui ferait échouer tout travail légitime.
    expect_null(val)
  } else {
    expect_identical(val, paste0(expected_gb, "G"))
  }
})

test_that("the default sits BELOW the level at which oomd was observed to act", {
  # C'est tout l'argument du changement : l'ancien défaut (70 %) valait 21 Go
  # sur la station de référence (31,2 Go), au-dessus des 17,1 Go auxquels
  # systemd-oomd avait déjà tué la session. Un plafond qui ne se déclenche
  # qu'après l'exécuteur n'est pas un plafond.
  ref_total_kb <- 32764424            # /proc/meminfo de la station de l'incident
  observed_kill_gb <- 17.1            # journal systemd-oomd du 2026-08-15

  ceiling_gb <- floor(ref_total_kb / 1048576 * nemeton:::.MEMORY_CEILING_FRACTION)
  expect_lt(ceiling_gb, observed_kill_gb)
  # ... et au-dessus du run légitime le plus lourd jamais mesuré ici
  # (chaîne RECONFORT/IOTA2 complète, 11,3 Go le 2026-07-13).
  expect_gt(ceiling_gb, 11.3)
})

test_that("options() outrank the environment variable", {
  withr::local_envvar(NEMETON_MEMORY_MAX = "8G")
  withr::local_options(nemeton.memory_max = "12G")
  expect_identical(nemeton:::.memory_ceiling(), "12G")

  # Le nom historique reste honoré : nemetonshiny et les scripts existants
  # le posent encore.
  withr::local_options(nemeton.memory_max = NULL,
                       nemeton.reconfort_memory_max = "16G")
  expect_identical(nemeton:::.memory_ceiling(), "16G")
})

test_that("the environment variable is honoured when no option is set", {
  withr::local_options(nemeton.memory_max = NULL,
                       nemeton.reconfort_memory_max = NULL)
  withr::local_envvar(NEMETON_MEMORY_MAX = "9G")
  expect_identical(nemeton:::.memory_ceiling(), "9G")

  # Une variable vide n'est pas une valeur : on retombe sur le défaut calculé.
  withr::local_envvar(NEMETON_MEMORY_MAX = "  ")
  val <- nemeton:::.memory_ceiling()
  expect_true(is.null(val) || grepl("^[0-9]+G$", val))
})

test_that("every spelling of 'no ceiling' disables it, from either knob", {
  withr::local_options(nemeton.memory_max = NULL,
                       nemeton.reconfort_memory_max = NULL)
  for (word in c("none", "off", "false", "no", "0", "NONE", "Off", "")) {
    withr::local_envvar(NEMETON_MEMORY_MAX = word)
    if (!nzchar(word)) next   # vide = non renseigné, testé plus haut
    expect_null(nemeton:::.memory_ceiling(), info = word)
  }
  withr::local_envvar(NEMETON_MEMORY_MAX = NA)
  withr::local_options(nemeton.memory_max = FALSE)
  expect_null(nemeton:::.memory_ceiling())
  withr::local_options(nemeton.memory_max = "")
  expect_null(nemeton:::.memory_ceiling())
})

test_that(".memory_ceiling_parse normalises what a caller passes", {
  expect_identical(nemeton:::.memory_ceiling_parse("20G"), "20G")
  expect_identical(nemeton:::.memory_ceiling_parse(" 20G "), "20G")
  expect_null(nemeton:::.memory_ceiling_parse(FALSE))
  expect_null(nemeton:::.memory_ceiling_parse("none"))
  expect_null(nemeton:::.memory_ceiling_parse(""))
})

test_that("the RECONFORT alias and run_memory_capped share the one policy", {
  # Le point du changement : trois travaux lourds d'une même session ne peuvent
  # plus tourner sous trois plafonds différents.
  withr::local_options(nemeton.memory_max = "13G",
                       nemeton.reconfort_memory_max = NULL)
  expect_identical(nemeton:::.reconfort_memory_max(), "13G")
  expect_identical(nemeton:::.memory_ceiling(), "13G")

  # Et le plafond effectivement posé sur le scope systemd est celui-là.
  out <- nemeton:::.reconfort_cap_memory(
    "conda", c("run", "-n", "e"), systemd_run = "/usr/bin/systemd-run")
  expect_true("--property=MemoryMax=13G" %in% out$args)
})
