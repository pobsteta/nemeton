# Tests for run_reconfort_dieback() orchestration (lot L2b.3). Every
# external step (conda env, model/mask fetch, S2 ingest, IOTA2
# subprocess) is mocked — no Python, no network, no GB of S2.

# A throwaway DBIConnection just to satisfy con validation. tiles= is
# always passed so .get_zone_aoi() is never reached.
local_con <- function(env = parent.frame()) {
  testthat::skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  withr::defer(DBI::dbDisconnect(con), envir = env)
  con
}

# Install mocks where .reconfort_run_py fabricates the IOTA2 final
# rasters so output collection succeeds. `write_score` toggles whether
# the continuous-score raster is produced (to exercise the guard).
mock_pipeline <- function(calls_env, write_score = TRUE, exit = 0L) {
  bindings <- list(
    .ensure_reconfort_python = function(...) "test-env",
    .reconfort_conda_binary  = function() "/opt/conda/bin/conda",
    ensure_reconfort_model   = function(version, cache_dir = NULL, quiet = FALSE) {
      d <- withr::local_tempdir(.local_envir = calls_env$env)
      p <- file.path(d, "model_1_seed_0.txt"); writeLines("model", p); p
    },
    ensure_reconfort_oso_mask = function(...) {
      d <- withr::local_tempdir(.local_envir = calls_env$env)
      p <- file.path(d, RECONFORT_OSO_MASK$file); writeLines("mask", p); p
    },
    reconfort_ingest_s2 = function(aoi = NULL, tiles = NULL, date_from, date_to,
                                   s2_root, geodes_config = NULL, quiet = FALSE,
                                   ...) {
      ex <- file.path(s2_root, "extracted", tiles)
      for (e in ex) dir.create(e, recursive = TRUE, showWarnings = FALSE)
      calls_env$ingest <- TRUE
      calls_env$ingest_aoi <- aoi  # streaming mode passes the AOI
      list(tiles = tiles, s2_root = s2_root, extracted = ex)
    },
    .reconfort_run_py = function(conda_bin, env, script, cfg, workdir, quiet = FALSE) {
      calls_env$cfg <- readLines(cfg)
      calls_env$script <- basename(script)
      if (identical(as.integer(exit), 0L)) {
        kv <- calls_env$cfg
        getv <- function(k) sub(paste0("^", k, "='?([^']*)'?$"), "\\1",
                                grep(paste0("^", k, "="), kv, value = TRUE))
        label <- getv("label"); year <- getv("S2_year")
        final <- file.path(workdir, "results",
                           sprintf("iota2_results_classif_labels-%s-S2_%s", label, year),
                           "final")
        dir.create(final, recursive = TRUE, showWarnings = FALSE)
        writeLines("x", file.path(final, "Classif_Seed_0.tif"))
        writeLines("x", file.path(final, "ProbabilityMap_seed_0.tif"))
        if (write_score) {
          writeLines("x", file.path(final, sprintf("Final_continuous_score_masked%s.tif", year)))
        }
      }
      # `as.integer()` deposerait l'attribut `systemd_result` que le vrai
      # `.reconfort_run_py()` accroche au statut (verdict systemd).
      exit
    }
  )
  # Bind the mocks to the *test's* environment so they survive past this
  # helper's own frame (otherwise local_mocked_bindings would undo them
  # the moment mock_pipeline returns).
  do.call(testthat::local_mocked_bindings, c(bindings, list(.env = calls_env$env)))
}

test_that("run_reconfort_dieback orchestrates the phases and collects outputs", {
  skip_if_terra_write_broken()   # clustering post-process writes a TIF (runner anomaly)
  con <- local_con()
  cache <- withr::local_tempdir()
  calls <- new.env(); calls$env <- environment()
  mock_pipeline(calls)

  phases <- character(0)
  res <- run_reconfort_dieback(
    con = con, zone_id = 7L, cache_dir = cache,
    s2_year = 2024L, tiles = "T31UDP", quiet = TRUE,
    progress_callback = function(p) {
      if (identical(p$current, "reconfort:phase")) phases[[length(phases) + 1L]] <<- p$phase_name
    })

  expect_equal(res$status, "completed")
  expect_equal(res$tiles, "T31UDP")
  expect_equal(res$species, "CHE")              # v3 -> oak
  expect_true(file.exists(res$rasters$continuous_score))
  expect_true(file.exists(res$meta))            # run_meta.json written
  expect_true(calls$ingest)
  expect_identical(calls$script, "run_map_production_reconfort.py")
  # all 10 phases fired, in order (postprocess L3, persist L5, spec 021)
  expect_equal(phases, c("env","model","mask","tiles","ingest","stage","mapprod","collect","postprocess","persist"))
})

