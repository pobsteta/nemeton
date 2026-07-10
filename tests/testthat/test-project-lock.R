# test-project-lock.R — verrou projet (brief-core-project-lock).
# L'essentiel tourne sur SQLite (en mémoire, déterministe, sans DB externe) ;
# un bloc d'intégration PostgreSQL (skip sans NEMETON_DB_URL_TEST) couvre le
# chemin FOR UPDATE et le câblage db_migrate.

# --- fabrique une base SQLite avec la table project_lock (migration 0008) ---
new_lock_db <- function(path = ":memory:") {
  skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS project_lock (
      project_id    TEXT PRIMARY KEY,
      holder_id     TEXT NOT NULL,
      holder_label  TEXT,
      acquired_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      heartbeat_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )")
  con
}

# Force le heartbeat d'un verrou dans le passé (péremption), portable.
expire_lock <- function(con, project_id, seconds = 999) {
  is_pg <- inherits(con, "PqConnection")
  sql <- if (is_pg) {
    sprintf("UPDATE project_lock SET heartbeat_at = NOW() - make_interval(secs => %d)
              WHERE project_id = $1", as.integer(seconds))
  } else {
    sprintf("UPDATE project_lock SET heartbeat_at = datetime('now', '-%d seconds')
              WHERE project_id = $1", as.integer(seconds))
  }
  DBI::dbExecute(con, sql, params = list(project_id))
}

# --- validation d'arguments (aucune DB requise au-delà d'une con SQLite) ---

test_that("project_lock functions reject bad arguments", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  expect_error(project_lock_acquire("not a con", "p", "h"), "DBIConnection")
  expect_error(project_lock_acquire(con, "", "h"), "non-empty")
  expect_error(project_lock_acquire(con, "p", ""), "non-empty")
  expect_error(project_lock_acquire(con, c("a", "b"), "h"), "single string")
  expect_error(project_lock_acquire(con, "p", "h", ttl_seconds = 0), "positive")
  expect_error(project_lock_acquire(con, "p", "h", ttl_seconds = -5), "positive")
})

# --- cycle de vie complet ---

test_that("acquire on a free project succeeds", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  r <- project_lock_acquire(con, "proj1", "alice@x", "Alice")
  expect_true(r$ok)
  expect_equal(r$holder_id, "alice@x")
  expect_equal(r$holder_label, "Alice")
  expect_false(r$stolen)
})

test_that("a second holder is refused while the lock is fresh", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  project_lock_acquire(con, "proj1", "alice@x", "Alice")
  r <- project_lock_acquire(con, "proj1", "bob@x", "Bob")
  expect_false(r$ok)
  expect_equal(r$holder_id, "alice@x")       # rapporte le détenteur courant
  expect_equal(r$holder_label, "Alice")
})

test_that("re-acquiring one's own lock is re-entrant and refreshes it", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  a <- project_lock_acquire(con, "proj1", "alice@x", "Alice")
  b <- project_lock_acquire(con, "proj1", "alice@x", "Alice")
  expect_true(b$ok)
  expect_false(b$stolen)
  # acquired_at inchangé (ré-entrance ne réinitialise que le heartbeat).
  expect_equal(as.character(a$acquired_at), as.character(b$acquired_at))
})

test_that("an expired lock can be stolen, and the steal is flagged", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  project_lock_acquire(con, "proj1", "alice@x", "Alice")
  expire_lock(con, "proj1")
  r <- project_lock_acquire(con, "proj1", "bob@x", "Bob", ttl_seconds = 120)
  expect_true(r$ok)
  expect_true(r$stolen)
  expect_equal(r$holder_id, "bob@x")
  # Bob détient bien désormais.
  expect_equal(project_lock_status(con, "proj1")$holder_id, "bob@x")
})

test_that("heartbeat refreshes only for the holder", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  project_lock_acquire(con, "proj1", "alice@x", "Alice")
  expect_true(project_lock_heartbeat(con, "proj1", "alice@x"))
  expect_false(project_lock_heartbeat(con, "proj1", "bob@x"))
  expect_false(project_lock_heartbeat(con, "absent", "alice@x"))
})

