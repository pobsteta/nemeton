# Tag an sf object with field-data NDP attributes

Sets the attributes `field_plots_count` and `field_trees_count` that
[`detect_ndp`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
reads to bump the NDP to 2 (with plots only) or 3 (with \>= 10
trees/plot on average) along the alternative field-data path.

## Usage

``` r
tag_field_data_sources(
  data,
  placettes,
  arbres = NULL,
  source = "inventaire_terrain"
)
```

## Arguments

- data:

  An sf / data.frame to tag.

- placettes:

  sf or data.frame of placettes.

- arbres:

  sf or data.frame of trees (may be NULL).

- source:

  Character. Kind of field inventory, stored in
  `attr(data, "field_data_source")`: `"inventaire_terrain"` (default) or
  `"inventaire_video"` (Groma: a complete inventory, NDP 3 as soon as it
  carries trees), which
  [`detect_ndp`](https://pobsteta.github.io/nemeton/reference/detect_ndp.md)
  adds to the detected sources.

## Value

`data` with the added attributes.

## Lifecycle

Stable: covered by the 1.0 API contract (spec 057).

## Examples

``` r
df <- data.frame(x = 1)
placettes <- data.frame(plot_id = c("P1", "P2"))
arbres    <- data.frame(plot_id = rep(c("P1", "P2"), each = 15))
tagged <- tag_field_data_sources(df, placettes, arbres)
detect_ndp(tagged)$level  # 3
#> [1] 3
```
