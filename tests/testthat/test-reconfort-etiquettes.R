# Etiquettes RECONFORT : controle du format amont, classes, propagation Y-2..Y+2.

pl <- function(id, an, pe, cl = reconfort_classe(pe), ...) {
  data.frame(id_unique = id, date = an, dep_cor = cl, DEPERIS_pe = pe, ...)
}

test_that("les classes suivent les seuils 0,20 et 0,50", {
  expect_equal(reconfort_classe(c(0, 0.19, 0.2, 0.5, 0.51, 1, NA)),
               c(1L, 1L, 2L, 2L, 3L, 3L, NA))
  expect_error(reconfort_classe(1.2), "\\[0, 1\\]")
})

test_that("cas 2 : dep_cor = 0 et DEPERIS_pe = 1,2 sont refuses", {
  expect_error(reconfort_etiquettes(pl("a", 2022L, 0.1, cl = 0L)), "dep_cor")
  expect_error(reconfort_etiquettes(pl("a", 2022L, 1.2, cl = 3L)), "DEPERIS_pe")
  expect_error(reconfort_etiquettes(pl("a", 2022L, NA_real_, cl = 1L)), "DEPERIS_pe")
  expect_error(reconfort_etiquettes(data.frame(id_unique = "a")), "must be a data.frame")
  expect_error(reconfort_etiquettes(pl("a", 2022L, 0.1, cl = 4L)), "dep_cor")
})

test_that("un id_unique en double la meme annee est refuse, pas d'une annee a l'autre", {
  expect_error(reconfort_etiquettes(rbind(pl("a", 2022L, 0.1), pl("a", 2022L, 0.3))),
               "Duplicate")
  expect_no_error(reconfort_etiquettes(rbind(pl("a", 2021L, 0.1), pl("a", 2022L, 0.1))))
})

test_that("une date de type Date donne l'annee", {
  e <- reconfort_etiquettes(pl("a", as.Date("2022-06-15"), 0.1), propager = FALSE)
  expect_equal(e$annee, 2022L)
})

test_that("cas 3 : saine 2022 => 2020 et 2021 saines ; deperissante 2022 => 2023 et 2024", {
  s <- reconfort_etiquettes(pl("sain", 2022L, 0.05))
  expect_equal(s$annee, 2020:2022)
  expect_equal(s$dep_cor, c(1L, 1L, 1L))
  expect_equal(s$source, c("propagation", "propagation", "observation"))
  expect_true(is.na(s$DEPERIS_pe[1]))

  d <- reconfort_etiquettes(pl("dep", 2022L, 0.35))
  expect_equal(d$annee, 2022:2024)
  expect_equal(d$dep_cor, c(2L, 2L, 2L))

  # tres deperissante : garde la classe 3 en aval (Pascal, 2026-11-25)
  t3 <- reconfort_etiquettes(pl("tres", 2022L, 0.9))
  expect_equal(t3$dep_cor, c(3L, 3L, 3L))
  expect_equal(nrow(attr(s, "conflits")), 0L)
})

test_that("cas 3 : une observation reelle n'est pas ecrasee, le conflit est liste", {
  p <- rbind(pl("a", 2021L, 0.35), pl("a", 2022L, 0.05))  # 2021 deperissante, 2022 saine
  e <- reconfort_etiquettes(p)
  # la propagation « saine » 2022 -> 2021 est refusee : 2021 reste deperissante
  ligne <- e[e$annee == 2021L, ]
  expect_equal(ligne$dep_cor, 2L)
  expect_equal(ligne$source, "observation")
  # la propagation « deperissante » 2021 -> 2022 est refusee : 2022 reste saine
  expect_equal(e$dep_cor[e$annee == 2022L], 1L)
  cf <- attr(e, "conflits")
  expect_equal(nrow(cf), 2L)
  expect_setequal(cf$annee, c(2021L, 2022L))
  expect_true(all(cf$origine_refusee == "propagation" & cf$origine_retenue == "observation"))
})

test_that("deux propagations en desaccord ne sont pas tranchees : ligne ecartee et listee", {
  # saine en 2023 => 2021 saine ; deperissante en 2019 => 2021 deperissante
  p <- rbind(pl("a", 2023L, 0.05), pl("a", 2019L, 0.35))
  e <- reconfort_etiquettes(p)
  expect_false(2021L %in% e$annee)
  cf <- attr(e, "conflits")
  expect_equal(cf$annee, 2021L)
  expect_true(is.na(cf$classe_retenue))
})

test_that("une propagation identique a l'observation ne fait pas de conflit", {
  e <- reconfort_etiquettes(rbind(pl("a", 2021L, 0.05), pl("a", 2022L, 0.02)))
  expect_equal(nrow(attr(e, "conflits")), 0L)
  expect_equal(e$source[e$annee == 2021L], "observation")
})

test_that("la classe est recalculee depuis DEPERIS_pe, l'ecart est signale", {
  expect_warning(
    e <- reconfort_etiquettes(pl("a", 2022L, 0.6, cl = 1L), propager = FALSE),
    "differs"
  )
  expect_equal(e$dep_cor, 3L)
  expect_equal(nrow(attr(e, "ecarts_classe")), 1L)
})

test_that("les colonnes x, y sont portees sur les lignes propagees", {
  e <- reconfort_etiquettes(pl("a", 2022L, 0.05, x = 10, y = 20))
  expect_equal(unique(e$x), 10)
  expect_equal(unique(e$y), 20)
})
