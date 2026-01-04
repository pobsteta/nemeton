# Developer Quickstart: nemeton MVP

**Branch**: 001-mvp-v0.1.0
**Date**: 2026-01-04

Ce guide permet aux développeurs de démarrer rapidement l'implémentation du MVP du package nemeton.

---

## Prerequisites

### System Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y \
  libgdal-dev \
  libgeos-dev \
  libproj-dev \
  libudunits2-dev

# macOS (via Homebrew)
brew install gdal geos proj udunits

# Windows
# Installer RTools + OSGeo4W (GDAL/GEOS/PROJ)
```

### R Environment

```r
# R >= 4.1.0 requis
R.version$version.string

# Installer devtools
install.packages("devtools")
```

---

## Setup: Create Package Structure

### 1. Initialize Package

```r
# Depuis R console dans répertoire parent
usethis::create_package("nemeton")

# Ou depuis terminal
R -e 'usethis::create_package("nemeton")'

cd nemeton
```

### 2. Configure DESCRIPTION

Éditer `DESCRIPTION` :

```yaml
Package: nemeton
Type: Package
Title: Systemic Forest Analysis Using the Nemeton Method
Version: 0.1.0
Authors@R: c(
    person("Your", "Name", email = "you@example.com", role = c("aut", "cre"))
  )
Description: Implement the Nemeton method for systemic forest territory analysis.
    Calculate biophysical indicators (carbon, biodiversity, water, fragmentation,
    accessibility) from open spatial data, normalize to composite indices, and
    visualize results.
License: MIT + file LICENSE
Encoding: UTF-8
LazyData: true
Depends:
    R (>= 4.1.0)
Imports:
    sf (>= 1.0-0),
    terra (>= 1.7-0),
    exactextractr (>= 0.9.0),
    dplyr (>= 1.1.0),
    ggplot2 (>= 3.4.0),
    rlang (>= 1.1.0),
    cli (>= 3.6.0)
Suggests:
    testthat (>= 3.0.0),
    knitr,
    rmarkdown,
    covr,
    units
RoxygenNote: 7.2.0
VignetteBuilder: knitr
URL: https://github.com/yourorg/nemeton
BugReports: https://github.com/yourorg/nemeton/issues
```

### 3. Create Directory Structure

```bash
# Créer structure complète
mkdir -p R man data data-raw inst/extdata tests/testthat/fixtures vignettes

# Créer fichiers standards
touch README.md NEWS.md LICENSE
```

### 4. Setup Git

```bash
git init
usethis::use_git()

# .gitignore
usethis::use_git_ignore(c("*.Rproj.user", ".Rhistory", ".RData", ".Ruserdata", "*.o", "*.so", "*.dll"))
```

---

## Development Workflow

### Phase 1: Core Infrastructure

**Files to create** (in order):

1. **`R/utils.R`** (Utilitaires internes)
```r
#' Check CRS compatibility
#' @keywords internal
check_crs <- function(x, y) {
  # Implementation
}

#' Validate sf object
#' @keywords internal
validate_sf <- function(x, require_crs = TRUE) {
  # Implementation
}

#' Formatted message helper
#' @keywords internal
message_nemeton <- function(...) {
  cli::cli_alert_info(...)
}
```

2. **`R/nemeton-class.R`** (Classes S3)
```r
#' Create nemeton_units object
#' @export
nemeton_units <- function(x, id_col = NULL, metadata = list(), validate = TRUE) {
  # Voir contracts/api-core.md pour spec complète
}

#' @export
print.nemeton_units <- function(x, ...) {
  # Implementation
}

#' Create nemeton_layers object
#' @export
nemeton_layers <- function(rasters = NULL, vectors = NULL, validate = TRUE) {
  # Voir contracts/api-core.md
}
```

3. **`R/data-units.R`**, **`R/data-layers.R`**, **`R/data-preprocessing.R`**

4. **`R/indicators-core.R`**, **`R/indicators-biophysical.R`**

5. **`R/normalization.R`**, **`R/visualization.R`**

### Phase 2: Tests (TDD)

**Pour chaque module, créer tests AVANT implémentation** :

```r
# tests/testthat/test-units.R

test_that("nemeton_units creates valid object from sf", {
  # Setup
  polygons <- sf::st_as_sf(
    data.frame(
      id = 1:3,
      value = c(10, 20, 30)
    ),
    coords = c("x", "y"),  # Adapter selon géométrie réelle
    crs = 4326
  )

  # Execute
  units <- nemeton_units(polygons)

  # Assert
  expect_s3_class(units, "nemeton_units")
  expect_s3_class(units, "sf")
  expect_true("nemeton_id" %in% names(units))
  expect_equal(nrow(units), 3)
})

