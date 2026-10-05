# La suite ne doit rien écrire dans le cache réel de l'utilisateur
# (~/.local/share/nemeton/cache : TWI, vent NASA POWER…). Audit 1.0, v0.211.0.
local({
  d <- file.path(tempdir(), "nemeton-test-cache")
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
  withr::local_envvar(NEMETON_CACHE_DIR = d, .local_envir = testthat::teardown_env())
})

# Ni télécharger d'interpréteur : sans Python configuré, reticulate >= 1.41
# crée un venv éphémère via uv (CPython ~160 Mo). On le lui interdit ; un venv
# explicite (use_virtualenv) reste utilisable. Audit 1.0.
withr::local_envvar(
  RETICULATE_USE_MANAGED_VENV = "no",
  .local_envir = testthat::teardown_env()
)
