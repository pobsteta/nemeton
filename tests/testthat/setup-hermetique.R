# La suite ne doit rien écrire dans le cache réel de l'utilisateur
# (~/.local/share/nemeton/cache : TWI, vent NASA POWER…). Audit 1.0, v0.211.0.
local({
  d <- file.path(tempdir(), "nemeton-test-cache")
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
  withr::local_envvar(NEMETON_CACHE_DIR = d, .local_envir = testthat::teardown_env())
})
