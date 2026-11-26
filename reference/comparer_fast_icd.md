# Compare FAST and the ICD on a zone and a year

Crosses the FAST classes (0 to 4: 0 no alert, 1 to 4 the quartiles of
the positive scores) with the ICD levels (0 to 4) over the pixels that
have both, in surface (a 20 m pixel = 0.04 ha), and gives the overall
agreement and Cohen's kappa. Kappa is an indicator, not a validation:
both methods have their own errors. A second comparison is made at
\*\*equal alerted surface\*\* (the criterion of the
FAST-versus-discoloration study, mission 045): the ICD alert is level
\>= 2, and FAST is called alert on the same share of pixels, those with
the highest scores.

## Usage

``` r
comparer_fast_icd(
  zone_id,
  annee,
  result_dir,
  fast = NULL,
  con = NULL,
  cache_dir = NULL,
  a_date = FALSE,
  pixel_ha = 0.04
)
```

## Arguments

- zone_id:

  Integer. Monitoring zone.

- annee:

  Integer. Year.

- result_dir:

  Character. Root of the ICD results.

- fast:

  A \`SpatRaster\` of the continuous FAST score (the \`"count"\` alert
  raster of \[read_fast_alert_raster()\]). When \`NULL\`, it is read
  with \`read_fast_alert_raster()\` from \`con\` and \`cache_dir\` over
  April to October of \`annee\`.

- con, cache_dir:

  Used only when \`fast\` is \`NULL\`.

- a_date:

  Logical. Use the "to date" ICD set.

- pixel_ha:

  Pixel surface in hectares (20 m: 0.04).

## Value

A list: \`statut\` (\`"ok"\`, \`"fast_absent"\`, \`"icd_absent"\`,
\`"sans_pixel_commun"\`), \`annee\`, \`n_pixels\`, \`croisement\`
(\`fast\`, \`icd\`, \`n_pixels\`, \`surface_ha\`), \`accord_global\`,
\`kappa\`, \`surface_egale\` (\`part_alertee\`, \`n_alertes\`,
\`accord\`, \`kappa\`, and the hectares \`les_deux\`, \`fast_seul\`,
\`icd_seul\`, \`aucune\`).

## See also

\[run_icd_decoloration()\], \[read_fast_alert_raster()\].
