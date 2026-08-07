# test-eobs-click-series.R — accesseurs point pour les graphiques au clic de la
# carte « Contexte régional (E-OBS) » (spec 036). Chemin PUR : extraction terra
# au point, aucune acquisition. Testable offline.

# Stack estival PAR ANNÉE (une couche/an, nommée par l'année), à la manière de
# load_eobs_source() : ici la valeur au point (x, y=milieu) suit `base + slope*k`.
make_summer_stack <- function(years = 2011:2020, slope = 0.2, base = 20,
                              var = "tx") {
  lay <- lapply(seq_along(years), function(k) {
    r <- terra::rast(terra::ext(0, 10, 0, 10), resolution = 1, crs = "EPSG:4326")
    # Champ constant par couche = base + slope*(k-1) : série exacte au point.
    terra::values(r) <- base + slope * (k - 1)
    r
  })
  s <- terra::rast(lay)
  names(s) <- as.character(years)
  terra::time(s) <- as.Date(sprintf("%d-07-15", years))
  terra::varnames(s) <- var
  s
}

# Champ QUOTIDIEN pleine année sur `years` : chaque jour = valeur constante
# dépendant du mois, pour une climatologie mensuelle prévisible.
# temp_month(m) donne la T° du mois m ; precip = 1 mm/jour partout.
make_daily <- function(years = 2011:2012, temp_month = function(m) 10 + m,
                       precip = FALSE) {
  dates <- do.call(c, lapply(years, function(y)
    seq(as.Date(sprintf("%d-01-01", y)), as.Date(sprintf("%d-12-31", y)), by = "day")))
  lay <- lapply(dates, function(d) {
    r <- terra::rast(terra::ext(0, 10, 0, 10), resolution = 1, crs = "EPSG:4326")
    m <- as.integer(format(d, "%m"))
    terra::values(r) <- if (precip) 1 else temp_month(m)
    r
  })
  s <- terra::rast(lay)
  terra::time(s) <- dates
  s
}

pt <- c(5, 5)   # au centre du champ

# --- eobs_summer_series() -------------------------------------------------

test_that("eobs_summer_series returns one row per year, ordered, with the series", {
  s <- make_summer_stack(2011:2020, slope = 0.2, base = 20)
  out <- eobs_summer_series(s, pt)
  expect_s3_class(out, "data.frame")
  expect_identical(names(out), c("year", "value"))
  expect_equal(nrow(out), 10L)
  expect_equal(out$year, 2011:2020)
  expect_equal(out$value, 20 + (0:9) * 0.2)
  expect_identical(attr(out, "var"), "tx")
})

test_that("eobs_summer_series reorders unsorted layers by year", {
  s <- make_summer_stack(2011:2015)
  s <- s[[c(3, 1, 5, 2, 4)]]                 # couches mélangées
  out <- eobs_summer_series(s, pt)
  expect_equal(out$year, 2011:2015)          # ré-ordonné
  expect_false(is.unsorted(out$year))
})

test_that("eobs_summer_series is NA-safe outside the extent", {
  s <- make_summer_stack(2011:2013)
  out <- eobs_summer_series(s, c(999, 999))  # hors emprise
  expect_equal(nrow(out), 3L)
  expect_true(all(is.na(out$value)))
})

test_that("eobs_summer_series accepts an sf POINT", {
  s <- make_summer_stack(2011:2013, base = 5, slope = 0)
  p <- sf::st_as_sf(sf::st_sfc(sf::st_point(c(5, 5)), crs = 4326))
  out <- eobs_summer_series(s, p)
  expect_equal(out$value, rep(5, 3))
})

# --- eobs_monthly_climatology() -------------------------------------------

test_that("eobs_monthly_climatology (temp) returns 12 monthly means", {
  d <- make_daily(2011:2012, temp_month = function(m) 10 + m)
  out <- eobs_monthly_climatology(d, pt, var = "tg")
  expect_identical(names(out), c("month", "value"))
  expect_equal(out$month, 1:12)
  expect_equal(out$value, 10 + (1:12))       # moyenne = valeur constante du mois
  expect_identical(attr(out, "unit"), "°C")
  expect_identical(attr(out, "reducer"), "mean")
})

