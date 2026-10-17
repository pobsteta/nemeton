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
                              "detections", "houppiers", "parcelles", "ugf", "projet"))
  expect_equal(attr(s, "version"), "1.2.0")
  for (couche in c("parcelles", "ugf", "projet")) {
    expect_true(attr(s[[couche]], "lecture_seule"))
  }
  expect_null(attr(s$projet, "geometrie"))
  expect_equal(attr(s$ugf, "geometrie"), "MULTIPOLYGON")
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

    # Légende en trois groupes : rasters des placettes repliés et décochés
    # (brief groma 2026-10-17).
    doc <- xml2::read_xml(file.path("x", "inventaire_video.qgs"))
    grp <- xml2::xml_find_all(doc, "/qgis/layer-tree-group/layer-tree-group")
    expect_identical(xml2::xml_attr(grp, "name"),
                     c("Inventaire", "Rasters des placettes", "Fonds de carte"))
    expect_identical(xml2::xml_attr(grp, "checked"),
                     c("Qt::Checked", "Qt::Unchecked", "Qt::Checked"))
    expect_identical(xml2::xml_attr(grp, "expanded"), c("1", "0", "0"))
    expect_setequal(xml2::xml_attr(xml2::xml_find_all(grp[[2]], "layer-tree-layer"), "name"),
                    c("P1_mnt", "P1_mnh", "P2_mnt", "P2_mnh"))
    expect_length(xml2::xml_find_all(doc, "/qgis/layer-tree-group/layer-tree-layer"), 0)

    # Dossier ouvrable à côté du .qgz : mêmes fichiers, chemins ./ résolus.
    d <- file.path("sortie", "inventaire_video")
    expect_true(all(file.exists(file.path(d, c("inventaire_video.qgs", "inventaire_video.gpkg",
                                               "inventaire_video.qml", "rasters/P1_mnt.tif",
                                               "rasters/P2_mnh.tif")))))
    expect_identical(unname(tools::md5sum(file.path(d, "inventaire_video.qgs"))),
                     unname(tools::md5sum(file.path("x", "inventaire_video.qgs"))))
  })
})

