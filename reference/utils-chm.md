# CHM (Canopy Height Model) utilities

Helpers to sanitize and exploit Canopy Height Model rasters produced by
external sources such as the `opencanopy` package (pobsteta/opencanopy)
or LiDAR HD.

## Details

The main entry point is
[`sanitize_chm`](https://pobsteta.github.io/nemeton/reference/sanitize_chm.md),
a 5-step pipeline that masks out pixels where a forest height is
implausible (outside forest areas, buildings/water, low-NDVI,
out-of-range values, steep slopes). Sanitized CHMs are suitable inputs
for `P1` (volume), `P2` (site index) and other indicators that exploit
height information (see spec 005).
