# Helpers shared by the E6 monitoring test files.

# ---- Test DB isolation (v0.54.0) -------------------------------------
#
# The integration tests DROP-CASCADE the monitoring schema
# (`reset_schema()` in `with_clean_db()`), which has TWICE destroyed real
# user data when run against a production DB (incidents 2026-05-25 and
# 2026-05-31 — the villards zone/plots/obs_pixel wipe). ALL integration
# DB access therefore goes through `.guard_test_db()` + `.test_db_connect()`.
#
# Layered protection:
#   1. `NEMETON_DB_URL_TEST` MUST be set, else the integration tests skip.
#   2. It must NOT equal `NEMETON_DB_URL` (copy-paste-the-prod-URL guard).
#   3. The target DB must NOT carry the nemetonshiny application's own
#      tables (`projects` / `users` / `parcels`). This is the layer that
#      actually caught the real incident: TEST pointed at the prod DB
#      while `NEMETON_DB_URL` was unset, so the URL equality check (2)
#      could not fire. A clean throwaway test DB has none of these tables
#      (integration tests only ever create the monitoring schema via
#      `db_migrate()`).
# Override every layer only with `NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE`.

# Validate the test-DB env contract. Returns the test URL (invisibly) or
# signals a testthat `skip`. Pure env logic — opens NO connection, so it
# is unit-testable without a database (see test-helper-guards.R).
.guard_test_db <- function() {
  test_url <- Sys.getenv("NEMETON_DB_URL_TEST", "")
  if (!nzchar(test_url)) {
    testthat::skip(paste(
      "Integration tests skipped: set NEMETON_DB_URL_TEST to a DEDICATED",
      "test database (a separate DB from NEMETON_DB_URL)."
    ))
  }
  prod_url <- Sys.getenv("NEMETON_DB_URL", "")
  if (nzchar(prod_url) && identical(test_url, prod_url)) {
    testthat::skip(paste(
      "Integration tests skipped: NEMETON_DB_URL_TEST equals",
      "NEMETON_DB_URL. Refusing destructive ops on the production DB."
    ))
  }
  invisible(test_url)
}

# Open a GUARDED connection to the dedicated test DB. Every integration
# call site must use this instead of `db_connect(Sys.getenv(...))`.
.test_db_connect <- function(read_only = FALSE) {
  url <- .guard_test_db()
  con <- db_connect(url, read_only = read_only)

  # Layer 3 (see header): a "distinct" URL can still point at a DB that
  # holds real data. Refuse any DB carrying the application's own tables.
  allow_destr <- identical(
    toupper(Sys.getenv("NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE", "")), "TRUE")
  app_tables <- tryCatch(
    intersect(c("projects", "users", "parcels"), DBI::dbListTables(con)),
    error = function(e) character(0))
  if (length(app_tables) && !allow_destr) {
    db_disconnect(con)
    testthat::skip(paste0(
      ".test_db_connect() refused: the target DB carries application ",
      "table(s) {", paste(app_tables, collapse = ", "), "} — it looks ",
      "like the real Nemeton database, not a throwaway test DB. Point ",
      "NEMETON_DB_URL_TEST at a separate empty DB (e.g. 'nemeton_test'), ",
      "or set NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE only if this DB ",
      "is genuinely disposable."
    ))
  }
  con
}

skip_if_no_timescaledb <- function() {
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("RPostgres", quietly = TRUE)) {
    testthat::skip("DBI / RPostgres not installed.")
  }
  # `.test_db_connect()` signals a skip (unset / == prod / app-DB) or
  # errors if the server is unreachable — either way the integration
  # test is skipped, never run against an unguarded DB.
  con <- tryCatch(
    .test_db_connect(),
    error = function(e)
      testthat::skip(sprintf("Cannot connect to test DB: %s",
                             conditionMessage(e))))
  db_disconnect(con)
}


# Open a fresh GUARDED connection for an integration test, dropping the
# monitoring tables (and schema_migration) at the *start* and end of each
# test so the test is idempotent and doesn't leak state into other tests.
# The DROP block is harmless because `.test_db_connect()` guarantees the
# connection targets a dedicated, app-data-free test DB.
with_clean_db <- function(code) {
  con <- .test_db_connect()

  reset_schema <- function() {
    DBI::dbExecute(con, "DROP TABLE IF EXISTS knowledge_chunk CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS knowledge_document CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS alert CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS obs_pixel CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS plot CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS monitoring_zone CASCADE")
    DBI::dbExecute(con, "DROP TABLE IF EXISTS schema_migration CASCADE")
  }
  reset_schema()
  on.exit({
    # Teardown is not an assertion target. RPostgres can emit a benign
    # "Closing open result set, cancelling previous query" warning when
    # the connection is dropped with an un-finalised result still open;
    # mute teardown warnings so that noise doesn't leak into the report.
    suppressWarnings({
      tryCatch(reset_schema(), error = function(e) NULL)
      db_disconnect(con)
    })
  }, add = TRUE)
  force(code)(con)
}


# Build a tiny scenes tibble compatible with what stac_search_s2()
# returns. Used to mock the STAC layer in monitoring tests.
fake_scenes <- function(dates = as.Date(c("2025-06-10", "2025-06-25", "2025-07-10")),
                        cloud = c(5, 8, 3),
                        source = "cdse") {
  data.frame(
    scene_id  = sprintf("S2A_FAKE_%s", format(dates, "%Y%m%d")),
    obs_date  = dates,
    cloud_pct = cloud,
    href_B04  = "fake://B04.tif",
    href_B08  = "fake://B08.tif",
    href_B12  = "fake://B12.tif",
    source    = rep(source, length(dates)),
    stringsAsFactors = FALSE
  )
}
