pkgname <- "nemeton"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
base::assign(".ExTimings", "nemeton-Ex.timings", pos = 'CheckExEnv')
base::cat("name\tuser\tsystem\telapsed\n", file=base::get(".ExTimings", pos = 'CheckExEnv'))
base::assign(".format_ptime",
function(x) {
  if(!is.na(x[4L])) x[1L] <- x[1L] + x[4L]
  if(!is.na(x[5L])) x[2L] <- x[2L] + x[5L]
  options(OutDec = '.')
  format(x[1L:3L], digits = 7L)
},
pos = 'CheckExEnv')

### * </HEADER>
library('nemeton')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("calculate_change_rate")
### * calculate_change_rate

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: calculate_change_rate
### Title: Calculate Change Rates Between Periods
### Aliases: calculate_change_rate

### ** Examples

## Not run: 
##D # Calculate carbon change rates
##D rates <- calculate_change_rate(
##D   temporal,
##D   indicators = c("C1", "W3"),
##D   type = "both"
##D )
##D 
##D # View change rates
##D summary(rates[, c("C1_rate_abs", "C1_rate_rel")])
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("calculate_change_rate", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("create_composite_index")
### * create_composite_index

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: create_composite_index
### Title: Create composite index from multiple indicators
### Aliases: create_composite_index

### ** Examples

## Not run: 
##D # Equal weights
##D results <- create_composite_index(
##D   normalized_data,
##D   indicators = c("carbon_norm", "biodiversity_norm", "water_norm")
##D )
##D 
##D # Custom weights (carbon 50%, biodiversity 30%, water 20%)
##D results <- create_composite_index(
##D   normalized_data,
##D   indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
##D   weights = c(0.5, 0.3, 0.2),
##D   name = "ecosystem_health"
##D )
##D 
##D # Geometric mean for multiplicative effects
##D results <- create_composite_index(
##D   normalized_data,
##D   indicators = c("carbon_norm", "water_norm"),
##D   aggregation = "geometric_mean"
##D )
##D 
##D # Limiting factor approach
##D results <- create_composite_index(
##D   normalized_data,
##D   indicators = c("carbon_norm", "biodiversity_norm"),
##D   aggregation = "min",
##D   name = "conservation_potential"
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("create_composite_index", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("create_family_index")
### * create_family_index

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: create_family_index
### Title: Create Family Composite Indices
### Aliases: create_family_index

### ** Examples

## Not run: 
##D # Setup multi-family indicators
##D data(massif_demo_units)
##D units <- massif_demo_units[1:5, ]
##D units$C1 <- rnorm(5, 50, 10)  # Carbon biomass
##D units$C2 <- rnorm(5, 70, 10)  # Carbon NDVI
##D units$W1 <- rnorm(5, 15, 5)   # Water network
##D 
##D # Create family indices
##D units_fam <- create_family_index(units)
##D 
##D # With custom weights
##D units_fam <- create_family_index(
##D   units,
##D   weights = list(C = c(C1 = 0.7, C2 = 0.3))
##D )
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("create_family_index", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_accessibility")
### * indicator_accessibility

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_accessibility
### Title: Calculate accessibility indicator
### Aliases: indicator_accessibility

### ** Examples

## Not run: 
##D # Accessibility (higher = more accessible)
##D accessibility <- indicator_accessibility(units, layers)
##D 
##D # Remoteness (higher = more remote)
##D remoteness <- indicator_accessibility(
##D   units, layers,
##D   invert = TRUE
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_accessibility", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_biodiversity")
### * indicator_biodiversity

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_biodiversity
### Title: Calculate biodiversity indicator
### Aliases: indicator_biodiversity

### ** Examples

## Not run: 
##D # Species richness
##D richness <- indicator_biodiversity(units, layers, index = "richness")
##D 
##D # Shannon index
##D shannon <- indicator_biodiversity(
##D   units, layers,
##D   richness_layer = "shannon_index",
##D   index = "shannon"
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_biodiversity", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_carbon")
### * indicator_carbon

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_carbon
### Title: Calculate carbon stock indicator
### Aliases: indicator_carbon

### ** Examples

## Not run: 
##D carbon <- indicator_carbon(units, layers, biomass_layer = "agb")
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_carbon", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_carbon_biomass")
### * indicator_carbon_biomass

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_carbon_biomass
### Title: Carbon Stock via Biomass and Allometric Models (C1)
### Aliases: indicator_carbon_biomass

