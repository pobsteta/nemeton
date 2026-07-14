test_that("scratch_dir respecte l'option, puis la variable d'environnement, puis tempdir()", {
  root <- withr::local_tempdir()

  # 1) l'option prime
  withr::local_options(nemeton.scratch_dir = root)
  expect_identical(scratch_dir(), root)

  # 2) sinon la variable d'environnement
  withr::local_options(nemeton.scratch_dir = NULL)
  withr::local_envvar(NEMETON_SCRATCH_DIR = root)
  expect_identical(scratch_dir(), root)

  # 3) sinon tempdir()
  withr::local_envvar(NEMETON_SCRATCH_DIR = "")
  expect_identical(scratch_dir(), tempdir())
})

test_that("scratch_dir crée le sous-répertoire demandé", {
  root <- withr::local_tempdir()
  withr::local_options(nemeton.scratch_dir = root)
  p <- scratch_dir("reconfort_feat_123")
  expect_true(dir.exists(p))
  expect_identical(p, file.path(root, "reconfort_feat_123"))
  # idempotent : un second appel ne casse rien
  expect_identical(scratch_dir("reconfort_feat_123"), p)
})

test_that("scratch_dir échoue clairement sur un emplacement non créable", {
  withr::local_options(nemeton.scratch_dir = "/proc/nemeton_interdit")
  expect_error(scratch_dir(), "scratch directory")
})

test_that(".free_space_gb renvoie un nombre, ou NA sans planter", {
  v <- nemeton:::.free_space_gb(tempdir())
  expect_true(is.na(v) || (is.numeric(v) && v >= 0))
  # Chemin absurde : NA, jamais une erreur.
  expect_true(is.na(nemeton:::.free_space_gb("/nexiste/pas/du/tout")) ||
                is.numeric(nemeton:::.free_space_gb("/nexiste/pas/du/tout")))
})
