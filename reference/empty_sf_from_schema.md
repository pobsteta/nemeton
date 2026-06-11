# Build an empty sf data.frame matching a schema

Produces a zero-row `sf` object whose columns and column types match
`schema`. Used by
[`create_qgis_project`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
to seed the `arbre` layer before it is filled on the field.

## Usage

``` r
empty_sf_from_schema(schema, crs = 2154, geometry_type = "POINT")
```

## Arguments

- schema:

  A schema list (see
  [`get_arbre_schema`](https://pobsteta.github.io/nemeton/reference/get_arbre_schema.md)).

- crs:

  An integer EPSG code. Default 2154 (Lambert-93).

- geometry_type:

  One of `"POINT"`, `"MULTIPOINT"`, `"LINESTRING"`, `"POLYGON"`. Default
  `"POINT"`.

## Value

An empty sf object.