### ** Examples

## Not run: 
##D # With BD Forêt attributes
##D units$species <- c("Quercus", "Fagus", "Pinus")
##D units$age <- c(80, 60, 40)
##D units$density <- c(0.7, 0.8, 0.6)
##D 
##D results <- indicator_carbon_biomass(units)
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_carbon_biomass", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_carbon_ndvi")
### * indicator_carbon_ndvi

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_carbon_ndvi
### Title: NDVI Mean and Trend Analysis (C2)
### Aliases: indicator_carbon_ndvi

### ** Examples

## Not run: 
##D # Single-date NDVI
##D layers <- nemeton_layers(rasters = list(ndvi = "sentinel2_ndvi.tif"))
##D results <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi")
##D 
##D # Multi-date NDVI with trend
##D results <- indicator_carbon_ndvi(units, layers, ndvi_layer = "ndvi", trend = TRUE)
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_carbon_ndvi", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_fragmentation")
### * indicator_fragmentation

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_fragmentation
### Title: Calculate forest fragmentation indicator
### Aliases: indicator_fragmentation

### ** Examples

## Not run: 
##D # Forest percentage
##D forest_pct <- indicator_fragmentation(
##D   units, layers,
##D   forest_values = c(1, 2, 3)
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_fragmentation", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_landscape_edge")
### * indicator_landscape_edge

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_landscape_edge
### Title: Edge-to-Area Ratio (L2)
### Aliases: indicator_landscape_edge

### ** Examples

## Not run: 
##D results <- indicator_landscape_edge(units)
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_landscape_edge", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_landscape_fragmentation")
### * indicator_landscape_fragmentation

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_landscape_fragmentation
### Title: Landscape Fragmentation (L1)
### Aliases: indicator_landscape_fragmentation

### ** Examples

## Not run: 
##D layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
##D results <- indicator_landscape_fragmentation(
##D   units, layers, forest_values = c(1, 2, 3), buffer = 1000
##D )
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_landscape_fragmentation", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_soil_erosion")
### * indicator_soil_erosion

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_soil_erosion
### Title: Erosion Risk Index (F2)
### Aliases: indicator_soil_erosion

### ** Examples

## Not run: 
##D layers <- nemeton_layers(
##D   rasters = list(dem = "dem.tif", landcover = "landcover.tif")
##D )
##D results <- indicator_soil_erosion(units, layers, forest_values = c(1, 2, 3))
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_soil_erosion", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_soil_fertility")
### * indicator_soil_fertility

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_soil_fertility
### Title: Soil Fertility Class (F1)
### Aliases: indicator_soil_fertility

### ** Examples

## Not run: 
##D layers <- nemeton_layers(vectors = list(soil = "bd_sol.gpkg"))
##D results <- indicator_soil_fertility(units, layers, soil_layer = "soil")
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_soil_fertility", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_water")
### * indicator_water

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_water
### Title: Calculate water regulation indicator
### Aliases: indicator_water

### ** Examples

## Not run: 
##D water_reg <- indicator_water(units, layers)
##D 
##D # TWI only
##D twi <- indicator_water(
##D   units, layers,
##D   calculate_proximity = FALSE
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_water", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_water_network")
### * indicator_water_network

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_water_network
### Title: Hydrographic Network Density (W1)
### Aliases: indicator_water_network

### ** Examples

## Not run: 
##D layers <- nemeton_layers(vectors = list(streams = "watercourses.gpkg"))
##D results <- indicator_water_network(units, layers, watercourse_layer = "streams")
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_water_network", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_water_twi")
### * indicator_water_twi

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_water_twi
### Title: Topographic Wetness Index (W3)
### Aliases: indicator_water_twi

### ** Examples