test_that("renvoyer_inventaire_video renvoie les arbres à reprendre sans en perdre", {
  skip_if_not_installed("RSQLite")
  gpkg_iv <- iv_fixture("inventaire_video.gpkg")
  gpkg_def <- iv_fixture("P001_definitif.gpkg")
  withr::with_tempdir({
    res <- suppressWarnings(importer_inventaire_video(gpkg_iv, resultats = gpkg_def))
    etat <- res$arbres$etat_detection
    a_reprendre <- !is.na(etat) & etat %in% c("a_completer", "a_verifier")
    skip_if(!any(a_reprendre), "fixture sans arbre à reprendre")
    ids <- sort(unique(res$arbres$plot_id[a_reprendre]))

    dir.create("rasters")
    file.create(file.path("rasters", paste0(ids[1], "_mnt.tif")))
    qgz <- suppressMessages(renvoyer_inventaire_video(
      res, gpkg = gpkg_iv, rasters = "rasters", output_dir = "retour"))
    expect_true(file.exists(qgz))
    expect_equal(attr(qgz, "plot_ids"), ids)
    expect_equal(attr(qgz, "n_arbres"), sum(a_reprendre))
    contenu <- utils::unzip(qgz, list = TRUE)$Name
    expect_true(all(c("inventaire_video_retour.qgs", "inventaire_video.gpkg",
                      file.path("rasters", paste0(ids[1], "_mnt.tif"))) %in% contenu))
    utils::unzip(qgz, exdir = "x")
    g <- file.path("x", "inventaire_video.gpkg")
    # Tous les arbres des placettes renvoyées, pas seulement ceux à reprendre.
    a <- sf::st_read(g, layer = "arbres", quiet = TRUE)
    expect_setequal(a$uuid, res$arbres$uuid[res$arbres$plot_id %in% ids])
    expect_setequal(sf::st_read(g, layer = "placettes", quiet = TRUE)$plot_id, ids)
    qgs <- paste(readLines(file.path("x", "inventaire_video_retour.qgs"), warn = FALSE),
                 collapse = "")
    expect_match(qgs, "subset=&quot;etat_detection&quot; IN (&apos;a_completer&apos;, &apos;a_verifier&apos;)",
                 fixed = TRUE)

    qgz2 <- suppressMessages(renvoyer_inventaire_video(
      res, filtrer = FALSE, output_dir = "retour2"))
    utils::unzip(qgz2, exdir = "y")
    qgs2 <- paste(readLines(file.path("y", "inventaire_video_retour.qgs"), warn = FALSE),
                  collapse = "")
    expect_false(grepl("subset=", qgs2, fixed = TRUE))
  })
  expect_error(renvoyer_inventaire_video(list()), "importer_inventaire_video")
  imp <- list(placettes = sf::st_sf(plot_id = "P1", geometry = sf::st_sfc(
    sf::st_point(c(0, 0)), crs = 2154)), arbres = sf::st_sf(plot_id = "P1",
    etat_detection = "definitif", geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 2154)))
  expect_error(renvoyer_inventaire_video(imp, etats = "inconnu", output_dir = tempdir()),
               "etats")
  expect_error(renvoyer_inventaire_video(imp, output_dir = tempdir()), "nothing to send back")
  expect_error(renvoyer_inventaire_video(imp, output_dir = tempdir(), project_name = "../x"),
               "project_name")
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


# ---- Schéma 1.2.0 : tables projet, parcelles, ugf (brief Groma 2026-10-15) ----

# Projet nemetonshiny minimal : 2 parcelles, 3 ténements pour 2 UG.
iv_projet_nemetonshiny <- function(racine) {
  data <- file.path(racine, "data")
  dir.create(data, recursive = TRUE)
  carre <- function(x0, y0, l) {
    sf::st_polygon(list(rbind(c(x0, y0), c(x0 + l, y0), c(x0 + l, y0 + l),
                              c(x0, y0 + l), c(x0, y0))))
  }
  parcelles <- sf::st_sf(
    id = c("212000000A0001", "212000000A0002"), section = "A", numero = c("1", "2"),
    contenance = c(41000, 39000), commune = "21200",
    geometry = sf::st_sfc(carre(925000, 6700000, 200), carre(925200, 6700000, 200), crs = 2154))
  sf::st_write(sf::st_transform(parcelles, 4326), file.path(data, "parcels.gpkg"),
               layer = "parcels", quiet = TRUE)
  sf::st_write(sf::st_sf(code = "21200", nom = "Couchey",
                         geometry = sf::st_sfc(carre(924000, 6699000, 3000), crs = 2154)),
               file.path(data, "commune.gpkg"), layer = "commune", quiet = TRUE)
  ten <- sf::st_sf(
    tenement_id = c("tnm_1", "tnm_2", "tnm_3"), ug_id = c("ug_10", "ug_2", "ug_2"),
    surface_m2 = c(40000, 20000, 19000),
    geometry = sf::st_sfc(carre(925000, 6700000, 200), carre(925200, 6700000, 100),
                          carre(925300, 6700000, 100), crs = 2154))
  sf::st_write(sf::st_transform(ten, 4326), file.path(data, "tenements.gpkg"),
               layer = "tenements", quiet = TRUE)
  jsonlite::write_json(list(ug_id = c("ug_2", "ug_10"), label = c("UG deux", "UG dix"),
                            groupe = c(NA, "G1")),
                       file.path(data, "ugs.json"), auto_unbox = FALSE)
  jsonlite::write_json(list(id = "20261015_120000_test", name = "Couchey test",
                            description = "Fixture", owner = "", parcels_count = 2,
                            ug_count = 2, samples_generated_at = "2026-10-15 10:00:00"),
                       file.path(racine, "metadata.json"), auto_unbox = TRUE)
  racine
}

iv_plan_test <- function() {
  sf::st_sf(plot_id = c("P1", "P2", "P3"), type = c("Base", "Base", "Over"), wgt = 10,
            geometry = sf::st_sfc(sf::st_point(c(925050, 6700050)),
                                  sf::st_point(c(925250, 6700150)),
                                  sf::st_point(c(925350, 6700020)), crs = 2154))
}

test_that("creer_projet_inventaire_video remplit projet, parcelles et ugf depuis le projet", {
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    racine <- iv_projet_nemetonshiny("projet")
    qgz <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                         project_path = racine, output_dir = "sortie")
    utils::unzip(qgz, exdir = "x")
    gpkg <- file.path("x", "inventaire_video.gpkg")
    pr <- suppressWarnings(sf::st_read(gpkg, layer = "projet", quiet = TRUE))
    expect_equal(nrow(pr), 1L)
    expect_equal(pr$projet_id, "20261015_120000_test")
    expect_equal(pr$projet_nom, "Couchey test")
    expect_true(is.na(pr$proprietaire))
    expect_equal(pr$communes, "Couchey (21200)")
    expect_equal(pr$surface_zone_ha, 8)
    expect_equal(pr$surface_cadastre_ha, 8)
    expect_equal(c(pr$nb_placettes_base, pr$nb_placettes_rempl), c(2L, 1L))
    expect_equal(pr$plan_genere_le, "2026-10-15 10:00:00")
    expect_match(pr$prepare_par, "^nemeton ")
    # Emprise en EPSG:4326 contenant toutes les placettes.
    emprise <- sf::st_as_sfc(pr$emprise, crs = 4326)
    pts <- sf::st_transform(iv_plan_test(), 4326)
    expect_true(all(sf::st_covers(sf::st_buffer(emprise, 1e-7), pts, sparse = FALSE)))

    pa <- sf::st_read(gpkg, layer = "parcelles", quiet = TRUE)
    expect_equal(nrow(pa), 2L)
    expect_equal(pa$idu, c("212000000A0001", "212000000A0002"))
    expect_equal(pa$contenance_m2, c(41000, 39000))
    expect_equal(sf::st_crs(pa)$epsg, 2154L)

    ug <- sf::st_read(gpkg, layer = "ugf", quiet = TRUE)
    expect_equal(ug$ug_id, c("ug_2", "ug_10"))          # ordre naturel
    expect_equal(ug$surface_m2, c(39000, 40000))         # somme des ténements
    expect_equal(ug$libelle, c("UG deux", "UG dix"))
    expect_equal(as.character(sf::st_geometry_type(ug)), rep("MULTIPOLYGON", 2))
    expect_equal(as.numeric(sf::st_area(ug)), c(20000, 40000), tolerance = 1e-3)

    # Aucun index spatial sur les tables lues par le téléphone.
    con <- DBI::dbConnect(RSQLite::SQLite(), gpkg)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    trg <- DBI::dbGetQuery(con, "SELECT name FROM sqlite_master WHERE type = 'trigger'")$name
    expect_false(any(grepl("^rtree_(parcelles|ugf)_", trg)))
    ct <- DBI::dbGetQuery(con, "SELECT table_name, data_type FROM gpkg_contents")
    expect_equal(ct$data_type[ct$table_name == "projet"], "attributes")
    qgs <- paste(readLines(file.path("x", "inventaire_video.qgs"), warn = FALSE), collapse = "")
    expect_match(qgs, "layername=ugf", fixed = TRUE)
  })
})

