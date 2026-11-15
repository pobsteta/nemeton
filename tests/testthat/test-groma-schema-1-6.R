# Schema Groma 1.3.0 -> 1.6.0 (briefs groma du 2026-11-11 et 2026-11-13,
# spec 061 § 4 ter) : cibles en lecture seule, diametre au ruban, terrain sans
# QField, centre au telephone, rayon de 15 m.

# resolu une fois : les tests de terrain changent de dossier courant
GPKG_EXEMPLE <- normalizePath(testthat::test_path("fixtures", "inventaire_video",
                                                  "inventaire_video.gpkg"), mustWork = TRUE)
iv_fixture <- function(...) GPKG_EXEMPLE

# ---- Diametre au ruban : memes cas que core/tests/test_rapprochement_saisies.py

P1 <- c(1004.242641, 2004.242641)
P2 <- c(992, 2000)
P3 <- c(1000, 1995)

prov_ruban <- function(uuid, tree_id, pos, dbh, source, essence = NA, statut = "vivant",
                       qualite = NA) {
  data.frame(uuid = uuid, plot_id = "P01", tree_id = tree_id, dbh_cm = dbh,
             dbh_source = source, statut = statut, etat_detection = "provisoire",
             methode = "embarque", h_m = NA_real_, h_source = "aucune",
             essence_arbre = essence, qualite = qualite, notes = NA_character_,
             photos = NA_character_, x = pos[1], y = pos[2], stringsAsFactors = FALSE)
}
def_ruban <- function(pos, dbh) {
  data.frame(plot_id = "P01", dbh_cm = dbh, methode = "classique", x = pos[1], y = pos[2])
}
rapprocher_ruban <- function(prov, def) {
  k <- 0L
  rapprocher_arbres(prov, def, c(1000, 2000), 0, tolerance_m = 0.5, rayon_m = 20,
                    seuil_diam_cm = 7.5,
                    generer_uuid = function() { k <<- k + 1L; paste0("n", k - 1L) })
}

test_that("a tape diameter survives the reconciliation, an estimate is replaced", {
  prov <- rbind(prov_ruban("u1", "1", P1, 52, "mesure", "hetre", "mort", "B"),
                prov_ruban("u2", "2", P2, 20, "estime", "frene", qualite = "A"),
                prov_ruban("u3", "3", P3, 30, "mesure"))
  res <- rapprocher_ruban(prov, rbind(def_ruban(P1, 31), def_ruban(P2, 22), def_ruban(P3, 31)))
  a <- res$arbres
  u <- function(id) a[a$uuid == id, ]
  expect_equal(c(u("u1")$dbh_cm, u("u3")$dbh_cm), c(52, 30))
  expect_equal(c(u("u1")$dbh_source, u("u3")$dbh_source), c("mesure", "mesure"))
  expect_equal(u("u1")$etat_detection, "definitif")
  expect_equal(u("u2")$dbh_cm, 22)
  expect_equal(u("u2")$dbh_source, "estime")
  expect_equal(c(u("u1")$essence_arbre, u("u1")$statut, u("u1")$qualite), c("hetre", "mort", "B"))
  # ecart_dbh compare au ruban : 52 contre 31 cm oui, 30 contre 31 non
  al <- paste(res$alertes$uuid, res$alertes$motif)
  expect_true("u1 ecart_dbh" %in% al)
  expect_false("u3 ecart_dbh" %in% al)
})

test_that("a taped tree not found keeps its diameter; out of the plot it stays to check", {
  res <- rapprocher_ruban(prov_ruban("u1", "1", P1, 45, "mesure", "hetre"), def_ruban(P1, 0)[0, ])
  a <- res$arbres
  expect_equal(c(a$dbh_cm, a$dbh_source, a$essence_arbre), c("45", "mesure", "hetre"))
  # hors rayon, sans autre saisie que le ruban : garde en a_verifier
  loin <- prov_ruban("u9", "9", c(1030, 2000), 25, "mesure")
  res <- rapprocher_ruban(loin, def_ruban(c(1030, 2000), 25))
  expect_equal(res$arbres$etat_detection, "a_verifier")
  expect_equal(res$arbres$dbh_cm, 25)
  expect_true(nemeton:::.iv_a_attributs_terrain(data.frame(dbh_source = "mesure")))
  expect_false(nemeton:::.iv_a_attributs_terrain(data.frame(dbh_source = "estime")))
})

