# Inventaire vidéo Groma (spec 061) : GeoPackage d'exemple du dépôt groma,
# création du projet de terrain, validation, import et client du serveur.
iv_fixture <- function(...) {
  normalizePath(testthat::test_path("fixtures", "inventaire_video", ...), mustWork = TRUE)
}

test_that("le GeoPackage d'exemple passe la chaîne de données terrain", {
  g <- import_qgis_gpkg(iv_fixture("inventaire_video.gpkg"))
  expect_true(all(c("wgt", "ip", "stratum", "strat_height", "rayon_m", "seuil_diam_cm",
                    "unite_azimut", "declinaison_deg", "convergence_deg", "etat_traitement")
                  %in% names(g$placettes)))
  expect_equal(g$placettes$wgt, c(24.6, 24.6))
  expect_equal(unname(sf::st_coordinates(g$placettes)[1, ]), c(925000, 6700000))

  arbres <- g$arbres[g$arbres$etat_detection != "faux_positif" | is.na(g$arbres$etat_detection), ]
  arbres$espece <- nemeton:::.iv_espece_depuis_essence(arbres$essence_arbre)
  expect_true(all(arbres$espece[!is.na(arbres$essence_arbre)] %in%
                    list_species_classes("BFC")$code))
  v <- validate_field_data(g$placettes, arbres)
  expect_true(v$ok)
  agg <- aggregate_plot_metrics(g$placettes, arbres, plot_radius = 20)
  expect_equal(agg$field_n_trees[agg$plot_id == "P001"], sum(arbres$plot_id == "P001"))
  expect_equal(agg$field_n_trees[agg$plot_id == "P002"], 0L)
})

test_that("schema_inventaire_video lit le schéma partagé", {
  s <- schema_inventaire_video()
  expect_setequal(names(s), c("placettes", "centres_mesures", "cibles", "arbres",
                              "detections", "houppiers"))
  for (couche in c("placettes", "arbres", "detections")) {
    expect_false(attr(s[[couche]], "index_spatial"))
  }
  arbres <- schema_inventaire_video("arbres")
  noms <- vapply(arbres, `[[`, character(1), "name")
  ess <- arbres[[match("essence_arbre", noms)]]
  expect_equal(ess$qgis_widget, "ValueMap")
  expect_equal(unname(ess$labels["hetre"]), "H\u00eatre")
  expect_equal(arbres[[match("uuid", noms)]]$qgis_widget, "Hidden")
  expect_true(arbres[[match("espece", noms)]]$readonly)
  expect_equal(arbres[[match("dbh_cm", noms)]]$max, 1000)
  expect_true(all(vapply(schema_inventaire_video("detections"), `[[`, logical(1), "readonly")))
})

test_that("valider_inventaire_video signale les gros diamètres et les domaines", {
  v <- valider_inventaire_video(iv_fixture("inventaire_video.gpkg"))
  expect_true(v$ok)
  g <- nemeton:::.iv_lire(iv_fixture("inventaire_video.gpkg"))
  g$arbres$dbh_cm[1] <- 250
  g$arbres$methode[2] <- "laser"
  g$arbres$uuid[3] <- g$arbres$uuid[4]
  v <- valider_inventaire_video(g)
  expect_false(v$ok)
  expect_true(any(grepl("alert threshold", v$warnings$issue)))
  expect_true("methode" %in% v$errors$field)
  expect_true(any(v$errors$issue == "Duplicate uuid."))
  # Colonnes de plan comparées au plan d'origine.
  plan <- g$placettes
  plan$wgt[1] <- 99
  v <- valider_inventaire_video(iv_fixture("inventaire_video.gpkg"), plan = plan)
  expect_true(any(v$errors$issue == "Sampling-design column modified."))
})

