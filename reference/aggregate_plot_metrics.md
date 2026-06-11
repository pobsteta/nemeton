# Compute per-plot aggregates from field data

For each placette, summarises the trees it contains into a set of
dendrometric aggregates that downstream indicators can consume:

- `n_trees`: total tree records.

- `n_trees_alive`: trees whose `statut == "vivant"`.

- `dbh_mean_cm`: arithmetic mean DBH.

- `dg_cm`: quadratic mean diameter (sqrt(mean(DBH^2))).

- `h_mean_m`: mean height of measured trees.

- `h_dom_m`: top height as the mean of the 5 tallest (or fewer if fewer
  trees have a measured height).

- `g_ha`: basal area (m^2/ha) assuming a circular plot of `plot_radius`
  metres.

- `cv_dbh`, `cv_h`: coefficients of variation (sd / mean) used by the B2
  structural diversity component.

## Usage

``` r
aggregate_plot_metrics(placettes, arbres = NULL, plot_radius = 15)
```

## Arguments

- placettes:

  sf POINT of placettes (with a `plot_id` column).

- arbres:

  sf POINT or data.frame of trees (plot_id, tree_id, dbh_cm, h_m,
  statut).

- plot_radius:

  Numeric. Plot radius (m) used to compute basal area per hectare.
  Default 15.

## Value

An sf object identical to `placettes` plus the aggregate columns
(prefixed `field_` to make them easy to keep separate from
remote-sensing metrics downstream).

## Details

Placettes with no trees receive NA for every aggregate and
`n_trees = 0L`.