test_that("eobs_monthly_climatology (precip) sums per month then averages years", {
  # 1 mm/jour -> cumul mensuel = nb de jours du mois ; moyenné sur 2 ans.
  d <- make_daily(2011:2012, precip = TRUE)
  out <- eobs_monthly_climatology(d, pt, var = "rr")
  # jan=31, fév=(28+28)/2=28 (2011 et 2012 tous deux 29? non : 2012 bissextile)
  # fév 2011 = 28 j, fév 2012 = 29 j -> moyenne 28.5
  expect_equal(out$value[1], 31)             # janvier
  expect_equal(out$value[2], 28.5)           # février (moyenne 28/29)
  expect_equal(out$value[4], 30)             # avril
  expect_identical(attr(out, "unit"), "mm")
  expect_identical(attr(out, "reducer"), "sum")
})

test_that("eobs_monthly_climatology honours the years filter", {
  d <- make_daily(2011:2012, precip = TRUE)
  out <- eobs_monthly_climatology(d, pt, var = "rr", years = 2012)
  expect_equal(out$value[2], 29)             # fév 2012 seul (bissextile)
})

test_that("eobs_monthly_climatology is NA-safe outside the extent", {
  d <- make_daily(2011L)
  out <- eobs_monthly_climatology(d, c(999, 999), var = "tg")
  expect_equal(nrow(out), 12L)
  expect_true(all(is.na(out$value)))
})

test_that("eobs_monthly_climatology aborts on a rasters with no time", {
  r <- terra::rast(terra::ext(0, 10, 0, 10), resolution = 1, crs = "EPSG:4326")
  terra::values(r) <- 1
  expect_error(eobs_monthly_climatology(r, pt, var = "tg"), "no.*time|time")
})

# --- eobs_trend_fit() -----------------------------------------------------

test_that("eobs_trend_fit slope is per-decade (10x the per-year slope)", {
  s <- make_summer_stack(2011:2020, slope = 0.2, base = 20)
  fit <- eobs_trend_fit(eobs_summer_series(s, pt))
  expect_equal(fit$slope_decade, 2, tolerance = 1e-8)   # 0.2/an -> 2/décennie
  expect_equal(fit$r2, 1, tolerance = 1e-8)             # série parfaitement linéaire
  expect_equal(fit$n, 10L)
})

test_that("eobs_trend_fit degrades to NA below two finite points", {
  fit <- eobs_trend_fit(data.frame(year = 2011, value = 20))
  expect_true(is.na(fit$slope_decade))
  expect_equal(fit$n, 1L)
})

test_that("eobs_trend_fit slope matches the map's closed-form slope", {
  # Cohérence carte <-> graphe : la pente/décennie de eobs_trend_fit doit égaler
  # 10 * .eobs_ds_slope (pente closed-form utilisée par la carte).
  s <- make_summer_stack(2011:2018, slope = 0.35, base = 18)
  ser <- eobs_summer_series(s, pt)
  fit <- eobs_trend_fit(ser)
  closed <- nemeton:::.eobs_ds_slope(ser$value, ser$year) * 10
  expect_equal(fit$slope_decade, closed, tolerance = 1e-8)
})

# --- .eobs_point_vect() : pas de reprojection inutile ----------------------

test_that("a leaflet click on an EPSG:4326 stack is not reprojected", {
  # E-OBS est livré en 4326, comme le clic : demander à PROJ une opération
  # 4326 -> 4326 ne change rien et échoue sur un runtime à PROJ dégradé.
  r <- terra::rast(terra::ext(0, 10, 0, 10), resolution = 1, crs = "EPSG:4326")
  v <- .eobs_point_vect(c(7, 48.5), terra::crs(r))

  expect_equal(as.vector(terra::crds(v)), c(7, 48.5))
  expect_identical(terra::crs(v, describe = TRUE)$code, "4326")
})

test_that("a click on a projected stack IS reprojected", {
  r <- terra::rast(terra::ext(9e5, 1.1e6, 6.7e6, 6.9e6), resolution = 1000,
                   crs = "EPSG:2154")
  v <- .eobs_point_vect(c(7, 48.5), terra::crs(r))

  expect_identical(terra::crs(v, describe = TRUE)$code, "2154")
  expect_false(isTRUE(all.equal(as.vector(terra::crds(v)), c(7, 48.5))))
})
