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
  gpkg = NULL,
  resultats = NULL,
  field_data_gpkg = NULL,
  plan = NULL,
  priorite = c("classique", "video"),
  region = "BFC",
  terrain = NULL,
  dossier_photos = NULL
)
```

## Arguments

- gpkg:

  Path to the `inventaire_video.gpkg` returned from the field (QField
  copy). May be `NULL` when `terrain` is given.

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

- terrain:

  Optional paths of `terrain.zip` archives, or of directories searched
  for `*terrain.zip` (as written by
  [`groma_telecharger_resultats`](https://pobsteta.github.io/nemeton/reference/groma_etat_placettes.md)).

- dossier_photos:

  Directory receiving the photos of `terrain`. Default `photos/` next to
  `field_data_gpkg`, else next to `gpkg`; photo paths are written
  relative to that folder's parent when inside it.

## Value

A list with `placettes`, `arbres` (video inventory after reconciliation,
without `faux_positif`), `agregats` (tagged
[`aggregate_plot_metrics`](https://pobsteta.github.io/nemeton/reference/aggregate_plot_metrics.md)
output), `validation`, `a_completer` and `a_verifier` (subsets of
`arbres` by `etat_detection`), `classique_conserve` (plots whose
classical inventory stayed in the main layers), `ndp` (integer, NDP
level of `agregats`), `alertes` (`plot_id`, `uuid`, `motif`,
`dbh_provisoire`, `dbh_definitif`, `detail`: reconciliation, field data
and phone centres) and `numeros_modifies` (reconciliation) and
`field_data_gpkg` (path or `NULL`).

## Details

With `field_data_gpkg`, the video plots are merged into the project
field data by `plot_id`, without overwriting: absent plots are added to
the `placettes` / `arbres` layers; for a plot already inventoried, the
version chosen by `priorite` stays in the main layers (the ones
aggregated downstream) and the other goes to `placettes_alternatives` /
`arbres_alternatives`. Every row carries a `source` column
(`"inventaire_terrain"` or `"inventaire_video"`).

**Field data sent by Groma** (`terrain`, schema 1.5.0). Groma sends, per
plot, a `terrain.zip` holding `terrain.gpkg` (the same schema as the
QField copy, one plot) and `photos/`. For its plots, it replaces the
QField copy: if both exist, the server wins, with the alert
`terrain_serveur_prefere`, and each attribute entered only in QField
gets the alert `saisie_qfield_ignoree`. Only `terrain.gpkg` and
`photos/<name>` are extracted, never outside a temporary folder; packed
photos are copied to `dossier_photos/<plot_id>/` and their paths
rewritten.

A plot whose centre was measured with the phone GNSS
(`qualite_gnss = "telephone"`, schema 1.6.0) gets the alert
`centre_telephone`: the whole plot may be shifted by a few metres. The
matching tolerance is not widened: provisional and definitive trees are
both placed from that centre.

## Lifecycle

Experimental (spec 061).
