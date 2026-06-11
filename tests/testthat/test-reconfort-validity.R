# Helpers ------------------------------------------------------------

# Build a tiny circular AOI (sf POLYGON, EPSG:2154) of radius `r` m
# centred on a Lambert-93 point. Returned in WGS84 by default to
# exercise the reprojection path inside check_reconfort_validity().
make_aoi <- function(x, y, r = 8000, crs_out = 4326) {
  pt <- sf::st_sfc(sf::st_point(c(x, y)), crs = 2154)
  poly <- sf::st_buffer(pt, r)
  sf::st_transform(sf::st_sf(geometry = poly), crs_out)
}

# Reference points (Lambert-93 metres) — centroids of three CVL
# validity-zone polygons, so the AOIs sit safely inside the
# calibration extent. Plus two points well outside CVL.
PT_LOIRET   <- c(651018, 6757040)   # dept 45
PT_CHER     <- c(661374, 6662849)   # dept 18
PT_INDRE37  <- c(525448, 6686748)   # dept 37 (Indre-et-Loire)
PT_VOSGES   <- c(951111, 6793857)   # Est — outside CVL
PT_BRETAGNE <- c(210000, 6800000)   # far west — outside CVL

make_units <- function(species, n_per = 1L,
                       centre = PT_LOIRET, spacing = 800) {
  k <- length(species)
  ids <- seq_len(k * n_per)
  cx  <- centre[1] + ((ids - 1L) %% (k * 2L)) * spacing
  cy  <- centre[2] + ((ids - 1L) %/% (k * 2L)) * spacing
  geom <- lapply(seq_along(ids), function(i) {
    p <- sf::st_point(c(cx[i], cy[i]))
    sf::st_buffer(sf::st_sfc(p, crs = 2154), 200)[[1]]
  })
  sf::st_sf(
    id = ids,
    essence_dominante = rep(species, length.out = length(ids)),
    geometry = sf::st_sfc(geom, crs = 2154)
  )
}


# Tests --------------------------------------------------------------

test_that("Loiret AOI + oak/chestnut/pine units → fully valid", {
  aoi <- make_aoi(PT_LOIRET[1], PT_LOIRET[2], r = 8000)
  u   <- make_units(c("CHE", "CHE", "Castanea sativa", "Pin sylvestre"))
  res <- check_reconfort_validity(aoi, u)

  expect_true(res$geo_valid)
  expect_gt(res$geo_intersection_pct, 0.95)
  expect_true("45" %in% res$geo_dept_codes)
  expect_true(res$species_valid)
  expect_gt(res$species_target_pct, 0.95)
  expect_true(res$overall_valid)
  expect_true(res$advisory)
})

test_that("Cher AOI matches department 18", {
  aoi <- make_aoi(PT_CHER[1], PT_CHER[2], r = 6000)
  res <- check_reconfort_validity(aoi)
  expect_true(res$geo_valid)
  expect_true("18" %in% res$geo_dept_codes)
  # No units passed → species check skipped.
  expect_true(is.na(res$species_valid))
  expect_true(is.na(res$species_target_pct))
  expect_true(res$overall_valid)
})

test_that("Vosges AOI → geo invalid, no validated departments", {
  aoi <- make_aoi(PT_VOSGES[1], PT_VOSGES[2], r = 4000)
  res <- check_reconfort_validity(aoi)
  expect_false(res$geo_valid)
  expect_lt(res$geo_intersection_pct, 0.05)
  expect_length(res$geo_dept_codes, 0)
  expect_false(res$overall_valid)
})

test_that("Bretagne AOI with spruce/beech units → geo AND species both invalid", {
  aoi <- make_aoi(PT_BRETAGNE[1], PT_BRETAGNE[2], r = 4000)
  u   <- make_units(c("Picea abies", "EPC", "Fagus sylvatica"),
                    centre = PT_BRETAGNE)
  res <- check_reconfort_validity(aoi, u)

  expect_false(res$geo_valid)
  expect_false(res$species_valid)
  expect_equal(res$species_target_pct, 0)
  expect_false(res$overall_valid)
})

