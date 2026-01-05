# Create thematic maps for indicators

Generates publication-ready maps visualizing indicator values across
spatial units.

## Usage

``` r
plot_indicators_map(
  data,
  indicators = NULL,
  palette = c("viridis", "RdYlGn", "YlOrRd", "Greens", "Blues"),
  direction = 1,
  title = NULL,
  legend_title = NULL,
  breaks = NULL,
  labels = NULL,
  alpha = 0.9,
  border_color = "white",
  border_size = 0.3,
  facet = TRUE,
  ncol = 2,
  base_size = 11
)
```

## Arguments

- data:

  An `sf` object with indicator values

- indicators:

  Character vector of indicator column names to plot. If NULL and
  multiple indicators present, creates faceted plot.

- palette:

  Character. Color palette to use. Options:

  - "viridis" - Perceptually uniform, colorblind-friendly (default)

  - "RdYlGn" - Red-Yellow-Green diverging (low-medium-high)

  - "YlOrRd" - Yellow-Orange-Red sequential

  - "Greens" - Green sequential

  - "Blues" - Blue sequential

- direction:

  Numeric. Direction of color scale: 1 (default) or -1 (reversed)

- title:

  Character. Plot title. If NULL, auto-generated.

- legend_title:

  Character. Legend title. If NULL, uses "Value" or indicator name.

- breaks:

  Numeric vector. Manual breaks for color scale. If NULL, automatic.

- labels:

  Character vector. Labels for breaks. Same length as breaks.

- alpha:

  Numeric. Transparency (0-1). Default 0.9.

- border_color:

  Character. Border color for polygons. Default "white".

- border_size:

  Numeric. Border line width. Default 0.3.

- facet:

  Logical. Create faceted plot for multiple indicators? Default TRUE.

- ncol:

  Integer. Number of columns for faceted plot. Default 2.

- base_size:

  Numeric. Base font size for theme. Default 11.

## Value

A `ggplot` object

## Details

Creates thematic choropleth maps using ggplot2. Supports:

- Single indicator maps

- Multi-indicator faceted maps

- Custom color palettes

- Flexible styling

The function uses
[`geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html) for
spatial rendering and applies perceptually uniform color scales by
default (viridis).

## Examples

``` r
if (FALSE) { # \dontrun{
# Single indicator map
plot_indicators_map(
  results,
  indicators = "carbon",
  palette = "Greens",
  title = "Carbon Stock Distribution"
)

# Multiple indicators (faceted)
plot_indicators_map(
  normalized,
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  palette = "viridis",
  facet = TRUE,
  ncol = 3
)

# Composite index with custom breaks
plot_indicators_map(
  results,
  indicators = "ecosystem_health",
  palette = "RdYlGn",
  breaks = c(0, 25, 50, 75, 100),
  labels = c("Low", "Medium-Low", "Medium-High", "High", "Very High")
)
} # }
```
