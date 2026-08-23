# Diagnostic d'un enfant plafonné qui meurt — brief
# `nemetonshiny/specs/BRIEF-nemeton-oom-sigterm-scope.md` (2026-08-23).
#
# Le fond du sujet : le code de sortie ne dit PAS ce qui s'est passé. Un même
# dépassement de plafond remonte en -9 (reproduit ici) ou en -15 (observé en
# production le 2026-08-22), et les deux signifient aussi « quelqu'un a arrêté
# le scope ». On demande donc son verdict à systemd, et on ne prétend rien
# quand il ne répond pas.

test_that("systemd's oom-kill verdict is asserted, not hedged", {
  msg <- nemeton:::.capped_failure_message("run_x", -15L, "15G", "oom-kill")
  expect_match(msg[[1]], "ran out of memory")
  expect_match(msg[[1]], "15G", fixed = TRUE)
  # Les echappatoires sont nommees : un utilisateur d'app n'atteint pas
  # l'argument R, mais il atteint la variable d'environnement.
  expect_true(any(grepl("NEMETON_MEMORY_MAX", msg)))
  expect_true(any(grepl("spared", msg)))
})

test_that("the SAME verdict is reached from -9, -15, 137 and 143", {
  # C'est precisement le defaut corrige : la branche memoire ne connaissait que
  # -9/137 et le chemin nominal (systemd-run present) remonte -15.
  for (st in c(-9L, -15L, 137L, 143L)) {
    msg <- nemeton:::.capped_failure_message("run_x", st, "15G", "oom-kill")
    expect_match(msg[[1]], "ran out of memory", info = paste("exit", st))
  }
})

test_that("a non-memory verdict is never dressed up as an OOM", {
  # `systemctl stop`, arret de session, kill exterieur : meme -15, autre cause.
  msg <- nemeton:::.capped_failure_message("run_x", -15L, "15G", "signal")
  expect_false(any(grepl("ran out of memory", msg)))
  expect_match(msg[[1]], "signal")
  expect_true(any(grepl("not the memory ceiling", msg)))

  timeout <- nemeton:::.capped_failure_message("run_x", -15L, "15G", "timeout")
  expect_true(any(grepl("time limit", timeout)))
})

test_that("without a verdict, the ceiling is given as a likelihood", {
  # Mode degrade : pas de cgroup, pas de systemctl, ou unite deja disparue.
  msg <- nemeton:::.capped_failure_message("run_x", -15L, "15G", NA_character_)
  expect_match(msg[[1]], "killed \\(signal 15")
  expect_true(any(grepl("usual cause", msg)))
  # Ne pas affirmer ce qu'on ne sait pas.
  expect_false(any(grepl("ran out of memory", msg)))
  expect_true(any(grepl("looks the same from here", msg)))

  # Le signal est lu, pas recopie : 137 = 128 + 9.
  expect_match(nemeton:::.capped_failure_message("run_x", 137L, "15G")[[1]],
               "signal 9")
})

test_that("an ordinary non-zero exit stays an ordinary message", {
  # Une erreur R dans l'enfant sort en 1 et le scope reussit : ne rien inventer.
  msg <- nemeton:::.capped_failure_message("run_x", 1L, "15G", "success")
  expect_length(msg, 1L)
  expect_match(msg, "exit 1")
  expect_false(any(grepl("memory", msg)))
})

test_that("a brace in the function name cannot become a cli expression", {
  msg <- nemeton:::.capped_failure_message("f{bad}", 1L, "15G", "success")
  expect_no_error(cli::format_inline(msg))
})

test_that("naming the scope trades --collect for our own cleanup", {
  # MESURE 2026-08-23 : avec --collect, un scope mort d'OOM repond
  # `Result=success` — l'unite a disparu avant qu'on l'interroge. Les deux
  # options sont donc exclusives, et c'est ce que la construction encode.
  named <- nemeton:::.reconfort_cap_memory(
    "cmd", "a", memory_max = "8G", systemd_run = "/usr/bin/systemd-run",
    unit = "nemeton-test.scope")
  expect_true("--unit=nemeton-test.scope" %in% named$args)
  expect_false("--collect" %in% named$args)
  expect_identical(named$unit, "nemeton-test.scope")

  anon <- nemeton:::.reconfort_cap_memory(
    "cmd", "a", memory_max = "8G", systemd_run = "/usr/bin/systemd-run")
  expect_true("--collect" %in% anon$args)
  expect_false(any(grepl("^--unit=", anon$args)))
  expect_null(anon$unit)

  # Le plafond et la commande d'origine survivent aux deux variantes.
  for (out in list(named, anon)) {
    expect_true("--property=MemoryMax=8G" %in% out$args)
    i <- which(out$args == "--")
    expect_identical(out$args[(i + 1L):length(out$args)], c("cmd", "a"))
  }
})

test_that(".capped_scope_unit produces a name systemd accepts", {
  u <- nemeton:::.capped_scope_unit("run_fordead_dieback")
  expect_match(u, "^nemeton-run_fordead_dieback-[0-9]+-[A-Za-z0-9]+\\.scope$")
  # Deux appels ne collident pas (deux runs concurrents du meme travail).
  expect_false(identical(u, nemeton:::.capped_scope_unit("run_fordead_dieback")))
  # Un nom exotique est plie, pas refuse.
  expect_match(nemeton:::.capped_scope_unit("a b/c:d"), "^nemeton-a-b-c-d-")
  expect_no_match(nemeton:::.capped_scope_unit("a b/c"), "[ /]")
})

test_that(".capped_scope_result and _reset answer safely when asked nothing", {
  expect_true(is.na(nemeton:::.capped_scope_result(NULL)))
  expect_true(is.na(nemeton:::.capped_scope_result("")))
  expect_null(nemeton:::.capped_scope_reset(NULL))
  # Une unite inexistante : jamais d'erreur, et surtout pas un faux verdict.
  r <- nemeton:::.capped_scope_result("nemeton-inexistante-0-zz.scope",
                                      timeout_ms = 200L)
  expect_true(is.na(r) || identical(r, "success"))
})