test_that("sans project_path, projet, parcelles et ugf existent vides", {
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    qgz <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE, output_dir = "s")
    utils::unzip(qgz, exdir = "x")
    l <- sf::st_layers(file.path("x", "inventaire_video.gpkg"))
    n <- stats::setNames(l$features, l$name)
    expect_true(all(c("projet", "parcelles", "ugf") %in% names(n)))
    expect_equal(unname(n[c("projet", "parcelles", "ugf")]), c(0, 0, 0))
    expect_true(valider_inventaire_video(file.path("x", "inventaire_video.gpkg"))$ok)
  })
})

test_that("une source illisible n'empêche pas la création", {
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    racine <- iv_projet_nemetonshiny("projet")
    writeLines("pas un geopackage", file.path(racine, "data", "tenements.gpkg"))
    expect_warning(
      qgz <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                           project_path = racine, output_dir = "s"),
      "Management units")
    utils::unzip(qgz, exdir = "x")
    l <- sf::st_layers(file.path("x", "inventaire_video.gpkg"))
    n <- stats::setNames(l$features, l$name)
    expect_equal(unname(n[c("projet", "parcelles", "ugf")]), c(1, 2, 0))
  })
})

test_that("plusieurs centres mesurés : le plus récent compte", {
  prov <- data.frame(uuid = "u1", plot_id = "P1", tree_id = "1", dbh_cm = 30,
                     x = 1000, y = 2005)
  def <- data.frame(x = 1000, y = 2005, dbh_cm = 30, methode = "classique")
  centres <- sf::st_sf(plot_id = "P1", fid = c(1, 3, 2),
                       geometry = sf::st_sfc(sf::st_point(c(1000, 2000)),
                                             sf::st_point(c(1005, 2005)),
                                             sf::st_point(c(990, 1990)), crs = 2154))
  r <- rapprocher_arbres(prov, def, centre = centres)
  # Centre retenu = fid 3 (1005, 2005) : arbre à 5 m plein ouest.
  expect_equal(r$arbres$distance_m, 5)
  expect_equal(r$arbres$azimut, 270)
  # Sans fid : la dernière ligne.
  r2 <- rapprocher_arbres(prov, def, centre = sf::st_drop_geometry(
    transform(centres[, "plot_id"], x = c(1000, 1000, 1000), y = c(2000, 2000, 2001))))
  expect_equal(r2$arbres$distance_m, 4)
})