test_that("new trees from the server get dbh_source = estime", {
  prov <- prov_ruban("u1", "1", P1, 30, "estime")
  res <- rapprocher_ruban(prov, rbind(def_ruban(P1, 30), def_ruban(P3, 25)))
  expect_equal(res$arbres$dbh_source[res$arbres$uuid %in% res$nouveaux], "estime")
})

# ---- Schema, formulaires et symbologie

test_that("schema 1.6.0: read-only targets and tape diameter, labels, no spatial index", {
  s <- schema_inventaire_video()
  expect_equal(attr(s, "version"), "1.6.0")
  expect_true(attr(s$cibles, "lecture_seule"))
  for (couche in c("centres_mesures", "cibles")) expect_false(attr(s[[couche]], "index_spatial"))
  dom <- attr(s, "domaines")
  expect_true("telephone" %in% dom$qualite_gnss)
  expect_true("terrain" %in% dom$methode)
  expect_setequal(dom$dbh_source, c("estime", "mesure"))
  champ <- function(couche, nom) s[[couche]][[match(nom, vapply(s[[couche]], `[[`, "", "name"))]]
  expect_true(champ("arbres", "dbh_cm")$readonly)
  expect_true(champ("arbres", "dbh_source")$readonly)
  expect_equal(champ("arbres", "dbh_source")$default, "estime")
  expect_equal(unname(champ("centres_mesures", "qualite_gnss")$labels["telephone"]),
               "t\u00e9l\u00e9phone")
  expect_true(all(c("nb_positions", "nb_satellites", "hdop", "age_corrections_s",
                    "duree_mesure_s") %in% vapply(s$centres_mesures, `[[`, "", "name")))
  expect_equal(champ("placettes", "rayon_m")$default, 15)
  expect_equal(formals(creer_projet_inventaire_video)$rayon_m, 15)
  expect_equal(formals(numeroter_arbres)$rayon_m, 15)
  expect_equal(formals(rapprocher_arbres)$rayon_m, 15)
})

test_that("phone centres are drawn in an alert colour", {
  st <- nemeton:::.iv_style_couche("centres_mesures", character(0))
  expect_match(st$renderer, 'attr="qualite_gnss"', fixed = TRUE)
  expect_match(st$renderer, 'value="telephone"', fixed = TRUE)
})

# ---- Validation : domaines et centre au telephone

test_that("valider_inventaire_video checks the new domains and flags phone centres", {
  g <- nemeton:::.iv_lire(iv_fixture("inventaire_video.gpkg"))
  expect_true(valider_inventaire_video(g)$ok)
  g$arbres$dbh_source[1] <- "pied_a_coulisse"
  g$centres_mesures$qualite_gnss[1] <- "boussole"
  g$cibles <- data.frame(plot_id = "P001", source_azimut = "au_jugé")
  v <- valider_inventaire_video(g)
  expect_false(v$ok)
  expect_true(all(c("dbh_source", "qualite_gnss", "source_azimut") %in% v$errors$field))

  g <- nemeton:::.iv_lire(iv_fixture("inventaire_video.gpkg"))
  g$centres_mesures$qualite_gnss[1] <- "telephone"
  g$centres_mesures$precision_h_m[1] <- 4.2
  v <- valider_inventaire_video(g)
  expect_true(v$ok)
  w <- v$warnings[v$warnings$field == "qualite_gnss", ]
  expect_equal(w$plot_id, as.character(g$centres_mesures$plot_id[1]))
  expect_match(w$issue, "4.2 m")
})

# ---- Terrain envoye par Groma (terrain.zip)

