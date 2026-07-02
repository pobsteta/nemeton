# test-sentinel2-muscate.R — Theia MUSCATE STAC backend (spec 029)
#
# Sovereign last-resort fallback for the FAST/FORDEAD S2 feed. All STAC
# I/O is mocked (never hits the network); the real FR.json config is
# used to resolve the STAC api + MUSCATE collection.

# ---- band-asset key mapping (D2/D3) ----------------------------------

test_that(".muscate_band_asset_keys strips the leading zero and prefers SRE", {
  keys <- nemeton:::.muscate_band_asset_keys("B04", product = "SRE")
  # SRE variant of the MUSCATE (no-zero) name comes first.
  expect_identical(keys[1], "SRE_B4")
  expect_true("B4" %in% keys)          # bare fallback present
  expect_true(any(grepl("^FRE_", keys)))  # other product last-resort
  # FRE never outranks SRE when SRE is requested.
  expect_lt(match("SRE_B4", keys), match("FRE_B4", keys))
})

test_that(".muscate_band_asset_keys keeps B8A/B11/B12 unchanged", {
  expect_identical(nemeton:::.muscate_band_asset_keys("B8A")[1], "SRE_B8A")
  expect_identical(nemeton:::.muscate_band_asset_keys("B11")[1], "SRE_B11")
  expect_identical(nemeton:::.muscate_band_asset_keys("B12")[1], "SRE_B12")
})

test_that(".muscate_band_asset_keys honours the FRE product", {
  keys <- nemeton:::.muscate_band_asset_keys("B08", product = "FRE")
  expect_identical(keys[1], "FRE_B8")
  expect_lt(match("FRE_B8", keys), match("SRE_B8", keys))
})


# ---- feature remapping (asset dialect -> nemeton band keys) ----------

test_that(".muscate_remap_feature keys assets by nemeton band + /vsis3/ href", {
  feat <- list(
    id = "SENTINEL2A_20230601-105331_L2A_T31TGM_D",
    properties = list(datetime = "2023-06-01T10:53:31Z",
                      `eo:cloud_cover` = 8),
    assets = list(
      SRE_B4  = list(href = "s3://sm1-gdc-ext/muscate/b4.tif"),
      SRE_B8  = list(href = "s3://sm1-gdc-ext/muscate/b8.tif"),
      SRE_B12 = list(href = "s3://sm1-gdc-ext/muscate/b12.tif")
    )
  )
  out <- nemeton:::.muscate_remap_feature(feat, product = "SRE")
  expect_identical(out$assets$B04$href, "/vsis3/sm1-gdc-ext/muscate/b4.tif")
  expect_identical(out$assets$B08$href, "/vsis3/sm1-gdc-ext/muscate/b8.tif")
  expect_identical(out$assets$B12$href, "/vsis3/sm1-gdc-ext/muscate/b12.tif")
  # An absent optional band becomes an empty href (tolerated downstream).
  expect_identical(out$assets$B05$href, "")
})


# ---- backend end-to-end (mocked stac_search_items) -------------------

.muscate_fake_feature <- function(id = "SENTINEL2A_20230601_T31TGM",
                                  cloud = 8,
                                  datetime = "2023-06-01T10:53:31Z") {
  list(
    id = id,
    properties = list(datetime = datetime, `eo:cloud_cover` = cloud),
    assets = list(
      SRE_B4  = list(href = "s3://sm1-gdc-ext/muscate/b4.tif"),
      SRE_B8  = list(href = "s3://sm1-gdc-ext/muscate/b8.tif"),
      SRE_B12 = list(href = "s3://sm1-gdc-ext/muscate/b12.tif")
    )
  )
}

test_that(".muscate_remap_feature handles the real STAC dialect (plain band keys)", {
  # The live `sentinel2-l2a-theia` collection exposes reflectance under
  # plain band keys B02/B04/… (FRE GeoTIFFs), NOT SRE_B4 — confirmed by
  # the spec 029 K4 smoke (2026-07-02). The bare-band candidate must win.
  feat <- list(
    id = "SENTINEL2B_20230822-103757-145_L2A_T31TGN_C",
    properties = list(datetime = "2023-08-22T10:37:57Z", `eo:cloud_cover` = 10),
    assets = list(
      B04 = list(href = "https://s3-data.meso.umontpellier.fr/s2-theia/x/FRE_B4.tif"),
      B08 = list(href = "https://s3-data.meso.umontpellier.fr/s2-theia/x/FRE_B8.tif"),
      B12 = list(href = "https://s3-data.meso.umontpellier.fr/s2-theia/x/FRE_B12.tif")
    )
  )
  out <- nemeton:::.muscate_remap_feature(feat, product = "FRE")
  expect_identical(out$assets$B04$href, "/vsis3/s2-theia/x/FRE_B4.tif")
  expect_identical(out$assets$B08$href, "/vsis3/s2-theia/x/FRE_B8.tif")
})

