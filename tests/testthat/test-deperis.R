# Tournee DEPERIS (mission 061) : creer_tournee_deperis() et importer_deperis(), joues sur
# les cas communs `fixtures/echange/` de Ramulus (copies dans fixtures/deperis-v1/, sans reseau).

dp_fix <- function(...) normalizePath(testthat::test_path("fixtures", "deperis-v1", ...), mustWork = TRUE)
dp_schema_fichier <- function() normalizePath(file.path(testthat::test_path("..", "..", "inst", "schemas", "deperis-v1.schema.json")), mustWork = TRUE)

dp_cas <- function() {
  d <- sort(list.dirs(dp_fix(), recursive = FALSE))
  d[file.exists(file.path(d, "attendu.json"))]
}
dp_attendu <- function(d) jsonlite::read_json(file.path(d, "attendu.json"), simplifyVector = FALSE)

dp_deps <- function() {
  for (p in c("DBI", "RSQLite", "stringi", "openssl", "sf")) testthat::skip_if_not_installed(p)
}

dp_importer <- function(d, a) {
  fich <- file.path(d, unlist(a$fichiers))
  dep <- if (!is.null(a$depart)) normalizePath(file.path(d, a$depart)) else NULL
  if (is.null(dep)) {
    # cas lus par Ramulus a l'ouverture d'une tournee : meme controle, sans comparaison au depart
    r <- nemeton:::.dp_controler(nemeton:::.dp_lire_paquet(fich[1]), NULL)
    return(list(verdict = r$statut, motifs = r$motifs))
  }
  importer_deperis(fich, dep, operateur = a$fusion$operateur, version_ramulus = a$fusion$version_ramulus)
}

# --- empreintes : la copie du schema et des cas ne s'edite pas a la main ----------------

dp_sha <- function(f) {
  con <- file(f, "rb")
  on.exit(close(con))
  paste0(as.character(openssl::sha256(con)))
}

dp_lire_empreintes <- function(readme) {
  l <- readLines(readme, encoding = "UTF-8")
  m <- regmatches(l, regexec("^\\| `([^`]+)` \\| `([0-9a-f]{64})` \\|$", l))
  m <- m[lengths(m) == 3L]
  stats::setNames(vapply(m, `[`, "", 3L), vapply(m, `[`, "", 2L))
}

test_that("le schema copie de Ramulus a l'empreinte notee dans inst/schemas/README.md", {
  dp_deps()
  e <- dp_lire_empreintes(file.path(dirname(dp_schema_fichier()), "README.md"))
  expect_named(e, "deperis-v1.schema.json")
  expect_identical(dp_sha(dp_schema_fichier()), unname(e[["deperis-v1.schema.json"]]))
})

test_that("chaque fichier des cas communs copies a l'empreinte du README", {
  dp_deps()
  e <- dp_lire_empreintes(dp_fix("README.md"))
  fichiers <- setdiff(list.files(dp_fix(), recursive = TRUE), "README.md")
  expect_setequal(names(e), fichiers)
  vus <- vapply(names(e), function(f) dp_sha(dp_fix(f)), "")
  expect_identical(unname(vus), unname(e))
})

test_that("l'abaque et les essences du schema sont ceux des referentiels de Ramulus", {
  ab <- utils::read.csv2(dp_fix("referentiels", "abaque.csv"), colClasses = "character")
  m <- nemeton:::.dp_abaque()
  for (mb in 0:5) for (s in 0:5) expect_identical(unname(m[mb + 1L, s + 1L]), ab[ab$mb == as.character(mb), paste0("second_", s)])
  ess <- utils::read.csv2(dp_fix("referentiels", "essences.csv"), colClasses = "character", encoding = "UTF-8")
  e <- nemeton:::.dp_essences()
  expect_equal(nrow(e), 19L)
  expect_identical(e$type[match(ess$essence, e$essence)], ess$type)
  # valeurs de contrôle écrites à la main (fiches DSF 2025, page 1)
  expect_identical(nemeton:::.dp_classe(c(0, 5, 2, 3, 4), c(0, 0, 3, 4, 3)), c("A", "F", "D", "F", "F"))
})

