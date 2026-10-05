# Offset radiométrique L2A Sentinel-2 (spec 055).
#
# Depuis la processing baseline 04.00 (25/01/2022), les L2A portent
# BOA_ADD_OFFSET = -1000 : comptes numériques +1000. Avant 0.215.0, le cœur ne
# le retirait jamais : NDVI d'une forêt d'été ≈ 0,55 au lieu de 0,84 sur les
# scènes récentes, fausse chute au passage de 2022 (FAST, séries pixel).

skip_if_not_installed("terra")

# Identifiants : Planetary Computer (6 champs, horodatage de traitement en
# dernier), ESA / CDSE (7 champs, baseline N####), MUSCATE.
SID_PC_OLD  <- "S2A_MSIL2A_20190615T105031_R051_T31UDP_20201007T165927"
SID_PC_NEW  <- "S2A_MSIL2A_20230615T105031_R051_T31UDP_20230615T171500"
SID_PC_REPR <- "S2A_MSIL2A_20170615T105031_R051_T31UDP_20240207T203737"

test_that(".s2_boa_offset reads the baseline from every id format", {
  expect_equal(.s2_boa_offset(SID_PC_OLD), 0)
  expect_equal(.s2_boa_offset(SID_PC_NEW), -1000)
  # Archive retraitée : acquise en 2017, traitée en 2024 -> offset.
  expect_equal(.s2_boa_offset(SID_PC_REPR), -1000)
  # Bornes du 25/01/2022.
  expect_equal(.s2_boa_offset("S2A_MSIL2A_20220124T105031_R051_T31UDP_20220124T235959"), 0)
  expect_equal(.s2_boa_offset("S2A_MSIL2A_20220125T105031_R051_T31UDP_20220125T000001"), -1000)
  # ESA / CDSE : baseline N####, avec ou sans .SAFE.
  expect_equal(.s2_boa_offset("S2B_MSIL2A_20230101T103431_N0509_R108_T31TFN_20230101T134212.SAFE"), -1000)
  expect_equal(.s2_boa_offset("S2B_MSIL2A_20210101T103431_N0300_R108_T31TFN_20210101T134212"), 0)
  expect_equal(.s2_boa_offset("S2B_MSIL2A_20220201T103431_N0400_R108_T31TFN_20220201T134212"), -1000)
  # MUSCATE / MAJA : jamais d'offset ; format inconnu : NA.
  expect_equal(.s2_boa_offset("SENTINEL2A_20230601-104858-123_L2A_T31TFN_C_V3-1"), 0)
  expect_true(is.na(.s2_boa_offset("not_a_scene")))
  expect_length(.s2_boa_offset(c(SID_PC_OLD, SID_PC_NEW)), 2L)
})

# Cache synthétique : une forêt d'été (rouge 300, PIR 3500 en réflectance
# x 10000), enregistrée sans offset (scène ancienne) et avec (+1000).
make_cache <- function() {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  write_band <- function(sid, band, value) {
    d <- file.path(dir, .s2_safe_scene_id(sid))
    dir.create(d, showWarnings = FALSE, recursive = TRUE)
    r <- terra::rast(nrows = 4, ncols = 4, xmin = 600000, xmax = 600040,
                     ymin = 5300000, ymax = 5300040, crs = "EPSG:32631")
    terra::values(r) <- value
    r[1] <- 0  # nodata
    terra::writeRaster(r, file.path(d, paste0(band, ".tif")), overwrite = TRUE)
  }
  write_band(SID_PC_OLD, "B04", 300);  write_band(SID_PC_OLD, "B08", 3500)
  write_band(SID_PC_NEW, "B04", 1300); write_band(SID_PC_NEW, "B08", 4500)
  dir
}