test_that("importer_inventaire_video rapproche, agrège, marque et fusionne", {
  gpkg_iv <- iv_fixture("inventaire_video.gpkg")
  gpkg_def <- iv_fixture("P001_definitif.gpkg")
  withr::with_tempdir({
    fd <- "field_data.gpkg"
    # Inventaire classique existant sur P001.
    classique <- sf::st_sf(plot_id = "P001", geometry = sf::st_sfc(sf::st_point(c(925000, 6700000)),
                                                                   crs = 2154))
    sf::st_write(classique, fd, layer = "placettes", quiet = TRUE)
    res <- suppressWarnings(importer_inventaire_video(
      gpkg_iv, resultats = gpkg_def,
      field_data_gpkg = fd))
    expect_true(all(res$placettes$etat_traitement[res$placettes$plot_id == "P001"] == "definitif"))
    a <- res$arbres[res$arbres$plot_id == "P001", ]
    expect_false(any(a$etat_detection == "faux_positif", na.rm = TRUE))
    expect_true(all(a$espece[!is.na(a$essence_arbre)] %in% list_species_classes("BFC")$code))
    expect_false(anyDuplicated(a$tree_id) > 0)
    # Aucun attribut terrain perdu sur les arbres provisoires.
    g <- import_qgis_gpkg(gpkg_iv)
    prov <- g$arbres[g$arbres$plot_id == "P001" & g$arbres$etat_detection != "faux_positif", ]
    expect_true(all(prov$uuid %in% a$uuid))
    m <- match(prov$uuid, a$uuid)
    expect_identical(a$essence_arbre[m], prov$essence_arbre)
    expect_identical(a$notes[m], prov$notes)
    expect_equal(detect_ndp(res$agregats)$sources[detect_ndp(res$agregats)$sources ==
                                                     "inventaire_video"], "inventaire_video")
    expect_equal(attr(res$agregats, "field_data_source"), "inventaire_video")
    # Fusion : P001 classique reste principal, la vidéo est rangée à côté.
    p <- sf::st_read(fd, layer = "placettes", quiet = TRUE)
    expect_setequal(p$plot_id, c("P001", "P002"))
    expect_equal(p$source[p$plot_id == "P001"], "inventaire_terrain")
    alt <- sf::st_read(fd, layer = "placettes_alternatives", quiet = TRUE)
    expect_equal(alt$plot_id, "P001")
    expect_equal(alt$source, "inventaire_video")
  })
})