# --- les cas communs : un test par cas ---------------------------------------------------

for (d in dp_cas()) {
  local({
    d <- d
    a <- dp_attendu(d)
    test_that(paste0("cas ", a$cas, " : ", a$attendu, if (length(a$motifs)) paste0(" (", paste(as.character(unlist(a$motifs)), collapse = ", "), ")")), {
      dp_deps()
      if (!is.null(a$enregistrement)) {
        skip(paste0("cas ", a$cas, " : saisie d'une note par Ramulus (README des cas : un lecteur de fichier saute les cas `enregistrement`)"))
      }
      r <- dp_importer(d, a)
      expect_identical(r$verdict, a$attendu)
      expect_setequal(r$motifs, as.character(unlist(a$motifs)))
      if (identical(a$lecteur, "nemeton")) {
        # tout ou rien : un refus n'importe rien
        expect_identical(isTRUE(r$importe), a$attendu != "refuse")
        if (a$attendu == "refuse") {
          expect_null(r$placettes)
          expect_null(r$notes)
        }
      }
    })
  })
}

test_that("l'instantane lu de chaque fichier des cas est celui qu'ecrit Ramulus", {
  dp_deps()
  n <- 0L
  for (d in dp_cas()) {
    for (f in list.files(d, pattern = "\\.(gpkg|zip)$", full.names = TRUE)) {
      ref <- jsonlite::read_json(sub("\\.(gpkg|zip)$", ".instantane.json", f), simplifyVector = FALSE)
      p <- nemeton:::.dp_lire_paquet(f)
      expect_null(p$erreur, info = f)
      if (!is.null(p$inst)) expect_true(nemeton:::.dp_egal(p$inst, ref), info = f)
      n <- n + 1L
    }
  }
  expect_equal(n, 44L)
})

# --- fusion : A5, F1, S3 ------------------------------------------------------------------

test_that("la fusion redonne le paquet attendu, ecarte ce qui est en conflit et le dit", {
  dp_deps()
  for (cas in c("A5-fusion-deux-operateurs", "F1-fusion-conflit-centre", "S3-fusion-conflit-uuid")) {
    d <- dp_fix(cas)
    a <- dp_attendu(d)
    fich <- file.path(d, unlist(a$fichiers))
    dep <- normalizePath(file.path(d, a$depart))
    for (f in fich) expect_identical(importer_deperis(f, dep)$verdict, a$fusion$chaque_fichier, info = f)
    r <- dp_importer(d, a)
    expect_identical(r$verdict, a$attendu, info = cas)
    attendu_ecartes <- vapply(a$fusion$ecartes, function(e) paste(e$objet, e$cle), "")
    expect_setequal(paste(r$conflits$objet, r$conflits$cle), attendu_ecartes)
    expect_setequal(r$placettes_signalees, as.character(unlist(a$fusion$placettes_signalees)))
    res <- nemeton:::.dp_lire_paquet(normalizePath(file.path(d, a$fusion$resultat)))$inst
    expect_true(nemeton:::.dp_egal(r$paquet$inst$tables, res$tables), info = cas)
    expect_true(nemeton:::.dp_egal(r$paquet$inst$photos_du_paquet, res$photos_du_paquet), info = cas)
    # l'ordre des paquets ne change pas l'union
    r2 <- importer_deperis(rev(fich), dep, operateur = a$fusion$operateur, version_ramulus = a$fusion$version_ramulus)
    expect_true(nemeton:::.dp_egal(r$paquet$inst$tables, r2$paquet$inst$tables), info = cas)
  }
})

