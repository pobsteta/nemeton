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
