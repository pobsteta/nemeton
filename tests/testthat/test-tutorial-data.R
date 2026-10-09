# Données des tutoriels 07/08 téléchargées à la demande (.tutorial_data_dir).
# Aucun accès réseau : le téléchargement est simulé (copie locale ou échec).

test_that(".tutorial_data_ref : tag pour une version stable, main en cycle dev", {
  expect_identical(nemeton:::.tutorial_data_ref("1.0.0"), "v1.0.0")
  expect_identical(nemeton:::.tutorial_data_ref("0.216.0.9000"), "main")
  # Versionnage calendaire (spec 057 § 8).
  expect_identical(nemeton:::.tutorial_data_ref("2026.10.1"), "v2026.10.1")
  expect_identical(nemeton:::.tutorial_data_ref("2026.10.1.9000"), "main")
  expect_identical(
    nemeton:::.tutorial_data_url("coregistration/plotsCoregistration.rda", "v1.0.0"),
    paste0("https://raw.githubusercontent.com/pobsteta/nemeton/v1.0.0/",
           "inst/extdata/coregistration/plotsCoregistration.rda"))
})

test_that("le manifeste couvre les deux jeux, tailles et MD5 renseignés", {
  man <- nemeton:::.tutorial_data_manifest()
  expect_setequal(unique(man$dataset), c("aba.model", "coregistration"))
  expect_true(all(startsWith(man$path, paste0(man$dataset, "/"))))
  expect_true(all(man$size > 0))
  expect_true(all(grepl("^[0-9a-f]{32}$", man$md5)))
})

test_that("le manifeste correspond aux fichiers suivis par git (source)", {
  root <- testthat::test_path("..", "..")
  skip_if_not(dir.exists(file.path(root, ".git")) ||
                file.exists(file.path(root, ".git")), "pas un dépôt git")
  skip_if(!nzchar(Sys.which("git")), "git absent")
  files <- suppressWarnings(system2(
    "git", c("-C", shQuote(root), "ls-files", "--",
             "inst/extdata/aba.model", "inst/extdata/coregistration"),
    stdout = TRUE, stderr = FALSE))
  skip_if(!length(files), "git ls-files indisponible")
  man <- nemeton:::.tutorial_data_manifest()
  expect_setequal(man$path, sub("^inst/extdata/", "", files))
  # Les tailles du manifeste sont celles des fichiers du dépôt.
  expect_equal(unname(man$size),
               unname(file.size(file.path(root, "inst/extdata", man$path))))
})

# Source locale des fichiers (checkout source / load_all) servant de faux
# serveur ; absente d'un paquet installé (exclue du build) -> skip.
local_coreg <- function() {
  d <- system.file("extdata", "coregistration", package = "nemeton")
  if (!nzchar(d)) testthat::skip("coregistration data not in this install")
  d
}

test_that("téléchargement simulé dans le cache, puis réutilisation sans réseau", {
  src <- local_coreg()
  cache <- withr::local_tempdir()
  calls <- character(0)
  local_mocked_bindings(.tutorial_download = function(url, destfile) {
    calls <<- c(calls, url)
    file.copy(file.path(src, basename(url)), destfile, overwrite = TRUE)
    invisible(0L)
  })

  d <- suppressMessages(nemeton:::.tutorial_data_dir(
    "coregistration", cache_dir = cache, ref = "v1.0.0", use_local = FALSE))
  expect_identical(d, file.path(cache, "tutorials", "v1.0.0", "coregistration"))
  expect_setequal(list.files(d), c("lasCoregistration.rda",
                                   "plotsCoregistration.rda",
                                   "treesCoregistration.rda"))
  expect_length(calls, 3L)
  expect_true(all(startsWith(calls,
    "https://raw.githubusercontent.com/pobsteta/nemeton/v1.0.0/inst/extdata/coregistration/")))
  expect_false(any(grepl("\\.part$", list.files(d))))

  # Deuxième appel : tout est en cache et conforme, aucun téléchargement.
  d2 <- nemeton:::.tutorial_data_dir("coregistration", cache_dir = cache,
                                     ref = "v1.0.0", use_local = FALSE)
  expect_identical(d2, d)
  expect_length(calls, 3L)

  # Un fichier altéré est retéléchargé, lui seul.
  writeLines("abime", file.path(d, "plotsCoregistration.rda"))
  suppressMessages(nemeton:::.tutorial_data_dir(
    "coregistration", cache_dir = cache, ref = "v1.0.0", use_local = FALSE))
  expect_length(calls, 4L)
  expect_match(calls[4], "plotsCoregistration\\.rda$")
})

test_that("hors ligne : arrêt explicite et lisible, rien de partiel en cache", {
  cache <- withr::local_tempdir()
  local_mocked_bindings(.tutorial_download = function(url, destfile) {
    stop("cannot open URL: Could not resolve host: raw.githubusercontent.com")
  })
  err <- expect_error(
    nemeton:::.tutorial_data_dir("coregistration", cache_dir = cache,
                                 ref = "v1.0.0", use_local = FALSE, quiet = TRUE),
    class = "nemeton_tutorial_data_offline")
  msg <- conditionMessage(err)
  expect_match(msg, "Cannot download the tutorial data")
  expect_match(msg, "offline")
  expect_match(msg, "raw.githubusercontent.com/pobsteta/nemeton/v1.0.0", fixed = TRUE)
  expect_length(list.files(cache, recursive = TRUE), 0L)
})

test_that("un fichier téléchargé non conforme au manifeste est rejeté", {
  cache <- withr::local_tempdir()
  local_mocked_bindings(.tutorial_download = function(url, destfile) {
    writeLines("page d'erreur HTML", destfile)
    invisible(0L)
  })
  expect_error(
    nemeton:::.tutorial_data_dir("coregistration", cache_dir = cache,
                                 ref = "v1.0.0", use_local = FALSE, quiet = TRUE),
    "does not match the manifest")
  expect_length(list.files(cache, recursive = TRUE), 0L)
})

test_that("checkout source : les données locales sont utilisées sans téléchargement", {
  src <- local_coreg()
  local_mocked_bindings(.tutorial_download = function(url, destfile) {
    stop("ne doit pas être appelé")
  })
  expect_identical(nemeton:::.tutorial_data_dir("coregistration"), src)
})
