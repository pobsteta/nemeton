# Detect NDP level from data

Determines the NDP level based on the data sources present in the
dataset. Detection is based on attributes set on the data (e.g.,
`has_lidar_hd`, `has_drone_rgb`).

## Usage

``` r
detect_ndp(data)
```

## Arguments

- data:

  An sf object or data.frame with source attributes.

## Value

Integer. Detected NDP level (0-4).

## Details

The NDP is the highest level for which ALL required sources are present.

Source attributes checked (cumulative):

- NDP 0: Always available (public data: Sentinel-2, WorldClim, BD TOPO,
  MNT 25m)

- NDP 1: `has_lidar_hd = TRUE`

- NDP 2: NDP 1 + `has_drone_rgb = TRUE`

- NDP 3: NDP 2 + `has_inventaire_terrain = TRUE`

- NDP 4: NDP 3 + `has_scanner_terrestre = TRUE`

## Examples

``` r
# Default: NDP 0
df <- data.frame(x = 1)
detect_ndp(df)
#> [1] 0

# With LiDAR HD: NDP 1
attr(df, "has_lidar_hd") <- TRUE
detect_ndp(df)
#> [1] 1
```