test_that("importer et valider : plusieurs centres par placette, sans erreur", {
  skip_if_not_installed("RSQLite")
  src <- iv_fixture("inventaire_video.gpkg")
  withr::with_tempdir({
    file.copy(src, "iv.gpkg")
    c1 <- sf::st_read("iv.gpkg", layer = "centres_mesures", quiet = TRUE)
    nouveau <- c1[c1$plot_id == "P001", ]
    sf::st_geometry(nouveau) <- sf::st_geometry(nouveau) + c(3, 0)
    sf::st_crs(nouveau) <- 2154
    sf::st_write(nouveau, "iv.gpkg", layer = "centres_mesures", append = TRUE, quiet = TRUE)
    g <- nemeton:::.iv_lire("iv.gpkg")
    der <- nemeton:::.iv_derniers_centres(g$centres_mesures)
    expect_equal(unname(sf::st_coordinates(der[der$plot_id == "P001", ])[1, "X"]), 925003)
    v <- valider_inventaire_video("iv.gpkg")
    expect_true(v$ok)
    info <- v$warnings[v$warnings$field == "centres_mesures", ]
    expect_equal(info$plot_id, "P001")
    expect_equal(info$severity, "info")
  })
})

test_that("l'exemple Groma au schéma 1.2.0 passe la validation", {
  gpkg <- iv_fixture("inventaire_video.gpkg")
  expect_true(all(c("projet", "parcelles", "ugf") %in% sf::st_layers(gpkg)$name))
  expect_true(valider_inventaire_video(gpkg)$ok)
})

# ---- Plugin de projet QField (brief Groma 2026-10-16) ----

test_that("le plugin QField est livré à côté du projet, couches non verrouillées", {
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    racine <- iv_projet_nemetonshiny("projet")
    qgz <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                         project_path = racine, output_dir = "s",
                                         project_name = "couchey")
    qml <- file.path("s", "couchey.qml")
    expect_true(file.exists(qml))
    ref <- system.file("inventaire_video", "inventaire_video.qml", package = "nemeton")
    expect_identical(unname(tools::md5sum(qml)), unname(tools::md5sum(ref)))
    expect_false(any(grepl("\\.qml$", utils::unzip(qgz, list = TRUE)$Name)))

    utils::unzip(qgz, exdir = "x")
    qgs <- xml2::read_xml(file.path("x", "couchey.qgs"))
    couches <- xml2::xml_find_all(qgs, "//projectlayers/maplayer")
    noms <- xml2::xml_text(xml2::xml_find_first(couches, "layername"))
    expect_true(all(c("projet", "detections", "centres_mesures", "arbres") %in% noms))
    for (n in c("projet", "detections", "centres_mesures", "arbres")) {
      l <- couches[[match(n, noms)]]
      expect_equal(xml2::xml_attr(l, "readOnly"), "0")
      expect_length(xml2::xml_find_all(l, "flags"), 0)
    }
    expect_equal(xml2::xml_attr(couches[[match("projet", noms)]], "wkbType"), "NoGeometry")
    # Champs de detections non éditables dans les formulaires.
    det <- couches[[match("detections", noms)]]
    expect_true(all(xml2::xml_attr(xml2::xml_find_all(det, "editable/field"), "editable") == "0"))
    expect_equal(xml2::xml_text(xml2::xml_find_first(qgs, "/qgis/title")),
                 "Inventaire vidéo — Couchey test")

    p <- sf::st_read(file.path("x", "inventaire_video.gpkg"), layer = "placettes", quiet = TRUE)
    expect_true(all(is.na(p$declinaison_deg)))
  })
})

