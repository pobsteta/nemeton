# Tests localiser_ser() — spec 054 lot 4.

ser_jouet <- function() {
  carre <- function(x0, y0, d = 1000) {
    sf::st_polygon(list(matrix(c(x0, y0, x0 + d, y0, x0 + d, y0 + d, x0, y0 + d, x0, y0),
                               ncol = 2, byrow = TRUE)))
  }
  # A11 en deux entites (multipartie eclatee), C30 a droite, "-1" hors SER.
  sf::st_sf(codeser = c("A11", "A11", "C30", "-1"),
            geometry = sf::st_sfc(carre(0, 0), carre(0, 1000), carre(1000, 0, 2000),
                                  carre(5000, 5000), crs = 2154))
}

test_that("a straddling unit takes the SER covering most of it", {
  u <- sf::st_sf(id = 1:2, geometry = sf::st_sfc(
    # 700 m dans A11 (sur ses deux entites), 300 m dans C30
    sf::st_polygon(list(matrix(c(300, 500, 1300, 500, 1300, 1500, 300, 1500, 300, 500),
                               ncol = 2, byrow = TRUE))),
    # 200 m dans A11, 800 m dans C30
    sf::st_polygon(list(matrix(c(800, 100, 1800, 100, 1800, 600, 800, 600, 800, 100),
                               ncol = 2, byrow = TRUE))),
    crs = 2154))
  r <- localiser_ser(u, ser_layer = ser_jouet())
  expect_equal(r$ser, c("A11", "C30"))
})

test_that("points, outside units and the -1 code give NA where they must", {
  p <- sf::st_sf(id = 1:3, geometry = sf::st_sfc(
    sf::st_point(c(500, 500)), sf::st_point(c(5500, 5500)), sf::st_point(c(-9000, 0)),
    crs = 2154))
  r <- localiser_ser(p, ser_layer = ser_jouet(), colonne = "code_ser")
  expect_equal(r$code_ser, c("A11", NA, NA))
})

test_that("other CRS are handled and inputs are validated", {
  p <- sf::st_transform(sf::st_sf(id = 1, geometry = sf::st_sfc(
    sf::st_point(c(1500, 500)), crs = 2154)), 3035)
  expect_equal(localiser_ser(p, ser_layer = ser_jouet())$ser, "C30")
  expect_error(localiser_ser(data.frame(x = 1)), "sf object")
  expect_error(localiser_ser(p, ser_layer = sf::st_sf(code = "A", geometry = sf::st_geometry(ser_jouet())[1])),
               "codeser")
  vide <- localiser_ser(p[0, ], ser_layer = ser_jouet())
  expect_equal(nrow(vide), 0L)
})

test_that("the INRAE WFS answers for a real extent", {
  skip_on_cran()
  skip_if_offline("geodata.inrae.fr")
  data(massif_demo_units, package = "nemeton")
  r <- suppressWarnings(localiser_ser(massif_demo_units[1:2, ]))
  skip_if(all(is.na(r$ser)), "SER WFS unavailable")
  expect_match(r$ser, "^[A-K][0-9]{2}$")
})
