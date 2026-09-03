test_that(".progress_file_writer writes the app's two files", {
  skip_if_not_installed("jsonlite")
  withr::with_tempdir({
    p <- file.path(getwd(), "progress.json")
    w <- .progress_file_writer(p)
    w(list(current = "fordead:fit", pct = 10))
    w(list(current = "fordead:predict", pct = 90))

    # `.json` holds only the LAST event...
    last <- jsonlite::fromJSON(p)
    expect_equal(last$current, "fordead:predict")
    # ...`.ndjson` holds them all, in order.
    lines <- readLines("progress.ndjson")
    expect_length(lines, 2L)
    expect_equal(jsonlite::fromJSON(lines[[1L]])$current, "fordead:fit")
    # And no `.tmp` is left behind by the atomic write.
    expect_false(file.exists(paste0(p, ".tmp")))
  })
})

test_that(".progress_file_writer returns NULL without a path", {
  expect_null(.progress_file_writer(NULL))
  expect_null(.progress_file_writer(""))
})

test_that(".progress_ndjson_path derives the sibling path", {
  expect_equal(.progress_ndjson_path("/a/b.json"), "/a/b.ndjson")
  expect_equal(.progress_ndjson_path("/a/b"), "/a/b.ndjson")
})

test_that(".progress_replay feeds only the new lines to the callback", {
  skip_if_not_installed("jsonlite")
  withr::with_tempdir({
    seen <- list()
    cb <- function(ev) seen[[length(seen) + 1L]] <<- ev

    writeLines(c('{"current":"a"}', '{"current":"b"}'), "p.ndjson")
    n <- .progress_replay("p.ndjson", 0L, cb)
    expect_equal(n, 2L)
    expect_equal(vapply(seen, function(e) e$current, ""), c("a", "b"))

    # A second pass from the same offset replays nothing.
    expect_equal(.progress_replay("p.ndjson", n, cb), 2L)
    expect_length(seen, 2L)

    # A new line appended is replayed exactly once.
    cat('{"current":"c"}\n', file = "p.ndjson", append = TRUE)
    expect_equal(.progress_replay("p.ndjson", n, cb), 3L)
    expect_length(seen, 3L)
  })
})

test_that(".progress_replay tolerates a missing file, no callback, a bad line", {
  expect_equal(.progress_replay("nope.ndjson", 0L, function(e) stop("!")), 0L)
  withr::with_tempdir({
    writeLines(c("{ not json", '{"current":"ok"}'), "p.ndjson")
    expect_equal(.progress_replay("p.ndjson", 0L, NULL), 0L)     # no callback
    seen <- character()
    n <- .progress_replay("p.ndjson", 0L, function(e) seen <<- c(seen, e$current))
    expect_equal(n, 2L)      # both lines consumed...
    expect_equal(seen, "ok") # ...but only the parseable one delivered
  })
})

test_that("run_memory_capped rejects a bad call before spawning anything", {
  expect_error(run_memory_capped(fun = c("a", "b")), "must be the name")
  expect_error(run_memory_capped("massif_demo_units", args = list(1)), "named list")
  expect_error(run_memory_capped("x", package = c("a", "b")), "single package")
  expect_error(run_memory_capped("x", options = list(1)), "named list or NULL")
})

test_that("run_memory_capped runs a function from another package and seeds options", {
  skip_on_cran()
  skip_if_not_installed("processx")
  skip_if_not_installed("jsonlite")

  # package= : résout et exécute un export d'un AUTRE package dans l'enfant capé.
  # memory_max = FALSE : pas de cgroup requis, le test tourne partout (CI incluse).
  out <- suppressWarnings(run_memory_capped(
    "toJSON", args = list(x = list(a = 1L)), package = "jsonlite",
    memory_max = FALSE, quiet = TRUE))
  expect_equal(as.character(out), "{\"a\":[1]}")

  # options= : posée dans l'enfant AVANT l'appel ; le parent ne l'a pas.
  val <- suppressWarnings(run_memory_capped(
    "getOption", args = list(x = "nmt.isolate.test"), package = "base",
    options = list(nmt.isolate.test = "child-only"),
    memory_max = FALSE, quiet = TRUE))
  expect_equal(val, "child-only")
  expect_null(getOption("nmt.isolate.test"))
})

test_that("run_memory_capped runs the function in a child and returns its value", {
  skip_on_cran()
  skip_if_not_installed("processx")
  skip_if(is.null(.reconfort_systemd_run()), "systemd-run unavailable")

  # `ndp_table()` is exported, cheap, and needs neither DB nor progress — it
  # exercises the round trip (spawn, cgroup, RDS in, RDS out) and nothing else.
  res <- run_memory_capped("ndp_table", quiet = TRUE)
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), nrow(ndp_table()))
})