# ---- Symbologie Marculus, fonds et houppiers (briefs groma 2026-10-16) ----

test_that("projet QField : symbologie Marculus, fonds IGN/OSM, houppiers masqués", {
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    racine <- iv_projet_nemetonshiny("projet")
    qgz <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                         project_path = racine, output_dir = "s")
    utils::unzip(qgz, exdir = "x")
    qgs <- xml2::read_xml(file.path("x", "inventaire_video.qgs"))
    arbre <- xml2::xml_find_all(qgs, "//layer-tree-group/layer-tree-layer")
    noms <- xml2::xml_attr(arbre, "name")
    fonds <- c("Cadastre IGN", "Plan IGN", "Ortho IGN", "OpenStreetMap")
    # Les quatre fonds, dans cet ordre, sous toutes les couches vectorielles.
    expect_identical(utils::tail(noms, 4), fonds)
    expect_true(all(match(c("arbres", "ugf", "houppiers"), noms) < match("Cadastre IGN", noms)))
    coche <- stats::setNames(xml2::xml_attr(arbre, "checked"), noms)
    expect_identical(unname(coche[fonds]), c("Qt::Unchecked", "Qt::Checked", "Qt::Unchecked", "Qt::Unchecked"))
    expect_identical(unname(coche["houppiers"]), "Qt::Unchecked")
    expect_identical(unname(coche["arbres"]), "Qt::Checked")

    couches <- xml2::xml_find_all(qgs, "//projectlayers/maplayer")
    ln <- xml2::xml_text(xml2::xml_find_first(couches, "layername"))
    plan <- couches[[match("Plan IGN", ln)]]
    src <- utils::URLdecode(xml2::xml_text(xml2::xml_find_first(plan, "datasource")))
    expect_match(src, "^type=xyz&url=https://data.geopf.fr/wmts")
    expect_match(src, "LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2", fixed = TRUE)
    expect_match(src, "TILEMATRIX={z}&TILEROW={y}&TILECOL={x}", fixed = TRUE)
    expect_false(grepl("GetCapabilities", src))
    expect_equal(xml2::xml_text(xml2::xml_find_first(plan, "provider")), "wms")
    expect_equal(xml2::xml_text(xml2::xml_find_first(plan, "resourceMetadata/rights")),
                 "\u00a9 IGN G\u00e9oplateforme, Licence Ouverte Etalab 2.0")
    cad <- couches[[match("Cadastre IGN", ln)]]
    expect_match(utils::URLdecode(xml2::xml_text(xml2::xml_find_first(cad, "datasource"))),
                 "STYLE=PCI%20vecteur", fixed = TRUE)
    expect_equal(xml2::xml_text(xml2::xml_find_first(cad, "resourceMetadata/rights")), "cadastre \u00a9 IGN")

    # arbres : catégorisé sur essence_arbre, couleurs des groupes Marculus.
    ar <- couches[[match("arbres", ln)]]
    r <- xml2::xml_find_first(ar, "renderer-v2")
    expect_equal(xml2::xml_attr(r, "attr"), "essence_arbre")
    cats <- xml2::xml_find_all(r, "categories/category")
    i <- match("hetre", xml2::xml_attr(cats, "value"))
    sym <- xml2::xml_find_all(r, "symbols/symbol")[[i]]
    opt <- xml2::xml_find_all(sym, ".//Option[@name='color']")
    expect_equal(xml2::xml_attr(opt[[1]], "value"), "80,97,184,255")      # #5061b8
    expect_match(as.character(sym), "scale_linear", fixed = TRUE)
    # ugf : une couleur par forêt (aucune ici : catégorie « Sans forêt »), contour 0,9 mm.
    u <- couches[[match("ugf", ln)]]
    expect_equal(xml2::xml_attr(xml2::xml_find_first(u, "renderer-v2"), "attr"), "foret")
    w <- xml2::xml_find_all(u, ".//Option[@name='outline_width']")
    expect_true(all(xml2::xml_attr(w, "value") == "0.9"))
    # houppiers : contour seul #2e7d32.
    h <- couches[[match("houppiers", ln)]]
    expect_equal(xml2::xml_attr(xml2::xml_find_first(h, ".//Option[@name='style']"), "value"), "no")
    expect_equal(xml2::xml_attr(xml2::xml_find_first(h, ".//Option[@name='outline_color']"), "value"),
                 "46,125,50,255")
  })
})

