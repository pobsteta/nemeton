# Function Contracts: Air Quality & Microclimate Indicators (A-Family)

**Family**: A (Air Quality & Microclimate / Vaporeuse)
**Date**: 2026-01-05

## Functions

### indicator_air_coverage(units, land_cover, forest_classes = c(311, 312, 313), buffer_radius = 1000)

**Returns**: sf with `A1` (% forest coverage in buffer, 0-100)

**Calculation**: 
1. Create 1km buffer around each parcel
2. Rasterize or use existing land cover raster
3. Calculate: `A1 = (forest_pixels_in_buffer / total_pixels_in_buffer) × 100`

**Behavior**: Higher score = more forested surroundings. Uses terra for raster operations, sf for buffers.

**Parameters**:
- `land_cover`: SpatRaster with land cover classes (e.g., Corine Land Cover)
- `forest_classes`: Numeric vector of CLC codes for forests (311=broadleaf, 312=conifer, 313=mixed)
- `buffer_radius`: Buffer size in meters (default 1000m)

---

### indicator_air_quality(units, atmo_data = NULL, roads = NULL, urban_areas = NULL, method = c("auto", "direct", "proxy"), weights = c(roads = 0.7, urban = 0.3))

**Returns**: sf with `A2` (air quality index, 0-100) and `A2_method` (character: "direct" or "proxy")

**Calculation**:
- **Direct method** (if atmo_data available): Interpolate ATMO station measurements (NO2, PM10) to parcels
- **Proxy method** (fallback): 
  ```
  A2 = w1 × normalize_inverse(dist_roads) + w2 × normalize_inverse(dist_urban)
  normalize_inverse(d) = 100 × (1 - min(d, 5000) / 5000)
  ```

**Behavior**: 
- `method="auto"`: Use direct if atmo_data provided, else proxy
- Higher score = better air quality
- Logs method used in `A2_method` attribute
- Warns if using proxy (lower accuracy)

**Data Sources**:
- **atmo_data**: sf with ATMO station points and NO2/PM10 measurements
- **roads**: sf with OSM road network (motorway, trunk, primary classes)
- **urban_areas**: sf with CLC urban polygons (classes 111-142)

---

**Dependencies**: terra (rasters), sf (buffers, distances), osmdata (road data), optional: gstat (interpolation for direct method)
