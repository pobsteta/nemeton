# Detect NDP level and ML augmentation from data

Determines the NDP level and ML-augmented flags from the data sources
present on the dataset. Detection is based on attributes set on the data
(e.g. `has_lidar_hd`, `has_drone_rgb`, `chm_source`).

## Usage

``` r
detect_ndp(data)
```

## Arguments

- data:

  An sf object or data.frame with source attributes.

## Value

An object of class `"ndp_result"` — a list with:

- level:

  Integer. Detected NDP level (0-4).

- confidence:

  Numeric. Fibonacci confidence phi for `level`.

- augmented:

  Character vector. ML-augmentation flags (e.g. `"height_ml"` when
  `chm_source = "opencanopy"`).

- sources:

  Character vector. Data sources detected as present.

The object also carries `level` as an integer attribute so
`as.integer(result)` and arithmetic comparisons still work.

## Details

The NDP is the highest level for which ALL required sources are present.
ML-augmented flags (ADR-011 amended) do NOT change the base NDP level —
they are reported separately via the `augmented` vector.

Source attributes checked (cumulative):

- NDP 0: Always available (public: Sentinel-2, WorldClim, BD TOPO, MNT
  25m)

- NDP 1: `has_lidar_hd = TRUE`

- NDP 2: NDP 1 + `has_drone_rgb = TRUE`

- NDP 3: NDP 2 + `has_inventaire_terrain = TRUE`

- NDP 4: NDP 3 + `has_scanner_terrestre = TRUE`

ML-augmentation flags recognised:

- `"height_ml"` : `attr(data, "chm_source") == "opencanopy"`

- `"species_ml"` :
  `attr(data, "species_source") %in% c("tree_sat", "maestro")`

- `"texture_ml"` : `attr(data, "texture_source") == "maestro"`

## Note

Breaking change in nemeton 0.16.0: `detect_ndp()` used to return a plain
integer. It now returns an `ndp_result` list. Use `result$level` or
`as.integer(result)` for the numeric level.

## Examples

``` r
# Default: NDP 0, no ML augmentation
df <- data.frame(x = 1)
r <- detect_ndp(df)
r$level
#> [1] 0
r$augmented
#> character(0)

# With LiDAR HD: NDP 1
attr(df, "has_lidar_hd") <- TRUE
detect_ndp(df)$level
#> [1] 1

# With opencanopy CHM: NDP 0 but augmented
df2 <- data.frame(x = 1)
attr(df2, "chm_source") <- "opencanopy"
detect_ndp(df2)$augmented  # "height_ml"
#> [1] "height_ml"
```
