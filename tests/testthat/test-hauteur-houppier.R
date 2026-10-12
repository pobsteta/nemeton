# Cas communs de l'affectation des hauteurs par houppier
# (fixtures/hauteurs_houppiers/cas.json).
test_that("affecter_hauteur_houppier suit les cas communs", {
  cas <- jsonlite::fromJSON(testthat::test_path("fixtures", "hauteurs_houppiers", "cas.json"),
                            simplifyVector = FALSE)
  houppiers <- sf::st_sf(
    houppier_id = vapply(cas$houppiers, `[[`, numeric(1), "houppier_id"),
    h_max = vapply(cas$houppiers, `[[`, numeric(1), "h_max"),
    geometry = sf::st_as_sfc(vapply(cas$houppiers, `[[`, character(1), "wkt"))
  )
  num <- function(v) if (is.null(v)) NA_real_ else as.numeric(v)
  arbres <- sf::st_sf(
    id = vapply(cas$arbres, `[[`, character(1), "id"),
    h_m = vapply(cas$arbres, function(a) num(a$h_m), numeric(1)),
    h_source = vapply(cas$arbres, `[[`, character(1), "h_source"),
    geometry = sf::st_sfc(lapply(cas$arbres, function(a) sf::st_point(c(a$x, a$y))))
  )
  res <- affecter_hauteur_houppier(arbres, houppiers)
  for (k in seq_along(cas$arbres)) {
    att <- cas$arbres[[k]]$attendu
    expect_equal(res$h_m[k], num(att$h_m), info = res$id[k])
    expect_equal(res$h_source[k], att$h_source, info = res$id[k])
    expect_equal(res$houppier_id[k], if (is.null(att$houppier_id)) NA_integer_ else
      as.integer(att$houppier_id), info = res$id[k])
  }
})

test_that("affecter_hauteur_houppier refuse des houppiers sans h_max", {
  h <- sf::st_sf(houppier_id = 1L, geometry = sf::st_sfc(sf::st_point(c(0, 0))))
  a <- sf::st_sf(id = "a", geometry = sf::st_sfc(sf::st_point(c(0, 0))))
  expect_error(affecter_hauteur_houppier(a, h), "h_max")
})
