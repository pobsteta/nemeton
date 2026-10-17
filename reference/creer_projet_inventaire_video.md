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
  rayon_m = 20,
  seuil_diam_cm = 7.5,
  unite_azimut = c("deg", "gr"),
  declinaison_deg = NULL,
  avec_lidar = TRUE,
  dem = NULL,
  chm = NULL,
  project_path = NULL,
  marge_m = 10,
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

  Plot radius (m). Default 20.

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

  Margin around the plot for rasters and crowns (m). Default 10.

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
over the plot plus `marge_m`.

## Lifecycle

Experimental (spec 061).