## Not run: 
##D layers <- nemeton_layers(rasters = list(dem = "dem_25m.tif"))
##D results <- indicator_water_twi(units, layers, dem_layer = "dem")
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_water_twi", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("indicator_water_wetlands")
### * indicator_water_wetlands

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: indicator_water_wetlands
### Title: Wetland Coverage (W2)
### Aliases: indicator_water_wetlands

### ** Examples

## Not run: 
##D layers <- nemeton_layers(rasters = list(landcover = "landcover.tif"))
##D results <- indicator_water_wetlands(units, layers, wetland_values = c(50, 51, 52))
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("indicator_water_wetlands", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("invert_indicator")
### * invert_indicator

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: invert_indicator
### Title: Invert indicator values
### Aliases: invert_indicator

### ** Examples

## Not run: 
##D # Invert accessibility for wilderness index
##D data <- invert_indicator(
##D   data,
##D   indicators = "accessibility_norm",
##D   suffix = "_wilderness"
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("invert_indicator", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("list_indicators")
### * list_indicators

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: list_indicators
### Title: List available indicators
### Aliases: list_indicators

### ** Examples

## Not run: 
##D # Get all indicator names
##D list_indicators()
##D 
##D # Get details
##D list_indicators(return_type = "details")
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("list_indicators", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("massif_demo_layers")
### * massif_demo_layers

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: massif_demo_layers
### Title: Load Massif Demo Spatial Layers
### Aliases: massif_demo_layers

### ** Examples

# Load demo parcels and layers
data(massif_demo_units)
layers <- massif_demo_layers()

# Inspect layers
print(layers)

## Not run: 
##D # Compute all indicators
##D results <- nemeton_compute(
##D   massif_demo_units,
##D   layers,
##D   indicators = "all",
##D   preprocess = TRUE
##D )
##D 
##D # Carbon indicator only
##D carbon <- nemeton_compute(
##D   massif_demo_units,
##D   layers,
##D   indicators = "carbon",
##D   preprocess = TRUE
##D )
##D 
##D # Water regulation (using DEM and water courses)
##D water <- nemeton_compute(
##D   massif_demo_units,
##D   layers,
##D   indicators = "water",
##D   preprocess = TRUE
##D )
##D 
##D # Fragmentation (using land cover)
##D fragmentation <- nemeton_compute(
##D   massif_demo_units,
##D   layers,
##D   indicators = "fragmentation",
##D   forest_values = c(1, 2, 3),  # Forest classes
##D   preprocess = TRUE
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("massif_demo_layers", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("massif_demo_units")
### * massif_demo_units

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: massif_demo_units
### Title: Massif Demo - Example Forest Dataset
### Aliases: massif_demo_units
### Keywords: datasets

### ** Examples

# Load the demo dataset
data(massif_demo_units)

# Inspect parcels
print(massif_demo_units)
summary(massif_demo_units$surface_ha)
table(massif_demo_units$forest_type)

# Plot parcels
if (require("ggplot2")) {
  ggplot(massif_demo_units) +
    geom_sf(aes(fill = forest_type)) +
    theme_minimal() +
    labs(title = "Massif Demo - Forest Types")
}

## Not run: 
##D # Complete workflow example
##D library(nemeton)
##D 
##D # 1. Load data
##D data(massif_demo_units)
##D layers <- massif_demo_layers()
##D 
##D # 2. Compute all indicators
##D results <- nemeton_compute(
##D   massif_demo_units,
##D   layers,
##D   indicators = "all",
##D   preprocess = TRUE
##D )
##D 
##D # 3. Normalize indicators
##D normalized <- normalize_indicators(
##D   results,
##D   indicators = c("carbon", "biodiversity", "water"),
##D   method = "minmax"
##D )
##D 
##D # 4. Create ecosystem health index
##D health <- create_composite_index(
##D   normalized,
##D   indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
##D   weights = c(0.4, 0.4, 0.2),
##D   name = "ecosystem_health"
##D )
##D 
##D # 5. Visualize
##D plot_indicators_map(
##D   health,
##D   indicators = "ecosystem_health",
##D   palette = "RdYlGn",
##D   title = "Ecosystem Health - Massif Demo"
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("massif_demo_units", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("nemeton_compute")
### * nemeton_compute

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: nemeton_compute
### Title: Calculate Nemeton indicators for spatial units
### Aliases: nemeton_compute

### ** Examples

## Not run: 
##D library(nemeton)
##D 
##D # Create units
##D units <- nemeton_units(sf::st_read("parcels.gpkg"))
##D 
##D # Create layer catalog
##D layers <- nemeton_layers(
##D   rasters = list(
##D     biomass = "biomass.tif",
##D     dem = "dem.tif"
##D   ),
##D   vectors = list(
##D     roads = "roads.gpkg"
##D   )
##D )
##D 
##D # Calculate all indicators
##D results <- nemeton_compute(units, layers)
##D 
##D # Calculate specific indicators
##D results <- nemeton_compute(
##D   units, layers,
##D   indicators = c("carbon", "biodiversity")
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("nemeton_compute", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("nemeton_layers")
### * nemeton_layers

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: nemeton_layers
### Title: Create nemeton_layers object
### Aliases: nemeton_layers

### ** Examples

## Not run: 
##D layers <- nemeton_layers(
##D   rasters = list(
##D     ndvi = "data/sentinel2_ndvi.tif",
##D     dem = "data/ign_mnt_25m.tif"
##D   ),
##D   vectors = list(
##D     rivers = "data/bdtopo_hydro.gpkg",
##D     roads = "data/routes.shp"
##D   )
##D )
##D 
##D summary(layers)
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("nemeton_layers", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("nemeton_radar")
### * nemeton_radar

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: nemeton_radar
### Title: Create radar chart for indicator profile
### Aliases: nemeton_radar

### ** Examples

## Not run: 
##D # Load demo data
##D data(massif_demo_units)
##D layers <- massif_demo_layers()
##D results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
##D normalized <- normalize_indicators(results)
##D 
##D # Radar for a specific unit (indicator mode)
##D nemeton_radar(normalized, unit_id = "unit_001")
##D 
##D # Radar for average of all units
##D nemeton_radar(normalized)
##D 
##D # Custom indicators and styling
##D nemeton_radar(
##D   normalized,
##D   unit_id = "unit_005",
##D   indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
##D   fill_color = "#d73027",
##D   fill_alpha = 0.5
##D )
##D 
##D # Family mode with 12 families
##D # First create family indices
##D units_fam <- create_family_index(normalized)
##D nemeton_radar(units_fam, unit_id = 1, mode = "family")
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("nemeton_radar", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("nemeton_set_language")
### * nemeton_set_language

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: nemeton_set_language
### Title: Set language manually
### Aliases: nemeton_set_language

### ** Examples

## Not run: 
##D # Set French
##D nemeton_set_language("fr")
##D 
##D # Set English
##D nemeton_set_language("en")
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("nemeton_set_language", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("nemeton_temporal")
### * nemeton_temporal

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: nemeton_temporal
### Title: Create Multi-Period Temporal Dataset
### Aliases: nemeton_temporal

### ** Examples

## Not run: 
##D # Load demo data for two periods
##D data(massif_demo_units)
##D results_2015 <- nemeton_compute(massif_demo_units, layers_2015, indicators = "C1")
##D results_2020 <- nemeton_compute(massif_demo_units, layers_2020, indicators = "C1")
##D 
##D # Create temporal dataset
##D temporal <- nemeton_temporal(
##D   periods = list("2015" = results_2015, "2020" = results_2020),
##D   dates = c("2015-01-01", "2020-01-01"),
##D   labels = c("Baseline", "Current")
##D )
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("nemeton_temporal", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("nemeton_units")
### * nemeton_units

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: nemeton_units
### Title: Create nemeton_units object
### Aliases: nemeton_units

### ** Examples

## Not run: 
##D library(sf)
##D 
##D # From sf object
##D polygons <- st_read("parcels.gpkg")
##D units <- nemeton_units(
##D   polygons,
##D   metadata = list(
##D     site_name = "Forêt de Fontainebleau",
##D     year = 2024,
##D     source = "IGN BD Forêt v2"
##D   )
##D )
##D 
##D # From file path
##D units <- nemeton_units(
##D   "parcels.gpkg",
##D   id_col = "parcel_id",
##D   metadata = list(site_name = "Test Forest")
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("nemeton_units", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("normalize_indicators")
### * normalize_indicators

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: normalize_indicators
### Title: Normalize indicator values
### Aliases: normalize_indicators

### ** Examples

## Not run: 
##D # Normalize all indicators with min-max
##D normalized <- normalize_indicators(
##D   results,
##D   indicators = c("carbon", "biodiversity", "water"),
##D   method = "minmax"
##D )
##D 
##D # Z-score normalization
##D normalized_z <- normalize_indicators(
##D   results,
##D   method = "zscore",
##D   suffix = "_z"
##D )
##D 
##D # Normalize using reference dataset
##D new_normalized <- normalize_indicators(
##D   new_data,
##D   indicators = c("carbon", "water"),
##D   reference_data = reference_results
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("normalize_indicators", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("plot_comparison_map")
### * plot_comparison_map

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: plot_comparison_map
### Title: Create comparison map (before/after or scenarios)
### Aliases: plot_comparison_map

### ** Examples

## Not run: 
##D plot_comparison_map(
##D   current_state,
##D   future_scenario,
##D   indicator = "ecosystem_health",
##D   labels = c("Current (2024)", "Future (2050)"),
##D   palette = "RdYlGn"
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("plot_comparison_map", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("plot_difference_map")
### * plot_difference_map

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: plot_difference_map
### Title: Create difference map (change visualization)
### Aliases: plot_difference_map

### ** Examples

## Not run: 
##D plot_difference_map(
##D   current_state,
##D   future_scenario,
##D   indicator = "carbon",
##D   type = "relative",
##D   title = "Carbon Stock Change (%)"
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("plot_difference_map", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("plot_indicators_map")
### * plot_indicators_map

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: plot_indicators_map
### Title: Create thematic maps for indicators
### Aliases: plot_indicators_map

### ** Examples

## Not run: 
##D # Single indicator map
##D plot_indicators_map(
##D   results,
##D   indicators = "carbon",
##D   palette = "Greens",
##D   title = "Carbon Stock Distribution"
##D )
##D 
##D # Multiple indicators (faceted)
##D plot_indicators_map(
##D   normalized,
##D   indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
##D   palette = "viridis",
##D   facet = TRUE,
##D   ncol = 3
##D )
##D 
##D # Composite index with custom breaks
##D plot_indicators_map(
##D   results,
##D   indicators = "ecosystem_health",
##D   palette = "RdYlGn",
##D   breaks = c(0, 25, 50, 75, 100),
##D   labels = c("Low", "Medium-Low", "Medium-High", "High", "Very High")
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("plot_indicators_map", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("plot_temporal_heatmap")
### * plot_temporal_heatmap

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: plot_temporal_heatmap
### Title: Plot Temporal Heatmap
### Aliases: plot_temporal_heatmap

### ** Examples

## Not run: 
##D # Create temporal dataset
##D temporal <- nemeton_temporal(
##D   periods = list("2015" = units_2015, "2020" = units_2020),
##D   id_column = "parcel_id"
##D )
##D 
##D # Plot heatmap for unit P1
##D plot_temporal_heatmap(temporal, unit_id = "P1")
##D 
##D # With normalization
##D plot_temporal_heatmap(temporal, unit_id = "P1", normalize = TRUE)
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("plot_temporal_heatmap", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("plot_temporal_trend")
### * plot_temporal_trend

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: plot_temporal_trend
### Title: Plot Temporal Trend (Time-Series)
### Aliases: plot_temporal_trend

### ** Examples

## Not run: 
##D # Create temporal dataset
##D temporal <- nemeton_temporal(
##D   periods = list("2015" = units_2015, "2020" = units_2020)
##D )
##D 
##D # Plot carbon trend
##D plot_temporal_trend(temporal, indicator = "C1")
##D 
##D # Multiple indicators
##D plot_temporal_trend(temporal, indicator = c("C1", "W1"))
## End(Not run)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("plot_temporal_trend", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
