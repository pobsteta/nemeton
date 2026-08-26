# Lecture de /proc/meminfo : garder le bruit systeme hors de la console —
# brief `briefs/vers-nemeton/2026-08-24-meminfo-windows.md`, sur un run Windows
# reel de Pascal.

test_that(".mem_total_kb n'avertit pas quand /proc/meminfo n'existe pas", {
  # Le defaut n'etait PAS l'echec — le tryCatch le gerait — mais l'AVERTISSEMENT
  # que readLines() emet AVANT d'echouer, que `tryCatch(error=)` n'attrape pas.
  # L'utilisateur Windows lisait « impossible d'ouvrir le fichier
  # '/proc/meminfo' » en plein calcul, au milieu d'un traitement qui aboutissait.
  local_mocked_bindings(
    file.exists = function(...) FALSE,
    .package = "base"
  )
  expect_no_warning(res <- nemeton:::.mem_total_kb())
  expect_true(is.na(res))
})

test_that(".pai_total_ram_gb a la meme garde", {
  # Second site du meme defaut : il n'etait pas apparu dans le run signale,
  # mais serait sorti au premier calcul de reGeneration sous Windows.
  local_mocked_bindings(
    file.exists = function(...) FALSE,
    .package = "base"
  )
  expect_no_warning(res <- nemeton:::.pai_total_ram_gb())
  expect_true(is.na(res))
})

test_that("sans MemTotal lisible, le plafond est absent et non fantaisiste", {
  local_mocked_bindings(.mem_total_kb = function() NA_real_)
  withr::local_options(nemeton.memory_max = NULL,
                       nemeton.reconfort_memory_max = NULL)
  withr::local_envvar(NEMETON_MEMORY_MAX = NA)
  expect_null(nemeton:::.memory_ceiling())
})

test_that("le message « sans plafond » ne parle pas de cgroup hors Linux", {
  # Sous Windows il n'y a ni cgroup ni OOM killer : expliquer le probleme avec
  # ce vocabulaire, c'est le decrire dans des termes que la plateforme ignore —
  # l'utilisateur n'a ni systemd a installer ni cgroup a activer.
  #
  # Verifie sur le CORPS de la fonction plutot que par un appel :
  # `run_memory_capped()` exige un processus enfant et un systemd-run absent
  # pour atteindre cette branche, ce qu'un test ne peut pas mettre en scene
  # proprement sur une machine qui, elle, a les deux.
  f <- deparse(nemeton::run_memory_capped)
  i_unix <- grep('identical\\(.Platform\\$OS\\.type, "unix"\\)', f)
  expect_length(i_unix, 1L)
  # La phrase « OOM killer » vit dans la branche unix, pas dans l'autre.
  i_oom  <- grep("OOM killer", f)
  i_else <- grep("not available on this platform|memory ceilings are not", f)
  expect_true(length(i_oom) >= 1L)
  expect_true(length(i_else) >= 1L)
  expect_true(min(i_oom) < min(i_else))
})