test_that("un conflit de centre garde la placette, ses notes et la signale", {
  dp_deps()
  d <- dp_fix("F1-fusion-conflit-centre")
  r <- dp_importer(d, dp_attendu(d))
  expect_equal(nrow(r$placettes), 3L)
  expect_identical(r$placettes$etat[r$placettes$plot_id == "P001"], "notee")
  expect_equal(sum(r$notes$plot_id == "P001"), 4L)
  expect_false("P001" %in% r$centres$plot_id)
  expect_identical(r$placettes_signalees, "P001")
  expect_true(any(grepl("placette P001 signal", r$messages)))
})

test_that("l'import est rejouable sans doublon", {
  dp_deps()
  d <- dp_fix("A3-rendu")
  zip <- file.path(d, "EXEMPLE-2027-01.zip")
  dep <- dp_fix("A1-tournee-depart", "deperis.gpkg")
  r1 <- importer_deperis(zip, dep)
  r2 <- importer_deperis(zip, dep, precedent = r1)
  r3 <- importer_deperis(c(zip, zip), dep)
  for (r in list(r2, r3)) {
    expect_identical(r$verdict, "accepte")
    expect_equal(nrow(r$notes), 9L)
    expect_equal(nrow(r$centres), 3L)
    expect_equal(nrow(r$photos), 9L)
    expect_setequal(r$notes$uuid, r1$notes$uuid)
  }
  expect_error(importer_deperis(zip, dep, precedent = importer_deperis(file.path(dp_fix("R2-classe-differente-abaque"), "EXEMPLE-2027-01.zip"), dep)), "precedent")
})

test_that("importer_deperis recalcule la classe, copie les photos et rend des sf en EPSG:2154", {
  dp_deps()
  r <- importer_deperis(file.path(dp_fix("A3-rendu"), "EXEMPLE-2027-01.zip"), dp_fix("A1-tournee-depart", "deperis.gpkg"),
                        dossier_photos = file.path(withr::local_tempdir(), "ph"))
  expect_s3_class(r$placettes, "sf")
  expect_equal(sf::st_crs(r$placettes)$epsg, 2154L)
  expect_equal(unname(sf::st_coordinates(r$placettes)[1, ]), c(856560.23, 6670351.34))
  expect_identical(r$notes$classe, nemeton:::.dp_classe(r$notes$mb, r$notes$second))
  expect_true(all(file.exists(r$photos$chemin)))
  expect_identical(r$nature, "premiere")
  expect_output(print(r), "accepte")
  expect_error(importer_deperis(file.path(dp_fix("A3-rendu"), "EXEMPLE-2027-01.zip")), "depart")
})

# --- contre-epreuves : un test rougit si l'abaque ou le refus change ----------------------

test_that("contre-epreuve : une case de l'abaque modifiee fait refuser un paquet jusque-la accepte", {
  dp_deps()
  zip <- file.path(dp_fix("A3-rendu"), "EXEMPLE-2027-01.zip")
  dep <- dp_fix("A1-tournee-depart", "deperis.gpkg")
  expect_identical(importer_deperis(zip, dep)$verdict, "accepte")
  s <- nemeton:::.dp_schema()
  for (i in seq_along(s[["$defs"]]$abaque$anyOf)) {
    b <- s[["$defs"]]$abaque$anyOf[[i]]$properties
    if (b$mb$const == 2L && b$second$const == 3L) s[["$defs"]]$abaque$anyOf[[i]]$properties$classe$const <- "C" # D -> C
  }
  testthat::local_mocked_bindings(.dp_schema = function() s, .package = "nemeton")
  r <- importer_deperis(zip, dep)
  expect_identical(r$verdict, "refuse")
  expect_true("classe_differente_abaque" %in% r$motifs)
})