test_that("stac_search_s2_theia_muscate returns a normalised scene tibble", {
  skip_if_not_installed("httr2")
  testthat::local_mocked_bindings(
    stac_search_items = function(...) list(.muscate_fake_feature()),
    .package = "nemeton"
  )
  out <- stac_search_s2_theia_muscate(c(6.0, 47.8, 6.3, 48.0),
                                      "2023-06-01", "2023-06-30")
  expect_identical(nrow(out), 1L)
  expect_identical(out$source, "muscate")
  expect_identical(out$obs_date, as.Date("2023-06-01"))
  expect_identical(out$href_B04, "/vsis3/sm1-gdc-ext/muscate/b4.tif")
  # Same column contract as the cdse/pc backends.
  expect_named(out, c("scene_id", "obs_date", "cloud_pct",
                      "href_B02", "href_B04", "href_B05", "href_B08",
                      "href_B8A", "href_B11", "href_B12", "source"))
})

test_that("stac_search_s2_theia_muscate applies the scene-level cloud filter", {
  skip_if_not_installed("httr2")
  testthat::local_mocked_bindings(
    stac_search_items = function(...) list(
      .muscate_fake_feature(id = "clear", cloud = 8),
      .muscate_fake_feature(id = "cloudy", cloud = 55)
    ),
    .package = "nemeton"
  )
  out <- stac_search_s2_theia_muscate(c(6, 47.8, 6.3, 48), "2023-06-01",
                                      "2023-06-30", max_cloud = 20)
  expect_identical(nrow(out), 1L)
  expect_identical(out$scene_id, "clear")
})

test_that("stac_search_s2_theia_muscate keeps scenes with unknown cloud cover", {
  skip_if_not_installed("httr2")
  testthat::local_mocked_bindings(
    stac_search_items = function(...) list(
      .muscate_fake_feature(id = "no_cloud_meta", cloud = NULL)
    ),
    .package = "nemeton"
  )
  out <- stac_search_s2_theia_muscate(c(6, 47.8, 6.3, 48), "2023-06-01",
                                      "2023-06-30", max_cloud = 20)
  expect_identical(nrow(out), 1L)   # NA cloud -> not dropped
})


# ---- façade wiring: MUSCATE is a last-resort fallback ----------------

test_that("stac_search_s2 falls through to MUSCATE when cdse + pc are silent", {
  testthat::local_mocked_bindings(
    stac_search_s2_cdse          = function(...) nemeton:::.empty_scene_tibble(),
    stac_search_s2_pc            = function(...) nemeton:::.empty_scene_tibble(),
    stac_search_s2_theia_muscate = function(...) {
      data.frame(scene_id = "muscate_1", obs_date = as.Date("2023-06-01"),
                 cloud_pct = 8, href_B04 = "x", href_B08 = "y",
                 href_B12 = "z", source = "muscate",
                 stringsAsFactors = FALSE)
    }
  )
  out <- stac_search_s2(c(6, 47.8, 6.3, 48), "2023-06-01", "2023-06-30")
  expect_identical(nrow(out), 1L)
  expect_identical(out$source, "muscate")
})

test_that("stac_search_s2 never queries MUSCATE when cdse yields scenes", {
  called <- new.env()
  called$muscate <- FALSE
  testthat::local_mocked_bindings(
    stac_search_s2_cdse = function(...) {
      data.frame(scene_id = "cdse_1", obs_date = as.Date("2023-06-01"),
                 cloud_pct = 3, href_B04 = "x", href_B08 = "y",
                 href_B12 = "z", source = "cdse", stringsAsFactors = FALSE)
    },
    stac_search_s2_theia_muscate = function(...) {
      called$muscate <- TRUE
      nemeton:::.empty_scene_tibble()
    }
  )
  out <- stac_search_s2(c(6, 47.8, 6.3, 48), "2023-06-01", "2023-06-30")
  expect_identical(out$source, "cdse")
  expect_false(called$muscate)   # nominal path: no MUSCATE request
})


# ---- D4: reflectance scale cancels in the normalised indices ---------

test_that("NDVI/NBR are invariant under a common linear reflectance scale", {
  # MUSCATE reflectance is scaled (x10000) w.r.t. the [0,1] convention;
  # since the FAST indices are ratios (A-B)/(A+B), a common factor
  # cancels — the core assumption that lets a mixed cdse/muscate series
  # stay coherent (spec 029 D4). No additive offset is assumed.
  ndvi <- function(nir, red) (nir - red) / (nir + red)
  expect_equal(ndvi(0.42, 0.18), ndvi(4200, 1800))
})