test_that("AOI straddling Loiret + far west: geo_valid follows the threshold", {
  cx <- (PT_BRETAGNE[1] + PT_LOIRET[1]) / 2
  cy <- (PT_BRETAGNE[2] + PT_LOIRET[2]) / 2
  aoi <- make_aoi(cx, cy, r = 120000)  # huge radius
  res_loose  <- check_reconfort_validity(aoi, threshold_geo = 0.02)
  res_strict <- check_reconfort_validity(aoi, threshold_geo = 0.95)
  expect_true(res_loose$geo_valid)
  expect_false(res_strict$geo_valid)
  expect_equal(res_loose$geo_intersection_pct,
               res_strict$geo_intersection_pct)
})

test_that("Mixed target/non-target units: 70% threshold is the boundary", {
  aoi <- make_aoi(PT_LOIRET[1], PT_LOIRET[2], r = 8000)
  # 7 oak + 3 beech ≈ 70% target species (equal-size buffers; the
  # area ratio is ~0.70 to float precision, so test against a 0.65
  # threshold rather than the exact 0.70 boundary).
  u_pass <- make_units(c(rep("CHE", 7L), rep("Fagus", 3L)))
  res_pass <- check_reconfort_validity(aoi, u_pass,
                                       threshold_species = 0.65)
  expect_true(res_pass$species_valid)
  expect_equal(round(res_pass$species_target_pct, 2), 0.70)

  # Drop to 5/10 — fails the 0.7 threshold but passes 0.4.
  u_fail <- make_units(c(rep("CHE", 5L), rep("Fagus", 5L)))
  res_fail <- check_reconfort_validity(aoi, u_fail,
                                       threshold_species = 0.7)
  expect_false(res_fail$species_valid)
  res_lax  <- check_reconfort_validity(aoi, u_fail,
                                       threshold_species = 0.4)
  expect_true(res_lax$species_valid)
})

test_that("Oak vs chestnut vs Scots pine vs maritime pine detection", {
  aoi <- make_aoi(PT_INDRE37[1], PT_INDRE37[2], r = 6000)
  u <- make_units(c("Quercus petraea", "Castanea sativa",
                    "Pin sylvestre", "Pin maritime", "CHE"),
                  centre = PT_INDRE37)
  res <- check_reconfort_validity(aoi, u, threshold_species = 0.4)

  # 2 oak (Quercus, CHE) + 1 chestnut + 1 Scots pine + 1 maritime
  # pine (rejected) = 80% target species.
  expect_equal(round(res$species_target_pct, 2), 0.80)
  expect_equal(round(res$species_chene_pct, 2), 0.40)
  expect_equal(round(res$species_chataignier_pct, 2), 0.20)
  expect_equal(round(res$species_pin_pct, 2), 0.20)  # maritime excluded
  expect_true(res$species_valid)
})

test_that("Empty units sf is treated as 'no species data'", {
  aoi <- make_aoi(PT_LOIRET[1], PT_LOIRET[2], r = 8000)
  u <- make_units(c("CHE"))[0L, ]
  res <- check_reconfort_validity(aoi, u)
  expect_true(is.na(res$species_valid))
  expect_true(is.na(res$species_target_pct))
  expect_true(res$overall_valid)
})

test_that("units without a species column → warning + species check skipped", {
  aoi <- make_aoi(PT_LOIRET[1], PT_LOIRET[2], r = 8000)
  pt  <- sf::st_sfc(sf::st_point(PT_LOIRET), crs = 2154)
  u   <- sf::st_sf(id = 1L, geometry = sf::st_buffer(pt, 200))

  expect_warning(
    res <- check_reconfort_validity(aoi, u),
    "No species column"
  )
  expect_true(is.na(res$species_valid))
})

