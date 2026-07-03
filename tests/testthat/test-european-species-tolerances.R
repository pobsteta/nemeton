# test-european-species-tolerances.R — table essences UE (spec 027)

test_that("full table: ~193 species with the expected schema", {
  d <- european_species_tolerances()
  expect_s3_class(d, "data.frame")
  expect_gte(nrow(d), 190)
  expect_true(all(c("code", "species_sci", "species_fr", "type", "statut",
                    "tmax_tol_c", "vpd_tol_kpa", "drought_tol", "shade_tol",
                    "waterlog_tol", "frost_winter_min_c", "frost_late",
                    "frost_early", "air_humidity", "thermophily",
                    "confidence", "invasif", "notes") %in% names(d)))
  expect_false(any(duplicated(d$code)))
  # Mêmes axes que regeneration_tolerances(), dans des plages plausibles.
  expect_true(all(d$tmax_tol_c >= 20 & d$tmax_tol_c <= 46))
  expect_true(all(d$vpd_tol_kpa >= 1 & d$vpd_tol_kpa <= 5))
})

test_that("statut filter + the 'frm' convenience value", {
  frm <- european_species_tolerances(statut = "frm")
  expect_setequal(unique(frm$statut), c("frm_1999", "frm_2025"))
  expect_equal(nrow(frm),
               nrow(european_species_tolerances(statut = c("frm_1999", "frm_2025"))))
  atlas <- european_species_tolerances(statut = "atlas_jrc")
  expect_true(all(atlas$statut == "atlas_jrc"))
  expect_equal(nrow(frm) + nrow(atlas), nrow(european_species_tolerances()))
})

test_that("confidence and invasif filters", {
  expect_true(all(european_species_tolerances(confiance = "eleve")$confidence == "eleve"))
  full <- european_species_tolerances()
  no_inv <- european_species_tolerances(include_invasif = FALSE)
  expect_equal(nrow(no_inv), sum(!full$invasif))
  expect_false(any(no_inv$invasif))
})

test_that("type filter", {
  con <- european_species_tolerances(type = "conifere")
  expect_true(all(con$type == "conifere"))
})

test_that("a known species carries the source values", {
  d <- european_species_tolerances()
  aa <- d[d$code == "abies_alba", ]
  expect_equal(nrow(aa), 1L)
  expect_equal(aa$tmax_tol_c, 29)
  expect_equal(aa$vpd_tol_kpa, 1.6)
  expect_equal(aa$statut, "frm_1999")
  expect_equal(aa$confidence, "eleve")
})

test_that("confidence values are within the documented set", {
  expect_true(all(european_species_tolerances()$confidence %in%
                    c("eleve", "moyen", "faible")))
})
