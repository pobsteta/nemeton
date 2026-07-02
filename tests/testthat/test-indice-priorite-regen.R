# test-indice-priorite-regen.R — priorité de régénération (spec 027 v2.1 L3)
#
# sf synthétique portant les colonnes de sortie des moteurs (contrat §7).
# Aucun moteur GPL, aucun raster, aucun réseau.

.pr_units <- function(..., n = 1L) {
  cols <- list(...)
  g <- lapply(seq_len(n), function(i) {
    x <- (i - 1) * 10
    sf::st_polygon(list(rbind(c(x, 0), c(x + 5, 0),
                              c(x + 5, 5), c(x, 5), c(x, 0))))
  })
  base <- data.frame(id = seq_len(n))
  for (nm in names(cols)) base[[nm]] <- rep(cols[[nm]], length.out = n)
  sf::st_sf(base, geometry = sf::st_sfc(g, crs = 2154))
}


test_that("index crosses exposure and water stress (equal weight)", {
  # sensibilite 80 (exposé), njstress 30/60 -> 50 ; rew_min 0.5 -> 50 ; H=mean(50,50)=50
  u <- .pr_units(sensibilite = 80, njstress = 30, rew_min = 0.5)
  out <- indice_priorite_regen(u)
  expect_equal(out$regen_exposition[[1]], 80, tolerance = 1e-6)
  expect_equal(out$regen_hydrique[[1]], 50, tolerance = 1e-6)
  expect_equal(out$indice_priorite_regen[[1]], 65, tolerance = 1e-6)  # mean(80,50)
  expect_equal(out$regen_essence[[1]], "generique")
})

test_that("high exposure + high water stress -> top priority + flags", {
  u <- .pr_units(sensibilite = 95, njstress = 60, rew_min = 0.0)
  out <- indice_priorite_regen(u)
  expect_gt(out$indice_priorite_regen[[1]], 90)
  expect_true(out$parcelle_sensible[[1]])
  expect_true(out$priorite[[1]])
})

test_that("cool & moist parcel -> low priority, no flags", {
  u <- .pr_units(sensibilite = 10, njstress = 0, rew_min = 1.0)
  out <- indice_priorite_regen(u)
  expect_lt(out$indice_priorite_regen[[1]], 10)
  expect_false(out$parcelle_sensible[[1]])
  expect_false(out$priorite[[1]])
})

test_that("exposure falls back to d_tmax/d_vpd when sensibilite absent", {
  # d_tmax 3/6 -> 50 ; d_vpd 1/2 -> 50 ; E = 50
  u <- .pr_units(d_tmax = 3, d_vpd = 1, njstress = 0, rew_min = 1)
  out <- indice_priorite_regen(u)
  expect_equal(out$regen_exposition[[1]], 50, tolerance = 1e-6)
})

test_that("water stress renormalises over available metrics", {
  # only rew_min present -> H from rew alone ; rew 0.25 -> 75
  u <- .pr_units(sensibilite = 40, rew_min = 0.25)
  out <- indice_priorite_regen(u)
  expect_equal(out$regen_hydrique[[1]], 75, tolerance = 1e-6)
})

test_that("custom weights bias the cross", {
  u <- .pr_units(sensibilite = 100, njstress = 0, rew_min = 1)  # E=100, H=0
  out <- indice_priorite_regen(u, weights = c(exposition = 3, hydrique = 1))
  expect_equal(out$indice_priorite_regen[[1]], 75, tolerance = 1e-6)  # (3*100+1*0)/4
})

test_that("rew_min on a 0-100 scale is auto-detected", {
  u <- .pr_units(sensibilite = 0, rew_min = 25)   # treated as 0.25 -> H 75
  out <- indice_priorite_regen(u)
  expect_equal(out$regen_hydrique[[1]], 75, tolerance = 1e-6)
})

test_that("no engine columns -> NA index + warning", {
  u <- .pr_units(other = 1)
  expect_warning(out <- indice_priorite_regen(u), "no exposure")
  expect_true(is.na(out$indice_priorite_regen[[1]]))
})

test_that("couverture_pct is preserved", {
  u <- .pr_units(sensibilite = 50, njstress = 10, rew_min = 0.6, couverture_pct = 42L)
  out <- indice_priorite_regen(u)
  expect_equal(out$couverture_pct[[1]], 42L)
})

test_that("species option (OFF by default) pushes priority up for an intolerant species", {
  # Hot microsite: tmax_moyenne 30 + d_tmax 6 = 36°C ; beech tol 28°C -> full penalty.
  u <- .pr_units(sensibilite = 50, njstress = 10, rew_min = 0.7,
                 d_tmax = 6, tmax_moyenne = 30, vpd_canicule = 2.0)
  generic <- indice_priorite_regen(u)$indice_priorite_regen[[1]]
  beech   <- indice_priorite_regen(u, species = "essence_hetraie")$indice_priorite_regen[[1]]
  oak     <- indice_priorite_regen(u, species = "essence_chene_vert")$indice_priorite_regen[[1]]
  expect_gt(beech, generic)          # intolerant -> higher priority
  expect_gt(beech, oak)              # beech more urgent than thermophilic oak
})

test_that("regeneration_tolerances() ships every species class", {
  tol <- regeneration_tolerances()
  expect_true(all(c("code", "tmax_tol_c", "vpd_tol_kpa") %in% names(tol)))
  expect_setequal(tol$code, list_species_classes()$code)
})
