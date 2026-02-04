# Tests for Family Module
# Phase 5: Generic family indicator module

test_that("mod_family_ui returns valid Shiny UI for each family", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("bsicons")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      for (code in nemeton:::get_family_codes()) {
        ui <- nemeton:::mod_family_ui(paste0("family_", code), code)
        expect_s3_class(ui, "shiny.tag")
      }
    }
  )
})

test_that("mod_family_ui contains expected output elements", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("bsicons")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_family_ui("family_C", "C")
      ui_html <- as.character(ui)

      # Should contain map/plot outputs
      expect_true(grepl("family_C-map1", ui_html))
      expect_true(grepl("family_C-plot2_ui", ui_html))

      # Should contain table output
      expect_true(grepl("family_C-indicator_table", ui_html))

      # Should contain missing warning output
      expect_true(grepl("family_C-missing_warning", ui_html))
    }
  )
})

test_that("mod_family_ui works in English", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("bsicons")

  with_mocked_bindings(
    get_app_options = function() list(language = "en"),
    {
      ui <- nemeton:::mod_family_ui("family_B", "B")
      ui_html <- as.character(ui)

      # Should contain English family name
      expect_true(grepl("Biodiversity", ui_html))
    }
  )
})

test_that("get_indicator_cols excludes metadata columns", {
  df <- data.frame(
    nemeton_id = 1:3,
    id = 1:3,
    C1 = runif(3),
    C2 = runif(3),
    geometry = rep("POINT(0 0)", 3)
  )

  result <- nemeton:::get_indicator_cols(df)
  expect_equal(result, c("C1", "C2"))
})

test_that("clean_indicator_label strips _norm suffix", {
  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      i18n <- nemeton:::get_i18n("fr")
      label <- nemeton:::clean_indicator_label("C1_norm", i18n)
      # Should match indicator_C1 translation
      expect_equal(label, "Biomasse carbone (tC/ha)")
    }
  )
})

test_that("clean_indicator_label falls back to humanized name", {
  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      i18n <- nemeton:::get_i18n("fr")
      label <- nemeton:::clean_indicator_label("UNKNOWN_IND", i18n)
      expect_equal(label, "UNKNOWN IND")
    }
  )
})

test_that("clean_indicator_label resolves long-form column names", {
  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      i18n <- nemeton:::get_i18n("fr")
      label <- nemeton:::clean_indicator_label("carbon_biomass", i18n)
      expect_equal(label, "Biomasse carbone (tC/ha)")

      label_en <- nemeton:::clean_indicator_label("water_twi", nemeton:::get_i18n("en"))
      expect_equal(label_en, "Topographic Wetness Index")
    }
  )
})

test_that("mod_family_ui contains AI generate button", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("bsicons")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_family_ui("family_C", "C")
      ui_html <- as.character(ui)

      # Should contain AI generate button
      expect_true(grepl("family_C-ai_generate", ui_html))
      expect_true(grepl("robot", ui_html))
    }
  )
})

test_that("build_analysis_prompt returns valid prompt string", {
  family_config <- nemeton:::get_family_config("C")
  ind_data <- data.frame(
    nemeton_id = c("p1", "p2", "p3"),
    carbon_biomass_norm = c(0.5, 0.7, 0.3),
    carbon_ndvi_norm = c(0.8, 0.6, 0.9)
  )

  prompt <- nemeton:::build_analysis_prompt(family_config, ind_data, "fran\u00e7ais")
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 0)
  expect_true(grepl("3 parcelles", prompt))
  expect_true(grepl("carbon_biomass_norm", prompt))
  expect_true(grepl("carbon_ndvi_norm", prompt))
  expect_true(grepl("min=", prompt))
  expect_true(grepl("mean=", prompt))
})

test_that("build_analysis_prompt handles all-NA indicator", {
  family_config <- nemeton:::get_family_config("W")
  ind_data <- data.frame(
    nemeton_id = c("p1", "p2"),
    water_network_norm = c(NA_real_, NA_real_)
  )

  prompt <- nemeton:::build_analysis_prompt(family_config, ind_data, "English")
  expect_true(grepl("no data", prompt))
})

test_that("create_llm_chat errors on unknown provider", {
  with_mocked_bindings(
    get_app_config = function(key, default = NULL) {
      if (key == "llm_provider") return("unknown_provider")
      if (key == "llm_models") return(list())
      default
    },
    {
      expect_error(
        nemeton:::create_llm_chat("test prompt"),
        "Unknown LLM provider: 'unknown_provider'"
      )
    }
  )
})

test_that("get_llm_api_key_var returns correct env var names", {
  expect_equal(nemeton:::get_llm_api_key_var("anthropic"), "ANTHROPIC_API_KEY")
  expect_equal(nemeton:::get_llm_api_key_var("mistral"), "MISTRAL_API_KEY")
  expect_equal(nemeton:::get_llm_api_key_var("openai"), "OPENAI_API_KEY")
  expect_equal(nemeton:::get_llm_api_key_var("google"), "GOOGLE_API_KEY")
  expect_equal(nemeton:::get_llm_api_key_var("deepseek"), "DEEPSEEK_API_KEY")
  expect_null(nemeton:::get_llm_api_key_var("ollama"))
  expect_null(nemeton:::get_llm_api_key_var("nonexistent"))
})

test_that("mod_family_ui returns valid UI for unknown family", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  with_mocked_bindings(
    get_app_options = function() list(language = "fr"),
    {
      ui <- nemeton:::mod_family_ui("family_Z", "Z")
      ui_html <- as.character(ui)
      expect_true(grepl("Unknown family", ui_html))
    }
  )
})
