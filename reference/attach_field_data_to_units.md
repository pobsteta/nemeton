# Attach per-plot field aggregates to a units sf

Spatial-joins a sf of forest units (polygons) with the sf of aggregated
placettes (points). For each unit, the aggregates are averaged across
the placettes it contains; units with no placettes get NAs (and
`field_n_trees = 0`).

## Usage

``` r
attach_field_data_to_units(units, field_agg)
```

## Arguments

- units:

  sf POLYGON. Forest management units.

- field_agg:

  sf POINT. Output of
  [`aggregate_plot_metrics`](https://pobsteta.github.io/nemeton/reference/aggregate_plot_metrics.md).

## Value

`units` enriched with `field_*` columns.

## Details

This gives indicators a uniform `field_*` set of columns to read,
regardless of whether field data is available or not.
