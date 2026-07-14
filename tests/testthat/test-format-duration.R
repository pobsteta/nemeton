test_that("format_duration mène par l'unité la plus grande (h, puis min, puis s)", {
  # Sous la minute : secondes seules.
  expect_identical(format_duration(0), "0 s")
  expect_identical(format_duration(23), "23 s")
  expect_identical(format_duration(59.4), "59 s")

  # Au-dela : minutes d'abord, jamais un compte de secondes brut.
  expect_identical(format_duration(60), "1 min 00 s")
  expect_identical(format_duration(819), "13 min 39 s")   # le run RECONFORT reel

  # Au-dela de l'heure : heures d'abord.
  expect_identical(format_duration(3600), "1 h 00 min 00 s")
  expect_identical(format_duration(7512), "2 h 05 min 12 s")
  expect_identical(format_duration(7243), "2 h 00 min 43 s")
})

test_that("format_duration(with_seconds = FALSE) donne la forme courte", {
  expect_identical(format_duration(819, with_seconds = FALSE), "13 min")
  expect_identical(format_duration(7512, with_seconds = FALSE), "2 h 05 min")
  # Sous la minute, la seconde reste la seule unite lisible.
  expect_identical(format_duration(23, with_seconds = FALSE), "23 s")
})

test_that("format_duration gère les entrées invalides sans planter", {
  expect_identical(format_duration(NULL), "?")
  expect_identical(format_duration(NA), "?")
  expect_identical(format_duration(-1), "?")
  expect_identical(format_duration(Inf), "?")
  expect_identical(format_duration("abc"), "?")
})
