# Send video-inventory trees back to the field

Builds a new QField project (`.qgz`) for the plots that still hold trees
to complete or to check after
[`importer_inventaire_video`](https://pobsteta.github.io/nemeton/reference/importer_inventaire_video.md)
(groma brief, section 4, option). The GeoPackage `inventaire_video.gpkg`
keeps **all** the reconciled trees of those plots, so that importing it
again replaces the plots without losing any tree; only the display of
the `arbres` layer is filtered on `etat_detection` (QGIS `subset`), and
it can be turned off with `filtrer = FALSE`.

## Usage

``` r
renvoyer_inventaire_video(
  import,
  gpkg = NULL,
  rasters = NULL,
  etats = c("a_completer", "a_verifier"),
  filtrer = TRUE,
  output_dir,
  project_name = "inventaire_video_retour",
  overwrite = TRUE
)
```

## Arguments

- import:

  Result of
  [`importer_inventaire_video`](https://pobsteta.github.io/nemeton/reference/importer_inventaire_video.md)
  (list with `placettes` and `arbres`).

- gpkg:

  Optional path of the `inventaire_video.gpkg` returned from the field,
  for the other layers.

- rasters:

  Optional directory holding the per-plot GeoTIFFs (`<plot_id>_mnt.tif`,
  `<plot_id>_mnh.tif`), e.g. the `rasters/` folder of the original
  `.qgz`; the files of the selected plots are copied.

- etats:

  States of `etat_detection` to send back. Default
  `c("a_completer", "a_verifier")`.

- filtrer:

  Logical. Filter the display of `arbres` on `etats`. Default `TRUE`.

- output_dir:

  Destination directory.

- project_name:

  File name of the `.qgz` (`^[A-Za-z0-9_-]+$`). Default
  `"inventaire_video_retour"`.

- overwrite:

  Logical. Overwrite an existing `.qgz`. Default `TRUE`.

## Value

Absolute path to the `.qgz` (invisibly), with attribute `plot_ids`
(plots sent back) and `n_arbres` (trees in `etats`).

## Details

The other layers (`centres_mesures`, `cibles`, `detections`,
`houppiers`) are copied for the same plots from `gpkg` when given, and
left empty otherwise. Layers are written as by
[`creer_projet_inventaire_video`](https://pobsteta.github.io/nemeton/reference/creer_projet_inventaire_video.md)
(no spatial index on `placettes`, `arbres`, `detections`; SQLite
triggers).

## Lifecycle

Experimental (spec 061).
