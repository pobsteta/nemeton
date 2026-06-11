# QGIS Project Export

Package a sampling plan (output of the GRTS + TSP workflow, see tutorial
`09-sampling`) as a `.qgz` QGIS 3.x project that can be opened directly
in QGIS Desktop or pushed to QField on a tablet via the QFieldSync
plugin.

A `.qgz` is a ZIP archive containing a QGIS project file (`.qgs` XML)
and the data referenced with relative paths. We embed a GeoPackage with
the layers required for field work:

- **placettes**: GRTS sampling points (editable metadata).

- **arbres**: empty layer seeded from
  [`get_arbre_schema`](https://pobsteta.github.io/nemeton/reference/get_arbre_schema.md),
  filled on the field.

- **zone_etude**: study area (read-only context).

- **parcours_tsp** (optional): TSP route between plots.

The QGIS project file declares edit widgets, aliases, and NOT NULL
constraints based on the schemas returned by
[`get_placette_schema`](https://pobsteta.github.io/nemeton/reference/get_placette_schema.md)
and
[`get_arbre_schema`](https://pobsteta.github.io/nemeton/reference/get_arbre_schema.md),
so the form is ready to use both on QGIS Desktop and on QField.
