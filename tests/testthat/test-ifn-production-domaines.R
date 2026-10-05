# Tests ifn_production_domaines() — spec 054 lot 5 (estimateur composite).

domaine_ser <- function(code) {
  pl <- nemeton:::.ifn_prod_placettes()
  p <- pl[pl$ser == code & pl$echantillon == "vif", ]
  pts <- sf::st_as_sf(p, coords = c("xl", "yl"), crs = 2154)
  # Disques de 600 m autour des centres de maille (grille de 1 km) : le domaine
  # contient exactement les placettes de la SER, sans celles des voisines.
  sf::st_sf(id = code, geometry = sf::st_union(sf::st_buffer(pts, 600)))
}

test_that("the embedded tables are there and coherent", {
  pl <- nemeton:::.ifn_prod_placettes()
  expect_true(all(c("campagne", "xl", "yl", "ser", "echantillon", "pg", "pv") %in% names(pl)))
  expect_setequal(unique(pl$echantillon), c("vif", "coupe"))
  expect_false(anyNA(pl$xl))
  m <- nemeton:::.ifn_prod_modele()
  expect_setequal(m$attribut, c("pg", "pv"))
  expect_true(all(m$sigma2_v > 0))
})

test_that("a large domain keeps its own plots and lands near its SER", {
  d <- domaine_ser("C30")
  r <- ifn_production_domaines(d, id_col = "id")
  ref <- ifn_production_reference("C30")
  expect_equal(r$nature, "composite")
  expect_gt(r$n_placettes, 300)
  expect_gt(r$poids_direct, 0.5)            # beaucoup de placettes : le direct pese
  expect_equal(r$valeur, ref$valeur, tolerance = 0.15)
  expect_true(r$rse > 0 && r$rse < 10)
  expect_equal(r$ser, "C30:1.00")
  det <- attr(r, "detail")
  expect_equal(nrow(det), 5L)
  expect_true(all(det$gamma >= 0 & det$gamma <= 1))
  expect_equal(det$estimation, det$gamma * det$direct + (1 - det$gamma) * det$prediction)
  expect_equal(det$prediction, det$ser)          # sans covariables : la SER
  expect_equal(r$predicteur, "ser")
})

test_that("a small domain leans on its SER (generalised variance, not 2-plot psi)", {
  d <- domaine_ser("C30")
  c0 <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(d)))
  ut <- sf::st_sf(id = "ut", geometry = sf::st_sfc(
    sf::st_buffer(sf::st_point(c0[1, ]), 6000, endCapStyle = "SQUARE"), crs = 2154))
  r <- ifn_production_domaines(ut)
  expect_lt(r$poids_direct, 0.5)
  # Variance calee selon la surface : 14 400 ha est sous la plage calibree.
  ech <- nemeton:::.ifn_prod_echelle()
  e <- ech[ech$attribut == "pv" & ech$predicteur == "ser", ]
  expect_equal(r$variance_domaine, exp(e$a + e$b * log(14400)))
  expect_true(r$hors_calibrage)
  expect_equal(r$surface_ha, 14400, tolerance = 1e-6)
  expect_true(r$part_bordure >= 0 && r$part_bordure <= 1)
  det <- attr(r, "detail")
  # Aucune campagne ne donne tout le poids a deux placettes.
  expect_true(all(det$gamma[det$n_vif <= 3] < 0.5))
})

test_that("a domain without plots takes its SER, through the outlines", {
  d <- domaine_ser("C30")
  c0 <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(d)))[1, ]
  # 100 m x 100 m : aucune placette, SER fournie par une couche jouet.
  mini <- sf::st_sf(id = "mini", geometry = sf::st_sfc(
    sf::st_buffer(sf::st_point(c0), 50, endCapStyle = "SQUARE"), crs = 2154))
  couche <- sf::st_sf(codeser = "C30", geometry = sf::st_geometry(d))
  r <- ifn_production_domaines(mini, ser_layer = couche)
  expect_equal(r$n_placettes, 0L)
  expect_equal(r$nature, "prediction")
  expect_equal(r$poids_direct, 0)
  s <- ifn_production_ser(ser = "C30", attribut = "pv", groupe = "tous",
                          campagne = as.integer(strsplit(r$campagnes, ",")[[1]]))
  expect_equal(r$valeur, mean(s$estimation))
})

test_that("inputs are validated", {
  expect_error(ifn_production_domaines(data.frame(x = 1)), "sf object")
  d <- domaine_ser("C30")
  expect_error(ifn_production_domaines(d, id_col = "absente"), "absente")
  expect_error(ifn_production_domaines(d, campagnes = 1990), "No campaign")
  expect_equal(ifn_production_domaines(d, attribut = "pg")$attribut, "pg")
})

test_that("the calibrated variance shrinks with the domain area", {
  ech <- nemeton:::.ifn_prod_echelle()
  expect_true(all(ech$b < 0))
  expect_true(all(ech$servi[ech$predicteur == "ser"]))
  expect_equal(ech$servi[ech$predicteur == "hybride"], ech$attribut[ech$predicteur == "hybride"] == "pv")
})

