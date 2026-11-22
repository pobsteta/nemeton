# Marqueur de run plafonné (2026-11-22 : quatre moteurs reGénération vivants sur
# un même projet, rien ne permettait de le savoir ni de les arrêter).

# Sans systemd (ou un scope inconnu), on retombe sur la table des processus.
.sans_systemd <- function(env = parent.frame()) {
  local_mocked_bindings(.capped_unit_active = function(unit) NA, .env = env)
}

test_that("le marqueur est ecrit puis relu, champs compris", {
  d <- withr::local_tempdir()
  p <- file.path(d, "sous", "engine_run.json")
  nemeton:::.capped_marker_write(p, unit = "nemeton-x.scope", pid = 42L,
                                 fun = "run_x", package = "pkg")
  rec <- nemeton:::.capped_marker_read(p)
  expect_identical(rec$pid, 42L)
  expect_identical(rec$unit, "nemeton-x.scope")
  expect_identical(rec$fun, "run_x")
  expect_identical(rec$package, "pkg")
  expect_identical(as.integer(rec$parent_pid), as.integer(Sys.getpid()))
  expect_true(nzchar(rec$started))
  # Unit absente -> NA, pas une chaine vide.
  nemeton:::.capped_marker_write(p, unit = NULL, pid = 42L, fun = "f", package = "p")
  expect_true(is.na(nemeton:::.capped_marker_read(p)$unit))
})

test_that("le marqueur n'est retire que par le run qui l'a pose", {
  d <- withr::local_tempdir()
  p <- file.path(d, "engine_run.json")
  nemeton:::.capped_marker_write(p, unit = NA, pid = 100L, fun = "f", package = "p")
  nemeton:::.capped_marker_release(p, 999L)   # run plus ancien : n'efface pas
  expect_true(file.exists(p))
  nemeton:::.capped_marker_release(p, 100L)
  expect_false(file.exists(p))
})

test_that("capped_run_alive rend le marqueur d'un run vivant", {
  skip_on_os("windows")
  .sans_systemd()
  d <- withr::local_tempdir()
  p <- file.path(d, "engine_run.json")
  nemeton:::.capped_marker_write(p, unit = NA, pid = Sys.getpid(), fun = "f", package = "p")
  rec <- capped_run_alive(p)
  expect_identical(rec$pid, as.integer(Sys.getpid()))
  expect_true(file.exists(p))
})

test_that("capped_run_alive efface un marqueur perime ou illisible", {
  skip_on_os("windows")
  skip_if_not_installed("processx")
  .sans_systemd()
  d <- withr::local_tempdir()
  p <- file.path(d, "engine_run.json")
  px <- processx::process$new("true")
  px$wait(5000)
  nemeton:::.capped_marker_write(p, unit = NA, pid = px$get_pid(), fun = "f", package = "p")
  expect_null(capped_run_alive(p))
  expect_false(file.exists(p))

  writeLines("pas du json {", p)
  expect_null(capped_run_alive(p))
  expect_false(file.exists(p))

  expect_null(capped_run_alive(file.path(d, "absent.json")))
  expect_error(capped_run_alive(c("a", "b")), "single non-empty path")
})

test_that("systemd fait foi quand il sait repondre", {
  d <- withr::local_tempdir()
  p <- file.path(d, "engine_run.json")
  nemeton:::.capped_marker_write(p, unit = "nemeton-x.scope", pid = Sys.getpid(),
                                 fun = "f", package = "p")
  # Scope inactif : run fini, meme si le pid (le notre) vit.
  local_mocked_bindings(.capped_unit_active = function(unit) FALSE)
  expect_null(capped_run_alive(p))
  expect_false(file.exists(p))
})

test_that("stop_memory_capped arrete le run et retire son marqueur", {
  skip_on_os("windows")
  skip_if_not_installed("processx")
  .sans_systemd()
  d <- withr::local_tempdir()
  p <- file.path(d, "engine_run.json")
  px <- processx::process$new("sleep", "60")
  on.exit(if (px$is_alive()) px$kill(), add = TRUE)
  nemeton:::.capped_marker_write(p, unit = NA, pid = px$get_pid(), fun = "f", package = "p")
  expect_true(stop_memory_capped(p, timeout = 5))
  px$wait(2000)
  expect_false(px$is_alive())
  expect_false(file.exists(p))
  # Plus rien a arreter.
  expect_false(stop_memory_capped(p))
})

test_that("run_memory_capped refuse un marker_path qui n'en est pas un", {
  expect_error(run_memory_capped("ndp_table", marker_path = c("a", "b")),
               "single non-empty path")
  expect_error(run_memory_capped("ndp_table", marker_path = ""),
               "single non-empty path")
})

test_that("run_memory_capped pose le marqueur pendant le run et le retire apres", {
  skip_on_cran()
  skip_if(pkgload::is_dev_package("nemeton"),
          "l'enfant a besoin de nemeton installé (load_all seul)")
  skip_if_not_installed("processx")
  skip_if_not_installed("jsonlite")
  d <- withr::local_tempdir()
  p <- file.path(d, "engine_run.json")
  res <- suppressWarnings(run_memory_capped(
    "ndp_table", quiet = TRUE, marker_path = p))
  expect_s3_class(res, "data.frame")
  expect_false(file.exists(p))
})
