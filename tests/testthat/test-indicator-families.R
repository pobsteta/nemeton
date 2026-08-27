# Tests de l'API publique de la table des familles d'indicateurs
# (BRIEF-indicator-families-export.md). L'app `nemetonshiny` s'appuie sur ces
# garanties pour construire son menu et ses libellés : les casser ici casse
# l'app en aval.

test_that("indicator_families() returns the 12 families in canonical order", {
  fams <- indicator_families()

  expect_s3_class(fams, "data.frame")
  expect_equal(nrow(fams), 12L)
  expect_equal(
    fams$code,
    c("C", "B", "W", "A", "F", "L", "T", "R", "S", "P", "E", "N")
  )
})

test_that("indicator_families() has non-empty names in both languages", {
  fams <- indicator_families()

  for (field in c("name", "name_fr", "name_en")) {
    expect_type(fams[[field]], "character")
    expect_false(any(is.na(fams[[field]])), info = field)
    expect_true(all(nzchar(fams[[field]])), info = field)
  }

  # `name` suit `lang`, `name_fr`/`name_en` sont toujours là
  expect_equal(indicator_families()$name, indicator_families()$name_fr)
  expect_equal(indicator_families(lang = "en")$name, indicator_families()$name_en)
  expect_equal(indicator_families(lang = "en")$name_fr, indicator_families()$name_fr)

  expect_equal(indicator_families(codes = "C")$name_fr, "Carbone & Vitalité")
  expect_equal(indicator_families(codes = "C", lang = "en")$name, "Carbon & Vitality")
})

test_that("indicators and column_names are aligned", {
  fams <- indicator_families()

  for (i in seq_len(nrow(fams))) {
    ind <- fams$indicators[[i]]
    cols <- fams$column_names[[i]]

    expect_type(ind, "character")
    expect_type(cols, "character")
    expect_length(cols, length(ind))
    expect_gt(length(ind), 0)
    expect_true(all(nzchar(ind)), info = fams$code[i])
    expect_true(all(nzchar(cols)), info = fams$code[i])
  }

  # Aucun doublon de colonne d'une famille à l'autre
  all_cols <- unlist(fams$column_names, use.names = FALSE)
  expect_equal(anyDuplicated(all_cols), 0L)

  all_codes <- unlist(fams$indicators, use.names = FALSE)
  expect_equal(anyDuplicated(all_codes), 0L)
})

test_that("indicator codes follow the <family><n> convention", {
  fams <- indicator_families()

  for (i in seq_len(nrow(fams))) {
    pattern <- paste0("^", fams$code[i], "[0-9]+$")
    expect_true(
      all(grepl(pattern, fams$indicators[[i]])),
      info = paste(fams$code[i], ":", paste(fams$indicators[[i]], collapse = " "))
    )
  }
})

test_that("every declared column is actually produced by the engine", {
  # Le test qui relie la table au moteur : chaque `column_name` doit être
  # produit par une fonction exportée du même nom, et être normalisable par
  # `normalize_indicator()` (donc reconnu par la chaîne de calcul).
  cols <- unlist(indicator_families()$column_names, use.names = FALSE)
  exported <- getNamespaceExports("nemeton")

  expect_equal(setdiff(cols, exported), character(0))

  for (col in cols) {
    expect_true(is.function(get(col, envir = asNamespace("nemeton"))), info = col)
    # Pas d'avertissement « no explicit 0-100 rule » (garde-fou spec 038)
    expect_silent(normalize_indicator(col, 50))
  }
})

test_that("F et L n'ont plus de code/slug croise", {
  # Ce test gardait le croisement des deux familles. L a ete decroisee en
  # 0.176.0 (renommage des fonctions, spec 045), F en 0.182.0 (correction de
  # la table, spec 049) : plus aucune ne diverge, et c'est desormais l'absence
  # de croisement qui est verrouillee.
  f <- indicator_families(codes = "F")
  expect_equal(f$indicators[[1]], c("F1", "F2"))
  expect_equal(f$column_names[[1]], c("indicateur_f1_fertilite", "indicateur_f2_erosion"))

  l <- indicator_families(codes = "L")
  expect_equal(l$indicators[[1]][1:2], c("L1", "L2"))
  expect_equal(
    l$column_names[[1]][1:2],
    c("indicateur_l1_effet_lisiere", "indicateur_l2_morcellement")
  )
})