test_that("run_reconfort_dieback writes a cfg with masking on by default", {
  skip_if_terra_write_broken()   # clustering post-process writes a TIF (runner anomaly)
  con <- local_con()
  cache <- withr::local_tempdir()
  calls <- new.env(); calls$env <- environment()
  mock_pipeline(calls)

  run_reconfort_dieback(con = con, zone_id = 1L, cache_dir = cache,
                        s2_year = 2024L, tiles = "T31UDP", quiet = TRUE)
  cfg <- calls$cfg
  expect_true(any(grepl("^v_model='v3'", cfg)))
  expect_true(any(grepl("^list_tiles='T31UDP'", cfg)))
  expect_true(any(grepl("^mask_final_maps='True'", cfg)))
  expect_true(any(grepl("^S2_year='2024'", cfg)))
})

test_that("run_reconfort_dieback with binary_mask = FALSE disables masking", {
  skip_if_terra_write_broken()   # clustering post-process writes a TIF (runner anomaly)
  con <- local_con()
  cache <- withr::local_tempdir()
  calls <- new.env(); calls$env <- environment()
  mock_pipeline(calls)

  run_reconfort_dieback(con = con, zone_id = 1L, cache_dir = cache,
                        s2_year = 2024L, tiles = "T31UDP",
                        binary_mask = FALSE, quiet = TRUE)
  expect_true(any(grepl("^mask_final_maps='False'", calls$cfg)))
  # no mask staged
  wd <- file.path(cache, "reconfort", "run_z1_S22024")
  expect_false(file.exists(file.path(wd, "masks", RECONFORT_OSO_MASK$file)))
})

test_that("run_reconfort_dieback aborts when no continuous score is produced", {
  con <- local_con()
  cache <- withr::local_tempdir()
  calls <- new.env(); calls$env <- environment()
  mock_pipeline(calls, write_score = FALSE)

  expect_error(
    run_reconfort_dieback(con = con, zone_id = 1L, cache_dir = cache,
                          s2_year = 2024L, tiles = "T31UDP", quiet = TRUE),
    "continuous-score"
  )
})

test_that("run_reconfort_dieback aborts on a non-zero map-production exit", {
  con <- local_con()
  cache <- withr::local_tempdir()
  calls <- new.env(); calls$env <- environment()
  mock_pipeline(calls, exit = 1L)

  err <- expect_error(
    run_reconfort_dieback(con = con, zone_id = 1L, cache_dir = cache,
                          s2_year = 2024L, tiles = "T31UDP", quiet = TRUE),
    "RECONFORT map production"
  )
  # Et l'etat d'IOTA2 voyage avec l'erreur : ici, pas meme de dossier results.
  expect_match(conditionMessage(err), "chain died before writing one")
})

test_that("le verdict systemd du sous-processus python remonte dans l'erreur", {
  # Le fond du brief du 2026-09-03 : `conda run` a renvoye 1 alors que le scope
  # avait ete tue par l'OOM killer (pic 11,5 Go sous un plafond de 12 Go). Lire
  # le code de sortie, c'est nommer le worker dask mort, pas la cause.
  con <- local_con()
  cache <- withr::local_tempdir()
  calls <- new.env(); calls$env <- environment()
  mock_pipeline(calls, exit = structure(1L, systemd_result = "oom-kill"))

  err <- expect_error(
    run_reconfort_dieback(con = con, zone_id = 1L, cache_dir = cache,
                          s2_year = 2024L, tiles = "T31UDP", quiet = TRUE),
    "ran out of memory"
  )
  expect_match(conditionMessage(err), "NEMETON_MEMORY_MAX")
})

test_that(".reconfort_py_verdict lit l'attribut, et NA quand il n'y a rien", {
  expect_identical(.reconfort_py_verdict(structure(1L, systemd_result = "oom-kill")),
                   "oom-kill")
  expect_true(is.na(.reconfort_py_verdict(1L)))
  expect_true(is.na(.reconfort_py_verdict(structure(1L, systemd_result = NULL))))
})

