# Remove pixels outside the oak stands or clear-cut

Applies the two RECONFORT training masks to a table of pixels (or plots)
located by coordinates: \* \*\*oak stand\*\*: a pixel outside the layer
\`chenaie\` is removed (the layer is supplied by the caller, in practice
BD Foret v2); \* \*\*clear-cut\*\*: a pixel whose SUFOSAT date
(\`YYDDD\`) falls in year \`C\` is removed for every observation year
\`annee \>= C\` (kept for the years before the cut; the cut year is
excluded because the series is then already disturbed).

## Usage

``` r
reconfort_masquer(pixels, chenaie = NULL, coupes = NULL, crs = "EPSG:2154")
```

## Arguments

- pixels:

  A \`data.frame\` with \`x\`, \`y\` and \`annee\` (observation year).

- chenaie:

  \`NULL\` (no oak mask), a \[terra::SpatRaster\] (cells with a
  non-zero, non-\`NA\` value are oak stand) or an \`sf\` polygon layer.

- coupes:

  \`NULL\` (no clear-cut mask), a \[terra::SpatRaster\] holding
  \`YYDDD\` codes, or an \`sf\` layer with a \`date_coupe\` column
  (\`YYDDD\`) of polygons (several cuts on a pixel: the earliest
  counts).

- crs:

  Coordinate reference system of \`x\`/\`y\` (anything accepted by
  \[terra::crs()\]); masks are reprojected to it when it differs.

## Value

\`pixels\` without the removed rows, with the attribute \`retires\` (a
data.frame of the removed rows and their \`motif\`: \`"hors_chenaie"\`
or \`"coupe_rase"\`).

## Examples

``` r
px <- data.frame(x = 1, y = 1, annee = c(2020L, 2021L))
coupes <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2,
                      crs = "EPSG:2154", vals = 21150)
reconfort_masquer(px, coupes = coupes, crs = "EPSG:2154")
#>   x y annee
#> 1 1 1  2020
```
