# Tests ifn_source.R — accès aux données brutes IFN (spec 040).
# Les cas réseau sont skippés hors ligne : la CI ne doit pas dépendre de
# la disponibilité du serveur de l'IGN.

test_that("argument validation happens before any network access", {
  expect_error(ifn_telecharger(), "dest_dir")
  expect_error(ifn_telecharger(c("a", "b")), "dest_dir")
  expect_error(ifn_charger(character(0)), "non-empty")
  expect_error(ifn_charger("ARBRE", visite = 3), "visite")
})

test_that("campagne is validated as a single plausible year (audit 1.0)", {
  d <- tempfile()
  expect_error(ifn_telecharger(d, campagne = c(2023, 2024)), "campagne")
  expect_error(ifn_telecharger(d, campagne = 1999), "campagne")
  expect_error(ifn_telecharger(d, campagne = 2023.5), "campagne")
  expect_error(ifn_telecharger(d, campagne = "2024"), "campagne")
  expect_error(ifn_telecharger(d, campagne = NA_real_), "campagne")
  expect_error(ifn_telecharger(d, campagne = 3000), "campagne")
})

# Fabrique un vrai zip minimal (contenu d'un export IFN) à `dest`.
.faux_zip_ifn <- function(dest) {
  src <- tempfile(); dir.create(src)
  writeLines("IDP;ESPAR\n1;02", file.path(src, "ARBRE.csv"))
  old <- setwd(src); on.exit(setwd(old))
  utils::zip(normalizePath(dest, mustWork = FALSE), "ARBRE.csv", flags = "-q")
}

test_that("a truncated download never lands under the final name (audit 1.0)", {
  skip_if(!nzchar(Sys.which("zip")), "zip utility not available")
  d <- tempfile(); dir.create(d)
  local_mocked_bindings(.ifn_download = function(url, dest) {
    # Serveur coupé à mi-transfert : quelques octets sans répertoire central.
    writeBin(as.raw(c(0x50, 0x4b, 0x03, 0x04, 0, 0)), dest)
    invisible(0L)
  })
  expect_error(ifn_telecharger(d, campagne = 2024), "integrity")
  # Ni archive définitive, ni temporaire orphelin.
  expect_length(list.files(d, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("a truncated cached archive is discarded and re-downloaded (audit 1.0)", {
  skip_if(!nzchar(Sys.which("zip")), "zip utility not available")
  d <- tempfile(); dir.create(d)
  cible <- file.path(d, basename(nemeton:::.ifn_url(2024)))
  writeBin(as.raw(1:10), cible)  # cache corrompu laissé par un run précédent
  appels <- 0L
  local_mocked_bindings(.ifn_download = function(url, dest) {
    appels <<- appels + 1L
    .faux_zip_ifn(dest)
    invisible(0L)
  })
  z <- ifn_telecharger(d, campagne = 2024)
  expect_identical(appels, 1L)
  expect_true("ARBRE.csv" %in% utils::unzip(z, list = TRUE)$Name)
  expect_identical(attr(z, "campagne"), 2024L)

  # Une archive saine est resservie sans nouveau téléchargement.
  ifn_telecharger(d, campagne = 2024)
  expect_identical(appels, 1L)
})

test_that("the download timeout is raised locally, then restored", {
  skip_if(!nzchar(Sys.which("zip")), "zip utility not available")
  d <- tempfile(); dir.create(d)
  vu <- NA
  local_mocked_bindings(.ifn_download = function(url, dest) {
    vu <<- getOption("timeout")
    .faux_zip_ifn(dest)
  })
  withr::local_options(timeout = 60)
  ifn_telecharger(d, campagne = 2024)
  expect_gte(vu, 1800)
  expect_identical(getOption("timeout"), 60)
})

test_that("the export URL follows the IGN naming scheme", {
  u <- nemeton:::.ifn_url(2024)
  expect_match(u, "export_dataifn_2005_2024\\.zip$")
  expect_match(u, "^https://inventaire-forestier\\.ign\\.fr/")
})

test_that("the latest campaign is discovered, not hard-coded", {
  skip_on_cran()
  skip_if_offline()
  # `skip_if_offline()` teste la connectivite GENERALE, pas le serveur de
  # l'IGN. Sur un runner GitHub, Internet est debout et c'est l'IGN qui ne
  # repond pas : la garde passait, la sonde echouait, et un job REQUIS
  # tombait sur une panne amont (2026-08-25, PR #430 — une PR qui ne
  # touchait que DESCRIPTION et un fichier Markdown).
  #
  # La garde porte donc sur la dependance REELLE. Ce n'est pas taire le
  # test : s'il repond, les assertions valent, et un serveur qui servirait
  # une campagne anterieure a 2024 le ferait toujours echouer — c'est
  # exactement ce pour quoi il existe.
  info <- tryCatch(ifn_campagne_disponible(), error = function(e) NULL)
  skip_if(is.null(info),
          "Serveur d'export IFN de l'IGN injoignable depuis cet environnement")
  expect_true(is.numeric(info$campagne))
  # Le point de la reimplementation : ne pas rester fige sur 2023 comme
  # FrenchNFIfindeR. Au 22/07/2026 la campagne servie est 2024.
  expect_gte(info$campagne, 2024)
  expect_equal(info$millesime, paste0("2005-", info$campagne))
})
