# Score continu RECONFORT (inst/python/reconfort/mask_and_compress_rasters.py),
# audit 1.0 : bornage [1, 100], no-data = toutes bandes a 0, cartes a 2 bandes.
# Lance python3 sur un petit cas synthetique ; rasterio est remplace par un
# module factice (seul numpy est requis).

skip_if_no_python_numpy <- function() {
  py <- Sys.which("python3")
  testthat::skip_if(!nzchar(py), "python3 not available")
  ok <- suppressWarnings(system2(py, c("-c", shQuote("import numpy")),
                                 stdout = FALSE, stderr = FALSE))
  testthat::skip_if(!identical(ok, 0L), "numpy not available")
  py
}

run_score_python <- function(py, cases_py) {
  glue <- .reconfort_glue_dir()
  script <- tempfile(fileext = ".py")
  on.exit(unlink(script), add = TRUE)
  writeLines(c(
    "import sys, types, json",
    # pas de __pycache__ dans le dossier du paquet
    "sys.dont_write_bytecode = True",
    "import numpy as np",
    "rio = types.ModuleType('rasterio')",
    "win = types.ModuleType('rasterio.windows')",
    "win.from_bounds = lambda *a, **k: None",
    "rio.windows = win",
    "sys.modules['rasterio'] = rio",
    "sys.modules['rasterio.windows'] = win",
    sprintf("sys.path.insert(0, %s)", encodeString(glue, quote = '"')),
    "from mask_and_compress_rasters import continuous_score_from_probas as f",
    "out = {}",
    cases_py,
    "print(json.dumps(out))"
  ), script)
  res <- system2(py, script, stdout = TRUE, stderr = TRUE)
  jsonlite::fromJSON(paste(res, collapse = ""))
}

test_that("RECONFORT continuous score is bounded and keeps valid pixels (audit 1.0)", {
  py <- skip_if_no_python_numpy()
  skip_if_not_installed("jsonlite")
  out <- run_score_python(py, c(
    # pixel 1 : tres sain (1000, 0, 0) -> score brut 1/30 ; avant : 0 = no-data
    # pixel 2 : sum_proba == 0 mais valide (500, 500, 0) -> 1001/30 = 33
    # pixel 3 : masque (0, 0, 0) -> no-data
    # pixel 4 : tres deperissant (0, 0, 1000) -> 3001/30 -> borne a 100
    "m3 = np.array([[[1000, 500, 0, 0]], [[0, 500, 0, 0]], [[0, 0, 0, 1000]]], dtype=np.int16)",
    "out['three'] = f(m3).ravel().tolist()",
    # carte a 2 classes (v3_pine) : p3 = 0, pas d'IndexError
    "m2 = np.array([[[1000, 0, 0]], [[0, 1000, 0]]], dtype=np.int16)",
    "out['two'] = f(m2).ravel().tolist()"
  ))
  expect_equal(out$three, c(1, 33, 0, 100))
  # (1001 - 1000) / 30 -> 1 ; (1001 + 1000) / 30 = 66.7 -> 66 ; masque -> 0
  expect_equal(out$two, c(1, 66, 0))
})
