# nemeton 0.1.0 (Development)

## Major Features

* Initial package structure
* Core S3 classes: `nemeton_units`, `nemeton_layers`
* Indicator calculation framework
* 5 biophysical indicators:
  - `indicator_carbon()`: Carbon stock (above-ground biomass)
  - `indicator_biodiversity()`: Biodiversity indices (Shannon, richness)
  - `indicator_water()`: Water regulation (TWI, proximity)
  - `indicator_fragmentation()`: Forest fragmentation
  - `indicator_accessibility()`: Accessibility to roads/trails
* Normalization and aggregation: `nemeton_index()`
* Visualizations: `nemeton_map()`, `nemeton_radar()`
* Example dataset: `massif_demo`

## Breaking Changes

* None (initial release)

## Bug Fixes

* None (initial release)

## Documentation

* Package vignettes: Introduction and Basic Workflow
* Complete roxygen2 documentation for all exported functions
* README with quick start guide
