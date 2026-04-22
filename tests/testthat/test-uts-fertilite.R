# tests/testthat/test-uts-fertilite.R
# Integrity checks on the UTS → fertility lookup table shipped in
# inst/extdata/uts_fertilite_fr.csv (Phase B of the F1 GIS Sol wiring).

uts_csv_path <- function() {
  system.file("extdata", "uts_fertilite_fr.csv", package = "nemeton",
              mustWork = TRUE)
}

uts_table <- function() {
  utils::read.csv(uts_csv_path(), stringsAsFactors = FALSE,
                  fileEncoding = "UTF-8")
}

test_that("uts_fertilite_fr.csv ships and loads cleanly", {
  expect_true(file.exists(uts_csv_path()))
  tbl <- uts_table()
  expect_s3_class(tbl, "data.frame")
  expect_gte(nrow(tbl), 50)  # Target V1: 50-80 UTS
})

test_that("uts_fertilite_fr.csv has the expected schema", {
  tbl <- uts_table()
  expected_cols <- c("rpf_code", "rpf_name", "wrb_code",
                     "fertility_class", "fertility_score",
                     "texture_dom", "drainage", "depth_cm",
                     "ph_range", "forest_note",
                     "source_biblio", "notes")
  expect_equal(names(tbl), expected_cols)
})

test_that("rpf_code values are unique and non-empty", {
  tbl <- uts_table()
  expect_true(all(nzchar(tbl$rpf_code)))
  expect_equal(anyDuplicated(tbl$rpf_code), 0L)
})

test_that("fertility_class is an integer in [1, 5]", {
  tbl <- uts_table()
  expect_true(all(tbl$fertility_class %in% 1:5))
})

test_that("fertility_score follows the 1-5 → 15/35/55/75/90 grid", {
  tbl <- uts_table()
  expected_grid <- c(`1` = 15, `2` = 35, `3` = 55, `4` = 75, `5` = 90)
  expect_equal(tbl$fertility_score,
               unname(expected_grid[as.character(tbl$fertility_class)]))
})

test_that("rpf_name, source_biblio, and forest_note are non-empty", {
  tbl <- uts_table()
  expect_true(all(nzchar(tbl$rpf_name)))
  expect_true(all(nzchar(tbl$source_biblio)))
  expect_true(all(nzchar(tbl$forest_note)))
})

test_that("all 14 AFES families are represented", {
  tbl <- uts_table()
  # AFES 2008 Référentiel Pédologique — Grands Ensembles de Référence.
  # Prefix mapping lets us verify coverage without parsing rpf_name.
  family_prefixes <- list(
    Brunisols   = "^BRUN_",
    Luvisols    = "^LUV_",
    Podzosols   = "^POD_",
    Alocrisols  = "^ALO_",
    Calcosols   = "^CAL_",
    Calcisols   = "^CAS_",
    Fluviosols  = "^FLU_",
    Colluviosols = "^COL_",
    Rankosols   = "^RAN_",
    Arenosols   = "^ARE_",
    Redoxisols  = "^RDX_",
    Reductisols = "^RDS_",
    Peyrosols   = "^PEY_",
    Organosols  = "^ORG_",
    # AFES groups Lithosols + Regosols together; Anthroposols is its own family.
    Regosols_lithosols = "^(LIT|REG)_",
    Anthroposols = "^ANT_"
  )
  for (fam in names(family_prefixes)) {
    matches <- grepl(family_prefixes[[fam]], tbl$rpf_code)
    expect_true(any(matches),
                info = sprintf("Family '%s' is missing from the table", fam))
  }
})

test_that("fertility distribution is forestry-plausible", {
  tbl <- uts_table()
  class_counts <- table(tbl$fertility_class)
  # At least one UTS in each of the five classes — a table with no
  # class-1 or no class-5 entries would be a sign of bias.
  expect_true(all(1:5 %in% as.integer(names(class_counts))))
  # The bulk of French forest UTS sit in classes 2-4; so classes 3 and 4
  # together should weigh more than class 1 or class 5 alone.
  mid_weight <- sum(class_counts[c("3", "4")])
  tail_weight <- max(class_counts[c("1", "5")])
  expect_gt(mid_weight, tail_weight)
})
