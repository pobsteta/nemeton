# Tests for Synthesis Module
# Phase 5: Project synthesis view

test_that("mod_synthesis_ui returns valid Shiny UI", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_synthesis_ui("synthesis")
      expect_s3_class(ui, "shiny.tag")
    }
  )
})

test_that("mod_synthesis_ui contains expected output elements", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_synthesis_ui("synthesis")
      ui_html <- as.character(ui)

      # Should contain project summary
      expect_true(grepl("synthesis-project_summary", ui_html))

      # Should contain radar plot
      expect_true(grepl("synthesis-radar_plot", ui_html))

      # Should contain summary table
      expect_true(grepl("synthesis-summary_table", ui_html))

      # Should contain download buttons
      expect_true(grepl("synthesis-download_pdf", ui_html))
      expect_true(grepl("synthesis-download_gpkg", ui_html))
    }
  )
})

test_that("mod_synthesis_ui works in English", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "en"),
    {
      ui <- nemeton:::mod_synthesis_ui("synthesis")
      ui_html <- as.character(ui)

      # Should contain English title
      expect_true(grepl("Project Synthesis", ui_html))
      expect_true(grepl("12 Families Radar", ui_html))
    }
  )
})

test_that("mod_synthesis_ui contains download buttons with correct classes", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_synthesis_ui("synthesis")
      ui_html <- as.character(ui)

      # PDF button has success class
      expect_true(grepl("btn-success", ui_html))
      # GeoPackage button has primary class
      expect_true(grepl("btn-primary", ui_html))
    }
  )
})

test_that("i18n keys for synthesis exist in both languages", {
  fr <- nemeton:::get_i18n("fr")
  en <- nemeton:::get_i18n("en")

  keys <- c("synthesis_title", "radar_title", "summary_table_title",
            "download_pdf", "download_gpkg", "no_project", "no_data",
            "missing_indicators_title")

  for (key in keys) {
    expect_true(fr$has(key), info = paste("FR missing:", key))
    expect_true(en$has(key), info = paste("EN missing:", key))
  }
})

test_that("i18n keys for indicator codes exist", {
  fr <- nemeton:::get_i18n("fr")
  en <- nemeton:::get_i18n("en")

  all_codes <- nemeton:::get_all_indicator_codes()

  for (code in all_codes) {
    key <- paste0("indicator_", code)
    expect_true(fr$has(key), info = paste("FR missing:", key))
    expect_true(en$has(key), info = paste("EN missing:", key))
  }
})

test_that("INDICATOR_FAMILIES have indicator_labels for all indicators", {
  families <- nemeton:::INDICATOR_FAMILIES

  for (fam_code in names(families)) {
    fam <- families[[fam_code]]
    expect_true("indicator_labels" %in% names(fam),
                info = paste("Family", fam_code, "missing indicator_labels"))

    for (ind in fam$indicators) {
      expect_true(ind %in% names(fam$indicator_labels),
                  info = paste("Family", fam_code, "missing label for", ind))
      expect_true("fr" %in% names(fam$indicator_labels[[ind]]),
                  info = paste("Family", fam_code, ind, "missing fr label"))
      expect_true("en" %in% names(fam$indicator_labels[[ind]]),
                  info = paste("Family", fam_code, ind, "missing en label"))
    }
  }
})
