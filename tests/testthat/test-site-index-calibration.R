# Regression guard on the published-reference calibration of
# inst/extdata/site_index_curves.csv. Phase A audit of the
# historical Chapman-Richards + Bontemps Korf curves.
#
# For each species in site_index_reference_points(), asserts that
# H(age_ref, class_3) from the shipped CSV matches the published
# reference point to within 0.5 m. This catches any silent drift
# introduced by a future re-tweak of the a/k/p parameters in
# data-raw/site_index_curves.R or of the FASY Korf parameters.

test_that("site index curves match published class_3 reference points", {
  refs   <- site_index_reference_points()
  curves <- read_site_index_curves()

  tol <- 0.5  # metres

  for (i in seq_len(nrow(refs))) {
    sp        <- refs$species[i]
    age_ref   <- refs$age[i]
    h_ref     <- refs$h_class_3[i]

    row <- curves[curves$species == sp & curves$age == age_ref, ]
    expect_equal(nrow(row), 1L,
                 info = paste("missing CSV row for", sp, "age", age_ref))
    if (nrow(row) == 1L) {
      h_csv <- row$class_3
      expect_lt(
        abs(h_csv - h_ref), tol,
        label = sprintf(
          "|CSV H(%d, class_3) - ref| for %s (source: %s)",
          age_ref, sp, refs$source[i]
        )
      )
    }
  }
})


test_that("site_index_reference_points covers every calibrated species", {
  refs        <- site_index_reference_points()
  species_in_csv <- setdiff(list_site_index_species(),
                            c("BROADLEAF_GENUS", "CONIFER_GENUS",
                              # FASY_NO / FASY_NE are regional variants
                              # of FASY; the mean FASY is the reference.
                              "FASY_NO", "FASY_NE"))
  expect_setequal(refs$species, species_in_csv)
})
