# QGIS Project Import and Aggregation

Read a GeoPackage produced by a QGIS or QField field session back into
R, validate its contents against the placette/arbre schema, and compute
per-plot aggregates that can be consumed by the core indicators (P1
volume, P2 site index, B2 structure, etc.).

Companion of
[`create_qgis_project`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
— the same schemas
([`get_placette_schema`](https://pobsteta.github.io/nemeton/reference/get_placette_schema.md),
[`get_arbre_schema`](https://pobsteta.github.io/nemeton/reference/get_arbre_schema.md))
define both the outbound form and the inbound validation rules.