test_that("labels and tooltips are complete and named by indicator code", {
  for (lang in c("fr", "en")) {
    fams <- indicator_families(lang = lang)
    for (i in seq_len(nrow(fams))) {
      for (field in c("labels", "tooltips")) {
        txt <- fams[[field]][[i]]
        expect_equal(names(txt), fams$indicators[[i]], info = fams$code[i])
        expect_false(any(is.na(txt)), info = paste(lang, fams$code[i], field))
        expect_true(all(nzchar(txt)), info = paste(lang, fams$code[i], field))
      }
    }
  }
})

test_that("indicator_families() subsets and validates codes", {
  expect_equal(indicator_families(codes = c("W", "C"))$code, c("W", "C"))
  expect_equal(indicator_families(codes = c("w", "c"))$code, c("W", "C"))
  expect_equal(nrow(indicator_families(codes = character(0))), 0L)

  expect_error(indicator_families(codes = "Z"), "Unknown family code")
  expect_error(indicator_families(codes = 1), "character vector")
  expect_error(indicator_families(lang = "de"))
})

test_that("indicator_labels() flattens the table consistently", {
  fams <- indicator_families()
  ind <- indicator_labels()

  expect_s3_class(ind, "data.frame")
  expect_equal(names(ind), c(
    "family", "family_column", "code", "column_name",
    "label", "label_fr", "label_en",
    "tooltip", "tooltip_fr", "tooltip_en",
    "doc_url", "doc_url_fr", "doc_url_en", "doc_lang"
  ))
  expect_equal(nrow(ind), length(unlist(fams$indicators, use.names = FALSE)))

  expect_equal(ind$code, unlist(fams$indicators, use.names = FALSE))
  expect_equal(ind$column_name, unlist(fams$column_names, use.names = FALSE))
  expect_equal(ind$family, rep(fams$code, lengths(fams$indicators)))

  expect_equal(ind$label, unlist(lapply(fams$labels, unname), use.names = FALSE))
  expect_equal(
    indicator_labels(lang = "en")$label,
    unlist(lapply(indicator_families(lang = "en")$labels, unname), use.names = FALSE)
  )

  lookup <- stats::setNames(ind$label, ind$column_name)
  expect_equal(lookup[["indicateur_c1_biomasse"]], "Biomasse carbone (tC/ha)")

  expect_equal(nrow(indicator_labels(codes = character(0))), 0L)
  expect_error(indicator_labels(codes = "Z"), "Unknown family code")
})


test_that("indicator_labels() expose doc_url selon ce que declare indicator_docs", {
  ind <- indicator_labels()

  # La colonne existe pour les 41 indicateurs et reste du texte : l'aval teste
  # `is.na()` pour decider d'afficher le lien, il ne doit jamais recevoir NULL
  # ni une liste.
  expect_type(ind$doc_url, "character")
  expect_equal(length(ind$doc_url), nrow(ind))

  c1 <- ind$doc_url[ind$code == "C1"]
  expect_length(c1, 1L)
  expect_false(is.na(c1))
  # URL absolue, batie sur le champ URL du DESCRIPTION, pas codee en dur ici.
  expect_match(c1, "^https?://")
  expect_match(c1, "articles/fiche-c1-biomasse_fr\\.html$")

  # Le test porte sur le MECANISME, pas sur la liste : `doc_url` est non-NA
  # exactement pour les indicateurs declares dans `indicator_docs`, et NA pour
  # tous les autres. Ajouter une fiche ne le fait donc pas tomber au rouge.
  declares <- unlist(lapply(INDICATOR_FAMILIES, function(f) names(f$indicator_docs)),
                     use.names = FALSE)
  expect_setequal(ind$code[!is.na(ind$doc_url)], declares)

  # Une famille sans aucune fiche ne casse pas. Le cas est verifie sur une
  # famille SYNTHETIQUE, pas sur une famille reelle : nommer "W" ici revenait
  # a figer le fait que W n'a pas de fiche, et l'assertion est effectivement
  # tombee au rouge le jour ou les fiches W ont ete ecrites — pour une bonne
  # nouvelle. C'est exactement le piege que le brief app decrit.
  fam_sans_docs <- list(indicators = c("X1", "X2"))
  sans <- .family_docs(fam_sans_docs, "fr")
  expect_true(all(is.na(sans$url)))
  expect_true(all(is.na(sans$lang)))

  # C1 n'a qu'une fiche francaise : une demande en anglais rend la page
  # francaise, et le dit (`doc_lang`). Le jour ou la fiche anglaise existe,
  # c'est cette assertion qui signalera qu'il faut la mettre a jour.
  en <- indicator_labels(lang = "en")
  expect_equal(en$doc_url[en$code == "C1"], c1)
  expect_equal(en$doc_lang[en$code == "C1"], "fr")
  expect_equal(ind$doc_lang[ind$code == "C1"], "fr")

  # doc_url_fr / doc_url_en sont presentes quelle que soit la langue demandee,
  # comme label_fr / label_en.
  expect_equal(en$doc_url_fr[en$code == "C1"], c1)
  # `doc_lang` et `doc_url` sont NA aux memes lignes, toujours.
  expect_equal(is.na(ind$doc_lang), is.na(ind$doc_url))

})

