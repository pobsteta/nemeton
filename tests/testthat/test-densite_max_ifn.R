# Tests de densite_max_ifn() et du plafond d'auto-eclaircie (spec 068).

test_that("densite_max_ifn gives the RDI quantile per dominant species", {
  # 3 placettes de chene (03), 2 de hetre (09) : RDI = N (d/25)^1.605
  a <- data.frame(placette = c("p1", "p2", "p3", "p4", "p5", "p5"),
                  essence = c("03", "03", "03", "09", "09", "03"),
                  d1 = c(25, 25, 25, 50, 50, 10), poids = c(400, 600, 800, 200, 300, 10),
                  statut = "vivant")
  out <- densite_max_ifn(a, quantile = 1, min_placettes = 2L)
  expect_equal(out$essence, c("03", "09", "toutes"))
  expect_equal(out$n_placettes, c(3L, 2L, 5L))
  expect_equal(out$rdi_max[1], 800)
  expect_equal(out$rdi_max[2], 300 * 2^1.605 + 10 * 0.4^1.605)
  expect_equal(out$rdi_max[3], max(out$rdi_max[1:2]))
  g5 <- 300 * pi * 0.25^2 + 10 * pi * 0.05^2
  expect_equal(out$g_max, c(800 * pi * 0.125^2, g5, g5))
  # essence trop rare : seule la ligne "toutes"
  expect_equal(densite_max_ifn(a, quantile = 1, min_placettes = 4L)$essence, "toutes")
  # coupes et recrues ignores
  b <- rbind(a, data.frame(placette = "p1", essence = "03", d1 = 60, poids = 1000, statut = "coupe"))
  expect_equal(densite_max_ifn(b, 1, 2L), out)
  expect_error(densite_max_ifn(a[, -3]), "d1")
  expect_error(densite_max_ifn(a, quantile = 0), "quantile")
})

test_that(".itin_rdi_max maps the ceilings on the FINN groups", {
  dm <- data.frame(essence = c("03", "09", "toutes"), rdi_max = c(1000, 1100, 1200))
  expect_equal(nemeton:::.itin_rdi_max(dm, c("09", "62", "03", "other")),
               list(rdi = c(1100, 1200, 1000, 1200), g = NULL))
  dm$g_max <- c(50, 60, 70)
  expect_equal(nemeton:::.itin_rdi_max(dm, c("09", "other"))$g, c(60, 70))
  expect_null(nemeton:::.itin_rdi_max(NULL, "03"))
  expect_error(nemeton:::.itin_rdi_max(dm[1:2, ], "03"), "toutes")
  expect_error(nemeton:::.itin_rdi_max(dm[, 1, drop = FALSE], "03"), "rdi_max")
})

test_that(".itin_auto_eclaircie removes the smallest stems down to the ceiling", {
  # site 1 : 1000 tiges de 10 cm + 500 de 30 cm sur 1 ha, groupe 1 dominant
  coh <- data.frame(siteID = c(1L, 1L, 2L), species = c(1L, 1L, 2L),
                    dbh = c(10, 30, 30), trees = c(1000, 500, 100))
  r10 <- (10 / 25)^1.605; r30 <- (30 / 25)^1.605
  rdi1 <- 1000 * r10 + 500 * r30
  plafond <- c(rdi1 - 100 * r10, 5000)
  out <- nemeton:::.itin_auto_eclaircie(coh, list(rdi = plafond), 2L, 1)
  expect_equal(out$trees, c(900, 500, 100))
  # plafond sous le RDI des seules grosses : les petites disparaissent
  out2 <- nemeton:::.itin_auto_eclaircie(coh, list(rdi = c(400 * r30, 5000)), 2L, 1)
  expect_equal(out2$dbh, c(30, 30))
  expect_equal(out2$trees, c(400, 100))
  # surface de patch : le RDI est ramene a l'hectare
  coh7 <- transform(coh, trees = trees * 0.7)
  out3 <- nemeton:::.itin_auto_eclaircie(coh7, list(rdi = plafond), 2L, 0.7)
  expect_equal(out3$trees, c(630, 350, 70))
  # plafond de G : les petites tiges partent d'abord, puis les grosses
  g10 <- pi * 0.05^2; g30 <- pi * 0.15^2
  g1 <- 1000 * g10 + 500 * g30
  out4 <- nemeton:::.itin_auto_eclaircie(coh, list(rdi = c(1e9, 1e9), g = c(g1 - 100 * g10, 1e9)), 2L, 1)
  expect_equal(out4$trees, c(900, 500, 100))
  out5 <- nemeton:::.itin_auto_eclaircie(coh, list(rdi = c(1e9, 1e9), g = c(450 * g30, 1e9)), 2L, 1)
  expect_equal(out5$trees, c(450, 100))
})
