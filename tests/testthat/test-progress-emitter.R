# test-progress-emitter.R — .make_progress_emitter()
#
# Le rapport de progression ne doit jamais tuer le run qu'il rapporte.
# Contexte : ingestion Couchey du 2026-08-30, 13 h 40, scenes cachees et
# `ingest_run.json` a `done` — et une erreur par-dessus, levee par le
# callback de l'app sur un payload de fin de run (v0.193.0).

test_that("a callback that throws never propagates, and warns once", {
  n_calls <- 0L
  emit <- nemeton:::.make_progress_emitter(function(payload) {
    n_calls <<- n_calls + 1L
    stop("boom")
  })

  # Premier echec : avertissement, pas d'erreur.
  expect_warning(emit(list(current = "s2:complete")), "Progress callback failed")
  # Les suivants restent silencieux — un callback casse l'est a chaque
  # appel, et l'inondation enterrerait le run.
  expect_silent(emit(list(current = "fast_prewarm:NDVI_count")))
  expect_silent(emit(list(current = "fast_prewarm:NBR_rolling")))
  expect_identical(n_calls, 3L)   # le callback reste appele
})

test_that("a payload without `current` still warns cleanly", {
  emit <- nemeton:::.make_progress_emitter(function(payload) stop("boom"))
  expect_warning(emit(list(index = "NDMI", mode = "trend")),
                 "Progress callback failed")
})

test_that("a working callback is passed through untouched", {
  seen <- list()
  emit <- nemeton:::.make_progress_emitter(function(payload) {
    seen[[length(seen) + 1L]] <<- payload
    "valeur ignoree"
  })
  expect_silent(emit(list(current = "s2:scene", completed = 1L)))
  expect_length(seen, 1L)
  expect_identical(seen[[1]]$current, "s2:scene")
})

test_that("no callback is a no-op emitter", {
  emit <- nemeton:::.make_progress_emitter(NULL)
  expect_null(emit(list(current = "s2:scene")))
  expect_silent(emit(list(current = "s2:scene")))
})
