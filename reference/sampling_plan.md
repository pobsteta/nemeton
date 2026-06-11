# Sampling Plan Generator (GRTS + stratification)

Build a field sampling plan from a study area, with optional
stratification on CHM height, forest type (BD Foret polygons) and
topographic position (TPI from a DEM). The draw prefers spsurvey GRTS
(spatially balanced, stratified), falls back to BalancedSampling LPM2
(spatially balanced only), then to a plain spatial random draw.

This is a library version of the pipeline taught in tutorial
`09-sampling`. It degrades gracefully: without any optional input it
produces a spatial random draw equivalent to a single call to
[`st_sample`](https://r-spatial.github.io/sf/reference/st_sample.html).
