# Politique de plafond mémoire — une seule, partagée par les trois chemins
# lourds (run_memory_capped, .reconfort_run_py, .reconfort_cap_memory).
# Décision 2026-09-01 : 40 % de MemTotal (révise les 50 % du 2026-08-22, après
# un TROISIÈME point de mesure), cf. l'en-tête de R/memory-ceiling.R.

test_that(".memory_ceiling derives 40% of MemTotal by default", {
  skip_if_not(file.exists("/proc/meminfo"), "Linux only")
  withr::local_options(nemeton.memory_max = NULL,
                       nemeton.reconfort_memory_max = NULL)
  withr::local_envvar(NEMETON_MEMORY_MAX = NA)

  kb  <- nemeton:::.mem_total_kb()
  skip_if(is.na(kb) || kb <= 0, "MemTotal unreadable")
  expected_gb <- floor(kb / 1048576 * 0.4)

  val <- nemeton:::.memory_ceiling()
  if (expected_gb < 4) {
    # Trop peu de RAM pour un plafond utile : aucun plafond, pas un plafond
    # ridicule qui ferait échouer tout travail légitime.
    expect_null(val)
  } else {
    expect_identical(val, paste0(expected_gb, "G"))
  }
})

test_that("the default sits BELOW EVERY level at which oomd was observed to act", {
  # C'est tout l'argument de la politique : un plafond entre le pic legitime
  # observe et le point de mort observe. Un plafond qui ne se declenche
  # qu'apres l'executeur n'est pas un plafond — c'est ce qui condamnait les
  # 70 % (21 Go, au-dessus des 17,1 Go du premier incident), puis les 50 %
  # (15 Go, au-dessus des 14,5 Go du troisieme).
  #
  # Le point de mort n'est PAS une constante de la machine : 17,1 Go un jour,
  # 14,5 Go un autre, selon le cache de pages, le swap et ce que le bureau
  # fait par ailleurs. D'ou le pluriel : le defaut doit passer sous TOUS les
  # points mesures, pas sous le dernier en date.
  ref_total_kb <- 32764424        # /proc/meminfo de la station de reference
  observed_kill_gb <- c(17.1,     # journal systemd-oomd du 2026-08-15
                        14.5)     # journal systemd-oomd du 2026-09-01
  heaviest_legit_gb <- 11.3       # chaine RECONFORT/IOTA2 complete, 2026-07-13

  ceiling_gb <- floor(ref_total_kb / 1048576 * nemeton:::.MEMORY_CEILING_FRACTION)
  expect_lt(ceiling_gb, min(observed_kill_gb))
  expect_gt(ceiling_gb, heaviest_legit_gb)
})

test_that("un nouveau point de mort sous le plafond doit faire echouer ce test", {
  # Garde-fou de la politique elle-meme, pas du code : si oomd est observe
  # plus bas que le plafond calcule, la fraction est redevenue inerte et il
  # faut la revoir. Ce test dit ou ajouter le point de mesure — dans le
  # vecteur du test precedent — plutot que de laisser quelqu'un deduire la
  # regle du seul chiffre 0.4.
  ref_total_kb <- 32764424
  ceiling_gb <- floor(ref_total_kb / 1048576 * nemeton:::.MEMORY_CEILING_FRACTION)
  expect_equal(ceiling_gb, 12)   # 40 % de 31,2 Go
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