# ---- Projection, emprise et dossier du projet (briefs groma 2026-10-17) ----

test_that("projet QField : projection active, ellipsoïde, emprise d'ouverture", {
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    racine <- iv_projet_nemetonshiny("projet")
    pl <- iv_plan_test()
    qgz <- creer_projet_inventaire_video(pl, avec_lidar = FALSE,
                                         project_path = racine, output_dir = "s")
    utils::unzip(qgz, exdir = "x")
    doc <- xml2::read_xml(file.path("x", "inventaire_video.qgs"))
    expect_equal(xml2::xml_text(xml2::xml_find_first(doc,
      "/qgis/properties/SpatialRefSys/ProjectionsEnabled")), "1")
    expect_equal(xml2::xml_text(xml2::xml_find_first(doc,
      "/qgis/properties/Measure/Ellipsoid")), "EPSG:7019")
    ext <- xml2::xml_find_first(doc, "/qgis/ProjectViewSettings/DefaultViewExtent")
    v <- vapply(c("xmin", "ymin", "xmax", "ymax"), function(a) as.numeric(xml2::xml_attr(ext, a)), numeric(1))
    bb <- sf::st_bbox(sf::st_transform(pl, 2154))
    # L'emprise contient les placettes et leur rayon, marge comprise.
    expect_true(v[1] < bb[["xmin"]] - 20 && v[3] > bb[["xmax"]] + 20)
    expect_true(v[2] < bb[["ymin"]] - 20 && v[4] > bb[["ymax"]] + 20)
    expect_equal(xml2::xml_text(xml2::xml_find_first(ext, "spatialrefsys/authid")), "EPSG:2154")
    # Sans raster, le groupe des rasters n'est pas écrit.
    expect_identical(xml2::xml_attr(xml2::xml_find_all(doc, "/qgis/layer-tree-group/layer-tree-group"),
                                    "name"), c("Inventaire", "Fonds de carte"))
  })
})

test_that("le dossier du projet est remplacé avec le .qgz, jamais sans overwrite", {
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    racine <- iv_projet_nemetonshiny("projet")
    qgz <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                         project_path = racine, output_dir = "s",
                                         project_name = "couchey")
    d <- file.path("s", "couchey")
    expect_true(all(file.exists(file.path(d, c("couchey.qgs", "inventaire_video.gpkg",
                                               "couchey.qml")))))
    # Le .qgz garde son contenu (serveur Groma, extraction de l'application).
    expect_true(all(c("couchey.qgs", "inventaire_video.gpkg") %in%
                    utils::unzip(qgz, list = TRUE)$Name))
    writeLines("ancien", file.path(d, "reste.txt"))
    creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                  project_path = racine, output_dir = "s",
                                  project_name = "couchey")
    expect_false(file.exists(file.path(d, "reste.txt")))
    expect_length(list.files("s", pattern = "^couchey_"), 0)   # pas de reste temporaire
    unlink(qgz)
    expect_error(creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                               output_dir = "s", project_name = "couchey",
                                               overwrite = FALSE),
                 "already exists")
  })
})

# ---- Publication sur le serveur Groma (brief groma 2026-10-17) ----

