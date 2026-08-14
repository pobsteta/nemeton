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

test_that("F and L keep their legacy code/slug pairing", {
  # Garde-fou : le code court et le slug de colonne divergent sur ces deux
  # familles. Un « alignement » naïf casserait les libellés en aval.
  f <- indicator_families(codes = "F")
  expect_equal(f$indicators[[1]], c("F1", "F2"))
  expect_equal(f$column_names[[1]], c("indicateur_f2_erosion", "indicateur_f1_fertilite"))

  l <- indicator_families(codes = "L")
  expect_equal(l$indicators[[1]][1:2], c("L1", "L2"))
  expect_equal(
    l$column_names[[1]][1:2],
    c("indicateur_l2_fragmentation", "indicateur_l1_sylvosphere")
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
    "tooltip", "tooltip_fr", "tooltip_en"
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
