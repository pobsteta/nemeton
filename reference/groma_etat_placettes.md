# Groma server client

`groma_etat_placettes()` lists the plots known to the Groma server
(`GET /placettes`) and their processing state.
`groma_telecharger_resultats()` downloads, for each plot, the definitive
result (`GET /placettes/{plot_id}/resultat.gpkg`) and the reports
(`rapport.json`, `rapport.html`). Requires httr2.

## Usage

``` r
groma_etat_placettes(url, jeton = NULL)

groma_telecharger_resultats(
  url,
  jeton = NULL,
  plot_ids,
  dossier,
  fichiers = c("resultat.gpkg", "rapport.json", "rapport.html")
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

  Files to download per plot. Default all three.

## Value

`groma_etat_placettes()`: a data.frame, one row per plot.
`groma_telecharger_resultats()`: character vector of the downloaded
files (`<plot_id>_<fichier>`), with the attribute `detail`, a data.frame
`plot_id`, `fichier`, `chemin` (`NA` when the download failed), `statut`
(HTTP status).

## Lifecycle

Experimental (spec 061).
