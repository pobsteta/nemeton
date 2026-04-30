# Helpers ------------------------------------------------------------

# Build a tiny circular AOI (sf POLYGON, EPSG:2154) of radius `r` m
# centred on a Lambert-93 point. Returned in WGS84 by default to
# exercise the reprojection path inside check_fordead_validity().
make_aoi <- function(x, y, r = 5000, crs_out = 4326) {
  pt <- sf::st_sfc(sf::st_point(c(x, y)), crs = 2154)
  poly <- sf::st_buffer(pt, r)
  sf::st_transform(sf::st_sf(geometry = poly), crs_out)
}

# Reference points (Lambert-93 metres) — taken from the centroids
# of the 5 validity-zone polygons so the AOIs are guaranteed to be
# safely inside the calibration extent.
PT_VOSGES         <- c(951111, 6793857)
PT_JURA           <- c(905980, 6628877)
PT_HAUTE_SAVOIE   <- c(965057, 6554062)
PT_MASSIF_CENTRAL <- c(680000, 6520000)  # Cantal/Aubrac, far from FORDEAD zones
PT_BRIE           <- c(720000, 6845000)  # Île-de-France, no spruce/fir

make_units <- function(species, n_per = 1L,
                       centre = PT_VOSGES, spacing = 800) {
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

test_that("Vosges AOI + spruce-only units → fully valid", {
  aoi <- make_aoi(PT_VOSGES[1], PT_VOSGES[2], r = 8000)
  u   <- make_units(c("EPC", "EPC", "SAP", "EPC"))
  res <- check_fordead_validity(aoi, u)

  expect_true(res$geo_valid)
  expect_gt(res$geo_intersection_pct, 0.95)
  expect_true("88" %in% res$geo_dept_codes)
  expect_true(res$species_valid)
  expect_gt(res$species_resineux_pct, 0.95)
  expect_true(res$overall_valid)
})

test_that("Jura AOI matches department 39", {
  aoi <- make_aoi(PT_JURA[1], PT_JURA[2], r = 6000)
  res <- check_fordead_validity(aoi)
  expect_true(res$geo_valid)
  expect_true("39" %in% res$geo_dept_codes)
  # No units passed → species check skipped.
  expect_true(is.na(res$species_valid))
  expect_true(is.na(res$species_resineux_pct))
  expect_true(res$overall_valid)
})

test_that("Massif Central AOI → geo invalid, no validated departments", {
  aoi <- make_aoi(PT_MASSIF_CENTRAL[1], PT_MASSIF_CENTRAL[2], r = 4000)
  res <- check_fordead_validity(aoi)
  expect_false(res$geo_valid)
  expect_lt(res$geo_intersection_pct, 0.05)
  expect_length(res$geo_dept_codes, 0)
  expect_false(res$overall_valid)
})

test_that("Brie AOI with oak units → geo AND species both invalid", {
  aoi <- make_aoi(PT_BRIE[1], PT_BRIE[2], r = 4000)
  u   <- make_units(c("Quercus petraea", "CHE", "Fagus sylvatica"),
                    centre = PT_BRIE)
  res <- check_fordead_validity(aoi, u)

  expect_false(res$geo_valid)
  expect_false(res$species_valid)
  expect_equal(res$species_resineux_pct, 0)
  expect_false(res$overall_valid)
})

test_that("AOI straddling Vosges + Île-de-France: geo_valid follows the threshold", {
  # Centre between Brie and Vosges, large radius → ~50/50 split.
  cx <- (PT_BRIE[1] + PT_VOSGES[1]) / 2
  cy <- (PT_BRIE[2] + PT_VOSGES[2]) / 2
  aoi <- make_aoi(cx, cy, r = 100000)  # huge radius
  res_loose <- check_fordead_validity(aoi, threshold_geo = 0.05)
  res_strict <- check_fordead_validity(aoi, threshold_geo = 0.95)
  expect_true(res_loose$geo_valid)
  expect_false(res_strict$geo_valid)
  expect_equal(res_loose$geo_intersection_pct,
               res_strict$geo_intersection_pct)
})

test_that("Mixed conifer/broadleaf units: 70% threshold is the boundary", {
  aoi <- make_aoi(PT_VOSGES[1], PT_VOSGES[2], r = 8000)
  # 7 spruce + 3 oak = exactly 70% conifer (equal-size buffers).
  u_pass <- make_units(c(rep("EPC", 7L), rep("Quercus", 3L)))
  res_pass <- check_fordead_validity(aoi, u_pass,
                                     threshold_species = 0.7)
  expect_true(res_pass$species_valid)
  expect_equal(round(res_pass$species_resineux_pct, 2), 0.70)

  # Drop to 5/10 — fails the 0.7 threshold but passes 0.4.
  u_fail <- make_units(c(rep("EPC", 5L), rep("Quercus", 5L)))
  res_fail <- check_fordead_validity(aoi, u_fail,
                                     threshold_species = 0.7)
  expect_false(res_fail$species_valid)
  res_lax  <- check_fordead_validity(aoi, u_fail,
                                     threshold_species = 0.4)
  expect_true(res_lax$species_valid)
})

test_that("Spruce vs silver fir vs Douglas: species detection is correct", {
  aoi <- make_aoi(PT_HAUTE_SAVOIE[1], PT_HAUTE_SAVOIE[2], r = 4000)
  u <- make_units(c("Picea abies", "Abies alba", "Pseudotsuga menziesii",
                    "Sapin de Douglas", "Épicéa commun"))
  res <- check_fordead_validity(aoi, u, threshold_species = 0.4)

  # 2 EPC (Picea, Épicéa) + 1 SAP (Abies alba) + 2 Douglas (rejected)
  # = 60% conifer EPC+SAP.
  expect_equal(round(res$species_resineux_pct, 2), 0.60)
  expect_equal(round(res$species_epc_pct, 2), 0.40)
  expect_equal(round(res$species_sap_pct, 2), 0.20)
  expect_true(res$species_valid)
})

test_that("Empty units sf is treated as 'no species data'", {
  aoi <- make_aoi(PT_VOSGES[1], PT_VOSGES[2], r = 8000)
  u <- make_units(c("EPC"))[0L, ]
  res <- check_fordead_validity(aoi, u)
  expect_true(is.na(res$species_valid))
  expect_true(is.na(res$species_resineux_pct))
  # geo still valid, so overall_valid = TRUE
  expect_true(res$overall_valid)
})

test_that("units without a species column → warning + species check skipped", {
  aoi <- make_aoi(PT_VOSGES[1], PT_VOSGES[2], r = 8000)
  pt  <- sf::st_sfc(sf::st_point(PT_VOSGES), crs = 2154)
  u   <- sf::st_sf(id = 1L, geometry = sf::st_buffer(pt, 200))

  expect_warning(
    res <- check_fordead_validity(aoi, u),
    "No species column"
  )
  expect_true(is.na(res$species_valid))
})

test_that("non-sf aoi raises a typed error", {
  expect_error(
    check_fordead_validity("not an sf"),
    "must be an sf or sfc"
  )
  expect_error(
    check_fordead_validity(make_aoi(PT_VOSGES[1], PT_VOSGES[2]),
                           units = list(species = "EPC")),
    "must be an sf object or NULL"
  )
})

test_that("alternative species columns are picked up", {
  aoi <- make_aoi(PT_VOSGES[1], PT_VOSGES[2], r = 6000)
  u <- make_units(c("EPC", "EPC"))
  names(u)[names(u) == "essence_dominante"] <- "species"
  res <- check_fordead_validity(aoi, u)
  expect_true(res$species_valid)
})

test_that("thresholds are echoed back in the result", {
  aoi <- make_aoi(PT_VOSGES[1], PT_VOSGES[2], r = 6000)
  res <- check_fordead_validity(aoi,
                                threshold_geo = 0.6,
                                threshold_species = 0.8,
                                min_resineux = 0.4)
  expect_equal(res$thresholds$geo, 0.6)
  expect_equal(res$thresholds$species, 0.8)
  expect_equal(res$thresholds$min_resineux, 0.4)
})
