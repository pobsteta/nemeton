# Field Data Schema for QField Integration

Defines the data model used for field inventory with QField. Two layers
are linked by `plot_id`:

- **placette** (1): sampling plot, produced upstream by the GRTS/TSP
  workflow (tutorial 09-sampling).

- **arbre** (N): individual tree measurements collected on the field.

Each field description carries the information needed by
[`create_qgis_project`](https://pobsteta.github.io/nemeton/reference/create_qgis_project.md)
to produce a fully configured `.qgz` project: type, domain of values,
and the recommended QGIS edit widget.

The species domain is pulled from
[`list_species_classes`](https://pobsteta.github.io/nemeton/reference/list_species_classes.md)
to keep a single source of truth with the rest of the package.