# Archive terrain.zip d'une placette de la fixture, avec une photo emballee,
# une photo absente et, si `piege`, des entrees dangereuses.
faire_terrain <- function(dossier, pid = "P001", essence = "chene_sessile", piege = FALSE) {
  g <- nemeton:::.iv_lire(iv_fixture("inventaire_video.gpkg"))
  src <- file.path(dossier, paste0("src_", pid))
  dir.create(file.path(src, "photos"), recursive = TRUE)
  gp <- file.path(src, "terrain.gpkg")
  pl <- g$placettes[g$placettes$plot_id == pid, ]
  ar <- g$arbres[g$arbres$plot_id == pid, ]
  ar$essence_arbre[1] <- essence
  ar$photos[1] <- "photos/P001_a_20261111-101010.jpg;DCIM/absente.jpg"
  writeBin(as.raw(1:10), file.path(src, "photos", "P001_a_20261111-101010.jpg"))
  ce <- g$centres_mesures[g$centres_mesures$plot_id == pid, ]
  ce$qualite_gnss <- "telephone"
  ce$precision_h_m <- 6
  ce$fid <- NULL   # lu comme colonne par .iv_lire(), cle du GeoPackage a l'ecriture
  sf::st_write(pl, gp, "placettes", quiet = TRUE)
  sf::st_write(ar, gp, "arbres", quiet = TRUE, append = TRUE)
  sf::st_write(ce, gp, "centres_mesures", quiet = TRUE, append = TRUE)
  fichiers <- c("terrain.gpkg", "photos/P001_a_20261111-101010.jpg")
  if (piege) {
    writeLines("x", file.path(src, "autre.txt"))
    fichiers <- c(fichiers, "autre.txt")
  }
  z <- file.path(dossier, paste0(pid, "_terrain.zip"))
  withr::with_dir(src, utils::zip(z, fichiers, flags = "-q"))
  z
}

test_that("only terrain.gpkg and photos/<name> are extracted", {
  sures <- nemeton:::.iv_terrain_entrees_sures(c(
    "terrain.gpkg", "photos/a.jpg", "photos/../x", "../terrain.gpkg", "/etc/passwd",
    "C:/x.gpkg", "photos\\b.jpg", "photos/sous/c.jpg", "autre.txt", "photos/"))
  expect_equal(sures, c("terrain.gpkg", "photos/a.jpg"))
  withr::with_tempdir({
    z <- faire_terrain(getwd(), piege = TRUE)
    expect_warning(gp <- nemeton:::.iv_terrain_extraire(z, "x"), "ignored")
    expect_true(file.exists(gp))
    expect_false(file.exists(file.path("x", "autre.txt")))
  })
})

test_that("Groma field data replace the QField copy, with alerts and photos", {
  skip_if_not_installed("sf")
  withr::with_tempdir({
    dir.create("projet")
    file.copy(iv_fixture("inventaire_video.gpkg"), "projet/inventaire_video.gpkg")
    # copie de QField : une essence saisie seulement la
    q <- nemeton:::.iv_lire("projet/inventaire_video.gpkg")
    a <- sf::st_read("projet/inventaire_video.gpkg", "arbres", quiet = TRUE)
    a$qualite[a$plot_id == "P001"][16] <- "C"   # arbre sans qualite dans le terrain
    sf::st_write(a, "projet/inventaire_video.gpkg", "arbres", delete_layer = TRUE, quiet = TRUE)
    z <- faire_terrain(getwd())
    res <- suppressWarnings(importer_inventaire_video("projet/inventaire_video.gpkg",
                                                      terrain = getwd()))
    al <- res$alertes
    expect_true("detail" %in% names(al))
    expect_true(any(al$motif == "terrain_serveur_prefere" & al$plot_id == "P001"))
    perdue <- al[al$motif == "saisie_qfield_ignoree", ]
    expect_true(any(grepl("^qualite = C$", perdue$detail)))
    expect_true(any(al$motif == "centre_telephone" & al$plot_id == "P001"))
    arb <- res$arbres[res$arbres$plot_id == "P001", ]
    expect_true("chene_sessile" %in% arb$essence_arbre)
    ph <- arb$photos[!is.na(arb$photos) & nzchar(arb$photos)][1]
    expect_equal(ph, "photos/P001/P001_a_20261111-101010.jpg;DCIM/absente.jpg")
    expect_true(file.exists(file.path("projet", "photos", "P001", "P001_a_20261111-101010.jpg")))
    # les autres placettes viennent de la copie de QField
    expect_true(all(q$placettes$plot_id %in% res$placettes$plot_id))
  })
})

test_that("field data alone are enough to import", {
  withr::with_tempdir({
    z <- faire_terrain(getwd())
    res <- suppressWarnings(importer_inventaire_video(terrain = z, dossier_photos = "ph"))
    expect_equal(unique(res$placettes$plot_id), "P001")
    expect_true(file.exists(file.path("ph", "P001", "P001_a_20261111-101010.jpg")))
    expect_error(importer_inventaire_video(), "terrain")
  })
})

