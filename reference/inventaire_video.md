# Video Inventory (Groma)

Platform side of the Groma video inventory: a smartphone video replaces
the manual measurement of a circular plot (calliper, compass, tape). The
Groma Android application computes a \*\*provisional\*\* inventory in
the field, the Groma server a \*\*definitive\*\* one. nemeton carries
every platform step:

- [`creer_projet_inventaire_video`](https://pobsteta.github.io/nemeton/reference/creer_projet_inventaire_video.md):
  the field GeoPackage (`inventaire_video.gpkg`), the per-plot DTM/CHM
  GeoTIFFs and the QField project;

- [`numeroter_arbres`](https://pobsteta.github.io/nemeton/reference/numeroter_arbres.md):
  the Groma numbering rule;

- [`affecter_hauteur_houppier`](https://pobsteta.github.io/nemeton/reference/affecter_hauteur_houppier.md):
  tree height from the segmented crowns;

- [`rapprocher_arbres`](https://pobsteta.github.io/nemeton/reference/rapprocher_arbres.md):
  provisional to definitive reconciliation, without losing any field
  attribute;

- [`valider_inventaire_video`](https://pobsteta.github.io/nemeton/reference/valider_inventaire_video.md)
  and
  [`importer_inventaire_video`](https://pobsteta.github.io/nemeton/reference/importer_inventaire_video.md):
  validation, aggregation, NDP tagging and merge into the project field
  data;

- [`groma_etat_placettes`](https://pobsteta.github.io/nemeton/reference/groma_etat_placettes.md)
  and
  [`groma_telecharger_resultats`](https://pobsteta.github.io/nemeton/reference/groma_etat_placettes.md):
  client of the Groma server.

The GeoPackage schema has a single source, shared with the Groma Python
and Kotlin code: `inst/inventaire_video/inventaire_video.schema.json`
(see
[`schema_inventaire_video`](https://pobsteta.github.io/nemeton/reference/schema_inventaire_video.md)).
Spec 061.
