# test-indicator-a5.R — A5 rafraîchissement urbain (LST), spec 032
#
# In-memory LST rasters (Kelvin), no network. A cool patch under the unit
# surrounded by a hot ring makes the relative-freshness arithmetic checkable.

.a5_grid <- function() {
  terra::rast(nrows = 30, ncols = 30, xmin = 0, xmax = 300,
              ymin = 0, ymax = 300, crs = "EPSG:2154")
}

# Unit = central 100x100 block [100,200] x [100,200].
.a5_unit <- function() {
  g <- sf::st_as_sfc(sf::st_bbox(c(xmin = 100, ymin = 100,
                                   xmax = 200, ymax = 200), crs = 2154))
  sf::st_sf(id = 1L, geometry = g)
}

# LST: hot everywhere (`hot` K), cool square in the centre (`cool` K).
.a5_lst <- function(hot = 315, cool = 305) {
  r <- .a5_grid()
  terra::values(r) <- hot
  centre <- terra::ext(100, 200, 100, 200)
  r[terra::cells(r, centre)] <- cool
  r
}


test_that("A5 is high when the unit is cooler than its surroundings", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 315, cool = 305)          # unit 10 K cooler
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        buffer_m = 100, delta_scale = 5)
  # delta ~ +10 K (ref 315 - unit 305); score 50 + 10/5*50 = 150 -> clamp 100.
  expect_equal(out$A5[[1]], 100, tolerance = 1)
  expect_gt(out$A5_delta[[1]], 5)
})

test_that("A5 is low when the unit is hotter than its surroundings", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 305, cool = 315)          # unit 10 K hotter
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        buffer_m = 100, delta_scale = 5)
  expect_equal(out$A5[[1]], 0, tolerance = 1)
  expect_lt(out$A5_delta[[1]], -5)
})

test_that("A5 ~ 50 when the unit matches its surroundings", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 310, cool = 310)          # uniform
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        buffer_m = 100)
  expect_equal(out$A5[[1]], 50, tolerance = 1)
  expect_equal(out$A5_delta[[1]], 0, tolerance = 1e-6)
})

test_that("A5 accepts a fixed reference temperature", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 315, cool = 305)
  # Fixed reference 310 K, unit ~305 K -> delta +5 -> score 100.
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        reference = 310, delta_scale = 5)
  expect_equal(out$A5_delta[[1]], 5, tolerance = 1)
  expect_equal(out$A5[[1]], 100, tolerance = 1)
})

test_that("A5 is source-conditional: NULL lst -> NA", {
  skip_if_not_installed("sf")
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = NULL)
  expect_true(is.na(out$A5[[1]]))
  expect_true(is.na(out$A5_delta[[1]]))
})

test_that("A5 ignores the -32768 LST nodata sentinel", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst(hot = 315, cool = 305)
  # Poison a few cells with the nodata sentinel; must not skew the mean.
  lst[1:20] <- -32768
  out <- indicateur_a5_rafraichissement(.a5_unit(), lst = lst,
                                        buffer_m = 100, delta_scale = 5)
  expect_equal(out$A5[[1]], 100, tolerance = 1)
})

test_that("A5 is NA for a unit off the LST raster", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
  lst <- .a5_lst()
  off <- sf::st_sf(id = 1L, geometry = sf::st_as_sfc(
    sf::st_bbox(c(xmin = 5000, ymin = 5000, xmax = 5100, ymax = 5100),
                crs = 2154)))
  out <- indicateur_a5_rafraichissement(off, lst = lst)
  expect_true(is.na(out$A5[[1]]))
})

# --- a5_status : distinguer « vide » de « cassé » (brief A5, spec 032) -------
#
# Hors couverture Thermocity, A5 = NA est la bonne réponse, pas une panne. Sans
# colonne de statut, l'aval ne peut pas faire la différence — il ne voit qu'un NA
# et affiche une carte grise sans explication.

test_that("a5_status says why the indicator is empty", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")

  units <- .a5_unit()

  # 1. Pas de raster du tout : la source n'a rien fourni.
  no_lst <- indicateur_a5_rafraichissement(units, lst = NULL)
  expect_identical(no_lst$a5_status, "skipped_no_lst")
  expect_true(all(is.na(no_lst$A5)))

  # 2. Raster fourni et unité notée.
  ok <- indicateur_a5_rafraichissement(units, lst = .a5_lst())
  expect_identical(ok$a5_status, "calculated")
  expect_false(is.na(ok$A5))

  # 3. Raster fourni mais emprises disjointes : ce n'est pas la même chose que
  #    l'absence de source, et l'aval doit pouvoir le dire.
  ailleurs <- sf::st_sf(
    id = 1L,
    geometry = sf::st_as_sfc(sf::st_bbox(
      c(xmin = 10000, ymin = 10000, xmax = 10100, ymax = 10100), crs = 2154)))
  off <- indicateur_a5_rafraichissement(ailleurs, lst = .a5_lst())
  expect_identical(off$a5_status, "skipped_no_reference")
  expect_true(all(is.na(off$A5)))
})

test_that("a5_status is per-unit, like r5_status", {
  skip_if_not_installed("terra"); skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")

  # Une unité sur le raster, une hors emprise : le statut suit l'unité, il n'est
  # pas global — c'est ce qui permet un affichage par UGF.
  units <- rbind(
    .a5_unit(),
    sf::st_sf(id = 2L, geometry = sf::st_as_sfc(sf::st_bbox(
      c(xmin = 10000, ymin = 10000, xmax = 10100, ymax = 10100), crs = 2154))))
  out <- indicateur_a5_rafraichissement(units, lst = .a5_lst())

  expect_length(out$a5_status, 2L)
  expect_identical(out$a5_status[1], "calculated")
  expect_identical(out$a5_status[2], "skipped_no_reference")
})