test_that("non-sf aoi raises a typed error", {
  expect_error(
    check_reconfort_validity("not an sf"),
    "must be an sf or sfc"
  )
  expect_error(
    check_reconfort_validity(make_aoi(PT_LOIRET[1], PT_LOIRET[2]),
                             units = list(species = "CHE")),
    "must be an sf object or NULL"
  )
})

test_that("alternative species columns are picked up", {
  aoi <- make_aoi(PT_LOIRET[1], PT_LOIRET[2], r = 6000)
  u <- make_units(c("CHE", "CHE"))
  names(u)[names(u) == "essence_dominante"] <- "species"
  res <- check_reconfort_validity(aoi, u)
  expect_true(res$species_valid)
})

test_that("BD Forêt fallback: derives species from `bdforet` when units lacks a column", {
  aoi <- make_aoi(PT_LOIRET[1], PT_LOIRET[2], r = 8000)
  pt  <- sf::st_sfc(sf::st_point(PT_LOIRET), crs = 2154)
  u   <- sf::st_sf(id = 1L, geometry = sf::st_buffer(pt, 800))
  bdf_pts <- sf::st_sfc(
    sf::st_point(c(PT_LOIRET[1],       PT_LOIRET[2])),
    sf::st_point(c(PT_LOIRET[1] + 300, PT_LOIRET[2])),
    sf::st_point(c(PT_LOIRET[1] - 400, PT_LOIRET[2] + 200)),
    crs = 2154
  )
  bdf <- sf::st_sf(
    essence = c("CHE", "CHE", "Fagus"),
    geometry = sf::st_buffer(bdf_pts, 200)
  )

  expect_message(
    res <- check_reconfort_validity(aoi, u, bdforet = bdf),
    "BD For"
  )
  expect_true(res$geo_valid)
  expect_false(is.na(res$species_valid))
})

test_that("BD Forêt fallback: layers= resolves bdforet via resolve_vector_layer", {
  aoi <- make_aoi(PT_LOIRET[1], PT_LOIRET[2], r = 8000)
  pt  <- sf::st_sfc(sf::st_point(PT_LOIRET), crs = 2154)
  u   <- sf::st_sf(id = 1L, geometry = sf::st_buffer(pt, 800))
  bdf_pts <- sf::st_sfc(sf::st_point(c(PT_LOIRET[1], PT_LOIRET[2])), crs = 2154)
  bdf <- sf::st_sf(essence = "CHE", geometry = sf::st_buffer(bdf_pts, 500))
  layers <- structure(
    list(vectors = list(bdforet = bdf)),
    class = "nemeton_layers"
  )

  expect_message(
    res <- check_reconfort_validity(aoi, u, layers = layers),
    "BD For"
  )
  expect_false(is.na(res$species_valid))
})

test_that("BD Forêt fallback: ignored when units already has a species column", {
  aoi <- make_aoi(PT_LOIRET[1], PT_LOIRET[2], r = 8000)
  u   <- make_units(c("CHE", "CHE"))  # has essence_dominante
  bdf_pts <- sf::st_sfc(sf::st_point(c(PT_LOIRET[1], PT_LOIRET[2])), crs = 2154)
  bdf <- sf::st_sf(essence = "Fagus", geometry = sf::st_buffer(bdf_pts, 500))

  expect_no_message(
    res <- check_reconfort_validity(aoi, u, bdforet = bdf)
  )
  expect_true(res$species_valid)
  expect_gt(res$species_target_pct, 0.95)
})

test_that("thresholds + advisory flag are echoed back in the result", {
  aoi <- make_aoi(PT_LOIRET[1], PT_LOIRET[2], r = 6000)
  res <- check_reconfort_validity(aoi,
                                  threshold_geo = 0.6,
                                  threshold_species = 0.8,
                                  min_target = 0.4)
  expect_equal(res$thresholds$geo, 0.6)
  expect_equal(res$thresholds$species, 0.8)
  expect_equal(res$thresholds$min_target, 0.4)
  expect_true(res$advisory)
})