test_that("nemeton_units validates geometries", {
  # Test avec géométrie invalide
  # ...
})
```

### Phase 3: Documentation

**Pour chaque fonction exportée** :

```r
#' Calculate carbon stock indicator
#'
#' Computes carbon stock (above-ground biomass) for spatial units from biomass raster.
#'
#' @param units An `sf` object or `nemeton_units` representing analysis units
#' @param layers A `nemeton_layers` object containing spatial layers
#' @param biomass_layer Character. Name of the biomass raster layer. Default: "biomass"
#' @param method Character. Aggregation method: "sum" (total per unit) or "mean" (density).
#'   Default: "sum"
#' @param fun Character. Aggregation function: "sum", "mean", "median". Default: "sum"
#' @param na.rm Logical. Remove NA values? Default: TRUE
#' @param conversion_factor Numeric. Biomass to carbon conversion factor (IPCC default: 0.47).
#'   Default: 0.47
#'
#' @return Numeric vector of length `nrow(units)` with carbon stock values (tonnes)
#'
#' @details
#' The function uses `exactextractr::exact_extract()` for efficient zonal extraction.
#' Biomass raster is expected in tonnes/hectare of above-ground biomass.
#' Carbon stock is calculated as: carbon = biomass * conversion_factor.
#'
#' @examples
#' \dontrun{
#' library(nemeton)
#' units <- nemeton_units(sf::st_read("parcels.gpkg"))
#' layers <- nemeton_layers(rasters = list(biomass = "biomass.tif"))
#' carbon <- indicator_carbon(units, layers, method = "sum")
#' }
#'
#' @seealso [nemeton_compute()], [indicator_biodiversity()]
#'
#' @export
indicator_carbon <- function(units, layers, biomass_layer = "biomass", ...) {
  # Implementation
}
```

**Générer documentation** :

```r
devtools::document()  # Génère man/*.Rd
```

---

## Testing Strategy

### Run Tests

```r
# Tous les tests
devtools::test()

# Test spécifique
devtools::test_file("tests/testthat/test-units.R")

# Avec couverture
covr::package_coverage()
```

### Fixtures de Test

**Créer données synthétiques** :

```r
# tests/testthat/fixtures/create_fixtures.R

library(sf)
library(terra)

# Polygones de test
test_units <- st_sf(
  id = paste0("unit_", sprintf("%03d", 1:10)),
  area = runif(10, 10, 50),
  geometry = st_sfc(lapply(1:10, function(i) {
    st_polygon(list(matrix(c(
      i, i, i+1, i+1, i,
      0, 1, 1, 0, 0
    ), ncol = 2)))
  }), crs = 4326)
)

st_write(test_units, "tests/testthat/fixtures/demo_units.gpkg", delete_dsn = TRUE)

# Raster de test
r <- rast(ncols = 100, nrows = 100, xmin = 0, xmax = 10, ymin = 0, ymax = 10)
values(r) <- runif(ncell(r), 50, 150)  # Biomasse fictive
writeRaster(r, "tests/testthat/fixtures/demo_raster_small.tif", overwrite = TRUE)

# Valeurs attendues pour régression
expected_carbon <- c(120.5, 95.3, 150.2, ...)  # Calculées une fois
saveRDS(expected_carbon, "tests/testthat/fixtures/expected_carbon.rds")
```

---

## Example Data (Shipped with Package)

### Create massif_demo Dataset

```r
# data-raw/massif_demo.R

library(sf)
library(terra)

# 50 parcelles fictives en forêt de Fontainebleau
set.seed(42)

# Générer polygones
massif_demo <- st_sf(
  nemeton_id = paste0("unit_", sprintf("%03d", 1:50)),
  area_ha = runif(50, 15, 60),
  forest_type = sample(c("Chêne", "Hêtre", "Pin", "Mixte"), 50, replace = TRUE),
  geometry = st_sfc(lapply(1:50, function(i) {
    # Logique génération polygones réalistes
    # ...
  }), crs = 2154)  # Lambert 93
)

# Métadonnées
attr(massif_demo, "metadata") <- list(
  site_name = "Forêt de Fontainebleau (fictive)",
  year = 2024,
  source = "Données synthétiques pour démonstration",
  description = "50 parcelles forestières fictives pour exemples du package"
)