test_that("heartbeat keeps an otherwise-expiring lock alive", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  project_lock_acquire(con, "proj1", "alice@x", "Alice")
  expire_lock(con, "proj1")
  expect_true(project_lock_heartbeat(con, "proj1", "alice@x"))
  # Après heartbeat, un autre ne peut plus voler.
  expect_false(project_lock_status(con, "proj1")$stale)
  r <- project_lock_acquire(con, "proj1", "bob@x")
  expect_false(r$ok)
})

test_that("release deletes only for the holder and is idempotent", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  project_lock_acquire(con, "proj1", "alice@x", "Alice")
  expect_false(project_lock_release(con, "proj1", "bob@x"))   # non-détenteur
  expect_null(NULL)
  expect_true(project_lock_release(con, "proj1", "alice@x"))  # détenteur
  expect_false(project_lock_release(con, "proj1", "alice@x")) # déjà libéré
  expect_null(project_lock_status(con, "proj1"))              # libre
})

test_that("a project is acquirable again after release", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  project_lock_acquire(con, "proj1", "alice@x")
  project_lock_release(con, "proj1", "alice@x")
  r <- project_lock_acquire(con, "proj1", "bob@x", "Bob")
  expect_true(r$ok)
  expect_false(r$stolen)
})

test_that("status distinguishes free / fresh / expired", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  expect_null(project_lock_status(con, "proj1"))             # libre
  project_lock_acquire(con, "proj1", "alice@x", "Alice")
  s1 <- project_lock_status(con, "proj1")
  expect_false(s1$stale)                                     # tenu-frais
  expect_equal(s1$holder_label, "Alice")
  expire_lock(con, "proj1")
  s2 <- project_lock_status(con, "proj1")
  expect_true(s2$stale)                                      # tenu-périmé
})

test_that("holder_label is optional (NA when omitted)", {
  con <- new_lock_db(); withr::defer(DBI::dbDisconnect(con))
  r <- project_lock_acquire(con, "proj1", "alice@x")
  expect_true(r$ok)
  expect_true(is.na(r$holder_label))
})

# --- le verrou n'est PAS connection-local (contre le piège advisory-lock) ---

test_that("the lock is visible across separate connections", {
  skip_if_not_installed("RSQLite")
  path <- withr::local_tempfile(fileext = ".sqlite")
  con1 <- new_lock_db(path); withr::defer(DBI::dbDisconnect(con1))
  con2 <- DBI::dbConnect(RSQLite::SQLite(), path); withr::defer(DBI::dbDisconnect(con2))

  expect_true(project_lock_acquire(con1, "proj1", "alice@x", "Alice")$ok)
  # con2 est une connexion distincte : un advisory lock aurait déjà disparu.
  r <- project_lock_acquire(con2, "proj1", "bob@x", "Bob")
  expect_false(r$ok)
  expect_equal(r$holder_id, "alice@x")
  expect_equal(project_lock_status(con2, "proj1")$holder_id, "alice@x")
})

# --- intégration PostgreSQL : FOR UPDATE + db_migrate (skip sans DB) ---

test_that("project_lock works end-to-end on PostgreSQL via db_migrate", {
  with_clean_db(function(con) {
    db_migrate(con)
    # La migration 0008 a bien créé la table.
    expect_true(DBI::dbExistsTable(con, "project_lock"))

    expect_true(project_lock_acquire(con, "projX", "alice@x", "Alice")$ok)
    expect_false(project_lock_acquire(con, "projX", "bob@x")$ok)
    expect_true(project_lock_heartbeat(con, "projX", "alice@x"))

    expire_lock(con, "projX")
    st <- project_lock_acquire(con, "projX", "bob@x", "Bob")
    expect_true(st$ok && st$stolen)

    expect_true(project_lock_release(con, "projX", "bob@x"))
    expect_null(project_lock_status(con, "projX"))
  })
})

test_that("PostgreSQL exclusion holds across two connections", {
  guard <- tryCatch(.guard_test_db(), error = function(e) "skip")
  con1 <- .test_db_connect(); on.exit(db_disconnect(con1), add = TRUE)
  db_migrate(con1)
  DBI::dbExecute(con1, "DELETE FROM project_lock")
  con2 <- .test_db_connect(); on.exit(db_disconnect(con2), add = TRUE)

  expect_true(project_lock_acquire(con1, "projY", "alice@x")$ok)
  expect_false(project_lock_acquire(con2, "projY", "bob@x")$ok)
  project_lock_release(con1, "projY", "alice@x")
})
