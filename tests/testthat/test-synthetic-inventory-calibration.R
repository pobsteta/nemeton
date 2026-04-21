# Regression guard on the Charru-derived calibration of the
# H_dom -> D_g power law used by estimate_dq_from_hdom().
#
# For each of the 8 species covered by both Charru et al. 2012
# Table 1 (mean D_g, IFN) and Charru et al. 2017 Table 1 (mean
# H_0, IFN), asserts that feeding the mean H_0 back through
# estimate_dq_from_hdom() reproduces the mean D_g within 1 cm.
# Catches silent drift if someone retweaks the (a, b) parameters
# in synthetic_inventory.R.

# Species | H_0 mean | D_g mean (cm)
# --------|----------|---------------
# FASY    |  24.7    |  27.3
# QUPE    |  23.3    |  23.0
# QURO    |  21.3    |  26.0
# PIAB    |  24.5    |  29.3
# ABAL    |  25.3    |  29.6
# PISY    |  15.0    |  22.2
# QUPU    |  14.2    |  21.2
# PIHA    |  12.3    |  23.5
#
# Sources:
#   Charru M., Seynave I., Morneau F., Rivoire M., Bontemps J.-D.
#   (2012). Significant differences and curvilinearity in the
#   self-thinning relationships of 11 temperate tree species.
#   Annals of Forest Science 69(2), Table 1.
#
#   Charru M., Seynave I., Hervé J.-C., Bertrand R., Bontemps J.-D.
#   (2017). Recent growth changes in Western European forests
#   are driven by climate warming. Annals of Forest Science
#   74:33, Table 1.

test_that("estimate_dq_from_hdom matches the IFN mean Dg at mean H_0 within 1 cm", {
  refs <- data.frame(
    species = c("FASY", "QUPE", "QURO", "PIAB",
                "ABAL", "PISY", "QUPU", "PIHA"),
    h0_mean = c(24.7,  23.3,  21.3,  24.5,
                25.3,  15.0,  14.2,  12.3),
    dq_mean = c(27.3,  23.0,  26.0,  29.3,
                29.6,  22.2,  21.2,  23.5),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(nrow(refs))) {
    est <- estimate_dq_from_hdom(refs$h0_mean[i], refs$species[i])
    expect_lt(
      abs(est - refs$dq_mean[i]), 1.0,
      label = sprintf("|Dg_est(%s) - Dg_IFN| at H_0=%.1f m",
                      refs$species[i], refs$h0_mean[i])
    )
  }
})


test_that("estimate_dq_from_hdom clamps to species Dg range on extreme H_dom", {
  # Very small H_dom (7 m) should still be >= dq_min of each species.
  # Very large H_dom (60 m) should be <= dq_max.
  tab <- h_to_dq_params()
  for (i in seq_len(nrow(tab))) {
    sp <- tab$species[i]
    # At H=7m (just above the 6m cutoff), a species with dq_min=20
    # may not naturally reach that value; the clamp should kick in.
    dq_low  <- estimate_dq_from_hdom(7, sp)
    dq_high <- estimate_dq_from_hdom(60, sp)
    expect_gte(dq_low,  tab$dq_min[i],
               label = sprintf("%s Dg at H=7m is at least dq_min=%d",
                                sp, tab$dq_min[i]))
    expect_lte(dq_high, tab$dq_max[i],
               label = sprintf("%s Dg at H=60m is at most dq_max=%d",
                                sp, tab$dq_max[i]))
  }
})


test_that("h_to_dq_params exposes the calibration table", {
  tab <- h_to_dq_params()
  expect_s3_class(tab, "data.frame")
  expect_setequal(
    names(tab),
    c("species", "a", "b", "dq_min", "dq_max")
  )
  # Every tabulated species has a positive Charru-derived a.
  expect_true(all(tab$a > 0))
  # All b = 0.9 (sub-linear shape).
  expect_true(all(abs(tab$b - 0.9) < 1e-9))
  # Ranges are well-ordered.
  expect_true(all(tab$dq_max > tab$dq_min))
})