test_that("chaque fiche declaree pointe une vignette qui existe", {
  # C'est ce test qui rattrape une faute de frappe dans un `indicator_docs` :
  # sans lui, l'icone cote app ouvrirait un 404 silencieux.
  #
  # Il ne vaut que dans l'arbre source : sous R CMD check les tests tournent
  # depuis le paquet installe, ou `vignettes/` n'existe plus. Il se skippe
  # alors, plutot que de tomber au rouge pour une raison sans rapport.
  vdir <- testthat::test_path("..", "..", "vignettes")
  skip_if_not(dir.exists(vdir), "hors arbre source")

  ind <- indicator_labels()
  urls <- ind$doc_url[!is.na(ind$doc_url)]
  expect_true(length(urls) > 0L)

  for (u in urls) {
    rmd <- sub("\\.html$", ".Rmd", basename(u))
    expect_true(file.exists(file.path(vdir, rmd)),
                info = paste("vignette absente pour", u))
  }
})

test_that(".family_docs laisse passer une URL deja absolue", {
  fam <- list(
    indicators = c("X1", "X2"),
    indicator_docs = list(X1 = list(fr = "https://example.org/fiche.html"))
  )
  out <- .family_docs(fam, "fr",
                                base = "https://pobsteta.github.io/nemeton/")
  expect_equal(out$url, c("https://example.org/fiche.html", NA_character_))
  expect_equal(out$lang, c("fr", NA_character_))
})

test_that("une fiche absente dans la langue demandee retombe sur l'autre", {
  # Le repli est deliberé : une fiche en francais vaut mieux que pas de fiche.
  # `doc_lang` dit la langue REELLEMENT servie pour que l'interface le signale.
  fam_fr <- list(
    indicators = "X1",
    indicator_docs = list(X1 = list(fr = "articles/x.html"))
  )
  en <- .family_docs(fam_fr, "en", base = "https://ex.org/")
  expect_equal(en$url, "https://ex.org/articles/x.html")
  expect_equal(en$lang, "fr")

  # Les deux langues presentes : chacune sert la sienne, sans repli.
  fam_both <- list(
    indicators = "X1",
    indicator_docs = list(X1 = list(fr = "articles/x_fr.html",
                                    en = "articles/x_en.html"))
  )
  expect_equal(.family_docs(fam_both, "en", base = "https://ex.org/")$url,
               "https://ex.org/articles/x_en.html")
  expect_equal(.family_docs(fam_both, "en", base = "https://ex.org/")$lang,
               "en")

  # Entree vide ou malformee : NA des deux cotes, jamais une erreur.
  fam_bad <- list(indicators = "X1", indicator_docs = list(X1 = list(fr = "")))
  expect_true(is.na(.family_docs(fam_bad, "fr")$url))
  expect_true(is.na(.family_docs(fam_bad, "fr")$lang))
})

test_that("toute entree indicator_docs est une liste nommee par langue", {
  # Garde-fou de configuration : une entree ecrite en chaine nue
  # (`C1 = "articles/x.html"`) resterait silencieusement invisible cote app.
  # Ce test transforme la faute de frappe en echec de suite.
  for (fam in INDICATOR_FAMILIES) {
    docs <- fam$indicator_docs
    if (is.null(docs)) next
    expect_true(is.list(docs))
    expect_true(all(nzchar(names(docs))))
    expect_true(all(names(docs) %in% fam$indicators),
                info = paste("famille", fam$code))
    for (ic in names(docs)) {
      entry <- docs[[ic]]
      expect_true(is.list(entry), info = paste(fam$code, ic))
      expect_true(length(entry) > 0L, info = paste(fam$code, ic))
      expect_true(all(names(entry) %in% c("fr", "en")),
                  info = paste(fam$code, ic))
      expect_true(all(vapply(entry, function(h) {
        is.character(h) && length(h) == 1L && !is.na(h) && nzchar(h)
      }, logical(1))), info = paste(fam$code, ic))
    }
  }
})

