# Create a QGIS project from a sampling plan

Packages sampling plots, study area, and (optionally) the TSP route as a
`.qgz` QGIS 3.x project. The project embeds a GeoPackage and a minimal
QGIS project file wired with field schemas, ready to open in QGIS
Desktop and to push to QField via QFieldSync.

\`create_qfield_project()\` is a deprecated alias kept for backwards
compatibility. It forwards to \[create_qgis_project()\] and emits a
one-shot deprecation warning. New code should call
\[create_qgis_project()\] directly.

## Usage

``` r
create_qgis_project(
  placettes,
  zone_etude = NULL,
  parcours_tsp = NULL,
  output_dir,
  project_name = "echantillon",
  crs = 2154,
  region = "BFC",
  lang = "fr",
  overwrite = TRUE
)

create_qfield_project(
  placettes,
  zone_etude = NULL,
  parcours_tsp = NULL,
  output_dir,
  project_name = "echantillon",
  crs = 2154,
  region = "BFC",
  lang = "fr",
  overwrite = TRUE
)
```

## Arguments

- placettes:

  An sf object with POINT geometry. Must contain the `plot_id` column. A
  `type` column (values `"Base"`, `"Over"`) triggers categorised
  symbology.

- zone_etude:

  Optional sf polygon of the study area.

- parcours_tsp:

  Optional sf linestring of the TSP route.

- output_dir:

  Character. Destination directory (created if needed).

- project_name:

  Character. Name of the `.qgz` file (without extension) and the project
  title in QGIS. Default `"echantillon"`.

- crs:

  Integer EPSG code. Must match the CRS of `placettes`. Default 2154
  (Lambert-93).

- region:

  Character. Species region used to populate the `espece` domain in the
  arbre layer. Default `"BFC"`.

- lang:

  Character. Language used for aliases and labels. Default `"fr"`.

- overwrite:

  Logical. Overwrite an existing `.qgz`. Default `TRUE`.

## Value

Absolute path to the `.qgz` file that was created.

## Examples

``` r
if (FALSE) { # \dontrun{
library(sf)
pts <- st_sf(
  plot_id = sprintf("P%02d", 1:3),
  type = c("Base", "Base", "Over"),
  visit_order = 1:3,
  geometry = st_sfc(st_point(c(900000, 6500000)),
                    st_point(c(900100, 6500100)),
                    st_point(c(900200, 6500200)),
                    crs = 2154)
)
qgz <- create_qgis_project(pts, output_dir = tempdir())
} # }
```
