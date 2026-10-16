# Validate a video inventory

Runs
[`validate_field_data`](https://pobsteta.github.io/nemeton/reference/validate_field_data.md)
with `dbh_max_cm = Inf` and `dbh_alerte_cm = 200` (any diameter
accepted, flagged above 2 m), on the trees that are not `faux_positif`,
then the video-specific checks: `tree_id` unique and non-empty, `uuid`
unique and non-empty, domains of `etat_detection`, `h_source`, `methode`
and `essence_arbre`, and, when `plan` is given, sampling-design columns
and plot positions identical to the original plan.

The read-only layers `parcelles`, `ugf` and `projet` (schema 1.2.0) are
not checked. A plot may have several rows in `centres_mesures` (Groma
never rewrites a centre): this is reported as an information
(`severity = "info"` in `warnings`), the most recent centre being the
one used.

## Usage

``` r
valider_inventaire_video(gpkg, plan = NULL, region = "BFC")
```

## Arguments

- gpkg:

  Path to `inventaire_video.gpkg`, or a list with `placettes` and
  `arbres` (as returned by
  [`import_qgis_gpkg`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md)).

- plan:

  Optional sf of the original placettes (sampling plan).

- region:

  Character. Species region. Default `"BFC"`.

## Value

A list with `ok`, `errors` and `warnings`, as
[`validate_field_data`](https://pobsteta.github.io/nemeton/reference/validate_field_data.md).

## Lifecycle

Experimental (spec 061).
