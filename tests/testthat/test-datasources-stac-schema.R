# Garde-fou de schéma sur les champs STAC des sources de données.
#
# Contexte : le 2026-08-16, le cache `cache/layers/sufosat/` des projets restait
# vide et T3 (coupes rases) rendait NA en silence. Le produit était pourtant en
# ligne. `resolve_theia_assets()` et `theia_signed_href()` lisent
# `src$access$stac_collection` ; or l'entrée `sufosat` de FR.json déclarait ses
# champs STAC à la RACINE de l'entrée — seule des dix sources Theia à le faire.
# Résultat : « Datasource "sufosat" has no confirmed STAC collection », attrapé
# par le `tryCatch` de l'app, donc aucun message côté utilisateur.
#
# Une clé mal placée ne doit plus se manifester par un cache vide en production,
# mais par un test rouge ici.

stac_fields <- c("stac_collection", "stac_collection_status", "stac_api_service")

datasource_files <- function() {
  dir(system.file("datasources", package = "nemeton"),
      pattern = "\\.json$", full.names = TRUE)
}

test_that("no datasource declares its STAC fields outside access", {
  skip_if_not_installed("jsonlite")
  files <- datasource_files()
  expect_gt(length(files), 0)

  misplaced <- character(0)
  for (f in files) {
    js <- jsonlite::fromJSON(f, simplifyVector = FALSE)
    for (key in names(js$datasets %||% list())) {
      entry <- js$datasets[[key]]
      if (!is.list(entry)) next
      at_root <- intersect(names(entry), stac_fields)
      if (length(at_root)) {
        misplaced <- c(misplaced, sprintf("%s/%s: %s",
                                          basename(f), key,
                                          paste(at_root, collapse = ", ")))
      }
    }
  }
  expect_equal(misplaced, character(0))
})

test_that("every declared STAC collection is reachable where the resolver reads it", {
  skip_if_not_installed("jsonlite")
  for (f in datasource_files()) {
    js <- jsonlite::fromJSON(f, simplifyVector = FALSE)
    for (key in names(js$datasets %||% list())) {
      entry <- js$datasets[[key]]
      if (!is.list(entry) || is.null(entry$access$stac_collection)) next
      # Le statut n'est pas obligatoire, mais s'il est là il vit au même endroit
      # que la collection : c'est le couple que lit le résolveur.
      expect_type(entry$access$stac_collection, "character")
    }
  }
})

test_that("sufosat exposes the collection T3 needs", {
  src <- get_data_source("sufosat", "FR")
  expect_false(is.null(src))
  expect_identical(src$access$stac_collection, "sufosat")
  expect_identical(src$access$stac_collection_status, "confirmed")
  # `resolve_theia_assets()` refuse tout ce qui contient « to confirm » : la
  # collection doit être nommée, pas annoncée.
  expect_false(grepl("to confirm", src$access$stac_collection, ignore.case = TRUE))
})