test_that("the Groma client fetches terrain.zip, quietly absent when 404", {
  skip_if_not_installed("httr2")
  withr::with_tempdir({
    httr2::local_mocked_responses(function(req) {
      if (grepl("P002/terrain.zip", req$url)) return(httr2::response(status_code = 404))
      httr2::response(status_code = 200, body = charToRaw("zip"))
    })
    expect_no_warning(res <- groma_telecharger_resultats(
      "https://groma.example", NULL, c("P001", "P002"), "dl", fichiers = "terrain.zip"))
    expect_equal(basename(res), "P001_terrain.zip")
    expect_true("terrain.zip" %in% eval(formals(groma_telecharger_resultats)$fichiers))
  })
})

test_that("with etat, terrain.zip is fetched only when terrain_envoye_le changes", {
  skip_if_not_installed("httr2")
  withr::with_tempdir({
    appels <- character()
    httr2::local_mocked_responses(function(req) {
      appels <<- c(appels, req$url)
      httr2::response(status_code = 200, body = charToRaw("zip"))
    })
    etat <- data.frame(plot_id = c("P001", "P002"),
                       terrain_envoye_le = c("2026-11-15T10:00:00Z", NA))
    tel <- function(e) groma_telecharger_resultats("https://groma.example", NULL,
                                                   c("P001", "P002"), "dl",
                                                   fichiers = "terrain.zip", etat = e)
    res <- tel(etat)
    # P002 n'a rien envoye : aucune requete
    expect_equal(length(appels), 1L)
    expect_equal(basename(res), "P001_terrain.zip")
    expect_equal(readLines(file.path("dl", "P001_terrain.envoye_le")), "2026-11-15T10:00:00Z")
    expect_equal(attr(res, "detail")$telecharge, c(TRUE, FALSE))

    # meme date : archive gardee, pas de requete, chemin rendu
    res <- tel(etat)
    expect_equal(length(appels), 1L)
    expect_equal(basename(res), "P001_terrain.zip")
    expect_false(attr(res, "detail")$telecharge[1])

    # date changee : retelechargee
    etat$terrain_envoye_le[1] <- "2026-11-15T11:00:00Z"
    res <- tel(etat)
    expect_equal(length(appels), 2L)
    expect_equal(readLines(file.path("dl", "P001_terrain.envoye_le")), "2026-11-15T11:00:00Z")

    # sans etat : tout est retelecharge, comme avant
    tel(NULL)
    expect_equal(length(appels), 4L)
    expect_error(tel(data.frame(x = 1)), "groma_etat_placettes")
  })
})

test_that("validation reports the share of taped diameters per plot", {
  g <- nemeton:::.iv_lire(iv_fixture("inventaire_video.gpkg"))
  g$arbres$dbh_source <- "estime"
  g$arbres$dbh_source[1] <- "mesure"
  v <- valider_inventaire_video(g)
  pid1 <- as.character(g$arbres$plot_id[1])
  ligne <- v$dbh_ruban[v$dbh_ruban$plot_id == pid1, ]
  expect_equal(ligne$n_ruban, 1L)
  expect_equal(ligne$part_ruban, 1 / ligne$n_arbres)

  ar <- data.frame(plot_id = c("P1", "P1", "P1", "P2"),
                   dbh_source = c("mesure", "estime", "mesure", "estime"),
                   etat_detection = c("provisoire", "provisoire", "faux_positif", "provisoire"))
  pr <- nemeton:::.iv_part_ruban(ar[ar$etat_detection != "faux_positif", ])
  expect_equal(pr$plot_id, c("P1", "P2"))
  expect_equal(pr$n_arbres, c(2L, 1L))
  expect_equal(pr$n_ruban, c(1L, 0L))
  expect_equal(pr$part_ruban, c(0.5, 0))
  # projet anterieur au schema 1.4.0 : inconnu, pas zero
  sans <- nemeton:::.iv_part_ruban(ar[, c("plot_id", "etat_detection")])
  expect_true(all(is.na(sans$n_ruban)) && all(is.na(sans$part_ruban)))
  expect_equal(nrow(nemeton:::.iv_part_ruban(NULL)), 0L)
})