test_that(".reconfort_iota2_diagnosis nomme les chunks manquants et le final vide", {
  # L'etat exact du run Couchey (2026-09-03) : 4 chunks demandes, seul le
  # SUBREGION_2 ecrit, `final/` vide. C'est ce que 20 h de calcul avaient
  # laisse, et qu'il a fallu reconstituer a la main.
  wd <- withr::local_tempdir()
  res <- file.path(wd, "results", "iota2_results_classif_labels-z49-S2_2025")
  dir.create(file.path(res, "classif"), recursive = TRUE)
  dir.create(file.path(res, "final"), recursive = TRUE)
  file.create(file.path(res, "classif",
                        "Classif_T31TFN_model_1_seed_0_SUBREGION_2.tif"))
  file.create(file.path(res, "IOTA2_tasks_status.txt"))

  msg <- .reconfort_iota2_diagnosis(wd, "z49", 2025L, number_of_chunks = 4L)
  expect_true(any(grepl("1 of 4 chunks", msg)))
  expect_true(any(grepl("Missing 3 chunks: 0, 1, and 3", msg)))
  expect_true(any(grepl("holds no raster", msg)))
  expect_true(any(grepl("IOTA2_tasks_status.txt", msg, fixed = TRUE)))
})

test_that(".reconfort_iota2_diagnosis reste muet plutot que faux", {
  wd <- withr::local_tempdir()
  # Pas de dossier results : une seule ligne, et surtout pas d'inventaire vide
  # presente comme un constat.
  msg <- .reconfort_iota2_diagnosis(wd, "z49", 2025L, 4L)
  expect_length(msg, 1L)
  expect_match(msg[[1]], "died before writing one")
})

test_that("le nombre de chunks suit le plafond memoire, jamais au-dessus de 240 lignes", {
  skip_if_not_installed("terra")
  # L'AOI de Couchey : 1160 x 886. A 240 lignes fixes -> 4 chunks de 221 lignes,
  # soit 256 360 px, mesures a 11,46 Go de pic sous un plafond de 12 Go. Le
  # budget en pixels doit donc decouper plus fin que la regle des lignes.
  p <- file.path(withr::local_tempdir(), "mask.tif")
  terra::writeRaster(terra::rast(nrows = 886, ncols = 1160, vals = 1), p)

  n12 <- .reconfort_chunk_count(p, memory_max = "12G")
  expect_gt(n12, 4L)
  # Un plafond plus large redecoupe moins fin...
  expect_lte(.reconfort_chunk_count(p, memory_max = "24G"), n12)
  # ...mais jamais moins que la regle historique des 240 lignes (ici 4).
  expect_gte(.reconfort_chunk_count(p, memory_max = "64G"), 4L)
  # Sans plafond lisible, on retombe exactement sur l'ancien comportement.
  expect_identical(.reconfort_chunk_count(p, memory_max = NULL), 4L)
})

test_that(".reconfort_chunk_count reste prudent quand l'emprise est inconnue", {
  expect_identical(.reconfort_chunk_count(NA_character_), 1L)
  expect_identical(.reconfort_chunk_count("nowhere.tif"), 1L)
})

test_that("run_reconfort_dieback validates con and v_model", {
  expect_error(
    run_reconfort_dieback(con = list(), zone_id = 1L, cache_dir = tempdir(),
                          tiles = "T31UDP"),
    "DBIConnection"
  )
  con <- local_con()
  expect_error(
    run_reconfort_dieback(con = con, zone_id = 1L, cache_dir = tempdir(),
                          v_model = "nope", tiles = "T31UDP"),
    "Unknown RECONFORT model"
  )
})

test_that(".reconfort_stage_s2_layout builds the year/tile view", {
  wd <- withr::local_tempdir()
  ex1 <- file.path(wd, "ex", "T31UDP"); dir.create(ex1, recursive = TRUE)
  writeLines("scene", file.path(ex1, "marker.txt"))
  root <- nemeton:::.reconfort_stage_s2_layout(wd, 2024L, "T31UDP", ex1)
  linked <- file.path(root, "2024", "T31UDP")
  expect_true(dir.exists(linked))
  expect_true(file.exists(file.path(linked, "marker.txt")))
})

test_that(".reconfort_stage_workdir copies the vendored glue", {
  wd <- withr::local_tempdir()
  glue <- nemeton:::.reconfort_glue_dir()
  nemeton:::.reconfort_stage_workdir(wd, glue)
  expect_true(file.exists(file.path(wd, "run_map_production_reconfort.py")))
  expect_true(file.exists(file.path(wd, "iota2", "external_features", "custom_index.py")))
})
