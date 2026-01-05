# Create radar chart for indicator profile

Generates a radar (spider) chart showing the multi-dimensional profile
of indicators for a specific unit or the average across all units.

## Usage

``` r
nemeton_radar(
  data,
  unit_id = NULL,
  indicators = NULL,
  mode = c("indicator", "family"),
  normalize = TRUE,
  title = NULL,
  fill_color = "#3182bd",
  fill_alpha = 0.3
)
```

## Arguments

- data:

  An sf object with indicator columns

- unit_id:

  Optional. ID of the specific unit to plot. Can be a single value or a
  vector of IDs for comparison mode (v0.3.0+). If NULL, plots the
  average of all units.

- indicators:

  Character vector of indicator names to include in the radar. If NULL,
  auto-detects based on mode.

- mode:

  Character. Display mode: "indicator" for individual indicators
  (default) or "family" for family indices (family_C, family_W, etc.).
  When mode = "family", supports 4-12 family axes dynamically.

- normalize:

  Logical. If TRUE (default), normalizes values to 0-100 scale.

- title:

  Optional plot title. If NULL, auto-generated based on unit_id.

- fill_color:

  Color to fill the radar polygon. Default "#3182bd" (blue).

- fill_alpha:

  Transparency of the fill (0-1). Default 0.3.

## Value

A ggplot object

## Details

The radar chart displays multiple indicators as axes radiating from a
center point. Each axis represents one indicator, with values scaled
from center (0) to edge (100).

If `unit_id` is specified, the chart shows the profile for that specific
unit. If `unit_id` is a vector (v0.3.0+), creates a comparison chart
with multiple overlaid polygons for comparing units side-by-side. If
`unit_id` is NULL, the chart shows the mean values across all units.

Normalization is recommended when indicators have different scales. The
function applies min-max normalization to scale all values to 0-100.

\*\*v0.3.0 Enhancements\*\*: Supports 9-12 family axes and comparison
mode for multiple units.

## See also

[`plot_indicators_map`](https://pobsteta.github.io/nemeton/reference/plot_indicators_map.md),
[`normalize_indicators`](https://pobsteta.github.io/nemeton/reference/normalize_indicators.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Load demo data
data(massif_demo_units)
layers <- massif_demo_layers()
results <- nemeton_compute(massif_demo_units, layers, indicators = "all")
normalized <- normalize_indicators(results)

# Radar for a specific unit (indicator mode)
nemeton_radar(normalized, unit_id = "unit_001")

# Radar for average of all units
nemeton_radar(normalized)

# Custom indicators and styling
nemeton_radar(
  normalized,
  unit_id = "unit_005",
  indicators = c("carbon_norm", "biodiversity_norm", "water_norm"),
  fill_color = "#d73027",
  fill_alpha = 0.5
)

# Family mode with 9+ families (v0.3.0)
# First create family indices
units_fam <- create_family_index(normalized)
nemeton_radar(units_fam, unit_id = 1, mode = "family")

# Comparison mode (v0.3.0) - compare multiple units
nemeton_radar(units_fam, unit_id = c(1, 2, 3), mode = "family")
} # }
```