test_that("run_memory_capped surfaces a child failure as a catchable error", {
  skip_on_cran()
  skip_if_not_installed("processx")

  expect_error(
    suppressWarnings(run_memory_capped("no_such_nemeton_function", quiet = TRUE)),
    "failed in its capped child process"
  )
})

test_that("the memory ceiling kills the child, and only the child", {
  skip_on_cran()
  skip_if_not_installed("processx")
  systemd <- .reconfort_systemd_run()
  skip_if(is.null(systemd), "systemd-run unavailable")

  # The crux of this file, tested on the mechanism itself rather than through a
  # pipeline: a child that blows past its ceiling must be SIGKILLed by its own
  # cgroup (128 + 9 = 137) while this session carries on. No exported nemeton
  # function allocates on demand, hence the bare allocator below.
  #
  # It must WRITE the memory, not merely ask for it: `numeric(3e8)` is calloc'd,
  # i.e. mmap'd onto the shared zero page, and pages never written are never
  # faulted in — the cgroup sees ~0 and happily lets it exit 0. `runif` fills
  # them, so the 2.4 GB is real and the 64 MB ceiling bites at once.
  cmd <- .reconfort_cap_memory(
    file.path(R.home("bin"), "Rscript"),
    c("-e", "x <- runif(3e8); sum(x)"),   # ~2.4 GB written, ceiling is 64 MB
    memory_max = "64M", systemd_run = systemd
  )
  px <- processx::process$new(cmd$command, cmd$args, stdout = NULL, stderr = NULL)
  px$wait(timeout = 60000L)
  if (px$is_alive()) {
    px$kill()
    skip("child did not settle within 60 s")
  }
  # SIGKILL: -9 from processx, 137 (128 + 9) from a shell.
  expect_true(as.integer(px$get_exit_status()) %in% c(-9L, 137L))
  # And we are still here to assert it — which is the whole point.
})

test_that("the child's progress is replayed into the parent's callback", {
  skip_on_cran()
  skip_if_not_installed("processx")
  skip_if(is.null(.reconfort_systemd_run()), "systemd-run unavailable")

  # A callback cannot cross a process boundary, but its side effects are what
  # the app relies on (it pushes an ntfy notification per phase). So: child
  # writes events to disk, parent tails and replays them. Verify end to end.
  withr::with_tempdir({
    seen <- list()
    res <- run_memory_capped(
      "ndp_table",
      progress_path     = file.path(getwd(), "progress.json"),
      progress_callback = function(ev) seen[[length(seen) + 1L]] <<- ev,
      quiet = TRUE
    )
    expect_s3_class(res, "data.frame")
    # `ndp_table()` takes no `progress_callback`, so the child must NOT inject
    # one (that would be an "unused argument" error mid-run) — hence no events,
    # and a result that still comes back intact.
    expect_length(seen, 0L)
  })
})

# --- log_path : la sortie de l'enfant, gardée ---------------------------
# Brief `nemetonshiny/specs/BRIEF-nemeton-trace-enfant-plafonne.md` (2026-09-03).
# Sous un worker `future`, le parent a `OUT=/dev/null` : `""` (heriter) envoie
# donc le traceback de l'enfant dans le vide. Apres 20 h de calcul, il ne
# restait aucun message. `log_path` capture au lieu d'heriter.

test_that("run_memory_capped refuse un log_path qui n'en est pas un", {
  expect_error(run_memory_capped("x", log_path = c("a", "b")), "single non-empty path")
  expect_error(run_memory_capped("x", log_path = ""), "single non-empty path")
})

test_that("log_path garde la sortie de l'enfant, succes compris", {
  skip_on_cran()
  skip_if_not_installed("processx")

  withr::with_tempdir({
    log <- file.path(getwd(), "sub", "child.log")   # le dossier n'existe pas
    res <- suppressWarnings(run_memory_capped(
      "print", args = list(x = "HELLO-FROM-CHILD"), package = "base",
      memory_max = FALSE, log_path = log
    ))
    expect_true(file.exists(log))
    expect_match(paste(readLines(log), collapse = "\n"), "HELLO-FROM-CHILD")
  })
})

test_that("l'echec cite le fichier ET la derniere ligne de l'enfant", {
  skip_on_cran()
  skip_if_not_installed("processx")

  withr::with_tempdir({
    log <- file.path(getwd(), "child.log")
    err <- tryCatch(
      suppressWarnings(run_memory_capped(
        "log", args = list(x = "BOOM-XYZ"), package = "base",
        memory_max = FALSE, log_path = log
      )),
      error = function(e) e
    )
    expect_s3_class(err, "error")
    msg <- conditionMessage(err)
    expect_match(msg, "child.log", fixed = TRUE)   # ou regarder
    # `log("BOOM-XYZ")` : l'erreur R de l'enfant part sur stderr, donc c'est la
    # fusion 2>&1 qu'on lit ici autant que la capture.
    expect_match(msg, "non-numeric argument")      # et ce qu'on y aurait lu
  })
})