test_that("contre-epreuve : aucun cas refuse n'est accepte, et un controle neutralise le laisserait passer", {
  dp_deps()
  dep <- dp_fix("A1-tournee-depart", "deperis.gpkg")
  r2 <- importer_deperis(file.path(dp_fix("R2-classe-differente-abaque"), "EXEMPLE-2027-01.zip"), dep)
  expect_identical(r2$verdict, "refuse")
  expect_false(r2$importe)
  # contrôle neutralisé (aucune règle de schéma) : R2 serait accepté, donc le test ci-dessus détecte bien le refus
  testthat::local_mocked_bindings(.dp_val = function(...) list(), .package = "nemeton")
  expect_identical(importer_deperis(file.path(dp_fix("R2-classe-differente-abaque"), "EXEMPLE-2027-01.zip"), dep)$verdict, "accepte")
})

# --- creer_tournee_deperis() --------------------------------------------------------------

dp_plan <- function() {
  p <- sf::st_read(dp_fix("A1-tournee-depart", "deperis.gpkg"), "placettes", quiet = TRUE)
  plan <- p[, c("plot_id", "wgt", "ip", "stratum", "strat_type", "nb_arbres", "collecte_photos", "contre_notation")]
  plan$collecte_photos <- as.logical(plan$collecte_photos)
  plan$contre_notation <- as.logical(plan$contre_notation)
  plan
}
dp_t <- function(x) as.POSIXct(x, tz = "UTC")

test_that("creer_tournee_deperis redonne la tournee de depart A1 (instantane identique)", {
  dp_deps()
  out <- creer_tournee_deperis(dp_plan(), "EXEMPLE-2027-01", saison = "ETE", dossier = withr::local_tempdir(),
                               prepare_le = dp_t("2027-06-15 08:00:00"), delai_contre_notation_jours = 15L, version_nemeton = "exemple")
  ref <- jsonlite::read_json(dp_fix("A1-tournee-depart", "deperis.instantane.json"), simplifyVector = FALSE)
  expect_true(nemeton:::.dp_egal(nemeton:::.dp_instantane(out), ref))
  expect_identical(attr(out, "contre_notation"), "P002")
  expect_identical(nemeton:::.dp_controler(nemeton:::.dp_lire_paquet(out))$statut, "accepte")
  # le fichier s'ouvre avec GDAL ; ni index spatial ni colonne `date`
  l <- sf::st_layers(out)
  expect_setequal(l$name, c("placettes", "centres", "tournee", "notations"))
  con <- DBI::dbConnect(RSQLite::SQLite(), out)
  on.exit(DBI::dbDisconnect(con))
  expect_equal(nrow(DBI::dbGetQuery(con, "SELECT 1 FROM sqlite_master WHERE name LIKE 'rtree%'")), 0L)
  expect_identical(DBI::dbGetQuery(con, "PRAGMA application_id")[[1]], 1196444487L)
  expect_identical(DBI::dbGetQuery(con, "PRAGMA user_version")[[1]], 10400L)
  expect_equal(unname(sf::st_coordinates(sf::st_read(out, "placettes", quiet = TRUE))[1, ]), c(856560.23, 6670351.34))
})

test_that("creer_tournee_deperis ecrit la contre-notation A2 depuis l'import de A3", {
  dp_deps()
  imp <- importer_deperis(file.path(dp_fix("A3-rendu"), "EXEMPLE-2027-01.zip"), dp_fix("A1-tournee-depart", "deperis.gpkg"))
  out <- creer_tournee_deperis(dp_plan(), "EXEMPLE-2027-01-CN", "contre_notation", dossier = withr::local_tempdir(),
                               contre_notation = imp, prepare_le = dp_t("2027-07-08 08:00:00"),
                               delai_contre_notation_jours = 15L, version_nemeton = "exemple")
  ref <- jsonlite::read_json(dp_fix("A2-tournee-contre-notation", "deperis.instantane.json"), simplifyVector = FALSE)
  inst <- nemeton:::.dp_instantane(out)
  expect_true(nemeton:::.dp_egal(inst, ref))
  expect_false("notations" %in% names(inst$tables)) # aucune première note
  expect_identical(inst$tables$placettes$lignes[[1]]$plot_id, "P002")
  # sans centre du premier operateur, une placette ne peut pas etre contre-notee
  imp$centres <- imp$centres[imp$centres$plot_id != "P002", ]
  expect_error(creer_tournee_deperis(dp_plan(), "X-CN", "contre_notation", dossier = withr::local_tempdir(), contre_notation = imp), "no centre")
  expect_error(creer_tournee_deperis(dp_plan(), "X-CN", "contre_notation", dossier = withr::local_tempdir()), "importer_deperis")
})

