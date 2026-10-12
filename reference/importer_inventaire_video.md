# Import a video inventory into the project field data

The “Integrate” step: reads `inventaire_video.gpkg`
([`import_qgis_gpkg`](https://pobsteta.github.io/nemeton/reference/import_qgis_gpkg.md)),
reconciles each plot for which the Groma server returned a definitive
result
([`rapprocher_arbres`](https://pobsteta.github.io/nemeton/reference/rapprocher_arbres.md)),
derives `espece` from `essence_arbre`
([`map_bdforet_essence`](https://pobsteta.github.io/nemeton/reference/map_bdforet_essence.md)),
drops the `faux_positif` trees, validates
([`valider_inventaire_video`](https://pobsteta.github.io/nemeton/reference/valider_inventaire_video.md)),
aggregates per plot
([`aggregate_plot_metrics`](https://pobsteta.github.io/nemeton/reference/aggregate_plot_metrics.md),
one call per plot radius) and tags the NDP source
([`tag_field_data_sources`](https://pobsteta.github.io/nemeton/reference/tag_field_data_sources.md),
`source = "inventaire_video"`).

## Usage

``` r
importer_inventaire_video(
  gpkg,
  resultats = NULL,
  field_data_gpkg = NULL,
  plan = NULL,
  priorite = c("classique", "video"),
  region = "BFC"
)
```

## Arguments

- gpkg:

  Path to the `inventaire_video.gpkg` returned from the field.

- resultats:

  Optional paths (files or directories) of the definitive GeoPackages of
  the Groma server (layer `detections`), e.g. from
  [`groma_telecharger_resultats`](https://pobsteta.github.io/nemeton/reference/groma_etat_placettes.md).

- field_data_gpkg:

  Optional path of the project field data (`data/field_data.gpkg`),
  created when absent.

- plan:

  Optional sf of the original sampling plan (checked by
  [`valider_inventaire_video`](https://pobsteta.github.io/nemeton/reference/valider_inventaire_video.md)).

- priorite:

  `"classique"` (default) or `"video"`: which version of a plot
  inventoried both ways enters the main layers.

- region:

  Character. Species region. Default `"BFC"`.

## Value

A list with `placettes`, `arbres` (video inventory after reconciliation,
without `faux_positif`), `agregats` (tagged
[`aggregate_plot_metrics`](https://pobsteta.github.io/nemeton/reference/aggregate_plot_metrics.md)
output), `validation`, `a_completer` and `a_verifier` (subsets of
`arbres` by `etat_detection`), `classique_conserve` (plots whose
classical inventory stayed in the main layers), `ndp` (integer, NDP
level of `agregats`), `alertes` and `numeros_modifies` (reconciliation)
and `field_data_gpkg` (path or `NULL`).

## Details

With `field_data_gpkg`, the video plots are merged into the project
field data by `plot_id`, without overwriting: absent plots are added to
the `placettes` / `arbres` layers; for a plot already inventoried, the
version chosen by `priorite` stays in the main layers (the ones
aggregated downstream) and the other goes to `placettes_alternatives` /
`arbres_alternatives`. Every row carries a `source` column
(`"inventaire_terrain"` or `"inventaire_video"`).

## Lifecycle

Experimental (spec 061).
