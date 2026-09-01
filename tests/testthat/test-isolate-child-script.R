# test-isolate-child-script.R — le script execute par l'enfant plafonne
#
# Ce script est du code ecrit sous forme de chaines : ni `R CMD check`, ni
# `codetools`, ni aucune relecture d'IDE ne le voit. Il portait un
# `on.exit(db_disconnect(con))` au niveau top-level d'un Rscript — ou un
# handler on.exit n'est JAMAIS tire. La ligne annoncait un nettoyage qui
# n'avait pas lieu (v0.193.1).

test_that("le script genere parse, et ne s'appuie sur aucun on.exit", {
  sc <- nemeton:::.capped_child_script()
  expect_type(sc, "character")
  expect_silent(invisible(parse(text = sc)))

  # Le piege : `on.exit()` hors d'une fonction ne s'execute pas. Si
  # quelqu'un en remet un ici, il croira nettoyer et ne nettoiera rien.
  code <- sc[!grepl("^\\s*#", sc)]
  expect_false(any(grepl("on\\.exit", code)))

  # Et la fermeture doit rester : `finally` s'execute, lui.
  expect_true(any(grepl("finally", code)))
  expect_true(any(grepl("db_disconnect", code)))
})

test_that("on.exit au top-level d'un Rscript ne se tire pas — la mesure", {
  skip_on_cran()
  # Le fait sur lequel repose le correctif, verifie plutot qu'affirme.
  f <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    'on.exit(cat("HANDLER-TIRE\\n"), add = TRUE)',
    'cat("CORPS\\n")'
  ), f)
  out <- system2(file.path(R.home("bin"), "Rscript"), shQuote(f),
                 stdout = TRUE, stderr = TRUE)
  expect_true(any(grepl("CORPS", out)))
  expect_false(any(grepl("HANDLER-TIRE", out)))
})

test_that("le script tourne de bout en bout et ecrit son resultat", {
  skip_on_cran()
  # Sans DB ni package tiers : `base::identity` ne prend ni `con` ni
  # `progress_callback`, donc les deux branches d'injection sont sautees
  # et le chemin execute est exactement celui du vrai enfant.
  dir <- withr::local_tempdir()
  f_in     <- file.path(dir, "call.rds")
  f_out    <- file.path(dir, "result.rds")
  f_script <- file.path(dir, "run.R")
  saveRDS(list(fun = "identity", args = list(x = 42L), package = "base",
               db_url = "", options = list(), progress_path = NULL,
               libs = .libPaths()), f_in)
  writeLines(nemeton:::.capped_child_script(), f_script)

  st <- system2(file.path(R.home("bin"), "Rscript"),
                shQuote(c(f_script, f_in, f_out)),
                stdout = TRUE, stderr = TRUE)
  expect_true(file.exists(f_out), info = paste(st, collapse = "\n"))
  expect_identical(readRDS(f_out), 42L)
})

test_that("une erreur du corps remonte, la fermeture ne l'avale pas", {
  skip_on_cran()
  dir <- withr::local_tempdir()
  f_in     <- file.path(dir, "call.rds")
  f_out    <- file.path(dir, "result.rds")
  f_script <- file.path(dir, "run.R")
  # `base::stop` leve : le parent DOIT voir l'echec, c'est tout l'interet
  # du process plafonne (un exit non nul, pas un result.rds silencieux).
  saveRDS(list(fun = "stop", args = list("boum"), package = "base",
               db_url = "", options = list(), progress_path = NULL,
               libs = .libPaths()), f_in)
  writeLines(nemeton:::.capped_child_script(), f_script)

  st <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                 shQuote(c(f_script, f_in, f_out)),
                                 stdout = TRUE, stderr = TRUE))
  expect_false(file.exists(f_out))
  expect_true(any(grepl("boum", st)))
})