test_that("creer_projet_inventaire_video produit un GeoPackage utilisable par Groma", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("lidR")
  skip_if_terra_write_broken()
  withr::with_tempdir({
    pl <- sf::st_sf(plot_id = c("P1", "P2"), wgt = c(10, 10), stratum = "s1",
                    geometry = sf::st_sfc(sf::st_point(c(925000, 6700000)),
                                          sf::st_point(c(925200, 6700000)), crs = 2154))
    ext <- terra::ext(924950, 925250, 6699950, 6700050)
    mnt <- terra::rast(ext, resolution = 1, crs = "EPSG:2154")
    xy <- terra::xyFromCell(mnt, seq_len(terra::ncell(mnt)))
    terra::values(mnt) <- 300 + 0.1 * (xy[, 2] - 6699950)   # pente de 10 % vers le sud
    mnh <- terra::rast(ext, resolution = 0.5, crs = "EPSG:2154")
    xy <- terra::xyFromCell(mnh, seq_len(terra::ncell(mnh)))
    h <- 25 * exp(-((xy[, 1] %% 8 - 4)^2 + (xy[, 2] %% 8 - 4)^2) / 6)
    terra::values(mnh) <- h
    qgz <- suppressWarnings(creer_projet_inventaire_video(
      pl, dem = mnt, chm = mnh, declinaison_deg = 2.4, output_dir = "sortie"))
    expect_true(file.exists(qgz))
    contenu <- utils::unzip(qgz, list = TRUE)$Name
    expect_true(all(c("inventaire_video.qgs", "inventaire_video.gpkg",
                      "rasters/P1_mnt.tif", "rasters/P1_mnh.tif") %in% contenu))
    utils::unzip(qgz, exdir = "x")
    gpkg <- file.path("x", "inventaire_video.gpkg")
    p <- sf::st_read(gpkg, layer = "placettes", quiet = TRUE)
    expect_equal(p$wgt, c(10, 10))
    expect_equal(p$etat_traitement, c("a_faire", "a_faire"))
    expect_equal(p$exposition[1], "S")
    expect_equal(p$pente_pct[1], 10, tolerance = 0.01)
    expect_true(p$convergence_deg[1] > 2 && p$convergence_deg[1] < 2.3)
    expect_gt(nrow(sf::st_read(gpkg, layer = "houppiers", quiet = TRUE)), 0)
    r <- terra::rast(file.path("x", "rasters", "P1_mnh.tif"))
    expect_equal(terra::res(r), c(0.5, 0.5))
    expect_equal(terra::datatype(r), "FLT4S")

    con <- DBI::dbConnect(RSQLite::SQLite(), gpkg)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    trg <- DBI::dbGetQuery(con, "SELECT name FROM sqlite_master WHERE type = 'trigger'")$name
    expect_true(all(c("trg_detections_insert", "trg_detections_update") %in% trg))
    # Aucun déclencheur R*Tree sur les couches que Groma met à jour.
    expect_false(any(grepl("^rtree_(placettes|arbres|detections)_", trg)))
    # Connexion sans fonction spatiale : insertion puis mise à jour.
    DBI::dbExecute(con, "INSERT INTO detections (uuid, plot_id, num_provisoire, dbh_cm, h_m,
                         h_source, etat_detection, methode)
                         VALUES ('u1', 'P1', '1', 32.5, 24, 'mnh', 'provisoire', 'embarque')")
    a <- DBI::dbGetQuery(con, "SELECT * FROM arbres")
    expect_equal(a$uuid, "u1")
    expect_equal(a$statut, "vivant")
    DBI::dbExecute(con, "UPDATE arbres SET essence_arbre = 'hetre' WHERE uuid = 'u1'")
    DBI::dbExecute(con, "UPDATE detections SET dbh_cm = 33 WHERE uuid = 'u1'")
    DBI::dbExecute(con, "UPDATE placettes SET etat_traitement = 'provisoire' WHERE plot_id = 'P1'")
    a <- DBI::dbGetQuery(con, "SELECT * FROM arbres")
    expect_equal(a$dbh_cm, 33)
    expect_equal(a$essence_arbre, "hetre")

    qgs <- paste(readLines(file.path("x", "inventaire_video.qgs"), warn = FALSE), collapse = "")
    expect_match(qgs, "categorizedSymbol")
    expect_match(qgs, "labelsEnabled=\"1\"")
    expect_match(qgs, "name=\"H\u00eatre\" value=\"hetre\"", fixed = TRUE)
    expect_match(qgs, "./rasters/P1_mnh.tif", fixed = TRUE)
    expect_match(qgs, "<field name=\"espece\" editable=\"0\"/>", fixed = TRUE)
  })
})

test_that("creer_projet_inventaire_video refuse un nom de projet dangereux", {
  pl <- sf::st_sf(plot_id = "P1", geometry = sf::st_sfc(sf::st_point(c(925000, 6700000)),
                                                         crs = 2154))
  expect_error(creer_projet_inventaire_video(pl, output_dir = tempdir(),
                                             project_name = "../x"), "project_name")
})

test_that("le client Groma interroge et télécharge", {
  skip_if_not_installed("httr2")
  withr::with_tempdir({
    httr2::local_mocked_responses(function(req) {
      if (grepl("/placettes$", req$url)) {
        expect_true("Authorization" %in% names(req$headers))
        return(httr2::response_json(body = list(list(plot_id = "P001", etat = "definitif"))))
      }
      if (grepl("P404", req$url)) return(httr2::response(status_code = 404))
      httr2::response(status_code = 200, body = charToRaw("contenu"))
    })
    etat <- groma_etat_placettes("https://groma.example/api/", "jeton")
    expect_equal(etat$plot_id, "P001")
    res <- suppressWarnings(groma_telecharger_resultats(
      "https://groma.example/api", "jeton", c("P001", "P404"), "dl", fichiers = "resultat.gpkg"))
    expect_length(res, 1L)
    expect_true(file.exists(res))
    expect_match(basename(res), "P001")
    expect_equal(attr(res, "detail")$statut, c(200L, 404L))
    expect_true(is.na(attr(res, "detail")$chemin[2]))
    expect_error(groma_telecharger_resultats("https://x", NULL, "../P1", "dl"), "plot_ids")
  })
})

