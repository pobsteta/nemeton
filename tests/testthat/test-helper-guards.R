# Unit tests for the test-DB isolation guard (v0.54.0).
#
# `.guard_test_db()` is pure env-var logic (no DB connection), so it is
# testable offline. It protects against the villards-wipe incidents
# (2026-05-25, 2026-05-31) where the destructive integration helper ran
# against the production database. See helper-monitoring.R.

test_that(".guard_test_db skips when NEMETON_DB_URL_TEST is unset", {
  withr::with_envvar(c(NEMETON_DB_URL_TEST = ""), {
    expect_condition(.guard_test_db(), class = "skip")
  })
})

test_that(".guard_test_db skips when test URL equals prod URL", {
  withr::with_envvar(c(
    NEMETON_DB_URL      = "postgresql://x@h/db",
    NEMETON_DB_URL_TEST = "postgresql://x@h/db"
  ), {
    expect_condition(.guard_test_db(), class = "skip")
  })
})

test_that(".guard_test_db passes when test URL differs from prod URL", {
  withr::with_envvar(c(
    NEMETON_DB_URL      = "postgresql://x@h/prod",
    NEMETON_DB_URL_TEST = "postgresql://x@h/test"
  ), {
    expect_equal(.guard_test_db(), "postgresql://x@h/test")
  })
})

test_that(".guard_test_db cannot catch test-URL-points-at-prod when prod URL is unset", {
  # This is the exact 2026-05-31 incident shape: NEMETON_DB_URL unset,
  # NEMETON_DB_URL_TEST pointing at the real DB. The URL-equality check
  # has nothing to compare against, so `.guard_test_db()` returns the
  # URL — the app-table layer in `.test_db_connect()` is what actually
  # refuses this case (covered by the integration skip behaviour).
  withr::with_envvar(c(
    NEMETON_DB_URL      = NA,   # unset
    NEMETON_DB_URL_TEST = "postgresql://x@h/nemeton"
  ), {
    expect_equal(.guard_test_db(), "postgresql://x@h/nemeton")
  })
})
