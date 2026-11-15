# Groma server client

`groma_etat_placettes()` lists the plots known to the Groma server
(`GET /placettes`) and their processing state.
`groma_telecharger_resultats()` downloads, for each plot, the definitive
result (`GET /placettes/{plot_id}/resultat.gpkg`), the reports
(`rapport.json`, `rapport.html`) and the field data entered in Groma
(`terrain.zip`, schema 1.5.0; HTTP 404 while nothing was sent, without
warning). Without `etat`, each call downloads everything afresh. With
`etat`, `terrain.zip` is requested only for plots whose
`terrain_envoye_le` is set, and only when it differs from the date of
the last download (kept next to the archive in
`<plot_id>_terrain.envoye_le`); otherwise the archive on disk is kept.
Requires httr2.

## Usage

``` r
groma_etat_placettes(url, jeton = NULL)

groma_telecharger_resultats(
  url,
  jeton = NULL,
  plot_ids,
  dossier,
  fichiers = c("resultat.gpkg", "rapport.json", "rapport.html", "terrain.zip"),
  etat = NULL
)
```

## Arguments

- url:

  Base URL of the Groma server.

- jeton:

  Bearer token (`NULL` for none).

- plot_ids:

  Character vector of plots to download.

- dossier:

  Destination directory (created if needed).

- fichiers:

  Files to download per plot. Default all four.

- etat:

  Optional data.frame returned by `groma_etat_placettes()`:
  `terrain.zip` is then downloaded only when its `terrain_envoye_le`
  changed. Default `NULL` (download all).

## Value

`groma_etat_placettes()`: a data.frame, one row per plot (with
`terrain_envoye_le` since schema 1.5.0; a plot with field data only has
`etat = "sans_paquet"`). `groma_telecharger_resultats()`: character
vector of the downloaded (or kept up-to-date) files
(`<plot_id>_<fichier>`), with the attribute `detail`, a data.frame
`plot_id`, `fichier`, `chemin` (`NA` when the download failed or nothing
was sent), `statut` (HTTP status, `NA` when no request was made) and
`telecharge` (`TRUE` when the file was downloaded by this call).

## Lifecycle

Experimental (spec 061).
