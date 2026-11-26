# Series of one pixel for the ICD charts

For a point (the click on the map), reads from the rasters already
computed by \[run_icd_decoloration()\] (no network, local reads): per
year and month the raw value and the anomaly \`z\` of the five indices,
the ICD, the sensitive months of the species group, the weights used,
the thresholds, and the class and level of each year.

## Usage

``` r
read_icd_pixel_series(zone_id, xy, crs = 4326, result_dir, a_date = FALSE)
```

## Arguments

- zone_id:

  Integer. Monitoring zone.

- xy:

  Numeric length 2, \`c(x, y)\` (east, north) in \`crs\`.

- crs:

  CRS of \`xy\` (default 4326: longitude, latitude).

- result_dir:

  Character. Root of the ICD results.

- a_date:

  Logical. Read the "to date" annual set.

## Value

\`NULL\` when the zone has no result or the point is outside the grid.
Otherwise a list: \`essence\` (\`NA\` for a pixel without ICD, with
\`motif\`), \`serie\` (long \`data.frame\`: \`annee\`, \`mois\`,
\`indice\`, \`brut\`, \`z\`), \`icd\` (\`annee\`, \`mois\`, \`icd\`,
\`sensible\`), \`annuel\` (\`annee\`, \`classe\`, \`niveau\`,
\`icd_min\`, \`mois_alerte\`, \`date_alerte\`, \`provisoire\`),
\`poids\` (weights used for the species group, rescaled to 1),
\`indices_actifs\`, \`mois_sensibles\`, \`seuils\` and
\`annee_provisoire\`.

## See also

\[run_icd_decoloration()\], \[read_icd_raster()\].