test_that("domain covariates are computed like the SER ones", {
  r <- terra::rast(nrows = 100, ncols = 100, xmin = 0, xmax = 1000, ymin = 0, ymax = 1000,
                   crs = "EPSG:2154")
  h <- r; terra::values(h) <- c(rep(300, 5000), rep(c(1000, 2000), 2500))  # cm
  a <- r; terra::values(a) <- rep(c(100, 300), each = 5000)
  dom <- sf::st_sf(code = "x", geometry = sf::st_sfc(sf::st_polygon(list(
    matrix(c(0, 0, 1000, 0, 1000, 1000, 0, 1000, 0, 0), ncol = 2, byrow = TRUE))), crs = 2154))
  cv <- ifn_covariables_domaines(dom, h, a, id_col = "code")
  expect_equal(cv$id, "x")
  expect_equal(cv$h_mean, 15, tolerance = 1e-6)     # 3 m hors foret, 10 et 20 m dedans
  expect_equal(cv$h_sd, 5, tolerance = 1e-6)
  expect_equal(cv$alt_mean, 300, tolerance = 1e-6)  # seuls les pixels de foret
  expect_equal(cv$part_foret, 0.5, tolerance = 1e-6)
  expect_equal(ifn_covariables_domaines(dom, h / 100, a, unite_hauteur = "m")$h_mean, 15,
               tolerance = 1e-6)
  expect_error(ifn_covariables_domaines(dom, as.matrix(h), a), "SpatRaster")
})

test_that("une covariable NA ne s'annonce pas « hybride »", {
  # Audit 1.0 : delta = 0 en silence, predicteur = "hybride" quand meme.
  d <- domaine_ser("C30")
  c0 <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(d)))[1, ]
  ut <- sf::st_sf(id = "ut", geometry = sf::st_sfc(
    sf::st_buffer(sf::st_point(c0), 6000, endCapStyle = "SQUARE"), crs = 2154))
  cs <- nemeton:::.ifn_prod_cov_ser()
  cs <- cs[cs$ser == "C30", ]
  cv_na <- data.frame(id = "1", h_mean = NA_real_, h_sd = cs$h_sd,
                      alt_mean = cs$alt_mean, alt_sd = cs$alt_sd)
  expect_warning(r <- ifn_production_domaines(ut, covariables = cv_na), "covariates")
  ref <- ifn_production_domaines(ut)
  expect_equal(r$predicteur, "ser")
  expect_equal(r$valeur, ref$valeur)
  expect_equal(r$variance_domaine, ref$variance_domaine)
  # Covariable absente (id inconnu) : meme repli.
  cv_autre <- cv_na; cv_autre$id <- "zz"; cv_autre$h_mean <- cs$h_mean
  expect_warning(r2 <- ifn_production_domaines(ut, covariables = cv_autre), "covariates")
  expect_equal(r2$predicteur, "ser")
})

test_that("part_foret reste une part (0-1) sur un raster en degres", {
  # Audit 1.0 : l'aire des pixels etait res_x * res_y (degres carres) divisee
  # par une aire de domaine en m2, d'ou une part_foret quasi nulle.
  r <- terra::rast(nrows = 20, ncols = 20, xmin = 5, xmax = 5.02,
                   ymin = 45, ymax = 45.02, crs = "EPSG:4326")
  h <- r; terra::values(h) <- 1500                     # tout en foret (cm)
  a <- r; terra::values(a) <- 400
  dom <- sf::st_sf(code = "g", geometry = sf::st_sfc(sf::st_polygon(list(
    matrix(c(5, 45, 5.02, 45, 5.02, 45.02, 5, 45.02, 5, 45), ncol = 2,
           byrow = TRUE))), crs = 4326))
  cv <- ifn_covariables_domaines(dom, h, a, id_col = "code")
  expect_equal(cv$part_foret, 1, tolerance = 0.01)
})

test_that("the hybrid prediction moves with the domain covariates, for PV only", {
  d <- domaine_ser("C30")
  c0 <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(d)))[1, ]
  ut <- sf::st_sf(id = "ut", geometry = sf::st_sfc(
    sf::st_buffer(sf::st_point(c0), 6000, endCapStyle = "SQUARE"), crs = 2154))
  cs <- nemeton:::.ifn_prod_cov_ser()
  cs <- cs[cs$ser == "C30", ]
  # Covariables egales a celles de la SER : la correction est nulle.
  cv0 <- data.frame(id = "1", h_mean = cs$h_mean, h_sd = cs$h_sd,
                    alt_mean = cs$alt_mean, alt_sd = cs$alt_sd)
  r0 <- ifn_production_domaines(ut, covariables = cv0)
  expect_equal(r0$predicteur, "hybride")
  det0 <- attr(r0, "detail")
  w_c30 <- grepl("^C30:1.00$", r0$ser)
  if (w_c30) expect_equal(det0$prediction, det0$ser)
  # Une hauteur plus forte change la prediction dans le sens de beta.
  cf <- nemeton:::.ifn_prod_coef()
  b <- cf$beta[cf$attribut == "pv" & cf$terme == "h_mean"]
  cv1 <- cv0; cv1$h_mean <- cv0$h_mean + 5
  r1 <- ifn_production_domaines(ut, covariables = cv1)
  expect_equal(sign(mean(attr(r1, "detail")$prediction - det0$prediction)), sign(b))
  # PG : covariables ignorees.
  expect_message(rg <- ifn_production_domaines(ut, attribut = "pg", covariables = cv0), "unused")
  expect_equal(rg$predicteur, "ser")
  expect_error(ifn_production_domaines(ut, covariables = data.frame(id = "1")), "ifn_covariables_domaines")
})
