# Helpers shared by the E6 monitoring test files.

skip_if_no_timescaledb <- function() {
  url <- Sys.getenv("NEMETON_DB_URL_TEST", Sys.getenv("NEMETON_DB_URL", ""))
  if (!nzchar(url)) {
    testthat::skip("NEMETON_DB_URL_TEST not set — TimescaleDB integration test skipped.")
  }
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("RPostgres", quietly = TRUE)) {
    testthat::skip("DBI / RPostgres not installed.")
  }
  con <- tryCatch(db_connect(url), error = function(e) NULL)
  if (is.null(con)) {
    testthat::skip(sprintf("Cannot connect to TimescaleDB at %s.", url))
  }
  db_disconnect(con)
}


# Open a fresh connection for an integration test, drop the four tables
# (and schema_migration) at the *start* and end of each test so the test
# is idempotent and doesn't leak state into other tests.
#
# Safety guard-rail (v0.47.2, incident 2026-05-25) : refuse to run when
# `NEMETON_DB_URL_TEST` resolves to the same URL as `NEMETON_DB_URL`
# unless the caller explicitly opts in with
# `NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE`. The `reset_schema()`
# below DROPs the entire monitoring schema; if the test DB == prod DB,
# every integration test wipes the user's villards / plots /
# obs_pixel / alert rows. The incident burned 17 050 obs_pixel rows.
with_clean_db <- function(code) {
  url_test <- Sys.getenv("NEMETON_DB_URL_TEST", "")
  url_main <- Sys.getenv("NEMETON_DB_URL",      "")
  url      <- if (nzchar(url_test)) url_test else url_main

  # Hard guard : refuse when the test URL points to the production
  # URL (either by being equal, or by `NEMETON_DB_URL_TEST` being
  # unset so the helper falls back to `NEMETON_DB_URL`).
  same_url      <- nzchar(url_main) && identical(url_test, url_main)
  fellback_main <- !nzchar(url_test) && nzchar(url_main)
  allow_destr   <- identical(toupper(Sys.getenv("NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE", "")),
                             "TRUE")
  if ((same_url || fellback_main) && !allow_destr) {
    testthat::skip(paste0(
      "with_clean_db() refused to run: NEMETON_DB_URL_TEST is not set ",
      "or equals NEMETON_DB_URL. Each integration test DROPs the ",
      "monitoring schema, which would wipe production data. ",
      "Point NEMETON_DB_URL_TEST at a *separate* test DB, ",
      "or set NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE to override ",
      "(in CI on an empty DB, for example)."
    ))
  }

  con <- db_connect(url)

  # Defence in depth (incidents 2026-05-25 AND 2026-05-31): the URL
  # comparison above CANNOT catch the case where NEMETON_DB_URL is unset
  # and NEMETON_DB_URL_TEST happens to point at the real application
  # database. reset_schema() DROPs the monitoring tables, so additionally
  # refuse to run against any DB that carries the nemetonshiny
  # application's own tables (projects / users / parcels) — a clean
  # throwaway test DB has none of these (the integration tests only ever
  # create the monitoring schema via db_migrate()). Only
  # NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE overrides (CI on a
  # disposable DB).
  app_tables <- tryCatch(
    intersect(c("projects", "users", "parcels"), DBI::dbListTables(con)),
    error = function(e) character(0))
  if (length(app_tables) && !allow_destr) {
    db_disconnect(con)
    testthat::skip(paste0(
      "with_clean_db() refused to run: the target DB carries application ",
      "table(s) {", paste(app_tables, collapse = ", "), "} — it looks ",
      "like the real Nemeton database, not a throwaway test DB. Point ",
      "NEMETON_DB_URL_TEST at a separate empty DB (e.g. 'nemeton_test'), ",
      "or set NEMETON_DB_URL_TEST_ALLOW_DESTRUCTIVE=TRUE only if this DB ",
      "is genuinely disposable."
    ))
  }

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
