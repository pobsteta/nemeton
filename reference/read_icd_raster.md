# Read an ICD result raster

Reads one layer of the yearly ICD result written by
\[run_icd_decoloration()\], for the map of the app. Pixels without ICD
(outside the four pure stands, or outside the UGF zone) are \`NA\`; the
counts are attached so the app can say how many and why.

## Usage

``` r
read_icd_raster(
  zone_id,
  annee,
  result_dir,
  layer = c("niveau", "classe", "icd_min", "mois_alerte", "n_mois_valides"),
  a_date = FALSE
)
```

## Arguments

- zone_id:

  Integer. Monitoring zone.

- annee:

  Integer. Year.

- result_dir:

  Character. Root of the ICD results, as given to
  \[run_icd_decoloration()\].

- layer:

  One of \`"niveau"\` (0 normal to 4 repeated alert), \`"classe"\` (0
  normal, 1 watch, 2 alert), \`"icd_min"\`, \`"mois_alerte"\`,
  \`"n_mois_valides"\`.

- a_date:

  Logical. Read the "to date" set (every year on the months already
  available this year) instead of the full season.

## Value

A one-layer \[terra::SpatRaster\], with attributes \`annee\`,
\`a_date\`, \`provisoire\` (the year under way), \`n_pixels_zone\`,
\`n_pixels_icd\`, \`n_pixels_sans_icd\`; \`NULL\` when the year has not
been computed.

## See also

\[run_icd_decoloration()\], \[read_icd_pixel_series()\].