# Sauvegarder
usethis::use_data(massif_demo, overwrite = TRUE)
```

**Documenter** :

```r
#' Example forest dataset
#'
#' Synthetic forest parcels dataset for package demonstrations and vignettes.
#' Represents 50 fictional parcels in Fontainebleau forest.
#'
#' @format An `sf` object (POLYGON) with 50 rows and 3 variables:
#' \describe{
#'   \item{nemeton_id}{Character. Unique identifier (unit_001 to unit_050)}
#'   \item{area_ha}{Numeric. Parcel area in hectares}
#'   \item{forest_type}{Character. Forest type (Chêne, Hêtre, Pin, Mixte)}
#'   \item{geometry}{sfc_POLYGON. Geometry column (CRS: EPSG:2154 - Lambert 93)}
#' }
#'
#' @source Synthetic data generated for package demonstration
#'
#' @examples
#' data(massif_demo)
#' plot(massif_demo["forest_type"])
#'
#' @seealso [nemeton_units()]
"massif_demo"
```

---

## Vignettes

### Create Vignette

```r
usethis::use_vignette("intro-nemeton")
usethis::use_vignette("workflow-basic")
```

**Template `vignettes/workflow-basic.Rmd`** :

```rmd
---
title: "Basic Workflow: Forest Analysis with nemeton"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Basic Workflow}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

## Introduction

This vignette demonstrates a complete workflow from loading data to visualization.

## Load Example Data

```{r setup}
library(nemeton)
library(sf)

data(massif_demo)
plot(massif_demo)
```

## Create Units

```{r units}
units <- nemeton_units(
  massif_demo,
  metadata = list(
    site_name = "Forêt de Fontainebleau",
    year = 2024
  )
)

print(units)
```

... [Continuer workflow complet]
```

---

## Check & Build

### Development Checks

```r
# Check complet (requis avant commit)
devtools::check()

# Build documentation
devtools::document()

# Build vignettes
devtools::build_vignettes()

# Lint code style
lintr::lint_package()

# Format code
styler::style_pkg()
```

### Installation Locale

```r
# Installer en mode dev
devtools::load_all()

# Installer comme package
devtools::install()
```

---

## CI/CD Setup (GitHub Actions)

### Create Workflow

```r
usethis::use_github_action("check-standard")
usethis::use_github_action("test-coverage")
```

Crée `.github/workflows/R-CMD-check.yaml` et `test-coverage.yaml`

---

## Cheat Sheet: Common Commands

| Task | Command |
|------|---------|
| Load package | `devtools::load_all()` |
| Run tests | `devtools::test()` |
| Check package | `devtools::check()` |
| Document | `devtools::document()` |
| Build | `devtools::build()` |
| Install | `devtools::install()` |
| Coverage | `covr::package_coverage()` |
| Lint | `lintr::lint_package()` |
| Style | `styler::style_pkg()` |

---

## Implementation Order (Recommended)

### Sprint 1 (Week 1-2): Core Infrastructure
1. Setup package structure
2. `R/utils.R` (helpers)
3. `R/nemeton-class.R` (classes S3)
4. `R/data-units.R` + tests
5. `R/data-layers.R` + tests
6. `R/data-preprocessing.R` + tests

**Milestone**: Can create units and layers, harmonize CRS

---

### Sprint 2 (Week 3-4): Indicators Core
1. `R/indicators-core.R` (nemeton_compute)
2. `R/indicators-biophysical.R`:
   - `indicator_carbon()` + tests
   - `indicator_biodiversity()` + tests
   - `indicator_water()` + tests
   - `indicator_fragmentation()` + tests
   - `indicator_accessibility()` + tests

**Milestone**: Can compute 5 indicators

---

### Sprint 3 (Week 5-6): Aggregation & Visualization
1. `R/normalization.R`:
   - `normalize_indicators()` + tests
   - `nemeton_index()` + tests
2. `R/visualization.R`:
   - `nemeton_map()` + tests
   - `nemeton_radar()` + tests

**Milestone**: Full workflow units → compute → index → visualize works

---

### Sprint 4 (Week 7-8): Data & Documentation
1. Create `massif_demo` dataset
2. Create rasters in `inst/extdata/`
3. Write vignette "intro-nemeton"
4. Write vignette "workflow-basic"
5. Write README.md with examples
6. Complete all roxygen2 documentation

**Milestone**: Package documenté, exemples fonctionnels

---

### Sprint 5 (Week 9-10): Polish & QA
1. Atteindre couverture >= 70%
2. Fixer tous warnings `devtools::check()`
3. Lint et style complet
4. GitHub Actions CI/CD
5. Revue finale

**Milestone**: MVP ready for release v0.1.0

---

## Resources

- **R Packages book**: https://r-pkgs.org/
- **sf documentation**: https://r-spatial.github.io/sf/
- **terra documentation**: https://rspatial.org/terra/
- **Tidyverse style guide**: https://style.tidyverse.org/
- **roxygen2 guide**: https://roxygen2.r-lib.org/

---

## Getting Help

- **Constitution**: `.specify/memory/constitution.md` (principes non-négociables)
- **Specification**: `SPECIFICATION_TECHNIQUE.md` (détails architecture)
- **API Contracts**: `specs/001-mvp-v0.1.0/contracts/` (signatures fonctions)
- **Data Model**: `specs/001-mvp-v0.1.0/data-model.md` (classes S3)

---

**Quickstart Complete** ✅ - Ready to start implementation!