test_that("read_s2_band_raster removes the offset of recent scenes only", {
  cache <- make_cache()
  old <- read_s2_band_raster(cache, SID_PC_OLD, "B04")
  new <- read_s2_band_raster(cache, SID_PC_NEW, "B04")
  expect_equal(terra::values(old)[2], 300)
  expect_equal(terra::values(new)[2], 300)
  # Le nodata 0 reste 0 (et non -1000).
  expect_equal(terra::values(new)[1], 0)
  # harmonize = FALSE : comptes bruts.
  raw <- read_s2_band_raster(cache, SID_PC_NEW, "B04", harmonize = FALSE)
  expect_equal(terra::values(raw)[2], 1300)
})

test_that("a DN below the offset is floored at 0, not made negative", {
  cache <- make_cache()
  d <- file.path(cache, .s2_safe_scene_id(SID_PC_NEW))
  r <- terra::rast(file.path(d, "B04.tif"))
  terra::values(r) <- 800
  terra::writeRaster(r, file.path(d, "B04.tif"), overwrite = TRUE)
  expect_equal(unique(terra::values(read_s2_band_raster(cache, SID_PC_NEW, "B04"))[, 1]), 0)
})

test_that("build_index_stack gives the same NDVI before and after 2022", {
  cache <- make_cache()
  scenes <- data.frame(scene_id = c(SID_PC_OLD, SID_PC_NEW),
                       obs_date = as.Date(c("2019-06-15", "2023-06-15")))
  ndvi <- suppressWarnings(build_index_stack(cache, scenes, "NDVI"))
  v <- terra::values(ndvi)[2, ]
  # (3500 - 300) / (3500 + 300) = 0,842 pour les deux dates ; sans
  # correction, la scène récente valait (4500 - 1300) / 5800 = 0,552.
  expect_equal(unname(v), rep(3200 / 3800, 2), tolerance = 1e-6)
})

test_that("the index-stack disk cache is keyed on the harmonisation", {
  cache <- make_cache()
  scenes <- data.frame(scene_id = SID_PC_NEW, obs_date = as.Date("2023-06-15"))
  p <- .index_stack_cache_path(file.path(cache, "stk"), cache, scenes,
                               "NDVI", NULL)
  # La clé dépend de la version d'harmonisation : une pile calculée avant le
  # retrait de l'offset (clé sans `harmonize`) n'est jamais relue.
  key_old <- rlang::hash(list(index = "NDVI", scenes = "x"))
  expect_false(grepl(substr(key_old, 1, 16), p, fixed = TRUE))
  s1 <- suppressWarnings(build_index_stack(cache, scenes, "NDVI",
                                           cache_result = TRUE,
                                           result_cache_dir = file.path(cache, "stk")))
  expect_equal(unname(terra::values(s1)[2, 1]), 3200 / 3800, tolerance = 1e-6)
  expect_true(file.exists(p))
})

test_that("FORDEAD mosaic refuses to merge scenes with different offsets", {
  cache <- make_cache()
  sid_new_tile2 <- sub("T31UDP", "T31UDQ", SID_PC_NEW)
  sid_old_tile2 <- sub("T31UDP", "T31UDQ", SID_PC_OLD)
  # Même date, deux tuiles, une retraitée (offset) et l'autre non.
  mk <- function(sid) list(sid = sid, dt = as.Date("2023-06-15"),
    band_paths = file.path(cache, .s2_safe_scene_id(
      if (grepl("2023", sid)) SID_PC_NEW else SID_PC_OLD), "B04.tif"))
  grp <- list(mk(sid_new_tile2), mk(sid_old_tile2))
  expect_warning(out <- .fordead_mosaic_same_date(grp, "B04"),
                 "different radiometric offsets")
  expect_true(out$sid %in% c(sid_new_tile2, sid_old_tile2))
  # Même offset : mosaïque, offset commun porté par le résultat.
  grp2 <- list(mk(SID_PC_NEW), mk(sub("T31UDP", "T31UDQ", SID_PC_NEW)))
  out2 <- .fordead_mosaic_same_date(grp2, "B04")
  expect_equal(out2$boa_offset, -1000)
})
