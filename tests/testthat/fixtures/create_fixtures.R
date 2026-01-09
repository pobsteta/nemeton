# create_fixtures.R
# Script to generate test fixtures for v0.3.0 indicators
# Run this script from tests/testthat/fixtures/ directory

library(sf)
library(terra)

# Get bounding box from massif_demo_units
data(massif_demo_units, package = "nemeton")
bbox <- st_bbox(massif_demo_units)
crs_lambert93 <- st_crs(2154)

# ===== T006: Protected Areas Demo =====
# Create synthetic protected area polygons (ZNIEFF-like zones)
set.seed(42)

# Create 3 protected area polygons overlapping some demo units
protected_areas <- st_sf(
  zone_id = c("ZNIEFF1_001", "ZNIEFF2_002", "N2000_SCI_003"),
  zone_type = c("ZNIEFF1", "ZNIEFF2", "N2000_SCI"),
  zone_name = c(
    "Forêt de haute biodiversité",
    "Zone naturelle d'intérêt écologique",
    "Site d'importance communautaire"
  ),
  geometry = st_sfc(
    # Zone 1: NW corner (overlaps ~3 parcels)
    st_polygon(list(cbind(
      c(698500, 699500, 699500, 698500, 698500),
      c(6503000, 6503000, 6504000, 6504000, 6503000)
    ))),
    # Zone 2: Center (overlaps ~5 parcels)
    st_polygon(list(cbind(
      c(699800, 701200, 701200, 699800, 699800),
      c(6500500, 6500500, 6502000, 6502000, 6500500)
    ))),
    # Zone 3: SE corner (overlaps ~2 parcels)
    st_polygon(list(cbind(
      c(701500, 702500, 702500, 701500, 701500),
      c(6499500, 6499500, 6500500, 6500500, 6499500)
    ))),
    crs = crs_lambert93
  ),
  crs = crs_lambert93
)

saveRDS(protected_areas, "protected_areas/protected_areas_demo.rds")
message("✓ Created protected_areas_demo.rds (3 zones)")

# ===== T007: Land Cover Rasters =====
# Create synthetic Corine Land Cover rasters for T2 (land use change)

# Extent slightly larger than bbox
ext_raster <- ext(bbox[1] - 100, bbox[3] + 100, bbox[2] - 100, bbox[4] + 100)

# Resolution: 100m (CLC standard)
# Create small rasters for testing (50x50 cells)
ncol_raster <- 50
nrow_raster <- 50

# Land cover 1990 (baseline)
set.seed(1990)
lc_1990 <- rast(
  nrows = nrow_raster, ncols = ncol_raster,
  extent = ext_raster,
  crs = "EPSG:2154"
)
# CLC classes: 311 = broadleaf, 312 = conifer, 313 = mixed, 231 = grassland
values(lc_1990) <- sample(c(311, 312, 313, 231), ncol_raster * nrow_raster,
  replace = TRUE, prob = c(0.4, 0.3, 0.2, 0.1)
)

# Land cover 2020 (with some changes ~10% transition)
set.seed(2020)
lc_2020 <- lc_1990 # Start with 1990
change_cells <- sample(1:ncell(lc_2020), size = round(ncell(lc_2020) * 0.1))
values(lc_2020)[change_cells] <- sample(c(311, 312, 313, 231), length(change_cells),
  replace = TRUE
)

terra::writeRaster(lc_1990, "land_cover/land_cover_1990.tif", overwrite = TRUE)
terra::writeRaster(lc_2020, "land_cover/land_cover_2020.tif", overwrite = TRUE)
message("✓ Created land_cover_1990.tif and land_cover_2020.tif (50x50 cells, ~10% change)")

# ===== T007b: Digital Elevation Model (DEM) =====
# Create synthetic DEM for R1 (fire/slope), R2 (storm/exposure)

set.seed(300)
dem_raster <- rast(
  nrows = nrow_raster, ncols = ncol_raster,
  extent = ext_raster,
  crs = "EPSG:2154"
)

# Elevation: 200-800m with gentle slope and some variability
# Create realistic terrain with east-west gradient + noise
x_coords <- rep(seq_len(ncol(dem_raster)), each = nrow(dem_raster))
y_coords <- rep(seq_len(nrow(dem_raster)), times = ncol(dem_raster))

elevation_base <- 400 + (x_coords / ncol(dem_raster)) * 200 # East-west gradient
elevation_noise <- rnorm(ncell(dem_raster), mean = 0, sd = 50) # Local variation
elevation_values <- elevation_base + elevation_noise

values(dem_raster) <- pmax(150, pmin(850, elevation_values)) # Clamp to realistic range

terra::writeRaster(dem_raster, "climate/dem_demo.tif", overwrite = TRUE)
message("✓ Created dem_demo.tif (200-800m elevation)")

# ===== T008: Climate Data =====
# Create synthetic climate rasters for R1 (fire risk) and R3 (drought)

# Temperature raster (for fire risk)
set.seed(100)
temp_raster <- rast(
  nrows = nrow_raster, ncols = ncol_raster,
  extent = ext_raster,
  crs = "EPSG:2154"
)
# Mean annual temperature: 10-15°C with spatial gradient
temp_values <- 12 + rnorm(ncell(temp_raster), mean = 0, sd = 1.5)
values(temp_raster) <- pmax(8, pmin(16, temp_values)) # Clamp to realistic range

# Precipitation raster (for fire and drought risk)
set.seed(200)
precip_raster <- rast(
  nrows = nrow_raster, ncols = ncol_raster,
  extent = ext_raster,
  crs = "EPSG:2154"
)
# Annual precipitation: 600-1200mm with spatial variability
precip_values <- 900 + rnorm(ncell(precip_raster), mean = 0, sd = 150)
values(precip_raster) <- pmax(500, pmin(1400, precip_values))

# Save as individual TIF files
terra::writeRaster(temp_raster, "climate/temperature_demo.tif", overwrite = TRUE)
terra::writeRaster(precip_raster, "climate/precipitation_demo.tif", overwrite = TRUE)
message("✓ Created temperature_demo.tif and precipitation_demo.tif")

message("\n=== All test fixtures created successfully ===")
message("Location: tests/testthat/fixtures/")
message("- protected_areas_demo.rds: 3 protected zones")
message("- land_cover_1990.tif: 50x50 cells, CLC classes")
message("- land_cover_2020.tif: 50x50 cells, ~10% change from 1990")
message("- dem_demo.tif: 200-800m elevation raster")
message("- temperature_demo.tif, precipitation_demo.tif: climate rasters")