test_that("groma_envoyer_projet publie le .qgz puis le .qml, avec leurs empreintes", {
  skip_if_not_installed("httr2")
  skip_if_not_installed("openssl")
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    racine <- iv_projet_nemetonshiny("projet")
    qgz <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                         project_path = racine, output_dir = "s")
    appels <- list()
    httr2::local_mocked_responses(function(req) {
      # Sérialisation réelle du corps JSON, comme au moment de l'envoi.
      json <- if (identical(req$body$type, "json")) {
        jsonlite::fromJSON(jsonlite::toJSON(req$body$data, auto_unbox = TRUE),
                           simplifyVector = FALSE)
      }
      appels[[length(appels) + 1L]] <<- list(methode = req$method %||% "GET", url = req$url,
                                              corps = req$body, json = json)
      expect_true("Authorization" %in% names(req$headers))
      if (grepl("/publier$", req$url)) return(httr2::response_json(body = list(version = 3L)))
      httr2::response(status_code = 201)
    })
    res <- groma_envoyer_projet(qgz, "https://groma.example/api/", "jeton")
    expect_equal(res$projet_id, "20261015_120000_test")
    expect_equal(res$version, 3L)
    expect_equal(res$taille, sum(file.size(c(qgz, sub("qgz$", "qml", qgz)))))
    expect_equal(vapply(appels, `[[`, "", "methode"), c("PUT", "PUT", "POST"))
    base <- "https://groma.example/api/projets/20261015_120000_test/qfield/"
    expect_equal(vapply(appels, `[[`, "", "url"),
                 paste0(base, c("fichiers/inventaire_video.qgz", "fichiers/inventaire_video.qml",
                                "publier")))
    corps <- appels[[3]]$corps$data
    expect_equal(corps$projet_nom, "Couchey test")
    expect_equal(vapply(corps$fichiers, `[[`, "", "nom"),
                 c("inventaire_video.qgz", "inventaire_video.qml"))
    expect_equal(corps$fichiers[[1]]$sha256, nemeton:::.groma_sha256(qgz))
    expect_equal(nchar(corps$fichiers[[1]]$sha256), 64L)
    # Le corps passe en JSON : empreintes en hexadécimal, chaînes nues.
    j <- appels[[3]]$json
    expect_true(all(vapply(j$fichiers, function(f) grepl("^[0-9a-f]{64}$", f$sha256), logical(1))))
    expect_null(attr(corps$fichiers[[1]]$sha256, "class"))
    expect_match(corps$nemeton_version, "^[0-9]{4}\\.")

    # Sans .qml : seul le .qgz part et est publié.
    file.remove(sub("qgz$", "qml", qgz))
    appels <- list()
    groma_envoyer_projet(qgz, "https://groma.example/api", "jeton", projet_nom = "Autre")
    expect_length(appels, 2L)
    expect_equal(length(appels[[2]]$corps$data$fichiers), 1L)
    expect_equal(appels[[2]]$corps$data$projet_nom, "Autre")
  })
})

test_that("groma_envoyer_projet : sans projet_id, erreur et aucun appel ; 401 lisible", {
  skip_if_not_installed("httr2")
  skip_if_not_installed("openssl")
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    sans <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE, output_dir = "a")
    n <- 0L
    httr2::local_mocked_responses(function(req) {
      n <<- n + 1L
      httr2::response(status_code = 401)
    })
    expect_error(groma_envoyer_projet(sans, "https://groma.example"), "projet_id")
    expect_equal(n, 0L)
    racine <- iv_projet_nemetonshiny("projet")
    avec <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                          project_path = racine, output_dir = "b")
    expect_error(groma_envoyer_projet(avec, "https://groma.example", "mauvais"), "refused the token")
    expect_equal(n, 1L)
  })
})

test_that("groma_envoyer_projet : seule une erreur de connexion dit « injoignable »", {
  skip_if_not_installed("httr2")
  skip_if_not_installed("openssl")
  skip_if_not_installed("RSQLite")
  withr::with_tempdir({
    racine <- iv_projet_nemetonshiny("projet")
    qgz <- creer_projet_inventaire_video(iv_plan_test(), avec_lidar = FALSE,
                                         project_path = racine, output_dir = "s")
    # Port fermé : vraie erreur de connexion.
    expect_error(groma_envoyer_projet(qgz, "http://127.0.0.1:9"), "unreachable")
    # Autre erreur pendant l'envoi : remonte telle quelle.
    httr2::local_mocked_responses(function(req) stop("panne interne du test"))
    expect_error(groma_envoyer_projet(qgz, "https://groma.example"), "panne interne du test")
  })
})