test_that("le tirage de la contre-notation est reproductible, au moins une placette, 5 %", {
  dp_deps()
  set.seed(1)
  n <- 60L
  plan <- sf::st_as_sf(data.frame(plot_id = sprintf("Q%03d", sample(n)), nb_arbres = 4L,
                                  x = 856000 + seq_len(n) * 40, y = 6670000), coords = c("x", "y"), crs = 2154)
  f <- function(graine, p = plan) attr(creer_tournee_deperis(p, "T", dossier = withr::local_tempdir(), contre_notation = 0.05, graine = graine), "contre_notation")
  a <- f(7L)
  expect_length(a, 3L)
  expect_identical(a, f(7L))
  expect_identical(a, f(7L, plan[rev(seq_len(n)), ])) # indépendant de l'ordre des lignes
  expect_false(identical(a, f(8L)))
  expect_length(attr(creer_tournee_deperis(plan[1:3, ], "T", dossier = withr::local_tempdir(), contre_notation = 0.05), "contre_notation"), 1L)
  expect_identical(attr(creer_tournee_deperis(plan, "T", dossier = withr::local_tempdir(), contre_notation = c("Q001")), "contre_notation"), "Q001")
})

test_that("creer_tournee_deperis refuse un plan hors format", {
  dp_deps()
  p <- dp_plan()
  dos <- function() withr::local_tempdir()
  expect_error(creer_tournee_deperis(sf::st_transform(p, 4326), "T", dossier = dos()), "2154")
  expect_error(creer_tournee_deperis(p, "T e s t", dossier = dos()), "code")
  q <- p; q$etat <- "notee"
  expect_error(creer_tournee_deperis(q, "T", dossier = dos()), "Reserved")
  q <- p; q$date <- "x"
  expect_error(creer_tournee_deperis(q, "T", dossier = dos()), "date")
  q <- p; q$plot_id[2] <- q$plot_id[1]
  expect_error(creer_tournee_deperis(q, "T", dossier = dos()), "plot_id")
  q <- p; sf::st_geometry(q) <- sf::st_sfc(lapply(seq_len(nrow(q)), function(i) sf::st_point(c(6670351, 856560))), crs = 2154)
  expect_error(creer_tournee_deperis(q, "T", dossier = dos()), "outside")
  q <- p; q$nb_arbres <- NULL
  expect_error(creer_tournee_deperis(q, "T", dossier = dos()), "nb_arbres")
  dd <- dos()
  creer_tournee_deperis(p, "T", dossier = dd)
  expect_error(creer_tournee_deperis(p, "T", dossier = dd), "already exists")
  expect_no_error(creer_tournee_deperis(p, "T", dossier = dd, overwrite = TRUE))
})

test_that("le texte ecrit est en NFC et le fichier rendu au depart est intact a l'import", {
  dp_deps()
  p <- dp_plan()
  p$stratum <- c("éte", "S2", "S1") # « é » décomposé
  out <- creer_tournee_deperis(p, "T", dossier = withr::local_tempdir())
  expect_identical(nemeton:::.dp_controler(nemeton:::.dp_lire_paquet(out))$statut, "accepte")
  v <- sf::st_read(out, "placettes", quiet = TRUE)$stratum
  expect_identical(v[1], "éte")
})
