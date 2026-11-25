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
  overwrite = TRUE,
  n_workers = .iv_workers_defaut(),
  progress_callback = NULL
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
  DEFLATE, `0` = nodata), in Groma's coding. Accepted codings,
  recognised by the declared nodata: Byte with nodata `255`
  (foretaccess, relief `0` to `254`) written as `value + 1`, `255`
  giving `0`; Byte with nodata `0` (already Groma, `1` to `255`) copied
  as is; a float relief `v` in \\\[0, 1\]\\ (cache of `generate_rvt()`)
  written as `1 + round(v * 254)`, `NA` giving `0`. Whatever the
  resolution or CRS, the nodata is set to `NA` first, then the raster is
  reprojected (when not in EPSG:2154) and resampled to the 2 m grid
  (nearest neighbour for Byte, bilinear for float), then coded. This is
  a deliberate departure from section 2.3 of the Groma brief, which
  refused any resolution other than 2 m: the CVAT of nemetonshiny keeps
  the resolution of the DTM (often 0.5 m), and refusing it would break
  real use. Known limit: `foretaccess::vat_combined(as_byte = TRUE)`
  codes `0` to `255` with `NA` as `255`; a valid maximal relief pixel
  (\\v \ge 0.996\\) is therefore indistinguishable from nodata and
  becomes `0` (fix planned in foretaccess). `NULL` (default): no
  `cvat.tif`. A missing file only raises a warning; an unreadable or
  otherwise coded file (Byte without nodata `0` or `255` declared,
  Int16, float outside \\\[0, 1\]\\) is an error of class
  `nemeton_erreur_cvat_codage`, raised before anything is written.

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

- n_workers:

  Integer (\\\ge 1\\). Number of worker processes used to segment the
  crowns tile by tile. Default
  `getOption("nemeton.iv_workers", min(4, parallel::detectCores() - 1))`
  (`1` when the number of cores cannot be detected). `1` segments
  sequentially, in this process. Workers are PSOCK processes (never
  forks, which hang with terra); each one reads the CHM from its file,
  so the parallel path is used only when the CHM is a file (a path, or a
  `SpatRaster` backed by one file already in EPSG:2154); an in-memory
  CHM is segmented sequentially. The crowns are identical whatever
  `n_workers` (same rows, same order, same `houppier_id`). If the
  cluster cannot be started, a warning is raised and the segmentation
  runs sequentially.

- progress_callback:

  Optional function called with a single list
  `list(etape, i, n, secondes)` at the start of each stage (`i = 0`) and
  after each of its units, never fatal (an error raised by the callback
  is ignored). `etape` is the stable stage name, `i` the units done out
  of `n`, `secondes` the time elapsed since the stage started (so the
  last call of a stage, with `i == n`, gives its duration). Stages, in
  order: `"sources"` (project tables and forest extent; `n = 1`),
  `"placettes"` (per-plot rasters and topography; `n` = plots),
  `"dalles_mnt"` (1 km DTM tiles; `n` = tiles), `"houppiers"` (crown
  segmentation; `n` = 1 km tiles, counted per tile when sequential, per
  batch of `n_workers` tiles when parallel; if the parallel run fails
  midway and falls back to sequential, the stage restarts with a new
  `i = 0` call and `secondes` restarts from 0), `"cvat"` (`n = 1`),
  `"geopackage"` (layers, triggers, indexes; `n = 1`) and `"qgz"`
  (`.qgs`, archive and project folder; `n = 1`). `"placettes"`,
  `"dalles_mnt"` and `"houppiers"` occur only with `avec_lidar` (the
  last two also need a DTM, respectively a CHM); `"cvat"` only with
  `cvat_path`.

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