test_that(".doc_base_url se termine toujours par une barre oblique", {
  expect_match(.doc_base_url(), "/$")
})

test_that("both languages are always returned, whatever lang", {
  fr <- indicator_families(lang = "fr")
  en <- indicator_families(lang = "en")

  # Les colonnes _fr / _en ne dépendent pas de `lang`
  for (col in c(
    "name_fr", "name_en", "description_fr", "description_en",
    "labels_fr", "labels_en", "tooltips_fr", "tooltips_en"
  )) {
    expect_identical(fr[[col]], en[[col]], info = col)
  }

  # `lang` ne pilote que les colonnes de confort
  expect_identical(fr$name, fr$name_fr)
  expect_identical(en$name, en$name_en)
  expect_identical(fr$description, fr$description_fr)
  expect_identical(en$description, en$description_en)
  expect_identical(fr$labels, fr$labels_fr)
  expect_identical(en$labels, en$labels_en)
  expect_identical(fr$tooltips, fr$tooltips_fr)
  expect_identical(en$tooltips, en$tooltips_en)

  ind_fr <- indicator_labels(lang = "fr")
  ind_en <- indicator_labels(lang = "en")
  for (col in c("label_fr", "label_en", "tooltip_fr", "tooltip_en")) {
    expect_identical(ind_fr[[col]], ind_en[[col]], info = col)
  }
  expect_identical(ind_fr$label, ind_fr$label_fr)
  expect_identical(ind_en$label, ind_en$label_en)
  expect_identical(ind_fr$tooltip, ind_fr$tooltip_fr)
  expect_identical(ind_en$tooltip, ind_en$tooltip_en)

  # Une langue ne doit pas être la copie de l'autre
  expect_false(identical(fr$name_fr, fr$name_en))
  expect_false(identical(ind_fr$label_fr, ind_fr$label_en))
})

test_that("descriptions are present and non-empty in both languages", {
  fams <- indicator_families()

  for (col in c("description", "description_fr", "description_en")) {
    expect_type(fams[[col]], "character")
    expect_false(any(is.na(fams[[col]])), info = col)
    expect_true(all(nzchar(fams[[col]])), info = col)
  }
  # Une description est une phrase, pas un mot-clé
  expect_true(all(nchar(fams$description_fr) > 20))
  expect_true(all(nchar(fams$description_en) > 20))
})

test_that("family_column matches the column produced by create_family_index()", {
  fams <- indicator_families()

  expect_identical(fams$family_column, get_famille_col(fams$code))
  expect_identical(get_famille_code(fams$family_column), fams$code)
  expect_equal(anyDuplicated(fams$family_column), 0L)
  expect_true(all(grepl("^famille_[a-z]+$", fams$family_column)))

  # Le lien avec le moteur : ce sont les colonnes que create_family_index()
  # ajoute réellement au jeu de données.
  data(massif_demo_units, package = "nemeton", envir = environment())
  expect_true(all(fams$family_column %in% names(massif_demo_units)))

  # indicator_labels() porte la même colonne, par famille
  ind <- indicator_labels()
  expect_identical(ind$family_column, get_famille_col(ind$family))
})

test_that("get_famille_col() / get_famille_code() round-trip and validate", {
  expect_identical(get_famille_col("C"), "famille_carbone")
  expect_identical(get_famille_col("c"), "famille_carbone")
  expect_identical(
    get_famille_col(c("C", "b", "N")),
    c("famille_carbone", "famille_biodiversite", "famille_naturalite")
  )
  expect_identical(get_famille_col(character(0)), character(0))
  expect_null(names(get_famille_col("C")))

  expect_error(get_famille_col("Z"), "Unknown family code")
  expect_error(get_famille_col(1), "character vector")

  expect_identical(get_famille_code("famille_eau"), "W")
  expect_identical(
    get_famille_code(c("famille_eau", "surface_m2")),
    c("W", NA_character_)
  )
})

test_that("indicator_families() is pure (no side effect, stable across calls)", {
  expect_identical(indicator_families(), indicator_families())
  expect_identical(indicator_labels(), indicator_labels())
})
