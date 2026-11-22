# Create the video inventory field project

Builds `inventaire_video.gpkg` (layers `placettes`, `centres_mesures`,
`cibles`, `arbres`, `detections`, `houppiers`, and the read-only
`parcelles`, `ugf` and `projet` of schema 1.2.0, see
[`schema_inventaire_video`](https://pobsteta.github.io/nemeton/reference/schema_inventaire_video.md)),
the per-plot DTM and CHM GeoTIFFs (`rasters/<plot_id>_mnt.tif`,
`rasters/<plot_id>_mnh.tif`: Float32, 0.5 m, strips, DEFLATE without
predictor, nodata -9999) and the QField project, packaged as a `.qgz`
like
[`create_qgis_project`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md).

## Usage

``` r
creer_projet_inventaire_video(
  placettes,
  plot_ids = NULL,
  rayon_m = 15,
  seuil_diam_cm = 7.5,
  unite_azimut = c("deg", "gr"),
  declinaison_deg = NULL,
  avec_lidar = TRUE,
  dem = NULL,
  chm = NULL,
  project_path = NULL,
  marge_m = 10,
  cvat_path = NULL,
  output_dir,
  project_name = "inventaire_video",
  region = "BFC",
  lang = "fr",
  overwrite = TRUE
)
```

## Arguments

- placettes:

  sf POINT of the sampling plan (`plot_id` required).

- plot_ids:

  Optional character vector: plots to include.

- rayon_m:

  Plot radius (m). Default 15 (ONF LiDAR calibration plots).

- seuil_diam_cm:

  Minimal diameter (cm). Default 7.5.

- unite_azimut:

  `"deg"` or `"gr"`.

- declinaison_deg:

  Magnetic declination (degrees, positive towards east). `NULL`
  (default) leaves it empty (`NA`, never 0): Groma then computes it with
  WMM2025 at the plot; a value given here takes precedence.

- avec_lidar:

  Logical. Clip DTM/CHM and segment crowns. Default `TRUE`; without any
  DTM/CHM available, a warning is raised and the project is built
  without rasters.

- dem, chm:

  `SpatRaster` or path. When `NULL`, resolved from `project_path` with
  [`resolve_project_dem`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md)
  and
  [`resolve_project_chm`](https://pobsteta.github.io/nemeton/reference/resolve_project_layers.md).

- project_path:

  Optional nemetonshiny project directory, used to resolve `dem` and
  `chm`, and read (never written) to fill the tables shown by the Groma
  map and project list: `projet` (one row, from `metadata.json`,
  `data/parcels.gpkg`, `data/commune.gpkg` and the written plots;
  `emprise` is the plots' envelope in EPSG:4326 WKT), `parcelles` (copy
  of `data/parcels.gpkg`) and `ugf` (`data/tenements.gpkg` merged by
  `ug_id`, attributes from `data/ugs.json`). Without it, or when a
  source cannot be read (warning), those tables are created empty.

- marge_m:

  Margin around the plot for the per-plot rasters (m), and around the
  plots in the forest extent when there is neither `ugf` nor
  `parcelles`. Default 10.

- cvat_path:

  Optional path of a CVAT relief raster (as computed by nemetonshiny
  with `foretaccess::vat_combined()`). When given, it is cropped to the
  forest extent and written as `rasters/cvat.tif` (Byte, 2 m, EPSG:2154,
  DEFLATE; `1 + round(v * 254)` for a relief `v` in \\\[0, 1\]\\, `0` =
  nodata; a float value outside \\\[0, 1\]\\ is clamped, `NA` gives
  `0`). A Byte input (the 8-bit CVAT of nemetonshiny, `v = b / 255`) is
  rescaled the same way, its value `255` being foretaccess' marker for
  `NA` and giving `0`. Reprojected when not in EPSG:2154. `NULL`
  (default): no `cvat.tif`. A missing or unreadable file only raises a
  warning.

- output_dir:

  Destination directory.

- project_name:

  File name of the `.qgz` (`^[A-Za-z0-9_-]+$`). Default
  `"inventaire_video"`.

- region, lang:

  Unused for the species list (the tree species list is the BD Foret V2
  reference); kept for symmetry with
  [`create_qgis_project`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md).

- overwrite:

  Logical. Overwrite an existing `.qgz`. Default `TRUE`.

## Value

Absolute path to the `.qgz` (invisibly). The Groma QField project plugin
is written next to it as `<project_name>.qml` (copy of
`inst/inventaire_video/inventaire_video.qml`, not inside the archive):
ship both files to the phone. A folder `<project_name>/` is also written
next to the `.qgz`, holding the same project ready to open
(`<project_name>.qgs`, `inventaire_video.gpkg`, `rasters/`,
`<project_name>.qml`): QGIS resolves the `./` paths of the project from
the folder of the `.qgz`, so a `.qgz` opened alone finds none of its
layers. The folder is replaced like the `.qgz` (`overwrite`), edits made
in it included.

## Details

`placettes`, `arbres` and `detections` are written **without spatial
index**: the GDAL R\*Tree triggers call `ST_IsEmpty` on every `UPDATE`,
a function the Android SQLite used by Groma does not know. The triggers
of `declencheurs.sql` then link `detections` (written by Groma only) to
`arbres` by `uuid`, without any spatial function.

The planned position and the sampling-design columns of `placettes` are
never modified. `convergence_deg` (meridian convergence at the planned
point) is computed; `pente_pct`, `exposition` and `recouvrement_pct` are
filled from the DTM/CHM when empty. Crowns come from
[`segment_houppiers`](https://pobsteta.github.io/nemeton/reference/segment_houppiers.md)
over the whole forest extent (see section “Forest-wide data”), not only
around the plots.

## Forest-wide data (schema 1.7.0)

The forest extent is the union of the `ugf` plus 50 m (else of the
`parcelles` plus 50 m, else the plots plus `rayon_m + marge_m`); it
always also covers every plot plus `rayon_m + marge_m`, so that a plot
planned outside the `ugf` keeps its data. On that extent the function
writes 1 km DTM tiles `rasters/mnt_<x>_<y>.tif` (south-west corner in
km, 4 digits; 0.5 m, same format as the per-plot rasters, nodata outside
the extent or the LiDAR; no CHM tile), segments the crowns
([`segment_houppiers`](https://pobsteta.github.io/nemeton/reference/segment_houppiers.md),
tile by tile, a crown kept by the tile that holds its apex) and writes
them to `houppiers` with `x_sommet` / `y_sommet`. A crown touching the
buffer (`rayon_m + marge_m`) of one or several plots is written once per
plot touched, with that `plot_id` (as before schema 1.7.0); a crown
touching none is written once with `plot_id` `NULL`. `houppier_id`
identifies the crown: the rows of a crown shared by two plots carry the
same `houppier_id`. Tiles and `cvat.tif` (legend group "Rasters des
placettes") are in the `.qgz` and in the project folder.

## Lifecycle

Experimental (spec 061).