test_that("validate_field_data : seuils de diamètre configurables, défauts inchangés", {
  pl <- sf::st_sf(plot_id = "P1", geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 2154))
  ar <- data.frame(plot_id = "P1", tree_id = c("1", "2"), dbh_cm = c(250, 400))
  v <- validate_field_data(pl, ar)
  expect_equal(v$errors$issue, "DBH out of range (expected > 0 and <= 300 cm).")
  v <- validate_field_data(pl, ar, dbh_max_cm = Inf, dbh_alerte_cm = 200)
  expect_true(v$ok)
  expect_equal(nrow(v$warnings), 2L)
  expect_equal(unique(v$warnings$issue), "DBH above alert threshold (200 cm).")
  sch <- get_arbre_schema(dbh_max_cm = 1000)
  expect_equal(Filter(function(f) f$name == "dbh_cm", sch)[[1]]$max, 1000)
  expect_equal(Filter(function(f) f$name == "dbh_cm", get_arbre_schema())[[1]]$max, 300)
})

test_that("map_bdforet_essence couvre tout le référentiel d'essences Groma", {
  ess <- nemeton:::.iv_essences()
  attendu <- c("Sapin, \u00e9pic\u00e9a" = "essence_pessiere_sapiniere",
               "Ch\u00eanes sempervirents" = "essence_chene_vert",
               "Robinier" = "essence_feuillus_pionniers",
               "Pin maritime" = "essence_pinede", "Pin d'Alep" = "essence_pinede",
               "Pin \u00e0 crochets, pin cembro" = "essence_pinede",
               "Autres pins" = "essence_pinede")
  for (lib in names(attendu)) expect_equal(map_bdforet_essence(lib), attendu[[lib]], info = lib)
  hors_nc <- setdiff(unique(ess$bdforet), "NC")
  expect_false(any(vapply(hors_nc, map_bdforet_essence, "") == "essence_mixte"))
})

test_that("importer_inventaire_video rend les formes attendues par l'app", {
  gpkg_iv <- iv_fixture("inventaire_video.gpkg")
  withr::with_tempdir({
    fd <- "field_data.gpkg"
    # Inventaire classique de P002, à conserver tel quel.
    p2 <- sf::st_sf(plot_id = "P002", geometry = sf::st_sfc(sf::st_point(c(925180, 6700090)),
                                                            crs = 2154))
    a2 <- sf::st_sf(plot_id = "P002", tree_id = c("1", "2"), dbh_cm = c(30, 42),
                    geometry = sf::st_sfc(sf::st_point(c(925181, 6700091)),
                                          sf::st_point(c(925183, 6700088)), crs = 2154))
    sf::st_write(p2, fd, layer = "placettes", quiet = TRUE)
    sf::st_write(a2, fd, layer = "arbres", quiet = TRUE)
    res <- importer_inventaire_video(gpkg_iv, resultats = NULL, field_data_gpkg = fd)
    expect_true(res$validation$ok)
    expect_identical(res$ndp, 3L)
    expect_equal(res$classique_conserve, "P002")
    expect_s3_class(res$a_completer, "data.frame")
    expect_s3_class(res$a_verifier, "data.frame")
    expect_named(res$numeros_modifies, c("plot_id", "uuid", "ancien", "nouveau"))
    a <- sf::st_read(fd, layer = "arbres", quiet = TRUE)
    cl <- a[a$plot_id == "P002", ]
    expect_equal(sort(cl$dbh_cm), c(30, 42))
    expect_true(all(cl$source != "inventaire_video"))
    expect_true("P001" %in% a$plot_id)
  })
})

test_that("detect_ndp : inventaire vidéo = palier 3 dès qu'il porte des arbres", {
  df <- data.frame(x = 1)
  pl <- data.frame(plot_id = c("P1", "P2"))
  ar <- data.frame(plot_id = rep("P1", 5))
  expect_equal(detect_ndp(tag_field_data_sources(df, pl, ar))$level, 2L)
  expect_equal(detect_ndp(tag_field_data_sources(df, pl, ar, source = "inventaire_video"))$level, 3L)
  expect_equal(detect_ndp(tag_field_data_sources(df, pl, NULL, source = "inventaire_video"))$level, 2L)
})
